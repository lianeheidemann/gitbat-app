import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// As regras de dependência entre as pastas de `lib/` (ver "Project
/// structure" no README): o que é compartilhado (`core/`) e o que vale para o
/// app inteiro (`app/`) não conhecem nenhuma ferramenta, e uma ferramenta não
/// importa outra — só `home`, que abre todas.
///
/// Um import no lugar errado passa pela análise e pelo build sem aviso
/// nenhum; é só aqui que ele aparece.
void main() {
  final imports = _importsOf(Directory('lib'));

  test('lê os imports de lib/', () {
    // Sem isso, um erro no próprio leitor faria as regras abaixo passarem
    // sem conferir nada.
    expect(imports.length, greaterThan(500));
  });

  test('core/ e app/ não importam features/', () {
    final wrong = [
      for (final (:from, :to) in imports)
        if ((from.startsWith('core/') || from.startsWith('app/')) &&
            to.startsWith('features/'))
          '$from → $to',
    ];
    expect(wrong, isEmpty);
  });

  test('uma ferramenta não importa outra (fora home)', () {
    final wrong = [
      for (final (:from, :to) in imports)
        if (_feature(from) case final source?
            when source != 'home' &&
                _feature(to) != null &&
                _feature(to) != source)
          '$from → $to',
    ];
    expect(wrong, isEmpty);
  });
}

final _directive = RegExp(
  r"^\s*(?:import|export)\s+'([^']+)'",
  multiLine: true,
);

/// Cada `import`/`export` de um arquivo de [lib] para outro, com os dois
/// caminhos relativos a `lib/` (ex.: `features/collage/collage_page.dart`).
List<({String from, String to})> _importsOf(Directory lib) {
  final result = <({String from, String to})>[];
  for (final file in lib.listSync(recursive: true).whereType<File>()) {
    final path = file.path.replaceAll(r'\', '/');
    if (!path.endsWith('.dart')) continue;
    final from = path.substring(path.indexOf('lib/') + 'lib/'.length);
    for (final match in _directive.allMatches(file.readAsStringSync())) {
      final target = match.group(1)!;
      final String to;
      if (target.startsWith('package:gitbat/')) {
        to = target.substring('package:gitbat/'.length);
      } else if (target.contains(':')) {
        continue; // dart: e pacotes de fora
      } else {
        // Resolvido a partir de `lib/`, para um `../` nunca passar da raiz.
        final resolved = Uri(path: 'lib/$from').resolve(target).path;
        to = resolved.substring('lib/'.length);
      }
      result.add((from: from, to: to));
    }
  }
  return result;
}

/// A ferramenta dona de [path] (`features/<ferramenta>/...`), ou `null` fora
/// de `features/`.
String? _feature(String path) {
  final parts = path.split('/');
  return parts.length > 2 && parts.first == 'features' ? parts[1] : null;
}
