import '../../app/language_controller.dart';
import 'package:flutter/material.dart';

import '../../app/app_palette.dart';
import '../../app/preview_background_controller.dart';
import '../../app/theme_controller.dart';

/// Conteúdo da aba "Configurações" (ícone de engrenagem, sempre a última da
/// barra) nas quatro telas de edição: o tema do app (claro ou escuro), o
/// fundo quadriculado da prévia e a paleta de cores da interface.
class PreviewSettingsPanel extends StatelessWidget {
  const PreviewSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<ThemeMode>(
          valueListenable: themeModeNotifier,
          builder: (context, mode, _) => Row(
            children: [
              Icon(
                mode == ThemeMode.dark
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('Tema escuro', 'Dark theme'),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Switch(
                key: const ValueKey('darkThemeSwitch'),
                value: mode == ThemeMode.dark,
                onChanged: (_) => toggleThemeMode(),
              ),
            ],
          ),
        ),
        Divider(
          height: 13,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: previewCheckerboardNotifier,
          builder: (context, enabled, _) => Row(
            children: [
              const Icon(Icons.grid_on_rounded, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr(
                    'Fundo quadriculado na prévia',
                    'Checkerboard preview background',
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Switch(value: enabled, onChanged: setPreviewCheckerboardEnabled),
            ],
          ),
        ),
        Divider(
          height: 13,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        ValueListenableBuilder<AppPalette>(
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
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  for (final palette in appPalettes)
                    _PaletteSwatch(
                      palette: palette,
                      selected: palette.id == current.id,
                      onTap: () => setPalette(palette),
                    ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bolinha de uma paleta: a cor principal, uma faixa com a cor de destaque
/// e o fundo escuro dela, com um anel e um "check" quando é a escolhida.
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
    final scheme = Theme.of(context).colorScheme;
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
            width: 40,
            height: 40,
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
                  stops: const [0.42, 0.42, 0.58, 0.58],
                  colors: [
                    palette.seed,
                    palette.accentGradient.last,
                    palette.accentGradient.last,
                    palette.darkBackground,
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
