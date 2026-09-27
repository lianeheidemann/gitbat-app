import 'package:flutter/material.dart';

import '../../app/preview_background_controller.dart';
import '../../app/theme_controller.dart';

/// Conteúdo da aba "Configurações" (ícone de engrenagem, sempre a última da
/// barra) nas quatro telas de edição: o tema do app (claro ou escuro) e o
/// fundo quadriculado da prévia.
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
                child: Text('Tema escuro', style: theme.textTheme.bodyMedium),
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
                  'Fundo quadriculado na prévia',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Switch(value: enabled, onChanged: setPreviewCheckerboardEnabled),
            ],
          ),
        ),
      ],
    );
  }
}
