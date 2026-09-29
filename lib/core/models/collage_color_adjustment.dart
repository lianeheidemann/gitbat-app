import 'package:flutter/material.dart';

import 'color_adjustments.dart';
import '../../app/translations.dart';

/// Os ajustes de cor oferecidos na folha "Ajustar cor" de uma foto da
/// montagem, na ordem em que aparecem na fileira de bolinhas. Cada um sabe
/// ler o próprio valor de uma célula e devolver a célula com o valor novo,
/// então a tela é uma lista só — sem um `switch` gigante repetido a cada
/// controle.
///
/// Todos valem de `-1` a `1`, com `0` no neutro (o meio da régua).
enum CollageColorAdjustment {
  brightness('Brilho', Icons.light_mode_outlined),
  exposure('Exposição', Icons.exposure),
  contrast('Contraste', Icons.contrast),
  highlights('Realces', Icons.wb_sunny_outlined),
  shadows('Sombras', Icons.nightlight_outlined),
  saturation('Saturação', Icons.water_drop_outlined),
  hue('Matiz', Icons.palette_outlined),
  temperature('Temperatura', Icons.thermostat);

  const CollageColorAdjustment(this.labelPt, this.icon);

  final String labelPt;
  String get label => trKey(labelPt);
  final IconData icon;

  /// Mesma leitura de `valueOf` (a da célula da montagem, em
  /// `collage_cell.dart`), para as telas que guardam os ajustes num
  /// [ColorAdjustments] só (moldura e edição de GIF) em vez de um por
  /// célula.
  double valueIn(ColorAdjustments a) => switch (this) {
    CollageColorAdjustment.brightness => a.brightness,
    CollageColorAdjustment.exposure => a.exposure,
    CollageColorAdjustment.contrast => a.contrast,
    CollageColorAdjustment.highlights => a.highlights,
    CollageColorAdjustment.shadows => a.shadows,
    CollageColorAdjustment.saturation => a.saturation,
    CollageColorAdjustment.hue => a.hue,
    CollageColorAdjustment.temperature => a.temperature,
  };

  ColorAdjustments applyIn(ColorAdjustments a, double value) => switch (this) {
    CollageColorAdjustment.brightness => a.copyWith(brightness: value),
    CollageColorAdjustment.exposure => a.copyWith(exposure: value),
    CollageColorAdjustment.contrast => a.copyWith(contrast: value),
    CollageColorAdjustment.highlights => a.copyWith(highlights: value),
    CollageColorAdjustment.shadows => a.copyWith(shadows: value),
    CollageColorAdjustment.saturation => a.copyWith(saturation: value),
    CollageColorAdjustment.hue => a.copyWith(hue: value),
    CollageColorAdjustment.temperature => a.copyWith(temperature: value),
  };
}
