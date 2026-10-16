import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../models/drawing_layer.dart';

/// A tradução de [DrawingLayer] em pixels — a **única**: a prévia das três
/// telas (Editar imagem, Editar SVG e o "..." da Montagem) e as exportações
/// saem daqui, então o que se vê é o que se salva. O SVG exportado tem a
/// mesma geometria em `<path>` (ver `svg_xml_editor.dart`'s
/// `applyDrawingSvg`).
///
/// Duas camadas, sempre nesta ordem:
///  - a da **imagem**, onde os traços de [DrawingTool.cutout] abrem buracos
///    transparentes;
///  - a dos **traços**, por cima: o pincel pinta, e a borracha e a
///    transparência limpam o que foi pintado antes delas. Um traço pintado
///    depois de uma transparência continua à vista.

/// Desenha [stroke] em [box] com [paint] (cor e modo de mistura por conta
/// de quem chama): polilinha de pontas e junções redondas, ou um círculo
/// quando o dedo só tocou.
void paintDrawingStroke(
  Canvas canvas,
  Size box,
  DrawingStroke stroke,
  Paint paint,
) {
  if (stroke.points.isEmpty) return;
  final points = stroke.pointsIn(box);
  final width = stroke.widthIn(box);
  paint.isAntiAlias = true;
  if (points.length == 1) {
    canvas.drawCircle(
      points.first,
      width / 2,
      paint..style = PaintingStyle.fill,
    );
    return;
  }
  canvas.drawPath(
    Path()..addPolygon(points, false),
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
}

Paint _clearPaint() => Paint()
  ..color = const Color(0xFF000000)
  ..blendMode = BlendMode.clear;

/// A camada dos traços em [box], numa camada própria: a borracha usa
/// [BlendMode.clear], que só pode limpar o que é dela — nunca a imagem nem o
/// que já estava no canvas por baixo.
void paintDrawingStrokes(Canvas canvas, Size box, DrawingLayer layer) {
  // Sem pintura não há o que mostrar: as borrachas sozinhas não deixam
  // marca nenhuma nesta camada.
  if (!layer.hasPaint) return;
  canvas.saveLayer(Offset.zero & box, Paint());
  for (final stroke in layer.strokes) {
    paintDrawingStroke(
      canvas,
      box,
      stroke,
      stroke.tool == DrawingTool.pen
          ? (Paint()..color = stroke.color)
          : _clearPaint(),
    );
  }
  canvas.restore();
}

/// Desenha o trecho [src] de [image] em [dst] já com [layer] por cima, no
/// mesmo lugar em que ele ficaria se tivesse sido pintado na própria foto:
/// os traços acompanham o recorte (`src`), a escala e o que mais o canvas
/// já tiver de giro e espelho.
///
/// [colorFilter] vale para a imagem **e** para o desenho — o desenho faz
/// parte da foto, e o ajuste de cor dela também o alcança, como na prévia
/// (onde o `ColorFiltered` envolve os dois).
void paintDrawnImage(
  Canvas canvas,
  ui.Image image,
  Rect src,
  Rect dst,
  DrawingLayer layer, {
  ColorFilter? colorFilter,
  FilterQuality filterQuality = FilterQuality.high,
}) {
  final imagePaint = Paint()..filterQuality = filterQuality;
  if (layer.isEmpty || src.isEmpty || dst.isEmpty) {
    canvas.drawImageRect(
      image,
      src,
      dst,
      imagePaint..colorFilter = colorFilter,
    );
    return;
  }
  final imageBox = Size(image.width.toDouble(), image.height.toDouble());

  // Leva o canvas para pixels da imagem inteira, de modo que `src` caia
  // exatamente em `dst`; o recorte em `dst` esconde o que passa da janela.
  void inImageSpace(void Function() paint) {
    canvas.save();
    canvas.clipRect(dst);
    canvas.translate(dst.left, dst.top);
    canvas.scale(dst.width / src.width, dst.height / src.height);
    canvas.translate(-src.left, -src.top);
    paint();
    canvas.restore();
  }

  canvas.saveLayer(dst, Paint()..colorFilter = colorFilter);
  final cutout = layer.hasCutout;
  if (cutout) canvas.saveLayer(dst, Paint());
  canvas.drawImageRect(image, src, dst, imagePaint);
  if (cutout) {
    inImageSpace(() {
      for (final stroke in layer.strokes) {
        if (stroke.tool != DrawingTool.cutout) continue;
        paintDrawingStroke(canvas, imageBox, stroke, _clearPaint());
      }
    });
    canvas.restore();
  }
  inImageSpace(() => paintDrawingStrokes(canvas, imageBox, layer));
  canvas.restore();
}

/// [image] com [layer] gravado nela, no tamanho nativo — para quem trabalha
/// com a foto pronta (a exportação de Editar imagem e o "Ajustar", que mede
/// as bordas transparentes já com o que a transparência apagou).
Future<ui.Image> bakeDrawing(ui.Image image, DrawingLayer layer) async {
  final rect =
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble());
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paintDrawnImage(
    canvas,
    image,
    rect,
    rect,
    layer,
    // Pixel a pixel, sem reamostrar.
    filterQuality: FilterQuality.none,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(image.width, image.height);
  } finally {
    picture.dispose();
  }
}

/// Só a camada dos traços, esticada na caixa do widget — a prévia do SVG,
/// que não tem pixels de imagem para furar.
class DrawingStrokesPainter extends CustomPainter {
  const DrawingStrokesPainter(this.layer);

  final DrawingLayer layer;

  @override
  void paint(Canvas canvas, Size size) =>
      paintDrawingStrokes(canvas, size, layer);

  @override
  bool shouldRepaint(DrawingStrokesPainter oldDelegate) =>
      !identical(oldDelegate.layer, layer);
}

/// A imagem inteira com o desenho, esticada na caixa do widget.
class DrawnImagePainter extends CustomPainter {
  const DrawnImagePainter({required this.image, required this.layer});

  final ui.Image image;
  final DrawingLayer layer;

  @override
  void paint(Canvas canvas, Size size) => paintDrawnImage(
    canvas,
    image,
    Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
    Offset.zero & size,
    layer,
    filterQuality: FilterQuality.medium,
  );

  @override
  bool shouldRepaint(DrawnImagePainter oldDelegate) =>
      !identical(oldDelegate.image, image) ||
      !identical(oldDelegate.layer, layer);
}
