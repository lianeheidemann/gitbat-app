import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/models/collage_text.dart';
import '../../../../core/ui/text_style_controls.dart';

/// Painel da aba "Texto": o campo de escrever (que também edita a caixa
/// trazida pelo lápis da barra de seleção) e, com uma caixa selecionada, cor,
/// fundo, opacidade e arredondamento dela.
///
/// O controller e o foco do campo são da tela, não deste widget: ela os cria
/// no `initState`, descarta no `dispose` e limpa o campo quando o desfazer,
/// o refazer ou a aba Stickers apagam a caixa que estava sendo editada.
///
/// As mudanças saem por [onReplaceText] em vez de montarem as configurações
/// aqui. A folha de cor sobrevive a vários rebuilds e aplica cada cor no
/// momento em que ela é escolhida — um retrato das configurações estaria
/// velho quando a segunda cor chegasse. Pelo mesmo motivo [findText] é uma
/// função, não um valor.
class CollageTextPanel extends StatelessWidget {
  const CollageTextPanel({
    super.key,
    required this.selectedText,
    required this.editingTextId,
    required this.textController,
    required this.textFocus,
    required this.findText,
    required this.onReplaceText,
    required this.onPushUndoCheckpoint,
    required this.onSubmit,
    required this.onCancelEdit,
    required this.previewImageBuilder,
  });

  /// Caixa de texto selecionada agora, ou `null` — os controles de estilo só
  /// aparecem com uma selecionada, porque mexem naquela caixa, não em todas.
  final CollageTextItem? selectedText;

  /// Id da caixa que o lápis trouxe para o campo, ou `null` ao criar uma nova.
  final String? editingTextId;

  final TextEditingController textController;
  final FocusNode textFocus;
  final CollageTextItem? Function(String id) findText;
  final void Function(String id, CollageTextItem item, {bool pushUndo})
  onReplaceText;
  final VoidCallback onPushUndoCheckpoint;
  final VoidCallback onSubmit;
  final VoidCallback onCancelEdit;

  /// Rasteriza a prévia atual para o conta-gotas da folha de cor.
  final Future<ui.Image> Function() previewImageBuilder;

  @override
  Widget build(BuildContext context) {
    final selected = selectedText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextComposerField(
          controller: textController,
          focusNode: textFocus,
          editing: editingTextId != null,
          onSubmit: onSubmit,
          onCancelEdit: onCancelEdit,
        ),
        // Os controles de estilo só fazem sentido com um texto selecionado —
        // eles mexem naquele texto, não em todos.
        if (selected != null)
          ...textStyleControls(
            context,
            item: selected,
            latest: () => findText(selected.id),
            onChangeStart: onPushUndoCheckpoint,
            onChanged: (item) => onReplaceText(item.id, item, pushUndo: false),
            onCommit: (item) => onReplaceText(item.id, item),
            previewImageBuilder: previewImageBuilder,
          ),
      ],
    );
  }
}
