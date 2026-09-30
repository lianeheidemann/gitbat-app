import '../../app/language_controller.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/collage_text.dart';
import '../services/imported_font_store.dart';
import 'app_message.dart';
import 'collage_overlay_view.dart';
import 'overlay_handles.dart';
import '../painting/overlay_painting.dart' show paintCollageTextBackground;
import 'font_picker_sheet.dart';
import 'text_style_controls.dart';
import '../../app/editor_defaults.dart';

/// Caixas de texto arrastáveis sobre uma prévia — mesma interação e mesmo
/// visual da aba "Texto" de `CollagePage` (arrastar/pinçar move e redimensiona,
/// alças de um dedo giram/redimensionam, um painel escreve/estiliza),
/// generalizada aqui para qualquer tela que só precise de texto (sem
/// stickers): "Editar imagem" e "Editar vídeo". [TextOverlayStack] entra na
/// pilha da prévia; [TextOverlayPanel] entra na aba/painel de baixo; as duas
/// compartilham estado efêmero (seleção, edição, campo de texto, fontes
/// importadas) através de um [TextOverlayController] comum, enquanto a
/// lista de [CollageTextItem] continua sendo dona de quem chama (mesmo
/// princípio de `FrameSettings.texts`/`ConversionSettings.frame.texts`, que
/// ficam vivos junto do resto do projeto enquanto o app roda).
class TextOverlayController extends ChangeNotifier {
  String? selectedId;
  String? editingId;
  final textController = TextEditingController();
  final textFocus = FocusNode();

  static const _fontStore = ImportedFontStore();
  List<ImportedFont> importedFonts = [];

  /// Gesto em andamento das alças de redimensionar/girar, guardado aqui
  /// para `TextOverlayStack` (um `StatelessWidget`) poder acumular entre
  /// quadros do arrasto sem precisar de `State` próprio.
  final handleDrag = OverlayHandleDrag();

  Future<void> loadFonts() async {
    final fonts = await _fontStore.loadAll();
    importedFonts = fonts;
    notifyListeners();
  }

  void select(String? id) {
    if (selectedId == id) return;
    selectedId = id;
    notifyListeners();
  }

  /// Tira a seleção quando o item selecionado some da lista (removido, ou a
  /// tela reiniciou o projeto) — mesma ideia de
  /// `CollagePage._dropSelectionIfGone`.
  void dropSelectionIfGone(List<CollageTextItem> texts) {
    final id = selectedId;
    if (id != null && texts.findText(id) == null) {
      selectedId = null;
      notifyListeners();
    }
  }

  void beginEdit(CollageTextItem item) {
    editingId = item.id;
    textController.text = item.text;
    textController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: item.text.length,
    );
    notifyListeners();
    textFocus.requestFocus();
  }

  void cancelEdit() {
    editingId = null;
    textController.clear();
    notifyListeners();
  }

  /// Fecha a edição em andamento sem mexer no campo de texto — usado depois
  /// que [TextOverlayPanel] já salvou o texto editado.
  void finishEdit() {
    editingId = null;
    notifyListeners();
  }

  void addImportedFont(ImportedFont font) {
    importedFonts = [...importedFonts, font];
    notifyListeners();
  }

  @override
  void dispose() {
    textController.dispose();
    textFocus.dispose();
    super.dispose();
  }
}

/// Caixa colorida atrás de um texto, desenhada por
/// [paintCollageTextBackground] — o mesmo desenho da exportação.
class TextOverlayBackgroundBox extends StatelessWidget {
  const TextOverlayBackgroundBox({
    super.key,
    required this.color,
    required this.cornerRatio,
    required this.padding,
    required this.child,
  });

  final Color color;
  final double cornerRatio;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BackgroundPainter(color: color, cornerRatio: cornerRatio),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  const _BackgroundPainter({required this.color, required this.cornerRatio});

  final Color color;
  final double cornerRatio;

  @override
  void paint(Canvas canvas, Size size) => paintCollageTextBackground(
    canvas,
    Offset.zero & size,
    color,
    cornerRatio,
  );

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.cornerRatio != cornerRatio;
}

/// Desenho de um texto sobreposto no tamanho do canvas dado — o mesmo
/// respiro e o mesmo arredondamento que a exportação pinta, então a prévia e
/// o arquivo final batem em qualquer tamanho de fonte.
///
/// Compartilhado entre a pilha desta biblioteca e a prévia da Montagem, que
/// desenha stickers e textos na mesma camada e por isso não usa
/// [TextOverlayStack].
Widget textOverlayArt(CollageTextItem item, Size canvasSize) {
  final fontSize = canvasSize.shortestSide * item.fontSizeRatio;
  final text = Text(
    item.text,
    textAlign: TextAlign.center,
    style: TextStyle(
      color: item.color,
      fontSize: fontSize,
      fontFamily: item.fontFamily,
      fontWeight: item.bold ? FontWeight.w700 : FontWeight.w400,
    ),
  );
  final background = item.backgroundColor;
  if (background == null) return text;
  final (padH, padV) = CollageTextItem.backgroundPaddingFor(fontSize);
  return TextOverlayBackgroundBox(
    color: background,
    cornerRatio: item.backgroundCornerRatio,
    padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
    child: text,
  );
}

/// Tamanho natural (escala 1) de um texto sobreposto, já com o respiro do
/// fundo quando ele existe. Calculado analiticamente, sem medir em tempo de
/// execução — é o que posiciona as alças de redimensionar/girar.
Size textOverlayNaturalSize(CollageTextItem item, Size canvasSize) {
  final fontSize = canvasSize.shortestSide * item.fontSizeRatio;
  final painter = TextPainter(
    text: TextSpan(
      text: item.text,
      style: TextStyle(
        fontSize: fontSize,
        fontFamily: item.fontFamily,
        fontWeight: item.bold ? FontWeight.w700 : FontWeight.w400,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout();
  final size = Size(painter.width, painter.height);
  painter.dispose();
  if (item.backgroundColor == null) return size;
  final (padH, padV) = CollageTextItem.backgroundPaddingFor(fontSize);
  return Size(size.width + padH * 2, size.height + padV * 2);
}

/// A pilha de textos arrastáveis + as alças do item selecionado — entra por
/// cima da prévia já composta (dentro de um `Stack`/`LayoutBuilder` do
/// tamanho exato do canvas final), do mesmo jeito que `CropOverlay` entra
/// por cima da prévia na aba "Recorte".
class TextOverlayStack extends StatelessWidget {
  const TextOverlayStack({
    super.key,
    required this.controller,
    required this.texts,
    required this.onChanged,
    required this.canvasSize,
    required this.interactive,
    this.onGestureStart,
  });

  final TextOverlayController controller;
  final List<CollageTextItem> texts;
  final ValueChanged<List<CollageTextItem>> onChanged;
  final Size canvasSize;

  /// Só responde a toque/arrasto/pinça com a aba "Texto" aberta — mesma
  /// regra de `CollageOverlayView.interactive`.
  final bool interactive;
  final VoidCallback? onGestureStart;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final sorted = [...texts]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
        return Stack(
          children: [
            for (final item in sorted) _overlayWidget(item),
            if (interactive) ..._selectedHandles(),
          ],
        );
      },
    );
  }

  Widget _overlayWidget(CollageTextItem item) {
    return CollageOverlayView(
      key: ValueKey(item.id),
      centerX: item.centerX,
      centerY: item.centerY,
      scale: item.scale,
      rotation: item.rotation,
      minScale: CollageTextItem.minScale,
      maxScale: CollageTextItem.maxScale,
      canvasSize: canvasSize,
      selected: interactive && controller.selectedId == item.id,
      interactive: interactive,
      onSelect: () => controller.select(item.id),
      onGestureStart: onGestureStart,
      onTransformChanged: (cx, cy, scale, rotation) => onChanged(
        texts.replacingText(
          item.id,
          item.copyWith(
            centerX: cx,
            centerY: cy,
            scale: scale,
            rotation: rotation,
          ),
        ),
      ),
      child: textOverlayArt(item, canvasSize),
    );
  }

  List<Widget> _selectedHandles() {
    final id = controller.selectedId;
    if (id == null) return const [];
    final item = texts.findText(id);
    if (item == null) return const [];

    final points = overlayHandlePoints(
      centerX: item.centerX,
      centerY: item.centerY,
      naturalSize: textOverlayNaturalSize(item, canvasSize),
      scale: item.scale,
      rotation: item.rotation,
      canvasSize: canvasSize,
    );
    final drag = controller.handleDrag;

    void apply(double scale, double rotation) => onChanged(
      texts.replacingText(
        id,
        item.copyWith(
          centerX: item.centerX,
          centerY: item.centerY,
          scale: scale,
          rotation: rotation,
        ),
      ),
    );

    return [
      OverlayHandle(
        center: points.bottomRight,
        icon: Icons.open_in_full_rounded,
        iconSize: 12,
        onPointerDown: (_) => drag.startResize(),
        onPointerMove: (event) {
          final scale = drag.resize(
            event,
            scale: item.scale,
            rotation: item.rotation,
            minScale: CollageTextItem.minScale,
            maxScale: CollageTextItem.maxScale,
            canvasSize: canvasSize,
            onFirstChange: onGestureStart,
          );
          if (scale != null) apply(scale, item.rotation);
        },
      ),
      OverlayHandle(
        center: points.topRight,
        icon: Icons.rotate_right_rounded,
        iconSize: 14,
        onPointerDown: (_) => drag.startRotate(points.topRight),
        onPointerMove: (event) {
          final rotation = drag.rotate(
            event,
            center: points.center,
            rotation: item.rotation,
            onFirstChange: onGestureStart,
          );
          if (rotation != null) apply(item.scale, rotation);
        },
      ),
    ];
  }
}

/// Painel de baixo: campo de escrever texto + (com um texto selecionado)
/// barra de ações e controles de cor/fundo — mesmo conteúdo da aba "Texto"
/// de `CollagePage`, sem a parte de layout/stickers que não existe aqui.
class TextOverlayPanel extends StatelessWidget {
  const TextOverlayPanel({
    super.key,
    required this.controller,
    required this.texts,
    required this.onChanged,
    required this.previewImageBuilder,
    this.onGestureStart,
  });

  final TextOverlayController controller;
  final List<CollageTextItem> texts;
  final ValueChanged<List<CollageTextItem>> onChanged;
  final Future<ui.Image> Function() previewImageBuilder;

  /// Chamado antes da primeira mudança de um gesto contínuo (slider, roda de
  /// cor) — a tela dona decide o que fazer (normalmente empilhar um
  /// checkpoint de desfazer), mesmo papel de `CollagePage._pushUndoCheckpoint`.
  final VoidCallback? onGestureStart;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final selected = controller.selectedId == null
            ? null
            : texts.findText(controller.selectedId!);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selected != null) _selectionToolbar(context, selected),
            TextComposerField(
              controller: controller.textController,
              focusNode: controller.textFocus,
              editing: controller.editingId != null,
              onSubmit: _submit,
              onCancelEdit: controller.cancelEdit,
            ),
            if (selected != null)
              ...textStyleControls(
                context,
                item: selected,
                latest: () {
                  final id = controller.selectedId;
                  return id == null ? null : texts.findText(id);
                },
                onChangeStart: () => onGestureStart?.call(),
                onChanged: (item) =>
                    onChanged(texts.replacingText(item.id, item)),
                onCommit: (item) {
                  onGestureStart?.call();
                  onChanged(texts.replacingText(item.id, item));
                },
                previewImageBuilder: previewImageBuilder,
              ),
          ],
        );
      },
    );
  }

  Widget _selectionToolbar(BuildContext context, CollageTextItem selected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: tr('Editar', 'Edit'),
            onPressed: () => controller.beginEdit(selected),
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
          IconButton(
            tooltip: tr('Fonte', 'Font'),
            onPressed: () => _pickFont(context, selected),
            icon: const Icon(Icons.font_download_outlined, size: 20),
          ),
          IconButton(
            tooltip: tr('Duplicar', 'Duplicate'),
            onPressed: () => _duplicate(selected),
            icon: const Icon(Icons.copy_outlined, size: 20),
          ),
          IconButton(
            tooltip: tr('Frente', 'Front'),
            onPressed: () => _bringToFront(selected),
            icon: const Icon(Icons.flip_to_front_outlined, size: 20),
          ),
          IconButton(
            tooltip: tr('Trás', 'Back'),
            onPressed: () => _sendToBack(selected),
            icon: const Icon(Icons.flip_to_back_outlined, size: 20),
          ),
          IconButton(
            tooltip: tr('Remover', 'Remove'),
            onPressed: () => _remove(selected),
            icon: const Icon(Icons.delete_outline, size: 20),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final text = controller.textController.text.trim();
    if (text.isEmpty) return;
    final editingId = controller.editingId;
    onGestureStart?.call();
    if (editingId != null) {
      final item = texts.findText(editingId);
      if (item != null) {
        onChanged(texts.replacingText(editingId, item.copyWith(text: text)));
      }
      controller.finishEdit();
    } else {
      final item = CollageTextItem(
        id: 't_${DateTime.now().microsecondsSinceEpoch}',
        text: text,
        color: EditorDefaults.text,
        centerX: 0.5,
        centerY: 0.5,
        zIndex: texts.nextTextZIndex,
      );
      onChanged([...texts, item]);
      controller.select(item.id);
    }
    controller.textController.clear();
    controller.textFocus.requestFocus();
  }

  void _pickFont(BuildContext context, CollageTextItem item) {
    showFontPickerSheet(
      context,
      selectedFamily: item.fontFamily,
      importedFonts: controller.importedFonts,
      onSelected: (family) => _applyFont(item.id, family),
      onImport: () => _importFont(context, item.id),
    );
  }

  void _applyFont(String id, String? family) {
    final item = texts.findText(id);
    if (item == null) return;
    onGestureStart?.call();
    onChanged(
      texts.replacingText(
        id,
        item.copyWith(fontFamily: family, clearFontFamily: family == null),
      ),
    );
  }

  Future<void> _importFont(BuildContext context, String textId) async {
    try {
      final font = await const ImportedFontStore().import();
      controller.addImportedFont(font);
      _applyFont(textId, font.family);
    } on ImportedFontException catch (e) {
      if (!context.mounted) return;
      showAppMessage(context, e.message);
    }
  }

  void _duplicate(CollageTextItem item) {
    onGestureStart?.call();
    final newItem = CollageTextItem(
      id: 't_${DateTime.now().microsecondsSinceEpoch}',
      text: item.text,
      color: item.color,
      backgroundColor: item.backgroundColor,
      backgroundCornerRatio: item.backgroundCornerRatio,
      fontSizeRatio: item.fontSizeRatio,
      bold: item.bold,
      centerX: (item.centerX + 0.05).clamp(0.0, 1.0),
      centerY: (item.centerY + 0.05).clamp(0.0, 1.0),
      scale: item.scale,
      rotation: item.rotation,
      zIndex: texts.nextTextZIndex,
      fontFamily: item.fontFamily,
    );
    onChanged([...texts, newItem]);
    controller.select(newItem.id);
  }

  void _bringToFront(CollageTextItem item) {
    onGestureStart?.call();
    onChanged(
      texts.replacingText(item.id, item.copyWith(zIndex: texts.nextTextZIndex)),
    );
  }

  void _sendToBack(CollageTextItem item) {
    onGestureStart?.call();
    onChanged(
      texts.replacingText(item.id, item.copyWith(zIndex: texts.minTextZIndex)),
    );
  }

  void _remove(CollageTextItem item) {
    onGestureStart?.call();
    onChanged(texts.removingText(item.id));
    controller.select(null);
  }
}
