import '../../app/language_controller.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/collage_text.dart';
import 'color_picker_sheet.dart';
import 'panel_rows.dart';
import '../../app/editor_defaults.dart';

/// Campo de escrever texto do painel da aba "Texto": o botão da ponta cria a
/// caixa, ou confirma a edição quando o lápis carregou uma aqui ([editing]).
/// Escrever direto no painel evita a janela que existia só para digitar uma
/// frase. O mesmo campo na Montagem e nos outros editores.
class TextComposerField extends StatelessWidget {
  const TextComposerField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.editing,
    required this.onSubmit,
    required this.onCancelEdit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// Com uma caixa trazida pelo lápis: aparece "Editar texto / Cancelar" e o
  /// botão da ponta salva em vez de adicionar.
  final bool editing;

  final VoidCallback onSubmit;
  final VoidCallback onCancelEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (editing) ...[
          Row(
            children: [
              Text(
                tr('Editar texto', 'Edit text'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onCancelEdit,
                child: Text(tr('Cancelar', 'Cancel')),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final canSubmit = value.text.trim().isNotEmpty;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              // Até 3 linhas, o mesmo que o diálogo antigo aceitava — com
              // `TextInputType.multiline` o Enter quebra linha e quem
              // confirma é o botão da ponta.
              maxLines: 3,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                hintText: tr('Digite seu texto...', 'Type your text...'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                contentPadding: const EdgeInsets.fromLTRB(18, 12, 4, 12),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: IconButton(
                    tooltip: editing
                        ? tr('Salvar texto', 'Save text')
                        : tr('Adicionar texto', 'Add text'),
                    onPressed: canSubmit ? onSubmit : null,
                    icon: Icon(
                      editing ? Icons.check_rounded : Icons.add_rounded,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: canSubmit
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      foregroundColor: canSubmit
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Os controles de estilo da caixa de texto selecionada — cor, tamanho e
/// "Fundo do texto" (cor, opacidade e arredondamento) —, como filhos da
/// `Column` do painel. Os mesmos na Montagem e nos outros editores.
///
/// As mudanças saem por dois caminhos, porque cada tela empilha o desfazer
/// do seu jeito: [onChangeStart] + [onChanged] nos gestos contínuos
/// (sliders e cada cor da folha), [onCommit] ao ligar/desligar o fundo.
///
/// A folha de cor sobrevive a vários rebuilds e aplica cada cor no momento
/// em que ela é escolhida — um retrato do item estaria velho quando a
/// segunda cor chegasse. Por isso [latest] é uma função: devolve a versão
/// atual do item (ou `null` se ele sumiu).
List<Widget> textStyleControls(
  BuildContext context, {
  required CollageTextItem item,
  required CollageTextItem? Function() latest,
  required VoidCallback onChangeStart,
  required ValueChanged<CollageTextItem> onChanged,
  required ValueChanged<CollageTextItem> onCommit,
  required Future<ui.Image> Function() previewImageBuilder,
}) {
  void pickColor({
    required String title,
    required Color initialColor,
    required CollageTextItem Function(CollageTextItem item, Color color) apply,
  }) {
    var checkpointPushed = false;
    showCollageColorPickerSheet(
      context: context,
      title: title,
      initialColor: initialColor,
      onColorSelected: (color) {
        final current = latest();
        if (current == null) return;
        if (!checkpointPushed) {
          checkpointPushed = true;
          onChangeStart();
        }
        onChanged(apply(current, color));
      },
      previewImageBuilder: previewImageBuilder,
    );
  }

  return [
    const SizedBox(height: 8),
    PanelColorRow(
      label: tr('Cor do texto', 'Text color'),
      color: item.color,
      onTap: () => pickColor(
        title: tr('Cor do texto', 'Text color'),
        initialColor: item.color,
        apply: (item, color) => item.copyWith(color: color),
      ),
    ),
    TextFontSizeRow(
      item: item,
      onChangeStart: onChangeStart,
      onChanged: (points) => onChanged(item.withFontSizePoints(points)),
    ),
    PanelSwitchRow(
      label: tr('Fundo do texto', 'Text background'),
      value: item.hasBackground,
      onChanged: (on) => onCommit(
        on
            ? item.copyWith(
                backgroundColor:
                    item.backgroundColor ?? EditorDefaults.background,
              )
            : item.copyWith(clearBackgroundColor: true),
      ),
    ),
    if (item.hasBackground) ...[
      const SizedBox(height: 4),
      _backgroundGroup(
        context,
        item: item,
        onPickColor: () => pickColor(
          title: tr('Cor do fundo do texto', 'Text background color'),
          initialColor: item.backgroundColor ?? EditorDefaults.background,
          apply: (item, color) => item.copyWith(backgroundColor: color),
        ),
        onChangeStart: onChangeStart,
        onChanged: onChanged,
      ),
    ],
  ];
}

/// Cor/opacidade/arredondamento do fundo do texto, agrupados numa caixa com
/// destaque à esquerda — deixa claro que os três são sub-opções de "Fundo do
/// texto" logo acima, então os rótulos aqui dentro não repetem "do fundo" (a
/// folha de cor, mais longe desse contexto, continua dizendo "Cor do fundo
/// do texto").
Widget _backgroundGroup(
  BuildContext context, {
  required CollageTextItem item,
  required VoidCallback onPickColor,
  required VoidCallback onChangeStart,
  required ValueChanged<CollageTextItem> onChanged,
}) {
  final theme = Theme.of(context);
  final background = item.backgroundColor!;
  return Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(10),
      border: Border(
        left: BorderSide(color: theme.colorScheme.primary, width: 3),
      ),
    ),
    child: Column(
      children: [
        PanelColorRow(
          label: tr('Cor', 'Color'),
          color: background,
          onTap: onPickColor,
        ),
        const SizedBox(height: 4),
        PanelSliderRow(
          onChangeStart: onChangeStart,
          label: tr('Opacidade', 'Opacity'),
          value: background.a,
          min: 0,
          max: 1,
          valueLabel: '${(background.a * 100).round()}%',
          onChanged: (v) => onChanged(
            item.copyWith(backgroundColor: background.withValues(alpha: v)),
          ),
        ),
        const SizedBox(height: 4),
        PanelSliderRow(
          onChangeStart: onChangeStart,
          label: tr('Arredondamento', 'Rounding'),
          value: item.backgroundCornerRatio,
          min: 0,
          max: CollageTextItem.maxBackgroundCornerRatio,
          valueLabel:
              '${(item.backgroundCornerRatio / CollageTextItem.maxBackgroundCornerRatio * 100).round()}%',
          onChanged: (v) => onChanged(item.copyWith(backgroundCornerRatio: v)),
        ),
      ],
    ),
  );
}
