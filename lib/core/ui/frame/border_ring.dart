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
        // Dentro de uma área rolável a altura (ou a largura) chega
        // infinita: a espessura sai da medida que for finita, e o tamanho
        // final é o do próprio conteúdo — antes o `Stack` tentava ocupar o
        // espaço todo, estourava com altura infinita e a prévia sumia.
        final reference = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0);
        final thickness = frame.thicknessFor(reference);
        return Stack(
          // As restrições de fora chegam iguais ao conteúdo: em espaço
          // fixo ele continua ocupando tudo, como antes.
          fit: StackFit.passthrough,
          children: [
            Padding(
              padding: EdgeInsets.all(thickness),
              child: ClipPath(
                clipper: _InnerClipper(frame: frame, thickness: thickness),
                child: child,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FrameRingPainter(
                    frame: frame,
                    thickness: thickness,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Recorte do conteúdo no retângulo arredondado de dentro — o raio sai do
/// tamanho final (o de fora), como na exportação.
class _InnerClipper extends CustomClipper<Path> {
  const _InnerClipper({required this.frame, required this.thickness});

  final FrameSettings frame;
  final double thickness;

  @override
  Path getClip(Size size) {
    final outerShortest = size.shortestSide + thickness * 2;
    final outerRadius = frame.cornerRadiusFor(outerShortest);
    final inner = (outerRadius - thickness).clamp(0.0, outerRadius);
    return Path()..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(inner)),
    );
  }

  @override
  bool shouldReclip(covariant _InnerClipper old) =>
      old.frame != frame || old.thickness != thickness;
}

/// [BorderRingPainter] com os raios calculados a partir do tamanho pintado.
class _FrameRingPainter extends CustomPainter {
  const _FrameRingPainter({required this.frame, required this.thickness});

  final FrameSettings frame;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final outerRadius = frame.cornerRadiusFor(size.shortestSide);
    BorderRingPainter(
      color: frame.color,
      thickness: thickness,
      outerRadius: outerRadius,
      innerRadius: (outerRadius - thickness).clamp(0.0, outerRadius),
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _FrameRingPainter old) =>
      old.frame != frame || old.thickness != thickness;
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
