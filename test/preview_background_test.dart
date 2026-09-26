import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_to_gif/app/preview_background_controller.dart';
import 'package:video_to_gif/core/ui/checkerboard_background.dart';

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
    expect(box.color, previewAreaColor);
    expect(
      tester.getSize(find.byType(CheckerboardBackground)),
      const Size(120, 60),
    );

    previewCheckerboardNotifier.value = false;
    await tester.pump();
    expect(find.byType(CheckerboardBackground), findsNothing);
  });
}
