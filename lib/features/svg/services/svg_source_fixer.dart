import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

import '../../../core/services/opaque_bounds.dart';

/// Motivo legível de um SVG que não deu para abrir — vira a mensagem da
/// tela inicial no lugar do genérico "Não foi possível ler este arquivo".
class SvgOpenException implements Exception {
  const SvgOpenException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Tamanho do quadro provisório usado para achar o desenho de um SVG que não
/// informa tamanho nenhum (sem `width`/`height` nem `viewBox`).
const _probeSide = 2048;

/// Deixa um SVG "difícil" legível pelo `flutter_svg` antes de abrir no
/// editor, e devolve o caminho a usar (o original quando nada muda, ou uma
/// cópia corrigida na pasta temporária, com o mesmo nome de arquivo).
///
/// Corrige os casos que o leitor do app recusava:
/// - `.svgz` (compactado com gzip) renomeado para `.svg`;
/// - arquivo salvo em UTF-16 (alguns programas do Windows);
/// - ângulo com unidade em `rotate(10deg)`/`skewX(...deg)`;
/// - SVG sem tamanho nenhum: o desenho é localizado e vira o `viewBox`.
Future<String> prepareSvgForEditing(String path) async {
  final bytes = await File(path).readAsBytes();
  final fixed = fixSvgSource(bytes);
  var text = fixed.text;
  var changed = fixed.changed;

  if (!_hasSize(text)) {
    text = await _withDetectedViewBox(text, path);
    changed = true;
  }
  if (!changed) return path;

  final temp = await getTemporaryDirectory();
  final dir = await Directory(
    '${temp.path}/svg_${DateTime.now().microsecondsSinceEpoch}',
  ).create(recursive: true);
  final name = path.split(Platform.pathSeparator).last;
  final out = File('${dir.path}/$name');
  await out.writeAsString(text);
  return out.path;
}

/// A parte síncrona de [prepareSvgForEditing]: descompacta, decodifica o
/// texto e troca as unidades de ângulo. `changed` diz se algo mudou.
({String text, bool changed}) fixSvgSource(Uint8List bytes) {
  var data = bytes;
  var changed = false;
  if (data.length > 2 && data[0] == 0x1F && data[1] == 0x8B) {
    try {
      data = Uint8List.fromList(gzip.decode(data));
      changed = true;
    } catch (_) {
      throw const SvgOpenException(
        'Este arquivo está compactado e não deu para abrir.',
      );
    }
  }

  String text;
  if (data.length >= 2 && data[0] == 0xFF && data[1] == 0xFE) {
    text = _utf16(data.sublist(2), littleEndian: true);
    changed = true;
  } else if (data.length >= 2 && data[0] == 0xFE && data[1] == 0xFF) {
    text = _utf16(data.sublist(2), littleEndian: false);
    changed = true;
  } else {
    text = utf8.decode(data, allowMalformed: true);
  }
  if (text.startsWith('﻿')) text = text.substring(1);

  final withoutDeg = text.replaceAllMapped(
    RegExp(
      r'(rotate|skewX|skewY)\(\s*([-+0-9.eE]+)\s*deg',
      caseSensitive: false,
    ),
    (m) => '${m[1]}(${m[2]}',
  );
  if (withoutDeg != text) changed = true;

  if (!withoutDeg.contains('<svg')) {
    throw const SvgOpenException('Este arquivo não é um SVG.');
  }
  return (text: withoutDeg, changed: changed);
}

String _utf16(Uint8List data, {required bool littleEndian}) {
  final units = <int>[];
  for (var i = 0; i + 1 < data.length; i += 2) {
    units.add(
      littleEndian
          ? data[i] | (data[i + 1] << 8)
          : (data[i] << 8) | data[i + 1],
    );
  }
  return String.fromCharCodes(units);
}

/// `true` quando o SVG raiz tem `viewBox` ou `width` e `height` numéricos
/// (não em %). Sem nenhum dos dois o leitor não sabe o tamanho do desenho.
bool _hasSize(String text) {
  try {
    final root = XmlDocument.parse(text).rootElement;
    if ((root.getAttribute('viewBox') ?? '').trim().isNotEmpty) return true;
    bool numeric(String? v) =>
        v != null && !v.contains('%') && RegExp(r'\d').hasMatch(v);
    return numeric(root.getAttribute('width')) &&
        numeric(root.getAttribute('height'));
  } catch (_) {
    throw const SvgOpenException(
      'Este SVG está com o código quebrado (XML inválido).',
    );
  }
}

/// Coloca o SVG num quadro provisório grande, acha onde o desenho está e
/// usa esse retângulo como `viewBox` (e tamanho) do arquivo.
Future<String> _withDetectedViewBox(String text, String originalPath) async {
  final doc = XmlDocument.parse(text);
  final root = doc.rootElement;
  root
    ..setAttribute('viewBox', '0 0 $_probeSide $_probeSide')
    ..setAttribute('width', '$_probeSide')
    ..setAttribute('height', '$_probeSide');

  final temp = await getTemporaryDirectory();
  final probe = File(
    '${temp.path}/svg_probe_${DateTime.now().microsecondsSinceEpoch}.svg',
  );
  await probe.writeAsString(doc.toXmlString());
  try {
    final bounds = await detectSvgOpaqueBounds(
      probe.path,
      _probeSide,
      _probeSide,
    );
    if (bounds == null) {
      throw const SvgOpenException(
        'Este SVG não informa o tamanho e não foi possível encontrar o '
        'desenho dentro dele.',
      );
    }
    root
      ..setAttribute(
        'viewBox',
        '${bounds.x} ${bounds.y} ${bounds.width} ${bounds.height}',
      )
      ..setAttribute('width', '${bounds.width}')
      ..setAttribute('height', '${bounds.height}');
    return doc.toXmlString();
  } on SvgOpenException {
    rethrow;
  } catch (_) {
    throw const SvgOpenException(
      'Este SVG não informa o tamanho (width/height ou viewBox).',
    );
  } finally {
    if (probe.existsSync()) probe.deleteSync();
  }
}
