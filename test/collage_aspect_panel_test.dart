import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_to_gif/features/collage/models/collage_layout.dart';
import 'package:video_to_gif/features/collage/models/collage_settings.dart';
import 'package:video_to_gif/features/collage/widgets/panels/aspect_panel.dart';
import 'package:video_to_gif/features/collage/widgets/panels/collage_panel_actions.dart';

// Aba "Proporção": arrastar o slider fica em "x:y", mesmo passando por um
// formato pronto — senão o painel mudava de altura no meio do arrasto.

void main() {
  testWidgets('arrastar o slider escolhe "x:y" e o painel não pula', (
    tester,
  ) async {
    var settings = CollageSettings(
      layout: CollageLayout.row(2),
      aspectRatio: 1.5,
      cells: const [],
    );
    var custom = false;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return CollageAspectPanel(
                settings: settings,
                customSelected: custom,
                onCustomSelected: (v) => rebuild(() => custom = v),
                actions: CollagePanelActions(
                  update: (s, {pushUndo = true}) => rebuild(() => settings = s),
                  pushUndoCheckpoint: () {},
                  message: (_) {},
                ),
              );
            },
          ),
        ),
      ),
    );
    // Em 3:2 pronto: sem campos de x:y.
    expect(find.text('Largura'), findsNothing);

    final slider = find.byType(Slider);
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await tester.pump();
    await gesture.moveBy(const Offset(1, 0));
    await tester.pump();
    expect(custom, isTrue);
    final before = tester.getTopLeft(slider);

    // Volta exatamente para 3:2 ainda no meio do arrasto.
    rebuild(() => settings = settings.copyWith(aspectRatio: 1.5));
    await tester.pump();
    expect(tester.getTopLeft(slider), before, reason: 'o slider não pula');
    expect(find.text('1.50'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
