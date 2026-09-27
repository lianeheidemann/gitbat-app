import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/crop_rect.dart';
import '../painting/frame_painter.dart' show rasterizeSvgFile;

// A opção "Ajustar" dos recortes (Editar imagem, Editar SVG e o recorte de
// foto da Montagem): acha o menor retângulo que ainda contém todo pixel
// visível, para cortar só as faixas totalmente transparentes em volta do
// desenho.

/// Alfa até este valor (~3% de opacidade) conta como transparente.
///
/// Zero exato não serve: PNGs saídos de removedores de fundo costumam deixar
/// dezenas de milhares de pixels com alfa 1–8 espalhados pela área "vazia".
/// São invisíveis, mas seguravam o recorte quase no tamanho da imagem. Nas
/// imagens reais medidas, o resultado é o mesmo com qualquer limiar entre 8
/// e 64, então 8 corta a sujeira sem comer a borda suave do desenho.
const invisibleAlphaThreshold = 8;

/// Menor [CropRect] que contém todo pixel de [rgba] com alfa acima de
/// [invisibleAlphaThreshold], ou `null` se nenhum pixel for visível.
///
/// Varre de fora para dentro e para no primeiro pixel achado em cada lado —
/// numa foto sem margem nenhuma isso sai quase de graça.
CropRect? opaqueBounds(Uint8List rgba, int width, int height) {
  bool rowHasContent(int y) {
    final start = y * width * 4 + 3;
    final end = start + width * 4;
    for (var i = start; i < end; i += 4) {
      if (rgba[i] > invisibleAlphaThreshold) return true;
    }
    return false;
  }

  var top = 0;
  while (top < height && !rowHasContent(top)) {
    top++;
  }
  if (top == height) return null;

  var bottom = height - 1;
  while (bottom > top && !rowHasContent(bottom)) {
    bottom--;
  }

  // Esquerda e direita só precisam olhar a faixa entre topo e base.
  bool columnHasContent(int x) {
    for (var y = top; y <= bottom; y++) {
      if (rgba[(y * width + x) * 4 + 3] > invisibleAlphaThreshold) {
        return true;
      }
    }
    return false;
  }

  var left = 0;
  while (!columnHasContent(left)) {
    left++;
  }
  var right = width - 1;
  while (right > left && !columnHasContent(right)) {
    right--;
  }

  return CropRect(
    x: left,
    y: top,
    width: right - left + 1,
    height: bottom - top + 1,
  );
}

/// Decodifica a foto em [path] e devolve [opaqueBounds] dela. A varredura
/// roda num isolate à parte: numa foto de 12 MP são 48 MB de bytes, o
/// bastante para travar a tela por um instante.
///
/// Com [width]/[height], o resultado sai nessa escala em vez da do arquivo
/// decodificado — para quem guarda o recorte num tamanho de exibição que
/// não bate pixel a pixel com o arquivo.
Future<CropRect?> detectOpaqueBounds(
  String path, {
  int? width,
  int? height,
}) async {
  final image = await _decode(await File(path).readAsBytes());
  return _boundsOf(image, width ?? image.width, height ?? image.height);
}

/// Mesma coisa de [detectOpaqueBounds] para um SVG, medido no espaço de
/// [width]x[height]. O desenho é rasterizado maior (até ~1024 px no lado
/// maior) para um ícone pequeno não perder precisão na borda.
Future<CropRect?> detectSvgOpaqueBounds(
  String path,
  int width,
  int height,
) async {
  final longest = math.max(width, height);
  final scale = longest <= 0 ? 1.0 : (1024 / longest).clamp(1.0, 8.0);
  final png = await rasterizeSvgFile(
    path,
    (width * scale).round().clamp(1, 1 << 14),
    (height * scale).round().clamp(1, 1 << 14),
  );
  return _boundsOf(await _decode(png), width, height);
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

/// [opaqueBounds] de [image], convertido para o espaço [targetWidth]x
/// [targetHeight] — arredondando para fora, para nunca cortar um pixel
/// visível. Libera [image].
Future<CropRect?> _boundsOf(
  ui.Image image,
  int targetWidth,
  int targetHeight,
) async {
  try {
    // `rawRgba` vem pré-multiplicado, mas o canal alfa em si não muda.
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    final rgba = data.buffer.asUint8List();
    final width = image.width;
    final height = image.height;
    final bounds = await Isolate.run(() => opaqueBounds(rgba, width, height));
    if (bounds == null) return null;
    if (width == targetWidth && height == targetHeight) return bounds;
    final sx = targetWidth / width;
    final sy = targetHeight / height;
    final left = (bounds.x * sx).floor().clamp(0, targetWidth - 1);
    final top = (bounds.y * sy).floor().clamp(0, targetHeight - 1);
    final right = ((bounds.x + bounds.width) * sx).ceil().clamp(
      left + 1,
      targetWidth,
    );
    final bottom = ((bounds.y + bounds.height) * sy).ceil().clamp(
      top + 1,
      targetHeight,
    );
    return CropRect(x: left, y: top, width: right - left, height: bottom - top);
  } finally {
    image.dispose();
  }
}
