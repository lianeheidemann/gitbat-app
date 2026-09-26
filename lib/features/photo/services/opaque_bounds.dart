import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../../core/models/crop_rect.dart';

// A opção "Ajustar ao conteúdo" da aba "Recorte" de "Editar imagem": acha o
// menor retângulo que ainda contém todo pixel visível da foto, para cortar
// só as faixas totalmente transparentes em volta do desenho.

/// Menor [CropRect] que contém todo pixel de [rgba] com alfa maior que zero,
/// ou `null` se a imagem inteira for transparente.
///
/// "Transparente" aqui é alfa 0 exato, sem limiar: uma sombra quase invisível
/// ainda é parte do desenho e não pode ser cortada.
///
/// Varre de fora para dentro e para no primeiro pixel achado em cada lado —
/// numa foto sem margem nenhuma isso sai quase de graça.
CropRect? opaqueBounds(Uint8List rgba, int width, int height) {
  bool rowHasContent(int y) {
    final start = y * width * 4 + 3;
    final end = start + width * 4;
    for (var i = start; i < end; i += 4) {
      if (rgba[i] != 0) return true;
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
      if (rgba[(y * width + x) * 4 + 3] != 0) return true;
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
Future<CropRect?> detectOpaqueBounds(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final ui.Image image;
  try {
    image = (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }

  try {
    // `rawRgba` vem pré-multiplicado, mas o canal alfa em si não muda.
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    final rgba = data.buffer.asUint8List();
    final width = image.width;
    final height = image.height;
    return await Isolate.run(() => opaqueBounds(rgba, width, height));
  } finally {
    image.dispose();
  }
}
