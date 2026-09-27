import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_to_gif/core/ffmpeg/filter_graph.dart';
import 'package:video_to_gif/core/models/conversion_settings.dart';
import 'package:video_to_gif/core/models/frame_settings.dart';
import 'package:video_to_gif/core/models/image_frame.dart';
import 'package:video_to_gif/core/models/output_transform.dart';
import 'package:video_to_gif/core/models/photo_info.dart';
import 'package:video_to_gif/core/models/video_info.dart';
import 'package:video_to_gif/features/photo/photo_frame_page.dart';
import 'package:video_to_gif/features/photo/services/photo_frame_compositor.dart';

// Com moldura de imagem, a aba "Girar" gira só o conteúdo dentro da janela
// (a moldura fica de pé) e o botão "90°" da aba "Moldura" gira a moldura
// junto com o conteúdo. Sem moldura de imagem, "Girar" continua girando o
// resultado inteiro.

final _ceramica = ImageFrameLibrary.bundled.firstWhere(
  (a) => a.id == 'bundled_ceramica',
);

/// PNG 80x40 deitado: metade esquerda vermelha, direita azul.
Future<PhotoInfo> _landscapePhoto(Directory dir) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 40, 40),
    Paint()..color = const Color(0xFFFF0000),
  );
  canvas.drawRect(
    const Rect.fromLTWH(40, 0, 40, 40),
    Paint()..color = const Color(0xFF0000FF),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(80, 40);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  final path = '${dir.path}/foto.png';
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  return PhotoInfo(path: path, width: 80, height: 40);
}

Future<(int, int, ByteData)> _decode(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final result = (image.width, image.height, data!);
  image.dispose();
  codec.dispose();
  return result;
}

/// Cor (sem alfa) do pixel em ([fx], [fy]), frações do tamanho da imagem.
int _rgbAt((int, int, ByteData) decoded, double fx, double fy) {
  final (width, height, data) = decoded;
  final x = (width * fx).floor();
  final y = (height * fy).floor();
  return data.getUint32((y * width + x) * 4) >> 8;
}

const _red = 0xFF0000;
const _blue = 0x0000FF;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FrameSettings', () {
    const turn = OutputTransform(quarterTurns: 1, flipHorizontal: true);

    test('sem moldura de imagem, "Girar" gira o resultado inteiro', () {
      const frame = FrameSettings(outputTransform: turn, frameQuarterTurns: 1);
      expect(frame.finalTransform, turn);
      expect(frame.contentTransform, OutputTransform.identity);
    });

    test('com moldura de imagem, "Girar" fica dentro e "90°" fica fora', () {
      final frame = FrameSettings(
        imageFrame: _ceramica,
        outputTransform: turn,
        frameQuarterTurns: 3,
      );
      expect(frame.contentTransform, turn);
      expect(frame.finalTransform, const OutputTransform(quarterTurns: 3));
    });

    test('o giro da moldura dá a volta em 4 quartos', () {
      final frame = FrameSettings(imageFrame: _ceramica, frameQuarterTurns: 3);
      expect(frame.copyWith(frameQuarterTurns: 4).frameQuarterTurns, 0);
      expect(frame.copyWith(style: FrameStyle.thin).frameQuarterTurns, 3);
    });
  });

  group('exportação da foto com moldura de imagem', () {
    late Directory dir;
    late PhotoInfo photo;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('frame_rotation_test');
      photo = await _landscapePhoto(dir);
    });

    tearDown(() => dir.delete(recursive: true));

    FrameSettings frame({
      OutputTransform transform = OutputTransform.identity,
      int frameTurns = 0,
    }) => FrameSettings(
      imageFrame: _ceramica,
      contentFit: ContentFitMode.fill,
      frameResolutionMode: ImageFrameResolutionMode.nativeMax,
      outputTransform: transform,
      frameQuarterTurns: frameTurns,
    );

    test('"Girar" deixa a moldura de pé e deita só a foto', () async {
      final png = await composeFramedPhoto(
        photo: photo,
        frame: frame(transform: const OutputTransform(quarterTurns: 1)),
      );
      final decoded = await _decode(png);
      // Canvas continua o do mockup em pé (1080x1920).
      expect((decoded.$1, decoded.$2), (1080, 1920));
      // Girada 90° no sentido horário, a metade esquerda (vermelha) vai
      // para cima e a direita (azul) para baixo, dentro da janela.
      expect(_rgbAt(decoded, 0.5, 0.3), _red);
      expect(_rgbAt(decoded, 0.5, 0.7), _blue);
    });

    test('sem giro, a foto fica deitada dentro da moldura em pé', () async {
      final decoded = await _decode(
        await composeFramedPhoto(photo: photo, frame: frame()),
      );
      expect((decoded.$1, decoded.$2), (1080, 1920));
      // "Preencher" cobre a janela em pé a partir do centro da foto: a
      // esquerda da janela é vermelha, a direita é azul.
      expect(_rgbAt(decoded, 0.3, 0.5), _red);
      expect(_rgbAt(decoded, 0.7, 0.5), _blue);
    });

    test(
      'o fundo da janela sai com a cor escolhida em qualquer ajuste',
      () async {
        FrameSettings expand(ContentFitMode fit) => FrameSettings(
          imageFrame: _ceramica,
          contentFit: fit,
          contentZoom: 0.5,
          frameResolutionMode: ImageFrameResolutionMode.nativeMax,
          expandBackgroundColor: const Color(0xFF00FF00),
        );
        // Foto deitada reduzida a 50% no meio da janela em pé: logo abaixo
        // do topo da janela só há fundo.
        final colored = await _decode(
          await composeFramedPhoto(
            photo: photo,
            frame: expand(ContentFitMode.expand),
          ),
        );
        expect(_rgbAt(colored, 0.5, 0.2), 0x00FF00);
        // "Encaixar" também usa a cor escolhida nas barras (antes, preto).
        final fitted = await _decode(
          await composeFramedPhoto(
            photo: photo,
            frame: expand(ContentFitMode.fit),
          ),
        );
        expect(_rgbAt(fitted, 0.5, 0.2), 0x00FF00);
      },
    );

    test('"90°" deita a moldura junto com a foto', () async {
      final decoded = await _decode(
        await composeFramedPhoto(photo: photo, frame: frame(frameTurns: 1)),
      );
      expect((decoded.$1, decoded.$2), (1920, 1080));
      // A composição de pé ([sem giro]) girada 90° no sentido horário: o
      // que era esquerda (vermelho) vai para cima.
      expect(_rgbAt(decoded, 0.5, 0.3), _red);
      expect(_rgbAt(decoded, 0.5, 0.7), _blue);
    });
  });

  testWidgets('"Editar imagem": abas "Borda" e "Moldura" e o botão "90°"', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final dir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('frame_rotation_page'),
    );
    addTearDown(() => dir!.delete(recursive: true));
    final photo = await tester.runAsync(() => _landscapePhoto(dir!));

    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: PhotoFramePage(photo: photo!)));
    await tester.pumpAndSettle();

    // Os rótulos antigos ("Imagem") sumiram do rodapé.
    expect(find.text('Imagem'), findsNothing);
    expect(find.text('Borda'), findsOneWidget);

    await tester.tap(find.text('Moldura').last);
    await tester.pumpAndSettle();
    final thumb = find.byKey(const ValueKey('imageFrameThumb_bundled_titanio'));
    await tester.ensureVisible(thumb);
    await tester.pumpAndSettle();
    await tester.tap(thumb);
    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey('frameRotateButton'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Titânio · 90°'), findsOneWidget);

    // Desfazer volta a moldura de pé.
    await tester.tap(find.byTooltip('Desfazer'));
    await tester.pumpAndSettle();
    expect(find.text('Titânio · 90°'), findsNothing);
  });

  test('FFmpeg: o fundo de "Expandir sem cortar" usa a cor escolhida', () {
    const video = VideoInfo(
      path: '/tmp/v.mp4',
      fileName: 'v.mp4',
      rawWidth: 640,
      rawHeight: 360,
      durationSeconds: 2,
      frameRate: 30,
      bitrateBps: 1000000,
      fileSizeBytes: 100000,
      codec: 'h264',
    );
    String graph(Color? color) => imageFramedGraph(
      ConversionSettings(
        startSeconds: 0,
        endSeconds: 2,
        frame: FrameSettings(
          imageFrame: _ceramica,
          contentFit: ContentFitMode.expand,
          expandBackgroundColor: color ?? const Color(0xFF000000),
        ),
      ),
      video,
      input: '0:v',
      artInput: '1:v',
      output: 'framed',
    );
    expect(graph(const Color(0xFFFF0000)), contains('color=0xff0000:t=fill'));
    expect(graph(null), contains('color=0x000000:t=fill'));
  });
}
