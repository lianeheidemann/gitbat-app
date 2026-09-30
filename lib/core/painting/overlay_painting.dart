import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/collage_sticker.dart';
import '../models/collage_text.dart';

/// Caixa colorida atrás de um texto da montagem. O raio sai do menor lado da
/// própria caixa (mesma unidade proporcional das outras razões de canto do
/// app), então o arredondamento parece o mesmo em qualquer tamanho de fonte
/// e em qualquer resolução de saída. Compartilhado entre a prévia
/// (`TextOverlayBackgroundBox`) e a exportação (`_TextOverlay.paint` da
/// montagem, `paintCollageTextItem`), para as duas nunca divergirem.
void paintCollageTextBackground(
  Canvas canvas,
  Rect rect,
  Color color,
  double cornerRatio,
) {
  if (rect.isEmpty) return;
  final radius =
      rect.shortestSide *
      cornerRatio.clamp(0.0, CollageTextItem.maxBackgroundCornerRatio);
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(radius)),
    Paint()..color = color,
  );
}

/// Desenha um [CollageTextItem] completo (fundo, se houver, e o texto por
/// cima) centrado e rotacionado em [canvasSize] — o mesmo desenho que
/// `_TextOverlay.paint` (`collage_compositor.dart`) usa na exportação da
/// montagem, reexposto aqui para a moldura de foto e o editor de vídeo/GIF
/// reaproveitarem sem duplicar a conta de tamanho de fonte/respiro/rotação.
void paintCollageTextItem(
  Canvas canvas,
  Size canvasSize,
  CollageTextItem item,
) {
  final fontSize = canvasSize.shortestSide * item.fontSizeRatio * item.scale;
  final center = Offset(
    item.centerX * canvasSize.width,
    item.centerY * canvasSize.height,
  );

  final painter = TextPainter(
    text: TextSpan(
      text: item.text,
      style: TextStyle(
        color: item.color,
        fontSize: fontSize,
        fontFamily: item.fontFamily,
        fontWeight: item.bold ? FontWeight.w700 : FontWeight.w400,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();

  try {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(item.rotation);

    final background = item.backgroundColor;
    if (background != null) {
      final (padH, padV) = CollageTextItem.backgroundPaddingFor(fontSize);
      paintCollageTextBackground(
        canvas,
        Rect.fromCenter(
          center: Offset.zero,
          width: painter.width + padH * 2,
          height: painter.height + padV * 2,
        ),
        background,
        item.backgroundCornerRatio,
      );
    }

    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  } finally {
    painter.dispose();
  }
}

/// Desenha um sticker no [canvas] de [canvasSize] — o mesmo desenho da
/// prévia (`CollageOverlayView` com a arte em `refSize`). Compartilhado com
/// as outras telas que têm a aba "Stickers" (foto, vídeo e SVG).
Future<void> paintCollageSticker(
  Canvas canvas,
  Size canvasSize,
  CollageSticker sticker,
) => _StickerPainter(sticker).paint(canvas, canvasSize);

class _StickerPainter {
  _StickerPainter(this.sticker);

  final CollageSticker sticker;

  Future<void> paint(Canvas canvas, Size canvasSize) async {
    final refSize =
        canvasSize.shortestSide *
        CollageSticker.referenceSizeRatio *
        sticker.scale;
    final center = Offset(
      sticker.centerX * canvasSize.width,
      sticker.centerY * canvasSize.height,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(sticker.rotation);

    switch (sticker.source) {
      case CollageStickerSource.bundledSvg:
        await _paintVector(canvas, refSize, SvgAssetLoader(sticker.assetPath!));
      case CollageStickerSource.importedSvg:
        await _paintVector(
          canvas,
          refSize,
          SvgFileLoader(File(sticker.imageFilePath!)),
        );
      case CollageStickerSource.importedImage:
        await _paintRasterSticker(canvas, refSize, sticker.imageFilePath!);
    }
    canvas.restore();
  }

  Future<void> _paintVector(
    Canvas canvas,
    double refSize,
    BytesLoader loader,
  ) async {
    final PictureInfo pictureInfo;
    try {
      pictureInfo = await vg.loadPicture(loader, null);
    } catch (_) {
      // Arte apagada/ilegível: deixa esse sticker de fora em vez de derrubar a
      // exportação inteira (ver `_tryDecodeImageFile`).
      return;
    }
    try {
      final nativeSize = pictureInfo.size;
      if (nativeSize.width <= 0 || nativeSize.height <= 0) return;
      final aspect = nativeSize.width / nativeSize.height;
      final w = aspect >= 1 ? refSize : refSize * aspect;
      final h = aspect >= 1 ? refSize / aspect : refSize;
      canvas.save();
      canvas.translate(-w / 2, -h / 2);
      canvas.scale(w / nativeSize.width, h / nativeSize.height);
      canvas.drawPicture(pictureInfo.picture);
      canvas.restore();
    } finally {
      pictureInfo.picture.dispose();
    }
  }

  Future<void> _paintRasterSticker(
    Canvas canvas,
    double refSize,
    String path,
  ) async {
    final image = await _tryDecodeImageFile(path);
    if (image == null) return;
    try {
      final aspect = image.width / image.height;
      final w = aspect >= 1 ? refSize : refSize * aspect;
      final h = aspect >= 1 ? refSize / aspect : refSize;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        Paint()..filterQuality = FilterQuality.high,
      );
    } finally {
      image.dispose();
    }
  }
}

/// Decodifica a arte de um sticker importado, devolvendo `null` (em vez de
/// propagar) quando o arquivo sumiu ou não é uma imagem legível: um sticker
/// apagado do aparelho depois de colocado não pode derrubar a exportação
/// inteira. O caminho é sempre um arquivo do aparelho — os stickers que vêm
/// com o app são SVG e passam por `_paintVector`.
Future<ui.Image?> _tryDecodeImageFile(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  } catch (_) {
    return null;
  }
}
