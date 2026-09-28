import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gitbat/app/theme_controller.dart';
import 'package:gitbat/core/ui/theme_mode_button.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    themeModeNotifier.value = ThemeMode.light;
  });

  testWidgets('alterna entre os temas claro e escuro', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(appBar: AppBar(actions: [ThemeModeButton()])),
      ),
    );

    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);

    await tester.tap(find.byType(ThemeModeButton));
    await tester.pump();

    expect(themeModeNotifier.value, ThemeMode.dark);
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
  });
}
