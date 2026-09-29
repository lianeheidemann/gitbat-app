import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../core/models/size_estimate.dart';
import 'app_palette.dart';

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

/// Monta o ThemeData do app para o modo claro ou escuro, na [palette]
/// escolhida nas configurações.
///
/// A partir da cor semente da paleta, gera um ColorScheme via Material 3 e,
/// no modo escuro, substitui as cores de superfície pelos tons próprios da
/// paleta (mais neutros que os gerados automaticamente).
ThemeData buildTheme(Brightness brightness, [AppPalette palette = batPalette]) {
  final base = ColorScheme.fromSeed(
    seedColor: palette.seed,
    brightness: brightness,
  );
  // No escuro, troca as superfícies geradas pelo ColorScheme.fromSeed por
  // tons neutros definidos à mão, mantendo a cor primária.
  final generated = brightness == Brightness.dark
      ? base.copyWith(
          primary: palette.seed,
          tertiary: palette.darkTertiary,
          surface: palette.darkBackground,
          surfaceContainerLow: palette.darkCard,
          surfaceContainer: palette.darkCard,
          surfaceContainerHigh: palette.darkContainerHigh,
          surfaceContainerHighest: palette.darkContainerHighest,
        )
      : base;
  final refine = brightness == Brightness.dark
      ? palette.refineDark
      : palette.refineLight;
  final refined = refine == null ? generated : refine(generated);
  final scheme = brightness == Brightness.light && palette.multicolorLight
      ? _multicolorLightScheme(refined, palette)
      : refined;

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
    extensions: [
      AppAccent(gradient: palette.accentGradient, onAccent: palette.onAccent),
    ],
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? palette.darkBackground
        : scheme.surface,
    appBarTheme: AppBarTheme(
      // Ícones da barra de status (hora, bateria) escuros no tema claro e
      // claros no escuro — antes ficavam brancos sobre o fundo claro.
      systemOverlayStyle: brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
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
          ? palette.darkCard
          : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.65)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      selectedColor: brightness == Brightness.dark
          ? palette.darkChipSelected
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

ColorScheme _multicolorLightScheme(ColorScheme base, AppPalette palette) {
  final secondarySource = _furthestColor(
    palette.seed,
    palette.accentGradient,
  );
  final tertiaryCandidates = <Color>[
    palette.darkTertiary?,
    palette.contentFrame,
    ...palette.accentGradient,
  ];
  final tertiarySource = _mostDistinctThirdColor(
    palette.seed,
    secondarySource,
    tertiaryCandidates,
  );
  final secondary = _lightRoleColor(secondarySource);
  final tertiary = _lightRoleColor(tertiarySource);
  final surface = Color.lerp(palette.contentBackground, Colors.white, 0.58)!;

  return base.copyWith(
    secondary: secondary,
    onSecondary: Colors.white,
    secondaryContainer: Color.lerp(secondarySource, Colors.white, 0.76),
    onSecondaryContainer: _lightRoleColor(secondarySource),
    tertiary: tertiary,
    onTertiary: Colors.white,
    tertiaryContainer: Color.lerp(tertiarySource, Colors.white, 0.76),
    onTertiaryContainer: _lightRoleColor(tertiarySource),
    surface: surface,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color.lerp(surface, secondarySource, 0.07),
    surfaceContainer: Color.lerp(surface, tertiarySource, 0.09),
    surfaceContainerHigh: Color.lerp(
      palette.contentBackground,
      secondarySource,
      0.12,
    ),
    surfaceContainerHighest: Color.lerp(
      palette.contentBackground,
      tertiarySource,
      0.16,
    ),
    outline: Color.lerp(base.outline, secondary, 0.28),
    outlineVariant: Color.lerp(base.outlineVariant, tertiarySource, 0.18),
    surfaceTint: base.primary,
  );
}

Color _furthestColor(Color reference, Iterable<Color> colors) {
  var result = colors.first;
  for (final candidate in colors.skip(1)) {
    if (_colorDistance(reference, candidate) >
        _colorDistance(reference, result)) {
      result = candidate;
    }
  }
  return result;
}

Color _mostDistinctThirdColor(
  Color primary,
  Color secondary,
  Iterable<Color> colors,
) {
  final distinctColors = colors
      .where((color) => color != primary && color != secondary)
      .toList();
  final candidates = distinctColors.isEmpty ? colors : distinctColors;

  var result = candidates.first;
  var resultScore = _combinedColorDistance(primary, secondary, result);
  for (final candidate in candidates.skip(1)) {
    final candidateScore = _combinedColorDistance(
      primary,
      secondary,
      candidate,
    );
    if (candidateScore > resultScore) {
      result = candidate;
      resultScore = candidateScore;
    }
  }
  return result;
}

int _combinedColorDistance(Color first, Color second, Color candidate) {
  return _colorDistance(first, candidate) + _colorDistance(second, candidate);
}

int _colorDistance(Color first, Color second) {
  final firstValue = first.toARGB32();
  final secondValue = second.toARGB32();
  final red = ((firstValue >> 16) & 0xff) - ((secondValue >> 16) & 0xff);
  final green = ((firstValue >> 8) & 0xff) - ((secondValue >> 8) & 0xff);
  final blue = (firstValue & 0xff) - (secondValue & 0xff);
  return red * red + green * green + blue * blue;
}

Color _lightRoleColor(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withSaturation(hsl.saturation.clamp(0.38, 0.82).toDouble())
      .withLightness(hsl.lightness.clamp(0.30, 0.44).toDouble())
      .toColor();
}

/// Degradê de destaque da paleta atual (botão principal da tela de
/// resultado), lido com `Theme.of(context).extension<AppAccent>()`.
class AppAccent extends ThemeExtension<AppAccent> {
  const AppAccent({required this.gradient, required this.onAccent});

  final List<Color> gradient;
  final Color onAccent;

  @override
  AppAccent copyWith({List<Color>? gradient, Color? onAccent}) => AppAccent(
    gradient: gradient ?? this.gradient,
    onAccent: onAccent ?? this.onAccent,
  );

  @override
  AppAccent lerp(AppAccent? other, double t) {
    if (other == null || other.gradient.length != gradient.length) {
      return t < 0.5 ? this : (other ?? this);
    }
    return AppAccent(
      gradient: [
        for (var i = 0; i < gradient.length; i++)
          Color.lerp(gradient[i], other.gradient[i], t)!,
      ],
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
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
