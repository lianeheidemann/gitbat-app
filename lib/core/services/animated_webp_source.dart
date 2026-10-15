import '../../app/language_controller.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';

import '../ffmpeg/ffmpeg_service.dart';
import '../models/video_info.dart';

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

/// Canvas, número de quadros, duração e o quadro mais curto de um WebP
/// animado, lidos direto do cabeçalho do arquivo (chunks `VP8X` e `ANMF`) —
/// sem decodificar nenhum quadro, então é instantâneo mesmo num arquivo
/// grande. `null` se o arquivo não tiver essa estrutura.
({int width, int height, int frames, int durationMs, int shortestFrameMs})?
parseAnimatedWebp(Uint8List bytes) {
  if (bytes.length < 30) return null;
  String tag(int at) => String.fromCharCodes(bytes.sublist(at, at + 4));
  int u24(int at) => bytes[at] | (bytes[at + 1] << 8) | (bytes[at + 2] << 16);
  int u32(int at) => u24(at) | (bytes[at + 3] << 24);
  if (tag(0) != 'RIFF' || tag(8) != 'WEBP') return null;

  int? width;
  int? height;
  var frames = 0;
  var durationMs = 0;
  int? shortestFrameMs;
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
      final raw = u24(payload + 12);
      final ms = raw <= 0 ? 100 : raw;
      durationMs += ms;
      if (shortestFrameMs == null || ms < shortestFrameMs) {
        shortestFrameMs = ms;
      }
    }
    at = payload + size + (size.isOdd ? 1 : 0);
  }
  if (width == null || height == null || frames < 2) return null;
  return (
    width: width,
    height: height,
    frames: frames,
    durationMs: durationMs,
    shortestFrameMs: shortestFrameMs!,
  );
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
///
/// Com [maxWidth] os quadros já são decodificados nessa largura (mantendo a
/// proporção) — um WebP de 1080×1920 com centenas de quadros passava
/// gigabytes de pixels ao FFmpeg só para depois serem reduzidos. Enquanto os
/// quadros vão sendo escritos, [onProgress] recebe a fração pronta (0–1).
/// Se [FfmpegService.cancel] for chamado, para no quadro seguinte com um
/// [FfmpegException].
Future<VideoInfo> probeAnimatedWebp(
  String path,
  FfmpegService ffmpeg, {
  int? maxWidth,
  void Function(double progress)? onProgress,
}) async {
  final temp = await getTemporaryDirectory();
  final dir = await Directory(
    '${temp.path}/webp_${DateTime.now().millisecondsSinceEpoch}',
  ).create(recursive: true);
  final bytes = await File(path).readAsBytes();

  // O intermediário é de taxa fixa, medida pelo quadro **mais curto** do
  // cabeçalho: os mais longos se repetem e o tempo total fica igual ao
  // original. Antes valia o primeiro quadro, e um primeiro quadro longo
  // (uma tela de título de 1 s, por exemplo) baixava a taxa do arquivo
  // inteiro — todo o resto saía lento e travado.
  final int width;
  final int height;
  final int frameCount;
  final double fps;
  int? decodeWidth;
  final info = parseAnimatedWebp(bytes);
  if (maxWidth != null && info != null && maxWidth < info.width) {
    // Par, que o H.264 e o redimensionamento do FFmpeg preferem.
    decodeWidth = (maxWidth ~/ 2 * 2).clamp(2, info.width);
  }
  Future<ui.Codec> openCodec() =>
      ui.instantiateImageCodec(bytes, targetWidth: decodeWidth);
  {
    final codec = await openCodec();
    try {
      frameCount = codec.frameCount;
      final first = await codec.getNextFrame();
      width = first.image.width;
      height = first.image.height;
      fps = webpIntermediateFps(
        info?.shortestFrameMs ?? webpFrameMs(first.duration),
      );
      first.image.dispose();
    } finally {
      codec.dispose();
    }
  }

  Future<void> writeFrames(IOSink sink) async {
    final codec = await openCodec();
    var elapsedMs = 0;
    try {
      for (var i = 0; i < frameCount; i++) {
        if (ffmpeg.isCancelled) {
          throw FfmpegException(
            tr('Conversão cancelada.', 'Conversion cancelled.'),
          );
        }
        final frame = await codec.getNextFrame();
        // Cru (sem codificar PNG no Flutter, que era o lento), com alfa
        // "reto", que é o que o FFmpeg espera em rgba.
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        frame.image.dispose();
        final pixels = data!.buffer.asUint8List();
        final frameMs = webpFrameMs(frame.duration);
        final copies = webpFrameCopies(
          startMs: elapsedMs,
          durationMs: frameMs,
          fps: fps,
        );
        elapsedMs += frameMs;
        for (var c = 0; c < copies; c++) {
          sink.add(pixels);
        }
        // Espera o FFmpeg ler antes de decodificar o próximo, para não
        // acumular quadros na memória.
        await sink.flush();
        onProgress?.call((i + 1) / frameCount);
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

/// Taxa fixa do intermediário para um WebP cujo quadro mais curto dura
/// [shortestFrameMs]: um quadro de saída por quadro mais curto, de 1 a 60
/// por segundo.
double webpIntermediateFps(int shortestFrameMs) =>
    (1000 / (shortestFrameMs <= 0 ? 100 : shortestFrameMs)).clamp(1.0, 60.0);

/// Quantas vezes o quadro que começa em [startMs] e dura [durationMs] entra
/// no intermediário de taxa fixa [fps].
///
/// A conta é pelo relógio acumulado (quantos instantes de amostragem caem
/// dentro do quadro), não pela duração isolada: assim o arredondamento de
/// um quadro não se soma ao do próximo, e o tempo total do `.mov` bate com
/// o do WebP. Um quadro mais curto que um intervalo da taxa (só acontece
/// acima de 60 por segundo) pode dar zero — sai, em vez de deixar o resto
/// da animação mais lento.
int webpFrameCopies({
  required int startMs,
  required int durationMs,
  required double fps,
}) {
  final first = (startMs * fps / 1000).round();
  final last = ((startMs + durationMs) * fps / 1000).round();
  return last - first;
}
