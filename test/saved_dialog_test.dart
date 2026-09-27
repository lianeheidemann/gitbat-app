import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_to_gif/app/theme.dart';
import 'package:video_to_gif/core/ui/saved_dialog.dart';

void main() {
  testWidgets('pop-up "Salvo!" mostra a mensagem e fecha no OK', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSavedDialog(context, 'Foto salva na galeria.'),
            child: const Text('salvar'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Salvo!'), findsOneWidget);
    expect(find.text('Foto salva na galeria.'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('savedDialog')), findsNothing);
  });

  test('tema compacto: densidade, título e botões menores', () {
    final theme = buildTheme(Brightness.dark);
    expect(theme.visualDensity, VisualDensity.compact);
    expect(theme.appBarTheme.titleTextStyle!.fontSize, 20);
    expect(theme.inputDecorationTheme.isDense, isTrue);
    expect(appTextScale, lessThan(1));
  });
}
