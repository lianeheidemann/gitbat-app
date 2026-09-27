import 'package:flutter_test/flutter_test.dart';
import 'package:video_to_gif/core/ffmpeg/ffmpeg_service.dart';
import 'package:video_to_gif/features/quick_convert/services/animated_webp_source.dart';

// WebP animado em "Converter formato": o FFmpeg do app não decodifica, então
// os quadros saem crus pelo Flutter e o FFmpeg os junta num .mov com PNG
// (sem perda, com transparência).

void main() {
  test('quadros crus viram .mov com codec PNG e alfa, na taxa pedida', () {
    expect(
      rawRgbaToMovArgs(
        input: '/tmp/pipe1',
        width: 320,
        height: 240,
        fps: 12.5,
        outputPath: '/tmp/x/origem.mov',
      ),
      [
        '-y',
        '-f',
        'rawvideo',
        '-pix_fmt',
        'rgba',
        '-s',
        '320x240',
        '-framerate',
        '12.5000',
        '-i',
        '/tmp/pipe1',
        '-c:v',
        'png',
        '-compression_level',
        '1',
        '-pix_fmt',
        'rgba',
        '/tmp/x/origem.mov',
      ],
    );
  });

  test('quadros mais longos se repetem na taxa fixa', () {
    expect(webpFrameCopies(const Duration(milliseconds: 100), 10), 1);
    expect(webpFrameCopies(const Duration(milliseconds: 300), 10), 3);
    expect(webpFrameCopies(const Duration(milliseconds: 20), 10), 1);
    expect(webpFrameMs(Duration.zero), 100);
  });

  test('só .webp é considerado WebP animado', () async {
    expect(await isAnimatedWebp('/tmp/nao-existe.gif'), isFalse);
    expect(await isAnimatedWebp('/tmp/nao-existe.webp'), isFalse);
  });
}
