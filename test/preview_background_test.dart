import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitbat/app/preview_background_controller.dart';
import 'package:gitbat/core/ui/checkerboard_background.dart';

// A área de prévia é de cor sólida; o xadrez fica só atrás da mídia, do
// tamanho exato dela.

void main() {
  testWidgets('xadrez só atrás da mídia, cor sólida em volta', (tester) async {
    previewCheckerboardNotifier.value = true;
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 400,
          height: 400,
          child: PreviewAreaBackground(
            child: Center(
              child: MediaCheckerboard(child: SizedBox(width: 120, height: 60)),
            ),
          ),
        ),
      ),
    );

    final box = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(PreviewAreaBackground),
        matching: find.byType(ColoredBox),
      ),
    );
    // Tema claro (padrão do MaterialApp): o fundo claro.
    expect(box.color, previewAreaColorLight);
    expect(
      tester.getSize(find.byType(CheckerboardBackground)),
      const Size(120, 60),
    );

    previewCheckerboardNotifier.value = false;
    await tester.pump();
    expect(find.byType(CheckerboardBackground), findsNothing);
  });
}
