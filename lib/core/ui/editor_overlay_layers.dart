import 'package:flutter/material.dart';

import '../models/collage_sticker.dart';
import '../models/collage_text.dart';
import 'sticker_overlay_editor.dart';
import 'text_overlay_editor.dart';

/// Stickers e textos arrastáveis por cima de [content], medidos no tamanho
/// exato dele — o mesmo canvas da exportação, para as coordenadas
/// normalizadas baterem. Os stickers ficam por baixo dos textos, como na
/// exportação.
///
/// É a pilha da prévia de Editar vídeo, Editar imagem e Editar SVG; a
/// Montagem desenha os dois numa camada só, ordenados juntos por `zIndex`.
class EditorOverlayLayers extends StatelessWidget {
  const EditorOverlayLayers({
    super.key,
    required this.content,
    required this.stickerController,
    required this.stickers,
    required this.onStickersChanged,
    required this.stickersInteractive,
    required this.textController,
    required this.texts,
    required this.onTextsChanged,
    required this.textsInteractive,
    required this.onGestureStart,
    this.fit = StackFit.loose,
  });

  final Widget content;

  final StickerOverlayController stickerController;
  final List<CollageSticker> stickers;
  final ValueChanged<List<CollageSticker>> onStickersChanged;

  /// Só com a aba "Stickers" aberta os stickers respondem a toque.
  final bool stickersInteractive;

  final TextOverlayController textController;
  final List<CollageTextItem> texts;
  final ValueChanged<List<CollageTextItem>> onTextsChanged;

  /// Só com a aba "Texto" aberta os textos respondem a toque.
  final bool textsInteractive;

  /// Antes do primeiro passo de um arrasto — o ponto de desfazer.
  final VoidCallback onGestureStart;

  /// Como a pilha dimensiona [content] (ver [Stack.fit]).
  final StackFit fit;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: fit,
      children: [
        content,
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) => StickerOverlayStack(
              controller: stickerController,
              stickers: stickers,
              onChanged: onStickersChanged,
              canvasSize: constraints.biggest,
              interactive: stickersInteractive,
              onGestureStart: onGestureStart,
            ),
          ),
        ),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) => TextOverlayStack(
              controller: textController,
              texts: texts,
              onChanged: onTextsChanged,
              canvasSize: constraints.biggest,
              interactive: textsInteractive,
              onGestureStart: onGestureStart,
            ),
          ),
        ),
      ],
    );
  }
}
