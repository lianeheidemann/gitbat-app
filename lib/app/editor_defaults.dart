import 'dart:ui' show Color;

import '../core/models/frame_settings.dart';
import 'app_palette.dart';
import 'theme_controller.dart';

/// Cores que já vêm escolhidas nas telas de edição, na paleta atual da
/// interface: fundo e moldura/borda (que aparecem ao ligar essas opções) e a
/// cor de todo texto novo. Lidas na hora em que a edição começa ou o item é
/// criado — trocar de paleta não repinta o que já foi feito.
abstract final class EditorDefaults {
  static AppPalette get _palette => paletteNotifier.value;

  static Color get background => _palette.contentBackground;
  static Color get frame => _palette.contentFrame;
  static Color get text => _palette.contentText;

  /// Moldura do vídeo, da foto e do SVG, ainda desligada.
  static FrameSettings frameSettings() =>
      FrameSettings(color: frame, backgroundColor: background);
}
