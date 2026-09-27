import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:video_to_gif/core/services/export_diagnostics.dart';

// O registro da exportação precisa sobreviver ao app ser fechado no meio:
// cada etapa vai para o arquivo na hora, e a próxima abertura sabe onde parou.

void main() {
  late Directory dir;
  late ExportDiagnostics diagnostics;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('diagnostico');
    diagnostics = ExportDiagnostics.at(File('${dir.path}/registro.log'));
  });

  tearDown(() => dir.delete(recursive: true));

  test('sem registro, não há relatório', () async {
    expect(await diagnostics.interruptedReport(), isNull);
  });

  test('exportação que parou no meio devolve as últimas etapas', () async {
    diagnostics.start('WebP 1440×570');
    for (var i = 1; i <= 20; i++) {
      diagnostics.step('quadro $i');
    }
    final report = await diagnostics.interruptedReport(maxLines: 5);
    expect(report, isNotNull);
    expect(report!.first, startsWith('EM ANDAMENTO: WebP 1440×570'));
    expect(report.length, 5);
    expect(report.last, contains('quadro 20'));
    expect(report.last, contains('MB)'), reason: 'anota a memória');
  });

  test('exportação que terminou, ou relatório já visto, não aparece', () async {
    diagnostics.start('GIF');
    diagnostics.step('quadro 1');
    diagnostics.finish('ok');
    expect(await diagnostics.interruptedReport(), isNull);

    diagnostics.start('GIF');
    diagnostics.step('quadro 1');
    expect(await diagnostics.interruptedReport(), isNotNull);
    diagnostics.markSeen();
    expect(await diagnostics.interruptedReport(), isNull);
  });

  test('começar de novo apaga o registro anterior', () async {
    diagnostics.start('primeira');
    diagnostics.step('etapa antiga');
    diagnostics.start('segunda');
    final report = await diagnostics.interruptedReport();
    expect(report!.join('\n'), isNot(contains('etapa antiga')));
    expect(report.first, contains('segunda'));
  });
}
