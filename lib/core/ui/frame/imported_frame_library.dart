import 'package:flutter/widgets.dart';

import '../../models/image_frame.dart';
import '../../services/imported_frame_store.dart';
import 'image_frame_picker.dart';

/// As molduras de imagem que a pessoa importou, na fileira de miniaturas da
/// aba "Moldura" de Editar vídeo e Editar imagem. Quem redesenha depois de
/// cada operação — e seleciona ou limpa a moldura — é a tela.
class ImportedFrameLibrary {
  final _store = ImportedFrameStore();

  List<ImageFrameAsset> frames = [];

  /// Carrega as importadas em sessões anteriores, para continuarem
  /// aparecendo na fileira.
  Future<void> load() async => frames = await _store.loadAll();

  /// Abre o seletor de arquivos para um SVG de moldura próprio (mesmo
  /// formato das prontas, com uma janela transparente real) e acrescenta a
  /// moldura à lista. Lança [ImportedFrameException] quando não dá.
  Future<ImageFrameAsset> import() async {
    final asset = await _store.importFrame();
    frames = [...frames, asset];
    return asset;
  }

  /// Pergunta e, confirmado, apaga [asset] do aparelho e da lista. Devolve
  /// se apagou.
  Future<bool> remove(BuildContext context, ImageFrameAsset asset) async {
    if (!await confirmRemoveImportedFrame(context, asset)) return false;
    await _store.remove(asset.id);
    frames = frames.where((a) => a.id != asset.id).toList();
    return true;
  }
}
