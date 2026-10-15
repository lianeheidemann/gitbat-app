import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/ui/drawing/zoomable_draw_surface.dart';
import '../models/eraser_mask.dart';

/// A prévia da aba "Borracha": a foto, o véu da seleção por cima, e os
/// gestos que desenham e dão zoom — estes da [ZoomableDrawSurface], a mesma
/// superfície do Pincel (um dedo desenha, dois dão zoom).
class EraserCanvas extends StatefulWidget {
  const EraserCanvas({
    super.key,
    required this.photoWidth,
    required this.photoHeight,
    required this.mask,
    required this.tool,
    required this.brushRadius,
    required this.onMaskChanged,
    required this.child,
    this.enabled = true,
    this.onZoomChanged,
    this.zoom,
  });

  final int photoWidth;
  final int photoHeight;

  /// A seleção já confirmada. O traço em andamento fica no estado da
  /// superfície e só entra aqui quando o dedo sai da tela — assim cada traço
  /// vira exatamente um passo de desfazer.
  final EraserMask mask;

  final EraserTool tool;

  /// Raio do pincel em **pixels da foto**, não da tela: assim a pincelada
  /// cobre a mesma área independentemente do zoom.
  final double brushRadius;

  final ValueChanged<EraserMask> onMaskChanged;

  /// A foto, desenhada no tamanho da caixa.
  final Widget child;

  final bool enabled;

  /// Avisa quando a prévia passa de enquadrada para ampliada e vice-versa
  /// (ver [ZoomableDrawSurface.onZoomChanged]).
  final ValueChanged<bool>? onZoomChanged;

  /// Ver [ZoomableDrawSurface.zoom] — o mesmo enquadramento do Pincel.
  final DrawZoomController? zoom;

  @override
  State<EraserCanvas> createState() => EraserCanvasState();
}

class EraserCanvasState extends State<EraserCanvas> {
  final _surface = GlobalKey<ZoomableDrawSurfaceState>();

  /// `true` quando a prévia está ampliada — a tela usa isso para mostrar o
  /// botão de voltar ao enquadramento.
  bool get isZoomed => _surface.currentState?.isZoomed ?? false;

  void resetZoom() => _surface.currentState?.resetZoom();

  /// Converte os pontos crus do gesto no traço definitivo, conforme a
  /// ferramenta: o retângulo só guarda os quatro cantos da caixa arrastada; o
  /// laço fecha o contorno; o pincel mantém a linha com espessura.
  EraserStroke _strokeFrom(List<Offset> points) {
    switch (widget.tool) {
      case EraserTool.rectangle:
        final first = points.first;
        final last = points.last;
        final rect = Rect.fromPoints(first, last);
        return EraserStroke(
          points: [
            rect.topLeft,
            rect.topRight,
            rect.bottomRight,
            rect.bottomLeft,
          ],
          closed: true,
        );
      case EraserTool.lasso:
        return EraserStroke(points: points, closed: true);
      case EraserTool.brush:
      case EraserTool.unbrush:
        return EraserStroke(
          points: points,
          radius: widget.brushRadius,
          subtract: widget.tool.subtracts,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ZoomableDrawSurface(
      key: _surface,
      sourceWidth: widget.photoWidth.toDouble(),
      sourceHeight: widget.photoHeight.toDouble(),
      enabled: widget.enabled,
      onZoomChanged: widget.onZoomChanged,
      zoom: widget.zoom,
      onStrokeEnd: (points) =>
          widget.onMaskChanged(widget.mask.add(_strokeFrom(points))),
      builder: (context, drawing, scale) => Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          CustomPaint(
            painter: _MaskPainter(
              // A seleção confirmada mais o traço em andamento.
              mask: drawing == null || drawing.isEmpty
                  ? widget.mask
                  : widget.mask.add(_strokeFrom(drawing)),
              scale: scale,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Desenha o véu da seleção. A pintura em si sai de [paintEraserMask], a
/// mesma função que a rasterização usa — se as duas divergissem, a pessoa
/// marcaria uma coisa e apagaria outra.
class _MaskPainter extends CustomPainter {
  const _MaskPainter({
    required this.mask,
    required this.scale,
    required this.color,
  });

  final EraserMask mask;
  final double scale;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (mask.strokes.isEmpty) return;
    // Uma camada própria: o "apagar seleção" usa `BlendMode.clear`, que
    // precisa de algo para limpar.
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.scale(scale);
    paintEraserMask(
      canvas,
      mask,
      addColor: color.withValues(alpha: 0.45),
      subtractColor: const Color(0x00000000),
      subtractBlendMode: BlendMode.clear,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MaskPainter old) =>
      old.mask != mask || old.scale != scale || old.color != color;
}

/// Ponto de referência para o slider de pincel: um raio em pixels da foto,
/// derivado de uma fração do menor lado. Assim o mesmo "tamanho 30" cobre a
/// mesma proporção numa foto de 1 MP e numa de 12 MP — um raio fixo em
/// pixels seria um respingo numa e um borrão na outra.
double brushRadiusFor(double percent, int photoWidth, int photoHeight) {
  final shortest = math.min(photoWidth, photoHeight);
  return (shortest * percent / 100).clamp(1.0, shortest.toDouble());
}
