import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gitbat/core/models/crop_rect.dart';
import 'package:gitbat/core/models/drawing_layer.dart';
import 'package:gitbat/core/models/frame_settings.dart';
import 'package:gitbat/core/models/photo_info.dart';
import 'package:gitbat/core/services/opaque_bounds.dart';
import 'package:gitbat/core/ui/drawing/drawing_canvas.dart';
import 'package:gitbat/core/ui/drawing/eraser_glyph.dart';
import 'package:gitbat/core/ui/option_pill_button.dart';
import 'package:gitbat/features/photo/photo_frame_page.dart';
import 'package:gitbat/features/photo/services/photo_frame_compositor.dart';
import 'package:gitbat/features/photo/widgets/eraser_mask_overlay.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

// A aba "Pincel" de "Editar imagem": o desenho fica preso à foto, entra no
// desfazer da tela e sai no PNG salvo — inclusive a transparência.

Future<void> _writeSolidPng(String path, int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF3366AA),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Future<(int, int, Uint8List)> _decode(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  codec.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final result = (image.width, image.height, data!.buffer.asUint8List());
  image.dispose();
  return result;
}

List<int> _rgbaAt((int, int, Uint8List) d, int x, int y) {
  final i = (y * d.$1 + x) * 4;
  return d.$3.sublist(i, i + 4);
}

/// Faixa horizontal de [tool] na altura [y] (normalizada) da foto.
DrawingStroke _band(DrawingTool tool, double y, {double width = 0.2}) =>
    DrawingStroke(
      tool: tool,
      points: [Offset(0, y), Offset(1, y)],
      widthRatio: width,
      color: const Color(0xFFFF0000),
    );

void main() {
  late Directory tempDir;
  late PhotoInfo photo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('drawing_tab_test');
    final path = '${tempDir.path}/foto.png';
    await _writeSolidPng(path, 100, 100);
    photo = PhotoInfo(path: path, width: 100, height: 100);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('exportação', () {
    test('o desenho sai no PNG, preso à foto e já recortado', () async {
      final png = await composeFramedPhoto(
        photo: photo,
        frame: FrameSettings(
          // Só a metade de baixo da foto; a faixa vermelha está em 75%.
          crop: const CropRect(x: 0, y: 50, width: 100, height: 50),
          drawing: DrawingLayer(strokes: [_band(DrawingTool.pen, 0.75)]),
        ),
      );
      final d = await _decode(png);
      expect((d.$1, d.$2), (100, 50));
      // y = 75 da foto vira y = 25 do recorte.
      expect(_rgbaAt(d, 50, 25), [255, 0, 0, 255]);
      expect(_rgbaAt(d, 50, 2), [0x33, 0x66, 0xAA, 255]);
    });

    test('a transparência sai transparente — ou na cor do fundo', () async {
      final drawing = DrawingLayer(strokes: [_band(DrawingTool.cutout, 0.5)]);
      final transparent = await _decode(
        await composeFramedPhoto(
          photo: photo,
          frame: FrameSettings(drawing: drawing),
        ),
      );
      expect(_rgbaAt(transparent, 50, 50)[3], 0);
      expect(_rgbaAt(transparent, 50, 10)[3], 255);

      final colored = await _decode(
        await composeFramedPhoto(
          photo: photo,
          frame: FrameSettings(
            drawing: drawing,
            transparentBackground: false,
            backgroundColor: const Color(0xFF00FF00),
          ),
        ),
      );
      expect(_rgbaAt(colored, 50, 50), [0, 255, 0, 255]);
    });

    test('"Ajustar" mede a foto já com a transparência', () async {
      // Apaga as faixas de cima e de baixo: sobra o meio.
      final bounds = await detectOpaqueBounds(
        photo.path,
        drawing: DrawingLayer(
          strokes: [
            _band(DrawingTool.cutout, 0, width: 0.4),
            _band(DrawingTool.cutout, 1, width: 0.4),
          ],
        ),
      );
      expect(bounds, isNotNull);
      expect(bounds!.y, inInclusiveRange(19, 21));
      expect(bounds.y + bounds.height, inInclusiveRange(79, 81));
      expect(bounds.width, 100);
    });
  });

  group('aba', () {
    Future<void> pumpPage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: PhotoFramePage(photo: photo)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pincel'));
      await tester.pumpAndSettle();
    }

    DrawingCanvas canvas(WidgetTester tester) =>
        tester.widget<DrawingCanvas>(find.byType(DrawingCanvas));

    Future<void> drawStroke(WidgetTester tester) async {
      final center = tester.getCenter(find.byType(DrawingCanvas));
      final gesture = await tester.startGesture(center);
      await tester.pump();
      for (var i = 1; i <= 4; i++) {
        await gesture.moveTo(center + Offset(i * 12.0, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('três grupos na linha de cima, com a Borracha dentro do '
        'Pincel', (tester) async {
      await pumpPage(tester);
      expect(find.byType(DrawingCanvas), findsOneWidget);
      // Pincel, Transparência e Borracha mágica; a Borracha não é um deles.
      for (final label in ['Pincel', 'Transparência', 'Borracha mágica']) {
        expect(find.widgetWithText(OptionPillButton, label), findsOneWidget);
      }
      final row = find.byKey(const ValueKey('drawingToolRow'));
      expect(
        find.descendant(
          of: row,
          matching: find.widgetWithText(OptionPillButton, 'Borracha'),
        ),
        findsNothing,
      );
      // Já a subopção Pintar / Borracha aparece com o Pincel escolhido, e a
      // Borracha tem o ícone desenhado de borracha.
      expect(find.widgetWithText(OptionPillButton, 'Pintar'), findsOneWidget);
      expect(find.widgetWithText(OptionPillButton, 'Borracha'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('drawingMode-eraser')),
          matching: find.byType(EraserGlyph),
        ),
        findsOneWidget,
      );
      // A foto aparece inteira, na orientação dela.
      expect(canvas(tester).sourceWidth, 100);
      expect(canvas(tester).sourceHeight, 100);
    });

    Future<void> tapKey(WidgetTester tester, String key) async {
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('a Borracha é subopção do Pincel: some nos outros grupos e '
        'volta ao modo em que estava', (tester) async {
      await pumpPage(tester);
      await tapKey(tester, 'drawingMode-eraser');
      await drawStroke(tester);
      expect(canvas(tester).layer.strokes.single.tool, DrawingTool.eraser);

      // Transparência e Borracha mágica não têm Pintar / Borracha.
      await tapKey(tester, 'drawingTool-cutout');
      expect(find.byKey(const ValueKey('drawingModeRow')), findsNothing);
      await tapKey(tester, 'drawingTool-magicEraser');
      expect(find.byKey(const ValueKey('drawingModeRow')), findsNothing);

      // Voltar ao Pincel traz de volta a Borracha, que era o modo dele.
      await tapKey(tester, 'drawingTool-pen');
      expect(find.byKey(const ValueKey('drawingModeRow')), findsOneWidget);
      final eraser = tester.widget<OptionPillButton>(
        find.byKey(const ValueKey('drawingMode-eraser')),
      );
      expect(eraser.selected, isTrue);
      // Cor e opacidade são só do Pintar.
      expect(find.byKey(const ValueKey('drawingColorRow')), findsNothing);
      await tapKey(tester, 'drawingMode-pen');
      expect(find.byKey(const ValueKey('drawingColorRow')), findsOneWidget);
    });

    testWidgets('arrastar desenha um traço, e desfazer o tira', (tester) async {
      await pumpPage(tester);
      expect(canvas(tester).layer.isEmpty, isTrue);

      await drawStroke(tester);
      final layer = canvas(tester).layer;
      expect(layer.strokes, hasLength(1));
      expect(layer.strokes.single.tool, DrawingTool.pen);
      // Pontos normalizados à foto, começando no centro dela.
      expect(layer.strokes.single.points.first.dx, closeTo(0.5, 0.02));
      expect(layer.strokes.single.points.first.dy, closeTo(0.5, 0.02));
      expect(find.text('1 traço'), findsOneWidget);

      await tester.tap(find.byTooltip('Desfazer'));
      await tester.pumpAndSettle();
      expect(canvas(tester).layer.isEmpty, isTrue);
    });

    Future<void> chooseMagicEraser(WidgetTester tester) async {
      final magic = find.byKey(const ValueKey('drawingTool-magicEraser'));
      await tester.ensureVisible(magic);
      await tester.pumpAndSettle();
      await tester.tap(magic);
      await tester.pumpAndSettle();
    }

    Future<void> choosePen(WidgetTester tester) async {
      final pen = find.byKey(const ValueKey('drawingTool-pen'));
      await tester.ensureVisible(pen);
      await tester.pumpAndSettle();
      await tester.tap(pen);
      await tester.pumpAndSettle();
    }

    testWidgets('a Borracha mágica troca a prévia e mantém o zoom', (
      tester,
    ) async {
      await pumpPage(tester);
      final zoom = canvas(tester).zoom!;
      zoom.value = (zoom: 2, pan: Offset.zero);
      await tester.pumpAndSettle();

      await chooseMagicEraser(tester);
      expect(find.byType(DrawingCanvas), findsNothing);
      final eraser = tester.widget<EraserCanvas>(find.byType(EraserCanvas));
      // O mesmo enquadramento: trocar de ferramenta não volta ao inteiro.
      expect(identical(eraser.zoom, zoom), isTrue);
      expect(zoom.isZoomed, isTrue);
      expect(find.text('Enquadrar'), findsOneWidget);
      // O resumo da aba passa a ser o da seleção.
      expect(find.text('Nenhuma seleção'), findsOneWidget);
      expect(find.text('Nenhum'), findsNothing);

      await choosePen(tester);
      expect(find.byType(EraserCanvas), findsNothing);
      expect(find.byType(DrawingCanvas), findsOneWidget);
      expect(zoom.isZoomed, isTrue);
      // O painel rola: o botão fica no fim dele.
      await tester.ensureVisible(find.text('Enquadrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enquadrar'));
      await tester.pumpAndSettle();
      expect(zoom.isZoomed, isFalse);
    });

    testWidgets('"Tentar de novo" some com um traço feito depois da apagada', (
      tester,
    ) async {
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _TempPaths(tempDir.path);
      addTearDown(() => PathProviderPlatform.instance = original);
      await pumpPage(tester);
      await chooseMagicEraser(tester);

      // Marca um ponto e apaga de verdade (Isolate: tempo real).
      final center = tester.getCenter(find.byType(EraserCanvas));
      await tester.tapAt(center);
      await tester.pumpAndSettle();
      final erase = find.widgetWithText(FilledButton, 'Apagar');
      await tester.ensureVisible(erase);
      await tester.pumpAndSettle();
      await tester.tap(erase);
      final retry = find.text('Tentar de novo');
      for (var i = 0; i < 200 && retry.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      expect(retry, findsOneWidget);

      // Um traço do Pincel depois: desfazer agora derrubaria o traço, não a
      // apagada — "Tentar de novo" some.
      await choosePen(tester);
      await drawStroke(tester);
      await chooseMagicEraser(tester);
      expect(retry, findsNothing);

      // Desfeito o traço, a apagada volta a ser o último passo.
      await tester.tap(find.byTooltip('Desfazer'));
      await tester.pumpAndSettle();
      expect(retry, findsOneWidget);
    });

    testWidgets('a ferramenta escolhida vale para o próximo traço', (
      tester,
    ) async {
      await pumpPage(tester);
      await tester.tap(find.widgetWithText(OptionPillButton, 'Transparência'));
      await tester.pumpAndSettle();
      await drawStroke(tester);
      expect(canvas(tester).layer.strokes.single.tool, DrawingTool.cutout);
      expect(canvas(tester).layer.hasCutout, isTrue);
    });
  });
}

/// A pasta temporária da Borracha mágica, sem o plugin de verdade.
class _TempPaths extends PathProviderPlatform {
  _TempPaths(this.dir);

  final String dir;

  @override
  Future<String?> getTemporaryPath() async => dir;
}
