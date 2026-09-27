import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitbat/features/collage/services/collage_export_runner.dart';

// Exportações que morrem no meio (o Android fecha o app) deixavam centenas
// de PNGs no cache; a próxima exportação limpa esse lixo.

void main() {
  test('apaga pastas de quadros e arquivos antigos da montagem', () async {
    final temp = await Directory.systemTemp.createTemp('limpeza');
    addTearDown(() => temp.delete(recursive: true));
    final frames = await Directory(
      '${temp.path}/montagem_quadros_123',
    ).create();
    await File('${frames.path}/quadro_00000.png').writeAsString('x');
    final old = File('${temp.path}/montagem_1.gif')..writeAsStringSync('x');
    old.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 1)));
    final recent = File('${temp.path}/montagem_2.webp')..writeAsStringSync('x');
    final other = File('${temp.path}/outra_coisa.png')..writeAsStringSync('x');

    await CollageExportRunner.cleanStaleExports(temp);

    expect(frames.existsSync(), isFalse);
    expect(old.existsSync(), isFalse);
    expect(
      recent.existsSync(),
      isTrue,
      reason: 'pode estar sendo compartilhado',
    );
    expect(other.existsSync(), isTrue);
  });
}
