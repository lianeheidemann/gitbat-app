import 'package:flutter/material.dart';

import '../../app/app_palette.dart';
import '../../app/language_controller.dart';
import '../../app/theme.dart';
import '../../app/theme_controller.dart';

const _accentFolding = <String, String>{
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
};

String _paletteNameSortKey(String name) => name
    .toLowerCase()
    .split('')
    .map((character) => _accentFolding[character] ?? character)
    .join();

/// Paletas em ordem alfabética pelo nome traduzido exibido na interface.
///
/// A lista original permanece intacta porque seu primeiro item também define
/// a paleta padrão do aplicativo.
List<AppPalette> palettesSortedByDisplayName() {
  final palettes = [...appPalettes];
  palettes.sort((first, second) {
    final nameComparison = _paletteNameSortKey(
      first.label,
    ).compareTo(_paletteNameSortKey(second.label));
    return nameComparison != 0 ? nameComparison : first.id.compareTo(second.id);
  });
  return palettes;
}

/// Seletor único de paletas usado tanto nas telas de edição quanto na página
/// geral de configurações. A escolha é aplicada e salva imediatamente.
class PalettePicker extends StatelessWidget {
  const PalettePicker({super.key, this.showLabels = false});

  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palettes = palettesSortedByDisplayName();
    return ValueListenableBuilder<AppPalette>(
      valueListenable: paletteNotifier,
      builder: (context, current, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.palette_outlined, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('Paleta de cores', 'Color palette'),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                current.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < palettes.length; index++) ...[
                  _PaletteOption(
                    palette: palettes[index],
                    selected: palettes[index].id == current.id,
                    showLabel: showLabels,
                    onTap: () => setPalette(palettes[index]),
                  ),
                  if (index < palettes.length - 1)
                    SizedBox(width: showLabels ? 6 : 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _PaletteOption extends StatelessWidget {
  const _PaletteOption({
    required this.palette,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  final AppPalette palette;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final swatch = _PaletteSwatch(
      palette: palette,
      selected: selected,
      onTap: onTap,
    );
    if (!showLabel) return swatch;

    return SizedBox(
      width: 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          swatch,
          const SizedBox(height: 6),
          Text(
            palette.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// Amostra compacta das cores realmente exibidas pela paleta no tema atual.
class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final paletteScheme = buildTheme(theme.brightness, palette).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: tr('Paleta ${palette.label}', 'Palette ${palette.label}'),
      child: Tooltip(
        message: palette.label,
        child: InkResponse(
          key: ValueKey('paletteSwatch-${palette.id}'),
          onTap: onTap,
          radius: 24,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.onSurface : scheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.34, 0.34, 0.52, 0.52, 0.68, 0.68],
                  colors: [
                    paletteScheme.primary,
                    paletteScheme.secondary,
                    paletteScheme.secondary,
                    paletteScheme.tertiary,
                    paletteScheme.tertiary,
                    paletteScheme.surfaceContainerHighest,
                  ],
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
