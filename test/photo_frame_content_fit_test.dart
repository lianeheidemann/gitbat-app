import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gitbat/core/models/photo_info.dart';
import 'package:gitbat/core/ui/editor_tabs_footer.dart';
import 'package:gitbat/features/photo/photo_frame_page.dart';

/// Em "Editar imagem", o "Ajuste do conteúdo" é uma subseção recolhível da
/// aba "Moldura" — igual a "Editar vídeo" (o mesmo `ImageFramePanel`) —, e
/// não mais uma aba própria.
Future<PhotoInfo> _photo(Directory dir) async {
  final recorder = ui.PictureRecorder();
  Canvas(
    recorder,
  ).drawRect(const Rect.fromLTWH(0, 0, 300, 200), Paint()..color = Colors.red);
  final picture = recorder.endRecording();
  final image = await picture.toImage(300, 200);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  final path = '${dir.path}/foto.png';
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  return PhotoInfo(path: path, width: 300, height: 200);
}

void main() {
  testWidgets('"Ajuste do conteúdo" fica dentro de "Moldura"', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final dir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('photo_content_fit'),
    );
    addTearDown(() => dir!.delete(recursive: true));
    final photo = await tester.runAsync(() => _photo(dir!));

    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: PhotoFramePage(photo: photo!)));
    await tester.pumpAndSettle();

    Finder tab(String label) => find.descendant(
      of: find.byType(EditorTabsFooter),
      matching: find.text(label),
    );

    await tester.tap(tab('Moldura'));
    await tester.pumpAndSettle();
    final thumb = find.byKey(const ValueKey('imageFrameThumb_bundled_titanio'));
    await tester.ensureVisible(thumb);
    await tester.pumpAndSettle();
    await tester.tap(thumb);
    await tester.pumpAndSettle();

    // Com a moldura escolhida, nenhuma aba "Ajuste" aparece na barra...
    expect(tab('Ajuste'), findsNothing);

    // ...e o ajuste está na própria aba "Moldura", começando recolhido.
    final header = find.text('Ajuste do conteúdo');
    await tester.ensureVisible(header);
    await tester.pumpAndSettle();
    expect(header, findsOneWidget);
    expect(find.byKey(const ValueKey('contentFitTile_auto')), findsNothing);

    await tester.tap(header);
    await tester.pumpAndSettle();
    for (final mode in ['auto', 'fill', 'expand']) {
      expect(find.byKey(ValueKey('contentFitTile_$mode')), findsOneWidget);
    }

    // Escolher "Expandir sem cortar" abre as opções dele (zoom e cor).
    final expand = find.byKey(const ValueKey('contentFitTile_expand'));
    await tester.ensureVisible(expand);
    await tester.pumpAndSettle();
    await tester.tap(expand);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('expandBackgroundColorRow')),
      findsOneWidget,
    );

    // Desfazer volta ao modo anterior.
    await tester.tap(find.byTooltip('Desfazer'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('expandBackgroundColorRow')),
      findsNothing,
    );
  });
}
