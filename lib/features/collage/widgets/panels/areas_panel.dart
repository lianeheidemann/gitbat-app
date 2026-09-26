import 'package:flutter/material.dart';

import '../../models/collage_layout.dart';

/// Painel da aba "Áreas": com ela aberta, a prévia mostra as alças entre as
/// fotos (ver [CollageDividerHandle]) para arrastar e mudar o tamanho de cada
/// área. Aqui fica só a explicação e o botão de voltar ao padrão.
class CollageAreasPanel extends StatelessWidget {
  const CollageAreasPanel({
    super.key,
    required this.layout,
    required this.onReset,
  });

  final CollageLayout layout;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Toque numa foto para mostrar as alças dela e arraste para mudar o '
          'tamanho. Arrastar dentro da foto move a imagem. Trocar o layout ou '
          'o número de fotos volta tudo ao tamanho padrão.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: layout.hasCustomSizes ? onReset : null,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Tamanhos iguais'),
          ),
        ),
      ],
    );
  }
}

/// Alça de um divisor na borda da foto selecionada da aba "Áreas": uma
/// pílula branca pequena com setas para os dois lados em que ela arrasta
/// (esquerda/direita num divisor vertical, cima/baixo num horizontal). A área
/// de toque ([touchLong] × [touchShort]) é maior que o desenho, para caber o
/// dedo sem a alça cobrir a foto.
class CollageDividerHandle extends StatelessWidget {
  const CollageDividerHandle({
    super.key,
    required this.divider,
    required this.onDragStart,
    required this.onDrag,
    required this.onDragEnd,
  });

  final CollageDivider divider;
  final VoidCallback onDragStart;

  /// Deslocamento no eixo do divisor (x num vertical, y num horizontal).
  final ValueChanged<double> onDrag;
  final VoidCallback onDragEnd;

  static const touchLong = 48.0;
  static const touchShort = 36.0;
  static const _long = 30.0;
  static const _short = 18.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vertical = divider.vertical;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => onDragStart(),
      onPanUpdate: (details) =>
          onDrag(vertical ? details.delta.dx : details.delta.dy),
      onPanEnd: (_) => onDragEnd(),
      onPanCancel: onDragEnd,
      child: Center(
        child: Container(
          width: vertical ? _short : _long,
          height: vertical ? _long : _short,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_short / 2),
            boxShadow: const [
              BoxShadow(color: Color(0x55000000), blurRadius: 4),
            ],
          ),
          child: Icon(
            vertical ? Icons.swap_horiz_rounded : Icons.swap_vert_rounded,
            size: 14,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
