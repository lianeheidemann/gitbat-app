import 'package:flutter/material.dart';

import '../app_palette.dart';
import 'palette_refinement.dart';

// Paletas com as cores definidas uma a uma nos dois temas, sobre o
// acabamento de [refinePaletteLight]/[refinePaletteDark].

ColorScheme _lavenderLight(ColorScheme base) => refinePaletteLight(
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

ColorScheme _lavenderDark(ColorScheme base) => refinePaletteDark(
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
ColorScheme _dahliaLight(ColorScheme base) => refinePaletteLight(
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

ColorScheme _dahliaDark(ColorScheme base) => refinePaletteDark(
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

ColorScheme _mintLight(ColorScheme base) => refinePaletteLight(
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

ColorScheme _mintDark(ColorScheme base) => refinePaletteDark(
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

ColorScheme _peachLight(ColorScheme base) => refinePaletteLight(
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

ColorScheme _peachDark(ColorScheme base) => refinePaletteDark(
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

ColorScheme _roseLight(ColorScheme base) => refinePaletteLight(
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

ColorScheme _roseDark(ColorScheme base) => refinePaletteDark(
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

ColorScheme _triadLight(ColorScheme base) => refinePaletteLight(
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

ColorScheme _triadDark(ColorScheme base) => refinePaletteDark(
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

ColorScheme _squareLight(ColorScheme base) => refinePaletteLight(
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

ColorScheme _squareDark(ColorScheme base) => refinePaletteDark(
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
