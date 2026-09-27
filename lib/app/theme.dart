import 'package:flutter/material.dart';

import '../core/models/size_estimate.dart';

const _seed = Color(0xFFC9A8FF);
const _darkBackground = Color(0xFF101014);
const _darkCard = Color(0xFF1A191F);

// Tamanhos padrão do app inteiro, num lugar só — a interface é compacta de
// propósito (preferência da dona do app). Junto com a escala de texto de
// [appTextScale], em `main.dart`, é daqui que tudo diminui ou cresce.

/// Fator aplicado a todo texto do app, por cima da escolha de fonte do
/// sistema — inclusive aos tamanhos escritos à mão nas telas.
const appTextScale = 0.9;
const _appBarTitleSize = 20.0;
const _buttonHeight = 40.0;
const _buttonTextSize = 14.0;
const _buttonRadius = 14.0;
const _fieldRadius = 12.0;
const _dialogRadius = 20.0;

/// Monta o ThemeData do app para o modo claro ou escuro.
///
/// A partir da cor semente [_seed], gera um ColorScheme via Material 3 e,
/// no modo escuro, substitui as cores de superfície por tons próprios
/// (mais neutros que os gerados automaticamente).
ThemeData buildTheme(Brightness brightness) {
  final base = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  // No escuro, troca as superfícies geradas pelo ColorScheme.fromSeed por
  // tons neutros definidos à mão, mantendo a cor primária.
  final scheme = brightness == Brightness.dark
      ? base.copyWith(
          primary: _seed,
          surface: _darkBackground,
          surfaceContainerLow: _darkCard,
          surfaceContainer: _darkCard,
          surfaceContainerHigh: const Color(0xFF211F28),
          surfaceContainerHighest: const Color(0xFF26232D),
        )
      : base;

  const buttonText = TextStyle(
    fontSize: _buttonTextSize,
    fontWeight: FontWeight.w700,
  );
  const buttonPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 8);
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(_buttonRadius),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? _darkBackground
        : scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: _appBarTitleSize,
        fontWeight: FontWeight.w700,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(_buttonHeight),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: buttonText.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: buttonPadding,
        textStyle: buttonText.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      dense: true,
      minVerticalPadding: 6,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 3,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_dialogRadius),
      ),
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_dialogRadius),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: brightness == Brightness.dark
          ? _darkCard
          : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.65)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      selectedColor: brightness == Brightness.dark
          ? const Color(0xFF5D4D72)
          : scheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      // Com a cor explícita: só o tamanho aqui fazia o rótulo herdar a cor
      // do texto em volta, e no tema claro os chips (ex.: proporções do
      // recorte) ficavam com texto branco sobre fundo branco.
      labelStyle: TextStyle(
        fontSize: 13,
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? scheme.onSurface.withValues(alpha: 0.38)
              : scheme.onSurface,
        ),
      ),
    ),
    dividerColor: scheme.outlineVariant.withValues(alpha: 0.45),
  );
}

/// Cor associada a cada faixa de peso, usada no painel de estimativa.
Color verdictColor(SizeVerdict verdict, ColorScheme scheme) {
  return switch (verdict) {
    SizeVerdict.light => const Color(0xFF58C78C),
    SizeVerdict.good => const Color(0xFFB8B36A),
    SizeVerdict.heavy => const Color(0xFFE6A15D),
    SizeVerdict.tooHeavy => const Color(0xFFE57373),
  };
}
