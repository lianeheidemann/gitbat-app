import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Contorno em forma de pasta: retângulo arredondado com uma abinha no canto
/// superior esquerdo, como o ícone de pasta de um gerenciador de arquivos.
/// Escrito como [ShapeBorder] (e não como um `CustomPainter` solto) para o
/// preenchimento, o contorno e o respingo de toque seguirem exatamente o
/// mesmo caminho — é o que `ShapeDecoration`/`Material.shape` esperam.
class FolderTabShape extends ShapeBorder {
  const FolderTabShape({
    this.radius = 10,
    this.tabHeight = 8,
    this.tabWidthRatio = 0.42,
    this.side = BorderSide.none,
  });

  /// Arredondamento dos cantos do corpo e da ponta da abinha.
  final double radius;

  /// Altura da abinha, medida acima do corpo da pasta.
  final double tabHeight;

  /// Largura da abinha como fração da largura total — uma fração (e não uma
  /// medida fixa) mantém a proporção da pasta em rótulos curtos ("Efeitos")
  /// e longos ("Importados") sem a abinha parecer sobrando ou espremida.
  final double tabWidthRatio;

  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(top: tabHeight);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    // Contorno desenhado de uma vez só (abinha + corpo), sem unir duas
    // formas com `Path.combine`: no celular (Impeller) essa união saía vazia
    // em pastas de rótulo curto ("Black", nomes curtos), e a pasta inteira
    // sumia da barra.
    final bodyTop = rect.top + tabHeight;
    final r = radius
        .clamp(0.0, math.min(rect.width / 2, (rect.bottom - bodyTop) / 2))
        .toDouble();
    final tabR = math.min(r, tabHeight);
    final tabWidth = (rect.width * tabWidthRatio).clamp(
      radius * 4,
      rect.width * 0.7,
    );
    final tabRight = rect.left + tabWidth;
    return Path()
      ..moveTo(rect.left, rect.top + tabR)
      ..arcToPoint(
        Offset(rect.left + tabR, rect.top),
        radius: Radius.circular(tabR),
      )
      ..lineTo(tabRight - tabR, rect.top)
      ..arcToPoint(
        Offset(tabRight, rect.top + tabR),
        radius: Radius.circular(tabR),
      )
      ..lineTo(tabRight, bodyTop)
      ..lineTo(rect.right - r, bodyTop)
      ..arcToPoint(Offset(rect.right, bodyTop + r), radius: Radius.circular(r))
      ..lineTo(rect.right, rect.bottom - r)
      ..arcToPoint(
        Offset(rect.right - r, rect.bottom),
        radius: Radius.circular(r),
      )
      ..lineTo(rect.left + r, rect.bottom)
      ..arcToPoint(
        Offset(rect.left, rect.bottom - r),
        radius: Radius.circular(r),
      )
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width <= 0) return;
    canvas.drawPath(
      getOuterPath(rect, textDirection: textDirection),
      side.toPaint(),
    );
  }

  @override
  ShapeBorder scale(double t) => FolderTabShape(
    radius: radius * t,
    tabHeight: tabHeight * t,
    tabWidthRatio: tabWidthRatio,
    side: side.scale(t),
  );
}

/// Uma pasta da barra da aba "Stickers" — as embutidas, as criadas pelo
/// usuário e o botão de criar uma nova (esse com [icon] no lugar do rótulo).
/// Selecionada fica preenchida de roxo; solta, só com o contorno.
class FolderTab extends StatelessWidget {
  const FolderTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Segurar abre o menu de renomear/apagar — só as pastas criadas pelo
  /// usuário passam algo aqui.
  final VoidCallback? onLongPress;

  /// Quando presente, aparece antes do rótulo (usado pelo botão de criar
  /// pasta, que mostra o ícone e o texto "Nova pasta").
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;
    // Rede de segurança para uma pasta antiga persistida com nome vazio —
    // `StickerFolderStore.create` já não deixa isso acontecer de novo, mas
    // sem isto uma entrada assim continuaria aparecendo como um vão sem
    // texto para sempre.
    final displayLabel = label.trim().isEmpty ? 'Pasta sem nome' : label;
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHigh,
      shape: FolderTabShape(
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          // O respiro de cima soma a altura da abinha (a `FolderTabShape`
          // reserva ela em `dimensions`), para o rótulo ficar centralizado no
          // corpo da pasta e não colado na aba.
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: foreground),
                const SizedBox(width: 5),
              ],
              Text(
                displayLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
