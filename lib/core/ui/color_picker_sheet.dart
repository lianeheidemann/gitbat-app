import '../../app/language_controller.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'app_message.dart';
import 'dialog_title.dart';
import '../../app/editor_defaults.dart';

/// Swatches rápidos oferecidos antes da roda HSV completa — os mesmos em
/// toda tela que escolhe cor (Montagem, Editar e Moldura em foto), para o
/// app inteiro ficar consistente. Depois do branco e do preto vêm as cores
/// padrão da paleta atual da interface ([EditorDefaults]: fundo, moldura e
/// texto), e então cores fixas de uso geral.
List<Color> get collageColorSwatches {
  final swatches = <Color>{
    const Color(0xFFFFFFFF),
    const Color(0xFF000000),
    EditorDefaults.background,
    EditorDefaults.frame,
    EditorDefaults.text,
    const Color(0xFFE57373),
    const Color(0xFF58C78C),
    // Amarelo vivo (antes, um amarelo-oliva apagado).
    const Color(0xFFFFD54F),
    const Color(0xFF64B5F6),
    const Color(0xFFE6A15D),
  };
  return swatches.toList();
}

/// Abre o bottom sheet de escolha de cor usado em todo o app: swatches
/// rápidos, roda HSV completa ([ColorPicker], pacote `flutter_colorpicker`) e
/// um conta-gotas que amostra um pixel da prévia atual — [previewImageBuilder]
/// rasteriza o que estiver na tela (a montagem inteira, o vídeo/GIF ou a foto
/// com moldura, dependendo de quem chama) para o usuário poder escolher uma
/// cor de qualquer parte visível da prévia, não só de uma paleta fixa.
Future<void> showCollageColorPickerSheet({
  required BuildContext context,
  required String title,
  required Color initialColor,
  required ValueChanged<Color> onColorSelected,
  required Future<ui.Image> Function() previewImageBuilder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _ColorPickerSheet(
      title: title,
      initialColor: initialColor,
      onColorSelected: onColorSelected,
      previewImageBuilder: previewImageBuilder,
    ),
  );
}

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({
    required this.title,
    required this.initialColor,
    required this.onColorSelected,
    required this.previewImageBuilder,
  });

  final String title;
  final Color initialColor;
  final ValueChanged<Color> onColorSelected;
  final Future<ui.Image> Function() previewImageBuilder;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late Color _color = widget.initialColor;
  bool _samplingPreview = false;
  late final TextEditingController _hexController = TextEditingController(
    text: _hexOf(widget.initialColor),
  );
  final FocusNode _hexFocus = FocusNode();

  /// A roda HSV começa aberta só quando a cor atual já é customizada (não
  /// bate com nenhum swatch fixo) — senão fica recolhida, e só a bolinha de
  /// cor customizada (entre os swatches) abre/fecha ela.
  late bool _wheelOpen = !collageColorSwatches.contains(_color);

  @override
  void initState() {
    super.initState();
    // Ao sair do campo, volta ao código da cor atual (descarta digitação
    // incompleta em vez de deixar um valor que não vale).
    _hexFocus.addListener(() {
      if (!_hexFocus.hasFocus) _syncHexText();
    });
  }

  @override
  void dispose() {
    _hexController.dispose();
    _hexFocus.dispose();
    super.dispose();
  }

  void _syncHexText() {
    // Aceita o formato curto `RGB` ao confirmar.
    final typed = _parseHex(_hexController.text);
    if (typed != null && typed != _color) {
      _select(typed);
      return;
    }
    setState(() => _hexController.text = _hexOf(_color));
  }

  void _select(Color color, {bool fromHexField = false}) {
    setState(() {
      _color = color;
      if (!fromHexField) _hexController.text = _hexOf(color);
    });
    widget.onColorSelected(color);
  }

  /// Digitar o código: só aplica com os 6 dígitos completos; enquanto
  /// incompleto não mexe na cor (o formato curto `RGB` vale ao confirmar).
  void _onHexChanged(String text) {
    if (text.length != 6) return;
    final color = _parseHex(text);
    if (color != null) _select(color, fromHexField: true);
  }

  void _selectSwatch(Color color) {
    setState(() => _wheelOpen = false);
    _select(color);
  }

  void _toggleWheel() => setState(() => _wheelOpen = !_wheelOpen);

  Future<void> _startEyedropper() async {
    setState(() => _samplingPreview = true);
    try {
      final ui.Image image;
      try {
        image = await widget.previewImageBuilder();
      } catch (_) {
        // Sem isso o erro virava uma exceção assíncrona sem dono e o botão
        // simplesmente não fazia nada, sem explicação nenhuma.
        if (mounted) {
          showAppMessage(
            context,
            tr(
              'Não foi possível preparar a prévia para o conta-gotas.',
              'Could not prepare the preview for the eyedropper.',
            ),
          );
        }
        return;
      }
      if (!mounted) {
        image.dispose();
        return;
      }
      final result = await showDialog<Color>(
        context: context,
        builder: (dialogContext) => _EyedropperDialog(image: image),
      );
      image.dispose();
      if (result != null) _select(result);
    } finally {
      if (mounted) setState(() => _samplingPreview = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final color in collageColorSwatches)
                    _SwatchButton(
                      color: color,
                      selected: !_wheelOpen && color == _color,
                      onTap: () => _selectSwatch(color),
                    ),
                  _CustomColorButton(
                    color: _color,
                    // "Customizada" tanto quando a cor atual já é uma cor
                    // fora da paleta fixa quanto quando a roda está aberta
                    // (o usuário pode estar mexendo nela ainda sem ter saído
                    // de um swatch) — nos dois casos mostra a cor atual em
                    // vez do gradiente neutro.
                    isCustom:
                        _wheelOpen || !collageColorSwatches.contains(_color),
                    onTap: _toggleWheel,
                  ),
                  _EyedropperButton(
                    busy: _samplingPreview,
                    onTap: _startEyedropper,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _HexField(
                controller: _hexController,
                focusNode: _hexFocus,
                color: _color,
                onChanged: _onHexChanged,
                onSubmitted: (_) => _syncHexText(),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: !_wheelOpen
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Center(
                          child: ColorPicker(
                            key: const ValueKey('collageColorPickerWheel'),
                            pickerColor: _color,
                            onColorChanged: _select,
                            enableAlpha: false,
                            displayThumbColor: true,
                            labelTypes: const [],
                            // Área e barra de matiz menores que o padrão do
                            // pacote (300 de largura, 70% de altura), que
                            // dominavam a folha perto dos swatches de 40.
                            colorPickerWidth: 240,
                            pickerAreaHeightPercent: 0.5,
                            pickerAreaBorderRadius: const BorderRadius.all(
                              Radius.circular(12),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `#RRGGBB` em maiúsculas (a cor é sempre opaca neste seletor).
String _hexOf(Color color) => (color.toARGB32() & 0x00FFFFFF)
    .toRadixString(16)
    .padLeft(6, '0')
    .toUpperCase();

/// Aceita `RRGGBB` ou `RGB` (com ou sem `#`); `null` se ainda incompleto.
Color? _parseHex(String text) {
  var hex = text.trim().replaceFirst('#', '');
  if (hex.length == 3) {
    hex = hex.split('').map((c) => '$c$c').join();
  }
  if (hex.length != 6) return null;
  final value = int.tryParse(hex, radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}

/// Campo do código hexadecimal da cor atual — mostra o valor e deixa
/// digitar outro; a bolinha ao lado é a própria cor.
class _HexField extends StatelessWidget {
  const _HexField({
    required this.controller,
    required this.focusNode,
    required this.color,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Color color;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 140,
          child: TextField(
            key: const ValueKey('collageColorHexField'),
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
              LengthLimitingTextInputFormatter(6),
            ],
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              isDense: true,
              prefixText: '#',
              labelText: tr('Código da cor', 'Color code'),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}

class _SwatchButton extends StatelessWidget {
  const _SwatchButton({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 3 : 1.5,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check_rounded,
                size: 18,
                color: color.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
              )
            : null,
      ),
    );
  }
}

/// Bolinha entre os swatches que abre/fecha a roda HSV completa — mostra a
/// própria [color] (com a marca de seleção, mesmo padrão de [_SwatchButton])
/// quando [isCustom], ou um gradiente arco-íris neutro quando a cor atual
/// ainda é só um dos swatches fixos.
class _CustomColorButton extends StatelessWidget {
  const _CustomColorButton({
    required this.color,
    required this.isCustom,
    required this.onTap,
  });

  final Color color;
  final bool isCustom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isCustom ? color : null,
          gradient: isCustom
              ? null
              : const SweepGradient(
                  colors: [
                    Color(0xFFFF0000),
                    Color(0xFFFFFF00),
                    Color(0xFF00FF00),
                    Color(0xFF00FFFF),
                    Color(0xFF0000FF),
                    Color(0xFFFF00FF),
                    Color(0xFFFF0000),
                  ],
                ),
          shape: BoxShape.circle,
          border: Border.all(
            color: isCustom
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: isCustom ? 3 : 1.5,
          ),
        ),
        child: isCustom
            ? Icon(
                Icons.check_rounded,
                size: 18,
                color: color.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
              )
            : null,
      ),
    );
  }
}

class _EyedropperButton extends StatelessWidget {
  const _EyedropperButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.10),
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
          ),
        ),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                Icons.colorize_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
      ),
    );
  }
}

/// Deixa o usuário tocar/arrastar sobre a prévia rasterizada da montagem
/// para escolher um pixel exato como cor — leitura direta dos bytes RGBA
/// (mesma técnica de `imported_frame_store.dart`'s detecção de buraco alfa),
/// sem precisar reencodar a imagem para PNG/arquivo.
class _EyedropperDialog extends StatefulWidget {
  const _EyedropperDialog({required this.image});

  final ui.Image image;

  @override
  State<_EyedropperDialog> createState() => _EyedropperDialogState();
}

class _EyedropperDialogState extends State<_EyedropperDialog> {
  ByteData? _raw;
  Color _preview = Colors.white;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await widget.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (!mounted) return;
    setState(() => _raw = raw);
  }

  Color? _colorAt(Offset localPosition, Size widgetSize) {
    final raw = _raw;
    if (raw == null || widgetSize.width <= 0 || widgetSize.height <= 0) {
      return null;
    }
    final px = (localPosition.dx / widgetSize.width * widget.image.width)
        .floor()
        .clamp(0, widget.image.width - 1);
    final py = (localPosition.dy / widgetSize.height * widget.image.height)
        .floor()
        .clamp(0, widget.image.height - 1);
    final offset = (py * widget.image.width + px) * 4;
    final a = raw.getUint8(offset + 3);
    // Sem cor nenhuma ali: transparência já é seu próprio modo de fundo, então
    // tocar numa área vazia da prévia não escolhe nada (antes devolvia preto,
    // porque num buffer pré-multiplicado o RGB de um pixel transparente é 0).
    if (a == 0) return null;
    // `rawRgba` vem pré-multiplicado pelo alfa: desfaz a multiplicação para
    // que uma área semitransparente devolva a cor que aparenta ter, e não uma
    // versão escurecida dela. O conta-gotas sempre devolve uma cor opaca.
    int channel(int index) {
      final value = raw.getUint8(offset + index);
      if (a == 255) return value;
      return (value * 255 / a).round().clamp(0, 255);
    }

    return Color.fromARGB(255, channel(0), channel(1), channel(2));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: DialogTitle(
        tr(
          'Toque na imagem para escolher a cor',
          'Tap the image to pick the color',
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: AspectRatio(
          aspectRatio: widget.image.width / widget.image.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              void handle(Offset localPosition) {
                final color = _colorAt(localPosition, size);
                if (color != null) setState(() => _preview = color);
              }

              return GestureDetector(
                onTapUp: (details) => handle(details.localPosition),
                onPanUpdate: (details) => handle(details.localPosition),
                child: RawImage(image: widget.image, fit: BoxFit.fill),
              );
            },
          ),
        ),
      ),
      actions: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: _preview,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_preview),
          child: Text(tr('Usar esta cor', 'Use this color')),
        ),
      ],
    );
  }
}
