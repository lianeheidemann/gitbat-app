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
    this.multicolorLight = false,
    this.refineLight = _generatedPaletteLight,
    this.refineDark = _generatedPaletteDark,
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

  /// Distribui as cores de identidade da paleta pelo tema claro, em vez de
  /// derivar todos os papéis cromáticos somente de [seed].
  final bool multicolorLight;

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

/// Acabamento compartilhado pelas paletas v2. Mantém as cores derivadas da
/// semente, mas controla superfícies e contornos para evitar o aspecto
/// excessivamente colorido do esquema Material gerado sem ajustes.
ColorScheme _generatedPaletteLight(ColorScheme base) => base.copyWith(
  surface: Color.lerp(base.surface, Colors.white, 0.38),
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: Color.lerp(base.surfaceContainerLow, Colors.white, 0.22),
  surfaceContainer: Color.lerp(base.surfaceContainer, Colors.white, 0.16),
  outlineVariant: Color.lerp(base.outline, Colors.white, 0.64),
  surfaceTint: base.primary,
);

ColorScheme _generatedPaletteDark(ColorScheme base) => base.copyWith(
  onSurface: const Color(0xFFF2EFF5),
  onSurfaceVariant: const Color(0xFFCDC6D2),
  outline: Color.lerp(base.outline, Colors.white, 0.12),
  outlineVariant: Color.lerp(base.outline, Colors.black, 0.55),
  surfaceTint: base.primary,
);

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

/// Cores inspiradas na flor de referência: lavanda nas ações principais,
/// rosa-dália nos destaques e superfícies grafite levemente arroxeadas.
ColorScheme _dahliaLight(ColorScheme base) => _refinePaletteLight(
  base,
  primary: const Color(0xFF75458D),
  primaryContainer: const Color(0xFFF2DAFF),
  onPrimaryContainer: const Color(0xFF2E0B3D),
  secondary: const Color(0xFF9B365F),
  secondaryContainer: const Color(0xFFFFD9E5),
  tertiary: const Color(0xFF76556B),
  tertiaryContainer: const Color(0xFFFFD8EA),
  surface: const Color(0xFFFFF8FC),
  surfaceLow: const Color(0xFFF9F0F7),
  surfaceHigh: const Color(0xFFF1E5EF),
  outline: const Color(0xFF81747F),
);

ColorScheme _dahliaDark(ColorScheme base) => _refinePaletteDark(
  base,
  primary: const Color(0xFFCDAAFD),
  onPrimary: const Color(0xFF321344),
  primaryContainer: const Color(0xFF54406F),
  secondary: const Color(0xFFF0A5C7),
  secondaryContainer: const Color(0xFF6D304C),
  tertiary: const Color(0xFFD69DA6),
  tertiaryContainer: const Color(0xFF633E49),
  outline: const Color(0xFF948F98),
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

const dahliaPalette = AppPalette(
  id: 'dalia',
  label: 'Dália',
  seed: Color(0xFFCDAAFD),
  darkBackground: Color(0xFF121115),
  darkCard: Color(0xFF19171D),
  darkContainerHigh: Color(0xFF211D2D),
  darkContainerHighest: Color(0xFF352F43),
  darkChipSelected: Color(0xFF54406F),
  darkTertiary: Color(0xFFF0A5C7),
  accentGradient: [Color(0xFFCDAAFD), Color(0xFFF0A5C7)],
  onAccent: Color(0xFF2A1730),
  contentBackground: Color(0xFFF1D7E5),
  contentFrame: Color(0xFF956EA3),
  contentText: Color(0xFF6D304C),
  refineLight: _dahliaLight,
  refineDark: _dahliaDark,
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

ColorScheme _triadLight(ColorScheme base) => _refinePaletteLight(
  base,
  primary: const Color(0xFFAD4718),
  primaryContainer: const Color(0xFFFFDBCA),
  onPrimaryContainer: const Color(0xFF3A1000),
  secondary: const Color(0xFF08785A),
  secondaryContainer: const Color(0xFFADF2D6),
  tertiary: const Color(0xFF355F9E),
  tertiaryContainer: const Color(0xFFD8E2FF),
  surface: const Color(0xFFFFF8F5),
  surfaceLow: const Color(0xFFFFF0E9),
  surfaceHigh: const Color(0xFFF8E4DA),
  outline: const Color(0xFF8B7064),
);

ColorScheme _triadDark(ColorScheme base) => _refinePaletteDark(
  base,
  primary: const Color(0xFFFFB68F),
  onPrimary: const Color(0xFF5C1E00),
  primaryContainer: const Color(0xFF7D2D05),
  secondary: const Color(0xFF60DDB2),
  secondaryContainer: const Color(0xFF00513D),
  tertiary: const Color(0xFFAFC7FF),
  tertiaryContainer: const Color(0xFF294778),
  outline: const Color(0xFFA58A7E),
);

ColorScheme _squareLight(ColorScheme base) => _refinePaletteLight(
  base,
  primary: const Color(0xFF7B3FA0),
  primaryContainer: const Color(0xFFF2DAFF),
  onPrimaryContainer: const Color(0xFF310049),
  secondary: const Color(0xFFA8412B),
  secondaryContainer: const Color(0xFFFFDAD1),
  tertiary: const Color(0xFF3F6F32),
  tertiaryContainer: const Color(0xFFC0EFB0),
  surface: const Color(0xFFFCF8FF),
  surfaceLow: const Color(0xFFF7F0FA),
  surfaceHigh: const Color(0xFFEEE4F1),
  outline: const Color(0xFF7F7482),
);

ColorScheme _squareDark(ColorScheme base) => _refinePaletteDark(
  base,
  primary: const Color(0xFFE4B6FF),
  onPrimary: const Color(0xFF4B1468),
  primaryContainer: const Color(0xFF633081),
  secondary: const Color(0xFFFFB4A2),
  secondaryContainer: const Color(0xFF7F2A1A),
  tertiary: const Color(0xFFA5D991),
  tertiaryContainer: const Color(0xFF2D5724),
  outline: const Color(0xFF9B8D9F),
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
  multicolorLight: true,
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
  multicolorLight: true,
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

/// Harmonia tríade: laranja e verde ficam a aproximadamente 120° do azul da
/// marca. É viva, mas as superfícies quentes e escuras mantêm a legibilidade.
const triadPalette = AppPalette(
  id: 'triade',
  label: 'Tríade',
  seed: Color(0xFFF59A62),
  darkBackground: Color(0xFF17110F),
  darkCard: Color(0xFF231A17),
  darkContainerHigh: Color(0xFF2E211C),
  darkContainerHighest: Color(0xFF382822),
  darkChipSelected: Color(0xFF6F402B),
  darkTertiary: Color(0xFFAFC7FF),
  accentGradient: [Color(0xFFFFB68F), Color(0xFF60DDB2)],
  onAccent: Color(0xFF351200),
  contentBackground: Color(0xFFFFD3BE),
  contentFrame: Color(0xFF17866A),
  contentText: Color(0xFF244F88),
  refineLight: _triadLight,
  refineDark: _triadDark,
);

/// Harmonia quadrada: violeta, coral, verde e azul ocupam quatro regiões
/// distintas do círculo cromático e criam a opção mais expressiva do app.
const squarePalette = AppPalette(
  id: 'quadrada',
  label: 'Quadrada',
  seed: Color(0xFFC779E8),
  darkBackground: Color(0xFF151018),
  darkCard: Color(0xFF211924),
  darkContainerHigh: Color(0xFF2B2030),
  darkContainerHighest: Color(0xFF35273A),
  darkChipSelected: Color(0xFF5D3A6B),
  darkTertiary: Color(0xFFFFB4A2),
  accentGradient: [Color(0xFFA5D991), Color(0xFF76A9FF)],
  onAccent: Color(0xFF161B2A),
  contentBackground: Color(0xFFE9D2F3),
  contentFrame: Color(0xFF5C9C4B),
  contentText: Color(0xFF7F2A1A),
  refineLight: _squareLight,
  refineDark: _squareDark,
);

// Paletas v2 inspiradas nas referências enviadas. Cada opção mantém cores
// próprias para superfícies escuras e deixa o Material 3 derivar o esquema
// claro a partir da semente. Assim, a mesma escolha acompanha a troca entre
// modo claro e escuro sem perder identidade ou contraste.
const auroraCoralPalette = AppPalette(
  id: 'aurora-coral',
  label: 'Aurora Coral',
  seed: Color(0xFFFF6648),
  darkBackground: Color(0xFF111521),
  darkCard: Color(0xFF1B2230),
  darkContainerHigh: Color(0xFF263044),
  darkContainerHighest: Color(0xFF303C52),
  darkChipSelected: Color(0xFF6B3D38),
  darkTertiary: Color(0xFFFFCB45),
  multicolorLight: true,
  accentGradient: [Color(0xFF17D4E8), Color(0xFFFF6648)],
  onAccent: Color(0xFF10131C),
  contentBackground: Color(0xFFFFE5E4),
  contentFrame: Color(0xFF596274),
  contentText: Color(0xFF7D2A1F),
);

/// Primeira versão da paleta turquesa, preservada como opção independente.
const classicTurquoisePalette = AppPalette(
  id: 'turquesa-classica',
  label: 'Turquesa',
  seed: Color(0xFF71BDC4),
  darkBackground: Color(0xFF171516),
  darkCard: Color(0xFF252122),
  darkContainerHigh: Color(0xFF302A2B),
  darkContainerHighest: Color(0xFF393233),
  darkChipSelected: Color(0xFF3E6265),
  darkTertiary: Color(0xFFFFE39B),
  accentGradient: [Color(0xFF71BDC4), Color(0xFFC93A26)],
  onAccent: Color(0xFF151718),
  contentBackground: Color(0xFFF1EAE4),
  contentFrame: Color(0xFFC93A26),
  contentText: Color(0xFF493E3C),
);

/// Versão aprovada da Vintage: o turquesa continua dominante e o
/// vermelho queimado passa a participar dos controles e estados ativos.
ColorScheme _vintageTurquoiseLight(ColorScheme base) => base.copyWith(
  primary: const Color(0xFF087F84),
  onPrimary: Colors.white,
  primaryContainer: const Color(0xFFD4F0EE),
  onPrimaryContainer: const Color(0xFF103B3D),
  secondary: const Color(0xFFC55646),
  onSecondary: Colors.white,
  secondaryContainer: const Color(0xFFF4DFDA),
  onSecondaryContainer: const Color(0xFF55231C),
  tertiary: const Color(0xFF9A741C),
  onTertiary: Colors.white,
  tertiaryContainer: const Color(0xFFF3E6D1),
  onTertiaryContainer: const Color(0xFF493609),
  surface: const Color(0xFFF7FCFB),
  onSurface: const Color(0xFF243537),
  onSurfaceVariant: const Color(0xFF4E6262),
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: const Color(0xFFEFF8F7),
  surfaceContainer: const Color(0xFFEAF4F2),
  surfaceContainerHigh: const Color(0xFFE4F0EE),
  surfaceContainerHighest: const Color(0xFFD8E9E6),
  outline: const Color(0xFF647A79),
  outlineVariant: const Color(0xFFB9CFCC),
  inversePrimary: const Color(0xFF72CDD0),
  surfaceTint: const Color(0xFF087F84),
);

ColorScheme _vintageTurquoiseDark(ColorScheme base) => base.copyWith(
  primary: const Color(0xFF49BBC1),
  onPrimary: const Color(0xFF102628),
  primaryContainer: const Color(0xFF234F52),
  onPrimaryContainer: const Color(0xFFBDECEF),
  secondary: const Color(0xFFC75A4C),
  onSecondary: const Color(0xFF2C100C),
  secondaryContainer: const Color(0xFF57302C),
  onSecondaryContainer: const Color(0xFFF3D1CB),
  tertiary: const Color(0xFFD2B46C),
  onTertiary: const Color(0xFF302606),
  tertiaryContainer: const Color(0xFF4A4025),
  onTertiaryContainer: const Color(0xFFF0DCA5),
  surface: const Color(0xFF121313),
  onSurface: const Color(0xFFF3F1EE),
  onSurfaceVariant: const Color(0xFFC9C6C1),
  surfaceContainerLowest: const Color(0xFF0D0E0E),
  surfaceContainerLow: const Color(0xFF1D1E1E),
  surfaceContainer: const Color(0xFF222323),
  surfaceContainerHigh: const Color(0xFF292B2C),
  surfaceContainerHighest: const Color(0xFF323436),
  outline: const Color(0xFF9DA7A5),
  outlineVariant: const Color(0xFF4D5554),
  inversePrimary: const Color(0xFF087F84),
  surfaceTint: const Color(0xFF49BBC1),
);

const vintageTurquoisePalette = AppPalette(
  id: 'turquesa-vintage',
  label: 'Vintage',
  seed: Color(0xFF49BBC1),
  darkBackground: Color(0xFF121313),
  darkCard: Color(0xFF1D1E1E),
  darkContainerHigh: Color(0xFF292B2C),
  darkContainerHighest: Color(0xFF323436),
  darkChipSelected: Color(0xFF57302C),
  darkTertiary: Color(0xFFD2B46C),
  accentGradient: [Color(0xFF49BBC1), Color(0xFFC55646)],
  onAccent: Color(0xFF102628),
  contentBackground: Color(0xFFF3E6D1),
  contentFrame: Color(0xFFB94B42),
  contentText: Color(0xFF263638),
  refineLight: _vintageTurquoiseLight,
  refineDark: _vintageTurquoiseDark,
);

/// Versão clara aprovada da paleta Pôr do Sol Rosa. Coral, azul
/// crepuscular e dourado aparecem sobre superfícies pêssego suaves.
ColorScheme _sunsetRoseLight(ColorScheme base) => base.copyWith(
  primary: const Color(0xFFC86578),
  onPrimary: Colors.white,
  primaryContainer: const Color(0xFFF3DDE2),
  onPrimaryContainer: const Color(0xFF563744),
  secondary: const Color(0xFF6678A6),
  onSecondary: Colors.white,
  secondaryContainer: const Color(0xFFE7EAF4),
  onSecondaryContainer: const Color(0xFF29375D),
  tertiary: const Color(0xFFD9A441),
  onTertiary: const Color(0xFF3C2B08),
  tertiaryContainer: const Color(0xFFF7EACB),
  onTertiaryContainer: const Color(0xFF4B350A),
  surface: const Color(0xFFFFF9F6),
  onSurface: const Color(0xFF563744),
  onSurfaceVariant: const Color(0xFF715964),
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: const Color(0xFFFBEDE4),
  surfaceContainer: const Color(0xFFF7E7E8),
  surfaceContainerHigh: const Color(0xFFE7EAF4),
  surfaceContainerHighest: const Color(0xFFDDE2F0),
  outline: const Color(0xFF6678A6),
  outlineVariant: const Color(0xFFC5CCE0),
  inversePrimary: const Color(0xFFD998A5),
  surfaceTint: const Color(0xFFC86578),
);

const sunsetRosePalette = AppPalette(
  id: 'por-do-sol-rosa',
  label: 'Pôr do Sol Rosa',
  seed: Color(0xFFFF7496),
  darkBackground: Color(0xFF11172A),
  darkCard: Color(0xFF1C2438),
  darkContainerHigh: Color(0xFF27324A),
  darkContainerHighest: Color(0xFF323D56),
  darkChipSelected: Color(0xFF70435B),
  darkTertiary: Color(0xFFFFC65A),
  accentGradient: [Color(0xFFFFC65A), Color(0xFFFF7496)],
  onAccent: Color(0xFF26131A),
  contentBackground: Color(0xFFF1F2F7),
  contentFrame: Color(0xFF6077A5),
  contentText: Color(0xFF40243A),
  refineLight: _sunsetRoseLight,
);

const oceanBreezePalette = AppPalette(
  id: 'brisa-oceanica',
  label: 'Brisa Oceânica',
  seed: Color(0xFF5E9CD1),
  darkBackground: Color(0xFF0B1831),
  darkCard: Color(0xFF142441),
  darkContainerHigh: Color(0xFF1D3151),
  darkContainerHighest: Color(0xFF263D60),
  darkChipSelected: Color(0xFF315F78),
  darkTertiary: Color(0xFF83D5BF),
  accentGradient: [Color(0xFF83D5BF), Color(0xFFFFC247)],
  onAccent: Color(0xFF092638),
  contentBackground: Color(0xFFF1F5F4),
  contentFrame: Color(0xFF3B58B9),
  contentText: Color(0xFF15335D),
);

const lilacCreamPalette = AppPalette(
  id: 'lilas-creme',
  label: 'Lilás e Creme',
  seed: Color(0xFF8D76F4),
  darkBackground: Color(0xFF151329),
  darkCard: Color(0xFF211E3B),
  darkContainerHigh: Color(0xFF2C2850),
  darkContainerHighest: Color(0xFF373162),
  darkChipSelected: Color(0xFF574E8A),
  darkTertiary: Color(0xFFFFD8C2),
  accentGradient: [Color(0xFF8D76F4), Color(0xFFFFD8C2)],
  onAccent: Color(0xFF251D48),
  contentBackground: Color(0xFFF6F4FF),
  contentFrame: Color(0xFFACA9F3),
  contentText: Color(0xFF46377F),
);

/// Versão clara aprovada da paleta Pitaya e Limão. O tema escuro continua
/// usando o acabamento compartilhado, sem nenhuma alteração.
ColorScheme _pitayaLimeLight(ColorScheme base) => base.copyWith(
  primary: const Color(0xFFB84F70),
  onPrimary: Colors.white,
  primaryContainer: const Color(0xFFF2DCE4),
  onPrimaryContainer: const Color(0xFF5F2944),
  secondary: const Color(0xFF738E52),
  onSecondary: Colors.white,
  secondaryContainer: const Color(0xFFE6F0D8),
  onSecondaryContainer: const Color(0xFF2D4120),
  tertiary: const Color(0xFF9FCB7A),
  onTertiary: const Color(0xFF26331C),
  tertiaryContainer: const Color(0xFFEAF4DF),
  onTertiaryContainer: const Color(0xFF2D4120),
  surface: const Color(0xFFFFF9FA),
  onSurface: const Color(0xFF4C2338),
  onSurfaceVariant: const Color(0xFF6D4B5B),
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: const Color(0xFFF9EDF1),
  surfaceContainer: const Color(0xFFF8E8ED),
  surfaceContainerHigh: const Color(0xFFF2DCE4),
  surfaceContainerHighest: const Color(0xFFEBCFD9),
  outline: const Color(0xFF7B4B61),
  outlineVariant: const Color(0xFFD9B9C6),
  inversePrimary: const Color(0xFFD5A0B3),
  surfaceTint: const Color(0xFFB84F70),
);

const pitayaLimePalette = AppPalette(
  id: 'pitaya-limao',
  label: 'Pitaya e Limão',
  seed: Color(0xFFD92B73),
  darkBackground: Color(0xFF201022),
  darkCard: Color(0xFF30162F),
  darkContainerHigh: Color(0xFF411D3E),
  darkContainerHighest: Color(0xFF51234B),
  darkChipSelected: Color(0xFF782753),
  darkTertiary: Color(0xFFB9F68D),
  accentGradient: [Color(0xFFFF6680), Color(0xFFB9F68D)],
  onAccent: Color(0xFF35101E),
  contentBackground: Color(0xFFFFF9E7),
  contentFrame: Color(0xFF92228C),
  contentText: Color(0xFF60143F),
  refineLight: _pitayaLimeLight,
);

const blushSagePalette = AppPalette(
  id: 'blush-salvia',
  label: 'Blush e Sálvia',
  seed: Color(0xFFD97F93),
  darkBackground: Color(0xFF181516),
  darkCard: Color(0xFF251F21),
  darkContainerHigh: Color(0xFF30292B),
  darkContainerHighest: Color(0xFF3B3234),
  darkChipSelected: Color(0xFF66464F),
  darkTertiary: Color(0xFF9CC6BD),
  multicolorLight: true,
  accentGradient: [Color(0xFFD97F93), Color(0xFF9CC6BD)],
  onAccent: Color(0xFF321C23),
  contentBackground: Color(0xFFF8E6D2),
  contentFrame: Color(0xFF8B79B7),
  contentText: Color(0xFF573A45),
);

const citrusGraphitePalette = AppPalette(
  id: 'citrico-grafite',
  label: 'Cítrico Grafite',
  seed: Color(0xFFFF872B),
  darkBackground: Color(0xFF151619),
  darkCard: Color(0xFF222429),
  darkContainerHigh: Color(0xFF2D3036),
  darkContainerHighest: Color(0xFF383C43),
  darkChipSelected: Color(0xFF67462D),
  darkTertiary: Color(0xFFE3EDB8),
  multicolorLight: true,
  accentGradient: [Color(0xFFFF872B), Color(0xFFE9343E)],
  onAccent: Color(0xFF2E1708),
  contentBackground: Color(0xFFF0E7D7),
  contentFrame: Color(0xFFB5B59D),
  contentText: Color(0xFF3B3C40),
);

const mistyMeadowPalette = AppPalette(
  id: 'prado-nebuloso',
  label: 'Prado Nebuloso',
  seed: Color(0xFF9A82B4),
  darkBackground: Color(0xFF171522),
  darkCard: Color(0xFF242133),
  darkContainerHigh: Color(0xFF302B41),
  darkContainerHighest: Color(0xFF3B354E),
  darkChipSelected: Color(0xFF5D5270),
  darkTertiary: Color(0xFFBDF1ED),
  multicolorLight: true,
  accentGradient: [Color(0xFF9A82B4), Color(0xFFBDF1ED)],
  onAccent: Color(0xFF261F35),
  contentBackground: Color(0xFFF4EFCB),
  contentFrame: Color(0xFFAFC7DB),
  contentText: Color(0xFF4F4560),
);

const neonOrchidPalette = AppPalette(
  id: 'orquidea-neon',
  label: 'Orquídea Neon',
  seed: Color(0xFFD93CB9),
  darkBackground: Color(0xFF170D2C),
  darkCard: Color(0xFF25143D),
  darkContainerHigh: Color(0xFF341C50),
  darkContainerHighest: Color(0xFF432461),
  darkChipSelected: Color(0xFF68266B),
  darkTertiary: Color(0xFFFFB8DA),
  multicolorLight: true,
  accentGradient: [Color(0xFF7B2ED0), Color(0xFFD93CB9)],
  onAccent: Color(0xFF240B30),
  contentBackground: Color(0xFFFFD0E3),
  contentFrame: Color(0xFF4F20A8),
  contentText: Color(0xFF651552),
);

const coastalGoldPalette = AppPalette(
  id: 'ouro-costeiro',
  label: 'Ouro Costeiro',
  seed: Color(0xFF3C58B8),
  darkBackground: Color(0xFF0D1730),
  darkCard: Color(0xFF172443),
  darkContainerHigh: Color(0xFF213155),
  darkContainerHighest: Color(0xFF2B3D67),
  darkChipSelected: Color(0xFF315B76),
  darkTertiary: Color(0xFFFFC23D),
  multicolorLight: true,
  accentGradient: [Color(0xFF84D4BE), Color(0xFFFFC23D)],
  onAccent: Color(0xFF13273B),
  contentBackground: Color(0xFFF0F3F2),
  contentFrame: Color(0xFF6599CA),
  contentText: Color(0xFF233D83),
);

const midnightCandyPalette = AppPalette(
  id: 'doce-meia-noite',
  label: 'Doce Meia-Noite',
  seed: Color(0xFF7585F8),
  darkBackground: Color(0xFF0C1B4A),
  darkCard: Color(0xFF14275A),
  darkContainerHigh: Color(0xFF1D346D),
  darkContainerHighest: Color(0xFF274181),
  darkChipSelected: Color(0xFF465694),
  darkTertiary: Color(0xFFFF70A2),
  accentGradient: [Color(0xFF7585F8), Color(0xFFFFC64C)],
  onAccent: Color(0xFF17204C),
  contentBackground: Color(0xFFFFEDF3),
  contentFrame: Color(0xFF243A83),
  contentText: Color(0xFF313C7A),
);

const emberSandPalette = AppPalette(
  id: 'brasa-e-areia',
  label: 'Brasa e Areia',
  seed: Color(0xFFFF5B00),
  darkBackground: Color(0xFF1D0F0B),
  darkCard: Color(0xFF2C1710),
  darkContainerHigh: Color(0xFF3A2017),
  darkContainerHighest: Color(0xFF48291E),
  darkChipSelected: Color(0xFF713619),
  darkTertiary: Color(0xFFFFD0A0),
  multicolorLight: true,
  accentGradient: [Color(0xFFFF5B00), Color(0xFFFFB15E)],
  onAccent: Color(0xFF371100),
  contentBackground: Color(0xFFFFD0A0),
  contentFrame: Color(0xFFB60015),
  contentText: Color(0xFF5E240C),
);

const berryCreamPalette = AppPalette(
  id: 'frutas-vermelhas',
  label: 'Frutas Vermelhas',
  seed: Color(0xFFFF5A78),
  darkBackground: Color(0xFF25101A),
  darkCard: Color(0xFF361824),
  darkContainerHigh: Color(0xFF472030),
  darkContainerHighest: Color(0xFF57283B),
  darkChipSelected: Color(0xFF7A354C),
  darkTertiary: Color(0xFFFFD8C7),
  multicolorLight: true,
  accentGradient: [Color(0xFFFF5A78), Color(0xFFFFA59A)],
  onAccent: Color(0xFF3C1320),
  contentBackground: Color(0xFFFFF9EE),
  contentFrame: Color(0xFF6B253F),
  contentText: Color(0xFF662038),
);

const terracottaLagoonPalette = AppPalette(
  id: 'terracota-lagoa',
  label: 'Terracota e Lagoa',
  seed: Color(0xFF087C83),
  darkBackground: Color(0xFF0A2023),
  darkCard: Color(0xFF123034),
  darkContainerHigh: Color(0xFF1B4044),
  darkContainerHighest: Color(0xFF245054),
  darkChipSelected: Color(0xFF35666A),
  darkTertiary: Color(0xFFF08E70),
  multicolorLight: true,
  accentGradient: [Color(0xFF75C6C0), Color(0xFFF08E70)],
  onAccent: Color(0xFF122A2B),
  contentBackground: Color(0xFFFFDDD2),
  contentFrame: Color(0xFF087C83),
  contentText: Color(0xFF35575A),
);

const fuchsiaMintPalette = AppPalette(
  id: 'fucsia-menta',
  label: 'Fúcsia e Menta',
  seed: Color(0xFFC84899),
  darkBackground: Color(0xFF241025),
  darkCard: Color(0xFF351735),
  darkContainerHigh: Color(0xFF461F45),
  darkContainerHighest: Color(0xFF572756),
  darkChipSelected: Color(0xFF743161),
  darkTertiary: Color(0xFF80F3DF),
  multicolorLight: true,
  accentGradient: [Color(0xFFC84899), Color(0xFF80F3DF)],
  onAccent: Color(0xFF311329),
  contentBackground: Color(0xFFFFE4B5),
  contentFrame: Color(0xFF80D9CC),
  contentText: Color(0xFF662352),
);

const tropicalPopPalette = AppPalette(
  id: 'pop-tropical',
  label: 'Pop Tropical',
  seed: Color(0xFF10D5E8),
  darkBackground: Color(0xFF121927),
  darkCard: Color(0xFF1D2637),
  darkContainerHigh: Color(0xFF283448),
  darkContainerHighest: Color(0xFF334159),
  darkChipSelected: Color(0xFF316873),
  darkTertiary: Color(0xFFFFC945),
  multicolorLight: true,
  accentGradient: [Color(0xFF10D5E8), Color(0xFFFF6545)],
  onAccent: Color(0xFF10252A),
  contentBackground: Color(0xFFFFE6E7),
  contentFrame: Color(0xFF596170),
  contentText: Color(0xFF174A55),
);

const skyLemonPalette = AppPalette(
  id: 'ceu-e-limao',
  label: 'Céu e Limão',
  seed: Color(0xFF57A0D9),
  darkBackground: Color(0xFF0C2038),
  darkCard: Color(0xFF142E49),
  darkContainerHigh: Color(0xFF1D3C5B),
  darkContainerHighest: Color(0xFF274A6C),
  darkChipSelected: Color(0xFF35637F),
  darkTertiary: Color(0xFFF4DF63),
  accentGradient: [Color(0xFF78C8F2), Color(0xFFF4DF63)],
  onAccent: Color(0xFF133247),
  contentBackground: Color(0xFFF0F6F4),
  contentFrame: Color(0xFFE95A8B),
  contentText: Color(0xFF285A80),
);

const nocturneSagePalette = AppPalette(
  id: 'noturno-salvia',
  label: 'Noturno e Sálvia',
  seed: Color(0xFF29486C),
  darkBackground: Color(0xFF081421),
  darkCard: Color(0xFF102238),
  darkContainerHigh: Color(0xFF18304A),
  darkContainerHighest: Color(0xFF223E5C),
  darkChipSelected: Color(0xFF36536B),
  darkTertiary: Color(0xFFC6D696),
  accentGradient: [Color(0xFF29486C), Color(0xFFE39ACB)],
  onAccent: Color(0xFFF6F8F5),
  contentBackground: Color(0xFFEEF3EE),
  contentFrame: Color(0xFFC6D696),
  contentText: Color(0xFF18314D),
);

const cyberPastelPalette = AppPalette(
  id: 'cyber-pastel',
  label: 'Cyber Pastel',
  seed: Color(0xFFCB5AF4),
  darkBackground: Color(0xFF18102B),
  darkCard: Color(0xFF25183D),
  darkContainerHigh: Color(0xFF33204F),
  darkContainerHighest: Color(0xFF412860),
  darkChipSelected: Color(0xFF633477),
  darkTertiary: Color(0xFF76EED0),
  multicolorLight: true,
  accentGradient: [Color(0xFFCB5AF4), Color(0xFF76EED0)],
  onAccent: Color(0xFF29133A),
  contentBackground: Color(0xFFFFFEE9),
  contentFrame: Color(0xFF7C3FFF),
  contentText: Color(0xFF52256D),
);

const electricCitrusPalette = AppPalette(
  id: 'citrico-eletrico',
  label: 'Cítrico Elétrico',
  seed: Color(0xFFFF6261),
  darkBackground: Color(0xFF111727),
  darkCard: Color(0xFF1B2337),
  darkContainerHigh: Color(0xFF263048),
  darkContainerHighest: Color(0xFF303C58),
  darkChipSelected: Color(0xFF6C3B48),
  darkTertiary: Color(0xFFE6EC2D),
  multicolorLight: true,
  accentGradient: [Color(0xFFFF6261), Color(0xFFE6EC2D)],
  onAccent: Color(0xFF2D1820),
  contentBackground: Color(0xFFEAF2EF),
  contentFrame: Color(0xFF45C1E2),
  contentText: Color(0xFF29334B),
);

const rivieraPinkPalette = AppPalette(
  id: 'riviera-rosa',
  label: 'Riviera Rosa',
  seed: Color(0xFF7582F1),
  darkBackground: Color(0xFF0D1D50),
  darkCard: Color(0xFF162A63),
  darkContainerHigh: Color(0xFF203777),
  darkContainerHighest: Color(0xFF2A448A),
  darkChipSelected: Color(0xFF465A94),
  darkTertiary: Color(0xFFFF75A4),
  accentGradient: [Color(0xFF7582F1), Color(0xFFFFC24A)],
  onAccent: Color(0xFF18224E),
  contentBackground: Color(0xFFFFEFF3),
  contentFrame: Color(0xFFFF75A4),
  contentText: Color(0xFF33438A),
);

const desertLagoonPalette = AppPalette(
  id: 'lagoa-deserto',
  label: 'Lagoa do Deserto',
  seed: Color(0xFF087A80),
  darkBackground: Color(0xFF092024),
  darkCard: Color(0xFF123035),
  darkContainerHigh: Color(0xFF1A3F45),
  darkContainerHighest: Color(0xFF234F55),
  darkChipSelected: Color(0xFF346268),
  darkTertiary: Color(0xFFEC9270),
  multicolorLight: true,
  accentGradient: [Color(0xFF74C4BE), Color(0xFFEC9270)],
  onAccent: Color(0xFF132C2D),
  contentBackground: Color(0xFFFFDED3),
  contentFrame: Color(0xFF087A80),
  contentText: Color(0xFF35565A),
);

const solarNavyPalette = AppPalette(
  id: 'solar-marinho',
  label: 'Solar Marinho',
  seed: Color(0xFF263A82),
  darkBackground: Color(0xFF0A1538),
  darkCard: Color(0xFF122249),
  darkContainerHigh: Color(0xFF1B2E5B),
  darkContainerHighest: Color(0xFF243B6D),
  darkChipSelected: Color(0xFF3A4D7E),
  darkTertiary: Color(0xFFFFC64D),
  multicolorLight: true,
  accentGradient: [Color(0xFF7585F8), Color(0xFFFFC64D)],
  onAccent: Color(0xFF17204A),
  contentBackground: Color(0xFFFFEEF2),
  contentFrame: Color(0xFFFF78A4),
  contentText: Color(0xFF2C3D7C),
);

/// Todas as paletas, na ordem em que aparecem nas configurações. A primeira
/// (a oficial, do morceguinho) é a padrão.
const appPalettes = [
  batPalette,
  lavenderPalette,
  dahliaPalette,
  mintPalette,
  peachPalette,
  rosePalette,
  triadPalette,
  squarePalette,
  auroraCoralPalette,
  classicTurquoisePalette,
  vintageTurquoisePalette,
  sunsetRosePalette,
  oceanBreezePalette,
  lilacCreamPalette,
  pitayaLimePalette,
  blushSagePalette,
  citrusGraphitePalette,
  mistyMeadowPalette,
  neonOrchidPalette,
  coastalGoldPalette,
  midnightCandyPalette,
  emberSandPalette,
  berryCreamPalette,
  terracottaLagoonPalette,
  fuchsiaMintPalette,
  tropicalPopPalette,
  skyLemonPalette,
  nocturneSagePalette,
  cyberPastelPalette,
  electricCitrusPalette,
  rivieraPinkPalette,
  desertLagoonPalette,
  solarNavyPalette,
];

/// A paleta com [id], ou a padrão se não houver (ex.: preferência antiga).
AppPalette paletteById(String? id) =>
    appPalettes.firstWhere((p) => p.id == id, orElse: () => appPalettes.first);
