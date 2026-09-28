import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gitbat/app/app_palette.dart';
import 'package:gitbat/app/theme.dart';
import 'package:gitbat/app/theme_controller.dart';
import 'package:gitbat/core/ui/preview_settings_panel.dart';

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
    await tester.tap(find.byKey(const ValueKey('paletteSwatch-lavanda')));
    await tester.pumpAndSettle();
    expect(paletteNotifier.value, lavenderPalette);
    expect(find.text('Lavanda'), findsOneWidget);

    // Ao abrir de novo, o app já nasce na paleta salva.
    paletteNotifier.value = appPalettes.first;
    await loadPalette();
    expect(paletteNotifier.value, lavenderPalette);
  });

  test('paleta desconhecida cai na padrão', () {
    expect(paletteById(null), appPalettes.first);
    expect(paletteById('nao-existe'), appPalettes.first);
  });

  test('paletas v2 adicionam 25 opções com ids únicos', () {
    expect(appPalettes, hasLength(33));
    expect(appPalettes.map((palette) => palette.id).toSet(), hasLength(33));
    expect(appPalettes.skip(8), hasLength(25));
  });

  for (final palette in appPalettes) {
    for (final brightness in Brightness.values) {
      test('paleta ${palette.label} no tema ${brightness.name}', () {
        final theme = buildTheme(brightness, palette);
        expect(theme.colorScheme.brightness, brightness);
        expect(theme.extension<AppAccent>()!.gradient, palette.accentGradient);
        if (brightness == Brightness.dark) {
          expect(theme.colorScheme.primary, isNot(equals(Colors.transparent)));
          expect(theme.colorScheme.surface, palette.darkBackground);
          expect(theme.scaffoldBackgroundColor, palette.darkBackground);
        }
      });
    }
  }

  test('a paleta oficial é a do morceguinho, com cores próprias', () {
    expect(appPalettes.first, batPalette);
    final dark = buildTheme(Brightness.dark).colorScheme;
    expect(dark.surface, const Color(0xFF0D1526));
    expect(dark.secondary, const Color(0xFF22D8EE));
    expect(dark.onSurface, const Color(0xFFF1F5FF));
    expect(dark.onSurfaceVariant, const Color(0xFFA8B6D3));
    expect(dark.surfaceContainerLow, const Color(0xFF16233B));
    expect(dark.surfaceContainerHigh, const Color(0xFF203251));
    final light = buildTheme(Brightness.light).colorScheme;
    expect(light.primary, const Color(0xFF0C48A8));
  });

  test('todas as paletas têm acabamento próprio nos dois temas', () {
    for (final palette in appPalettes) {
      expect(palette.refineLight, isNotNull, reason: palette.label);
      expect(palette.refineDark, isNotNull, reason: palette.label);
      expect(palette.darkTertiary, isNotNull, reason: palette.label);
    }
  });

  test('tríade e quadrada preservam o azul da marca', () {
    expect(appPalettes, containsAll([triadPalette, squarePalette]));
    expect(triadPalette.accentGradient, contains(const Color(0xFF60DDB2)));
    expect(squarePalette.accentGradient, contains(const Color(0xFF76A9FF)));
    expect(squarePalette.contentFrame, const Color(0xFF5C9C4B));
    expect(squarePalette.contentText, const Color(0xFF7F2A1A));
  });

  test('Pitaya e Limão usa a versão clara aprovada sem mudar a escura', () {
    final light = buildTheme(Brightness.light, pitayaLimePalette).colorScheme;
    expect(light.primary, const Color(0xFFB84F70));
    expect(light.tertiary, const Color(0xFF9FCB7A));
    expect(light.surface, const Color(0xFFFFF9FA));
    expect(light.surfaceContainer, const Color(0xFFF8E8ED));
    expect(light.onSurface, const Color(0xFF4C2338));
    expect(light.outline, const Color(0xFF7B4B61));

    final dark = buildTheme(Brightness.dark, pitayaLimePalette).colorScheme;
    expect(dark.primary, const Color(0xFFD92B73));
    expect(dark.tertiary, const Color(0xFFB9F68D));
    expect(dark.surface, const Color(0xFF201022));
  });

  test('Pôr do Sol Rosa usa mais azul no claro sem mudar a escura', () {
    final light = buildTheme(Brightness.light, sunsetRosePalette).colorScheme;
    expect(light.primary, const Color(0xFFC86578));
    expect(light.secondary, const Color(0xFF6678A6));
    expect(light.tertiary, const Color(0xFFD9A441));
    expect(light.surface, const Color(0xFFFFF9F6));
    expect(light.surfaceContainerHigh, const Color(0xFFE7EAF4));
    expect(light.outline, const Color(0xFF6678A6));

    final dark = buildTheme(Brightness.dark, sunsetRosePalette).colorScheme;
    expect(dark.primary, const Color(0xFFFF7496));
    expect(dark.tertiary, const Color(0xFFFFC65A));
    expect(dark.surface, const Color(0xFF11172A));
  });

  test('dália usa as cores extraídas das referências', () {
    expect(appPalettes, contains(dahliaPalette));
    expect(dahliaPalette.darkBackground, const Color(0xFF121115));
    expect(dahliaPalette.accentGradient, const [
      Color(0xFFCDAAFD),
      Color(0xFFF0A5C7),
    ]);
    expect(dahliaPalette.darkTertiary, const Color(0xFFF0A5C7));
  });
}
