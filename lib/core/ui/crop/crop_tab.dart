import '../../../app/language_controller.dart';
import 'package:flutter/material.dart';

import '../../models/aspect_preset.dart';
import '../../models/crop_rect.dart';
import '../labeled_section.dart';
import 'crop_controller.dart';
import 'crop_overlay.dart';
import 'crop_size_fields.dart';

/// Estado da aba "Recorte" comum a Editar vídeo, Editar imagem e Editar SVG:
/// as regras do recorte ([rules]), o preset marcado nos chips e os campos de
/// largura/altura.
///
/// Como em [CropController], quem guarda o recorte em si continua sendo a
/// tela — cada uma num lugar diferente e com a própria pilha de desfazer.
class CropTabController {
  CropTabController({
    required this.rules,
    required this.customPreset,
    this.trimPreset,
  });

  final CropController rules;

  /// O chip do recorte livre, que mostra os campos de largura e altura.
  final AspectPreset customPreset;

  /// "Ajustar", nas telas que têm: a tela detecta os pixels visíveis e grava
  /// o resultado (marcando [aspect] com ele), e o recorte fica livre como em
  /// [customPreset].
  final AspectPreset? trimPreset;

  /// Preset marcado nos chips — guardado à parte do recorte porque
  /// "Personalizado" e um preset podem cair no mesmo retângulo (ex.: ao
  /// digitar largura/altura que batem com 1:1), e o chip marcado tem que
  /// continuar sendo o que foi tocado.
  AspectPreset aspect = AspectPreset.presets.first;

  final widthController = TextEditingController();
  final heightController = TextEditingController();
  final widthFocus = FocusNode();
  final heightFocus = FocusNode();

  /// Os chips, na ordem da fileira.
  List<AspectPreset> get presets => [
    AspectPreset.presets.first,
    ?trimPreset,
    ...AspectPreset.presets.skip(1),
    customPreset,
  ];

  /// Recorte sem proporção travada: o livre e "Ajustar".
  bool get isFreeform => aspect == customPreset || aspect == trimPreset;

  /// Proporção travada pelo preset atual, ou `null` num recorte livre.
  double? get lockedRatio => isFreeform ? null : aspect.ratio;

  /// Marca [preset] e devolve o recorte que ele pede: no livre, o atual (ou
  /// 80% da fonte, centralizado); `null` em "Original"; nos outros, a maior
  /// janela centralizada naquela proporção.
  CropRect? select(AspectPreset preset, CropRect? current) {
    assert(preset != trimPreset, '"Ajustar" é aplicado pela tela.');
    aspect = preset;
    if (preset == customPreset) return current ?? rules.defaultCustomCrop();
    final ratio = preset.ratio;
    if (ratio == null) return null;
    return rules.forRatio(ratio);
  }

  /// Um arraste de [displayDelta] numa prévia de [previewSize] (que mostra a
  /// fonte inteira) em pixels da fonte.
  Offset toSourceDelta(Offset displayDelta, Size previewSize) => Offset(
    displayDelta.dx * rules.sourceWidth / previewSize.width,
    displayDelta.dy * rules.sourceHeight / previewSize.height,
  );

  /// [crop] depois de arrastar a alça [handle] por [displayDelta] na prévia,
  /// livre ou travado ao preset marcado. `null` quando nada muda.
  CropRect? resizeFromDisplay(
    CropRect? crop,
    CropHandle handle,
    Offset displayDelta,
    Size previewSize,
  ) {
    if (crop == null || previewSize.width <= 0 || previewSize.height <= 0) {
      return null;
    }
    return rules.resizeBy(
      crop: crop,
      handle: handle,
      sourceDelta: toSourceDelta(displayDelta, previewSize),
      ratio: lockedRatio,
    );
  }

  /// [crop] depois de mover a janela inteira por [displayDelta] na prévia,
  /// sem sair da fonte. Com [centerSnap] (em pixels da prévia), a janela
  /// gruda no centro da fonte quando chega a essa distância dele. `null`
  /// quando nada muda.
  CropRect? moveFromDisplay(
    CropRect? crop,
    Offset displayDelta,
    Size previewSize, {
    double? centerSnap,
  }) {
    if (crop == null || previewSize.width <= 0 || previewSize.height <= 0) {
      return null;
    }
    return rules.moveBy(
      crop: crop,
      sourceDelta: toSourceDelta(displayDelta, previewSize),
      snapDistance: centerSnap == null
          ? null
          : toSourceDelta(Offset(centerSnap, centerSnap), previewSize),
    );
  }

  void dispose() {
    widthController.dispose();
    heightController.dispose();
    widthFocus.dispose();
    heightFocus.dispose();
  }
}

/// Conteúdo da aba "Recorte": os chips de proporção e, com um recorte ativo,
/// os campos de largura/altura (só no recorte livre), o controle "Tamanho da
/// janela" e o botão "Centralizar".
class CropTabPanel extends StatelessWidget {
  const CropTabPanel({
    super.key,
    required this.tab,
    required this.crop,
    required this.onSelectPreset,
    required this.onSubmitWidth,
    required this.onSubmitHeight,
    required this.onResizeStart,
    required this.onResized,
    required this.onCenter,
    this.showPixelUnit = false,
  });

  final CropTabController tab;
  final CropRect? crop;
  final ValueChanged<AspectPreset> onSelectPreset;
  final ValueChanged<String> onSubmitWidth;
  final ValueChanged<String> onSubmitHeight;

  /// Começo do arrasto de "Tamanho da janela" — o ponto de desfazer.
  final VoidCallback onResizeStart;

  /// A janela redimensionada por "Tamanho da janela", a cada passo do
  /// arrasto.
  final ValueChanged<CropRect> onResized;
  final VoidCallback onCenter;

  /// Ver [CropSizeSummary.showPixelUnit].
  final bool showPixelUnit;

  @override
  Widget build(BuildContext context) {
    final crop = this.crop;
    final presets = tab.presets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OptionChips<AspectPreset>(
          options: presets,
          selected: presets.contains(tab.aspect) ? tab.aspect : presets.first,
          // Só a numeração da proporção quando ela existe (o rótulo já é
          // isso) — o texto por extenso ("Quadrado", "Retrato"...) deixava
          // os chips mais largos do que precisava.
          labelBuilder: (preset) => preset.label,
          onSelected: onSelectPreset,
        ),
        if (crop != null) ...[
          const SizedBox(height: 18),
          if (tab.isFreeform) ...[
            CropSizeSummary(crop: crop, showPixelUnit: showPixelUnit),
            const SizedBox(height: 12),
            CropSizeInputs(
              crop: crop,
              widthController: tab.widthController,
              heightController: tab.heightController,
              widthFocus: tab.widthFocus,
              heightFocus: tab.heightFocus,
              onSubmitWidth: onSubmitWidth,
              onSubmitHeight: onSubmitHeight,
              showPixelUnit: showPixelUnit,
            ),
            const SizedBox(height: 12),
          ],
          CropSizeSlider(
            percent: tab.rules.sizePercentOf(crop),
            onChangeStart: onResizeStart,
            onChanged: (percent) =>
                onResized(tab.rules.scaledTo(percent, crop: crop)),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onCenter,
              icon: const Icon(Icons.center_focus_strong_rounded),
              label: Text(tr('Centralizar', 'Center')),
            ),
          ),
        ],
      ],
    );
  }
}
