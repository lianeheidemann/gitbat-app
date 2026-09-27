import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitbat/core/models/frame_settings.dart';
import 'package:gitbat/core/models/photo_placement.dart';
import 'package:gitbat/features/svg/models/svg_edit_settings.dart';
import 'package:gitbat/features/svg/models/svg_info.dart';
import 'package:gitbat/features/svg/services/svg_xml_editor.dart';
import 'package:xml/xml.dart';

// "Editar SVG": borda (aba "Borda") e posição livre do desenho saem
// vetoriais no arquivo.

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100">'
    '<rect x="10" y="10" width="40" height="40" fill="#ff0000"/></svg>';
const _info = SvgInfo(path: '', width: 200, height: 100);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sem borda nem posição, o SVG não ganha grupos a mais', () {
    final xml = renderEditedSvg(_svg, _info, const SvgEditSettings());
    expect(xml, isNot(contains('clip-path')));
    expect(xml, isNot(contains('data-svgedit-placement')));
  });

  test('borda: conteúdo recortado por dentro e anel na cor escolhida', () {
    final xml = renderEditedSvg(
      _svg,
      _info,
      const SvgEditSettings(
        border: FrameSettings(
          style: FrameStyle.medium,
          color: Color(0xFF00FF00),
          thicknessAtReference: 24,
          cornerRatio: 0.1,
        ),
      ),
    );
    final root = XmlDocument.parse(xml).rootElement;
    final clip = root.descendantElements.firstWhere(
      (e) => e.name.local == 'clipPath',
    );
    expect(clip.getAttribute('id'), 'svgedit-border-clip');
    final group = root.childElements.firstWhere(
      (e) => e.getAttribute('clip-path') == 'url(#svgedit-border-clip)',
    );
    expect(group.descendantElements.any((e) => e.name.local == 'rect'), isTrue);
    final ring = root.childElements.last;
    expect(ring.name.local, 'path');
    expect(ring.getAttribute('fill'), '#00ff00');
    expect(ring.getAttribute('fill-rule'), 'evenodd');
    // Espessura: 24 na largura de referência (480) → 10 num viewBox de 200.
    expect(ring.getAttribute('d'), contains('M10 10'.replaceAll(' ', ' ')));
  });

  test('posição livre vira transform no grupo do conteúdo', () {
    final xml = renderEditedSvg(
      _svg,
      _info,
      const SvgEditSettings(
        placement: PhotoPlacement(dx: 0.1, dy: -0.2, scale: 0.5),
      ),
    );
    final root = XmlDocument.parse(xml).rootElement;
    final group = root.childElements.firstWhere(
      (e) => e.getAttribute('data-svgedit-placement') == '1',
    );
    // Centro (100, 50) deslocado por (20, -20).
    expect(
      group.getAttribute('transform'),
      'translate(120 30) rotate(0) scale(0.5) translate(-100 -50)',
    );
  });
}
