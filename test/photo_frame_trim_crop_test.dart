import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gitbat/core/models/photo_info.dart';
import 'package:gitbat/core/ui/crop/crop_overlay.dart';
import 'package:gitbat/features/photo/photo_frame_page.dart';

/// PNG [size]x[size] transparente com um quadrado opaco em [content].
Future<void> _writePng(String path, int size, Rect? content) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (content != null) {
    canvas.drawRect(content, Paint()..color = const Color(0xFF3366AA));
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('trim_crop_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> pumpPage(WidgetTester tester, Rect? content) async {
    final path = '${tempDir.path}/foto.png';
    await tester.runAsync(() => _writePng(path, 200, content));
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
  }

  /// Toca no chip e deixa a decodificação/varredura (assíncronas de
  /// verdade) terminarem antes de redesenhar.
  Future<void> tapTrim(WidgetTester tester) async {
    final chip = find.text('Ajustar');
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    // Cada etapa (ler o arquivo, decodificar, varrer no isolate) só avança
    // com tempo real, então alterna espera de verdade e redesenho.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('encosta o recorte nos pixels visíveis', (tester) async {
    await pumpPage(tester, const Rect.fromLTWH(30, 50, 100, 60));
    await tapTrim(tester);

    final crop = tester.widget<CropOverlay>(find.byType(CropOverlay)).crop!;
    expect((crop.x, crop.y, crop.width, crop.height), (30, 50, 100, 60));
    expect(find.textContaining('100×60'), findsWidgets);
  });

  testWidgets('avisa quando não há margem transparente', (tester) async {
    await pumpPage(tester, const Rect.fromLTWH(0, 0, 200, 200));
    await tapTrim(tester);

    expect(
      find.text('A imagem não tem bordas transparentes para remover.'),
      findsOneWidget,
    );
    expect(tester.widget<CropOverlay>(find.byType(CropOverlay)).crop, isNull);
  });
}
