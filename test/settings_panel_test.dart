import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_to_gif/app/app_palette.dart';
import 'package:video_to_gif/app/theme.dart';
import 'package:video_to_gif/app/theme_controller.dart';
import 'package:video_to_gif/core/ui/preview_settings_panel.dart';

// A aba "Configurações" das telas de edição troca o tema claro/escuro e a
// paleta de cores.

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

  testWidgets('escolher uma paleta troca e salva a paleta do app', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    paletteNotifier.value = appPalettes.first;
    addTearDown(() => paletteNotifier.value = appPalettes.first);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: PreviewSettingsPanel()),
        ),
      ),
    );
    expect(find.text('Paleta de cores'), findsOneWidget);
    for (final palette in appPalettes) {
      expect(
        find.byKey(ValueKey('paletteSwatch-${palette.id}')),
        findsOneWidget,
      );
    }
    await tester.tap(find.byKey(const ValueKey('paletteSwatch-morceguinho')));
    await tester.pumpAndSettle();
    expect(paletteNotifier.value, batPalette);
    expect(find.text('Morceguinho'), findsOneWidget);

    // Ao abrir de novo, o app já nasce na paleta salva.
    paletteNotifier.value = appPalettes.first;
    await loadPalette();
    expect(paletteNotifier.value, batPalette);
  });

  test('paleta desconhecida cai na padrão', () {
    expect(paletteById(null), appPalettes.first);
    expect(paletteById('nao-existe'), appPalettes.first);
  });

  for (final palette in appPalettes) {
    for (final brightness in Brightness.values) {
      test('paleta ${palette.label} no tema ${brightness.name}', () {
        final theme = buildTheme(brightness, palette);
        expect(theme.colorScheme.brightness, brightness);
        expect(theme.extension<AppAccent>()!.gradient, palette.accentGradient);
        if (brightness == Brightness.dark) {
          expect(theme.colorScheme.primary, palette.seed);
          expect(theme.scaffoldBackgroundColor, palette.darkBackground);
        }
      });
    }
  }
}
