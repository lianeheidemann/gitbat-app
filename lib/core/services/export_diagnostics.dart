import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Registro das etapas de uma exportação pesada (montagem animada), gravado
/// no aparelho **na hora, com flush** — se o Android fechar o app no meio,
/// o arquivo continua com a última etapa que começou.
///
/// Na próxima vez que a tela abre, [interruptedReport] devolve essas últimas
/// linhas quando a exportação anterior não chegou ao fim, para o app mostrar
/// onde ela parou (e quanta memória estava em uso).
class ExportDiagnostics {
  ExportDiagnostics.at(this.file);

  final File file;

  static const _fileName = 'exportacao_diagnostico.log';
  static const _runningMark = 'EM ANDAMENTO';
  static const _endMark = 'FIM';

  /// O registro no diretório de suporte do app. `null` quando não dá para
  /// abrir — o diagnóstico nunca pode impedir a exportação.
  static Future<ExportDiagnostics?> open() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return ExportDiagnostics.at(File('${dir.path}/$_fileName'));
    } catch (_) {
      return null;
    }
  }

  /// Começa um registro novo (apaga o anterior).
  void start(String description) {
    _write('$_runningMark: $description\n', FileMode.write);
    step('início');
  }

  /// Anota que [description] começou agora, com a memória em uso.
  void step(String description) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final time = '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
    _write('$time  $description  (${_memoryMb()} MB)\n', FileMode.append);
  }

  /// Marca o fim (com sucesso, erro ou cancelamento).
  void finish(String result) => _write('$_endMark: $result\n', FileMode.append);

  /// As últimas [maxLines] linhas da exportação anterior, quando ela ficou
  /// "em andamento" (o app foi fechado no meio); senão `null`.
  Future<List<String>?> interruptedReport({int maxLines = 8}) async {
    try {
      if (!await file.exists()) return null;
      final lines = (await file.readAsLines())
          .where((l) => l.trim().isNotEmpty)
          .toList();
      if (lines.isEmpty || !lines.first.startsWith(_runningMark)) return null;
      if (lines.last.startsWith(_endMark)) return null;
      final tail = lines.length <= maxLines
          ? lines
          : [lines.first, ...lines.sublist(lines.length - (maxLines - 1))];
      return tail;
    } catch (_) {
      return null;
    }
  }

  /// Depois de mostrar o relatório: não mostra de novo.
  void markSeen() => finish('relatório visto');

  void _write(String text, FileMode mode) {
    try {
      file.writeAsStringSync(text, mode: mode, flush: true);
    } catch (_) {
      // Sem espaço ou sem permissão: segue sem diagnóstico.
    }
  }

  static int _memoryMb() {
    try {
      return ProcessInfo.currentRss ~/ (1024 * 1024);
    } catch (_) {
      return -1;
    }
  }
}
