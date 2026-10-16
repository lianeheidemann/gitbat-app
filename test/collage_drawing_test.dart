import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitbat/core/models/crop_rect.dart';
import 'package:gitbat/core/models/drawing_layer.dart';
import 'package:gitbat/core/ui/drawing/drawing_canvas.dart';
import 'package:gitbat/core/ui/drawing/photo_draw_page.dart';
import 'package:gitbat/core/ui/option_pill_button.dart';
import 'package:gitbat/features/collage/models/collage_background.dart';
import 'package:gitbat/features/collage/models/collage_cell.dart';
import 'package:gitbat/features/collage/models/collage_layout.dart';
import 'package:gitbat/features/collage/models/collage_settings.dart';
import 'package:gitbat/features/collage/services/collage_compositor.dart';

// O Pincel da Montagem mora no "..." de cada foto: o desenho é da foto,
// então acompanha recorte, espelho e troca de lugar, e sai na exportação
// pelo mesmo `paintDrawnImage` da prévia.

Future<void> _writeSolidPng(String path, int size, Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    Paint()..color = color,
  );
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

Future<List<int>> _pixel(Uint8List png, int x, int y) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  codec.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final i = (y * image.width + x) * 4;
  image.dispose();
  return data!.buffer.asUint8List().sublist(i, i + 4);
}

/// Faixa vertical em [x] (normalizado), de cima a baixo da foto.
DrawingStroke _band(DrawingTool tool, double x) => DrawingStroke(
  tool: tool,
  points: [Offset(x, 0), Offset(x, 1)],
  widthRatio: 0.2,
  color: const Color(0xFFFF0000),
);

void main() {
  late Directory tempDir;
  late String photoPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('collage_drawing_test');
    photoPath = '${tempDir.path}/azul.png';
    await _writeSolidPng(photoPath, 100, const Color(0xFF0000FF));
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  CollageSettings single(CollageCellSettings cell) => CollageSettings(
    layout: CollageLayout.row(1),
    aspectRatio: 1,
    background: const CollageBackground(
      mode: CollageBackgroundMode.color,
      color: Color(0xFF00FF00),
    ),
    cells: [cell],
  );

  group('exportação', () {
    test('o traço sai na foto e acompanha o espelho', () async {
      final cell = CollageCellSettings(
        photoPath: photoPath,
        photoWidth: 100,
        photoHeight: 100,
        drawing: DrawingLayer(strokes: [_band(DrawingTool.pen, 0.2)]),
      );
      final plain = await composeCollage(
        settings: single(cell),
        outputWidth: 100,
      );
      expect(await _pixel(plain, 20, 50), [255, 0, 0, 255]);
      expect(await _pixel(plain, 80, 50), [0, 0, 255, 255]);

      final flipped = await composeCollage(
        settings: single(cell.copyWith(flipHorizontal: true)),
        outputWidth: 100,
      );
      expect(await _pixel(flipped, 80, 50), [255, 0, 0, 255]);
      expect(await _pixel(flipped, 20, 50), [0, 0, 255, 255]);
    });

    test('o traço acompanha o recorte manual da foto', () async {
      // Só a metade direita da foto, em "encaixar": a faixa em x = 75% da
      // foto cai no meio do recorte.
      final cell = CollageCellSettings(
        photoPath: photoPath,
        photoWidth: 100,
        photoHeight: 100,
        manualCrop: const CropRect(x: 50, y: 0, width: 50, height: 100),
        fitMode: CollageCellFitMode.contain,
        drawing: DrawingLayer(strokes: [_band(DrawingTool.pen, 0.75)]),
      );
      final png = await composeCollage(
        settings: single(cell),
        outputWidth: 100,
      );
      expect(await _pixel(png, 50, 50), [255, 0, 0, 255]);
    });

    test('a transparência deixa ver o fundo da montagem', () async {
      final cell = CollageCellSettings(
        photoPath: photoPath,
        photoWidth: 100,
        photoHeight: 100,
        drawing: DrawingLayer(strokes: [_band(DrawingTool.cutout, 0.5)]),
      );
      final png = await composeCollage(
        settings: single(cell),
        outputWidth: 100,
      );
      expect(await _pixel(png, 50, 50), [0, 255, 0, 255]);
      expect(await _pixel(png, 10, 50), [0, 0, 255, 255]);
    });

    test('"Trocar com…" leva o desenho junto; o estilo compartilhado não o '
        'copia', () {
      final drawn = CollageCellSettings(
        photoPath: photoPath,
        photoWidth: 100,
        photoHeight: 100,
        drawing: DrawingLayer(strokes: [_band(DrawingTool.pen, 0.5)]),
      );
      final other = CollageCellSettings(
        photoPath: '${tempDir.path}/outra.png',
        photoWidth: 100,
        photoHeight: 100,
      );
      final settings = CollageSettings(
        layout: CollageLayout.row(2),
        cells: [drawn, other],
      );
      final swapped = settings.swappingCells(0, 1);
      expect(swapped.cells[1].drawing.isNotEmpty, isTrue);
      expect(swapped.cells[0].drawing.isEmpty, isTrue);
      expect(settings.withSharedCellStyle(other).drawing.isEmpty, isTrue);
      expect(drawn.resetFraming().drawing.isNotEmpty, isTrue);
    });
  });

  group('tela do Pincel', () {
    Future<void> pump(WidgetTester tester, {required bool transparency}) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute<DrawingLayer>(
                        builder: (_) => PhotoDrawPage(
                          photoPath: photoPath,
                          photoWidth: 100,
                          photoHeight: 100,
                          allowTransparency: transparency,
                        ),
                      ),
                    );
                    _lastResult = result;
                  },
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('foto animada: sem transparência', (tester) async {
      await pump(tester, transparency: false);
      expect(find.widgetWithText(OptionPillButton, 'Pintar'), findsOneWidget);
      expect(find.widgetWithText(OptionPillButton, 'Borracha'), findsOneWidget);
      expect(
        find.widgetWithText(OptionPillButton, 'Transparência'),
        findsNothing,
      );
    });

    testWidgets('desenhar e "Usar" devolve o desenho', (tester) async {
      _lastResult = null;
      await pump(tester, transparency: true);
      expect(
        find.widgetWithText(OptionPillButton, 'Transparência'),
        findsOneWidget,
      );
      final center = tester.getCenter(find.byType(DrawingCanvas));
      final gesture = await tester.startGesture(center);
      await tester.pump();
      await gesture.moveTo(center + const Offset(40, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('photoDrawDone')));
      await tester.pumpAndSettle();
      expect(_lastResult, isNotNull);
      expect(_lastResult!.strokes, hasLength(1));
    });

    testWidgets('sair com alterações pergunta antes de descartar', (
      tester,
    ) async {
      await pump(tester, transparency: true);
      final center = tester.getCenter(find.byType(DrawingCanvas));
      await tester.dragFrom(center, const Offset(40, 0));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Descartar desenho?'), findsOneWidget);
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoDrawPage), findsNothing);
    });
  });
}

DrawingLayer? _lastResult;
