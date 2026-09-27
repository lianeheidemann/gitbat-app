import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:gitbat/features/svg/services/svg_source_fixer.dart';
import 'package:xml/xml.dart';

// SVGs que o leitor do app recusava ("Não foi possível ler este arquivo
// como SVG") agora abrem, ou dizem o motivo.

class _TempPaths extends PathProviderPlatform {
  _TempPaths(this.dir);
  final String dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
}

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
    '<rect width="5" height="5" transform="rotate(10deg)"/></svg>';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('.svgz renomeado é descompactado', () {
    final fixed = fixSvgSource(
      Uint8List.fromList(gzip.encode(utf8.encode('<svg viewBox="0 0 1 1"/>'))),
    );
    expect(fixed.text, '<svg viewBox="0 0 1 1"/>');
    expect(fixed.changed, isTrue);
  });

  test('UTF-16 vira texto normal', () {
    const text = '<svg viewBox="0 0 1 1"/>';
    final bytes = <int>[0xFF, 0xFE];
    for (final unit in text.codeUnits) {
      bytes
        ..add(unit & 0xFF)
        ..add(unit >> 8);
    }
    expect(fixSvgSource(Uint8List.fromList(bytes)).text, text);
  });

  test('ângulo em "deg" perde a unidade', () {
    final fixed = fixSvgSource(Uint8List.fromList(utf8.encode(_svg)));
    expect(fixed.text, contains('rotate(10)'));
    expect(fixed.changed, isTrue);
  });

  test('arquivo que não é SVG diz isso', () {
    expect(
      () => fixSvgSource(Uint8List.fromList(utf8.encode('<html></html>'))),
      throwsA(isA<SvgOpenException>()),
    );
  });

  testWidgets('SVG sem tamanho ganha o viewBox do próprio desenho', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('svgfix');
    addTearDown(() => dir.deleteSync(recursive: true));
    PathProviderPlatform.instance = _TempPaths(dir.path);
    final original = File('${dir.path}/icone.svg')
      ..writeAsStringSync(
        '<svg xmlns="http://www.w3.org/2000/svg">'
        '<rect x="100" y="50" width="40" height="20" fill="#f00"/></svg>',
      );
    final path = (await tester.runAsync(
      () => prepareSvgForEditing(original.path),
    ))!;
    expect(path, isNot(original.path));
    expect(path.endsWith('icone.svg'), isTrue);
    final root = XmlDocument.parse(File(path).readAsStringSync()).rootElement;
    final box = root
        .getAttribute('viewBox')!
        .split(' ')
        .map(int.parse)
        .toList();
    // O retângulo desenhado (100,50 40×20), com no máximo 2 unidades de
    // sobra pela suavização.
    expect(box[0], inInclusiveRange(98, 100));
    expect(box[1], inInclusiveRange(48, 50));
    expect(box[0] + box[2], inInclusiveRange(140, 142));
    expect(box[1] + box[3], inInclusiveRange(70, 72));
  });

  testWidgets('SVG já legível abre sem cópia', (tester) async {
    final dir = Directory.systemTemp.createTempSync('svgfix');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/ok.svg')
      ..writeAsStringSync('<svg viewBox="0 0 1 1"/>');
    final path = (await tester.runAsync(
      () => prepareSvgForEditing(file.path),
    ))!;
    expect(path, file.path);
  });
}
