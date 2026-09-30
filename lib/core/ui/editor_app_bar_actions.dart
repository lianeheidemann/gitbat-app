import '../../app/language_controller.dart';
import 'package:flutter/material.dart';

/// Desfazer e refazer, os dois primeiros botões da barra de cima em todas as
/// telas de edição — apagados quando não há o que desfazer/refazer.
List<Widget> undoRedoActions({
  required bool canUndo,
  required bool canRedo,
  required VoidCallback onUndo,
  required VoidCallback onRedo,
}) => [
  IconButton(
    tooltip: tr('Desfazer', 'Undo'),
    onPressed: canUndo ? onUndo : null,
    icon: const Icon(Icons.undo_rounded),
  ),
  IconButton(
    tooltip: tr('Refazer', 'Redo'),
    onPressed: canRedo ? onRedo : null,
    icon: const Icon(Icons.redo_rounded),
  ),
];

/// Botão da barra de cima que, enquanto a ação dele roda (salvar,
/// compartilhar), troca o ícone por um indicador de progresso e a dica por
/// [busyTooltip].
class BusyIconButton extends StatelessWidget {
  const BusyIconButton({
    super.key,
    required this.busy,
    required this.tooltip,
    required this.busyTooltip,
    required this.icon,
    required this.onPressed,
  });

  final bool busy;
  final String tooltip;
  final String busyTooltip;
  final Widget icon;

  /// `null` apaga o botão — por exemplo, com outra ação em andamento.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: busy ? busyTooltip : tooltip,
      onPressed: onPressed,
      icon: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : icon,
    );
  }
}
