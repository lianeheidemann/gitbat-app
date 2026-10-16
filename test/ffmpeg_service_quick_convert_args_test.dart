import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:gitbat/core/ffmpeg/webp_args.dart' show mp4Bitrate;
import 'package:gitbat/core/models/quick_convert_format.dart';
import 'package:gitbat/core/models/video_info.dart';
import 'package:gitbat/core/ffmpeg/ffmpeg_service.dart';

// quickConvertVideoArgs monta a linha de comando do único formato de vídeo
// oferecido por "Converter formato" (MP4) — uma função pura, sem tocar o
// FFmpeg de verdade, então dá para conferir os argumentos direto.

const _video = VideoInfo(
  path: '/tmp/exemplo.mp4',
  fileName: 'exemplo.mp4',
  rawWidth: 1080,
  rawHeight: 1920,
  durationSeconds: 5,
  frameRate: 30,
  bitrateBps: 6000000,
  fileSizeBytes: 3000000,
  codec: 'h264',
);

void _expectFlagValue(List<String> args, String flag, String value) {
  final index = args.indexOf(flag);
  expect(index, greaterThanOrEqualTo(0), reason: 'flag $flag não encontrada');
  expect(args[index + 1], value, reason: 'valor de $flag');
}

void main() {
  final ffmpeg = FfmpegService();

  group('quickConvertVideoArgs — MP4', () {
    test('usa h264_mediacodec (encoder de hardware) + aac, mantendo áudio '
        'quando existir', () {
      final args = ffmpeg.quickConvertVideoArgs(
        video: _video,
        format: QuickConvertFormat.mp4,
        width: 720,
        outputPath: '/tmp/saida.mp4',
      );

      _expectFlagValue(args, '-c:v', 'h264_mediacodec');
      _expectFlagValue(args, '-c:a', 'aac');
      _expectFlagValue(args, '-f', 'mp4');
      _expectFlagValue(
        args,
        '-vf',
        'scale=720:1280:flags=lanczos+accurate_rnd+full_chroma_int:'
            'out_color_matrix=bt709:out_range=tv,format=yuv420p',
      );
      expect(args, contains('-movflags'));
      // Vídeo comum: o FFmpeg escolhe sozinho os streams, sem `-map`.
      expect(args, isNot(contains('-map')));
      expect(args, isNot(contains('-filter_complex')));
      expect(args, isNot(contains('-preset')));
      expect(args, isNot(contains('-crf')));
      expect(args.last, '/tmp/saida.mp4');
    });

    test('taxa de bits explícita — sem ela o encoder cai em 200 kb/s', () {
      final args = ffmpeg.quickConvertVideoArgs(
        video: _video,
        format: QuickConvertFormat.mp4,
        width: 1080,
        outputPath: '/tmp/saida.mp4',
      );
      _expectFlagValue(args, '-b:v', '${mp4Bitrate(1080, 1920, 30)}');
      expect(mp4Bitrate(1080, 1920, 30), greaterThan(5000000));
    });

    test('converte e etiqueta a cor em BT.709, em yuv420p', () {
      final args = ffmpeg.quickConvertVideoArgs(
        video: _video,
        format: QuickConvertFormat.mp4,
        width: 720,
        outputPath: '/tmp/saida.mp4',
      );
      _expectFlagValue(args, '-pix_fmt', 'yuv420p');
      _expectFlagValue(args, '-colorspace', 'bt709');
      _expectFlagValue(args, '-color_primaries', 'bt709');
      _expectFlagValue(args, '-color_trc', 'bt709');
      _expectFlagValue(args, '-color_range', 'tv');
      _expectFlagValue(args, '-movflags', '+faststart+write_colr');
    });

    test('GIF e WebP: a transparência vira a cor de fundo', () {
      for (final codec in ['gif', 'webp']) {
        final video = VideoInfo(
          path: '/tmp/origem.mov',
          fileName: 'origem.$codec',
          rawWidth: 640,
          rawHeight: 480,
          durationSeconds: 2,
          frameRate: 12.5,
          bitrateBps: 0,
          fileSizeBytes: 1000,
          codec: codec,
        );
        final args = ffmpeg.quickConvertVideoArgs(
          video: video,
          format: QuickConvertFormat.mp4,
          width: 320,
          outputPath: '/tmp/saida.mp4',
          background: const Color(0xFF123456),
        );
        expect(args, isNot(contains('-vf')), reason: codec);
        final graph = args[args.indexOf('-filter_complex') + 1];
        expect(graph, contains('scale=320:240:'), reason: codec);
        expect(graph, contains('color=0x123456:t=fill'), reason: codec);
        expect(graph, contains('overlay=0:0:format=rgb'), reason: codec);
        expect(graph, endsWith('format=yuv420p[out]'), reason: codec);
        _expectFlagValue(args, '-map', '[out]');
        expect(args, containsAllInOrder(['-map', '[out]', '-map', '0:a?']));
        _expectFlagValue(args, '-b:v', '${mp4Bitrate(320, 240, 13)}');
      }
    });
  });

  group('QuickConvertFormat.isAnimatedImage', () {
    test('só gif e webp são imagem animada', () {
      expect(QuickConvertFormat.gif.isAnimatedImage, isTrue);
      expect(QuickConvertFormat.webp.isAnimatedImage, isTrue);
      expect(QuickConvertFormat.mp4.isAnimatedImage, isFalse);
    });
  });
}
