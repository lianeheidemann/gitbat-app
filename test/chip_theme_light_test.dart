import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_to_gif/app/theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('rótulo dos chips legível no tema ${brightness.name}', (
      tester,
    ) async {
      final theme = buildTheme(brightness);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            // Texto em volta de propósito na cor do fundo, como o painel que
            // deixava os chips invisíveis.
            body: DefaultTextStyle(
              style: TextStyle(color: theme.colorScheme.surface),
              child: Wrap(
                children: [
                  ChoiceChip(
                    label: const Text('4:5'),
                    selected: false,
                    onSelected: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final style = tester
          .widget<RichText>(
            find.descendant(
              of: find.byType(ChoiceChip),
              matching: find.byType(RichText),
            ),
          )
          .text
          .style!;
      expect(style.color, theme.colorScheme.onSurface);
    });
  }
}
