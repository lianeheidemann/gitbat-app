import '../../../app/language_controller.dart';
import 'package:flutter/material.dart';

/// Folha "Como deixar o GIF mais leve": o que pesa num GIF e o que mexer
/// para reduzir. Mora na home (junto do ícone de interrogação), e não na
/// tela de edição, para a barra de lá ficar só com o que age sobre o GIF.
class GifWeightHelpSheet extends StatelessWidget {
  const GifWeightHelpSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget item(String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('O que deixa um GIF pesado', 'What makes a GIF heavy'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            item(
              tr('1. Duração — efeito direto', '1. Duration — direct effect'),
              tr(
                'Cada segundo adiciona novos quadros. Cortar um trecho é uma das formas mais eficientes de reduzir o tamanho.',
                'Every second adds new frames. Trimming is one of the most effective ways to reduce the size.',
              ),
            ),
            item(
              tr(
                '2. Resolução — efeito muito forte',
                '2. Resolution — very strong effect',
              ),
              tr(
                'Quanto maior a área de cada quadro, maior tende a ser o GIF. 480 px costuma funcionar bem para compartilhamento.',
                'The bigger each frame, the bigger the GIF tends to be. 480 px usually works well for sharing.',
              ),
            ),
            item(
              tr(
                '3. FPS — fluidez versus tamanho',
                '3. FPS — smoothness versus size',
              ),
              tr(
                'Mais quadros deixam o movimento mais suave, mas aumentam o arquivo. 12 FPS é um bom ponto de partida.',
                'More frames make motion smoother but grow the file. 12 FPS is a good starting point.',
              ),
            ),
            item(
              tr('4. Janela de recorte', '4. Crop window'),
              tr(
                'Segure as bolinhas dos cantos da moldura na própria prévia para redimensionar. Formatos fixos preservam a proporção; Personalizado libera largura e altura.',
                'Drag the corner handles in the preview to resize. Fixed shapes keep the aspect ratio; Custom frees width and height.',
              ),
            ),
            item(
              tr('5. Cores e suavização', '5. Colors and smoothing'),
              tr(
                'Mais cores e dither preservam gradientes e detalhes, mas podem reduzir a eficiência da compressão.',
                'More colors and dithering keep gradients and detail but can make compression less efficient.',
              ),
            ),
            item(
              tr('Por que medir novamente?', 'Why measure again?'),
              tr(
                'A estimativa inicial é aproximada. Ao medir, o app usa o FFmpeg em uma pequena amostra do próprio vídeo para calibrar o cálculo.',
                'The first estimate is approximate. When measuring, the app runs FFmpeg on a short sample of the video to calibrate the calculation.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Abre a folha — mesmo formato dos outros sheets do app.
void showGifWeightHelpSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const GifWeightHelpSheet(),
  );
}
