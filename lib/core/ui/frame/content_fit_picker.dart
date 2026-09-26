import 'package:flutter/material.dart';

import '../../models/frame_settings.dart';
import '../panel_rows.dart';
import 'frame_sliders.dart';

/// Ladrilho de um modo de encaixe do conteúdo na moldura de imagem. O modo
/// "Expandir sem cortar" abre as opções dele (zoom e cor do fundo) quando
/// está selecionado.
class ContentFitTile extends StatelessWidget {
  const ContentFitTile({
    super.key,
    required this.mode,
    required this.selected,
    required this.onSelected,
    this.expandedOptions,
  });

  final ContentFitMode mode;
  final bool selected;
  final ValueChanged<ContentFitMode> onSelected;

  /// Opções mostradas dentro do ladrilho selecionado de "Expandir sem
  /// cortar" — o zoom e a cor do fundo da janela.
  final Widget? expandedOptions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showOptions =
        selected && mode == ContentFitMode.expand && expandedOptions != null;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.10)
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            key: ValueKey('contentFitTile_${mode.name}'),
            onTap: () => onSelected(mode),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: ContentFitTileHeader(mode: mode, selected: selected),
            ),
          ),
          if (showOptions)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.55,
                    ),
                  ),
                  const SizedBox(height: 12),
                  expandedOptions!,
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Cabeçalho do ladrilho: ícone, nome do modo e a marca de selecionado.
class ContentFitTileHeader extends StatelessWidget {
  const ContentFitTileHeader({
    super.key,
    required this.mode,
    required this.selected,
  });

  final ContentFitMode mode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            contentFitIcon(mode),
            size: 16,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            mode.label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (selected)
          Icon(
            Icons.check_circle_rounded,
            color: theme.colorScheme.primary,
            size: 20,
          ),
      ],
    );
  }
}

IconData contentFitIcon(ContentFitMode mode) => switch (mode) {
  ContentFitMode.auto => Icons.auto_fix_high_rounded,
  ContentFitMode.fill => Icons.crop_free_rounded,
  ContentFitMode.fit => Icons.fit_screen_rounded,
  ContentFitMode.expand => Icons.open_in_full_rounded,
};

/// Opções do ladrilho "Expandir sem cortar": o zoom do conteúdo e a cor do
/// fundo da janela da moldura em volta dele
/// ([FrameSettings.expandBackgroundColor]).
class ExpandFitOptions extends StatelessWidget {
  const ExpandFitOptions({
    super.key,
    required this.frame,
    required this.onChangeStart,
    required this.onChanged,
    required this.onPickColor,
  });

  final FrameSettings frame;
  final VoidCallback onChangeStart;
  final ValueChanged<FrameSettings> onChanged;
  final VoidCallback onPickColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        ContentZoomRow(
          frame: frame,
          onChangeStart: onChangeStart,
          onChanged: onChanged,
        ),
        Divider(
          height: 13,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        PanelColorRow(
          key: const ValueKey('expandBackgroundColorRow'),
          label: 'Cor do fundo da moldura',
          color: frame.expandBackgroundColor,
          onTap: onPickColor,
        ),
      ],
    );
  }
}
