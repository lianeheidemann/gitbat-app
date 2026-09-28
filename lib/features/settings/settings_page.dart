import 'package:flutter/material.dart';

import '../../app/language_controller.dart';
import '../../core/ui/palette_picker.dart';

/// Configurações gerais do aplicativo. Começa pequena de propósito e pode
/// receber novas seções sem sobrecarregar a tela inicial.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Configurações', 'Settings'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            tr('Aparência', 'Appearance'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(
              'Escolha as cores da interface.',
              'Choose the interface colors.',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: const PalettePicker(showLabels: true),
            ),
          ),
        ],
      ),
    );
  }
}
