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
            brightness: scheme.brightness,
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
    required this.brightness,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Brightness brightness;

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
    final dark = brightness == Brightness.dark;
    _paintLayer(
      canvas,
      color: tertiary.withValues(alpha: dark ? 0.28 : 0.16),
      edgeWidth: 225,
      edgeHeight: 184,
      firstControl: const Offset(188, 30),
      secondControl: const Offset(168, 96),
      curveEnd: const Offset(88, 145),
      returnControl: const Offset(42, 173),
    );
    _paintLayer(
      canvas,
      color: primary.withValues(alpha: dark ? 0.25 : 0.14),
      edgeWidth: 177,
      edgeHeight: 140,
      firstControl: const Offset(150, 32),
      secondControl: const Offset(125, 80),
      curveEnd: const Offset(65, 113),
      returnControl: const Offset(32, 132),
    );
    _paintLayer(
      canvas,
      color: secondary.withValues(alpha: dark ? 0.22 : 0.12),
      edgeWidth: 122,
      edgeHeight: 100,
      firstControl: const Offset(106, 25),
      secondControl: const Offset(78, 63),
      curveEnd: const Offset(39, 84),
      returnControl: const Offset(19, 96),
    );
    _paintLayer(
      canvas,
      color: Color.lerp(
        primary,
        secondary,
        0.5,
      )!.withValues(alpha: dark ? 0.20 : 0.10),
      edgeWidth: 66,
      edgeHeight: 62,
      firstControl: const Offset(58, 14),
      secondControl: const Offset(43, 37),
      curveEnd: const Offset(22, 51),
      returnControl: const Offset(10, 59),
    );
  }

  void _paintLayer(
    Canvas canvas, {
    required Color color,
    required double edgeWidth,
    required double edgeHeight,
    required Offset firstControl,
    required Offset secondControl,
    required Offset curveEnd,
    required Offset returnControl,
  }) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(edgeWidth, 0)
      ..cubicTo(
        firstControl.dx,
        firstControl.dy,
        secondControl.dx,
        secondControl.dy,
        curveEnd.dx,
        curveEnd.dy,
      )
      ..quadraticBezierTo(
        returnControl.dx,
        returnControl.dy,
        0,
        edgeHeight,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PaletteCornerPainter oldDelegate) =>
      primary != oldDelegate.primary ||
      secondary != oldDelegate.secondary ||
      tertiary != oldDelegate.tertiary ||
      brightness != oldDelegate.brightness;
}
