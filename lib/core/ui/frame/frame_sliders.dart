import 'package:flutter/material.dart';

import '../../models/frame_settings.dart';
import '../panel_rows.dart';

/// Espessura da borda (moldura procedural, aba "Borda"), em pixels na
/// resolução de referência.
class FrameThicknessRow extends StatelessWidget {
  const FrameThicknessRow({
    super.key,
    required this.frame,
    required this.onChangeStart,
    required this.onChanged,
  });

  final FrameSettings frame;
  final VoidCallback onChangeStart;
  final ValueChanged<FrameSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final thickness = frame.thicknessAtReference.clamp(0, 24).toDouble();
    return PanelSliderRow(
      label: 'Espessura da borda',
      valueLabel: '${thickness.round()}px',
      value: thickness,
      min: 0,
      max: 24,
      divisions: 24,
      onChangeStart: onChangeStart,
      onChanged: (v) => onChanged(frame.copyWith(thicknessAtReference: v)),
    );
  }
}

/// Arredondamento dos cantos: no mínimo o canto é reto; no máximo
/// ([FrameSettings.maxCornerRatio]) a borda fica completamente arredondada.
/// O valor aparece como porcentagem desse máximo, não em pixels — o
/// arredondamento é proporcional ao canvas, não absoluto — e anda de 1 em
/// 1%.
class CornerRadiusRow extends StatelessWidget {
  const CornerRadiusRow({
    super.key,
    required this.frame,
    required this.onChangeStart,
    required this.onChanged,
  });

  final FrameSettings frame;
  final VoidCallback onChangeStart;
  final ValueChanged<FrameSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    const max = FrameSettings.maxCornerRatio;
    final ratio = frame.cornerRatio.clamp(0.0, max).toDouble();
    return PanelSliderRow(
      label: 'Arredondamento dos cantos',
      valueLabel: '${(ratio / max * 100).round()}%',
      value: ratio,
      min: 0,
      max: max,
      // Um passo por ponto percentual (0% a 100% do máximo).
      divisions: 100,
      onChangeStart: onChangeStart,
      onChanged: (v) => onChanged(frame.copyWith(cornerRatio: v)),
    );
  }
}

/// Zoom do conteúdo dentro da moldura de imagem.
class ContentZoomRow extends StatelessWidget {
  const ContentZoomRow({
    super.key,
    required this.frame,
    required this.onChangeStart,
    required this.onChanged,
  });

  final FrameSettings frame;
  final VoidCallback onChangeStart;
  final ValueChanged<FrameSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final zoom = frame.contentZoom
        .clamp(FrameSettings.minContentZoom, FrameSettings.maxContentZoom)
        .toDouble();
    final percent = (zoom * 100).round();
    return PanelSliderRow(
      sliderKey: const ValueKey('frameContentZoomSlider'),
      label: 'Zoom do conteúdo',
      valueLabel: '$percent%',
      value: zoom,
      min: FrameSettings.minContentZoom,
      max: FrameSettings.maxContentZoom,
      divisions: 58,
      onChangeStart: onChangeStart,
      onChanged: (v) => onChanged(frame.copyWith(contentZoom: v)),
    );
  }
}
