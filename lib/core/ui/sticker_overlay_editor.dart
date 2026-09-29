import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/collage_sticker.dart';
import '../services/imported_asset_store.dart';
import 'collage_overlay_view.dart';
import 'overlay_handles.dart';
import 'sticker_library.dart';

/// Stickers arrastáveis sobre uma prévia — a mesma aba "Stickers" da
/// Montagem (mesmas pastas, mesma arte, mesmos gestos), generalizada para
/// "Editar imagem", "Editar vídeo" e "Editar SVG", do mesmo jeito que
/// `text_overlay_editor.dart` fez com o texto. [StickerOverlayStack] entra na
/// pilha da prévia; [StickerOverlayPanel] entra no painel de baixo; os dois
/// dividem o estado efêmero (seleção, pastas, importados) por um
/// [StickerOverlayController]. A lista de [CollageSticker] continua sendo de
/// quem chama (`FrameSettings.stickers`/`SvgEditSettings.stickers`).
///
/// As pastas e os importados são a mesma [StickerLibrary] da Montagem.
class StickerOverlayController extends StickerLibrary {
  String? selectedId;

  /// Gesto em andamento das alças (ver `TextOverlayController`).
  final handleDrag = OverlayHandleDrag();

  void select(String? id) {
    if (selectedId == id) return;
    selectedId = id;
    notifyListeners();
  }

  void dropSelectionIfGone(List<CollageSticker> stickers) {
    final id = selectedId;
    if (id != null && stickers.findSticker(id) == null) {
      selectedId = null;
      notifyListeners();
    }
  }
}

/// Arte de um sticker no tamanho de referência do canvas — o mesmo desenho
/// da Montagem (`CollagePage._stickerArt`) e da exportação
/// (`paintCollageSticker`).
Widget stickerOverlayArt(CollageSticker sticker, Size canvasSize) {
  final refSize = canvasSize.shortestSide * CollageSticker.referenceSizeRatio;
  final content = switch (sticker.source) {
    CollageStickerSource.bundledSvg => SvgPicture.asset(
      sticker.assetPath!,
      fit: BoxFit.contain,
    ),
    CollageStickerSource.importedSvg => SvgPicture.file(
      File(sticker.imageFilePath!),
      fit: BoxFit.contain,
    ),
    CollageStickerSource.importedImage => Image.file(
      File(sticker.imageFilePath!),
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    ),
  };
  return SizedBox(width: refSize, height: refSize, child: content);
}

/// A pilha de stickers + as alças do selecionado, por cima da prévia já
/// composta (no tamanho exato do canvas final) — como `TextOverlayStack`.
class StickerOverlayStack extends StatelessWidget {
  const StickerOverlayStack({
    super.key,
    required this.controller,
    required this.stickers,
    required this.onChanged,
    required this.canvasSize,
    required this.interactive,
    this.onGestureStart,
  });

  final StickerOverlayController controller;
  final List<CollageSticker> stickers;
  final ValueChanged<List<CollageSticker>> onChanged;
  final Size canvasSize;

  /// Só responde a toque com a aba "Stickers" aberta.
  final bool interactive;
  final VoidCallback? onGestureStart;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final sorted = [...stickers]
          ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
        return Stack(
          children: [
            for (final item in sorted) _overlayWidget(item),
            if (interactive) ..._selectedHandles(),
          ],
        );
      },
    );
  }

  void _apply(CollageSticker item, double cx, double cy, double s, double r) =>
      onChanged(
        stickers.replacingSticker(
          item.id,
          item.copyWith(centerX: cx, centerY: cy, scale: s, rotation: r),
        ),
      );

  Widget _overlayWidget(CollageSticker item) {
    return CollageOverlayView(
      key: ValueKey(item.id),
      centerX: item.centerX,
      centerY: item.centerY,
      scale: item.scale,
      rotation: item.rotation,
      minScale: CollageSticker.minScale,
      maxScale: CollageSticker.maxScale,
      canvasSize: canvasSize,
      selected: interactive && controller.selectedId == item.id,
      interactive: interactive,
      onSelect: () => controller.select(item.id),
      onGestureStart: onGestureStart,
      onTransformChanged: (cx, cy, scale, rotation) =>
          _apply(item, cx, cy, scale, rotation),
      child: stickerOverlayArt(item, canvasSize),
    );
  }

  List<Widget> _selectedHandles() {
    final id = controller.selectedId;
    if (id == null) return const [];
    final item = stickers.findSticker(id);
    if (item == null) return const [];

    final ref = canvasSize.shortestSide * CollageSticker.referenceSizeRatio;
    final points = overlayHandlePoints(
      centerX: item.centerX,
      centerY: item.centerY,
      naturalSize: Size(ref, ref),
      scale: item.scale,
      rotation: item.rotation,
      canvasSize: canvasSize,
    );
    final drag = controller.handleDrag;

    return [
      OverlayHandle(
        key: const ValueKey('stickerResizeHandle'),
        center: points.bottomRight,
        icon: Icons.open_in_full_rounded,
        iconSize: 13,
        onPointerDown: (_) => drag.startResize(),
        onPointerMove: (event) {
          final scale = drag.resize(
            event,
            scale: item.scale,
            rotation: item.rotation,
            minScale: CollageSticker.minScale,
            maxScale: CollageSticker.maxScale,
            canvasSize: canvasSize,
            onFirstChange: onGestureStart,
          );
          if (scale != null) {
            _apply(item, item.centerX, item.centerY, scale, item.rotation);
          }
        },
      ),
      OverlayHandle(
        key: const ValueKey('stickerRotateHandle'),
        center: points.topRight,
        icon: Icons.rotate_right_rounded,
        iconSize: 13,
        onPointerDown: (_) => drag.startRotate(points.topRight),
        onPointerMove: (event) {
          final rotation = drag.rotate(
            event,
            center: points.center,
            rotation: item.rotation,
            onFirstChange: onGestureStart,
          );
          if (rotation != null) {
            _apply(item, item.centerX, item.centerY, item.scale, rotation);
          }
        },
      ),
      OverlayHandle(
        key: const ValueKey('stickerRemoveHandle'),
        center: points.topLeft,
        icon: Icons.close_rounded,
        iconSize: 13,
        destructive: true,
        onTap: () {
          onGestureStart?.call();
          onChanged(stickers.removingSticker(item.id));
          controller.select(null);
        },
      ),
    ];
  }
}

/// Painel da aba "Stickers" fora da Montagem: a [StickerLibraryPanel] com
/// os stickers desta tela. Tocar numa arte acrescenta o sticker no centro,
/// já selecionado.
class StickerOverlayPanel extends StatelessWidget {
  const StickerOverlayPanel({
    super.key,
    required this.controller,
    required this.stickers,
    required this.onChanged,
  });

  final StickerOverlayController controller;
  final List<CollageSticker> stickers;
  final ValueChanged<List<CollageSticker>> onChanged;

  void _add(CollageSticker Function(String id, int z) build) {
    final item = build(
      's_${DateTime.now().microsecondsSinceEpoch}',
      stickers.nextStickerZIndex,
    );
    onChanged([...stickers, item]);
    controller.select(item.id);
  }

  void _addBundled((String path, String label) sticker) => _add(
    (id, z) => CollageSticker(
      id: id,
      source: CollageStickerSource.bundledSvg,
      assetPath: sticker.$1,
      label: sticker.$2,
      centerX: 0.5,
      centerY: 0.5,
      zIndex: z,
    ),
  );

  void _addImported(ImportedAsset asset) => _add(
    (id, z) => CollageSticker(
      id: id,
      source: asset.isVector
          ? CollageStickerSource.importedSvg
          : CollageStickerSource.importedImage,
      imageFilePath: asset.filePath,
      label: asset.label,
      centerX: 0.5,
      centerY: 0.5,
      zIndex: z,
    ),
  );

  /// O arquivo acabou de ser apagado: as cópias já colocadas sairiam
  /// quebradas na prévia e na exportação.
  void _removePlaced(List<CollageSticker> inUse) {
    var updated = stickers;
    for (final sticker in inUse) {
      updated = updated.removingSticker(sticker.id);
    }
    onChanged(updated);
    controller.dropSelectionIfGone(updated);
  }

  @override
  Widget build(BuildContext context) {
    return StickerLibraryPanel(
      library: controller,
      placed: stickers,
      usedIn: (pt: 'daqui', en: 'from here'),
      onAddBundled: _addBundled,
      onAddImported: _addImported,
      onRemovePlaced: _removePlaced,
    );
  }
}
