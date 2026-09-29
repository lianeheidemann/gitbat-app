import 'package:flutter/material.dart';

import '../../models/frame_settings.dart';
import '../../models/image_frame.dart';
import 'image_frame_picker.dart';

/// Prévia ao vivo de uma moldura de imagem, em Editar vídeo e Editar imagem:
/// a arte (SVG das prontas do app ou importado, ou PNG importado no formato
/// legado) sempre na sua proporção nativa, nunca distorcida, com [child]
/// encaixado exatamente dentro da janela de conteúdo
/// ([ImageFrameAsset.contentRect]) por baixo dela — conforme
/// [FrameSettings.contentFit] e ampliado por
/// [FrameSettings.effectiveContentZoom]. O `Transform.scale` centraliza por
/// padrão, o mesmo alinhamento que a exportação usa para o zoom, então
/// prévia e arquivo final nunca divergem.
class ImageFramedPreview extends StatelessWidget {
  const ImageFramedPreview({
    super.key,
    required this.asset,
    required this.frame,
    required this.contentAspectRatio,
    required this.child,
  });

  final ImageFrameAsset asset;
  final FrameSettings frame;

  /// Proporção do conteúdo como ele entra na janela — já girada pela aba
  /// "Girar" ([FrameSettings.contentTransform]), que é a que o encaixe
  /// precisa olhar.
  final double contentAspectRatio;

  /// O conteúdo num tamanho de referência qualquer, na proporção certa: o
  /// `FittedBox` que o encaixa só olha para a proporção dele.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final preview = AspectRatio(
      aspectRatio: asset.nativeAspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final rect = Rect.fromLTWH(
            size.width * asset.contentRect.left,
            size.height * asset.contentRect.top,
            size.width * asset.contentRect.width,
            size.height * asset.contentRect.height,
          );
          final fit = resolveContentFit(
            frame.contentFit,
            contentAspectRatio,
            rect.width / rect.height,
          );

          return Stack(
            children: [
              Positioned.fromRect(rect: rect, child: _content(fit)),
              Positioned.fill(
                child: IgnorePointer(
                  child: ImageFrameArtwork(asset: asset, fit: BoxFit.fill),
                ),
              ),
            ],
          );
        },
      ),
    );
    if (frame.transparentBackground) return preview;
    return ColoredBox(color: frame.backgroundColor, child: preview);
  }

  /// O conteúdo dentro da janela. Em "Expandir sem cortar", a área que ele
  /// não ocupa fica com a cor do fundo da moldura, enquanto o zoom atua só
  /// sobre o conteúdo nítido central — a mesma composição da exportação.
  Widget _content(ContentFitMode fit) {
    Widget fitted(BoxFit boxFit) => FittedBox(fit: boxFit, child: child);

    if (fit != ContentFitMode.expand) {
      return ColoredBox(
        color: frame.expandBackgroundColor,
        child: ClipRect(
          child: fitted(
            fit == ContentFitMode.fill ? BoxFit.cover : BoxFit.contain,
          ),
        ),
      );
    }

    return ColoredBox(
      color: frame.expandBackgroundColor,
      child: ClipRect(
        child: Transform.scale(
          scale: frame.effectiveContentZoom,
          child: fitted(BoxFit.contain),
        ),
      ),
    );
  }
}
