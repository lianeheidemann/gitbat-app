import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitbat/core/models/drawing_layer.dart';
import 'package:gitbat/core/painting/drawing_painting.dart';

// O Pincel tem uma tradução só de traço para pixel (`drawing_painting.dart`),
// usada pela prévia e pelas exportações. Estes testes conferem os pixels de
// verdade: o que cada ferramenta pinta, apaga ou fura, e em que ordem.

const _blue = Color(0xFF2050C0);
const _red = Color(0xFFFF0000);

Future<ui.Image> _solid(int width, int height, Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
}

Future<List<int>> _pixel(ui.Image image, int x, int y) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final i = (y * image.width + x) * 4;
  final bytes = data!.buffer.asUint8List();
  return [bytes[i], bytes[i + 1], bytes[i + 2], bytes[i + 3]];
}

/// Linha horizontal na altura [y] (normalizada), de ponta a ponta.
DrawingStroke _line(DrawingTool tool, double y, {double width = 0.1}) =>
    DrawingStroke(
      tool: tool,
      points: [Offset(0, y), Offset(1, y)],
      widthRatio: width,
      color: _red,
    );

void main() {
  group('modelo', () {
    test('o pincel gera traços normalizados com a cor e a opacidade', () {
      const brush = DrawingBrush(color: _red, opacity: 0.5, penPercent: 2);
      final stroke = brush.stroke(const [Offset(0.1, 0.2)]);
      expect(stroke.tool, DrawingTool.pen);
      expect(stroke.widthRatio, closeTo(0.02, 1e-9));
      expect(stroke.color.a, closeTo(0.5, 0.01));
      expect(stroke.widthIn(const Size(400, 200)), closeTo(4, 1e-9));
      expect(stroke.pointsIn(const Size(400, 200)), [const Offset(40, 40)]);

      // Cada ferramenta tem o próprio tamanho.
      final eraser = brush.copyWith(tool: DrawingTool.eraser);
      expect(eraser.sizePercent, brush.eraserPercent);
      expect(eraser.withSizePercent(9).eraserPercent, 9);
      expect(eraser.withSizePercent(9).penPercent, 2);
    });

    test('camada: somar, desfazer e as caixas do que foi pintado', () {
      var layer = DrawingLayer.empty;
      expect(layer.isEmpty, isTrue);
      expect(layer.paintBoundsIn(const Size(100, 100)), isNull);

      layer = layer.add(_line(DrawingTool.pen, 0.5));
      layer = layer.add(_line(DrawingTool.cutout, 0.2));
      expect(layer.hasPaint, isTrue);
      expect(layer.hasCutout, isTrue);
      // Só o pincel conta; a espessura (10) entra, e a caixa é cortada à
      // imagem.
      expect(
        layer.paintBoundsIn(const Size(100, 100)),
        const Rect.fromLTRB(0, 45, 100, 55),
      );
      expect(layer.removeLast().hasCutout, isFalse);
      expect(DrawingLayer.empty.removeLast().isEmpty, isTrue);
    });
  });

  group('pixels', () {
    late ui.Image photo;

    setUp(() async => photo = await _solid(100, 100, _blue));
    tearDown(() => photo.dispose());

    test('o pincel pinta por cima da foto', () async {
      final baked = await bakeDrawing(
        photo,
        DrawingLayer(strokes: [_line(DrawingTool.pen, 0.5)]),
      );
      expect(await _pixel(baked, 50, 50), [255, 0, 0, 255]);
      expect(await _pixel(baked, 50, 10), [0x20, 0x50, 0xC0, 255]);
      baked.dispose();
    });

    test('a borracha apaga o traço e deixa a foto intacta', () async {
      final baked = await bakeDrawing(
        photo,
        DrawingLayer(
          strokes: [
            _line(DrawingTool.pen, 0.5),
            _line(DrawingTool.eraser, 0.5, width: 0.3),
          ],
        ),
      );
      expect(await _pixel(baked, 50, 50), [0x20, 0x50, 0xC0, 255]);
      baked.dispose();
    });

    test('a transparência fura a foto', () async {
      final baked = await bakeDrawing(
        photo,
        DrawingLayer(strokes: [_line(DrawingTool.cutout, 0.5)]),
      );
      expect((await _pixel(baked, 50, 50))[3], 0);
      expect((await _pixel(baked, 50, 10))[3], 255);
      baked.dispose();
    });

    test('um traço depois da transparência continua à vista, e um antes '
        'some junto com a foto', () async {
      final after = await bakeDrawing(
        photo,
        DrawingLayer(
          strokes: [
            _line(DrawingTool.cutout, 0.5, width: 0.3),
            _line(DrawingTool.pen, 0.5),
          ],
        ),
      );
      expect(await _pixel(after, 50, 50), [255, 0, 0, 255]);
      // Fora do traço, ainda dentro do furo: transparente.
      expect((await _pixel(after, 50, 40))[3], 0);
      after.dispose();

      final before = await bakeDrawing(
        photo,
        DrawingLayer(
          strokes: [
            _line(DrawingTool.pen, 0.5),
            _line(DrawingTool.cutout, 0.5, width: 0.3),
          ],
        ),
      );
      expect((await _pixel(before, 50, 50))[3], 0);
      before.dispose();
    });

    test('o desenho acompanha o recorte e a escala de src → dst', () async {
      // Ponto pintado no canto de baixo à direita da foto (80,80); só a
      // metade de baixo à direita da foto é desenhada, ampliada 2x.
      final layer = DrawingLayer(
        strokes: [
          const DrawingStroke(
            tool: DrawingTool.pen,
            points: [Offset(0.8, 0.8)],
            widthRatio: 0.04,
            color: _red,
          ),
        ],
      );
      final recorder = ui.PictureRecorder();
      paintDrawnImage(
        Canvas(recorder),
        photo,
        const Rect.fromLTWH(50, 50, 50, 50),
        const Rect.fromLTWH(0, 0, 100, 100),
        layer,
      );
      final picture = recorder.endRecording();
      final out = await picture.toImage(100, 100);
      picture.dispose();
      // (80,80) da foto cai em ((80-50)*2, (80-50)*2) = (60,60).
      expect(await _pixel(out, 60, 60), [255, 0, 0, 255]);
      expect(await _pixel(out, 20, 20), [0x20, 0x50, 0xC0, 255]);
      out.dispose();
    });

    test('o ajuste de cor alcança a foto e o desenho', () async {
      const toGray = ColorFilter.mode(Color(0xFF808080), BlendMode.srcATop);
      final recorder = ui.PictureRecorder();
      final rect = const Rect.fromLTWH(0, 0, 100, 100);
      paintDrawnImage(
        Canvas(recorder),
        photo,
        rect,
        rect,
        DrawingLayer(strokes: [_line(DrawingTool.pen, 0.5)]),
        colorFilter: toGray,
      );
      final picture = recorder.endRecording();
      final out = await picture.toImage(100, 100);
      picture.dispose();
      expect(await _pixel(out, 50, 50), [128, 128, 128, 255]);
      expect(await _pixel(out, 50, 10), [128, 128, 128, 255]);
      out.dispose();
    });
  });
}
