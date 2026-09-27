import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gitbat/core/models/collage_sticker.dart';
import 'package:gitbat/core/models/frame_settings.dart';
import 'package:gitbat/core/models/photo_info.dart';
import 'package:gitbat/core/services/text_overlay_render.dart';
import 'package:gitbat/core/ui/sticker_overlay_editor.dart';
import 'package:gitbat/features/photo/photo_frame_page.dart';
import 'package:gitbat/features/photo/services/photo_frame_compositor.dart';
import 'package:gitbat/features/svg/models/svg_edit_settings.dart';
import 'package:gitbat/features/svg/models/svg_info.dart';
import 'package:gitbat/features/svg/services/svg_xml_editor.dart';
import 'package:xml/xml.dart';

// A aba "Stickers" da Montagem também em Editar imagem, Editar vídeo e
// Editar SVG — com a exportação de cada uma desenhando os stickers.

Future<Uint8List> _png(int w, int h, Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = color,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
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

int _rgbaAt((int, int, ByteData) d, int x, int y) =>
    d.$3.getUint32((y * d.$1 + x) * 4);

CollageSticker _imageSticker(String path) => CollageSticker(
  id: 's1',
  source: CollageStickerSource.importedImage,
  imageFilePath: path,
  centerX: 0.5,
  centerY: 0.5,
  scale: 1,
  zIndex: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('stickers'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('Editar imagem: o sticker sai na foto exportada', () async {
    final photoPath = '${dir.path}/foto.png';
    await File(
      photoPath,
    ).writeAsBytes(await _png(200, 100, const Color(0xFF0000FF)));
    final stickerPath = '${dir.path}/sticker.png';
    await File(
      stickerPath,
    ).writeAsBytes(await _png(10, 10, const Color(0xFF00FF00)));
    final png = await composeFramedPhoto(
      photo: PhotoInfo(path: photoPath, width: 200, height: 100),
      frame: FrameSettings(stickers: [_imageSticker(stickerPath)]),
    );
    final d = await _decode(png);
    expect(_rgbaAt(d, 100, 50), 0x00FF00FF, reason: 'sticker no centro');
    expect(_rgbaAt(d, 5, 5), 0x0000FFFF, reason: 'foto em volta');
  });

  test('Editar imagem sem borda: "Fundo transparente" desligado pinta a '
      'cor atrás da foto', () async {
    final photoPath = '${dir.path}/transparente.png';
    await File(
      photoPath,
    ).writeAsBytes(await _png(20, 10, const Color(0x00000000)));
    final png = await composeFramedPhoto(
      photo: PhotoInfo(path: photoPath, width: 20, height: 10),
      frame: const FrameSettings(
        transparentBackground: false,
        backgroundColor: Color(0xFFFF0000),
      ),
    );
    final d = await _decode(png);
    expect(_rgbaAt(d, 10, 5), 0xFF0000FF);
  });

  test('Editar imagem sem borda: "Fundo transparente" desligado pinta a '
      'cor atrás da foto', () async {
    final photoPath = '${dir.path}/transparente.png';
    await File(
      photoPath,
    ).writeAsBytes(await _png(20, 10, const Color(0x00000000)));
    final png = await composeFramedPhoto(
      photo: PhotoInfo(path: photoPath, width: 20, height: 10),
      frame: const FrameSettings(
        transparentBackground: false,
        backgroundColor: Color(0xFFFF0000),
      ),
    );
    final d = await _decode(png);
    expect(_rgbaAt(d, 10, 5), 0xFF0000FF);
  });

  test('Editar imagem com borda: o miolo transparente continua '
      'transparente', () async {
    final photoPath = '${dir.path}/transparente.png';
    await File(
      photoPath,
    ).writeAsBytes(await _png(200, 100, const Color(0x00000000)));
    final png = await composeFramedPhoto(
      photo: PhotoInfo(path: photoPath, width: 200, height: 100),
      frame: const FrameSettings(
        style: FrameStyle.medium,
        color: Color(0xFF00FF00),
        thicknessAtReference: 20,
      ),
    );
    final d = await _decode(png);
    expect(_rgbaAt(d, 100, 50) & 0xFF, 0, reason: 'miolo transparente');
    expect(_rgbaAt(d, 2, 50), 0x00FF00FF, reason: 'anel da borda');
  });

  test('Editar vídeo: o sticker entra na camada sobreposta', () async {
    final stickerPath = '${dir.path}/sticker.png';
    await File(
      stickerPath,
    ).writeAsBytes(await _png(10, 10, const Color(0xFF00FF00)));
    final layer = await renderTextOverlayLayer(
      const [],
      200,
      100,
      stickers: [_imageSticker(stickerPath)],
    );
    final d = await _decode(layer);
    expect(_rgbaAt(d, 100, 50), 0x00FF00FF);
    expect(_rgbaAt(d, 5, 5) & 0xFF, 0, reason: 'transparente em volta');
  });

  group('Editar SVG', () {
    const source =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100">'
        '<defs><linearGradient id="g"/></defs>'
        '<rect width="10" height="10" fill="url(#g)"/></svg>';
    const info = SvgInfo(path: '', width: 200, height: 100);

    test('sticker vetorial entra como <svg> aninhado, com ids próprios', () {
      const sticker = CollageSticker(
        id: 's1',
        source: CollageStickerSource.bundledSvg,
        assetPath: 'x.svg',
        centerX: 0.5,
        centerY: 0.5,
        zIndex: 0,
      );
      final xml = renderEditedSvg(
        source,
        info,
        const SvgEditSettings(stickers: [sticker]),
        stickerArt: {
          's1': const StickerSvgArt.vector(
            '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24">'
            '<defs><linearGradient id="g"/></defs>'
            '<circle cx="12" cy="12" r="10" fill="url(#g)"/></svg>',
          ),
        },
      );
      final root = XmlDocument.parse(xml).rootElement;
      final nested = root.descendantElements
          .where((e) => e.name.local == 'svg')
          .single;
      expect(nested.getAttribute('viewBox'), '0 0 24 24');
      // Lado = 100 (menor lado) × 0,28 = 28, centrado em (100, 50).
      expect(nested.getAttribute('width'), '28');
      final group = nested.parentElement!;
      expect(group.getAttribute('transform'), 'translate(100 50)');
      final circle = nested.descendantElements.firstWhere(
        (e) => e.name.local == 'circle',
      );
      expect(circle.getAttribute('fill'), 'url(#stk0_g)');
      // O gradiente do SVG principal continua com o id dele.
      expect(xml, contains('fill="url(#g)"'));
    });

    test('sticker em imagem entra como <image> com data URI', () {
      final xml = renderEditedSvg(
        source,
        info,
        SvgEditSettings(stickers: [_imageSticker('/x.png')]),
        stickerArt: {
          's1': StickerSvgArt.raster(
            Uint8List.fromList([1, 2, 3]),
            'image/png',
          ),
        },
      );
      expect(xml, contains('href="data:image/png;base64,AQID"'));
    });
  });

  testWidgets('Editar imagem: aba "Stickers" acrescenta o sticker na prévia', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final photoPath = '${dir.path}/foto.png';
    await tester.runAsync(
      () async => File(
        photoPath,
      ).writeAsBytes(await _png(200, 100, const Color(0xFF0000FF))),
    );
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoFramePage(
          photo: PhotoInfo(path: photoPath, width: 200, height: 100),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tab = find.text('Stickers').last;
    await tester.ensureVisible(tab);
    await tester.pumpAndSettle();
    await tester.tap(tab);
    await tester.pumpAndSettle();
    expect(find.byType(StickerOverlayPanel), findsOneWidget);

    final stack = find.byType(StickerOverlayStack);
    expect(tester.widget<StickerOverlayStack>(stack).stickers, isEmpty);
    // Primeira arte da pasta aberta ("Reações", embutida).
    await tester.tap(
      find
          .descendant(
            of: find.byType(StickerOverlayPanel),
            matching: find.byType(SvgPicture),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<StickerOverlayStack>(stack).stickers, hasLength(1));
    // Selecionado, com as alças (inclusive a de remover).
    final remove = find.byKey(const ValueKey('stickerRemoveHandle'));
    expect(remove, findsOneWidget);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(tester.widget<StickerOverlayStack>(stack).stickers, isEmpty);
  });
}
