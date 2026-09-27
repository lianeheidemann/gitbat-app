import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_to_gif/app/theme_controller.dart';
import 'package:video_to_gif/core/ui/preview_settings_panel.dart';

// A aba "Configurações" das telas de edição troca o tema claro/escuro.

void main() {
  testWidgets('"Tema escuro" alterna o tema do app', (tester) async {
    SharedPreferences.setMockInitialValues({});
    themeModeNotifier.value = ThemeMode.light;
    addTearDown(() => themeModeNotifier.value = ThemeMode.light);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PreviewSettingsPanel())),
    );
    final toggle = find.byKey(const ValueKey('darkThemeSwitch'));
    expect(tester.widget<Switch>(toggle).value, isFalse);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(themeModeNotifier.value, ThemeMode.dark);
    expect(tester.widget<Switch>(toggle).value, isTrue);
  });
}
