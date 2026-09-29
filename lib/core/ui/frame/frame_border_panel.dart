import '../../../app/language_controller.dart';
import 'package:flutter/material.dart';

import '../../models/frame_settings.dart';
import '../panel_rows.dart';
import 'frame_sliders.dart';
import 'frame_style_picker.dart';
import 'frame_thumb_shell.dart';

/// Aba "Borda" (moldura procedural) de Editar vídeo, Editar imagem e Editar
/// SVG: as opções de estilo e, com uma delas ativa, a cor, a espessura e o
/// arredondamento dos cantos.
class FrameBorderPanel extends StatelessWidget {
  const FrameBorderPanel({
    super.key,
    required this.frame,
    required this.activeStyle,
    required this.onSelectStyle,
    required this.onPickColor,
    required this.onChangeStart,
    required this.onChanged,
  });

  /// A borda em edição — as fileiras de espessura e cantos leem e devolvem
  /// ela inteira.
  final FrameSettings frame;

  /// O estilo que decide se os controles aparecem: com moldura de imagem
  /// ativa, a tela passa "Sem borda" (ver [FrameSettings.activeStyle]).
  final FrameStyle activeStyle;

  final ValueChanged<FrameStyle> onSelectStyle;
  final VoidCallback onPickColor;

  /// Começo do arrasto de espessura/cantos — o ponto de desfazer.
  final VoidCallback onChangeStart;

  /// Espessura/cantos a cada passo do arrasto.
  final ValueChanged<FrameSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget divider() => Divider(
      height: 13,
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FrameStylePicker(active: frame.style, onSelected: onSelectStyle),
        if (activeStyle != FrameStyle.none) ...[
          const SizedBox(height: 18),
          SectionCard(
            children: [
              PanelColorRow(
                label: tr('Cor da borda', 'Border color'),
                color: frame.color,
                onTap: onPickColor,
              ),
              divider(),
              FrameThicknessRow(
                frame: frame,
                onChangeStart: onChangeStart,
                onChanged: onChanged,
              ),
              divider(),
              CornerRadiusRow(
                frame: frame,
                onChangeStart: onChangeStart,
                onChanged: onChanged,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
