import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitbat/core/ui/editor_tabs_footer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gitbat/core/models/collage_text.dart';
import 'package:gitbat/core/models/crop_rect.dart';
import 'package:gitbat/core/models/photo_info.dart';
import 'package:gitbat/core/ui/crop/crop_controller.dart';
import 'package:gitbat/core/ui/crop/crop_overlay.dart';
import 'package:gitbat/features/photo/photo_frame_page.dart';

// "Tamanho da janela" (1–100% da maior janela do mesmo formato), "Centralizar"
// (move sem redimensionar) e "Tamanho da fonte" (1–80) das abas de edição.

Future<PhotoInfo> _photo(Directory dir) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 400, 200),
    Paint()..color = const Color(0xFF3366AA),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(400, 200);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  final path = '${dir.path}/foto.png';
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  return PhotoInfo(path: path, width: 400, height: 200);
}

void main() {
  group('CropController: tamanho da janela e centralizar', () {
    final foto = CropController(sourceWidth: 400, sourceHeight: 200);
    final video = CropController(
      sourceWidth: 1920,
      sourceHeight: 1080,
      evenOnly: true,
      accumulateDragRemainder: false,
    );

    test('100% é a maior janela do mesmo formato que cabe', () {
      const square = CropRect(x: 10, y: 10, width: 50, height: 50);
      expect(foto.sizePercentOf(square), 25);
      final full = foto.scaledTo(100, crop: square);
      expect((full.width, full.height), (200, 200));
      expect(foto.sizePercentOf(full), 100);
    });

    test('muda o tamanho mantendo formato e centro', () {
      const crop = CropRect(x: 100, y: 50, width: 200, height: 100);
      final half = foto.scaledTo(50, crop: crop);
      expect((half.width, half.height), (200, 100));
      final quarter = foto.scaledTo(25, crop: crop);
      expect((quarter.width, quarter.height), (100, 50));
      expect(quarter.x + quarter.width / 2, crop.x + crop.width / 2);
      expect(quarter.y + quarter.height / 2, crop.y + crop.height / 2);
    });

    test('perto da borda, cresce encostando nela em vez de sair', () {
      const corner = CropRect(x: 0, y: 0, width: 40, height: 40);
      final grown = foto.scaledTo(100, crop: corner);
      expect((grown.x, grown.y, grown.width, grown.height), (0, 0, 200, 200));
    });

    test('no vídeo continua com lados pares', () {
      const crop = CropRect(x: 0, y: 0, width: 1080, height: 1080);
      final scaled = video.scaledTo(33, crop: crop);
      expect(scaled.width.isEven && scaled.height.isEven, isTrue);
    });

    test('"Centralizar" leva para o centro sem mudar o tamanho', () {
      const crop = CropRect(x: 0, y: 0, width: 120, height: 80);
      final centered = foto.centered(crop);
      expect(
        (centered.x, centered.y, centered.width, centered.height),
        (140, 60, 120, 80),
      );
    });
  });

  group('CollageTextItem: tamanho da fonte', () {
    const item = CollageTextItem(
      id: 't',
      text: 'oi',
      centerX: 0.5,
      centerY: 0.5,
      zIndex: 0,
    );

    test('o texto novo aparece como 35 e a alça entra na conta', () {
      expect(item.fontSizePoints, 35);
      expect(item.copyWith(scale: 2).fontSizePoints, 70);
      expect(item.copyWith(scale: 4).fontSizePoints, 80);
    });

    test('o controle grava o tamanho e zera a escala da alça', () {
      final next = item.copyWith(scale: 2).withFontSizePoints(12);
      expect(next.fontSizePoints, 12);
      expect(next.scale, 1);
      expect(item.withFontSizePoints(0).fontSizePoints, 1);
      expect(item.withFontSizePoints(200).fontSizePoints, 80);
    });
  });

  group('"Editar imagem"', () {
    Future<void> pumpPage(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final dir = await tester.runAsync(
        () => Directory.systemTemp.createTemp('crop_text_controls'),
      );
      addTearDown(() => dir!.delete(recursive: true));
      final photo = await tester.runAsync(() => _photo(dir!));
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: PhotoFramePage(photo: photo!)));
      await tester.pumpAndSettle();
    }

    CropRect crop(WidgetTester tester) =>
        tester.widget<CropOverlay>(find.byType(CropOverlay)).crop!;

    testWidgets('"Tamanho da janela" e "Centralizar" no Recorte', (
      tester,
    ) async {
      await pumpPage(tester);
      await tester.tap(find.text('1:1'));
      await tester.pumpAndSettle();
      expect((crop(tester).width, crop(tester).height), (200, 200));

      final sliderFinder = find.byKey(const ValueKey('cropSizeSlider'));
      await tester.ensureVisible(sliderFinder);
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(sliderFinder);
      expect((slider.min, slider.max, slider.value), (1, 100, 100));
      slider.onChangeStart!(slider.value);
      slider.onChanged!(50);
      await tester.pumpAndSettle();
      expect((crop(tester).width, crop(tester).height), (100, 100));
      expect(find.text('50%'), findsOneWidget);

      expect(find.text('Centralizar e redefinir'), findsNothing);
      final center = find.text('Centralizar');
      await tester.ensureVisible(center);
      await tester.pumpAndSettle();
      await tester.tap(center);
      await tester.pumpAndSettle();
      final after = crop(tester);
      expect(
        (after.x, after.y, after.width, after.height),
        (150, 50, 100, 100),
        reason: 'centraliza mantendo o tamanho escolhido',
      );
    });

    testWidgets('"Tamanho da fonte" no Texto', (tester) async {
      await pumpPage(tester);
      // Com a aba "Stickers" a barra ficou mais longa: "Texto" pode estar
      // fora da tela.
      await _showTab(tester, 'Texto');
      await tester.tap(find.text('Texto').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'oi');
      await tester.pump();
      await tester.tap(find.byTooltip('Adicionar texto'));
      await tester.pumpAndSettle();

      final sliderFinder = find.byKey(const ValueKey('textFontSizeSlider'));
      await tester.ensureVisible(sliderFinder);
      await tester.pumpAndSettle();
      Slider slider() => tester.widget<Slider>(sliderFinder);
      expect((slider().min, slider().max, slider().value), (1, 80, 35));
      slider().onChangeStart!(slider().value);
      slider().onChanged!(8);
      await tester.pumpAndSettle();
      expect(slider().value, 8);
    });
  });
}

/// Rola a barra de abas até [label] aparecer (as abas do fim ficam fora da
/// tela e a lista só constrói o que está visível).
Future<void> _showTab(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    120,
    scrollable: find
        .descendant(
          of: find.byType(EditorTabsFooter),
          matching: find.byType(Scrollable),
        )
        .last,
  );
  await tester.pumpAndSettle();
}
