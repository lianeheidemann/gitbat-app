import 'package:flutter/material.dart';

import '../../models/drawing_layer.dart';
import '../../painting/drawing_painting.dart';

/// Uma imagem com o desenho do Pincel por cima, ocupando a caixa inteira —
/// o lugar de um `Image.file(fit: BoxFit.fill)` quando há desenho.
///
/// Pinta com [paintDrawnImage], a mesma função da exportação: é o que deixa
/// a transparência abrir buracos só na imagem (um `Stack` com os traços por
/// cima não conseguiria furar o que está embaixo sem furar também o fundo
/// da tela).
///
/// Lê a imagem pelo mesmo [ImageStream] de um `Image` comum — mesmo cache e,
/// numa foto animada, os quadros chegando um a um.
class DrawnImage extends StatefulWidget {
  const DrawnImage({super.key, required this.image, required this.layer});

  final ImageProvider image;
  final DrawingLayer layer;

  @override
  State<DrawnImage> createState() => _DrawnImageState();
}

class _DrawnImageState extends State<DrawnImage> {
  ImageStream? _stream;
  ImageInfo? _info;
  late final _listener = ImageStreamListener(_onImage);

  void _onImage(ImageInfo info, bool synchronousCall) {
    // O quadro recebido é de quem escuta: o anterior tem que ser liberado.
    setState(() {
      _info?.dispose();
      _info = info;
    });
  }

  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(DrawnImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _resolve();
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info == null) return const SizedBox.expand();
    return SizedBox.expand(
      child: CustomPaint(
        painter: DrawnImagePainter(image: info.image, layer: widget.layer),
      ),
    );
  }
}

/// Os traços do Pincel por cima de [child] — o desenho de um SVG, que é
/// vetor e não tem pixels para furar (lá não existe a transparência).
class DrawingOverlay extends StatelessWidget {
  const DrawingOverlay({super.key, required this.layer, required this.child});

  final DrawingLayer layer;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (layer.isEmpty) return child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: DrawingStrokesPainter(layer)),
          ),
        ),
      ],
    );
  }
}
