import '../../app/language_controller.dart';
import 'package:flutter/material.dart';

import '../../core/models/conversion_settings.dart';
import '../../core/models/size_estimate.dart';
import '../../core/models/video_info.dart';
import '../../core/ffmpeg/ffmpeg_service.dart';
import '../../core/services/output_service.dart';
import '../../core/ui/app_message.dart';
import '../../core/ui/saved_dialog.dart';
import '../../app/theme.dart';
import '../../app/app_palette.dart';

/// Tela final: exibe o resumo da conversão e as ações de salvar/compartilhar.
class ResultPage extends StatefulWidget {
  const ResultPage({
    super.key,
    required this.result,
    required this.estimate,
    required this.settings,
    required this.video,
  });

  final ConversionResult result;
  final SizeEstimate estimate;
  final ConversionSettings settings;
  final VideoInfo video;

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  static const _output = OutputService();

  bool _saving = false;
  bool _saved = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _output.saveToGallery(widget.result.file);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });
      await showSavedDialog(
        context,
        tr(
          '${widget.result.format.shortLabel} salvo na galeria.',
          '${widget.result.format.shortLabel} saved to the gallery.',
        ),
      );
    } on OutputException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message(e.message);
    }
  }

  void _message(String text) => showAppMessage(context, text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final result = widget.result;
    final verdict = SizeVerdict.forBytes(result.bytes);
    final accent = verdictColor(verdict, scheme);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(
            '${result.format.shortLabel} pronto',
            '${result.format.shortLabel} ready',
          ),
        ),
        actions: [
          IconButton(
            tooltip: tr('Compartilhar', 'Share'),
            onPressed: () => _output.share(
              result.file,
              mimeType: result.format.mimeType,
              text: tr(
                '${result.format.shortLabel} feito com o app GitBat',
                '${result.format.shortLabel} made with the GitBat app',
              ),
            ),
            icon: const Icon(Icons.share_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
              child: Column(
                children: [
                  _SuccessMark(color: accent),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      Text(
                        result.formattedSize,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          color: accent,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Text(
                          verdict.label,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      text: tr(
                        'Conversão concluída em ',
                        'Conversion finished in ',
                      ),
                      children: [
                        TextSpan(
                          text: '${_elapsedSeconds()}s',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SizeComparison(
                    original: SizeEstimate.formatBytes(
                      widget.video.fileSizeBytes,
                    ),
                    // A estimativa calibrada (palettegen/paletteuse) só existe
                    // para GIF — ver size_estimator.dart. Mostrar um número
                    // baseado nesse modelo para uma exportação em WebP seria
                    // enganoso (o WebP tende a sair bem menor), então essa
                    // coluna some nesse caso.
                    predicted: result.format == OutputFormat.gif
                        ? widget.estimate.formatted
                        : null,
                    finalSize: result.formattedSize,
                    difference: result.format == OutputFormat.gif
                        ? tr(
                            '${_predictionDiff()} da previsão',
                            '${_predictionDiff()} from the estimate',
                          )
                        : null,
                    accent: accent,
                  ),
                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.55),
                  ),
                  const SizedBox(height: 10),
                  _SectionTitle(
                    icon: Icons.video_file_outlined,
                    label: tr(
                      '${result.format.shortLabel} gerado',
                      '${result.format.shortLabel} created',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MetricRow(
                    icon: Icons.layers_outlined,
                    label: tr('Quadros', 'Frames'),
                    original: tr(
                      'de ${_originalFrames()}',
                      'of ${_originalFrames()}',
                    ),
                    value: '${result.frames}',
                  ),
                  const SizedBox(height: 6),
                  _MetricRow(
                    icon: Icons.schedule_outlined,
                    label: tr('Duração', 'Duration'),
                    original: tr(
                      'de ${widget.video.durationSeconds.toStringAsFixed(1)}s',
                      'of ${widget.video.durationSeconds.toStringAsFixed(1)}s',
                    ),
                    value:
                        '${widget.settings.outputDurationSeconds.toStringAsFixed(1)}s • ${widget.settings.fps} FPS',
                  ),
                  const SizedBox(height: 6),
                  _MetricRow(
                    icon: Icons.aspect_ratio_outlined,
                    label: tr('Dimensões', 'Dimensions'),
                    original: tr(
                      'de ${widget.video.width} × ${widget.video.height} px',
                      'of ${widget.video.width} × ${widget.video.height} px',
                    ),
                    value: '${result.width} × ${result.height} px',
                  ),
                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.55),
                  ),
                  const SizedBox(height: 10),
                  _SectionTitle(
                    icon: Icons.workspace_premium_outlined,
                    label: tr('Qualidade', 'Quality'),
                  ),
                  const SizedBox(height: 8),
                  if (result.format == OutputFormat.gif)
                    Row(
                      children: [
                        Expanded(
                          child: _QualityPill(
                            icon: Icons.palette_outlined,
                            label: tr(
                              '${widget.settings.colors} cores',
                              '${widget.settings.colors} colors',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _QualityPill(
                            icon: Icons.tune_rounded,
                            label: widget.settings.dither.label,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _QualityPill(
                            icon: Icons.water_drop_outlined,
                            label: widget.settings.palette.label,
                          ),
                        ),
                      ],
                    )
                  else
                    _QualityPill(
                      icon: Icons.high_quality_outlined,
                      label: tr(
                        'Qualidade ${widget.settings.webpQuality}',
                        'Quality ${widget.settings.webpQuality}',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _GradientActionButton(
              isBusy: _saving,
              isDone: _saved,
              onPressed: _saving || _saved ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  int _originalFrames() =>
      (widget.video.durationSeconds * widget.video.frameRate).round();

  int _elapsedSeconds() {
    final milliseconds = widget.result.elapsed.inMilliseconds;
    if (milliseconds <= 0) return 0;
    return (milliseconds + 999) ~/ 1000;
  }

  String _predictionDiff() {
    final estimated = widget.estimate.bytes;
    if (estimated <= 0) return '—';

    final actual = widget.result.bytes;
    final percent = ((actual - estimated) / estimated * 100).round();
    return percent > 0 ? '+$percent%' : '$percent%';
  }
}

class _SuccessMark extends StatelessWidget {
  const _SuccessMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(Icons.check_rounded, color: color, size: 15),
      ),
    );
  }
}

class _SizeComparison extends StatelessWidget {
  const _SizeComparison({
    required this.original,
    required this.predicted,
    required this.finalSize,
    required this.difference,
    required this.accent,
  });

  final String original;

  /// `null` quando não há estimativa confiável para o formato de saída
  /// (ver o comentário no chamador) — nesse caso a coluna e a linha de
  /// diferença abaixo somem, sobrando só "Original" e "Final".
  final String? predicted;
  final String finalSize;
  final String? difference;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _SizeCell(
                    label: tr('Original', 'Original'),
                    value: original,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.38),
                ),
                if (predicted != null) ...[
                  Expanded(
                    child: _SizeCell(
                      label: tr('Previsto', 'Estimated'),
                      value: predicted!,
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.38),
                  ),
                ],
                Expanded(
                  child: _SizeCell(
                    label: tr('Final', 'Final'),
                    value: finalSize,
                    accent: accent,
                  ),
                ),
              ],
            ),
          ),
          if (difference != null) ...[
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.38),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                difference!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SizeCell extends StatelessWidget {
  const _SizeCell({required this.label, required this.value, this.accent});

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: accent ?? scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, color: scheme.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.original,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String original;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.38),
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: scheme.primary, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              Text(
                original,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _QualityPill extends StatelessWidget {
  const _QualityPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.62),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: scheme.primary, size: 16),
          const SizedBox(width: 5),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({
    required this.isBusy,
    required this.isDone,
    required this.onPressed,
  });

  final bool isBusy;
  final bool isDone;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final accent =
        Theme.of(context).extension<AppAccent>() ??
        AppAccent(
          gradient: batPalette.accentGradient,
          onAccent: batPalette.onAccent,
        );
    final foreground = accent.onAccent;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: onPressed == null && !isDone ? 0.72 : 1,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: accent.gradient),
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isBusy)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: foreground,
                      ),
                    )
                  else
                    Icon(
                      isDone ? Icons.check_rounded : Icons.download_rounded,
                      color: foreground,
                      size: 18,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    isBusy
                        ? tr('Salvando…', 'Saving…')
                        : isDone
                        ? tr('Salvo na galeria', 'Saved to gallery')
                        : tr('Salvar na galeria', 'Save to gallery'),
                    style: TextStyle(
                      color: foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
