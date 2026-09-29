import '../../app/language_controller.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/sticker_catalog.dart';
import 'stickers_panel.dart';
import '../models/collage_sticker.dart';
import '../services/imported_asset_store.dart';
import '../services/sticker_folder_store.dart';
import 'app_message.dart';
import 'collage_overlay_view.dart';
import 'overlay_handles.dart';
import 'text_input_dialog.dart';
import 'dialog_title.dart';

/// Stickers arrastáveis sobre uma prévia — a mesma aba "Stickers" da
/// Montagem (mesmas pastas, mesma arte, mesmos gestos), generalizada para
/// "Editar imagem", "Editar vídeo" e "Editar SVG", do mesmo jeito que
/// `text_overlay_editor.dart` fez com o texto. [StickerOverlayStack] entra na
/// pilha da prévia; [StickerOverlayPanel] entra no painel de baixo; os dois
/// dividem o estado efêmero (seleção, pastas, importados) por um
/// [StickerOverlayController]. A lista de [CollageSticker] continua sendo de
/// quem chama (`FrameSettings.stickers`/`SvgEditSettings.stickers`).
class StickerOverlayController extends ChangeNotifier {
  String? selectedId;

  static const _stickerStore = ImportedAssetStore(ImportedAssetKind.sticker);
  static const _folderStore = StickerFolderStore();

  String folderId = BundledStickerFolder.reactions.id;
  List<StickerFolder> customFolders = [];
  List<ImportedAsset> importedStickers = [];
  String? pendingFolderScrollId;

  /// Gesto em andamento das alças (ver `TextOverlayController`).
  final handleDrag = OverlayHandleDrag();

  Future<void> load() async {
    try {
      importedStickers = await _stickerStore.loadAll();
      customFolders = await _folderStore.loadAll();
    } catch (_) {
      // Sem os importados, as pastas embutidas continuam funcionando.
    }
    _dropFolderIfGone();
    notifyListeners();
  }

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

  void openFolder(String id) {
    folderId = id;
    notifyListeners();
  }

  void _dropFolderIfGone() {
    final exists =
        BundledStickerFolder.values.any((f) => f.id == folderId) ||
        customFolders.any((f) => f.id == folderId);
    if (!exists) folderId = BundledStickerFolder.imported.id;
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

/// Painel da aba "Stickers" fora da Montagem: as mesmas pastas e a mesma
/// arte de `CollageStickersPanel`, com criar/renomear/apagar pasta,
/// importar e remover sticker. Tocar numa arte acrescenta o sticker no
/// centro, já selecionado.
class StickerOverlayPanel extends StatefulWidget {
  const StickerOverlayPanel({
    super.key,
    required this.controller,
    required this.stickers,
    required this.onChanged,
  });

  final StickerOverlayController controller;
  final List<CollageSticker> stickers;
  final ValueChanged<List<CollageSticker>> onChanged;

  @override
  State<StickerOverlayPanel> createState() => _StickerOverlayPanelState();
}

class _StickerOverlayPanelState extends State<StickerOverlayPanel> {
  StickerOverlayController get _c => widget.controller;

  static const _stickerStore = StickerOverlayController._stickerStore;
  static const _folderStore = StickerOverlayController._folderStore;

  void _message(String text) => showAppMessage(context, text);

  void _add(CollageSticker Function(String id, int z) build) {
    final item = build(
      's_${DateTime.now().microsecondsSinceEpoch}',
      widget.stickers.nextStickerZIndex,
    );
    widget.onChanged([...widget.stickers, item]);
    _c.select(item.id);
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

  Future<void> _import({String? folderId}) async {
    try {
      final asset = await _stickerStore.import(folderId: folderId);
      if (!mounted) return;
      _c.importedStickers = [..._c.importedStickers, asset];
      _addImported(asset);
    } on ImportedAssetException catch (e) {
      _message(e.message);
    }
  }

  Future<String?> _prompt(String initial, String title) => showDialog<String>(
    context: context,
    builder: (_) =>
        TextInputDialog(initial: initial, title: title, maxLines: 1),
  );

  Future<void> _createFolder() async {
    final name = await _prompt('', tr('Nova pasta', 'New folder'));
    if (name == null) return;
    if (name.trim().isEmpty) {
      _message(
        tr('Digite um nome para a pasta.', 'Type a name for the folder.'),
      );
      return;
    }
    try {
      final folder = await _folderStore.create(name);
      if (!mounted) return;
      _c
        ..customFolders = [..._c.customFolders, folder]
        ..pendingFolderScrollId = folder.id
        ..openFolder(folder.id);
    } catch (e) {
      if (mounted) {
        _message(
          tr(
            'Não deu para criar a pasta: $e',
            'Could not create the folder: $e',
          ),
        );
      }
    }
  }

  void _openFolderMenu(StickerFolder folder) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: Text(tr('Renomear', 'Rename')),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _renameFolder(folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(tr('Apagar', 'Delete')),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _removeFolder(folder);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameFolder(StickerFolder folder) async {
    final name = await _prompt(
      folder.name,
      tr('Renomear pasta', 'Rename folder'),
    );
    if (name == null || name.trim().isEmpty) return;
    await _folderStore.rename(folder.id, name);
    if (!mounted) return;
    _c.customFolders = [
      for (final f in _c.customFolders)
        f.id == folder.id ? StickerFolder(id: f.id, name: name.trim()) : f,
    ];
    _c.openFolder(_c.folderId);
  }

  Future<void> _removeFolder(StickerFolder folder) async {
    final inFolder = _c.importedStickers
        .where((a) => a.folderId == folder.id)
        .length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: DialogTitle(tr('Apagar pasta?', 'Delete folder?')),
        content: Text(
          inFolder == 0
              ? tr(
                  '"${folder.name}" vai ser apagada.',
                  '"${folder.name}" will be deleted.',
                )
              : tr(
                  '"${folder.name}" vai ser apagada. '
                      '${inFolder == 1 ? 'O sticker que está' : 'Os $inFolder stickers que estão'} '
                      'nela ${inFolder == 1 ? 'volta' : 'voltam'} para "Importados".',
                  '"${folder.name}" will be deleted. '
                      '${inFolder == 1 ? 'The sticker in it goes' : 'The $inFolder stickers in it go'} '
                      'back to "Imported".',
                ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('Apagar', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _stickerStore.moveFolderToRoot(folder.id);
    await _folderStore.remove(folder.id);
    if (!mounted) return;
    _c
      ..customFolders = _c.customFolders
          .where((f) => f.id != folder.id)
          .toList()
      ..importedStickers = [
        for (final asset in _c.importedStickers)
          asset.folderId == folder.id
              ? ImportedAsset(
                  id: asset.id,
                  label: asset.label,
                  filePath: asset.filePath,
                  isVector: asset.isVector,
                  nativeAspectRatio: asset.nativeAspectRatio,
                )
              : asset,
      ];
    _c._dropFolderIfGone();
    _c.openFolder(_c.folderId);
  }

  Future<void> _removeImported(ImportedAsset asset) async {
    final inUse = widget.stickers
        .where((s) => s.imageFilePath == asset.filePath)
        .toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: DialogTitle(tr('Remover sticker?', 'Remove sticker?')),
        content: Text(
          inUse.isEmpty
              ? tr(
                  '"${asset.label}" vai ser removido da lista.',
                  '"${asset.label}" will be removed from the list.',
                )
              : tr(
                  '"${asset.label}" vai ser removido da lista e também daqui, '
                      'onde está usado ${inUse.length} '
                      '${inUse.length == 1 ? 'vez' : 'vezes'}.',
                  '"${asset.label}" will be removed from the list and also '
                      'from here, where it is used ${inUse.length} '
                      '${inUse.length == 1 ? 'time' : 'times'}.',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('Remover', 'Remove')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _stickerStore.remove(asset.id);
    if (!mounted) return;
    _c.importedStickers = _c.importedStickers
        .where((a) => a.id != asset.id)
        .toList();
    _c.openFolder(_c.folderId);
    if (inUse.isEmpty) return;
    // O arquivo acabou de ser apagado: as cópias já colocadas sairiam
    // quebradas na prévia e na exportação.
    var updated = widget.stickers;
    for (final sticker in inUse) {
      updated = updated.removingSticker(sticker.id);
    }
    widget.onChanged(updated);
    _c.dropSelectionIfGone(updated);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => CollageStickersPanel(
        stickerFolderId: _c.folderId,
        customFolders: _c.customFolders,
        importedStickers: _c.importedStickers,
        pendingFolderScrollId: _c.pendingFolderScrollId,
        onPendingScrollConsumed: () => _c.pendingFolderScrollId = null,
        onFolderSelected: _c.openFolder,
        onOpenFolderMenu: _openFolderMenu,
        onCreateFolder: _createFolder,
        onAddBundledSticker: _addBundled,
        onAddImportedSticker: _addImported,
        onRemoveSticker: _removeImported,
        onImportSticker: _import,
      ),
    );
  }
}
