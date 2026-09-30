import '../../../app/language_controller.dart';
import 'package:flutter/material.dart';

import '../../models/frame_settings.dart';
import '../../models/image_frame.dart';
import '../collapsible_subsection.dart';
import '../panel_rows.dart';
import 'content_fit_picker.dart';
import 'frame_rotate_button.dart';
import 'frame_thumb_shell.dart';
import 'image_frame_picker.dart';

/// Aba "Moldura" (moldura de imagem) de Editar vídeo e Editar imagem: as
/// artes prontas, as importadas e o botão de importar. É a outra família de
/// moldura — escolher aqui desativa a "Borda", e vice-versa.
///
/// Com uma arte escolhida ([FrameSettings.hasFixedAspect]), aparecem abaixo
/// das miniaturas o "Ajuste do conteúdo" (recolhível: como o conteúdo se
/// encaixa na janela), os cards da cor de dentro da janela e da resolução
/// do arquivo final e, por último, o botão "90°" (gira a moldura).
class ImageFramePanel extends StatelessWidget {
  const ImageFramePanel({
    super.key,
    required this.frame,
    required this.imported,
    required this.onSelected,
    required this.onClear,
    required this.onImport,
    required this.onRemoveImported,
    required this.onPickWindowColor,
    required this.resolutionFitLabel,
    required this.onChanged,
    required this.contentFitExpanded,
    required this.onToggleContentFit,
    required this.onChangeStart,
    required this.onChangedContinuous,
  });

  final FrameSettings frame;
  final List<ImageFrameAsset> imported;
  final ValueChanged<ImageFrameAsset> onSelected;
  final VoidCallback onClear;
  final VoidCallback onImport;
  final ValueChanged<ImageFrameAsset> onRemoveImported;
  final VoidCallback onPickWindowColor;

  /// Ver [FrameResolutionSelector.fitLabel].
  final String resolutionFitLabel;

  /// Mudanças de um toque só: modo de encaixe, resolução e giro.
  final ValueChanged<FrameSettings> onChanged;

  /// "Ajuste do conteúdo" aberto — guardado pela tela, para sobreviver à
  /// troca de abas.
  final bool contentFitExpanded;
  final VoidCallback onToggleContentFit;

  /// Começo do arrasto do zoom de "Expandir sem cortar" — o ponto de
  /// desfazer.
  final VoidCallback onChangeStart;

  /// O zoom a cada passo do arrasto.
  final ValueChanged<FrameSettings> onChangedContinuous;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ImageFramePicker(
          selected: frame.imageFrame,
          imported: imported,
          onSelected: onSelected,
          onClear: onClear,
          onImport: onImport,
          onRemoveImported: onRemoveImported,
        ),
        // A cor da janela, a resolução e o giro só existem para moldura de
        // imagem — sem uma escolhida, não há arte para deitar nem canvas
        // próprio para dimensionar.
        if (frame.hasFixedAspect) ...[
          const SizedBox(height: 18),
          SectionCard(
            children: [
              CollapsibleSubsection(
                label: tr('Ajuste do conteúdo', 'Content fit'),
                expanded: contentFitExpanded,
                onToggle: onToggleContentFit,
                child: ContentFitOptions(
                  frame: frame,
                  onSelected: (mode) =>
                      onChanged(frame.copyWith(contentFit: mode)),
                  onChangeStart: onChangeStart,
                  onChanged: onChangedContinuous,
                  onPickColor: onPickWindowColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SectionCard(
            children: [
              // Fundo de dentro da janela da moldura, em qualquer ajuste
              // (antes só em "Expandir sem cortar"; nos outros era preto).
              PanelColorRow(
                key: const ValueKey('frameWindowColorRow'),
                label: tr('Cor do fundo da moldura', 'Frame background color'),
                color: frame.expandBackgroundColor,
                onTap: onPickWindowColor,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SectionCard(
            children: [
              FrameResolutionSelector(
                selected: frame.frameResolutionMode,
                fitLabel: resolutionFitLabel,
                onChanged: (mode) =>
                    onChanged(frame.copyWith(frameResolutionMode: mode)),
              ),
            ],
          ),
          // O giro da moldura fica por último, sozinho: é um botão só.
          const SizedBox(height: 18),
          FrameRotateButton(
            onRotate: () => onChanged(
              frame.copyWith(frameQuarterTurns: frame.frameQuarterTurns + 1),
            ),
          ),
        ],
      ],
    );
  }
}

/// Card próprio de "Resolução da moldura": o tamanho/qualidade do arquivo
/// final, independente de como o conteúdo se encaixa na moldura — por isso
/// sempre visível, não atrelado ao "Ajuste do conteúdo".
class FrameResolutionSelector extends StatelessWidget {
  const FrameResolutionSelector({
    super.key,
    required this.selected,
    required this.fitLabel,
    required this.onChanged,
  });

  final ImageFrameResolutionMode selected;

  /// Rótulo de [ImageFrameResolutionMode.matchAjustar] na tela: "Ajustar" no
  /// vídeo, "Da foto" na foto.
  final String fitLabel;

  final ValueChanged<ImageFrameResolutionMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Resolução da moldura', 'Frame resolution'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<ImageFrameResolutionMode>(
            key: const ValueKey('frameResolutionSegmentedButton'),
            segments: [
              ButtonSegment(
                value: ImageFrameResolutionMode.matchAjustar,
                label: Text(
                  fitLabel,
                  key: const ValueKey('frameResolutionSegment_matchAjustar'),
                ),
              ),
              ButtonSegment(
                value: ImageFrameResolutionMode.nativeMax,
                label: Text(
                  tr('Máxima', 'Maximum'),
                  key: const ValueKey('frameResolutionSegment_nativeMax'),
                ),
              ),
            ],
            selected: {selected},
            showSelectedIcon: true,
            expandedInsets: EdgeInsets.zero,
            onSelectionChanged: (selection) => onChanged(selection.single),
          ),
        ],
      ),
    );
  }
}
