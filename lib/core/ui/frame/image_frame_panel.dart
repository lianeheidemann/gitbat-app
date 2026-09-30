import '../../../app/language_controller.dart';
import 'package:flutter/material.dart';

import '../../models/frame_settings.dart';
import '../../models/image_frame.dart';
import '../panel_rows.dart';
import 'frame_rotate_button.dart';
import 'frame_thumb_shell.dart';
import 'image_frame_picker.dart';

/// Aba "Moldura" (moldura de imagem) de Editar vídeo e Editar imagem: as
/// artes prontas, as importadas e o botão de importar. É a outra família de
/// moldura — escolher aqui desativa a "Borda", e vice-versa.
///
/// Com uma arte escolhida ([FrameSettings.hasFixedAspect]), aparecem abaixo
/// das miniaturas os cards da cor de dentro da janela e da resolução do
/// arquivo final e, por último, o botão "90°" (gira a moldura).
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
    this.leadingCard,
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

  /// Resolução e giro da moldura — mudanças de um toque só.
  final ValueChanged<FrameSettings> onChanged;

  /// Card extra antes dos outros, com uma arte escolhida (o "Ajuste do
  /// conteúdo" recolhível do vídeo; na foto ele é uma aba própria).
  final Widget? leadingCard;

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
          if (leadingCard case final card?) ...[
            const SizedBox(height: 18),
            card,
          ],
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
