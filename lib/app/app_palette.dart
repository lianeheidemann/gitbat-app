import 'package:flutter/material.dart';

/// Paleta de cores da interface, escolhida na aba "Configurações" das telas
/// de edição. Cada paleta vale para os dois temas: no claro, o esquema sai
/// inteiro de [seed] (Material 3); no escuro, [seed] vira a cor primária e as
/// superfícies usam os tons neutros definidos à mão aqui, levemente puxados
/// para a cor da paleta.
class AppPalette {
  const AppPalette({
    required this.id,
    required this.label,
    required this.seed,
    required this.darkBackground,
    required this.darkCard,
    required this.darkContainerHigh,
    required this.darkContainerHighest,
    required this.darkChipSelected,
    required this.accentGradient,
    required this.onAccent,
    this.darkTertiary,
  });

  /// Identificador salvo nas preferências — não mudar depois de publicado.
  final String id;
  final String label;
  final Color seed;
  final Color darkBackground;
  final Color darkCard;
  final Color darkContainerHigh;
  final Color darkContainerHighest;

  /// Fundo dos chips selecionados no tema escuro.
  final Color darkChipSelected;

  /// Cor de destaque extra no escuro (ex.: o ciano do fone do morceguinho).
  final Color? darkTertiary;

  /// Degradê do botão principal da tela de resultado e a cor do texto dele.
  final List<Color> accentGradient;
  final Color onAccent;
}

const lavenderPalette = AppPalette(
  id: 'lavanda',
  label: 'Lavanda',
  seed: Color(0xFFC9A8FF),
  darkBackground: Color(0xFF101014),
  darkCard: Color(0xFF1A191F),
  darkContainerHigh: Color(0xFF211F28),
  darkContainerHighest: Color(0xFF26232D),
  darkChipSelected: Color(0xFF5D4D72),
  accentGradient: [Color(0xFFD3B4FF), Color(0xFFBC8FFF)],
  onAccent: Color(0xFF25172E),
);

/// Combina com o ícone do morceguinho: azul do corpo, ciano do fone e o
/// fundo azul-marinho.
const batPalette = AppPalette(
  id: 'morceguinho',
  label: 'Morceguinho',
  seed: Color(0xFF64A2F6),
  darkBackground: Color(0xFF0C1322),
  darkCard: Color(0xFF131C2F),
  darkContainerHigh: Color(0xFF1A2439),
  darkContainerHighest: Color(0xFF1F2B43),
  darkChipSelected: Color(0xFF294677),
  darkTertiary: Color(0xFF2FD4F0),
  accentGradient: [Color(0xFF8CBCFA), Color(0xFF5B9AF2)],
  onAccent: Color(0xFF0B1A38),
);

const mintPalette = AppPalette(
  id: 'menta',
  label: 'Menta',
  seed: Color(0xFF7FD6B0),
  darkBackground: Color(0xFF0E1311),
  darkCard: Color(0xFF171D1A),
  darkContainerHigh: Color(0xFF1D2521),
  darkContainerHighest: Color(0xFF232C28),
  darkChipSelected: Color(0xFF3C5E50),
  accentGradient: [Color(0xFF9DE3C4), Color(0xFF6BCBA1)],
  onAccent: Color(0xFF0F2A1E),
);

const peachPalette = AppPalette(
  id: 'pessego',
  label: 'Pêssego',
  seed: Color(0xFFFFB38A),
  darkBackground: Color(0xFF141010),
  darkCard: Color(0xFF1E1817),
  darkContainerHigh: Color(0xFF271F1D),
  darkContainerHighest: Color(0xFF2D2522),
  darkChipSelected: Color(0xFF6E4A3C),
  accentGradient: [Color(0xFFFFC7A8), Color(0xFFFFA273)],
  onAccent: Color(0xFF331A0D),
);

const rosePalette = AppPalette(
  id: 'rosa',
  label: 'Rosa',
  seed: Color(0xFFF7A8D0),
  darkBackground: Color(0xFF141013),
  darkCard: Color(0xFF1F181D),
  darkContainerHigh: Color(0xFF281F26),
  darkContainerHighest: Color(0xFF2E242B),
  darkChipSelected: Color(0xFF6B4460),
  accentGradient: [Color(0xFFFBC1DE), Color(0xFFF291C2)],
  onAccent: Color(0xFF331026),
);

/// Todas as paletas, na ordem em que aparecem nas configurações. A primeira
/// é a padrão.
const appPalettes = [
  lavenderPalette,
  batPalette,
  mintPalette,
  peachPalette,
  rosePalette,
];

/// A paleta com [id], ou a padrão se não houver (ex.: preferência antiga).
AppPalette paletteById(String? id) =>
    appPalettes.firstWhere((p) => p.id == id, orElse: () => appPalettes.first);
