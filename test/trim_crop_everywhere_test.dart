import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_to_gif/core/models/crop_rect.dart';
import 'package:video_to_gif/core/ui/crop/crop_overlay.dart';
import 'package:video_to_gif/core/ui/crop/photo_crop_page.dart';
import 'package:video_to_gif/features/svg/models/svg_info.dart';
import 'package:video_to_gif/features/svg/svg_edit_page.dart';

// "Ajustar" (cortar só a margem transparente) também em "Editar SVG" e no
// recorte de foto da Montagem.

/// Toca no chip e alterna espera real e redesenho — ler o arquivo,
/// decodificar/rasterizar e varrer só avançam com tempo de verdade.
Future<void> _tapTrim(WidgetTester tester) async {
  final chip = find.text('Ajustar');
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

CropRect? _crop(WidgetTester tester) =>
    tester.widget<CropOverlay>(find.byType(CropOverlay)).crop;

void main() {
  late Directory dir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('trim_everywhere');
  });

  tearDown(() => dir.delete(recursive: true));

  testWidgets('Editar SVG: "Ajustar" encosta no desenho', (tester) async {
    final path = '${dir.path}/a.svg';
    await tester.runAsync(
      () => File(path).writeAsString(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100" '
        'width="200" height="100">'
        '<rect x="40" y="20" width="60" height="50" fill="#ff0000"/>'
        '</svg>',
      ),
    );
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SvgEditPage(svg: SvgInfo(path: path, width: 200, height: 100)),
      ),
    );
    await tester.pumpAndSettle();

    await _tapTrim(tester);
    final crop = _crop(tester)!;
    // A rasterização suaviza as bordas do desenho, então o recorte pode
    // sobrar 1–2 px para fora — nunca cortar o desenho.
    expect(crop.x, inInclusiveRange(38, 40));
    expect(crop.y, inInclusiveRange(18, 20));
    expect(crop.x + crop.width, inInclusiveRange(100, 102));
    expect(crop.y + crop.height, inInclusiveRange(70, 72));
  });

  testWidgets('Montagem (Recortar foto): "Ajustar" encosta no desenho', (
    tester,
  ) async {
    final path = '${dir.path}/a.png';
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(30, 10, 50, 40),
        Paint()..color = const Color(0xFF00FF00),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(120, 80);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(path).writeAsBytes(bytes!.buffer.asUint8List());
    });
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoCropPage(
          photoPath: path,
          photoWidth: 120,
          photoHeight: 80,
          cellAspectRatio: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapTrim(tester);
    final crop = _crop(tester)!;
    expect((crop.x, crop.y, crop.width, crop.height), (30, 10, 50, 40));
  });
}
