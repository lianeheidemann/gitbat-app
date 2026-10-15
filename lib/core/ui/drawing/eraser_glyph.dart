import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ícone de borracha (de apagar lápis), no traço arredondado dos ícones
/// Material — o pacote de ícones do Flutter não traz o `ink_eraser` dos
/// Material Symbols, e nenhum dos que vêm nele diz "borracha" (a vassoura
/// de `cleaning_services` lia como "limpar tudo").
///
/// Uma borracha deitada a 45°, com a ponta que apaga preenchida e o corpo
/// só em contorno, e a linha do papel por baixo.
class EraserGlyph extends StatelessWidget {
  const EraserGlyph({super.key, required this.color, this.size = 24});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _EraserGlyphPainter(color)),
  );
}

class _EraserGlyphPainter extends CustomPainter {
  const _EraserGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Desenhado numa grade de 24, como os ícones Material.
    final unit = size.shortestSide / 24;
    canvas.scale(unit);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final fill = Paint()
      ..color = color
      ..isAntiAlias = true;

    // A linha do papel.
    canvas.drawLine(const Offset(9, 21), const Offset(20, 21), stroke);

    canvas.save();
    canvas.translate(12.5, 10.5);
    canvas.rotate(-math.pi / 4);
    const body = Rect.fromLTWH(-8, -4, 16, 8);
    final rounded = RRect.fromRectAndRadius(body, const Radius.circular(2.5));
    // A ponta que apaga, à esquerda (embaixo, depois do giro), cheia — o
    // canto dela fica logo acima do começo da linha do papel.
    canvas.save();
    canvas.clipRRect(rounded);
    canvas.drawRect(const Rect.fromLTWH(-8, -4, 6, 8), fill);
    canvas.restore();
    canvas.drawRRect(rounded.deflate(1), stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EraserGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}
