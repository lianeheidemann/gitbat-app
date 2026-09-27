import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/models/crop_rect.dart';
import '../../../core/models/frame_settings.dart';
import '../../../core/models/image_frame.dart';
import '../../../core/models/output_transform.dart';
import '../../../core/models/photo_info.dart';
import '../../collage/painting/collage_painter.dart' show paintCollageTextItem;
import '../../../core/painting/frame_painter.dart';
import '../../collage/services/collage_compositor.dart'
    show paintCollageSticker;

/// Compõe uma [PhotoInfo] com a [FrameSettings] escolhida (moldura
/// procedural ou moldura de imagem) num PNG final, com `dart:ui`/[Canvas]
/// puro — ao contrário do vídeo, uma foto não tem quadros nem tempo, então
/// não há necessidade do pipeline de FFmpeg usado por
/// `FfmpegService._framedGraph`/`_imageFramedGraph`; esta função replica a
/// mesma lógica de ajuste de conteúdo (cover/contain/expandir com zoom)
/// diretamente em cima da imagem decodificada.
Future<Uint8List> composeFramedPhoto({
  required PhotoInfo photo,
  required FrameSettings frame,
}) async {
  final image = await _decodeImageFile(photo.path);
  try {
    return await (frame.imageFrame != null
        ? _composeImageFramed(photo, image, frame)
        : _composeProcedural(photo, image, frame));
  } finally {
    image.dispose();
  }
}

/// Moldura procedural (ou nenhuma): canvas no tamanho da janela escolhida na
/// aba "Recorte" (`frame.crop`), ou no tamanho nativo da foto quando nenhuma
/// foi escolhida ("Original"). Sem nenhum passo assíncrono no meio, pode usar
/// [rasterizeCanvas] direto, igual a [FramePainter.rasterize].
Future<Uint8List> _composeProcedural(
  PhotoInfo photo,
  ui.Image image,
  FrameSettings frame,
) async {
  final crop =
      frame.crop ??
      CropRect(x: 0, y: 0, width: photo.width, height: photo.height);

  // O giro é o último passo: o canvas já sai com os lados trocados, mas
  // tudo abaixo continua desenhando na orientação original da foto — por
  // isso `size` vem do recorte, não do canvas.
  // Sem moldura de imagem, `finalTransform` é o próprio giro da aba
  // "Girar": a borda acompanha a foto.
  final (canvasWidth, canvasHeight) = transformedCanvasSize(
    frame.finalTransform,
    crop.width,
    crop.height,
  );
  final size = Size(crop.width.toDouble(), crop.height.toDouble());
  final stickers = await _stickerLayer(size, frame);

  try {
    return await rasterizeCanvas(canvasWidth, canvasHeight, (canvas, _) {
      applyCanvasOutputTransform(canvas, frame.finalTransform, size);
      // `paintFrame` já não desenha nada quando o estilo é `none`, e a
      // geometria correspondente cobre o canvas inteiro sem cantos
      // arredondados — então não precisa de um caso especial para "sem
      // moldura": o recorte abaixo já sai igual à foto (já cortada).
      // Sem borda, "Fundo transparente" desligado pinta a cor atrás da
      // foto inteira (aparece onde ela é transparente, ou em volta dela se
      // foi diminuída); com borda, `paintFrame` já cuida do fundo.
      if (frame.style == FrameStyle.none && !frame.transparentBackground) {
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = frame.backgroundColor,
        );
      }
      paintFrame(canvas, size, frame);
      final geometry = FrameGeometry.of(size, frame);
      if (frame.style != FrameStyle.none) {
        // `paintFrame` enche o retângulo todo com a cor da borda (no vídeo o
        // conteúdo cobre o miolo). Na foto o miolo volta a ficar vazio —
        // transparente ou com a cor do fundo —, para as partes
        // transparentes da foto não saírem com a cor da borda.
        canvas.drawRRect(
          geometry.contentClip,
          Paint()..blendMode = BlendMode.clear,
        );
        if (!frame.transparentBackground) {
          canvas.drawRRect(
            geometry.contentClip,
            Paint()..color = frame.backgroundColor,
          );
        }
      }
      canvas.save();
      canvas.clipRRect(geometry.contentClip);
      final coverSrc = _coverSrcRect(
        crop.width.toDouble(),
        crop.height.toDouble(),
        geometry.contentRect.width,
        geometry.contentRect.height,
      );
      final srcRect = coverSrc.shift(
        Offset(crop.x.toDouble(), crop.y.toDouble()),
      );
      // Posição livre (arrastar/pinçar/girar na prévia), em volta da janela.
      frame.placement.applyTo(canvas, geometry.contentRect);
      canvas.drawImageRect(
        image,
        srcRect,
        geometry.contentRect,
        Paint()
          ..filterQuality = FilterQuality.high
          // Só a foto leva o ajuste de cor: a moldura e o fundo são pintados
          // fora deste `Paint`, então continuam com a cor escolhida.
          ..colorFilter = frame.adjustments.filter,
      );
      canvas.restore();
      if (stickers != null) canvas.drawImage(stickers, Offset.zero, Paint());
      _paintTexts(canvas, size, frame);
    });
  } finally {
    stickers?.dispose();
  }
}

/// Desenha `FrameSettings.texts`, ordenados por `zIndex`, sobre o canvas
/// final já composto — mesmo desenho da prévia ao vivo (`TextOverlayStack`),
/// para as duas nunca divergirem.
/// Desenha `FrameSettings.stickers` (por baixo dos textos) numa imagem do
/// tamanho [size] — à parte porque carregar a arte é assíncrono e o canvas
/// da moldura procedural é síncrono. `null` sem sticker nenhum.
Future<ui.Image?> _stickerLayer(Size size, FrameSettings frame) async {
  if (frame.stickers.isEmpty) return null;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final sorted = [...frame.stickers]
    ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
  for (final sticker in sorted) {
    await paintCollageSticker(canvas, size, sticker);
  }
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(size.width.round(), size.height.round());
  } finally {
    picture.dispose();
  }
}

void _paintTexts(Canvas canvas, Size size, FrameSettings frame) {
  final sorted = [...frame.texts]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
  for (final item in sorted) {
    paintCollageTextItem(canvas, size, item);
  }
}

/// Moldura de imagem: canvas dimensionado por
/// [FrameSettings.frameResolutionMode], com a foto ajustada dentro da
/// janela de conteúdo da arte ([ImageFrameAsset.contentRect]) conforme
/// [ContentFitMode], e a arte desenhada por cima. Não usa [rasterizeCanvas]
/// porque desenhar a arte precisa de um passo assíncrono
/// (`vg.loadPicture`/decodificar um PNG importado) entre os outros
/// desenhos, que a assinatura síncrona de [rasterizeCanvas] não permite.
Future<Uint8List> _composeImageFramed(
  PhotoInfo photo,
  ui.Image image,
  FrameSettings frame,
) async {
  final asset = frame.imageFrame!;
  final (canvasWidth, canvasHeight) = _imageFrameCanvasDimensions(
    photo,
    asset,
    frame.frameResolutionMode,
  );
  final size = Size(canvasWidth.toDouble(), canvasHeight.toDouble());
  // Ver [_composeProcedural]: o canvas gravado já é o girado, a composição
  // continua acontecendo em [size], na orientação original. Aqui o giro do
  // resultado é só o da própria moldura (botão "90°" da aba "Moldura"); o
  // da aba "Girar" vale só para a foto, dentro da janela — ver
  // [_drawTransformedPhoto].
  final (outputWidth, outputHeight) = transformedCanvasSize(
    frame.finalTransform,
    canvasWidth,
    canvasHeight,
  );
  final areaRect = Rect.fromLTWH(
    size.width * asset.contentRect.left,
    size.height * asset.contentRect.top,
    size.width * asset.contentRect.width,
    size.height * asset.contentRect.height,
  );

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  applyCanvasOutputTransform(canvas, frame.finalTransform, size);

  if (!frame.transparentBackground) {
    canvas.drawRect(Offset.zero & size, Paint()..color = frame.backgroundColor);
  }

  // Região efetiva da foto depois do recorte escolhido na aba "Recorte" —
  // a imagem inteira quando nenhuma janela foi escolhida ("Original").
  final crop = frame.crop;
  final effectiveRect = crop == null
      ? Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble())
      : Rect.fromLTWH(
          crop.x.toDouble(),
          crop.y.toDouble(),
          crop.width.toDouble(),
          crop.height.toDouble(),
        );
  final paint = Paint()
    ..filterQuality = FilterQuality.high
    // Vale para os três modos de encaixe abaixo; a arte da moldura é
    // desenhada com outro `Paint`, sem o filtro.
    ..colorFilter = frame.adjustments.filter;
  // A foto entra na janela já girada/espelhada pela aba "Girar": o encaixe
  // é calculado sobre a proporção dela depois do giro.
  final transform = frame.contentTransform;
  final (turnedWidth, turnedHeight) = transform.swapsAxes
      ? (effectiveRect.height, effectiveRect.width)
      : (effectiveRect.width, effectiveRect.height);
  final fit = resolveContentFit(
    frame.contentFit,
    turnedWidth / turnedHeight,
    areaRect.width / areaRect.height,
  );

  // Fundo da área: a "Cor do fundo da moldura"
  // ([FrameSettings.expandBackgroundColor]) em qualquer ajuste — aparece em
  // volta da foto reduzida, nas barras de "Encaixar" e nas partes
  // transparentes da foto. Igual a `imageFramedGraph`.
  canvas.save();
  canvas.clipRect(areaRect);
  canvas.drawRect(areaRect, Paint()..color = frame.expandBackgroundColor);
  final Rect dst;
  switch (fit) {
    case ContentFitMode.expand:
      // Mesma composição de `imageFramedGraph`: a foto cabe inteira dentro
      // da área (escala mínima dos dois eixos), o zoom amplia ou reduz só
      // ela, e o que passar da área é recortado.
      final fitScale = math.min(
        areaRect.width / turnedWidth,
        areaRect.height / turnedHeight,
      );
      final zoom = frame.effectiveContentZoom;
      final drawWidth = turnedWidth * fitScale * zoom;
      final drawHeight = turnedHeight * fitScale * zoom;
      dst = Rect.fromLTWH(
        areaRect.left + (areaRect.width - drawWidth) / 2,
        areaRect.top + (areaRect.height - drawHeight) / 2,
        drawWidth,
        drawHeight,
      );
    case ContentFitMode.fill:
      dst = _coverDstRect(turnedWidth, turnedHeight, areaRect);
    case ContentFitMode.auto:
    case ContentFitMode.fit:
      dst = _containDstRect(turnedWidth, turnedHeight, areaRect);
  }
  // Posição livre (arrastar/pinçar/girar na prévia), em volta da foto.
  frame.placement.applyTo(canvas, dst);
  _drawTransformedPhoto(canvas, image, effectiveRect, dst, transform, paint);
  canvas.restore();

  await _drawArtwork(canvas, size, asset);
  final stickers = await _stickerLayer(size, frame);
  if (stickers != null) canvas.drawImage(stickers, Offset.zero, Paint());
  _paintTexts(canvas, size, frame);

  final picture = recorder.endRecording();
  try {
    final composed = await picture.toImage(outputWidth, outputHeight);
    try {
      final bytes = await composed.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    } finally {
      composed.dispose();
    }
  } finally {
    picture.dispose();
    stickers?.dispose();
  }
}

/// Tamanho do canvas de uma moldura de imagem: [ImageFrameResolutionMode.nativeMax]
/// usa a resolução original da arte; [ImageFrameResolutionMode.matchAjustar]
/// (rotulado como "Da foto" nesta tela, já que não há uma aba "Ajustar" de
/// resolução) usa o maior lado da própria foto escolhida como base,
/// mantendo a proporção nativa da arte.
(int, int) _imageFrameCanvasDimensions(
  PhotoInfo photo,
  ImageFrameAsset asset,
  ImageFrameResolutionMode mode,
) {
  if (mode == ImageFrameResolutionMode.nativeMax) {
    final width = asset.nativeReferenceWidth;
    final height = (width / asset.nativeAspectRatio).round();
    return (width, height);
  }

  final base = math.max(photo.width, photo.height).toDouble();
  if (asset.nativeAspectRatio >= 1) {
    return (base.round(), (base / asset.nativeAspectRatio).round());
  }
  return ((base * asset.nativeAspectRatio).round(), base.round());
}

/// Desenha a arte de uma moldura de imagem ocupando o canvas inteiro —
/// mesmos três formatos de [ImageFrameSource] que
/// `EditorPage._imageFrameArtwork` sabe exibir na prévia.
Future<void> _drawArtwork(
  Canvas canvas,
  Size size,
  ImageFrameAsset asset,
) async {
  switch (asset.source) {
    case ImageFrameSource.bundledSvg:
      final loader = SvgAssetLoader(asset.svgAssetPath!);
      await _drawPicture(canvas, size, vg.loadPicture(loader, null));
      break;
    case ImageFrameSource.importedSvg:
      final loader = SvgFileLoader(File(asset.imageFilePath!));
      await _drawPicture(canvas, size, vg.loadPicture(loader, null));
      break;
    case ImageFrameSource.importedImage:
      final artImage = await _decodeImageFile(asset.imageFilePath!);
      try {
        canvas.drawImageRect(
          artImage,
          Rect.fromLTWH(
            0,
            0,
            artImage.width.toDouble(),
            artImage.height.toDouble(),
          ),
          Offset.zero & size,
          Paint()..filterQuality = FilterQuality.high,
        );
      } finally {
        artImage.dispose();
      }
      break;
  }
}

/// Espera o `Picture` vetorial carregar e desenha escalado para preencher
/// [size] — mesma técnica de `rasterizeSvgAsset`/`rasterizeSvgFile`
/// (`frame_painter.dart`), mas desenhando direto no canvas em composição em
/// vez de rasterizar para um PNG à parte. Recebe o `Future<PictureInfo>` já
/// iniciado (em vez do `BytesLoader`) para não precisar nomear esse tipo,
/// que o `flutter_svg` não reexporta.
Future<void> _drawPicture(
  Canvas canvas,
  Size size,
  Future<PictureInfo> pictureInfoFuture,
) async {
  final pictureInfo = await pictureInfoFuture;
  try {
    canvas.save();
    canvas.scale(
      size.width / pictureInfo.size.width,
      size.height / pictureInfo.size.height,
    );
    canvas.drawPicture(pictureInfo.picture);
    canvas.restore();
  } finally {
    pictureInfo.picture.dispose();
  }
}

Future<ui.Image> _decodeImageFile(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

/// Retângulo de origem que, desenhado no destino `dstW`×`dstH`, cobre todo
/// o destino recortando o excedente do maior eixo — o "cover" do
/// `BoxFit.cover`, feito manualmente porque [Canvas.drawImageRect] não tem
/// um modo de ajuste embutido.
Rect _coverSrcRect(double srcW, double srcH, double dstW, double dstH) {
  final srcAspect = srcW / srcH;
  final dstAspect = dstW / dstH;
  if (srcAspect > dstAspect) {
    final cropWidth = srcH * dstAspect;
    return Rect.fromLTWH((srcW - cropWidth) / 2, 0, cropWidth, srcH);
  }
  final cropHeight = srcW / dstAspect;
  return Rect.fromLTWH(0, (srcH - cropHeight) / 2, srcW, cropHeight);
}

/// Desenha a região [src] de [image] ocupando [dst], girada e espelhada por
/// [transform] — [dst] já está na orientação de depois do giro. É o giro da
/// aba "Girar" com moldura de imagem ativa: só a foto gira, dentro da
/// janela.
void _drawTransformedPhoto(
  Canvas canvas,
  ui.Image image,
  Rect src,
  Rect dst,
  OutputTransform transform,
  Paint paint,
) {
  final srcSize = Size(src.width, src.height);
  final (turnedWidth, turnedHeight) = transform.swapsAxes
      ? (src.height, src.width)
      : (src.width, src.height);
  canvas.save();
  canvas.translate(dst.left, dst.top);
  canvas.scale(dst.width / turnedWidth, dst.height / turnedHeight);
  applyCanvasOutputTransform(canvas, transform, srcSize);
  canvas.drawImageRect(image, src, Offset.zero & srcSize, paint);
  canvas.restore();
}

/// Retângulo de destino, centralizado em [dst], que cobre [dst] inteiro sem
/// distorcer a imagem — o "cover" do `BoxFit.cover`, do lado do destino (o
/// excedente fica fora de [dst] e quem chama recorta).
Rect _coverDstRect(double srcW, double srcH, Rect dst) {
  final scale = math.max(dst.width / srcW, dst.height / srcH);
  final w = srcW * scale;
  final h = srcH * scale;
  return Rect.fromLTWH(
    dst.left + (dst.width - w) / 2,
    dst.top + (dst.height - h) / 2,
    w,
    h,
  );
}

/// Retângulo de destino, centralizado dentro de [dst], que mostra a imagem
/// inteira sem distorcer — o "contain" do `BoxFit.contain`.
Rect _containDstRect(double srcW, double srcH, Rect dst) {
  final srcAspect = srcW / srcH;
  final dstAspect = dst.width / dst.height;
  final double w, h;
  if (srcAspect > dstAspect) {
    w = dst.width;
    h = w / srcAspect;
  } else {
    h = dst.height;
    w = h * srcAspect;
  }
  return Rect.fromLTWH(
    dst.left + (dst.width - w) / 2,
    dst.top + (dst.height - h) / 2,
    w,
    h,
  );
}
