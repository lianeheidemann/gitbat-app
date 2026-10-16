import '../../../app/editor_defaults.dart';
import '../../../app/language_controller.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/drawing_layer.dart';
import '../checkerboard_background.dart';
import '../dialog_title.dart';
import '../edit_history.dart';
import '../editor_app_bar_actions.dart';
import '../frame/frame_color_row.dart';
import 'drawing_canvas.dart';
import 'drawing_panel.dart';
import 'drawn_image.dart';

/// Tela cheia do Pincel para uma única foto — a do "..." de uma foto da
/// Montagem, no mesmo formato de "Recortar" (`PhotoCropPage`): abre com o
/// desenho que a foto já tem e devolve o novo via `Navigator.pop`, ou `null`
/// se a pessoa saiu sem usar.
///
/// A foto aparece inteira e na orientação dela, sem o enquadramento da
/// célula: o desenho fica preso à foto, então acompanha depois o zoom, o
/// giro, o espelho e o recorte que ela tiver na montagem.
class PhotoDrawPage extends StatefulWidget {
  const PhotoDrawPage({
    super.key,
    required this.photoPath,
    required this.photoWidth,
    required this.photoHeight,
    this.initialDrawing = DrawingLayer.empty,
    this.allowTransparency = true,
    this.colorFilter,
  });

  final String photoPath;
  final int photoWidth;
  final int photoHeight;
  final DrawingLayer initialDrawing;

  /// Oferece a ferramenta [DrawingTool.cutout] — só numa foto parada.
  final bool allowTransparency;

  /// O ajuste de cor da foto, que também alcança o desenho (ver
  /// `paintDrawnImage`) — aqui só para a prévia mostrar o que vai sair.
  final ColorFilter? colorFilter;

  @override
  State<PhotoDrawPage> createState() => _PhotoDrawPageState();
}

class _PhotoDrawPageState extends State<PhotoDrawPage> {
  late DrawingLayer _drawing = widget.initialDrawing;
  final _history = EditHistory<DrawingLayer>();
  DrawingBrush _brush = DrawingBrush(color: EditorDefaults.text);
  final _canvasKey = GlobalKey<DrawingCanvasState>();
  final _previewKey = GlobalKey();

  List<DrawingTool> get _tools => [
    DrawingTool.pen,
    DrawingTool.eraser,
    if (widget.allowTransparency) DrawingTool.cutout,
  ];

  bool get _changed => !identical(_drawing, widget.initialDrawing);

  void _apply(DrawingLayer next) {
    _history.push(_drawing);
    setState(() => _drawing = next);
  }

  void _undo() {
    final previous = _history.undo(_drawing);
    if (previous != null) setState(() => _drawing = previous);
  }

  void _redo() {
    final next = _history.redo(_drawing);
    if (next != null) setState(() => _drawing = next);
  }

  void _pickColor() => showFrameColorPicker(
    context: context,
    title: tr('Cor do pincel', 'Brush color'),
    selectedColor: _brush.color,
    onSelected: (color) =>
        setState(() => _brush = _brush.copyWith(color: color)),
    onFirstChange: () {},
    previewImageBuilder: () => renderPreviewImage(context, _previewKey),
  );

  /// Sair sem "Usar" descarta o desenho — pergunta antes, se algo mudou.
  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: DialogTitle(tr('Descartar desenho?', 'Discard drawing?')),
        content: Text(
          tr(
            'O que você desenhou agora não vai para a foto.',
            'What you drew now will not be applied to the photo.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('Descartar', 'Discard')),
          ),
        ],
      ),
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    final canvas = _canvasKey.currentState;
    return PopScope<DrawingLayer>(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Pincel', 'Brush')),
          actions: [
            ...undoRedoActions(
              canUndo: _history.canUndo,
              canRedo: _history.canRedo,
              onUndo: _undo,
              onRedo: _redo,
            ),
            TextButton(
              key: const ValueKey('photoDrawDone'),
              // O resultado sai direto por aqui, sem passar pela pergunta
              // de descartar do `PopScope`.
              onPressed: () => Navigator.of(context).pop(_drawing),
              child: Text(
                tr('Usar', 'Use'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PreviewAreaBackground(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: MediaCheckerboard(
                        child: RepaintBoundary(
                          key: _previewKey,
                          child: DrawingCanvas(
                            key: _canvasKey,
                            sourceWidth: widget.photoWidth.toDouble(),
                            sourceHeight: widget.photoHeight.toDouble(),
                            layer: _drawing,
                            brush: _brush,
                            onStroke: (stroke) => _apply(_drawing.add(stroke)),
                            onZoomChanged: (_) => setState(() {}),
                            contentBuilder: _content,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                constraints: const BoxConstraints(maxHeight: 260),
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: DrawingPanel(
                    brush: _brush,
                    onBrushChanged: (brush) => setState(() => _brush = brush),
                    tools: _tools,
                    sourceShortestSide: widget.photoWidth < widget.photoHeight
                        ? widget.photoWidth.toDouble()
                        : widget.photoHeight.toDouble(),
                    onPickColor: _pickColor,
                    onClear: _drawing.isEmpty
                        ? null
                        : () => _apply(DrawingLayer.empty),
                    onFitView: (canvas?.isZoomed ?? false)
                        ? canvas!.resetZoom
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(DrawingLayer layer) {
    Widget content = DrawnImage(
      image: FileImage(File(widget.photoPath)),
      layer: layer,
    );
    final filter = widget.colorFilter;
    if (filter != null) {
      content = ColorFiltered(colorFilter: filter, child: content);
    }
    return content;
  }
}
