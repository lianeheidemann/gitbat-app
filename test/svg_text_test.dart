import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitbat/core/ui/editor_tabs_footer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gitbat/core/models/collage_text.dart';
import 'package:gitbat/core/models/crop_rect.dart';
import 'package:gitbat/features/svg/models/svg_edit_settings.dart';
import 'package:gitbat/features/svg/models/svg_info.dart';
import 'package:gitbat/features/svg/services/svg_xml_editor.dart';
import 'package:gitbat/features/svg/svg_edit_page.dart';
import 'package:xml/xml.dart';

// Texto no "Editar SVG": sai no arquivo como `<text>` de verdade, por cima
// da arte, fora do filtro e da opacidade, medido no `viewBox` final.

const _sampleSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100" '
    'width="200" height="100">'
    '<rect x="10" y="10" width="40" height="40" fill="#ff0000"/>'
    '</svg>';

const _info = SvgInfo(path: '', width: 200, height: 100);

CollageTextItem _text({String text = 'Olá', Color? background}) =>
    CollageTextItem(
      id: 't',
      text: text,
      centerX: 0.25,
      centerY: 0.5,
      zIndex: 0,
      backgroundColor: background,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('o texto vira <text> no fim do SVG, centrado e no tamanho certo', () {
    final xml = renderEditedSvg(
      _sampleSvg,
      _info,
      SvgEditSettings(texts: [_text()], opacity: 0.5),
    );
    final root = XmlDocument.parse(xml).rootElement;
    final group = root.childElements.last;
    expect(group.getAttribute('data-svgedit-text'), '1');
    expect(group.getAttribute('transform'), 'translate(50 50)');
    final text = group.findElements('text').single;
    // 35% do menor lado do viewBox (100).
    expect(text.getAttribute('font-size'), '35');
    expect(text.getAttribute('text-anchor'), 'middle');
    expect(text.innerText, 'Olá');
    // A opacidade vale só para a arte, não para o texto.
    final content = root.childElements.firstWhere(
      (e) => e.getAttribute('data-svgedit') == '1',
    );
    expect(content.getAttribute('opacity'), '0.5');
    expect(group.getAttribute('opacity'), isNull);
  });

  test('com recorte, o texto é medido no viewBox recortado', () {
    final xml = renderEditedSvg(
      _sampleSvg,
      _info,
      SvgEditSettings(
        crop: const CropRect(x: 100, y: 20, width: 100, height: 40),
        texts: [_text()],
      ),
    );
    final root = XmlDocument.parse(xml).rootElement;
    final group = root.childElements.last;
    // Recorte 100x40 a partir de (100, 20): centro 0.25 → x = 125.
    expect(group.getAttribute('transform'), 'translate(125 40)');
    expect(group.findElements('text').single.getAttribute('font-size'), '14');
  });

  test('fundo arredondado e várias linhas', () {
    final xml = renderEditedSvg(
      _sampleSvg,
      _info,
      SvgEditSettings(
        texts: [_text(text: 'a\nb', background: const Color(0xFF00FF00))],
      ),
    );
    final group = XmlDocument.parse(xml).rootElement.childElements.last;
    final rect = group.findElements('rect').single;
    expect(rect.getAttribute('fill'), '#00ff00');
    expect(double.parse(rect.getAttribute('rx')!), greaterThan(0));
    final spans = group.findAllElements('tspan').toList();
    expect(spans.map((e) => e.innerText), ['a', 'b']);
    expect(
      double.parse(spans[1].getAttribute('y')!),
      greaterThan(double.parse(spans[0].getAttribute('y')!)),
    );
  });

  test('sem texto, o SVG sai sem nada a mais', () {
    final xml = renderEditedSvg(_sampleSvg, _info, const SvgEditSettings());
    expect(xml, isNot(contains('<text')));
  });

  testWidgets('a tela do SVG tem a aba "Texto" e adiciona texto', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final dir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('svg_text_test'),
    );
    addTearDown(() => dir!.delete(recursive: true));
    final path = '${dir!.path}/a.svg';
    await tester.runAsync(() => File(path).writeAsString(_sampleSvg));

    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SvgEditPage(svg: SvgInfo(path: path, width: 200, height: 100)),
      ),
    );
    await tester.pumpAndSettle();

    await _showTab(tester, 'Texto');
    await tester.tap(find.text('Texto').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'oi');
    await tester.pump();
    await tester.tap(find.byTooltip('Adicionar texto'));
    await tester.pumpAndSettle();

    expect(find.text('oi'), findsWidgets);
    expect(find.text('Tamanho da fonte'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
