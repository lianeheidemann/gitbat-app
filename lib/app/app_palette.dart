import 'translations.dart';
import 'package:flutter/material.dart';

import 'palettes/bat_palette.dart';
import 'palettes/classic_palettes.dart';
import 'palettes/v2_palettes.dart';

// As paletas moram em `palettes/`, por grupo; quem importa este arquivo
// continua enxergando todas.
export 'palettes/bat_palette.dart';
export 'palettes/classic_palettes.dart';
export 'palettes/v2_palettes.dart';

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
