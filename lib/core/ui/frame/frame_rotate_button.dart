import 'package:flutter/material.dart';

/// Botão "90°" da aba "Moldura": gira a moldura de imagem **junto com o
/// conteúdo** um quarto de volta no sentido horário — o mockup inteiro
/// deita, com a foto/vídeo dentro. É o oposto da aba "Girar", que com uma
/// moldura de imagem ativa deixa a moldura parada e gira só o conteúdo
/// (ver `FrameSettings.frameQuarterTurns`).
class FrameRotateButton extends StatelessWidget {
  const FrameRotateButton({super.key, required this.onRotate});

  final VoidCallback onRotate;

  /// Só o botão, sem texto de apoio: o ícone de girar com "90°" já diz o
  /// que ele faz, e o giro atual aparece no resumo da aba.
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        key: const ValueKey('frameRotateButton'),
        onPressed: onRotate,
        icon: const Icon(Icons.rotate_right_rounded),
        label: const Text('90°'),
      ),
    );
  }
}
