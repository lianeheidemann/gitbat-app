import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Faixas decorativas que emolduram a tela inicial sem disputar atenção com
/// o conteúdo. As cores vêm do [ColorScheme], portanto acompanham tanto a
/// paleta quanto o modo claro/escuro escolhidos no app.
class PaletteCornerDecoration extends StatelessWidget {
  const PaletteCornerDecoration({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: CustomPaint(
          key: const ValueKey('paletteCornerDecoration'),
          painter: _PaletteCornerPainter(
            primary: scheme.primary,
            secondary: scheme.secondary,
            tertiary: scheme.tertiary,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _PaletteCornerPainter extends CustomPainter {
  const _PaletteCornerPainter({
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;

  @override
  void paint(Canvas canvas, Size size) {
    _paintCorner(canvas);
    canvas.save();
    canvas.translate(size.width, size.height);
    canvas.rotate(math.pi);
    _paintCorner(canvas);
    canvas.restore();
  }

  void _paintCorner(Canvas canvas) {
    _paintLayer(canvas, 190, 155, tertiary.withValues(alpha: 0.10));
    _paintLayer(canvas, 150, 122, primary.withValues(alpha: 0.12));
    _paintLayer(canvas, 108, 88, secondary.withValues(alpha: 0.14));
  }

  void _paintLayer(Canvas canvas, double width, double height, Color color) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(width, 0)
      ..cubicTo(
        width * 0.83,
        height * 0.28,
        width * 0.48,
        height * 0.78,
        0,
        height,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PaletteCornerPainter oldDelegate) =>
      primary != oldDelegate.primary ||
      secondary != oldDelegate.secondary ||
      tertiary != oldDelegate.tertiary;
}
