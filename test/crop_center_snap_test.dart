import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_to_gif/core/models/crop_rect.dart';
import 'package:video_to_gif/core/models/photo_info.dart';
import 'package:video_to_gif/core/ui/crop/crop_controller.dart';
import 'package:video_to_gif/core/ui/crop/crop_overlay.dart';
import 'package:video_to_gif/features/photo/photo_frame_page.dart';

void main() {
  group('CropController: trava no centro', () {
    const snap = Offset(10, 10);

    test('grudar no centro quando chega perto e soltar ao seguir', () {
      final c = CropController(sourceWidth: 200, sourceHeight: 200);
      // Janela 100x100 em x=20: o centro fica em x=50.
      var crop = const CropRect(x: 20, y: 0, width: 100, height: 100);
      crop = c.moveBy(
        crop: crop,
        sourceDelta: const Offset(24, 0),
        snapDistance: snap,
      )!;
      expect(crop.x, 50, reason: 'a 6 px do centro, gruda');
      expect(crop.y, 0, reason: 'o eixo vertical está longe do centro');
      expect(c.centerAlignment(crop), (true, false));

      // Pouco a pouco não solta (a posição livre ainda está perto)...
      final still = c.moveBy(
        crop: crop,
        sourceDelta: const Offset(3, 0),
        snapDistance: snap,
      );
      expect(still, isNull);
      // ...mas seguindo o arrasto passa do limite e solta.
      final free = c.moveBy(
        crop: crop,
        sourceDelta: const Offset(15, 0),
        snapDistance: snap,
      )!;
      expect(free.x, 62);
      expect(c.centerAlignment(free), (false, false));
    });

    test('longe do centro, anda normalmente', () {
      final c = CropController(sourceWidth: 200, sourceHeight: 200);
      const crop = CropRect(x: 0, y: 0, width: 50, height: 50);
      final next = c.moveBy(
        crop: crop,
        sourceDelta: const Offset(5, 5),
        snapDistance: snap,
      )!;
      expect((next.x, next.y), (5, 5));
    });

    test('pinça redimensiona mantendo formato e centro', () {
      final c = CropController(sourceWidth: 400, sourceHeight: 400);
      const crop = CropRect(x: 100, y: 150, width: 200, height: 100);
      c.pinchStart(crop);
      final bigger = c.pinchTo(1.5, crop: crop)!;
      expect((bigger.width, bigger.height), (300, 150));
      expect(bigger.x + bigger.width / 2, 200);
      expect(bigger.y + bigger.height / 2, 200);
      // Não passa do tamanho da fonte.
      final max = c.pinchTo(5, crop: bigger)!;
      expect((max.width, max.height), (400, 200));
    });
  });

  testWidgets('Editar imagem: arrastar dentro da janela move e trava no '
      'centro, com guias', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('snap_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/foto.png';
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 200, 200),
        Paint()..color = const Color(0xFF3366AA),
      );
      final image = await recorder.endRecording().toImage(200, 200);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(path).writeAsBytes(bytes!.buffer.asUint8List());
    });
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoFramePage(
          photo: PhotoInfo(path: path, width: 200, height: 200),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('1:1'));
    await tester.pumpAndSettle();
    CropRect crop() =>
        tester.widget<CropOverlay>(find.byType(CropOverlay)).crop!;
    // Diminui a janela para poder movê-la.
    final overlay = tester.widget<CropOverlay>(find.byType(CropOverlay));
    overlay.onPinchStart!();
    overlay.onPinch!(0.5);
    await tester.pumpAndSettle();
    final start = crop();
    expect(start.width, lessThan(200));
    expect(
      tester.widget<CropOverlay>(find.byType(CropOverlay)).crop!.x,
      (200 - start.width) ~/ 2,
    );

    final interior = find.byKey(const ValueKey('cropInteriorGesture'));
    final gesture = await tester.startGesture(tester.getCenter(interior));
    // Sai do centro...
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(crop().x, greaterThan(start.x));
    expect(find.byKey(const ValueKey('cropCenterGuideVertical')), findsNothing);
    expect(
      find.byKey(const ValueKey('cropCenterGuideHorizontal')),
      findsOneWidget,
      reason: 'na vertical continua centralizada',
    );
    // ...e volta para perto: gruda de novo e mostra a guia.
    await gesture.moveBy(const Offset(-77, 0));
    await tester.pump();
    expect(crop().x, start.x);
    expect(
      find.byKey(const ValueKey('cropCenterGuideVertical')),
      findsOneWidget,
    );
    await gesture.up();
    await tester.pump();
    expect(find.byKey(const ValueKey('cropCenterGuideVertical')), findsNothing);
  });
}
