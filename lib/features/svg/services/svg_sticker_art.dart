import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

import '../../../core/models/collage_sticker.dart';
import 'svg_xml_editor.dart';

/// Lê a arte de cada sticker para [renderEditedSvg] (que é síncrono):
/// vetoriais como texto SVG, importados em imagem como bytes. Um sticker
/// cujo arquivo sumiu fica de fora do mapa — e do SVG exportado — em vez de
/// derrubar o salvamento inteiro.
Future<Map<String, StickerSvgArt>> loadStickerSvgArt(
  List<CollageSticker> stickers,
) async {
  final result = <String, StickerSvgArt>{};
  for (final sticker in stickers) {
    try {
      switch (sticker.source) {
        case CollageStickerSource.bundledSvg:
          result[sticker.id] = StickerSvgArt.vector(
            await rootBundle.loadString(sticker.assetPath!),
          );
        case CollageStickerSource.importedSvg:
          result[sticker.id] = StickerSvgArt.vector(
            await File(sticker.imageFilePath!).readAsString(),
          );
        case CollageStickerSource.importedImage:
          final path = sticker.imageFilePath!;
          result[sticker.id] = StickerSvgArt.raster(
            await File(path).readAsBytes(),
            _mimeFor(path),
          );
      }
    } catch (_) {
      // Arte ilegível: esse sticker não entra.
    }
  }
  return result;
}

String _mimeFor(String path) {
  final ext = path.split('.').last.toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    _ => 'image/png',
  };
}
