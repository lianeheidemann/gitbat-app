import '../../app/language_controller.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_svg/flutter_svg.dart';

import 'models/collage_background.dart';
import 'models/collage_cell.dart';
import 'models/collage_defaults.dart';
import 'models/collage_export.dart';
import 'models/collage_layout.dart';
import 'models/collage_settings.dart';
import '../../core/models/collage_sticker.dart';
import '../../core/models/collage_text.dart';
import '../../core/models/photo_info.dart';
import 'services/collage_animation.dart';
import 'services/collage_export_runner.dart';
import 'services/collage_compositor.dart';
import '../../core/ffmpeg/ffmpeg_service.dart';
import '../../core/services/export_diagnostics.dart';
import '../../core/services/imported_asset_store.dart';
import '../../core/services/imported_font_store.dart';
import '../../core/services/output_service.dart';
import '../../core/services/sticker_folder_store.dart';
import '../../core/ui/app_bar_title.dart';
import '../../core/ui/app_message.dart';
import 'widgets/background_image_view.dart';
import '../../core/ui/checkerboard_background.dart';
import 'widgets/collage_cell_view.dart';
import '../../core/ui/collage_overlay_view.dart';
import '../../core/ui/editor_app_bar_actions.dart';
import '../../core/ui/editor_tabs_footer.dart';
import '../../core/ui/overlay_handles.dart';
import '../../core/ui/sticker_library.dart';
import '../../core/ui/text_overlay_editor.dart';
import 'painting/collage_painter.dart';
import '../../core/ui/export_progress_dialog.dart';
import 'widgets/cell_actions.dart';
import '../../core/ui/font_picker_sheet.dart';
import 'widgets/panels/collage_panel_actions.dart';
import 'widgets/panels/aspect_panel.dart';
import 'widgets/panels/background_panel.dart';
import 'widgets/panels/border_panel.dart';
import 'widgets/panels/color_panel.dart';
import 'widgets/panels/margin_panel.dart';
import 'widgets/panels/text_panel.dart';
import 'widgets/panels/layout_panel.dart';
import 'widgets/panels/areas_panel.dart';
import '../../core/ui/preview_settings_panel.dart';
import '../../core/ui/saved_dialog.dart';
import '../../core/ui/dialog_title.dart';
import '../../core/ui/edit_history.dart';
import '../../app/editor_defaults.dart';

/// Geometria do sticker/texto selecionado, na medida necessária para
/// posicionar as alças de redimensionar/girar por fora dele (ver
/// `_CollagePageState._selectedHandlesLayer`) — junto de como escrever a
/// transformação de volta no item certo, já que sticker e texto usam
/// `copyWith`/`replacingSticker`/`replacingText` diferentes.
class _SelectedOverlayGeometry {
  const _SelectedOverlayGeometry({
    required this.centerX,
    required this.centerY,
    required this.scale,
    required this.rotation,
    required this.minScale,
    required this.maxScale,
    required this.naturalSize,
    required this.apply,
  });

  final double centerX;
  final double centerY;
  final double scale;
  final double rotation;
  final double minScale;
  final double maxScale;

  /// Tamanho do conteúdo em escala 1 — o efetivo na tela é
  /// `naturalSize * scale`.
  final Size naturalSize;

  final void Function(
    double centerX,
    double centerY,
    double scale,
    double rotation,
  )
  apply;
}

/// Abas fixas no rodapé da tela de montagem — cada uma abre um painel com o
/// conteúdo daquela seção logo acima da barra de abas, substituindo a antiga
/// lista rolável de cards expansíveis.
enum _CollageTab {
  layout,
  areas,
  aspect,
  margin,
  border,
  background,
  color,
  stickers,
  text,
  // Última aba da barra nas três telas de edição (vídeo, foto e montagem) —
  // configurações gerais, não desta montagem em si. Como a barra itera
  // `_CollageTab.values` direto, ser o último valor do enum já garante que
  // fica por último na barra.
  settings,
}

class CollagePage extends StatefulWidget {
  const CollagePage({super.key, required this.photos});

  final List<PhotoInfo> photos;

  @override
  State<CollagePage> createState() => _CollagePageState();
}

class _CollagePageState extends State<CollagePage> {
  static const _output = OutputService();

  /// Exportação da montagem: tamanhos, progresso, cancelamento e a geração
  /// do arquivo final. A tela fica só com as folhas de escolha e o pop-up.
  final _export = CollageExportRunner();
  static const _stickerStore = ImportedAssetStore(ImportedAssetKind.sticker);
  static const _backgroundStore = ImportedAssetStore(
    ImportedAssetKind.backgroundImage,
  );
  static const _folderStore = StickerFolderStore();
  static const _fontStore = ImportedFontStore();

  /// Pastas e stickers importados da aba "Stickers" — a mesma biblioteca dos
  /// outros editores, carregada aqui junto com os fundos e as fontes (ver
  /// [_loadImportedAssets]).
  final _stickerLibrary = StickerLibrary();

  late CollageSettings _settings =
      CollageSettings.forLayout(
        _defaultLayoutFor(widget.photos.length),
        widget.photos,
        cellStyle: CollageDefaults.cell(),
      ).copyWith(
        borderColor: EditorDefaults.frame,
        background: CollageDefaults.background(),
      );

  /// Valor próprio da linha "Tudo" da aba "Margem" — só muda quando ELA é
  /// arrastada (que também iguala `outerMarginRatio`/`innerMarginRatio` a
  /// esse valor). Sem isto, "Tudo" mostrava a média das outras duas a cada
  /// rebuild, então o próprio slider se movia sozinho ao arrastar "Externa"
  /// ou "Entre fotos" — o oposto do que uma pessoa espera de um slider que
  /// não tocou.
  late double _marginAllValue =
      (_settings.outerMarginRatio + _settings.innerMarginRatio) / 2;

  List<ImportedAsset> _importedBackgrounds = [];

  /// Fontes próprias do usuário, já registradas no engine por
  /// [ImportedFontStore.loadAll] — entram na folha de fontes ao lado das
  /// embutidas.
  List<ImportedFont> _importedFonts = [];

  final _history = EditHistory<CollageSettings>();

  String? _selectedOverlayId;

  /// Aba aberta no rodapé — `null` fecha o painel e deixa a prévia com o
  /// máximo de espaço. Começa em `layout`, equivalente ao
  /// `initiallyExpanded: true` que a seção de layout já tinha antes.
  _CollageTab? _activeTab = _CollageTab.layout;

  /// Foto tocada na aba "Áreas" — só ela mostra as alças de redimensionar.
  /// `null` = a primeira foto (a aba já abre com ela selecionada).
  int? _selectedAreaCell;

  /// Foto tocada na prévia (alças de girar/redimensionar e o "..."). Só uma
  /// por vez; tocar em outra troca, tocar fora das fotos solta.
  int? _selectedPhotoCell;

  /// Divisor sendo arrastado agora na aba "Áreas", para destacar as fotos
  /// que ele está redimensionando.
  CollageDivider? _draggingDivider;

  /// Layout de quando o arrasto da alça começou e o quanto o dedo já andou
  /// desde então: cada evento recalcula a partir do começo, em vez de somar
  /// passinhos — senão os passos menores que a tolerância escapavam da
  /// compensação e uma área travada ia encolhendo aos poucos.
  CollageLayout? _dragStartLayout;
  double _dragTotal = 0;

  /// Fotos com "Travar área" ligado no cartão "Área selecionada": o tamanho
  /// delas não muda mais — sem alças, sliders apagados, e nenhuma vizinha
  /// consegue empurrá-las. Cada foto tem o seu.
  final Set<int> _lockedAreaCells = {};

  /// Se a foto selecionada agora está com a proporção bloqueada.
  bool get _lockAreaAspect {
    final cell = _validSelectedAreaCell;
    return cell != null && _lockedAreaCells.contains(cell);
  }

  /// Alvo dos controles da aba "Borda e cantos": `false` = a montagem
  /// inteira, `true` = todas as fotos de uma vez. Só estado de UI (qual
  /// seletor está tocado agora) — não faz parte de [CollageSettings].
  bool _borderTargetsPhotos = false;

  /// Mesmo papel de [_borderTargetsPhotos], para a aba "Fundo": `false` = o
  /// fundo da montagem inteira, `true` = o fundo de dentro de cada foto.
  bool _backgroundTargetsPhotos = false;

  /// `true` quando o chip "x:y" da aba "Proporção" está escolhido — é ele que
  /// mostra os campos de largura e altura. Fica ligado sozinho quando a
  /// proporção atual não bate com nenhum chip pronto (arrastar o slider, por
  /// exemplo): nesse caso a proporção é customizada de fato.
  bool _customAspectSelected = false;

  bool _saving = false;
  bool _sharing = false;

  /// Durante a exportação animada a prévia sai de cena: as fotos animadas
  /// dela (GIF/WebP em tamanho cheio, decodificando ~24 quadros por
  /// segundo cada) competiam pela memória com a própria exportação.
  bool _exportingAnimated = false;

  /// Campo de escrever texto que fica no próprio painel da aba "Texto" — o
  /// mesmo campo cria uma caixa nova e edita a selecionada, sem abrir
  /// diálogo nenhum.
  final _textController = TextEditingController();
  final _textFocus = FocusNode();

  /// Progresso da exportação animada, ouvido pelo pop-up
  /// [ExportProgressDialog] — que vive numa rota própria e por isso não é
  /// reconstruído pelo `setState` desta tela.

  /// `true` entre pedir o cancelamento e a exportação de fato parar.

  /// Id da caixa sendo editada pelo campo; `null` = o campo está criando uma
  /// caixa nova.
  String? _editingTextId;

  @override
  void dispose() {
    _textController.dispose();
    _textFocus.dispose();
    _export.dispose();
    _stickerLibrary.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadImportedAssets();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showInterruptedExportReport(),
    );
    final ignored = widget.photos.length - _settings.cells.length;
    if (ignored > 0) {
      // Mais fotos do que cabe até no maior layout: avisa em vez de deixar o
      // usuário achar que elas entraram na montagem.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _message(
          ignored == 1
              ? tr(
                  'A última foto escolhida não coube na montagem.',
                  'The last chosen photo did not fit in the collage.',
                )
              : tr(
                  'As últimas $ignored fotos escolhidas não couberam na montagem.',
                  'The last $ignored chosen photos did not fit in the collage.',
                ),
        );
      });
    }
  }

  /// Layout inicial com células suficientes para todas as [count] fotos
  /// escolhidas. Acima de 9 fotos cai na grade livre (até 4x4 = 16 células, o
  /// máximo dela) em vez de sempre na grade 3x3 — que descartava em silêncio
  /// tudo o que passasse da nona foto.
  static CollageLayout _defaultLayoutFor(int count) {
    if (count <= 2) return CollageLayout.row(count < 2 ? 2 : count);
    if (count == 3) return CollageLayout.row(3);
    if (count == 4) return const CollageLayout(kind: CollageLayoutKind.grid2x2);
    if (count <= 6) return const CollageLayout(kind: CollageLayoutKind.grid2x3);
    if (count <= 9) return const CollageLayout(kind: CollageLayoutKind.grid3x3);
    const maxSpan = CollageLayout.maxFreeGridSpan;
    final rows = ((count + maxSpan - 1) ~/ maxSpan).clamp(1, maxSpan);
    return CollageLayout.grid(maxSpan, rows);
  }

  Future<void> _loadImportedAssets() async {
    final stickers = await _stickerStore.loadAll();
    final backgrounds = await _backgroundStore.loadAll();
    final folders = await _folderStore.loadAll();
    final fonts = await _fontStore.loadAll();
    if (!mounted) return;
    setState(() {
      _stickerLibrary
        ..importedStickers = stickers
        ..customFolders = folders
        ..dropFolderIfGone();
      _importedBackgrounds = backgrounds;
      _importedFonts = fonts;
    });
  }

  // ---------------------------------------------------------------------
  // Estado / desfazer-refazer
  // ---------------------------------------------------------------------

  /// Aplica uma nova [CollageSettings]. Por padrão empilha o estado anterior
  /// no histórico de desfazer — passe `pushUndo: false` para mudanças
  /// contínuas (arrastar, sliders) já precedidas por [_pushUndoCheckpoint]
  /// no início do gesto, para não empilhar um estado por quadro.
  void _update(CollageSettings settings, {bool pushUndo = true}) {
    if (pushUndo) _history.push(_settings);
    setState(() {
      // Espaço tirado ou layout trocado: os índices mudam de foto.
      if (settings.cells.length != _settings.cells.length) {
        _selectedPhotoCell = null;
      }
      if (settings.cells.length == _settings.cells.length - 1) {
        _shiftAreaIndicesAfterRemoval(_settings.cells, settings.cells);
      }
      _settings = settings;
    });
  }

  /// "Remover espaço" tira uma célula da lista: os cadeados e a seleção da
  /// aba "Áreas" acompanham (o removido sai, os de índice maior descem 1),
  /// senão o cadeado passava para a área vizinha.
  void _shiftAreaIndicesAfterRemoval(
    List<CollageCellSettings> before,
    List<CollageCellSettings> after,
  ) {
    var removed = after.length;
    for (var i = 0; i < after.length; i++) {
      if (!identical(before[i], after[i])) {
        removed = i;
        break;
      }
    }
    int? shift(int i) => i == removed ? null : (i > removed ? i - 1 : i);
    final locks = {for (final i in _lockedAreaCells) ?shift(i)};
    _lockedAreaCells
      ..clear()
      ..addAll(locks);
    final area = _selectedAreaCell;
    if (area != null) _selectedAreaCell = shift(area);
  }

  /// As três ações que as abas e as ações de célula devolvem para a tela.
  late final _panelActions = CollagePanelActions(
    update: _update,
    pushUndoCheckpoint: _pushUndoCheckpoint,
    message: _message,
  );

  void _pushUndoCheckpoint() => _history.push(_settings);

  void _undo() {
    final previous = _history.undo(_settings);
    if (previous == null) return;
    setState(() {
      _settings = previous;
      _dropSelectionIfGone();
    });
  }

  void _redo() {
    final next = _history.redo(_settings);
    if (next == null) return;
    setState(() {
      _settings = next;
      _dropSelectionIfGone();
    });
  }

  /// Solta a seleção quando a sobreposição selecionada não existe mais no
  /// estado atual — desfazer a criação de um sticker/texto deixava a barra de
  /// ações na tela apontando para algo que já tinha sumido, com todos os
  /// botões sem efeito nenhum.
  void _dropSelectionIfGone() {
    final id = _selectedOverlayId;
    if (id == null) return;
    if (_findSticker(id) == null && _findText(id) == null) {
      _selectedOverlayId = null;
    }
    // Desfazer/remover a caixa que estava sendo editada deixava o campo do
    // painel apontando para algo que não existe mais.
    final editingId = _editingTextId;
    if (editingId != null && _findText(editingId) == null) {
      _editingTextId = null;
      _textController.clear();
    }
  }

  /// Id da sobreposição cuja seleção está *visível* agora: a moldura, a alça
  /// de redimensionar e a barra de ações só aparecem enquanto a aba dona do
  /// item estiver aberta ("Stickers" para sticker, "Texto" para texto) — as
  /// mesmas abas em que `CollageOverlayView.interactive` já deixa mexer nele.
  /// Fora delas os controles não fazem nada, e a moldura em volta de um texto
  /// enquanto se ajusta o fundo da montagem só polui a prévia.
  /// [_selectedOverlayId] continua guardado ao trocar de aba, então voltando
  /// para ela a moldura reaparece no mesmo item.
  String? get _activeSelectionId {
    final id = _selectedOverlayId;
    if (id == null) return null;
    return switch (_activeTab) {
      _CollageTab.stickers => _findSticker(id) == null ? null : id,
      _CollageTab.text => _findText(id) == null ? null : id,
      _ => null,
    };
  }

  void _message(String text) => showAppMessage(context, text);

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final toolbar = _selectionToolbar();
    final busy = _saving || _sharing;
    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(tr('Montagem', 'Collage')),
        actions: [
          ...undoRedoActions(
            canUndo: _history.canUndo,
            canRedo: _history.canRedo,
            onUndo: _undo,
            onRedo: _redo,
          ),
          BusyIconButton(
            busy: _saving,
            tooltip: tr('Salvar na galeria', 'Save to gallery'),
            busyTooltip: tr('Salvando…', 'Saving…'),
            onPressed: busy ? null : _save,
            icon: const Icon(Icons.download_rounded),
          ),
          BusyIconButton(
            busy: _sharing,
            tooltip: tr('Compartilhar', 'Share'),
            busyTooltip: tr('Preparando…', 'Preparing…'),
            onPressed: busy ? null : _share,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                // Toque fora das fotos solta a selecionada — as fotos têm
                // o próprio toque e ganham a disputa quando o dedo cai nelas.
                behavior: HitTestBehavior.opaque,
                onTap: _selectedPhotoCell == null
                    ? null
                    : () => setState(() => _selectedPhotoCell = null),
                child: PreviewAreaBackground(
                  child: Center(
                    child: _exportingAnimated
                        ? _exportPlaceholder()
                        : MediaCheckerboard(child: _preview()),
                  ),
                ),
              ),
            ),
            ?toolbar,
            // Recolher o painel pela alça não é fechar: a aba continua
            // aberta, então sticker e texto seguem selecionáveis e móveis na
            // prévia enquanto os controles deles estão fora da tela.
            EditorTabsFooter(
              sections: _sections,
              activeIndex: _activeTab?.index,
              onSelected: (index) => setState(
                () => _activeTab = index == null
                    ? null
                    : _CollageTab.values[index],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Rodapé de abas
  // ---------------------------------------------------------------------

  /// As abas na ordem de [_CollageTab], sem valor de resumo no painel.
  List<EditorSection> get _sections => [
    for (final tab in _CollageTab.values)
      EditorSection(
        icon: _tabIcon(tab),
        title: _tabLabel(tab),
        builder: (_) => _panelContentFor(tab),
      ),
  ];

  Widget _panelContentFor(_CollageTab tab) => switch (tab) {
    _CollageTab.layout => CollageLayoutPanel(
      layout: _settings.layout,
      onSelectKind: _selectLayoutKind,
      onApplyLayout: _applyLayout,
    ),
    _CollageTab.areas => CollageAreasPanel(
      layout: _settings.layout,
      selectedCell: _validSelectedAreaCell,
      lockAspect: _lockAreaAspect,
      onLockAspectChanged: (v) => setState(() {
        final cell = _validSelectedAreaCell;
        if (cell == null) return;
        v ? _lockedAreaCells.add(cell) : _lockedAreaCells.remove(cell);
      }),
      onChangeStart: _pushUndoCheckpoint,
      onWidthChanged: (f) => _resizeSelectedArea(width: f),
      onHeightChanged: (f) => _resizeSelectedArea(height: f),
      onToggleImageFit: _toggleAllImageFitModes,
      onReset: () => _update(
        _settings.copyWith(layout: _settings.layout.withEqualSizes()),
      ),
    ),
    _CollageTab.aspect => CollageAspectPanel(
      settings: _settings,
      actions: _panelActions,
      customSelected: _customAspectSelected,
      onCustomSelected: (v) => setState(() => _customAspectSelected = v),
    ),
    _CollageTab.margin => CollageMarginPanel(
      settings: _settings,
      actions: _panelActions,
      marginAllValue: _marginAllValue,
      onMarginAllChanged: (v) {
        _marginAllValue = v;
        _update(
          _settings.copyWith(outerMarginRatio: v, innerMarginRatio: v),
          pushUndo: false,
        );
      },
      onResetMargins: () {
        _marginAllValue = 0;
        _update(_settings.copyWith(outerMarginRatio: 0, innerMarginRatio: 0));
      },
    ),
    _CollageTab.border => CollageBorderPanel(
      settings: _settings,
      actions: _panelActions,
      targetsPhotos: _borderTargetsPhotos,
      onTargetChanged: (v) => setState(() => _borderTargetsPhotos = v),
      firstCell: _firstCell,
      previewImageBuilder: _renderPreviewImage,
    ),
    _CollageTab.background => CollageBackgroundPanel(
      targetBackground: _targetBackground,
      targetsPhotos: _backgroundTargetsPhotos,
      onTargetChanged: (v) => setState(() => _backgroundTargetsPhotos = v),
      importedBackgrounds: _importedBackgrounds,
      onApply: _applyBackground,
      onImport: _importBackgroundImage,
      onRemoveImported: _confirmRemoveBackground,
      onPushUndoCheckpoint: _pushUndoCheckpoint,
      previewImageBuilder: _renderPreviewImage,
    ),
    _CollageTab.color => CollageColorPanel(
      settings: _settings,
      actions: _panelActions,
    ),
    _CollageTab.stickers => StickerLibraryPanel(
      library: _stickerLibrary,
      placed: _settings.stickers,
      usedIn: (pt: 'da montagem', en: 'from the collage'),
      onAddBundled: _addBundledSticker,
      onAddImported: _addStickerFromAsset,
      onRemovePlaced: _removePlacedStickers,
    ),
    _CollageTab.text => CollageTextPanel(
      selectedText: _selectedOverlayId == null
          ? null
          : _findText(_selectedOverlayId!),
      editingTextId: _editingTextId,
      textController: _textController,
      textFocus: _textFocus,
      findText: _findText,
      onReplaceText: (id, item, {bool pushUndo = true}) =>
          _update(_settings.replacingText(id, item), pushUndo: pushUndo),
      onPushUndoCheckpoint: _pushUndoCheckpoint,
      onSubmit: _submitPanelText,
      onCancelEdit: _cancelTextEdit,
      previewImageBuilder: _renderPreviewImage,
    ),
    _CollageTab.settings => const PreviewSettingsPanel(),
  };

  IconData _tabIcon(_CollageTab tab) => switch (tab) {
    _CollageTab.layout => Icons.grid_view_outlined,
    _CollageTab.areas => Icons.view_quilt_outlined,
    _CollageTab.aspect => Icons.aspect_ratio_rounded,
    _CollageTab.margin => Icons.space_dashboard_outlined,
    _CollageTab.border => Icons.crop_din_rounded,
    _CollageTab.background => Icons.wallpaper_rounded,
    _CollageTab.color => Icons.tune_rounded,
    _CollageTab.stickers => Icons.emoji_emotions_outlined,
    _CollageTab.text => Icons.text_fields_rounded,
    _CollageTab.settings => Icons.settings_rounded,
  };

  String _tabLabel(_CollageTab tab) => switch (tab) {
    _CollageTab.layout => tr('Layout', 'Layout'),
    _CollageTab.areas => tr('Áreas', 'Areas'),
    _CollageTab.aspect => tr('Proporção', 'Aspect'),
    _CollageTab.margin => tr('Margem', 'Margin'),
    _CollageTab.border => tr('Borda', 'Border'),
    _CollageTab.background => tr('Fundo', 'Background'),
    _CollageTab.color => tr('Cor', 'Color'),
    _CollageTab.stickers => tr('Stickers', 'Stickers'),
    _CollageTab.text => tr('Texto', 'Text'),
    _CollageTab.settings => tr('Configurações', 'Settings'),
  };

  // ---------------------------------------------------------------------
  // Prévia
  // ---------------------------------------------------------------------

  Widget _preview() {
    return AspectRatio(
      aspectRatio: _settings.aspectRatio,
      // Contorno fino marcando sempre a área da montagem, como em "Editar
      // imagem" — por cima (não empurra o conteúdo) e só na prévia.
      child: Container(
        key: const ValueKey('collageAreaOutline'),
        foregroundDecoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final geometry = CollageGeometry.of(size, _settings);
            return Stack(
              fit: StackFit.expand,
              children: [
                // A borda da prévia é desenhada pelo mesmo `paintCollageBorder`
                // da exportação (antes era um Container pintado à mão aqui, que
                // podia divergir do PNG final).
                if (geometry.borderThickness > 0)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: CollageBorderPainter(_settings),
                    ),
                  ),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.all(geometry.borderThickness),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(geometry.innerRadius),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _backgroundPreview(),
                          for (var i = 0; i < _settings.cells.length; i++)
                            Positioned.fromRect(
                              rect: geometry.cellRects[i].translate(
                                -geometry.borderThickness,
                                -geometry.borderThickness,
                              ),
                              child: _areaSelectable(
                                i,
                                CollageCellView(
                                  cell: _settings.cells[i],
                                  cellSize: geometry.cellRects[i].size,
                                  canvasWidth: geometry.canvasSize.width,
                                  // Com "Stickers" ou "Texto" aberto no rodapé, a
                                  // foto para de responder a gesto — só um dos
                                  // dois grupos (fotos, ou stickers/texto) pode
                                  // ser movido por vez, o mesmo motivo que
                                  // CollageOverlayView.interactive já aplica ao
                                  // contrário nesses dois casos.
                                  // Em "Áreas" também: o arrasto é das alças
                                  // entre as fotos, não do enquadramento.
                                  // Em "Áreas" a foto continua podendo ser
                                  // movida; o toque nela só a seleciona (ver o
                                  // `Listener` abaixo).
                                  interactive:
                                      _activeTab != _CollageTab.stickers &&
                                      _activeTab != _CollageTab.text,
                                  selected: _selectedPhotoCell == i,
                                  onSelectedChanged: (v) => setState(
                                    () => _selectedPhotoCell = v ? i : null,
                                  ),
                                  onGestureStart: _pushUndoCheckpoint,
                                  onChanged: (cell) => _update(
                                    _settings.replacingCell(i, cell),
                                    pushUndo: false,
                                  ),
                                  onMenu: () => openCollageCellMenu(
                                    i,
                                    context,
                                    settings: () => _settings,
                                    actions: _panelActions,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                ..._overlayWidgets(size),
                if (_activeTab == _CollageTab.layout &&
                    _settings.layout.kind == CollageLayoutKind.custom)
                  ..._addSlotButtons(geometry),
                if (_activeTab == _CollageTab.areas) ...[
                  ..._areaHighlights(geometry),
                  ..._dividerHandles(geometry),
                ],
                // Sempre depois (por cima) das sobreposições, sem ligar para
                // o zIndex de quem está selecionado — ver o porquê no doc de
                // `CollageOverlayView`.
                ..._selectedHandlesWidgets(size),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Botões "+" do layout "Personalizada": um no meio de cada lado de cada
  /// espaço, um pouco para dentro (os "+" de duas vizinhas não se
  /// encostam). Tocar divide aquele espaço em dois, com o novo daquele lado.
  List<Widget> _addSlotButtons(CollageGeometry geometry) {
    if (_settings.cells.length >= CollageLayout.maxCustomCells) {
      return const [];
    }
    // Bolinha pequena encostada na borda, por dentro; a área de toque é
    // maior que o desenho para o dedo acertar.
    const dot = 20.0;
    const touch = 32.0;
    const inset = 2.0;
    final scheme = Theme.of(context).colorScheme;
    final buttons = <Widget>[];
    for (var i = 0; i < geometry.cellRects.length; i++) {
      final r = geometry.cellRects[i];
      const d = inset + dot / 2;
      final centers = {
        CollageSide.left: Offset(r.left + d, r.center.dy),
        CollageSide.right: Offset(r.right - d, r.center.dy),
        CollageSide.top: Offset(r.center.dx, r.top + d),
        CollageSide.bottom: Offset(r.center.dx, r.bottom - d),
      };
      for (final MapEntry(key: side, value: c) in centers.entries) {
        buttons.add(
          Positioned(
            key: ValueKey('collageAddSlot_${i}_${side.name}'),
            left: c.dx - touch / 2,
            top: c.dy - touch / 2,
            width: touch,
            height: touch,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _addSlot(i, side),
              child: Center(
                child: Container(
                  width: dot,
                  height: dot,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Color(0x40000000), blurRadius: 3),
                    ],
                  ),
                  child: Icon(Icons.add, size: 14, color: scheme.onPrimary),
                ),
              ),
            ),
          ),
        );
      }
    }
    return buttons;
  }

  /// Divide o espaço [cell] em dois, com o novo (vazio, no estilo das
  /// outras fotos) do lado [side].
  void _addSlot(int cell, CollageSide side) {
    final layout = _settings.layout.splitCell(cell, side);
    if (identical(layout, _settings.layout)) return;
    _update(
      _settings.copyWith(
        layout: layout,
        cells: [
          ..._settings.cells,
          _settings.withSharedCellStyle(CollageDefaults.cell()),
        ],
      ),
    );
  }

  /// Na aba "Áreas", tocar numa foto a seleciona (mostra as alças dela).
  /// É um `Listener` e não um toque do `GestureDetector`, para não disputar
  /// com o arrasto que move a foto dentro da área.
  Widget _areaSelectable(int index, Widget cell) {
    if (_activeTab != _CollageTab.areas) return cell;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        if (_selectedAreaCell != index) {
          setState(() => _selectedAreaCell = index);
        }
      },
      child: cell,
    );
  }

  /// Largura ou altura nova (fração) da foto selecionada, vinda dos sliders
  /// do cartão "Área selecionada" (apagados com a área travada).
  void _resizeSelectedArea({double? width, double? height}) {
    final cell = _validSelectedAreaCell;
    if (cell == null || _lockAreaAspect) return;
    final layout = _settings.layout;
    final next = width != null
        ? layout.withWidthFraction(cell, width)
        : layout.withHeightFraction(cell, height!);
    if (_breaksLockedAreas(_settings.layout, next)) return;
    _update(_settings.copyWith(layout: next), pushUndo: false);
  }

  /// Se [next] muda o tamanho de alguma foto com "Travar área" ligado. Uma
  /// foto travada nunca muda de tamanho: o arrasto ou o controle que faria
  /// isso simplesmente não tem efeito — inclusive quando quem está sendo
  /// redimensionada é uma vizinha dela. "Tamanhos iguais" continua valendo
  /// (é um pedido explícito de voltar ao padrão).
  bool _breaksLockedAreas(CollageLayout before, CollageLayout next) {
    for (final cell in _lockedAreaCells) {
      if (cell >= _settings.cells.length) continue;
      final dw = (next.widthFractionOf(cell) - before.widthFractionOf(cell))
          .abs();
      final dh = (next.heightFractionOf(cell) - before.heightFractionOf(cell))
          .abs();
      if (dw > 1e-4 || dh > 1e-4) return true;
    }
    return false;
  }

  /// Alterna todas as fotos juntas entre preencher e encaixar. Se os modos
  /// estiverem misturados, primeiro unifica tudo em encaixar; o próximo toque
  /// volta tudo para preencher. O enquadramento é reiniciado como no duplo
  /// toque individual, evitando herdar zoom, rotação ou deslocamento de um
  /// modo cuja geometria é diferente.
  void _toggleAllImageFitModes() {
    final hasCover = _settings.cells.any(
      (cell) => cell.hasPhoto && cell.fitMode == CollageCellFitMode.cover,
    );
    final target = hasCover
        ? CollageCellFitMode.contain
        : CollageCellFitMode.cover;
    _update(
      _settings.copyWith(
        cells: [
          for (final cell in _settings.cells)
            if (cell.hasPhoto)
              cell.resetFraming().copyWith(fitMode: target)
            else
              cell,
        ],
      ),
    );
  }

  /// Foto selecionada na aba "Áreas", se ela ainda existe no layout atual
  /// (desfazer ou trocar de layout pode ter tirado células).
  int? get _validSelectedAreaCell {
    if (_settings.cells.isEmpty) return null;
    final index = _selectedAreaCell ?? 0;
    return index < _settings.cells.length ? index : 0;
  }

  /// Arrasto de uma alça da aba "Áreas": o divisor arrastado se move, e
  /// uma área travada encostada nele anda inteira sem mudar de tamanho.
  void _dragDivider(CollageDivider divider, double delta, Size contentSize) {
    // Áreas travadas não mudam de tamanho, mas andam inteiras quando a
    // vizinha empurra (a do outro lado delas é que encolhe).
    _dragTotal += delta;
    final start = _dragStartLayout ?? _settings.layout;
    final next = start.resizedKeepingLocked(
      divider,
      _dragStartLayout == null ? delta : _dragTotal,
      contentSize,
      locked: {
        for (final c in _lockedAreaCells)
          if (c < _settings.cells.length) c,
      },
      outerMarginRatio: _settings.outerMarginRatio,
      innerMarginRatio: _settings.innerMarginRatio,
    );
    if (next == null) return;
    _update(_settings.copyWith(layout: next), pushUndo: false);
  }

  /// Tamanho da área de conteúdo (dentro da borda) — o espaço de
  /// [CollageLayout.cellRectsFor] que as alças usam.
  Size _contentSizeOf(CollageGeometry geometry) {
    final thickness = geometry.borderThickness;
    return Size(
      (geometry.canvasSize.width - thickness * 2).clamp(0.0, double.infinity),
      (geometry.canvasSize.height - thickness * 2).clamp(0.0, double.infinity),
    );
  }

  /// Contorno de destaque da aba "Áreas": na foto selecionada e, enquanto
  /// uma alça é arrastada, em todas as fotos que ela está redimensionando.
  List<Widget> _areaHighlights(CollageGeometry geometry) {
    final selected = _validSelectedAreaCell;
    final dragging = _draggingDivider;
    final indices = <int>{
      ?selected,
      if (dragging != null) ..._settings.layout.cellsTouching(dragging),
    };
    final color = Theme.of(context).colorScheme.primary;
    return [
      for (final i in indices)
        if (i < geometry.cellRects.length)
          Positioned.fromRect(
            key: ValueKey('collageAreaHighlight_$i'),
            rect: geometry.cellRects[i],
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: dragging == null || i == selected
                        ? color
                        : color.withValues(alpha: 0.6),
                    width: 2.5,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
      // Cadeado no canto de cima, à esquerda (o da direita é do "..."), de
      // cada foto com "Travar área" ligado.
      for (final i in _lockedAreaCells)
        if (i < geometry.cellRects.length)
          Positioned(
            key: ValueKey('collageAreaLockBadge_$i'),
            left: geometry.cellRects[i].left + 6,
            top: geometry.cellRects[i].top + 6,
            width: 20,
            height: 20,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(
                  Icons.lock_rounded,
                  size: 12,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
    ];
  }

  /// Alças da aba "Áreas": só as da foto selecionada, pequenas, no meio de
  /// cada borda que ela divide com uma vizinha. O arrasto vira
  /// [CollageLayout.resizedBy] contra o tamanho real da área de conteúdo da
  /// prévia; a exportação só vê os pesos, que são proporcionais.
  List<Widget> _dividerHandles(CollageGeometry geometry) {
    final selected = _validSelectedAreaCell;
    // Área travada: sem alças, o tamanho dela não muda.
    if (selected == null || _lockAreaAspect) return const [];
    final thickness = geometry.borderThickness;
    final contentSize = _contentSizeOf(geometry);
    final handles = _settings.layout.handlesAround(
      selected,
      contentSize,
      outerMarginRatio: _settings.outerMarginRatio,
      innerMarginRatio: _settings.innerMarginRatio,
    );
    const long = CollageDividerHandle.touchLong;
    const short = CollageDividerHandle.touchShort;
    return [
      for (final handle in handles)
        Positioned(
          // Chave única por divisor: no "Personalizada" todos têm
          // column/index -1, e chaves repetidas deixavam alças antigas
          // presas na prévia depois de sair de "Áreas".
          key: ValueKey(
            'collageDivider_${handle.divider.vertical ? 'v' : 'h'}_'
            '${handle.divider.path ?? '${handle.divider.column}_${handle.divider.index}'}',
          ),
          left:
              thickness +
              handle.center.dx -
              (handle.divider.vertical ? short : long) / 2,
          top:
              thickness +
              handle.center.dy -
              (handle.divider.vertical ? long : short) / 2,
          width: handle.divider.vertical ? short : long,
          height: handle.divider.vertical ? long : short,
          child: CollageDividerHandle(
            divider: handle.divider,
            onDragStart: () {
              _pushUndoCheckpoint();
              _dragStartLayout = _settings.layout;
              _dragTotal = 0;
              setState(() => _draggingDivider = handle.divider);
            },
            onDragEnd: () {
              _dragStartLayout = null;
              _dragTotal = 0;
              setState(() => _draggingDivider = null);
            },
            onDrag: (delta) => _dragDivider(handle.divider, delta, contentSize),
          ),
        ),
    ];
  }

  Widget _backgroundPreview() {
    final background = _settings.background;
    switch (background.mode) {
      case CollageBackgroundMode.transparent:
        return const SizedBox.shrink();
      case CollageBackgroundMode.color:
        return ColoredBox(color: background.color);
      case CollageBackgroundMode.image:
        final path = background.imagePath;
        if (path == null) return const SizedBox.shrink();
        return BackgroundImageView(path: path);
    }
  }

  /// Sticker e texto entram na mesma lista, ordenados por `zIndex` (menor
  /// primeiro) — mesma ordem usada por `collage_compositor.dart`'s
  /// `_paintOverlays`, para "Frente"/"Trás" terem o mesmo efeito visual na
  /// prévia e na exportação. As `Key`s estáveis (`ValueKey(id)`) garantem
  /// que reordenar a lista a cada rebuild não recrie os widgets nem perca o
  /// estado local de gesto em andamento.
  List<Widget> _overlayWidgets(Size size) {
    final entries = <(int zIndex, Widget widget)>[
      for (final sticker in _settings.stickers)
        (sticker.zIndex, _stickerOverlayWidget(sticker, size)),
      for (final text in _settings.texts)
        (text.zIndex, _textOverlayWidget(text, size)),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final entry in entries) entry.$2];
  }

  Widget _stickerOverlayWidget(CollageSticker sticker, Size size) {
    return CollageOverlayView(
      key: ValueKey(sticker.id),
      centerX: sticker.centerX,
      centerY: sticker.centerY,
      scale: sticker.scale,
      rotation: sticker.rotation,
      minScale: CollageSticker.minScale,
      maxScale: CollageSticker.maxScale,
      canvasSize: size,
      selected: _activeSelectionId == sticker.id,
      interactive: _activeTab == _CollageTab.stickers,
      onSelect: () => setState(() => _selectedOverlayId = sticker.id),
      onGestureStart: _pushUndoCheckpoint,
      onTransformChanged: (cx, cy, scale, rotation) => _update(
        _settings.replacingSticker(
          sticker.id,
          sticker.copyWith(
            centerX: cx,
            centerY: cy,
            scale: scale,
            rotation: rotation,
          ),
        ),
        pushUndo: false,
      ),
      child: _stickerArt(sticker, size),
    );
  }

  Widget _textOverlayWidget(CollageTextItem text, Size size) {
    return CollageOverlayView(
      key: ValueKey(text.id),
      centerX: text.centerX,
      centerY: text.centerY,
      scale: text.scale,
      rotation: text.rotation,
      minScale: CollageTextItem.minScale,
      maxScale: CollageTextItem.maxScale,
      canvasSize: size,
      selected: _activeSelectionId == text.id,
      interactive: _activeTab == _CollageTab.text,
      onSelect: () => setState(() => _selectedOverlayId = text.id),
      onGestureStart: _pushUndoCheckpoint,
      onTransformChanged: (cx, cy, scale, rotation) => _update(
        _settings.replacingText(
          text.id,
          text.copyWith(
            centerX: cx,
            centerY: cy,
            scale: scale,
            rotation: rotation,
          ),
        ),
        pushUndo: false,
      ),
      child: textOverlayArt(text, size),
    );
  }

  Widget _stickerArt(CollageSticker sticker, Size canvasSize) {
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
      ),
    };
    return SizedBox(width: refSize, height: refSize, child: content);
  }

  // ---------------------------------------------------------------------
  // Alças de redimensionar/girar do item selecionado — numa camada própria,
  // sempre por cima de tudo na pilha principal (ver o porquê no doc de
  // `CollageOverlayView`), calculadas analiticamente em vez de medidas em
  // tempo de execução.
  // ---------------------------------------------------------------------

  /// Tamanho natural (escala 1) do conteúdo de um sticker — mesmo `refSize`
  /// quadrado que [_stickerArt] usa.
  Size _stickerNaturalSize(CollageSticker sticker, Size canvasSize) {
    final refSize = canvasSize.shortestSide * CollageSticker.referenceSizeRatio;
    return Size(refSize, refSize);
  }

  /// Geometria + como aplicar a transformação de volta, para o sticker ou
  /// texto selecionado agora — `null` fora das abas "Stickers"/"Texto" ou
  /// sem nada selecionado (mesma regra de [_activeSelectionId]).
  _SelectedOverlayGeometry? _selectedOverlayGeometry(Size canvasSize) {
    final id = _activeSelectionId;
    if (id == null) return null;

    final sticker = _findSticker(id);
    if (sticker != null) {
      return _SelectedOverlayGeometry(
        centerX: sticker.centerX,
        centerY: sticker.centerY,
        scale: sticker.scale,
        rotation: sticker.rotation,
        minScale: CollageSticker.minScale,
        maxScale: CollageSticker.maxScale,
        naturalSize: _stickerNaturalSize(sticker, canvasSize),
        apply: (cx, cy, s, r) => _update(
          _settings.replacingSticker(
            id,
            sticker.copyWith(centerX: cx, centerY: cy, scale: s, rotation: r),
          ),
          pushUndo: false,
        ),
      );
    }

    final text = _findText(id);
    if (text != null) {
      return _SelectedOverlayGeometry(
        centerX: text.centerX,
        centerY: text.centerY,
        scale: text.scale,
        rotation: text.rotation,
        minScale: CollageTextItem.minScale,
        maxScale: CollageTextItem.maxScale,
        naturalSize: textOverlayNaturalSize(text, canvasSize),
        apply: (cx, cy, s, r) => _update(
          _settings.replacingText(
            id,
            text.copyWith(centerX: cx, centerY: cy, scale: s, rotation: r),
          ),
          pushUndo: false,
        ),
      );
    }
    return null;
  }

  /// Gesto em andamento das alças de redimensionar/girar.
  final _handleDrag = OverlayHandleDrag();

  /// As duas alças do item selecionado, sempre por cima de tudo — ver o doc
  /// de `CollageOverlayView` para o porquê de não morarem mais dentro dele.
  List<Widget> _selectedHandlesWidgets(Size canvasSize) {
    final geometry = _selectedOverlayGeometry(canvasSize);
    if (geometry == null) return const [];

    final points = overlayHandlePoints(
      centerX: geometry.centerX,
      centerY: geometry.centerY,
      naturalSize: geometry.naturalSize,
      scale: geometry.scale,
      rotation: geometry.rotation,
      canvasSize: canvasSize,
    );

    return [
      OverlayHandle(
        center: points.bottomRight,
        icon: Icons.open_in_full_rounded,
        iconSize: 12,
        onPointerDown: (_) => _handleDrag.startResize(),
        onPointerMove: (event) {
          final scale = _handleDrag.resize(
            event,
            scale: geometry.scale,
            rotation: geometry.rotation,
            minScale: geometry.minScale,
            maxScale: geometry.maxScale,
            canvasSize: canvasSize,
            onFirstChange: _pushUndoCheckpoint,
          );
          if (scale == null) return;
          geometry.apply(
            geometry.centerX,
            geometry.centerY,
            scale,
            geometry.rotation,
          );
        },
      ),
      OverlayHandle(
        center: points.topRight,
        icon: Icons.rotate_right_rounded,
        iconSize: 14,
        onPointerDown: (_) => _handleDrag.startRotate(points.topRight),
        onPointerMove: (event) {
          final rotation = _handleDrag.rotate(
            event,
            center: points.center,
            rotation: geometry.rotation,
            onFirstChange: _pushUndoCheckpoint,
          );
          if (rotation == null) return;
          geometry.apply(
            geometry.centerX,
            geometry.centerY,
            geometry.scale,
            rotation,
          );
        },
      ),
    ];
  }

  Widget? _selectionToolbar() {
    final id = _activeSelectionId;
    if (id == null) return null;
    final isText = _findText(id) != null;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 4,
        children: [
          if (isText)
            IconButton(
              tooltip: tr('Editar', 'Edit'),
              onPressed: () => _editSelectedText(id),
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
          if (isText)
            IconButton(
              tooltip: tr('Fonte', 'Font'),
              onPressed: () => _pickTextFont(id),
              icon: const Icon(Icons.font_download_outlined, size: 20),
            ),
          IconButton(
            tooltip: tr('Duplicar', 'Duplicate'),
            onPressed: () => _duplicateSelected(id, isText),
            icon: const Icon(Icons.copy_outlined, size: 20),
          ),
          IconButton(
            tooltip: tr('Frente', 'Front'),
            onPressed: () => _bringToFront(id, isText),
            icon: const Icon(Icons.flip_to_front_outlined, size: 20),
          ),
          IconButton(
            tooltip: tr('Trás', 'Back'),
            onPressed: () => _sendToBack(id, isText),
            icon: const Icon(Icons.flip_to_back_outlined, size: 20),
          ),
          IconButton(
            tooltip: tr('Remover', 'Remove'),
            onPressed: () => _removeSelected(id, isText),
            icon: const Icon(Icons.delete_outline, size: 20),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Seção "Layout"
  // ---------------------------------------------------------------------
  void _selectLayoutKind(CollageLayoutKind kind) {
    final currentCount = _settings.cells.length.clamp(2, 8);
    final layout = switch (kind) {
      CollageLayoutKind.row => CollageLayout.row(currentCount),
      CollageLayoutKind.column => CollageLayout.column(currentCount),
      CollageLayoutKind.grid2x2 => const CollageLayout(
        kind: CollageLayoutKind.grid2x2,
      ),
      CollageLayoutKind.grid2x3 => const CollageLayout(
        kind: CollageLayoutKind.grid2x3,
      ),
      CollageLayoutKind.grid3x3 => const CollageLayout(
        kind: CollageLayoutKind.grid3x3,
      ),
      // Mantém as colunas/linhas do layout atual (uma 3×3 continua 3×3);
      // só os botões de + e − da grade livre mudam isso.
      // Parte da montagem atual: as fotos ficam onde estavam.
      CollageLayoutKind.custom => _settings.layout.toCustom(),
      CollageLayoutKind.freeGrid => CollageLayout.grid(
        _settings.layout.columnCount.clamp(
          CollageLayout.minFreeGridSpan,
          CollageLayout.maxFreeGridSpan,
        ),
        _settings.layout.rowCount.clamp(
          CollageLayout.minFreeGridSpan,
          CollageLayout.maxFreeGridSpan,
        ),
      ),
    };
    _applyLayout(layout);
  }

  /// Troca o layout mantendo as fotos já escolhidas nas primeiras células —
  /// células novas (quando o layout cresce) nascem vazias, prontas para
  /// receber uma foto ao toque (ver [CollageCellView]'s `+`), mas já com a
  /// borda/canto/fundo das fotos que já estão na montagem; células
  /// excedentes (quando o layout encolhe) são descartadas.
  void _applyLayout(CollageLayout layout) {
    final oldCells = _settings.cells;
    final cells = List<CollageCellSettings>.generate(
      layout.cellCount,
      (i) => i < oldCells.length
          ? oldCells[i]
          : _settings.withSharedCellStyle(CollageDefaults.cell()),
    );
    _selectedAreaCell = null;
    _lockedAreaCells.clear();
    _update(_settings.copyWith(layout: layout, cells: cells));
  }

  // ---------------------------------------------------------------------
  // Seção "Margem" / "Proporção" / "Borda e cantos"
  // ---------------------------------------------------------------------

  /// Espessura/arredondamento/cor atuais para o alvo escolhido no seletor
  /// "Montagem"/"Fotos" — quando o alvo é "Fotos", os 3 controles mexem em
  /// todas as células de uma vez ([CollageSettings.updatingAllCells]), então
  /// a primeira célula representa bem todas (não sobra mais nenhum jeito de
  /// uma foto divergir da outra, já que "Borda da foto" saiu do menu "...").
  CollageCellSettings? get _firstCell =>
      _settings.cells.isEmpty ? null : _settings.cells.first;

  // ---------------------------------------------------------------------
  // Seção "Fundo"
  // ---------------------------------------------------------------------

  /// Fundo do alvo escolhido no seletor "Montagem"/"Fotos": o da montagem
  /// inteira ou o de dentro das fotos. Com o alvo "Fotos" os controles mexem
  /// em todas as células de uma vez ([CollageSettings.updatingAllCells]),
  /// então a primeira célula representa bem todas — mesma lógica de
  /// [CollageBorderPanel].
  CollageBackground get _targetBackground => _backgroundTargetsPhotos
      ? (_firstCell?.background ?? CollageDefaults.background())
      : _settings.background;

  void _applyBackground(CollageBackground background, {bool pushUndo = true}) {
    _update(
      _backgroundTargetsPhotos
          ? _settings.updatingAllCells(
              (cell) => cell.copyWith(background: background),
            )
          : _settings.copyWith(background: background),
      pushUndo: pushUndo,
    );
  }

  Future<void> _importBackgroundImage() async {
    try {
      final asset = await _backgroundStore.import();
      if (!mounted) return;
      setState(() => _importedBackgrounds = [..._importedBackgrounds, asset]);
      _applyBackground(
        _targetBackground.copyWith(
          mode: CollageBackgroundMode.image,
          imagePath: asset.filePath,
        ),
      );
    } on ImportedAssetException catch (e) {
      _message(e.message);
    }
  }

  Future<void> _confirmRemoveBackground(ImportedAsset asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: DialogTitle(
          tr('Remover imagem de fundo?', 'Remove background image?'),
        ),
        content: Text(
          tr(
            '"${asset.label}" vai ser removida da lista.',
            '"${asset.label}" will be removed from the list.',
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

    await _backgroundStore.remove(asset.id);
    if (!mounted) return;
    setState(() {
      _importedBackgrounds = _importedBackgrounds
          .where((a) => a.id != asset.id)
          .toList();
    });
    // A imagem apagada pode estar em uso como fundo da montagem, das fotos ou
    // dos dois ao mesmo tempo — quem apontava para o arquivo que sumiu volta
    // para transparente, independente do alvo selecionado agora.
    var updated = _settings;
    if (updated.background.imagePath == asset.filePath) {
      updated = updated.copyWith(
        background: updated.background.copyWith(
          mode: CollageBackgroundMode.transparent,
          clearImagePath: true,
        ),
      );
    }
    if (updated.cells.any((c) => c.background.imagePath == asset.filePath)) {
      updated = updated.updatingAllCells(
        (cell) => cell.background.imagePath == asset.filePath
            ? cell.copyWith(
                background: cell.background.copyWith(
                  mode: CollageBackgroundMode.transparent,
                  clearImagePath: true,
                ),
              )
            : cell,
      );
    }
    if (!identical(updated, _settings)) _update(updated);
  }

  Future<ui.Image> _renderPreviewImage() async {
    final bytes = await composeCollage(
      settings: _settings,
      outputWidth: _previewSampleWidth(),
    );
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  int _previewSampleWidth() => 480;

  // ---------------------------------------------------------------------
  // Seção "Ajustar cor"
  // ---------------------------------------------------------------------

  // ---------------------------------------------------------------------
  // Seção "Stickers" / "Texto"
  // ---------------------------------------------------------------------

  void _addBundledSticker((String path, String label) sticker) {
    final item = CollageSticker(
      id: 's_${DateTime.now().microsecondsSinceEpoch}',
      source: CollageStickerSource.bundledSvg,
      assetPath: sticker.$1,
      label: sticker.$2,
      centerX: 0.5,
      centerY: 0.5,
      zIndex: _settings.nextZIndex,
    );
    _update(_settings.addingSticker(item));
    setState(() => _selectedOverlayId = item.id);
  }

  void _addStickerFromAsset(ImportedAsset asset) {
    final sticker = CollageSticker(
      id: 's_${DateTime.now().microsecondsSinceEpoch}',
      source: asset.isVector
          ? CollageStickerSource.importedSvg
          : CollageStickerSource.importedImage,
      imageFilePath: asset.filePath,
      label: asset.label,
      centerX: 0.5,
      centerY: 0.5,
      zIndex: _settings.nextZIndex,
    );
    _update(_settings.addingSticker(sticker));
    setState(() => _selectedOverlayId = sticker.id);
  }

  /// O arquivo acabou de ser apagado do aparelho: deixar as cópias já
  /// colocadas na montagem apontando para ele quebrava a prévia e fazia a
  /// exportação inteira falhar com "Não foi possível gerar a imagem".
  void _removePlacedStickers(List<CollageSticker> inUse) {
    var updated = _settings;
    for (final sticker in inUse) {
      updated = updated.removingSticker(sticker.id);
    }
    _update(updated);
    setState(_dropSelectionIfGone);
  }

  /// Cria a caixa nova (ou salva a que o lápis trouxe para o campo). O foco
  /// volta para o campo em vez de sair: dá para escrever várias caixas em
  /// sequência sem reabrir o teclado a cada uma.
  void _submitPanelText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final editingId = _editingTextId;
    if (editingId != null) {
      final item = _findText(editingId);
      if (item != null) {
        _update(_settings.replacingText(editingId, item.copyWith(text: text)));
      }
      setState(() => _editingTextId = null);
    } else {
      final item = CollageTextItem(
        id: 't_${DateTime.now().microsecondsSinceEpoch}',
        text: text,
        color: EditorDefaults.text,
        centerX: 0.5,
        centerY: 0.5,
        zIndex: _settings.nextZIndex,
      );
      _update(_settings.addingText(item));
      setState(() => _selectedOverlayId = item.id);
    }
    _textController.clear();
    _textFocus.requestFocus();
  }

  void _cancelTextEdit() {
    setState(() => _editingTextId = null);
    _textController.clear();
  }

  /// O lápis da barra de ações traz o texto da caixa selecionada para o campo
  /// do painel — que já está na tela, já que a barra só aparece com a aba
  /// "Texto" aberta.
  void _editSelectedText(String id) {
    final item = _findText(id);
    if (item == null) return;
    setState(() {
      _editingTextId = id;
      _textController.text = item.text;
      _textController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: item.text.length,
      );
    });
    _textFocus.requestFocus();
  }

  /// Folha com as [bundledCollageFonts] em miniaturas "Aa", cada uma
  /// renderizada na própria fonte — mesmo padrão visual dos outros sheets
  /// de escolha (`showModalBottomSheet` + `Wrap`).
  void _pickTextFont(String id) {
    final item = _findText(id);
    if (item == null) return;
    showFontPickerSheet(
      context,
      selectedFamily: item.fontFamily,
      importedFonts: _importedFonts,
      onSelected: (family) => _applyTextFont(id, family),
      onImport: () => _importFont(id),
      // As importadas ficam na mesma grade das embutidas — segurar remove.
      onRemoveImported: _confirmRemoveFont,
    );
  }

  void _applyTextFont(String id, String? family) {
    final item = _findText(id);
    if (item == null) return;
    _pushUndoCheckpoint();
    _update(
      _settings.replacingText(
        id,
        item.copyWith(fontFamily: family, clearFontFamily: family == null),
      ),
      pushUndo: false,
    );
  }

  /// Importar uma fonte já a aplica no texto que abriu a folha — mesmo
  /// caminho de "importar e usar" dos stickers.
  Future<void> _importFont(String textId) async {
    try {
      final font = await _fontStore.import();
      if (!mounted) return;
      setState(() => _importedFonts = [..._importedFonts, font]);
      _applyTextFont(textId, font.family);
    } on ImportedFontException catch (e) {
      _message(e.message);
    }
  }

  /// Remover a fonte devolve os textos que a usavam para a fonte padrão — a
  /// família deixa de existir na próxima abertura do app, e um texto
  /// apontando para ela ficaria com uma fonte que não é a escolhida nem a
  /// mostrada agora.
  Future<void> _confirmRemoveFont(ImportedFont font) async {
    final inUse = _settings.texts
        .where((t) => t.fontFamily == font.family)
        .toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: DialogTitle(tr('Remover fonte?', 'Remove font?')),
        content: Text(
          inUse.isEmpty
              ? tr(
                  '"${font.label}" vai sair da lista de fontes.',
                  '"${font.label}" will leave the font list.',
                )
              : tr(
                  '"${font.label}" vai sair da lista de fontes, e '
                      '${inUse.length == 1 ? 'o texto que a usa volta' : 'os ${inUse.length} textos que a usam voltam'} '
                      'para a fonte padrão.',
                  '"${font.label}" will leave the font list, and '
                      '${inUse.length == 1 ? 'the text using it goes' : 'the ${inUse.length} texts using it go'} '
                      'back to the default font.',
                ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('Remover', 'Remove')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _fontStore.remove(font.id);
    if (!mounted) return;
    setState(() {
      _importedFonts = _importedFonts.where((f) => f.id != font.id).toList();
    });
    var updated = _settings;
    for (final text in inUse) {
      updated = updated.replacingText(
        text.id,
        text.copyWith(clearFontFamily: true),
      );
    }
    if (!identical(updated, _settings)) _update(updated);
  }

  // ---------------------------------------------------------------------
  // Overlays selecionados: duplicar / frente / trás / remover
  // ---------------------------------------------------------------------

  CollageSticker? _findSticker(String id) {
    for (final sticker in _settings.stickers) {
      if (sticker.id == id) return sticker;
    }
    return null;
  }

  CollageTextItem? _findText(String id) {
    for (final text in _settings.texts) {
      if (text.id == id) return text;
    }
    return null;
  }

  int get _minOverlayZIndex {
    var min = 0;
    for (final sticker in _settings.stickers) {
      if (sticker.zIndex < min) min = sticker.zIndex;
    }
    for (final text in _settings.texts) {
      if (text.zIndex < min) min = text.zIndex;
    }
    return min;
  }

  void _duplicateSelected(String id, bool isText) {
    if (isText) {
      final item = _findText(id);
      if (item == null) return;
      final newItem = CollageTextItem(
        id: 't_${DateTime.now().microsecondsSinceEpoch}',
        text: item.text,
        color: item.color,
        fontSizeRatio: item.fontSizeRatio,
        bold: item.bold,
        centerX: (item.centerX + 0.05).clamp(0.0, 1.0),
        centerY: (item.centerY + 0.05).clamp(0.0, 1.0),
        scale: item.scale,
        rotation: item.rotation,
        zIndex: _settings.nextZIndex,
      );
      _update(_settings.addingText(newItem));
      setState(() => _selectedOverlayId = newItem.id);
    } else {
      final sticker = _findSticker(id);
      if (sticker == null) return;
      final newSticker = CollageSticker(
        id: 's_${DateTime.now().microsecondsSinceEpoch}',
        source: sticker.source,
        assetPath: sticker.assetPath,
        imageFilePath: sticker.imageFilePath,
        label: sticker.label,
        centerX: (sticker.centerX + 0.05).clamp(0.0, 1.0),
        centerY: (sticker.centerY + 0.05).clamp(0.0, 1.0),
        scale: sticker.scale,
        rotation: sticker.rotation,
        zIndex: _settings.nextZIndex,
      );
      _update(_settings.addingSticker(newSticker));
      setState(() => _selectedOverlayId = newSticker.id);
    }
  }

  void _bringToFront(String id, bool isText) {
    if (isText) {
      final item = _findText(id);
      if (item == null) return;
      _update(
        _settings.replacingText(
          id,
          item.copyWith(zIndex: _settings.nextZIndex),
        ),
      );
    } else {
      final sticker = _findSticker(id);
      if (sticker == null) return;
      _update(
        _settings.replacingSticker(
          id,
          sticker.copyWith(zIndex: _settings.nextZIndex),
        ),
      );
    }
  }

  void _sendToBack(String id, bool isText) {
    final z = _minOverlayZIndex - 1;
    if (isText) {
      final item = _findText(id);
      if (item == null) return;
      _update(_settings.replacingText(id, item.copyWith(zIndex: z)));
    } else {
      final sticker = _findSticker(id);
      if (sticker == null) return;
      _update(_settings.replacingSticker(id, sticker.copyWith(zIndex: z)));
    }
  }

  void _removeSelected(String id, bool isText) {
    _update(
      isText ? _settings.removingText(id) : _settings.removingSticker(id),
    );
    setState(() => _selectedOverlayId = null);
  }

  // ---------------------------------------------------------------------
  // Menu por célula: substituir / trocar / ajustar cor / girar / espelhar
  // ---------------------------------------------------------------------

  // ---------------------------------------------------------------------
  // Ações
  // ---------------------------------------------------------------------

  /// Formato, regra de duração e tamanho escolhidos na última exportação —
  /// a folha de opções reabre já marcada no que a pessoa usou da última vez.
  CollageExportFormat _exportFormat = CollageExportFormat.gif;
  CollageDurationRule _durationRule = CollageDurationRule.longest;
  CollageExportSize _exportSize = CollageExportSize.standard;

  /// Pergunta o formato (quando há foto animada na montagem) e o tamanho da
  /// exportação. Devolve `null` quando a pessoa fecha a folha sem escolher.
  ///
  /// [_exportFormat]/[_durationRule]/[_exportSize] só guardam a última
  /// escolha para a folha já abrir marcada nela; a seleção feita durante
  /// esta chamada vive em variáveis locais (`selectedFormat`/`selectedRule`/
  /// `selectedSize`) para não vazar para outra folha que porventura esteja
  /// aberta ao mesmo tempo.
  Future<CollageExportFormat?> _askExportFormat() async {
    final info = await _export.inspectAnimationCached(_settings);
    if (!mounted) return null;

    var selectedFormat = info.hasAnimation
        ? _exportFormat
        : CollageExportFormat.png;
    var selectedRule = _durationRule;
    var selectedSize = _exportSize;

    final result = await showModalBottomSheet<CollageExportFormat>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, sheetSetState) {
          final theme = Theme.of(sheetContext);
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Exportar', 'Export'),
                      style: theme.textTheme.titleMedium,
                    ),
                    if (info.hasAnimation) ...[
                      const SizedBox(height: 4),
                      Text(
                        info.animatedCount == 1
                            ? tr(
                                'Uma das fotos é animada — a montagem pode sair animada também.',
                                'One of the photos is animated — the collage can be animated too.',
                              )
                            : tr(
                                '${info.animatedCount} fotos são animadas — a montagem pode sair animada também.',
                                '${info.animatedCount} photos are animated — the collage can be animated too.',
                              ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RadioGroup<CollageExportFormat>(
                        groupValue: selectedFormat,
                        onChanged: (value) {
                          if (value == null) return;
                          sheetSetState(() => selectedFormat = value);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final format in CollageExportFormat.values)
                              RadioListTile<CollageExportFormat>(
                                contentPadding: EdgeInsets.zero,
                                value: format,
                                title: Text(format.label),
                                subtitle: Text(format.subtitle),
                              ),
                          ],
                        ),
                      ),
                      // Com duas ou mais animações a escolha aparece
                      // sempre, mesmo quando elas têm a mesma duração.
                      if (selectedFormat.isAnimated &&
                          info.animatedCount > 1) ...[
                        const Divider(height: 24),
                        Text(
                          tr('Duração', 'Duration'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        RadioGroup<CollageDurationRule>(
                          groupValue: selectedRule,
                          onChanged: (value) {
                            if (value == null) return;
                            sheetSetState(() => selectedRule = value);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final rule in CollageDurationRule.values)
                                RadioListTile<CollageDurationRule>(
                                  contentPadding: EdgeInsets.zero,
                                  value: rule,
                                  title: Text(
                                    '${rule.label} '
                                    '(${_formatSeconds(info.durationFor(rule))})',
                                  ),
                                  subtitle: Text(rule.subtitle),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const Divider(height: 24),
                    ] else
                      const SizedBox(height: 12),
                    Text(
                      tr('Tamanho', 'Size'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final size in CollageExportSize.values)
                          ChoiceChip(
                            label: Text(size.label),
                            selected: selectedSize == size,
                            onSelected: (_) =>
                                sheetSetState(() => selectedSize = size),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(sheetContext).pop(selectedFormat),
                      child: Text(tr('Continuar', 'Continue')),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _exportFormat = selectedFormat;
        _durationRule = selectedRule;
        _exportSize = selectedSize;
      });
    }
    return result;
  }

  String _formatSeconds(Duration duration) =>
      '${(duration.inMilliseconds / 1000).toStringAsFixed(1)} s';

  /// Abre o pop-up de progresso e roda a exportação. Devolve o arquivo, ou
  /// `null` quando o usuário cancelou — o pop-up sai da tela em qualquer um
  /// dos casos, inclusive em erro, para nunca sobrar um "exportando" preso.
  Future<File?> _exportWithProgress(CollageExportFormat format) async {
    // O PNG sai de uma composição só, rápida demais para valer um pop-up que
    // só piscaria na tela.
    if (!format.isAnimated) return _buildExportFile(format);

    _export.begin();
    final (width, height) = CollageExportRunner.pixelSize(
      _settings,
      _exportSize,
      format,
    );
    final diagnostics = await ExportDiagnostics.open();
    diagnostics?.start(
      tr(
        '${format.label} $width×$height, ${_settings.cells.length} áreas, ${_exportSize.label}',
        '${format.label} $width×$height, ${_settings.cells.length} areas, ${_exportSize.label}',
      ),
    );
    if (!mounted) return null;
    final navigator = Navigator.of(context, rootNavigator: true);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ExportProgressDialog(
          progress: _export.progress,
          formatLabel: format.label,
          width: width,
          height: height,
          onCancel: _export.cancel,
        ),
      ),
    );
    try {
      // Tira a prévia animada de cena e solta os quadros dela antes de
      // começar.
      setState(() => _exportingAnimated = true);
      await _nextFrame();
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      diagnostics?.step('prévia pausada');
      final file = await _buildExportFile(
        format,
        diagnostics: diagnostics,
        betweenFrames: _nextFrame,
      );
      diagnostics?.finish('ok');
      return file;
    } on CollageRenderCancelled {
      diagnostics?.finish('cancelada');
      return null;
    } on FfmpegException catch (e) {
      // Cancelar durante a codificação chega aqui como falha do FFmpeg —
      // não é erro para mostrar ao usuário.
      if (_export.cancelled) {
        diagnostics?.finish('cancelada');
        return null;
      }
      diagnostics?.finish('erro do FFmpeg: ${e.message}');
      rethrow;
    } catch (e) {
      diagnostics?.finish('erro: $e');
      rethrow;
    } finally {
      navigator.pop();
      if (mounted) setState(() => _exportingAnimated = false);
    }
  }

  /// Espera a tela desenhar o próximo quadro — com teto, porque com o app em
  /// segundo plano nenhum quadro é desenhado e a exportação não pode parar.
  Future<void> _nextFrame() => SchedulerBinding.instance.endOfFrame.timeout(
    const Duration(milliseconds: 250),
    onTimeout: () {},
  );

  /// Lugar da prévia enquanto a exportação animada roda (atrás do pop-up).
  Widget _exportPlaceholder() {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      key: const ValueKey('collageExportPlaceholder'),
      aspectRatio: _settings.aspectRatio,
      child: ColoredBox(color: scheme.surfaceContainerHigh),
    );
  }

  /// Se a exportação anterior ficou pela metade (o app foi fechado no meio),
  /// mostra onde ela parou — para dar para mandar ao suporte.
  Future<void> _showInterruptedExportReport() async {
    final diagnostics = await ExportDiagnostics.open();
    final report = await diagnostics?.interruptedReport();
    if (report == null || !mounted) return;
    diagnostics!.markSeen();
    final text = report.join('\n');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('interruptedExportDialog'),
        title: DialogTitle(
          tr(
            'A última exportação foi interrompida',
            'The last export was interrupted',
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(
                  'O app fechou enquanto salvava a montagem. Se acontecer de novo, toque em "Copiar" e mande este texto para o suporte.',
                  'The app closed while saving the collage. If it happens again, tap "Copy" and send this text to support.',
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                text,
                style: Theme.of(
                  dialogContext,
                ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.of(dialogContext).pop();
              _message(tr('Relatório copiado.', 'Report copied.'));
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: Text(tr('Copiar', 'Copy')),
          ),
        ],
      ),
    );
  }

  void _reportExportProgress(double value) {
    // O notifier morre junto com a tela; sem esta guarda, um quadro que
    // termina depois de sair da montagem escreveria num objeto descartado.
    if (!mounted) return;
    _export.progress.value = ExportProgress(
      value: value.clamp(0.0, 1.0),
      cancelling: _export.progress.value.cancelling,
    );
  }

  Future<File> _buildExportFile(
    CollageExportFormat format, {
    ExportDiagnostics? diagnostics,
    Future<void> Function()? betweenFrames,
  }) => _export.build(
    settings: _settings,
    format: format,
    size: _exportSize,
    rule: _durationRule,
    reportProgress: _reportExportProgress,
    diagnostics: diagnostics,
    betweenFrames: betweenFrames,
  );

  Future<void> _save() async {
    final format = await _askExportFormat();
    if (format == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final file = await _exportWithProgress(format);
      if (file == null) {
        if (mounted) _message(tr('Exportação cancelada.', 'Export cancelled.'));
        return;
      }
      await _output.saveToGallery(file);
      if (!mounted) return;
      await showSavedDialog(
        context,
        tr('Montagem salva na galeria.', 'Collage saved to the gallery.'),
      );
    } on OutputException catch (e) {
      if (!mounted) return;
      _message(e.message);
    } on FfmpegException catch (e) {
      if (!mounted) return;
      _message(e.message);
    } catch (_) {
      if (!mounted) return;
      _message(
        tr('Não foi possível gerar a imagem.', 'Could not create the image.'),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share() async {
    final format = await _askExportFormat();
    if (format == null || !mounted) return;
    setState(() => _sharing = true);
    try {
      final file = await _exportWithProgress(format);
      if (file == null) {
        if (mounted) _message(tr('Exportação cancelada.', 'Export cancelled.'));
        return;
      }
      await _output.share(
        file,
        mimeType: format.mimeType,
        text: tr(
          'Montagem de fotos feita com o app GitBat',
          'Photo collage made with the GitBat app',
        ),
      );
    } on FfmpegException catch (e) {
      if (!mounted) return;
      _message(e.message);
    } catch (_) {
      if (!mounted) return;
      _message(
        tr('Não foi possível gerar a imagem.', 'Could not create the image.'),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
}

/// Diálogo de texto que é dono do próprio [TextEditingController]. O
/// controller precisa viver e morrer junto com o State do diálogo: solto num
/// método `async`, ou vazava (nunca era liberado) ou era liberado assim que
/// `showDialog` retornava — ainda durante a animação de saída, com o campo
/// montado e usando um controller já descartado.
