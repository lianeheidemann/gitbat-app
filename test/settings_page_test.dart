import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitbat/app/app_palette.dart';
import 'package:gitbat/app/theme_controller.dart';
import 'package:gitbat/features/home/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => paletteNotifier.value = appPalettes.first);

  testWidgets('a engrenagem abre configurações com as cinco paletas', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    paletteNotifier.value = batPalette;
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    await tester.tap(find.byKey(const ValueKey('settingsButton')));
    await tester.pumpAndSettle();

    expect(find.text('Configurações'), findsOneWidget);
    expect(find.text('Aparência'), findsOneWidget);
    expect(find.text('Paleta de cores'), findsOneWidget);
    for (final palette in appPalettes) {
      expect(
        find.byKey(ValueKey('paletteSwatch-${palette.id}')),
        findsOneWidget,
      );
    }

    await tester.tap(find.byKey(const ValueKey('paletteSwatch-menta')));
    await tester.pumpAndSettle();
    expect(paletteNotifier.value, mintPalette);
  });
}
