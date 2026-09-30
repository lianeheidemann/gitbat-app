import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gitbat/core/ffmpeg/ffmpeg_service.dart';
import 'package:gitbat/core/ffmpeg/webp_args.dart';
import 'package:gitbat/core/models/conversion_settings.dart';
import 'package:gitbat/core/models/frame_settings.dart';
import 'package:gitbat/core/models/image_frame.dart';
import 'package:gitbat/core/models/video_info.dart';
import 'package:gitbat/core/ui/editor_tabs_footer.dart';
import 'package:gitbat/features/video/editor_page.dart';

// O MP4 reaproveita a composição do WebP (mesmos filtros, moldura e giro) e
// troca só o fim da linha de comando — ver `webp_args.dart`. Estes testes
// garantem o contrato do formato: H.264 sem som e sem transparência nenhuma,
// com "Fundo transparente" virando a cor do fundo.

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

String _lavfiOf(List<String> args) => args[args.indexOf('-lavfi') + 1];

void _expectFlagValue(List<String> args, String flag, String value) {
  final index = args.indexOf(flag);
  expect(index, greaterThanOrEqualTo(0), reason: 'flag $flag não encontrada');
  expect(args[index + 1], value, reason: 'valor de $flag');
}

void main() {
  final ffmpeg = FfmpegService();

  group('modelo', () {
    test('MP4 é vídeo e não guarda transparência', () {
      expect(OutputFormat.mp4.isVideo, isTrue);
      expect(OutputFormat.mp4.supportsTransparency, isFalse);
      expect(OutputFormat.gif.supportsTransparency, isTrue);
      expect(OutputFormat.webp.supportsTransparency, isTrue);
    });

    test('no MP4, "Fundo transparente" sai com a cor do fundo', () {
      const frame = FrameSettings(
        style: FrameStyle.medium,
        transparentBackground: true,
        backgroundColor: Color(0xFF123456),
      );
      final mp4 = ConversionSettings(
        startSeconds: 0,
        endSeconds: 5,
        format: OutputFormat.mp4,
        frame: frame,
      );
      final webp = mp4.copyWith(format: OutputFormat.webp);

      expect(mp4.outputFrame.transparentBackground, isFalse);
      expect(mp4.outputFrame.backgroundColor, const Color(0xFF123456));
      expect(mp4.forOutput.frame.transparentBackground, isFalse);
      // A escolha da pessoa fica guardada: voltar para WebP devolve o
      // fundo transparente.
      expect(mp4.frame.transparentBackground, isTrue);
      expect(webp.outputFrame.transparentBackground, isTrue);
      expect(identical(webp.forOutput, webp), isTrue);
    });

    test('taxa de bits cresce com a imagem e tem piso de 1 Mbps', () {
      expect(mp4Bitrate(320, 240, 10), 1000000);
      expect(mp4Bitrate(1080, 1920, 24), (1080 * 1920 * 24 * 0.15).round());
    });
  });

  group('argumentos', () {
    test('sem moldura: H.264 do Android, sem som, sem paleta', () {
      final settings = ConversionSettings(
        startSeconds: 0,
        endSeconds: 5,
        format: OutputFormat.mp4,
      );
      final args = ffmpeg.webpArgs(
        video: _video,
        settings: settings,
        outputPath: '/tmp/saida.mp4',
      );

      _expectFlagValue(args, '-c:v', 'h264_mediacodec');
      _expectFlagValue(args, '-pix_fmt', 'yuv420p');
      _expectFlagValue(args, '-movflags', '+faststart');
      _expectFlagValue(args, '-f', 'mp4');
      expect(args, contains('-an'));
      expect(args, contains('-b:v'));
      expect(args, isNot(contains('libwebp')));
      expect(args, isNot(contains('-loop')));
      expect(_lavfiOf(args), isNot(contains('palettegen')));
      expect(args.last, '/tmp/saida.mp4');
    });

    test('moldura com fundo transparente vira fundo de cor, sem alfa', () {
      final settings = ConversionSettings(
        startSeconds: 0,
        endSeconds: 5,
        format: OutputFormat.mp4,
        frame: const FrameSettings(
          style: FrameStyle.medium,
          thicknessAtReference: 10,
          cornerRatio: 0.12,
          transparentBackground: true,
        ),
      ).forOutput;
      final args = ffmpeg.webpArgs(
        video: _video,
        settings: settings,
        outputPath: '/tmp/saida.mp4',
        maskPath: '/tmp/mascara.png',
      );

      // O grafo ainda usa alfa por dentro para arredondar os cantos (como no
      // WebP opaco); o contrato é não receber a máscara externa do fundo
      // transparente e entregar pixels sem alfa ao encoder.
      _expectFlagValue(args, '-pix_fmt', 'yuv420p');
      expect(_lavfiOf(args), isNot(contains('mask_gray')));
      expect(args.where((a) => a == '-i'), hasLength(1));
    });

    test('moldura de imagem: mesmo grafo do WebP, sem alfa', () {
      final settings = ConversionSettings(
        startSeconds: 0,
        endSeconds: 5,
        format: OutputFormat.mp4,
        frame: FrameSettings(
          imageFrame: ImageFrameLibrary.bundled.first,
          transparentBackground: true,
        ),
      ).forOutput;
      final args = ffmpeg.webpImageFramedArgs(
        video: _video,
        settings: settings,
        artPath: '/tmp/arte.png',
        outputPath: '/tmp/saida.mp4',
      );

      _expectFlagValue(args, '-c:v', 'h264_mediacodec');
      _expectFlagValue(args, '-pix_fmt', 'yuv420p');
      expect(args, contains('-shortest'));
      expect(_lavfiOf(args), isNot(contains('alphamerge')));
    });
  });

  testWidgets('escolher MP4 tira as abas "Cores" e "Qualidade"', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: EditorPage(
          video: _video,
          initialSettings: ConversionSettings.recommendedFor(_video),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    Finder tab(String label) => find.descendant(
      of: find.byType(EditorTabsFooter),
      matching: find.text(label),
    );

    // A aba "Formato" abre primeiro, com os três formatos.
    expect(find.text('Vídeo MP4'), findsOneWidget);
    expect(tab('Cores'), findsOneWidget);

    await tester.tap(find.text('Vídeo MP4'));
    await tester.pump();

    expect(tab('Cores'), findsNothing);
    expect(tab('Qualidade'), findsNothing);
    expect(
      find.byTooltip('Converter em MP4'),
      findsOneWidget,
      reason: 'o botão de baixar diz o formato',
    );
  });
}
