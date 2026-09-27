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
  final bytes = await File(path).readAsBytes();

  // O primeiro quadro dá o tamanho e a taxa do intermediário (que é de taxa
  // fixa): quadros mais longos que ele se repetem, e o tempo total fica
  // igual ao original.
  final int width;
  final int height;
  final int frameCount;
  final double fps;
  {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      frameCount = codec.frameCount;
      final first = await codec.getNextFrame();
      width = first.image.width;
      height = first.image.height;
      fps = (1000 / webpFrameMs(first.duration)).clamp(1.0, 60.0);
      first.image.dispose();
    } finally {
      codec.dispose();
    }
  }

  Future<void> writeFrames(IOSink sink) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      for (var i = 0; i < frameCount; i++) {
        final frame = await codec.getNextFrame();
        // Cru (sem codificar PNG no Flutter, que era o lento), com alfa
        // "reto", que é o que o FFmpeg espera em rgba.
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        frame.image.dispose();
        final pixels = data!.buffer.asUint8List();
        final copies = webpFrameCopies(frame.duration, fps);
        for (var c = 0; c < copies; c++) {
          sink.add(pixels);
        }
        // Espera o FFmpeg ler antes de decodificar o próximo, para não
        // acumular quadros na memória.
        await sink.flush();
      }
    } finally {
      codec.dispose();
    }
  }

  final movPath = '${dir.path}/origem.mov';
  await ffmpeg.rawRgbaToMov(
    width: width,
    height: height,
    fps: fps,
    outputPath: movPath,
    scratchDir: dir.path,
    writeFrames: writeFrames,
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
    fileSizeBytes: original.lengthSync(),
    codec: 'webp',
    rotationDegrees: probed.rotationDegrees,
  );
}

/// Duração de um quadro do WebP em ms — sem duração (0) conta como 100 ms,
/// o padrão dos navegadores para animações sem tempo definido.
int webpFrameMs(Duration duration) {
  final ms = duration.inMilliseconds;
  return ms <= 0 ? 100 : ms;
}

/// Quantas vezes um quadro de [duration] entra no intermediário de taxa
/// fixa [fps] — pelo menos uma, para nenhum quadro sumir.
int webpFrameCopies(Duration duration, double fps) {
  final copies = (webpFrameMs(duration) * fps / 1000).round();
  return copies < 1 ? 1 : copies;
}
