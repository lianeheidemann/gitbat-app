import 'package:flutter/material.dart';

import '../../core/models/default_colors.dart';
import '../app_palette.dart';

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
