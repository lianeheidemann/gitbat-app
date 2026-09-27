import 'dart:io';

import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

/// Salvar na galeria e compartilhar o GIF pronto.
class OutputService {
  const OutputService();

  static const _albumName = 'GitBat';

  /// Início do nome de todo arquivo que o app salva ou compartilha.
  static const filePrefix = 'GitBat_';

  /// Nome com a marca do app e a data/hora, ex.: `GitBat_20260927_201530.gif`.
  static String brandedFileName(String extension, DateTime when) {
    String two(int n) => n.toString().padLeft(2, '0');
    final date = '${when.year}${two(when.month)}${two(when.day)}';
    final time = '${two(when.hour)}${two(when.minute)}${two(when.second)}';
    final suffix = extension.isEmpty ? '' : '.$extension';
    return '$filePrefix${date}_$time$suffix';
  }

  /// Cópia de [file] com o nome de [brandedFileName], numa pasta própria ao
  /// lado dele — a galeria e o compartilhamento usam o nome do arquivo. Os
  /// arquivos das telas saem no temporário com nomes internos (`gif_123.gif`),
  /// e o original continua lá para quem ainda for usá-lo.
  static Future<File> brandedCopy(File file, {DateTime? now}) async {
    final name = file.uri.pathSegments.last;
    if (name.startsWith(filePrefix)) return file;
    final dot = name.lastIndexOf('.');
    final extension = dot == -1 ? '' : name.substring(dot + 1);
    final dir = await Directory(
      '${file.parent.path}/gitbat_${DateTime.now().microsecondsSinceEpoch}',
    ).create(recursive: true);
    final branded = brandedFileName(extension, now ?? DateTime.now());
    return file.copy('${dir.path}/$branded');
  }

  /// Salva na galeria do aparelho, pedindo permissão se ainda não tiver.
  ///
  /// [asVideo] usa `Gal.putVideo` em vez de `Gal.putImage` — necessário para
  /// os formatos de vídeo de verdade (MP4/WebM/MOV) que "Converter formato"
  /// também gera, além do GIF/WebP animados de sempre.
  ///
  /// Lança [OutputException] com uma mensagem em português quando o usuário
  /// nega o acesso — é o erro que mais aparece na prática.
  Future<void> saveToGallery(File gif, {bool asVideo = false}) async {
    if (!await Gal.hasAccess()) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        throw OutputException(
          'Sem permissão para salvar na galeria. Você pode liberar em '
          'Ajustes > Apps > GitBat > Permissões.',
        );
      }
    }

    final branded = await brandedCopy(gif);
    try {
      if (asVideo) {
        await Gal.putVideo(branded.path, album: _albumName);
      } else {
        await Gal.putImage(branded.path, album: _albumName);
      }
    } on GalException catch (e) {
      throw OutputException(
        'Não foi possível salvar na galeria: ${e.type.message}',
      );
    } finally {
      // A galeria guarda a própria cópia; a nossa já não serve para nada.
      if (branded.path != gif.path) {
        try {
          await branded.parent.delete(recursive: true);
        } on FileSystemException {
          // Sobra no temporário, que o sistema limpa sozinho.
        }
      }
    }
  }

  /// Abre a folha de compartilhamento do sistema com o arquivo anexado.
  /// [mimeType]/[text] têm o padrão do GIF de vídeo; a tela de moldura em
  /// foto passa os equivalentes para PNG.
  Future<void> share(
    File file, {
    String mimeType = 'image/gif',
    String text = 'GIF feito com o app GitBat',
  }) async {
    final branded = await brandedCopy(file);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(branded.path, mimeType: mimeType)],
        text: text,
      ),
    );
  }
}

class OutputException implements Exception {
  OutputException(this.message);

  final String message;

  @override
  String toString() => message;
}
