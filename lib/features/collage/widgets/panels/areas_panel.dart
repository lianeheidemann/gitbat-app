import 'package:flutter/material.dart';

import '../../models/collage_layout.dart';

/// Painel da aba "Áreas". Sem foto selecionada, só a explicação e
/// "Tamanhos iguais". Com uma foto tocada na prévia, o cartão "Área
/// selecionada": largura e altura dela em % (da largura disponível e da
/// altura da coluna dela), "Bloquear proporção" (os dois mudam juntos,
/// mantendo o formato da área), "Redefinir área" e "Tamanhos iguais".
class CollageAreasPanel extends StatelessWidget {
  const CollageAreasPanel({
    super.key,
    required this.layout,
    required this.selectedCell,
    required this.lockAspect,
    required this.onLockAspectChanged,
    required this.onChangeStart,
    required this.onWidthChanged,
    required this.onHeightChanged,
    required this.onResetArea,
    required this.onReset,
  });

  final CollageLayout layout;

  /// Foto selecionada na prévia, ou `null`.
  final int? selectedCell;
  final bool lockAspect;
  final ValueChanged<bool> onLockAspectChanged;

  /// Começo de um arraste de slider — ponto de desfazer.
  final VoidCallback onChangeStart;

  /// Nova largura/altura, como fração (0 a 1).
  final ValueChanged<double> onWidthChanged;
  final ValueChanged<double> onHeightChanged;
  final VoidCallback onResetArea;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cell = selectedCell;
    final resetAll = OutlinedButton.icon(
      onPressed: layout.hasCustomSizes ? onReset : null,
      icon: const Icon(Icons.filter_none_rounded, size: 16),
      label: const Text('Tamanhos iguais'),
    );
    if (cell == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Toque numa foto para ajustar a área dela: arraste as alças nas '
            'laterais ou use os controles que aparecem aqui. Arrastar dentro '
            'da foto move a imagem. Trocar o layout ou o número de fotos '
            'volta tudo ao tamanho padrão.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: resetAll),
        ],
      );
    }

    final (wLo, wHi) = layout.widthFractionRange;
    final (hLo, hHi) = layout.heightFractionRange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Área selecionada',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            children: [
              _AreaSliderRow(
                sliderKey: const ValueKey('areaWidthSlider'),
                icon: Icons.swap_horiz_rounded,
                label: 'Largura',
                value: layout.widthFractionOf(cell),
                min: wLo,
                max: wHi,
                onChangeStart: onChangeStart,
                onChanged: onWidthChanged,
              ),
              _AreaSliderRow(
                sliderKey: const ValueKey('areaHeightSlider'),
                icon: Icons.swap_vert_rounded,
                label: 'Altura',
                value: layout.heightFractionOf(cell),
                min: hLo,
                max: hHi,
                onChangeStart: onChangeStart,
                onChanged: onHeightChanged,
              ),
              Divider(
                height: 9,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 32,
                      child: Icon(Icons.lock_outline_rounded, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bloquear proporção',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Switch(
                      key: const ValueKey('areaLockAspectSwitch'),
                      value: lockAspect,
                      onChanged: onLockAspectChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onResetArea,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Redefinir área'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: resetAll),
          ],
        ),
      ],
    );
  }
}

/// Linha "Largura"/"Altura" do cartão "Área selecionada": ícone à esquerda,
/// rótulo com o slider embaixo e o valor em % à direita.
class _AreaSliderRow extends StatelessWidget {
  const _AreaSliderRow({
    required this.sliderKey,
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChangeStart,
    required this.onChanged,
  });

  final Key sliderKey;
  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final VoidCallback onChangeStart;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fixed = max <= min;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(label, style: theme.textTheme.bodySmall),
                ),
                SizedBox(
                  height: 28,
                  child: Slider(
                    key: sliderKey,
                    value: value.clamp(min, fixed ? min + 0.0001 : max),
                    min: min,
                    max: fixed ? min + 0.0001 : max,
                    onChangeStart: fixed ? null : (_) => onChangeStart(),
                    onChanged: fixed ? null : onChanged,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '${(value * 100).round()}%',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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
