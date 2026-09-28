import 'translations.dart';
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
    required this._label,
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
  final String _label;

  /// Nome da paleta no idioma atual.
  String get label => trKey(_label);
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

ColorScheme _refinePaletteLight(
  ColorScheme base, {
  required Color primary,
  required Color primaryContainer,
  required Color onPrimaryContainer,
  required Color secondary,
  required Color secondaryContainer,
  required Color tertiary,
  required Color tertiaryContainer,
  required Color surface,
  required Color surfaceLow,
  required Color surfaceHigh,
  required Color outline,
}) => base.copyWith(
  primary: primary,
  onPrimary: Colors.white,
  primaryContainer: primaryContainer,
  onPrimaryContainer: onPrimaryContainer,
  secondary: secondary,
  onSecondary: Colors.white,
  secondaryContainer: secondaryContainer,
  tertiary: tertiary,
  onTertiary: Colors.white,
  tertiaryContainer: tertiaryContainer,
  surface: surface,
  onSurface: const Color(0xFF1C1B20),
  onSurfaceVariant: const Color(0xFF514D57),
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: surfaceLow,
  surfaceContainer: surfaceLow,
  surfaceContainerHigh: surfaceHigh,
  surfaceContainerHighest: surfaceHigh,
  outline: outline,
  outlineVariant: Color.lerp(outline, Colors.white, 0.62),
  inversePrimary: primaryContainer,
  surfaceTint: primary,
);

ColorScheme _refinePaletteDark(
  ColorScheme base, {
  required Color primary,
  required Color onPrimary,
  required Color primaryContainer,
  required Color secondary,
  required Color secondaryContainer,
  required Color tertiary,
  required Color tertiaryContainer,
  required Color outline,
}) => base.copyWith(
  primary: primary,
  onPrimary: onPrimary,
  primaryContainer: primaryContainer,
  onPrimaryContainer: Color.lerp(primary, Colors.white, 0.72),
  secondary: secondary,
  onSecondary: onPrimary,
  secondaryContainer: secondaryContainer,
  onSecondaryContainer: Color.lerp(secondary, Colors.white, 0.72),
  tertiary: tertiary,
  onTertiary: onPrimary,
  tertiaryContainer: tertiaryContainer,
  onTertiaryContainer: Color.lerp(tertiary, Colors.white, 0.72),
  onSurface: const Color(0xFFF0EDF3),
  onSurfaceVariant: const Color(0xFFC9C2CF),
  surfaceContainerLowest: Color.lerp(base.surface, Colors.black, 0.18),
  outline: outline,
  outlineVariant: Color.lerp(outline, Colors.black, 0.52),
  inversePrimary: primaryContainer,
  surfaceTint: primary,
);

ColorScheme _lavenderLight(ColorScheme base) => _refinePaletteLight(
  base,
  primary: const Color(0xFF7151A5),
  primaryContainer: const Color(0xFFEBDDFF),
  onPrimaryContainer: const Color(0xFF291248),
  secondary: const Color(0xFF76546F),
  secondaryContainer: const Color(0xFFFFD7F5),
  tertiary: const Color(0xFF4D6098),
  tertiaryContainer: const Color(0xFFDCE2FF),
  surface: const Color(0xFFFCF8FF),
  surfaceLow: const Color(0xFFF6F0FC),
  surfaceHigh: const Color(0xFFEDE5F5),
  outline: const Color(0xFF7D7484),
);

ColorScheme _lavenderDark(ColorScheme base) => _refinePaletteDark(
  base,
  primary: const Color(0xFFD6B9FF),
  onPrimary: const Color(0xFF35165E),
  primaryContainer: const Color(0xFF50357B),
  secondary: const Color(0xFFE9B8DD),
  secondaryContainer: const Color(0xFF5D3D57),
  tertiary: const Color(0xFFB8C4FF),
  tertiaryContainer: const Color(0xFF354476),
  outline: const Color(0xFF968CA0),
);

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
  darkTertiary: Color(0xFFB8C4FF),
  refineLight: _lavenderLight,
  refineDark: _lavenderDark,
);

// Cores tiradas das artes do morceguinho em `assets/icon/icon-v2`.
// Sistema visual principal do GitBat. As quatro cores de marca continuam
// iguais às da logo; as demais pertencem somente à interface.
const _batNight = Color(0xFF0D1526); // fundo principal
const _batSurface = Color(0xFF16233B); // cartões e painéis
const _batSurfaceHigh = Color(0xFF203251); // controles elevados
const _batBody = Color(0xFF5A9EF6); // corpo
const _batCyan = Color(0xFF22D8EE); // fone de ouvido
const _batNavy = Color(0xFF0C48A8); // contorno do mascote
const _batDeepNavy = Color(0xFF061C4B); // contorno mais escuro
const _batIce = Color(0xFFB0DCFC); // corpo do mascote
const _batLavender = Color(0xFFA9BEF7); // dentro da orelha
const _batText = Color(0xFFF1F5FF); // texto principal
const _batTextMuted = Color(0xFFA8B6D3); // texto secundário e contornos

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
  onSurface: _batText,
  onSurfaceVariant: _batTextMuted,
  surfaceContainerLowest: _batNight,
  outline: _batTextMuted,
  outlineVariant: _batSurfaceHigh,
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
  darkCard: _batSurface,
  darkContainerHigh: _batSurfaceHigh,
  darkContainerHighest: _batSurfaceHigh,
  darkChipSelected: _batSurfaceHigh,
  darkTertiary: _batLavender,
  accentGradient: [_batBody, _batCyan],
  onAccent: _batDeepNavy,
  contentBackground: defaultBackgroundColor,
  contentFrame: defaultFrameColor,
  contentText: defaultTextColor,
  refineLight: _batLight,
  refineDark: _batDark,
);

ColorScheme _mintLight(ColorScheme base) => _refinePaletteLight(
  base,
  primary: const Color(0xFF1F7556),
  primaryContainer: const Color(0xFFBDF0D7),
  onPrimaryContainer: const Color(0xFF072E20),
  secondary: const Color(0xFF3E6558),
  secondaryContainer: const Color(0xFFC8EADB),
  tertiary: const Color(0xFF4A628F),
  tertiaryContainer: const Color(0xFFD9E2FF),
  surface: const Color(0xFFF6FCF8),
  surfaceLow: const Color(0xFFECF6F0),
  surfaceHigh: const Color(0xFFE1EEE7),
  outline: const Color(0xFF6E7E75),
);

ColorScheme _mintDark(ColorScheme base) => _refinePaletteDark(
  base,
  primary: const Color(0xFF8DDBB7),
  onPrimary: const Color(0xFF073826),
  primaryContainer: const Color(0xFF24523E),
  secondary: const Color(0xFFA8D4BF),
  secondaryContainer: const Color(0xFF315144),
  tertiary: const Color(0xFFB7C9FF),
  tertiaryContainer: const Color(0xFF354A73),
  outline: const Color(0xFF87998F),
);

ColorScheme _peachLight(ColorScheme base) => _refinePaletteLight(
  base,
  primary: const Color(0xFFA84B20),
  primaryContainer: const Color(0xFFFFDBCB),
  onPrimaryContainer: const Color(0xFF3B1000),
  secondary: const Color(0xFF7C5748),
  secondaryContainer: const Color(0xFFFFDBCC),
  tertiary: const Color(0xFF67558D),
  tertiaryContainer: const Color(0xFFEBDDFF),
  surface: const Color(0xFFFFF8F5),
  surfaceLow: const Color(0xFFFFF0E9),
  surfaceHigh: const Color(0xFFF8E5DC),
  outline: const Color(0xFF8A7166),
);

ColorScheme _peachDark(ColorScheme base) => _refinePaletteDark(
  base,
  primary: const Color(0xFFFFB693),
  onPrimary: const Color(0xFF5B1D00),
  primaryContainer: const Color(0xFF7F3515),
  secondary: const Color(0xFFE9BFAE),
  secondaryContainer: const Color(0xFF604538),
  tertiary: const Color(0xFFD8BCFF),
  tertiaryContainer: const Color(0xFF4E3E70),
  outline: const Color(0xFFA58A7E),
);

ColorScheme _roseLight(ColorScheme base) => _refinePaletteLight(
  base,
  primary: const Color(0xFF9B356A),
  primaryContainer: const Color(0xFFFFD8E9),
  onPrimaryContainer: const Color(0xFF3D0024),
  secondary: const Color(0xFF765661),
  secondaryContainer: const Color(0xFFFFD9E2),
  tertiary: const Color(0xFF595D91),
  tertiaryContainer: const Color(0xFFE1E2FF),
  surface: const Color(0xFFFFF8FA),
  surfaceLow: const Color(0xFFFFF0F5),
  surfaceHigh: const Color(0xFFF8E4EC),
  outline: const Color(0xFF86717A),
);

ColorScheme _roseDark(ColorScheme base) => _refinePaletteDark(
  base,
  primary: const Color(0xFFFFAFD2),
  onPrimary: const Color(0xFF5D123B),
  primaryContainer: const Color(0xFF7C2854),
  secondary: const Color(0xFFE6BDC9),
  secondaryContainer: const Color(0xFF5B3F49),
  tertiary: const Color(0xFFBFC4FF),
  tertiaryContainer: const Color(0xFF414575),
  outline: const Color(0xFFA38B95),
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
  darkTertiary: Color(0xFFB7C9FF),
  refineLight: _mintLight,
  refineDark: _mintDark,
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
  darkTertiary: Color(0xFFD8BCFF),
  refineLight: _peachLight,
  refineDark: _peachDark,
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
  darkTertiary: Color(0xFFBFC4FF),
  refineLight: _roseLight,
  refineDark: _roseDark,
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
