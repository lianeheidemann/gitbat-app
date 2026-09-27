import 'package:flutter/material.dart';

import '../../models/frame_settings.dart';

/// Borda procedural (aba "Borda") em volta de [child] na prévia: só o anel
/// na cor da borda — o miolo não é pintado, então partes transparentes do
/// conteúdo continuam transparentes — e o conteúdo recortado no retângulo
/// arredondado de dentro. Mesma geometria da exportação (`FrameGeometry`/
/// `paintFrame` na foto, `applyBorderSvg` no SVG). Sem borda, devolve
/// [child] como está.
class BorderedPreview extends StatelessWidget {
  const BorderedPreview({super.key, required this.frame, required this.child});

  final FrameSettings frame;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (frame.style == FrameStyle.none) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final thickness = frame.thicknessFor(width);
        final outerRadius = frame.cornerRadiusFor(
          constraints.biggest.shortestSide,
        );
        final innerRadius = (outerRadius - thickness).clamp(0.0, outerRadius);
        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: CustomPaint(
                painter: BorderRingPainter(
                  color: frame.color,
                  thickness: thickness,
                  outerRadius: outerRadius,
                  innerRadius: innerRadius,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(thickness),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(innerRadius),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Anel da borda: o retângulo arredondado de fora menos o de dentro.
class BorderRingPainter extends CustomPainter {
  const BorderRingPainter({
    required this.color,
    required this.thickness,
    required this.outerRadius,
    required this.innerRadius,
  });

  final Color color;
  final double thickness;
  final double outerRadius;
  final double innerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(outerRadius),
    );
    final inner = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(thickness),
      Radius.circular(innerRadius),
    );
    canvas.drawDRRect(outer, inner, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant BorderRingPainter old) =>
      old.color != color ||
      old.thickness != thickness ||
      old.outerRadius != outerRadius ||
      old.innerRadius != innerRadius;
}
