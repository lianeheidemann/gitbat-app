import 'dart:io';
import 'dart:typed_data';
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

/// Canvas, número de quadros e duração de um WebP animado, lidos direto do
/// cabeçalho do arquivo (chunks `VP8X` e `ANMF`) — sem decodificar nenhum
/// quadro, então é instantâneo mesmo num arquivo grande. `null` se o
/// arquivo não tiver essa estrutura.
({int width, int height, int frames, int durationMs})? parseAnimatedWebp(
  Uint8List bytes,
) {
  if (bytes.length < 30) return null;
  String tag(int at) => String.fromCharCodes(bytes.sublist(at, at + 4));
  int u24(int at) => bytes[at] | (bytes[at + 1] << 8) | (bytes[at + 2] << 16);
  int u32(int at) => u24(at) | (bytes[at + 3] << 24);
  if (tag(0) != 'RIFF' || tag(8) != 'WEBP') return null;

  int? width;
  int? height;
  var frames = 0;
  var durationMs = 0;
  var at = 12;
  while (at + 8 <= bytes.length) {
    final fourcc = tag(at);
    final size = u32(at + 4);
    final payload = at + 8;
    if (payload + size > bytes.length) break;
    if (fourcc == 'VP8X' && size >= 10) {
      width = u24(payload + 4) + 1;
      height = u24(payload + 7) + 1;
    } else if (fourcc == 'ANMF' && size >= 16) {
      frames++;
      final ms = u24(payload + 12);
      durationMs += ms <= 0 ? 100 : ms;
    }
    at = payload + size + (size.isOdd ? 1 : 0);
  }
  if (width == null || height == null || frames < 2) return null;
  return (width: width, height: height, frames: frames, durationMs: durationMs);
}

/// [VideoInfo] de um WebP animado sem convertê-lo: o cartão da tela aparece
/// na hora. O `path` continua sendo o `.webp` — a conversão para o `.mov`
/// intermediário ([probeAnimatedWebp]) só acontece ao tocar "Converter".
Future<VideoInfo?> readAnimatedWebpInfo(String path) async {
  final file = File(path);
  final bytes = await file.readAsBytes();
  final info = parseAnimatedWebp(bytes);
  if (info == null) return null;
  final seconds = info.durationMs / 1000;
  return VideoInfo(
    path: path,
    fileName: file.uri.pathSegments.last,
    rawWidth: info.width,
    rawHeight: info.height,
    durationSeconds: seconds,
    frameRate: seconds <= 0 ? 10 : info.frames / seconds,
    bitrateBps: seconds <= 0 ? 0 : (bytes.length * 8 / seconds).round(),
    fileSizeBytes: bytes.length,
    codec: 'webp',
  );
}

/// `true` quando [video] ainda aponta para o `.webp` original (lido por
/// [readAnimatedWebpInfo]) e precisa virar `.mov` antes de converter.
bool needsWebpIntermediate(VideoInfo video) =>
    video.codec == 'webp' && video.path.toLowerCase().endsWith('.webp');

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
