import 'package:flutter/material.dart';

import '../../app/preview_background_controller.dart';

/// Fundo quadriculado clássico de "transparência" (o mesmo indicador visual
/// de editores de imagem como Photoshop/GIMP) — cores neutras fixas,
/// independentes do tema claro/escuro, para representar sempre a mesma
/// coisa não importa o tema do app.
class CheckerboardBackground extends StatelessWidget {
  const CheckerboardBackground({super.key, this.cellSize = 6});

  final double cellSize;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CheckerboardPainter(cellSize: cellSize),
      child: const SizedBox.expand(),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter({required this.cellSize});

  final double cellSize;

  // Tons escuros: o xadrez claro de antes brigava com a interface escura e
  // chamava mais atenção do que a própria foto.
  static const _light = Color(0xFF4A4A4F);
  static const _dark = Color(0xFF323236);

  @override
  void paint(Canvas canvas, Size size) {
    // A última linha/coluna de quadradinhos quase nunca fecha certinho no
    // tamanho da área (o `ceil` abaixo arredonda para cima), e o
    // `CustomPaint` não recorta sozinho: sem isto o xadrez vazava até uma
    // casa inteira para fora, por cima da tira da alça do rodapé recolhido.
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = _light);

    final darkPaint = Paint()..color = _dark;
    final cols = (size.width / cellSize).ceil();
    final rows = (size.height / cellSize).ceil();
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        if ((row + col).isOdd) {
          canvas.drawRect(
            Rect.fromLTWH(col * cellSize, row * cellSize, cellSize, cellSize),
            darkPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerboardPainter oldDelegate) =>
      oldDelegate.cellSize != cellSize;
}

/// Cor sólida da área de prévia em volta da mídia — nas quatro telas de
/// edição, a região que não é da foto/vídeo/SVG/montagem nunca é xadrez.
const previewAreaColor = Color(0xFF26272B);

/// Fundo da área de prévia inteira: sempre a cor sólida [previewAreaColor].
/// O xadrez (quando ligado nas configurações) fica só atrás da própria
/// mídia — ver [MediaCheckerboard].
class PreviewAreaBackground extends StatelessWidget {
  const PreviewAreaBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: previewAreaColor, child: child);
  }
}

/// Xadrez de transparência só atrás de [child] (a prévia da foto, do vídeo,
/// do SVG ou da montagem), do tamanho exato dele — quando a preferência
/// global [previewCheckerboardNotifier] está ligada. Fica por fora do
/// `RepaintBoundary` do conta-gotas nas telas que o têm, para o xadrez não
/// entrar na cor amostrada.
class MediaCheckerboard extends StatelessWidget {
  const MediaCheckerboard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: previewCheckerboardNotifier,
      builder: (context, enabled, _) => enabled
          ? Stack(
              children: [
                const Positioned.fill(child: CheckerboardBackground()),
                child,
              ],
            )
          : child,
    );
  }
}
