import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Canvas, Color, Paint, Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:video_to_gif/features/collage/models/collage_cell.dart';
import 'package:video_to_gif/features/collage/models/collage_export.dart';
import 'package:video_to_gif/features/collage/models/collage_layout.dart';
import 'package:video_to_gif/features/collage/models/collage_settings.dart';
import 'package:video_to_gif/features/collage/services/collage_animation.dart';

import 'helpers/animated_gif.dart';

/// PNG sólido: uma foto parada de verdade em disco.
Future<void> _writeSolidPng(String path, Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 40, 40), Paint()..color = color);
  final picture = recorder.endRecording();
  final image = await picture.toImage(40, 40);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('collage_animation_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  CollageSettings settingsWith(List<String> paths) => CollageSettings(
    layout: CollageLayout.row(paths.length),
    aspectRatio: paths.length.toDouble(),
    outerMarginRatio: 0,
    innerMarginRatio: 0,
    cells: [
      for (final path in paths)
        CollageCellSettings(photoPath: path, photoWidth: 40, photoHeight: 40),
    ],
  );

  test('montagem só com fotos paradas não tem animação nenhuma', () async {
    final path = '${tempDir.path}/parada.png';
    await _writeSolidPng(path, const Color(0xFFFF0000));

    final info = await inspectCollageAnimation(settingsWith([path]));
    expect(info.hasAnimation, isFalse);
    expect(info.animatedCount, 0);
  });

  test('reconhece o GIF animado e mede a duração', () async {
    final gif = '${tempDir.path}/curto.gif';
    await writeAnimatedGif(gif, frames: 4, delayCentiseconds: 10);

    final info = await inspectCollageAnimation(settingsWith([gif]));
    expect(info.hasAnimation, isTrue);
    expect(info.animatedCount, 1);
    // 4 quadros de 100ms.
    expect(info.longest.inMilliseconds, 400);
    expect(info.shortest.inMilliseconds, 400);
    expect(info.hasDifferentDurations, isFalse);
  });

  test(
    'durações diferentes: a mais longa e a mais curta são separadas',
    () async {
      final curto = '${tempDir.path}/curto.gif';
      final longo = '${tempDir.path}/longo.gif';
      await writeAnimatedGif(curto, frames: 2, delayCentiseconds: 10);
      await writeAnimatedGif(longo, frames: 6, delayCentiseconds: 10);

      final info = await inspectCollageAnimation(settingsWith([curto, longo]));
      expect(info.animatedCount, 2);
      expect(info.shortest.inMilliseconds, 200);
      expect(info.longest.inMilliseconds, 600);
      expect(info.hasDifferentDurations, isTrue);
      expect(
        info.durationFor(CollageDurationRule.shortest).inMilliseconds,
        200,
      );
      expect(info.durationFor(CollageDurationRule.longest).inMilliseconds, 600);
    },
  );

  test('"a mais longa" rende mais quadros que "a mais curta"', () async {
    final curto = '${tempDir.path}/curto.gif';
    final longo = '${tempDir.path}/longo.gif';
    await writeAnimatedGif(curto, frames: 2, delayCentiseconds: 10);
    await writeAnimatedGif(longo, frames: 8, delayCentiseconds: 10);
    final settings = settingsWith([curto, longo]);

    final longDir = await Directory('${tempDir.path}/longa').create();
    final longSeq = await renderCollageFrames(
      settings: settings,
      outputWidth: 40,
      rule: CollageDurationRule.longest,
      workDir: longDir,
    );

    final shortDir = await Directory('${tempDir.path}/curta').create();
    final shortSeq = await renderCollageFrames(
      settings: settings,
      outputWidth: 40,
      rule: CollageDurationRule.shortest,
      workDir: shortDir,
    );

    expect(longSeq.frameCount, greaterThan(shortSeq.frameCount));
    // Os PNGs saíram mesmo em disco, numerados para o FFmpeg.
    expect(longDir.listSync().whereType<File>().length, longSeq.frameCount);
    expect(longSeq.pattern, endsWith('quadro_%05d.png'));
    expect(longSeq.fps, greaterThanOrEqualTo(5));
  });

  test('a animação curta segura o último quadro em vez de sumir', () async {
    // Curto (2 quadros = 200ms) ao lado de longo (8 quadros = 800ms): depois
    // dos 200ms, os quadros da montagem continuam mostrando o ÚLTIMO quadro
    // do curto — nada de sumir, piscar ou reiniciar. Comparando o pedaço da
    // esquerda (foto curta) do primeiro quadro depois do fim com o do último
    // quadro da montagem, os dois têm que ser idênticos.
    final curto = '${tempDir.path}/curto.gif';
    final longo = '${tempDir.path}/longo.gif';
    await writeAnimatedGif(curto, frames: 2, delayCentiseconds: 10);
    await writeAnimatedGif(longo, frames: 8, delayCentiseconds: 10);

    final workDir = await Directory('${tempDir.path}/quadros').create();
    final sequence = await renderCollageFrames(
      settings: settingsWith([curto, longo]),
      outputWidth: 80,
      rule: CollageDurationRule.longest,
      workDir: workDir,
    );

    final files = workDir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(files.length, sequence.frameCount);

    Future<List<int>> leftPixel(File file) async {
      final codec = await ui.instantiateImageCodec(await file.readAsBytes());
      final frame = await codec.getNextFrame();
      try {
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        // Metade esquerda do canvas = a foto curta.
        final offset = (10 * frame.image.width + 10) * 4;
        return [
          data!.getUint8(offset),
          data.getUint8(offset + 1),
          data.getUint8(offset + 2),
          data.getUint8(offset + 3),
        ];
      } finally {
        frame.image.dispose();
        codec.dispose();
      }
    }

    final afterEnd = await leftPixel(files[files.length ~/ 2]);
    final last = await leftPixel(files.last);
    expect(afterEnd[3], 255, reason: 'a foto curta não pode sumir no fim');
    expect(last, afterEnd);
  });

  test('a mesma animação em duas áreas anda junto, quadro a quadro', () async {
    // Os quadros são lidos um por vez (sem guardar todos na memória); uma
    // foto repetida em duas áreas usa o mesmo quadro nas duas.
    final longo = '${tempDir.path}/longo.gif';
    await writeAnimatedGif(longo, frames: 8, delayCentiseconds: 10);
    final workDir = await Directory('${tempDir.path}/par').create();
    final sequence = await renderCollageFrames(
      settings: settingsWith([longo, longo]),
      outputWidth: 80,
      rule: CollageDurationRule.longest,
      workDir: workDir,
    );
    final files = workDir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(files.length, sequence.frameCount);

    Future<(List<int>, List<int>)> pixels(File file) async {
      final codec = await ui.instantiateImageCodec(await file.readAsBytes());
      final frame = await codec.getNextFrame();
      try {
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        List<int> at(int x) {
          final o = (10 * frame.image.width + x) * 4;
          return [
            data!.getUint8(o),
            data.getUint8(o + 1),
            data.getUint8(o + 2),
          ];
        }

        return (at(10), at(frame.image.width - 10));
      } finally {
        frame.image.dispose();
        codec.dispose();
      }
    }

    final seen = <String>{};
    for (final file in files) {
      final (left, right) = await pixels(file);
      expect(left, right, reason: 'as duas áreas mostram o mesmo quadro');
      seen.add(left.join(','));
    }
    expect(seen.length, greaterThan(1), reason: 'a animação avança');
  });
}
