import '../../../app/language_controller.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/drawing_layer.dart';
import '../option_pill_button.dart';
import '../panel_rows.dart';
import 'eraser_glyph.dart';

/// Resumo da aba "Pincel" no cabeçalho do painel: quantos traços há.
String drawingSummary(DrawingLayer layer) => switch (layer.strokes.length) {
  0 => tr('Nenhum', 'None'),
  1 => tr('1 traço', '1 stroke'),
  final n => tr('$n traços', '$n strokes'),
};

/// Uma ferramenta a mais na linha do Pincel que não é de traço — a Borracha
/// mágica de "Editar imagem", que mora em `features/photo` e por isso entra
/// aqui de fora, sem o `core` conhecê-la.
class DrawingPanelExtraTool {
  const DrawingPanelExtraTool({
    required this.id,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  /// Para a chave do botão (`drawingTool-<id>`).
  final String id;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;
}

/// Painel do Pincel — o mesmo em Editar imagem, Editar SVG e no "..." de
/// uma foto da Montagem: ferramenta, cor e opacidade (só no pincel),
/// tamanho e as ações de limpar e enquadrar.
///
/// O pincel ([brush]) é estado de tela, não passo de desfazer: só os traços
/// entram no histórico.
class DrawingPanel extends StatelessWidget {
  const DrawingPanel({
    super.key,
    required this.brush,
    required this.onBrushChanged,
    required this.tools,
    required this.sourceShortestSide,
    required this.onPickColor,
    required this.onClear,
    this.onFitView,
    this.enabled = true,
    this.extraTools = const [],
    this.body,
  });

  final DrawingBrush brush;
  final ValueChanged<DrawingBrush> onBrushChanged;

  /// As ferramentas oferecidas aqui: [DrawingTool.cutout] só entra numa foto
  /// parada.
  final List<DrawingTool> tools;

  /// Menor lado da imagem de origem, para o tamanho aparecer em pixels dela.
  final double sourceShortestSide;

  final VoidCallback onPickColor;

  /// `null` com o desenho vazio (não há o que limpar).
  final VoidCallback? onClear;

  /// `null` com a prévia enquadrada; senão volta o zoom ao normal.
  final VoidCallback? onFitView;

  final bool enabled;

  /// Ferramentas a mais, depois das de traço, na mesma linha. Com uma delas
  /// escolhida ([DrawingPanelExtraTool.selected]), nenhuma de traço aparece
  /// marcada, e tocar numa de traço chega por [onBrushChanged] — quem chama
  /// desliga a extra ali.
  final List<DrawingPanelExtraTool> extraTools;

  /// Os controles da ferramenta extra escolhida, no lugar dos do pincel
  /// (dica, cor, opacidade, tamanho e limpar). Só vale com uma extra
  /// escolhida.
  final Widget? body;

  /// Ícone de cada ferramenta de traço. A borracha não existe no pacote de
  /// ícones e é desenhada ([EraserGlyph]); por isso o construtor recebe a
  /// cor e o tamanho, como o [OptionPillButton.iconBuilder].
  static Widget iconFor(DrawingTool tool, Color color, double size) =>
      switch (tool) {
        DrawingTool.pen => Icon(Icons.brush_rounded, color: color, size: size),
        DrawingTool.eraser => EraserGlyph(color: color, size: size),
        DrawingTool.cutout => Icon(
          Icons.layers_clear_rounded,
          color: color,
          size: size,
        ),
      };

  static String _hintFor(DrawingTool tool) => switch (tool) {
    DrawingTool.pen => tr(
      'Um dedo desenha; dois dedos dão zoom.',
      'One finger draws; two fingers zoom.',
    ),
    DrawingTool.eraser => tr(
      'Apaga só os traços do pincel — a imagem fica intacta.',
      'Erases only brush strokes — the image stays intact.',
    ),
    DrawingTool.cutout => tr(
      'Apaga a própria imagem, deixando-a transparente.',
      'Erases the image itself, making it transparent.',
    ),
  };

  /// O slider anda em [0, 1] e o tamanho cresce pelo quadrado: a ponta fina,
  /// onde um décimo de ponto faz diferença, ganha mais curso que a grossa.
  static double _percentFor(double t) =>
      DrawingBrush.minPercent +
      (DrawingBrush.maxPercent - DrawingBrush.minPercent) * t * t;

  static double _sliderFor(double percent) => math.sqrt(
    ((percent - DrawingBrush.minPercent) /
            (DrawingBrush.maxPercent - DrawingBrush.minPercent))
        .clamp(0.0, 1.0),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pixels = math.max(
      1,
      (brush.sizePercent * sourceShortestSide / 100).round(),
    );
    final linkStyle = TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
    final tool = tools.contains(brush.tool) ? brush.tool : tools.first;
    final extraActive = extraTools.any((t) => t.selected);
    final buttons = [
      for (final option in tools)
        OptionPillButton(
          key: ValueKey('drawingTool-${option.name}'),
          label: option.label,
          iconBuilder: (color, size) => iconFor(option, color, size),
          selected: !extraActive && tool == option,
          onPressed: enabled
              ? () => onBrushChanged(brush.copyWith(tool: option))
              : null,
        ),
      for (final extra in extraTools)
        OptionPillButton(
          key: ValueKey('drawingTool-${extra.id}'),
          label: extra.label,
          icon: extra.icon,
          selected: extra.selected,
          onPressed: enabled ? extra.onSelected : null,
        ),
    ];
    // Uma linha só, rolando na horizontal: quatro ferramentas não cabem numa
    // tela de 360dp, e quebrar em duas linhas comeria a altura do painel.
    final toolRow = SingleChildScrollView(
      key: const ValueKey('drawingToolRow'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (i, button) in buttons.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            button,
          ],
        ],
      ),
    );

    final extraBody = body;
    if (extraActive && extraBody != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [toolRow, const SizedBox(height: 8), extraBody],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        toolRow,
        const SizedBox(height: 6),
        Text(
          _hintFor(tool),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (tool == DrawingTool.pen) ...[
          PanelColorRow(
            key: const ValueKey('drawingColorRow'),
            label: tr('Cor', 'Color'),
            color: brush.color,
            onTap: enabled ? onPickColor : () {},
          ),
          PanelSliderRow(
            sliderKey: const ValueKey('drawingOpacitySlider'),
            label: tr('Opacidade', 'Opacity'),
            valueLabel: '${(brush.opacity * 100).round()}%',
            value: brush.opacity,
            min: 0.1,
            max: 1,
            divisions: 18,
            onChangeStart: () {},
            onChanged: (v) => onBrushChanged(brush.copyWith(opacity: v)),
          ),
        ],
        PanelSliderRow(
          sliderKey: const ValueKey('drawingSizeSlider'),
          label: tr('Tamanho', 'Size'),
          valueLabel: '${pixels}px',
          value: _sliderFor(brush.sizePercent),
          min: 0,
          max: 1,
          onChangeStart: () {},
          onChanged: (t) =>
              onBrushChanged(brush.withSizePercent(_percentFor(t))),
        ),
        Wrap(
          spacing: 4,
          children: [
            TextButton.icon(
              key: const ValueKey('drawingClear'),
              style: linkStyle,
              onPressed: enabled ? onClear : null,
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: Text(tr('Limpar desenho', 'Clear drawing')),
            ),
            if (onFitView != null)
              TextButton.icon(
                style: linkStyle,
                onPressed: onFitView,
                icon: const Icon(Icons.zoom_out_map_rounded, size: 18),
                label: Text(tr('Enquadrar', 'Fit to view')),
              ),
          ],
        ),
      ],
    );
  }
}
