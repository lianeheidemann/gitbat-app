import 'package:flutter/material.dart';

import '../../models/drawing_layer.dart';
import 'zoomable_draw_surface.dart';

/// A prévia da aba "Pincel": a imagem inteira (sem recorte nem giro, como na
/// Borracha mágica), o desenho por cima e os gestos — um dedo desenha com
/// [brush], dois dão zoom.
///
/// Quem desenha a imagem é [contentBuilder], que recebe o desenho já com o
/// traço em andamento: `DrawnImage` numa foto (a transparência fura a imagem
/// ao vivo), `DrawingOverlay` por cima do `SvgPicture` num SVG.
class DrawingCanvas extends StatefulWidget {
  const DrawingCanvas({
    super.key,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.layer,
    required this.brush,
    required this.onStroke,
    required this.contentBuilder,
    this.enabled = true,
    this.onZoomChanged,
    this.zoom,
  });

  /// Tamanho da imagem de origem (pixels da foto, ou o tamanho de exibição
  /// do SVG). Os traços saem normalizados a ele.
  final double sourceWidth;
  final double sourceHeight;

  /// O desenho já confirmado.
  final DrawingLayer layer;

  final DrawingBrush brush;

  /// Um traço terminado. Quem chama guarda — em geral `layer.add(stroke)`
  /// como um passo de desfazer.
  final ValueChanged<DrawingStroke> onStroke;

  final Widget Function(DrawingLayer previewLayer) contentBuilder;

  final bool enabled;

  /// Ver [ZoomableDrawSurface.onZoomChanged].
  final ValueChanged<bool>? onZoomChanged;

  /// Ver [ZoomableDrawSurface.zoom].
  final DrawZoomController? zoom;

  @override
  State<DrawingCanvas> createState() => DrawingCanvasState();
}

class DrawingCanvasState extends State<DrawingCanvas> {
  final _surface = GlobalKey<ZoomableDrawSurfaceState>();

  bool get isZoomed => _surface.currentState?.isZoomed ?? false;

  void resetZoom() => _surface.currentState?.resetZoom();

  DrawingStroke _strokeFrom(List<Offset> points) => widget.brush.stroke([
    for (final p in points)
      Offset(p.dx / widget.sourceWidth, p.dy / widget.sourceHeight),
  ]);

  @override
  Widget build(BuildContext context) {
    return ZoomableDrawSurface(
      key: _surface,
      sourceWidth: widget.sourceWidth,
      sourceHeight: widget.sourceHeight,
      enabled: widget.enabled,
      onZoomChanged: widget.onZoomChanged,
      zoom: widget.zoom,
      onStrokeEnd: (points) => widget.onStroke(_strokeFrom(points)),
      builder: (context, drawing, _) => widget.contentBuilder(
        drawing == null || drawing.isEmpty
            ? widget.layer
            : widget.layer.add(_strokeFrom(drawing)),
      ),
    );
  }
}
