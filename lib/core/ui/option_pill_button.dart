import 'package:flutter/material.dart';

/// Botão de escolha dos painéis da Borracha mágica e do Pincel —
/// ferramentas e qualidade.
///
/// Substitui o [ChoiceChip]: o chip do Material 3 fixa altura, padding e
/// fonte pelo tema, e o painel precisa das proporções do mockup (botões de
/// 34dp, cantos de 10dp, rótulo de 13sp). O rótulo nunca vira reticências:
/// numa célula estreita o conteúdo inteiro encolhe até caber.
class OptionPillButton extends StatelessWidget {
  const OptionPillButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.icon,
    this.iconBuilder,
    this.showCheck = false,
    this.expand = false,
  });

  final String label;
  final bool selected;

  /// `null` desabilita o botão (durante uma apagada, por exemplo).
  final VoidCallback? onPressed;

  /// Ícone à esquerda do rótulo, usado pelas ferramentas.
  final IconData? icon;

  /// Ícone desenhado (em vez de [icon]), que recebe a cor e o tamanho do
  /// estado atual — para os que não existem no pacote de ícones, como a
  /// borracha do Pincel.
  final Widget Function(Color color, double size)? iconBuilder;

  /// Mostra um ✓ à esquerda quando selecionado, como na linha de qualidade.
  final bool showCheck;

  /// Centraliza o conteúdo e ocupa a largura toda — para os botões de
  /// qualidade, que dividem a linha em partes iguais.
  final bool expand;

  static const double height = 34;
  static const double radius = 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Como no mockup: o escolhido em destaque, os outros em cinza-claro.
    final foreground = selected
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    final check = showCheck && selected;
    final leading = check ? Icons.check_rounded : icon;
    final builder = check ? null : iconBuilder;
    // Com ✓ o escolhido é só cheio; nas ferramentas ganha também a borda.
    final BorderSide border;
    if (selected) {
      border = showCheck
          ? BorderSide.none
          : BorderSide(color: scheme.primary, width: 1.5);
    } else {
      border = BorderSide(color: scheme.outlineVariant);
    }
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: border,
    );

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (builder != null) ...[
          builder(foreground, 16),
          SizedBox(width: expand ? 4 : 6),
        ] else if (leading != null) ...[
          Icon(leading, size: 16, color: foreground),
          SizedBox(width: expand ? 4 : 6),
        ],
        Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            color: foreground,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
    final content = expand
        ? Center(
            child: FittedBox(fit: BoxFit.scaleDown, child: row),
          )
        : row;

    return Semantics(
      button: true,
      selected: selected,
      child: Opacity(
        opacity: onPressed == null ? 0.38 : 1,
        child: Material(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLowest,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              height: height,
              child: Padding(
                // Os de qualidade dividem a linha em três: margem menor para
                // "✓ Normal" caber inteiro.
                padding: EdgeInsets.symmetric(horizontal: expand ? 4 : 12),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
