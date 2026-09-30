import 'package:flutter/material.dart';

/// Acabamento claro das paletas com as cores definidas uma a uma (ver
/// `classic_palettes.dart`): os papéis cromáticos, as superfícies e os
/// contornos saem das cores passadas, e o resto do esquema gerado pela
/// semente fica como está.
ColorScheme refinePaletteLight(
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

/// Espelho de [refinePaletteLight] para o tema escuro: as superfícies
/// continuam as do esquema escuro da paleta, e os tons "on" dos containers
/// saem das próprias cores, clareadas.
ColorScheme refinePaletteDark(
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
