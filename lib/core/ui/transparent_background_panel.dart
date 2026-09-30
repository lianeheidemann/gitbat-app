import '../../app/language_controller.dart';
import 'package:flutter/material.dart';

import 'panel_rows.dart';

/// Aba "Fundo" de Editar imagem e Editar SVG: o fundo transparente e, com
/// ele desligado, a cor do fundo.
class TransparentBackgroundPanel extends StatelessWidget {
  const TransparentBackgroundPanel({
    super.key,
    required this.transparent,
    required this.color,
    required this.onTransparentChanged,
    required this.onPickColor,
  });

  final bool transparent;
  final Color color;
  final ValueChanged<bool> onTransparentChanged;
  final VoidCallback onPickColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          key: const ValueKey('transparentBackgroundSwitch'),
          children: [
            Expanded(
              child: Text(
                tr('Fundo transparente', 'Transparent background'),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Switch(value: transparent, onChanged: onTransparentChanged),
          ],
        ),
        if (!transparent) ...[
          Divider(
            height: 13,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
          PanelColorRow(
            key: const ValueKey('backgroundColorRow'),
            label: tr('Cor do fundo', 'Background color'),
            color: color,
            onTap: onPickColor,
          ),
        ],
      ],
    );
  }
}
