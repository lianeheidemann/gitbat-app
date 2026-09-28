import 'package:flutter/material.dart';

import '../../app/language_controller.dart';
import '../../app/theme_controller.dart';

/// Botão compartilhado para alternar entre os temas claro e escuro.
///
/// Mantém ícone, tooltip e comportamento iguais em todas as barras do app.
class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return IconButton(
          tooltip: isDark
              ? tr('Ativar modo claro', 'Switch to light mode')
              : tr('Ativar modo escuro', 'Switch to dark mode'),
          color: scheme.secondary,
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          ),
          onPressed: toggleThemeMode,
        );
      },
    );
  }
}
