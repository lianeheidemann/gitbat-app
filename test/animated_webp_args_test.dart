import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitbat/core/ffmpeg/ffmpeg_service.dart';
import 'package:gitbat/core/services/animated_webp_source.dart';

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
    expect(webpFrameCopies(startMs: 0, durationMs: 100, fps: 10), 1);
    expect(webpFrameCopies(startMs: 100, durationMs: 300, fps: 10), 3);
    expect(webpFrameMs(Duration.zero), 100);
  });

  test('a taxa vem do quadro mais curto e o tempo total se mantém', () {
    // Um primeiro quadro longo (1 s) não pode baixar a taxa do resto.
    const durations = [1000, 40, 40, 40, 80];
    final fps = webpIntermediateFps(40);
    expect(fps, 25);
    var start = 0;
    var total = 0;
    final copies = <int>[];
    for (final ms in durations) {
      final n = webpFrameCopies(startMs: start, durationMs: ms, fps: fps);
      copies.add(n);
      total += n;
      start += ms;
    }
    expect(copies, [25, 1, 1, 1, 2]);
    // 1,2 s a 25 quadros por segundo.
    expect(total, 30);
    expect(webpIntermediateFps(5), 60);
    expect(webpIntermediateFps(5000), 1);
  });

  test('só .webp é considerado WebP animado', () async {
    expect(await isAnimatedWebp('/tmp/nao-existe.gif'), isFalse);
    expect(await isAnimatedWebp('/tmp/nao-existe.webp'), isFalse);
  });

  test('cabeçalho do WebP animado dá tamanho, quadros e duração sem '
      'decodificar nada', () {
    List<int> u24(int v) => [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF];
    List<int> u32(int v) => [...u24(v), (v >> 24) & 0xFF];
    List<int> chunk(String tag, List<int> payload) => [
      ...tag.codeUnits,
      ...u32(payload.length),
      ...payload,
      if (payload.length.isOdd) 0,
    ];
    List<int> frame(int ms) => chunk('ANMF', [
      ...u24(0),
      ...u24(0),
      ...u24(9),
      ...u24(4),
      ...u24(ms),
      0,
    ]);
    final body = [
      ...'WEBP'.codeUnits,
      ...chunk('VP8X', [0x02, 0, 0, 0, ...u24(319), ...u24(179)]),
      ...chunk('ANIM', [0, 0, 0, 0, 0, 0]),
      ...frame(100),
      ...frame(250),
      ...frame(0),
    ];
    final bytes = Uint8List.fromList([
      ...'RIFF'.codeUnits,
      ...u32(body.length),
      ...body,
    ]);
    final info = parseAnimatedWebp(bytes)!;
    expect((info.width, info.height), (320, 180));
    expect(info.frames, 3);
    // Quadro sem duração conta 100 ms.
    expect(info.durationMs, 450);
    expect(info.shortestFrameMs, 100);
    expect(parseAnimatedWebp(Uint8List.fromList('nada'.codeUnits)), isNull);
  });
}
