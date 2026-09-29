import '../../app/language_controller.dart';
import 'package:flutter/material.dart';

import '../models/collage_sticker.dart';
import '../models/sticker_catalog.dart';
import '../services/imported_asset_store.dart';
import '../services/sticker_folder_store.dart';
import 'app_message.dart';
import 'dialog_title.dart';
import 'stickers_panel.dart';
import 'text_input_dialog.dart';

/// Pastas e stickers importados da aba "Stickers": a pasta aberta, as pastas
/// criadas pela pessoa e os stickers que ela importou. O mesmo estado na
/// Montagem e nos outros editores (onde `StickerOverlayController` estende
/// esta classe).
class StickerLibrary extends ChangeNotifier {
  static const _stickerStore = ImportedAssetStore(ImportedAssetKind.sticker);
  static const _folderStore = StickerFolderStore();

  /// Pasta aberta: id de uma embutida ([BundledStickerFolder.id]) ou de uma
  /// criada pela pessoa ([StickerFolder.id]).
  String folderId = BundledStickerFolder.reactions.id;

  /// Pastas criadas pela pessoa — ver [StickerFolderStore].
  List<StickerFolder> customFolders = [];
  List<ImportedAsset> importedStickers = [];

  /// Id da pasta recém-criada que ainda precisa ficar visível na fileira
  /// (ver o `Builder` em [CollageStickersPanel]); `null` sem rolagem
  /// pendente.
  String? pendingFolderScrollId;

  Future<void> load() async {
    try {
      importedStickers = await _stickerStore.loadAll();
      customFolders = await _folderStore.loadAll();
    } catch (_) {
      // Sem os importados, as pastas embutidas continuam funcionando.
    }
    dropFolderIfGone();
    notifyListeners();
  }

  void openFolder(String id) {
    folderId = id;
    notifyListeners();
  }

  /// Volta para "Importados" quando a pasta aberta não existe mais — só
  /// acontece se ela for apagada, mas deixa a barra sempre com alguma pasta
  /// marcada em vez de nenhuma.
  void dropFolderIfGone() {
    final exists =
        BundledStickerFolder.values.any((f) => f.id == folderId) ||
        customFolders.any((f) => f.id == folderId);
    if (!exists) folderId = BundledStickerFolder.imported.id;
  }
}

/// A aba "Stickers" ligada a uma [StickerLibrary]: as pastas e a arte de
/// cada uma ([CollageStickersPanel]), com criar/renomear/apagar pasta,
/// importar e remover sticker. Tocar numa arte acrescenta o sticker — onde
/// e com que `zIndex` é a tela que decide.
class StickerLibraryPanel extends StatefulWidget {
  const StickerLibraryPanel({
    super.key,
    required this.library,
    required this.placed,
    required this.usedIn,
    required this.onAddBundled,
    required this.onAddImported,
    required this.onRemovePlaced,
  });

  final StickerLibrary library;

  /// Os stickers já colocados, para o aviso de remover um importado dizer
  /// quantas vezes ele está em uso.
  final List<CollageSticker> placed;

  /// Onde os stickers estão colocados, no mesmo aviso: "da montagem"/"from
  /// the collage" ou "daqui"/"from here".
  final ({String pt, String en}) usedIn;

  final ValueChanged<(String path, String label)> onAddBundled;
  final ValueChanged<ImportedAsset> onAddImported;

  /// Tira da tela as cópias de um importado que acabou de ser apagado do
  /// aparelho: apontando para o arquivo que sumiu, elas quebrariam a prévia
  /// e a exportação.
  final ValueChanged<List<CollageSticker>> onRemovePlaced;

  @override
  State<StickerLibraryPanel> createState() => _StickerLibraryPanelState();
}

class _StickerLibraryPanelState extends State<StickerLibraryPanel> {
  StickerLibrary get _library => widget.library;

  static const _stickerStore = StickerLibrary._stickerStore;
  static const _folderStore = StickerLibrary._folderStore;

  void _message(String text) => showAppMessage(context, text);

  Future<void> _import({String? folderId}) async {
    try {
      final asset = await _stickerStore.import(folderId: folderId);
      if (!mounted) return;
      _library.importedStickers = [..._library.importedStickers, asset];
      widget.onAddImported(asset);
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
    if (name == null) return; // Cancelado — nada a avisar.
    if (name.trim().isEmpty) {
      // Sem isto, um nome que não chegou a registrar (ex.: o teclado ainda
      // compondo o texto no instante do toque) fazia "Nova pasta" parecer
      // não fazer nada.
      _message(
        tr('Digite um nome para a pasta.', 'Type a name for the folder.'),
      );
      return;
    }
    try {
      final folder = await _folderStore.create(name);
      if (!mounted) return;
      // A pasta nova nasce perto do fim da fileira (antes só de "Nova
      // pasta"), fora da parte já visível se houver muitas pastas — o item
      // dela mesma, ao entrar na árvore, pede pra rolar até si.
      _library
        ..customFolders = [..._library.customFolders, folder]
        ..pendingFolderScrollId = folder.id
        ..openFolder(folder.id);
    } catch (e) {
      // Uma pasta que falha ao salvar não pode desaparecer em silêncio —
      // sem isto, tocar "Nova pasta" simplesmente não fazia nada visível.
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

  /// Menu de segurar uma pasta criada — as embutidas não passam
  /// `onLongPress`, então não chegam aqui.
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
    _library.customFolders = [
      for (final f in _library.customFolders)
        f.id == folder.id ? StickerFolder(id: f.id, name: name.trim()) : f,
    ];
    _library.openFolder(_library.folderId);
  }

  /// Apagar a pasta não apaga o que a pessoa importou para ela: os stickers
  /// voltam para "Importados" (`moveFolderToRoot`), e o diálogo diz isso
  /// antes de confirmar.
  Future<void> _removeFolder(StickerFolder folder) async {
    final inFolder = _library.importedStickers
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
    _library
      ..customFolders = _library.customFolders
          .where((f) => f.id != folder.id)
          .toList()
      ..importedStickers = [
        for (final asset in _library.importedStickers)
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
    _library.dropFolderIfGone();
    _library.openFolder(_library.folderId);
  }

  Future<void> _removeImported(ImportedAsset asset) async {
    final inUse = widget.placed
        .where((s) => s.imageFilePath == asset.filePath)
        .toList();
    final usedIn = widget.usedIn;
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
                  '"${asset.label}" vai ser removido da lista e também '
                      '${usedIn.pt}, onde está usado ${inUse.length} '
                      '${inUse.length == 1 ? 'vez' : 'vezes'}.',
                  '"${asset.label}" will be removed from the list and also '
                      '${usedIn.en}, where it is used ${inUse.length} '
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
    _library.importedStickers = _library.importedStickers
        .where((a) => a.id != asset.id)
        .toList();
    _library.openFolder(_library.folderId);
    if (inUse.isEmpty) return;
    widget.onRemovePlaced(inUse);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _library,
      builder: (context, _) => CollageStickersPanel(
        stickerFolderId: _library.folderId,
        customFolders: _library.customFolders,
        importedStickers: _library.importedStickers,
        pendingFolderScrollId: _library.pendingFolderScrollId,
        // Atribuição simples de propósito: quem consome é o `Builder` da
        // fileira, durante o build, e notificar ali lançaria exceção.
        onPendingScrollConsumed: () => _library.pendingFolderScrollId = null,
        onFolderSelected: _library.openFolder,
        onOpenFolderMenu: _openFolderMenu,
        onCreateFolder: _createFolder,
        onAddBundledSticker: widget.onAddBundled,
        onAddImportedSticker: widget.onAddImported,
        onRemoveSticker: _removeImported,
        onImportSticker: _import,
      ),
    );
  }
}
