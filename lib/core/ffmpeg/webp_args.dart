import '../models/conversion_settings.dart';
import '../models/frame_settings.dart';
import '../models/video_info.dart';
import 'ffmpeg_primitives.dart';
import 'filter_graph.dart';

/// Argumentos das saídas em cor cheia, sem paleta: WebP animado e MP4.
///
/// Os dois formatos usam a mesma composição (a mesma cadeia de filtros,
/// moldura e giro de [buildWebpArgs]/[buildWebpImageFramedArgs]); só o fim
/// da linha de comando muda — ver [streamEncodeArgs].

/// O fim da linha de comando para o formato de [settings]: [mp4EncodeArgs]
/// no MP4, [webpEncodeArgs] no WebP. O MP4 nunca tem alfa — a conversão já
/// chega aqui com "Fundo transparente" desligado nele
/// ([ConversionSettings.forOutput]).
List<String> streamEncodeArgs(
  ConversionSettings settings,
  VideoInfo video, {
  required bool hasAlpha,
  bool shortest = false,
  int? frameLimit,
}) => settings.format == OutputFormat.mp4
    ? mp4EncodeArgs(settings, video, shortest: shortest, frameLimit: frameLimit)
    : webpEncodeArgs(
        settings,
        hasAlpha: hasAlpha,
        shortest: shortest,
        frameLimit: frameLimit,
      );

/// Fim da linha de comando do MP4: H.264 pelo encoder de hardware do
/// Android (`h264_mediacodec`) — a variante LGPL do FFmpeg deste app não
/// traz `libx264`, o mesmo motivo de `FfmpegService.quickConvertVideoArgs`.
/// Sem áudio, `yuv420p` (o que todo player aceita) e `+faststart` para o
/// vídeo começar a tocar antes de baixar inteiro.
List<String> mp4EncodeArgs(
  ConversionSettings settings,
  VideoInfo video, {
  bool shortest = false,
  int? frameLimit,
}) {
  final (width, height) = settings.outputDimensions(video);
  return [
    '-map',
    '[out]',
    '-c:v',
    'h264_mediacodec',
    '-b:v',
    '${mp4Bitrate(width, height, settings.fps)}',
    '-pix_fmt',
    'yuv420p',
    '-an',
    if (shortest) '-shortest',
    if (frameLimit != null) ...['-frames:v', '$frameLimit'],
    '-movflags',
    '+faststart',
    '-f',
    'mp4',
  ];
}

/// Taxa de bits do MP4, em bits por segundo: ~0,15 bit por pixel por
/// quadro, com piso de 1 Mbps. O encoder de hardware não tem `-crf`, e sem
/// uma taxa explícita ele usa um padrão baixo demais para vídeo com texto e
/// moldura nítidos.
int mp4Bitrate(int width, int height, int fps) {
  final bits = (width * height * fps * 0.15).round();
  return bits < 1000000 ? 1000000 : bits;
}

List<String> webpEncodeArgs(
  ConversionSettings settings, {
  required bool hasAlpha,
  bool shortest = false,
  int? frameLimit,
}) {
  return [
    '-map',
    '[out]',
    '-c:v',
    'libwebp',
    '-quality',
    '${settings.webpQuality}',
    '-compression_level',
    '2',
    '-pix_fmt',
    hasAlpha ? 'yuva420p' : 'yuv420p',
    '-loop',
    settings.loop ? '0' : '1',
    '-an',
    if (shortest) '-shortest',
    if (frameLimit != null) ...['-frames:v', '$frameLimit'],
    '-f',
    'webp',
  ];
}

/// Argumentos completos do FFmpeg para WebP animado sem moldura de imagem:
/// cobre tanto "sem moldura nenhuma" quanto moldura procedural (opaca ou
/// com fundo transparente). [maskPath] é a máscara de cantos arredondados
/// preparada por [_prepareMaskFile] — só é usada quando há moldura
/// procedural com fundo transparente; nos outros dois casos é ignorada.
///
/// Público (sem `_`) só para dar acesso direto aos testes de unidade —
/// [convert] continua sendo o único ponto de entrada em uso normal.
List<String> buildWebpArgs({
  required VideoInfo video,
  required ConversionSettings settings,
  required String outputPath,
  String? maskPath,
  int? frameLimit,
}) {
  // O `-map [out]` de [webpEncodeArgs] fixa o rótulo final, então quem muda
  // de nome quando há giro é o rótulo que o grafo produz — ver
  // [transformedInto].
  final (composed, tail) = transformedInto(settings.finalTransform, 'out');

  if (settings.frame.style == FrameStyle.none) {
    final filter = buildConversionVideoFilter(settings, video);
    return [
      '-y',
      '-ss',
      ffmpegSeconds(settings.startSeconds),
      '-t',
      ffmpegSeconds(settings.sourceDurationSeconds),
      '-i',
      video.path,
      '-lavfi',
      '[0:v]$filter[$composed]$tail',
      ...streamEncodeArgs(
        settings,
        video,
        hasAlpha: false,
        frameLimit: frameLimit,
      ),
      outputPath,
    ];
  }

  if (maskPath == null || !settings.frame.transparentBackground) {
    // Moldura procedural opaca: [framedGraph] já entrega um canvas RGB
    // "achatado" (sem transparência nenhuma), então basta ir direto ao
    // encoder — nem o `alphamerge` externo do GIF é necessário aqui.
    final graph = framedGraph(settings, video, input: '0:v', output: composed);
    return [
      '-y',
      '-ss',
      ffmpegSeconds(settings.startSeconds),
      '-t',
      ffmpegSeconds(settings.sourceDurationSeconds),
      '-i',
      video.path,
      '-lavfi',
      '$graph$tail',
      ...streamEncodeArgs(
        settings,
        video,
        hasAlpha: false,
        frameLimit: frameLimit,
      ),
      outputPath,
    ];
  }

  // Moldura procedural com fundo transparente: mesmo grafo/máscara de
  // [transparentGifArgs], mas sem o `split`/`palettegen`/`paletteuse` —
  // o `[alpha]` já é RGBA de verdade, então vira `[out]` direto.
  final graph = framedGraph(settings, video, input: '0:v', output: 'framed');
  return [
    '-y',
    '-ss',
    ffmpegSeconds(settings.startSeconds),
    '-t',
    ffmpegSeconds(settings.sourceDurationSeconds),
    '-i',
    video.path,
    '-loop',
    '1',
    '-framerate',
    '${settings.fps}',
    '-i',
    maskPath,
    '-lavfi',
    '$graph;'
        '[framed]format=rgba,setpts=PTS-STARTPTS[framed_rgba];'
        '[1:v]format=gray,fps=${settings.fps},'
        'setpts=PTS-STARTPTS[mask_gray];'
        '[framed_rgba][mask_gray]alphamerge=shortest=1[$composed]$tail',
    ...streamEncodeArgs(
      settings,
      video,
      hasAlpha: true,
      frameLimit: frameLimit,
    ),
    outputPath,
  ];
}

/// Argumentos completos do FFmpeg para WebP animado com moldura de imagem.
/// Reaproveita [imageFramedGraph] — que já entrega alfa real via
/// `alphamerge` quando "Fundo transparente" está ligado — e, como em
/// [buildWebpArgs], dispensa paleta: o grafo vai direto para o `libwebp`.
///
/// Mantém o `-shortest` global que o [buildImageFramedGifArgs] também usa: a
/// arte é uma entrada infinita (`-loop 1`), e por segurança (builds de
/// FFmpeg que não propagam EOF por todos os filtros complexos) a saída é
/// encerrada junto com o fluxo de vídeo.
///
/// Público (sem `_`) só para dar acesso direto aos testes de unidade —
/// [convert] continua sendo o único ponto de entrada em uso normal.
List<String> buildWebpImageFramedArgs({
  required VideoInfo video,
  required ConversionSettings settings,
  required String artPath,
  required String outputPath,
  int? frameLimit,
}) {
  final transparent = settings.frame.transparentBackground;
  final (composed, tail) = transformedInto(settings.finalTransform, 'out');
  final graph = imageFramedGraph(
    settings,
    video,
    input: '0:v',
    artInput: '1:v',
    needsAreaMask: transparent,
    output: composed,
  );

  return [
    '-y',
    '-ss',
    ffmpegSeconds(settings.startSeconds),
    '-t',
    ffmpegSeconds(settings.sourceDurationSeconds),
    '-i',
    video.path,
    '-loop',
    '1',
    '-framerate',
    '${settings.fps}',
    '-i',
    artPath,
    '-lavfi',
    '$graph$tail',
    ...streamEncodeArgs(
      settings,
      video,
      hasAlpha: transparent,
      shortest: true,
      frameLimit: frameLimit,
    ),
    outputPath,
  ];
}

/// Arredonda para o inteiro par mais próximo — mesma exigência de
/// crop/scale do FFmpeg já seguida por [ConversionSettings._evenFromDouble].
