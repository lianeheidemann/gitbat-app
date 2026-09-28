import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitbat/app/app_palette.dart';
import 'package:gitbat/app/language_controller.dart';
import 'package:gitbat/app/theme.dart';
import 'package:gitbat/core/models/conversion_settings.dart';
import 'package:gitbat/features/home/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

// O botão da tela inicial troca a interface entre português e inglês, e a
// escolha fica salva para a próxima vez que o app abrir.

void main() {
  tearDown(() => languageNotifier.value = AppLanguage.pt);

  test('tr e os rótulos dos modelos seguem o idioma atual', () {
    languageNotifier.value = AppLanguage.pt;
    expect(tr('Fundo', 'Background'), 'Fundo');
    expect(DitherMode.none.label, 'Sem pontilhado');
    expect(lavenderPalette.label, 'Lavanda');

    languageNotifier.value = AppLanguage.en;
    expect(tr('Fundo', 'Background'), 'Background');
    expect(DitherMode.none.label, 'No dithering');
    expect(lavenderPalette.label, 'Lavender');
  });

  testWidgets('o botão da tela inicial alterna e salva o idioma', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    languageNotifier.value = AppLanguage.pt;
    // Mesmo esquema do main.dart: o app inteiro é refeito na troca.
    await tester.pumpWidget(
      ValueListenableBuilder<AppLanguage>(
        valueListenable: languageNotifier,
        builder: (context, language, _) =>
            MaterialApp(key: ValueKey(language), home: const HomePage()),
      ),
    );
    expect(find.text('Escolher vídeo'), findsOneWidget);
    expect(find.byIcon(Icons.language_rounded), findsOneWidget);
    expect(find.text('PT'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('languageToggle')));
    await tester.pumpAndSettle();
    expect(languageNotifier.value, AppLanguage.en);
    expect(find.text('Choose video'), findsOneWidget);
    expect(find.text('Collage'), findsOneWidget);
    expect(find.byIcon(Icons.language_rounded), findsOneWidget);
    expect(find.text('EN'), findsNothing);

    // Ao abrir de novo, o app volta no idioma salvo.
    languageNotifier.value = AppLanguage.pt;
    await loadLanguage();
    expect(languageNotifier.value, AppLanguage.en);
  });

  testWidgets('a tela inicial usa os acentos da paleta', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: const HomePage(),
      ),
    );

    final scheme = buildTheme(Brightness.dark).colorScheme;
    expect(
      tester.widget<Icon>(find.byKey(const ValueKey('svgAccentIcon'))).color,
      scheme.secondary,
    );
    expect(
      tester
          .widget<Icon>(find.byKey(const ValueKey('convertAccentIcon')))
          .color,
      scheme.secondary,
    );
  });
}
