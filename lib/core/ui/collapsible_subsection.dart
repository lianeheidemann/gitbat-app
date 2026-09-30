import 'package:flutter/material.dart';

/// Cabeçalho recolhível de uma subseção dentro de um card ("Ajuste do
/// conteúdo" na aba "Moldura", "Suavização de cor" e "Paleta" em "Qualidade
/// das cores"): tocar no rótulo mostra ou esconde [child]. O [subtitle]
/// mostra a opção escolhida mesmo com a subseção fechada.
///
/// Quem guarda [expanded] é a tela, para o estado sobreviver à troca de abas.
class CollapsibleSubsection extends StatelessWidget {
  const CollapsibleSubsection({
    super.key,
    required this.label,
    this.subtitle,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final String label;
  final String? subtitle;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.bodySmall),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[const SizedBox(height: 8), child],
      ],
    );
  }
}
