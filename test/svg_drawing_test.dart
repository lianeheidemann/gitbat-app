import 'dart:io';
import 'dart:ui' show Color, Offset;

import 'package:flutter/material.dart' show MaterialApp, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:gitbat/core/models/crop_rect.dart';
import 'package:gitbat/core/models/drawing_layer.dart';
import 'package:gitbat/core/ui/drawing/drawing_canvas.dart';
import 'package:gitbat/core/ui/option_pill_button.dart';
import 'package:gitbat/features/svg/models/svg_edit_settings.dart';
import 'package:gitbat/features/svg/models/svg_info.dart';
import 'package:gitbat/features/svg/services/svg_xml_editor.dart';
import 'package:gitbat/features/svg/svg_edit_page.dart';
import 'package:xml/xml.dart';

// O Pincel do "Editar SVG" sai vetorial: `<path>` dentro do grupo de
// conteúdo (recorte, giro e o resto o alcançam como alcançam a arte) e a
// borracha como `<mask>`, só sobre o que foi pintado antes dela.

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 80" '
    'width="120" height="80"><rect x="10" y="10" width="20" height="20"/>'
    '</svg>';

const _info = SvgInfo(path: '', width: 120, height: 80);

DrawingStroke _stroke(
  DrawingTool tool,
  List<Offset> points, {
  Color color = const Color(0xFFFF0000),
}) => DrawingStroke(tool: tool, points: points, widthRatio: 0.05, color: color);

final _line = _stroke(DrawingTool.pen, const [Offset(0, 0.5), Offset(1, 0.5)]);

XmlElement _render(SvgEditSettings settings, {String source = _svg}) =>
    XmlDocument.parse(renderEditedSvg(source, _info, settings)).rootElement;

XmlElement _contentGroup(XmlElement root) => root.childElements.firstWhere(
  (e) => e.name.local == 'g' && e.getAttribute('data-svgedit') == '1',
);

XmlElement _drawingGroup(XmlElement root) => root.descendantElements.firstWhere(
  (e) => e.getAttribute('data-svgedit-drawing') == '1',
);

void main() {
  group('applyDrawingSvg', () {
    test('sem desenho o documento não ganha grupo nenhum', () {
      final root = _render(const SvgEditSettings());
      expect(root.childElements.map((e) => e.name.local), ['rect']);
    });

    test('o traço vira um <path> em coordenadas do viewBox, por cima da '
        'arte e dentro do grupo de conteúdo', () {
      final root = _render(
        SvgEditSettings(drawing: DrawingLayer(strokes: [_line])),
      );
      final content = _contentGroup(root);
      expect(content.childElements.first.name.local, 'rect');
      final drawing = content.childElements.last;
      expect(drawing.getAttribute('data-svgedit-drawing'), '1');
      final path = drawing.childElements.single;
      expect(path.name.local, 'path');
      expect(path.getAttribute('d'), 'M0 40L120 40');
      expect(path.getAttribute('stroke'), '#ff0000');
      // 5% do menor lado (80).
      expect(path.getAttribute('stroke-width'), '4');
      expect(path.getAttribute('stroke-linecap'), 'round');
      expect(path.getAttribute('stroke-linejoin'), 'round');
      expect(path.getAttribute('fill'), 'none');
      expect(path.getAttribute('stroke-opacity'), isNull);
    });

    test('um toque vira círculo, e a opacidade sai no atributo', () {
      final root = _render(
        SvgEditSettings(
          drawing: DrawingLayer(
            strokes: [
              _stroke(DrawingTool.pen, const [
                Offset(0.5, 0.5),
              ], color: const Color(0x80000000)),
            ],
          ),
        ),
      );
      final circle = _drawingGroup(root).childElements.single;
      expect(circle.name.local, 'circle');
      expect(circle.getAttribute('cx'), '60');
      expect(circle.getAttribute('cy'), '40');
      expect(circle.getAttribute('r'), '2');
      expect(
        double.parse(circle.getAttribute('fill-opacity')!),
        closeTo(0.5, 0.01),
      );
    });

    test('a borracha só apaga o que foi pintado antes dela', () {
      final p1 = _line;
      final b1 = _stroke(DrawingTool.eraser, const [Offset(0.5, 0.5)]);
      final p2 = _stroke(DrawingTool.pen, const [Offset(0.2, 0.2)]);
      final b2 = _stroke(DrawingTool.eraser, const [Offset(0.2, 0.2)]);
      final b3 = _stroke(DrawingTool.eraser, const [Offset(0.3, 0.3)]);
      final p3 = _stroke(DrawingTool.pen, const [Offset(0.9, 0.9)]);
      final root = _render(
        SvgEditSettings(
          drawing: DrawingLayer(strokes: [p1, b1, p2, b2, b3, p3]),
        ),
      );

      // ((p1 − b1), p2) − (b2 + b3), p3
      final drawing = _drawingGroup(root);
      final outer = drawing.childElements.toList();
      expect(outer, hasLength(2));
      expect(outer[0].getAttribute('mask'), 'url(#svgedit-draw-mask-1)');
      expect(outer[1].name.local, 'circle'); // p3, fora das máscaras
      final middle = outer[0].childElements.toList();
      expect(middle, hasLength(2));
      expect(middle[0].getAttribute('mask'), 'url(#svgedit-draw-mask-0)');
      expect(middle[0].childElements.single.name.local, 'path'); // p1
      expect(middle[1].name.local, 'circle'); // p2

      final defs = root.childElements.firstWhere((e) => e.name.local == 'defs');
      final masks = defs.childElements.toList();
      expect(masks.map((m) => m.getAttribute('id')), [
        'svgedit-draw-mask-0',
        'svgedit-draw-mask-1',
      ]);
      expect(masks[0].getAttribute('maskUnits'), 'userSpaceOnUse');
      // Fundo branco (mantém) e a borracha em preto (apaga).
      expect(masks[0].childElements.first.getAttribute('fill'), '#ffffff');
      expect(masks[0].childElements.last.getAttribute('fill'), '#000000');
      // As duas borrachas seguidas dividem a mesma máscara.
      expect(masks[1].childElements, hasLength(3));
    });

    test('borracha antes de pintar e transparência não geram nada', () {
      final root = _render(
        SvgEditSettings(
          drawing: DrawingLayer(
            strokes: [
              _stroke(DrawingTool.eraser, const [Offset(0.5, 0.5)]),
              _stroke(DrawingTool.cutout, const [Offset(0.5, 0.5)]),
              _line,
            ],
          ),
        ),
      );
      expect(root.findAllElements('mask'), isEmpty);
      expect(_drawingGroup(root).childElements.single.name.local, 'path');
    });

    test('o desenho acompanha recorte e giro, como a arte', () {
      final root = _render(
        SvgEditSettings(
          crop: const CropRect(x: 0, y: 0, width: 60, height: 80),
          rotationQuarterTurns: 1,
          drawing: DrawingLayer(strokes: [_line]),
        ),
      );
      // O recorte só muda o viewBox; o giro vai para o grupo de conteúdo,
      // que contém o desenho.
      expect(root.getAttribute('viewBox'), isNot('0 0 120 80'));
      final content = _contentGroup(root);
      expect(content.getAttribute('transform'), contains('rotate(90'));
      expect(
        content.descendantElements.where((e) => e.name.local == 'path'),
        hasLength(1),
      );
    });

    test('um transform da raiz não alcança o desenho', () {
      final root = _render(
        SvgEditSettings(drawing: DrawingLayer(strokes: [_line])),
        source:
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 80" '
            'width="120" height="80" transform="scale(2)"><rect/></svg>',
      );
      final content = _contentGroup(root);
      expect(content.getAttribute('transform'), isNull);
      final inner = content.childElements.first;
      expect(inner.getAttribute('transform'), 'scale(2)');
      expect(inner.childElements.single.name.local, 'rect');
      expect(
        content.childElements.last.getAttribute('data-svgedit-drawing'),
        '1',
      );
    });
  });

  group('aba', () {
    late Directory tempDir;
    late String svgPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('svg_drawing_test');
      svgPath = '${tempDir.path}/exemplo.svg';
      await File(svgPath).writeAsString(_svg);
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    testWidgets('só pincel e borracha, e o traço entra no desfazer', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: SvgEditPage(
            svg: SvgInfo(path: svgPath, width: 120, height: 80),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pincel'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OptionPillButton, 'Pincel'), findsOneWidget);
      expect(find.widgetWithText(OptionPillButton, 'Borracha'), findsOneWidget);
      expect(
        find.widgetWithText(OptionPillButton, 'Transparência'),
        findsNothing,
      );

      DrawingCanvas canvas() =>
          tester.widget<DrawingCanvas>(find.byType(DrawingCanvas));
      expect(canvas().sourceWidth, 120);

      final center = tester.getCenter(find.byType(DrawingCanvas));
      final gesture = await tester.startGesture(center);
      await tester.pump();
      await gesture.moveTo(center + const Offset(30, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(canvas().layer.strokes, hasLength(1));

      await tester.tap(find.byTooltip('Desfazer'));
      await tester.pumpAndSettle();
      expect(canvas().layer.isEmpty, isTrue);
    });
  });
}
