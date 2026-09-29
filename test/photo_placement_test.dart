import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gitbat/core/models/frame_settings.dart';
import 'package:gitbat/core/models/photo_info.dart';
import 'package:gitbat/core/models/photo_placement.dart';
import 'package:gitbat/features/photo/photo_frame_page.dart';
import 'package:gitbat/features/photo/services/photo_frame_compositor.dart';
import 'package:gitbat/core/ui/photo_placement_view.dart';

/// PNG 80x40: metade esquerda vermelha, direita azul.
Future<PhotoInfo> _photo(Directory dir) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 40, 40),
    Paint()..color = const Color(0xFFFF0000),
  );
  canvas.drawRect(
    const Rect.fromLTWH(40, 0, 40, 40),
    Paint()..color = const Color(0xFF0000FF),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(80, 40);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  final path = '${dir.path}/foto.png';
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  return PhotoInfo(path: path, width: 80, height: 40);
}

Future<(int, int, ByteData)> _decode(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final result = (image.width, image.height, data!);
  image.dispose();
  codec.dispose();
  return result;
}

/// RGBA do pixel em ([x], [y]).
int _rgbaAt((int, int, ByteData) d, int x, int y) =>
    d.$3.getUint32((y * d.$1 + x) * 4);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('travas', () {
    test('perto do centro, do 100% e do ângulo reto, gruda', () {
      final s = PhotoPlacementView.snapped(
        const PhotoPlacement(dx: 0.01, dy: -0.015, scale: 1.02, rotation: 0.05),
      );
      expect((s.dx, s.dy, s.scale, s.rotation), (0.0, 0.0, 1.0, 0.0));
      final right = PhotoPlacementView.snapped(
        const PhotoPlacement(rotation: math.pi / 2 + 0.03),
      );
      expect(right.rotation, closeTo(math.pi / 2, 1e-9));
    });

    test('longe, fica onde está', () {
      const free = PhotoPlacement(dx: 0.2, dy: -0.1, scale: 1.5, rotation: 0.4);
      expect(PhotoPlacementView.snapped(free), free);
    });
  });

  group('exportação', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('placement'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('diminuir deixa as bordas transparentes', () async {
      final photo = await _photo(dir);
      final png = await composeFramedPhoto(
        photo: photo,
        frame: const FrameSettings(placement: PhotoPlacement(scale: 0.5)),
      );
      final d = await _decode(png);
      expect((d.$1, d.$2), (80, 40));
      expect(_rgbaAt(d, 2, 2) & 0xFF, 0, reason: 'canto sem foto');
      expect(_rgbaAt(d, 30, 20), 0xFF0000FF, reason: 'vermelho encolhido');
      expect(_rgbaAt(d, 50, 20), 0x0000FFFF, reason: 'azul encolhido');
    });

    test('mover e girar 180° troca os lados', () async {
      final photo = await _photo(dir);
      final png = await composeFramedPhoto(
        photo: photo,
        frame: const FrameSettings(
          placement: PhotoPlacement(rotation: math.pi),
        ),
      );
      final d = await _decode(png);
      expect(_rgbaAt(d, 10, 20), 0x0000FFFF);
      expect(_rgbaAt(d, 70, 20), 0xFF0000FF);
    });
  });

  testWidgets('Editar imagem: arrastar a foto na prévia a move e dois '
      'toques voltam ao centro', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('placement_page');
    addTearDown(() => dir.deleteSync(recursive: true));
    final photo = (await tester.runAsync(() => _photo(dir)))!;
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: PhotoFramePage(photo: photo)));
    await tester.pumpAndSettle();

    // Na aba "Recorte" a prévia é a das alças; em "Girar", a foto.
    await tester.tap(find.text('Girar').last);
    await tester.pumpAndSettle();
    PhotoPlacement placement() => tester
        .widget<PhotoPlacementView>(find.byType(PhotoPlacementView))
        .placement;
    final area = find.byKey(const ValueKey('photoPlacementGesture'));
    expect(area, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(area));
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(placement().dx, greaterThan(0));
    expect(placement().dy, 0, reason: 'na vertical ficou no centro');
    expect(
      find.byKey(const ValueKey('photoCenterGuideHorizontal')),
      findsOneWidget,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('photoCenterGuideHorizontal')),
      findsNothing,
    );

    // Desfazer volta o arrasto inteiro.
    await tester.tap(find.byTooltip('Desfazer'));
    await tester.pumpAndSettle();
    expect(placement(), PhotoPlacement.identity);
    await tester.tap(find.byTooltip('Refazer'));
    await tester.pumpAndSettle();
    expect(placement().dx, greaterThan(0));

    await tester.tap(area);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(area);
    await tester.pumpAndSettle();
    expect(placement(), PhotoPlacement.identity);
  });

  testWidgets('Editar imagem: tocar na foto mostra alças; a de '
      'redimensionar aumenta com um dedo e a de girar gira', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('placement_handles');
    addTearDown(() => dir.deleteSync(recursive: true));
    final photo = (await tester.runAsync(() => _photo(dir)))!;
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: PhotoFramePage(photo: photo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Girar').last);
    await tester.pumpAndSettle();

    PhotoPlacement placement() => tester
        .widget<PhotoPlacementView>(find.byType(PhotoPlacementView))
        .placement;
    final resize = find.byKey(const ValueKey('photoResizeHandle'));
    expect(resize, findsNothing);
    await tester.tap(find.byKey(const ValueKey('photoPlacementGesture')));
    // O toque simples só vale depois do tempo de um toque duplo.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(resize, findsOneWidget);
    expect(find.byKey(const ValueKey('photoRotateHandle')), findsOneWidget);

    // Puxar a alça de canto para dentro diminui a foto.
    await tester.drag(resize, const Offset(-160, -90));
    await tester.pumpAndSettle();
    expect(placement().scale, lessThan(0.9));

    // Arrastar a foto na vertical também a move (a rolagem da página não
    // pode roubar o gesto).
    final before = placement().dy;
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('photoPlacementGesture'))),
    );
    for (var i = 0; i < 6; i++) {
      await g.moveBy(const Offset(0, 10));
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(placement().dy, greaterThan(before));

    final rotate = find.byKey(const ValueKey('photoRotateHandle'));
    await tester.drag(rotate, const Offset(0, 80));
    await tester.pumpAndSettle();
    expect(placement().rotation, isNot(0));
  });
}
