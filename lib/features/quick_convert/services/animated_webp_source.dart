import 'dart:io';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';

import '../../../core/ffmpeg/ffmpeg_service.dart';
import '../../../core/models/video_info.dart';

/// WebP animado como origem de "Converter formato".
///
/// O FFmpeg empacotado no app (geração 7) abre o arquivo mas não decodifica
/// nenhum quadro de um WebP animado — o suporte só chegou em versões mais
/// novas. O decodificador do próprio Flutter entende o formato (é o mesmo
/// que a Montagem usa), então aqui ele extrai os quadros para PNGs e o
/// FFmpeg os junta num `.mov` sem perda e com transparência. O resto da
/// conversão (GIF, MP4, WebP) segue normal em cima desse arquivo.

/// `true` quando [path] é um `.webp` com mais de um quadro.
Future<bool> isAnimatedWebp(String path) async {
  if (!path.toLowerCase().endsWith('.webp')) return false;
  try {
    final codec = await ui.instantiateImageCodec(
      await File(path).readAsBytes(),
    );
    final animated = codec.frameCount > 1;
    codec.dispose();
    return animated;
  } catch (_) {
    return false;
  }
}

/// Converte o WebP animado em [path] num `.mov` temporário e devolve o
/// [VideoInfo] dele — com o nome e o tamanho do arquivo **original**, para
/// o cartão da tela e o formato de origem continuarem sendo "WebP".
Future<VideoInfo> probeAnimatedWebp(String path, FfmpegService ffmpeg) async {
  final temp = await getTemporaryDirectory();
  final dir = await Directory(
    '${temp.path}/webp_${DateTime.now().millisecondsSinceEpoch}',
  ).create(recursive: true);

  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  var totalMs = 0;
  final frameCount = codec.frameCount;
  try {
    for (var i = 0; i < frameCount; i++) {
      final frame = await codec.getNextFrame();
      // Quadros sem duração (0) contam como 100 ms, o padrão dos
      // navegadores para animações sem tempo definido.
      final ms = frame.duration.inMilliseconds;
      totalMs += ms <= 0 ? 100 : ms;
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      await File(
        '${dir.path}/quadro_${i.toString().padLeft(5, '0')}.png',
      ).writeAsBytes(png!.buffer.asUint8List());
    }
  } finally {
    codec.dispose();
  }

  // Taxa média: o WebP pode ter durações diferentes por quadro, mas o
  // intermediário é de taxa fixa — o tempo total fica igual ao original.
  final fps = (frameCount * 1000 / totalMs).clamp(1.0, 60.0);
  final movPath = '${dir.path}/origem.mov';
  await ffmpeg.pngSequenceToMov(
    framePattern: '${dir.path}/quadro_%05d.png',
    fps: fps,
    outputPath: movPath,
  );

  final probed = await ffmpeg.probe(movPath);
  final original = File(path);
  return VideoInfo(
    path: probed.path,
    fileName: original.uri.pathSegments.last,
    rawWidth: probed.rawWidth,
    rawHeight: probed.rawHeight,
    durationSeconds: probed.durationSeconds,
    frameRate: probed.frameRate,
    bitrateBps: probed.bitrateBps,
    fileSizeBytes: await original.length(),
    codec: 'webp',
    rotationDegrees: probed.rotationDegrees,
  );
}
