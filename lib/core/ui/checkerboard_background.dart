import 'package:flutter/material.dart';

import '../../app/preview_background_controller.dart';

/// Fundo quadriculado clássico de "transparência" (o mesmo indicador visual
/// de editores de imagem como Photoshop/GIMP) — cinzas neutros, escuros no
/// tema escuro e claros no claro.
class CheckerboardBackground extends StatelessWidget {
  const CheckerboardBackground({super.key, this.cellSize = 6});

  final double cellSize;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CheckerboardPainter(
        cellSize: cellSize,
        dark: Theme.of(context).brightness == Brightness.dark,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter({required this.cellSize, required this.dark});

  final double cellSize;
  final bool dark;

  // Tons escuros no tema escuro (o xadrez claro brigava com a interface
  // e chamava mais atenção que a foto) e claros no tema claro.
  static const _darkThemeColors = (Color(0xFF4A4A4F), Color(0xFF323236));
  static const _lightThemeColors = (Color(0xFFFFFFFF), Color(0xFFDCDCE1));

  @override
  void paint(Canvas canvas, Size size) {
    // A última linha/coluna de quadradinhos quase nunca fecha certinho no
    // tamanho da área (o `ceil` abaixo arredonda para cima), e o
    // `CustomPaint` não recorta sozinho: sem isto o xadrez vazava até uma
    // casa inteira para fora, por cima da tira da alça do rodapé recolhido.
    canvas.clipRect(Offset.zero & size);
    final (light, darker) = dark ? _darkThemeColors : _lightThemeColors;
    canvas.drawRect(Offset.zero & size, Paint()..color = light);

    final darkPaint = Paint()..color = darker;
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
      oldDelegate.cellSize != cellSize || oldDelegate.dark != dark;
}

/// Cor sólida da área de prévia em volta da mídia — nas quatro telas de
/// edição, a região que não é da foto/vídeo/SVG/montagem nunca é xadrez.
/// Escura no tema escuro, clara no claro.
const previewAreaColor = Color(0xFF26272B);
const previewAreaColorLight = Color(0xFFE9E8EE);

/// [previewAreaColor] ou [previewAreaColorLight], conforme o tema.
Color previewAreaColorFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? previewAreaColor
    : previewAreaColorLight;

/// Fundo da área de prévia inteira: sempre a cor sólida [previewAreaColor].
/// O xadrez (quando ligado nas configurações) fica só atrás da própria
/// mídia — ver [MediaCheckerboard].
class PreviewAreaBackground extends StatelessWidget {
  const PreviewAreaBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: previewAreaColorFor(context), child: child);
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
