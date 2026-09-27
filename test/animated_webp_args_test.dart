import 'package:flutter_test/flutter_test.dart';
import 'package:video_to_gif/core/ffmpeg/ffmpeg_service.dart';
import 'package:video_to_gif/features/quick_convert/services/animated_webp_source.dart';

// WebP animado em "Converter formato": o FFmpeg do app não decodifica, então
// os quadros saem pelo Flutter e são juntados num .mov com PNG (sem perda,
// com transparência).

void main() {
  test('PNGs viram .mov com codec PNG e alfa, na taxa pedida', () {
    expect(
      pngSequenceToMovArgs(
        framePattern: '/tmp/x/quadro_%05d.png',
        fps: 12.5,
        outputPath: '/tmp/x/origem.mov',
      ),
      [
        '-y',
        '-framerate',
        '12.5000',
        '-i',
        '/tmp/x/quadro_%05d.png',
        '-c:v',
        'png',
        '-pix_fmt',
        'rgba',
        '/tmp/x/origem.mov',
      ],
    );
  });

  test('só .webp é considerado WebP animado', () async {
    expect(await isAnimatedWebp('/tmp/nao-existe.gif'), isFalse);
    expect(await isAnimatedWebp('/tmp/nao-existe.webp'), isFalse);
  });
}
