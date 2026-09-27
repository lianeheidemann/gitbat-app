import 'package:flutter/material.dart';

/// Aviso de "salvo" das telas de edição (Editar imagem, Editar SVG,
/// Montagem e Converter formato): um pop-up com ✓, a [message] e um botão
/// OK — mais difícil de perder que um aviso passageiro no rodapé. O fluxo
/// "Escolher vídeo" não usa: a tela de resultado dele já mostra tudo.
Future<void> showSavedDialog(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('savedDialog'),
      icon: Icon(
        Icons.check_circle_rounded,
        color: Theme.of(dialogContext).colorScheme.primary,
      ),
      title: const Text('Salvo!'),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          style: FilledButton.styleFrom(minimumSize: const Size(120, 40)),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
