import 'package:flutter/material.dart';

import 'app/licenses.dart';
import 'core/models/collage_text.dart';
import 'app/preview_background_controller.dart';
import 'core/services/bundled_font_store.dart';
import 'core/services/bundled_frame_store.dart';
import 'core/services/bundled_sticker_store.dart';
import 'app/theme.dart';
import 'app/theme_controller.dart';
import 'features/home/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Exigência da LGPL do FFmpeg: o aviso precisa estar acessível no app.
  registerThirdPartyLicenses();
  await loadThemeMode();
  await loadPalette();
  await loadPreviewCheckerboardPreference();
  // Registra as fontes de `assets/fonts` antes da primeira tela, para a
  // lista de fontes do texto já nascer completa.
  final fonts = await const BundledFontStore().loadAll();
  bundledCollageFonts = [
    (null, 'Padrão'),
    for (final font in fonts) (font.family, font.label),
  ];
  bundledStickerAssets = await loadBundledStickerAssets();
  bundledImageFrames = await loadBundledImageFrames();
  runApp(const GitBatApp());
}

/// Widget raiz do app: configura o MaterialApp com os temas claro/escuro na
/// paleta escolhida e define a HomePage como tela inicial.
class GitBatApp extends StatelessWidget {
  const GitBatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeModeNotifier, paletteNotifier]),
      builder: (context, _) {
        final palette = paletteNotifier.value;
        return MaterialApp(
          title: 'GitBat',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light, palette),
          darkTheme: buildTheme(Brightness.dark, palette),
          themeMode: themeModeNotifier.value,
          // Todo texto do app um pouco menor ([appTextScale]), por cima da
          // escolha de fonte do sistema — inclusive os tamanhos fixos das
          // telas, que o tema sozinho não alcança.
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: _ScaledTextScaler(media.textScaler, appTextScale),
              ),
              child: child!,
            );
          },
          home: const HomePage(),
        );
      },
    );
  }
}

/// [base] (a escala de fonte do sistema) multiplicada por [factor].
class _ScaledTextScaler extends TextScaler {
  const _ScaledTextScaler(this.base, this.factor);

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  double get textScaleFactor => base.scale(1) * factor;

  @override
  bool operator ==(Object other) =>
      other is _ScaledTextScaler &&
      other.base == base &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
