import 'package:flutter/material.dart';

/// Botão "90°" da aba "Moldura": gira a moldura de imagem **junto com o
/// conteúdo** um quarto de volta no sentido horário — o mockup inteiro
/// deita, com a foto/vídeo dentro. É o oposto da aba "Girar", que com uma
/// moldura de imagem ativa deixa a moldura parada e gira só o conteúdo
/// (ver `FrameSettings.frameQuarterTurns`).
class FrameRotateButton extends StatelessWidget {
  const FrameRotateButton({
    super.key,
    required this.quarterTurns,
    required this.onRotate,
  });

  /// Giro atual da moldura, de 0 a 3 — só para o texto de apoio.
  final int quarterTurns;
  final VoidCallback onRotate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            quarterTurns == 0
                ? 'Girar a moldura com o conteúdo'
                : 'Moldura girada ${quarterTurns * 90}°',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          key: const ValueKey('frameRotateButton'),
          onPressed: onRotate,
          icon: const Icon(Icons.rotate_right_rounded),
          label: const Text('90°'),
        ),
      ],
    );
  }
}
