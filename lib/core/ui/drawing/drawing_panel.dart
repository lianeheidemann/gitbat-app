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
  /// parada. [DrawingTool.pen] e [DrawingTool.eraser] formam o grupo
  /// "Pincel" (a Borracha é uma subopção dele, "Pintar" / "Borracha").
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
  /// desliga a extra ali. Voltar ao Pincel também.
  final List<DrawingPanelExtraTool> extraTools;

  /// Os controles da ferramenta extra escolhida, no lugar dos do pincel
  /// (cor, opacidade, tamanho e limpar). Só vale com uma extra
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

    // A Borracha só apaga o que o Pincel pintou, então é uma subopção dele
    // (Pintar / Borracha) e não uma ferramenta ao lado. A linha de cima tem
    // os grupos: Pincel, Transparência e as extras.
    final inPencil = tool == DrawingTool.pen || tool == DrawingTool.eraser;
    final hasEraser = tools.contains(DrawingTool.eraser);
    final groups = [
      OptionPillButton(
        key: const ValueKey('drawingTool-pen'),
        label: DrawingTool.pen.label,
        iconBuilder: (color, size) => iconFor(DrawingTool.pen, color, size),
        selected: !extraActive && inPencil,
        // Voltar ao Pincel volta ao modo em que ele estava (Pintar ou
        // Borracha), e tira a ferramenta extra de cena.
        onPressed: enabled
            ? () => onBrushChanged(brush.copyWith(tool: brush.pencilMode))
            : null,
      ),
      if (tools.contains(DrawingTool.cutout))
        OptionPillButton(
          key: const ValueKey('drawingTool-cutout'),
          label: DrawingTool.cutout.label,
          iconBuilder: (color, size) =>
              iconFor(DrawingTool.cutout, color, size),
          selected: !extraActive && tool == DrawingTool.cutout,
          onPressed: enabled
              ? () => onBrushChanged(brush.copyWith(tool: DrawingTool.cutout))
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
    // Uma linha só, rolando na horizontal: com a Borracha mágica os grupos
    // não cabem numa tela de 360dp, e quebrar em duas linhas comeria a
    // altura do painel. Um grupo sozinho (SVG, foto animada) não precisa de
    // linha: só a escolha de Pintar / Borracha.
    final Widget? toolRow = groups.length < 2
        ? null
        : SingleChildScrollView(
            key: const ValueKey('drawingToolRow'),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (i, button) in groups.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  button,
                ],
              ],
            ),
          );

    // Pintar / Borracha, repartidos em partes iguais como um seletor de
    // modo, só com o Pincel escolhido.
    final Widget? modeRow = (!extraActive && inPencil && hasEraser)
        ? Row(
            key: const ValueKey('drawingModeRow'),
            children: [
              Expanded(
                child: OptionPillButton(
                  key: const ValueKey('drawingMode-pen'),
                  label: tr('Pintar', 'Paint'),
                  iconBuilder: (color, size) =>
                      iconFor(DrawingTool.pen, color, size),
                  selected: tool == DrawingTool.pen,
                  expand: true,
                  onPressed: enabled
                      ? () => onBrushChanged(
                          brush.copyWith(tool: DrawingTool.pen),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OptionPillButton(
                  key: const ValueKey('drawingMode-eraser'),
                  label: DrawingTool.eraser.label,
                  iconBuilder: (color, size) =>
                      iconFor(DrawingTool.eraser, color, size),
                  selected: tool == DrawingTool.eraser,
                  expand: true,
                  onPressed: enabled
                      ? () => onBrushChanged(
                          brush.copyWith(tool: DrawingTool.eraser),
                        )
                      : null,
                ),
              ),
            ],
          )
        : null;

    final extraBody = body;
    if (extraActive && extraBody != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [?toolRow, const SizedBox(height: 8), extraBody],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (toolRow != null) ...[toolRow, const SizedBox(height: 8)],
        ?modeRow,
        const SizedBox(height: 4),
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
