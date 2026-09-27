import 'package:flutter/material.dart';

import '../core/models/default_colors.dart';

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
    required this.contentBackground,
    required this.contentFrame,
    required this.contentText,
    this.darkTertiary,
    this.refineLight,
    this.refineDark,
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

  /// Cores que já vêm escolhidas nas telas de edição (ver
  /// `lib/app/editor_defaults.dart`): o fundo e a moldura/borda que aparecem
  /// ao ligar essas opções, e a cor do texto novo. Seguem a paleta para o
  /// que você cria já sair combinando com o app.
  final Color contentBackground;
  final Color contentFrame;
  final Color contentText;

  /// Ajuste fino do esquema já gerado, para paletas com cores definidas uma
  /// a uma (em vez de só derivadas de [seed]).
  final ColorScheme Function(ColorScheme)? refineLight;
  final ColorScheme Function(ColorScheme)? refineDark;
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
  contentBackground: Color(0xFFC9A8FF),
  contentFrame: Color(0xFF8370B0),
  contentText: Color(0xFF544181),
);

// Cores tiradas das artes do morceguinho em `assets/icon/icon-v2`.
const _batNight = Color(0xFF111929); // fundo do ícone
const _batBody = Color(0xFF5A9EF6); // corpo
const _batCyan = Color(0xFF22D8EE); // fone de ouvido
const _batNavy = Color(0xFF0C48A8); // contorno do mascote
const _batDeepNavy = Color(0xFF061C4B); // contorno mais escuro
const _batIce = Color(0xFFB0DCFC); // corpo do mascote
const _batLavender = Color(0xFFA9BEF7); // dentro da orelha

ColorScheme _batLight(ColorScheme base) => base.copyWith(
  primary: _batNavy,
  onPrimary: Colors.white,
  primaryContainer: const Color(0xFFD6E9FE),
  onPrimaryContainer: _batDeepNavy,
  secondary: const Color(0xFF00788A),
  onSecondary: Colors.white,
  secondaryContainer: const Color(0xFFC6F4FA),
  onSecondaryContainer: const Color(0xFF002E35),
  tertiary: const Color(0xFF4E5DAF),
  onTertiary: Colors.white,
  tertiaryContainer: const Color(0xFFE0E5FF),
  onTertiaryContainer: const Color(0xFF141F5A),
  surface: const Color(0xFFF6F9FE),
  onSurface: const Color(0xFF0F1A2E),
  onSurfaceVariant: const Color(0xFF44516A),
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: const Color(0xFFEEF4FD),
  surfaceContainer: const Color(0xFFE8F0FC),
  surfaceContainerHigh: const Color(0xFFE1EAF9),
  surfaceContainerHighest: const Color(0xFFD9E4F6),
  outline: const Color(0xFF74829C),
  outlineVariant: const Color(0xFFC3CEE0),
  inversePrimary: _batBody,
  surfaceTint: _batNavy,
);

ColorScheme _batDark(ColorScheme base) => base.copyWith(
  primary: _batBody,
  onPrimary: _batDeepNavy,
  primaryContainer: _batNavy,
  onPrimaryContainer: _batIce,
  secondary: _batCyan,
  onSecondary: const Color(0xFF00363D),
  secondaryContainer: const Color(0xFF0B4F5C),
  onSecondaryContainer: const Color(0xFFBDF4FB),
  tertiary: _batLavender,
  onTertiary: const Color(0xFF1B2A5E),
  tertiaryContainer: const Color(0xFF34407A),
  onTertiaryContainer: const Color(0xFFE0E5FF),
  onSurface: const Color(0xFFE3EAF7),
  onSurfaceVariant: const Color(0xFFAEBBD3),
  surfaceContainerLowest: const Color(0xFF0B1220),
  outline: const Color(0xFF5E7196),
  outlineVariant: const Color(0xFF2E3D5C),
  inversePrimary: _batNavy,
  surfaceTint: _batBody,
);

/// Paleta oficial do app, a do morceguinho: azul do corpo como cor
/// principal, ciano do fone como secundária, lavanda da orelha como
/// terciária e o azul-noite do ícone como fundo no tema escuro. Tem todas
/// as cores definidas à mão, nos dois temas.
const batPalette = AppPalette(
  id: 'morceguinho',
  label: 'Morceguinho',
  seed: _batBody,
  darkBackground: _batNight,
  darkCard: Color(0xFF172238),
  darkContainerHigh: Color(0xFF1D2A43),
  darkContainerHighest: Color(0xFF24324E),
  darkChipSelected: _batNavy,
  darkTertiary: _batLavender,
  accentGradient: [_batBody, _batCyan],
  onAccent: _batDeepNavy,
  contentBackground: defaultBackgroundColor,
  contentFrame: defaultFrameColor,
  contentText: defaultTextColor,
  refineLight: _batLight,
  refineDark: _batDark,
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
  contentBackground: Color(0xFFB8EBD3),
  contentFrame: Color(0xFF2F8A66),
  contentText: Color(0xFF13402F),
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
  contentBackground: Color(0xFFFFD3BA),
  contentFrame: Color(0xFFC0673D),
  contentText: Color(0xFF5A2A14),
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
  contentBackground: Color(0xFFF9C6E0),
  contentFrame: Color(0xFFB24E86),
  contentText: Color(0xFF5B1D42),
);

/// Todas as paletas, na ordem em que aparecem nas configurações. A primeira
/// (a oficial, do morceguinho) é a padrão.
const appPalettes = [
  batPalette,
  lavenderPalette,
  mintPalette,
  peachPalette,
  rosePalette,
];

/// A paleta com [id], ou a padrão se não houver (ex.: preferência antiga).
AppPalette paletteById(String? id) =>
    appPalettes.firstWhere((p) => p.id == id, orElse: () => appPalettes.first);
