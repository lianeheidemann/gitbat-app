import '../../app/language_controller.dart';
import 'package:flutter/material.dart';

/// Título de pop-up com um X no canto de cima à direita para fechar — no
/// lugar do botão "Cancelar" (preferência da dona do app). Fechar pelo X é o
/// mesmo que cancelar: o diálogo devolve `null`.
class DialogTitle extends StatelessWidget {
  const DialogTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(text)),
        const SizedBox(width: 8),
        // Encostado no canto, sem aumentar a altura do título.
        Transform.translate(
          offset: const Offset(10, -10),
          child: IconButton(
            key: const ValueKey('dialogCloseButton'),
            tooltip: tr('Fechar', 'Close'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    );
  }
}
