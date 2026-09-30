import 'package:flutter_test/flutter_test.dart';
import 'package:gitbat/app/app_palette.dart';
import 'package:gitbat/app/editor_defaults.dart';
import 'package:gitbat/app/theme_controller.dart';
import 'package:gitbat/core/ui/color_picker_sheet.dart';
import 'package:gitbat/features/collage/models/collage_background.dart';
import 'package:gitbat/features/collage/models/collage_cell.dart';
import 'package:gitbat/features/collage/models/collage_defaults.dart';
import 'package:gitbat/features/collage/models/collage_layout.dart';
import 'package:gitbat/features/collage/models/collage_settings.dart';
import 'package:gitbat/core/models/default_colors.dart';
import 'package:gitbat/core/models/frame_settings.dart';

/// O que estes testes seguram é a promessa de que as duas cores padrão são as
/// *mesmas* nas três telas de edição. Sem isso, uma delas volta a ser branco
/// ou preto num modelo só e a diferença só aparece no aparelho.
void main() {
  test('fundo e moldura do vídeo/moldura em foto usam as cores padrão', () {
    const frame = FrameSettings();
    expect(frame.color, defaultFrameColor);
    expect(frame.backgroundColor, defaultBackgroundColor);
  });

  test('borda e fundo da montagem usam as mesmas cores', () {
    const settings = CollageSettings(
      layout: CollageLayout(kind: CollageLayoutKind.grid2x2),
    );
    expect(settings.borderColor, defaultFrameColor);
    expect(settings.background.color, defaultBackgroundColor);
  });

  test('a borda e o fundo de cada foto da montagem também', () {
    const cell = CollageCellSettings();
    expect(cell.borderColor, defaultFrameColor);
    expect(cell.background.color, defaultBackgroundColor);
  });

  test('a cor não liga nada sozinha: fundo continua transparente', () {
    expect(const FrameSettings().transparentBackground, isTrue);
    expect(const CollageBackground().mode, CollageBackgroundMode.transparent);
  });

  group('as cores padrão das telas de edição seguem a paleta da interface', () {
    tearDown(() => paletteNotifier.value = appPalettes.first);

    test('a oficial usa as mesmas cores fixas dos modelos', () {
      paletteNotifier.value = batPalette;
      expect(EditorDefaults.background, defaultBackgroundColor);
      expect(EditorDefaults.frame, defaultFrameColor);
      expect(EditorDefaults.text, defaultTextColor);
    });

    for (final palette in appPalettes) {
      test('paleta ${palette.label}', () {
        paletteNotifier.value = palette;
        final frame = EditorDefaults.frameSettings();
        expect(frame.color, palette.contentFrame);
        expect(frame.backgroundColor, palette.contentBackground);

        final collage = CollageSettings.forLayout(
          const CollageLayout(kind: CollageLayoutKind.grid2x2),
          const [],
          cellStyle: CollageDefaults.cell(),
        );
        for (final cell in collage.cells) {
          expect(cell.borderColor, palette.contentFrame);
          expect(cell.background.color, palette.contentBackground);
        }
        // Área nova sem nenhuma foto ainda: herda o estilo das vazias.
        expect(
          collage.withSharedCellStyle(const CollageCellSettings()).borderColor,
          palette.contentFrame,
        );

        expect(
          collageColorSwatches,
          containsAll([
            palette.contentBackground,
            palette.contentFrame,
            palette.contentText,
          ]),
        );
      });
    }
  });
}
