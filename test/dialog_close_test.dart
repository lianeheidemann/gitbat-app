import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_to_gif/core/ui/text_input_dialog.dart';

// Pop-ups fecham pelo X no canto de cima à direita, sem botão "Cancelar".

void main() {
  testWidgets('X fecha o pop-up devolvendo nada', (tester) async {
    String? result = 'não fechou';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<String>(
                context: context,
                builder: (_) =>
                    const TextInputDialog(initial: 'a', title: 'Nova pasta'),
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar'), findsNothing);
    final close = find.byKey(const ValueKey('dialogCloseButton'));
    expect(close, findsOneWidget);
    // No canto de cima, à direita do título.
    expect(
      tester.getCenter(close).dx,
      greaterThan(tester.getCenter(find.text('Nova pasta')).dx),
    );
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byType(TextInputDialog), findsNothing);
    expect(result, isNull);
  });
}
