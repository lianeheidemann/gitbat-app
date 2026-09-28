import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/models/conversion_settings.dart';
import '../../core/models/photo_info.dart';
import '../svg/models/svg_info.dart';
import '../svg/services/svg_source_fixer.dart';
import '../../core/ffmpeg/ffmpeg_service.dart';
import '../../app/language_controller.dart';
import '../../app/theme_controller.dart';
import 'widgets/gif_weight_help_sheet.dart';
import '../collage/collage_page.dart';
import '../video/editor_page.dart';
import '../photo/photo_frame_page.dart';
import '../quick_convert/quick_convert_page.dart';
import '../svg/svg_edit_page.dart';
import '../../app/editor_defaults.dart';

/// Tela inicial: apresenta o app e deixa o usuário escolher um vídeo para
/// começar a edição.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _ffmpeg = FfmpegService();
  bool _loading = false;
  String? _error;

  /// Abre o seletor de arquivos, lê os metadados do vídeo escolhido com o
  /// FFprobe e navega para o [EditorPage] com as configurações recomendadas.
  Future<void> _pickVideo() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // O seletor do sistema devolve acesso só ao arquivo escolhido, por isso
      // o app não precisa de permissão de leitura de mídia.
      final picked = await FilePicker.pickFile(
        type: FileType.video,
        dialogTitle: tr('Escolha um vídeo', 'Choose a video'),
      );

      final path = picked?.path;
      if (path == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final video = await _ffmpeg.probe(path);
      if (!mounted) return;

      setState(() => _loading = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EditorPage(
            video: video,
            initialSettings: ConversionSettings.recommendedFor(
              video,
            ).copyWith(frame: EditorDefaults.frameSettings()),
          ),
        ),
      );
    } on FfmpegException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = tr(
            'Não foi possível abrir este vídeo.',
            'Could not open this video.',
          );
        });
      }
    }
  }

  /// Abre o seletor de arquivos para uma foto, decodifica as dimensões
  /// nativas localmente (sem FFprobe — não há nada além do tamanho para
  /// sondar numa imagem estática) e navega para [PhotoFramePage].
  Future<void> _pickPhoto() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final picked = await FilePicker.pickFile(
        type: FileType.image,
        dialogTitle: tr('Escolha uma foto', 'Choose a photo'),
      );

      final path = picked?.path;
      if (path == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      // "Editar imagem" só sabe desenhar uma foto parada — um GIF/WebP
      // animado decodificaria normalmente (é só imagem pra esse codec), mas
      // ia perder o resto dos quadros em silêncio, virando uma foto parada
      // sem ninguém pedir isso. Vídeo nem chega aqui: o próprio
      // `FileType.image` do seletor de mídia já filtra por conta própria.
      if (codec.frameCount > 1) {
        codec.dispose();
        if (mounted) {
          setState(() {
            _loading = false;
            _error = tr(
              'Essa imagem é animada (GIF/WebP). "Editar imagem" só aceita fotos paradas.',
              'This image is animated (GIF/WebP). "Edit image" only accepts still photos.',
            );
          });
        }
        return;
      }
      final frame = await codec.getNextFrame();
      final photo = PhotoInfo(
        path: path,
        width: frame.image.width,
        height: frame.image.height,
      );
      frame.image.dispose();
      if (!mounted) return;

      setState(() => _loading = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PhotoFramePage(photo: photo)),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = tr(
            'Não foi possível abrir esta foto.',
            'Could not open this photo.',
          );
        });
      }
    }
  }

  /// Abre o seletor de arquivos para um SVG e lê o tamanho intrínseco pelo
  /// próprio `flutter_svg` (`PictureInfo.size`) — nunca reparseado dos
  /// atributos do XML na mão, que podem ser ausentes ou percentuais. Mesmo
  /// padrão de `ImportedFrameStore.importFrame()`, que já faz isso para SVGs
  /// de moldura. Ao contrário da foto, SVG não é `FileType.image` (não é um
  /// formato raster que `ui.instantiateImageCodec` entenda).
  Future<void> _pickSvg() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['svg'],
        dialogTitle: tr('Escolha um SVG', 'Choose an SVG'),
      );

      final pickedPath = picked?.path;
      if (pickedPath == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Conserta os casos que o leitor recusava (compactado, UTF-16, ângulo
      // em "deg", sem tamanho) — ver `svg_source_fixer.dart`.
      final String path;
      final PictureInfo pictureInfo;
      try {
        path = await prepareSvgForEditing(pickedPath);
        pictureInfo = await vg.loadPicture(SvgFileLoader(File(path)), null);
      } on SvgOpenException catch (e) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = e.message;
          });
        }
        return;
      } catch (e) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = _svgErrorMessage(e);
          });
        }
        return;
      }
      final size = pictureInfo.size;
      pictureInfo.picture.dispose();
      if (size.width <= 0 || size.height <= 0) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = tr(
              'Este SVG não tem um tamanho válido.',
              'This SVG has no valid size.',
            );
          });
        }
        return;
      }

      final svg = SvgInfo(path: path, width: size.width, height: size.height);
      if (!mounted) return;

      setState(() => _loading = false);
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => SvgEditPage(svg: svg)));
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = tr(
            'Não foi possível abrir este SVG.',
            'Could not open this SVG.',
          );
        });
      }
    }
  }

  /// Mensagem para um SVG que o leitor recusou, com o motivo quando dá para
  /// reconhecer — em vez de sempre o mesmo "não foi possível ler".
  static String _svgErrorMessage(Object error) {
    final text = error.toString();
    if (text.contains('did not specify dimensions')) {
      return tr(
        'Este SVG não informa o tamanho (width/height ou viewBox).',
        'This SVG does not declare its size (width/height or viewBox).',
      );
    }
    if (text.contains('Invalid double') || text.contains('FormatException')) {
      return tr(
        'Este SVG tem um número ou medida que o app não entende.',
        'This SVG has a number or unit the app does not understand.',
      );
    }
    if (text.contains('decode') || text.contains('Decode')) {
      return tr(
        'Este SVG traz uma imagem embutida que não deu para ler.',
        'This SVG has an embedded image that could not be read.',
      );
    }
    return tr(
      'Não foi possível ler este arquivo como SVG.',
      'Could not read this file as an SVG.',
    );
  }

  /// Abre o seletor de arquivos permitindo escolher várias fotos de uma vez
  /// (`FilePicker.pickFiles` com seleção múltipla, ao contrário de
  /// `_pickPhoto`'s `pickFile` singular) e navega para [CollagePage], onde o
  /// usuário monta a colagem. Exige pelo menos duas fotos — uma única foto já
  /// tem sua própria tela dedicada em "Editar imagem".
  Future<void> _pickPhotosForCollage() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.image,
        dialogTitle: tr(
          'Escolha as fotos da montagem',
          'Choose the collage photos',
        ),
      );

      if (picked.length < 2) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = picked.isEmpty
                ? null
                : tr(
                    'Escolha pelo menos duas fotos para montar uma colagem.',
                    'Choose at least two photos to make a collage.',
                  );
          });
        }
        return;
      }

      final photos = <PhotoInfo>[];
      for (final file in picked) {
        final path = file.path;
        if (path == null) continue;
        final bytes = await File(path).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        photos.add(
          PhotoInfo(
            path: path,
            width: frame.image.width,
            height: frame.image.height,
          ),
        );
        frame.image.dispose();
      }
      if (!mounted) return;

      if (photos.length < 2) {
        setState(() {
          _loading = false;
          _error = tr(
            'Escolha pelo menos duas fotos para montar uma colagem.',
            'Choose at least two photos to make a collage.',
          );
        });
        return;
      }

      setState(() => _loading = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => CollagePage(photos: photos)),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = tr(
            'Não foi possível abrir essas fotos.',
            'Could not open these photos.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow.withValues(
                  alpha: 0.86,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.55,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Um único símbolo universal; o idioma atual continua
                  // informado pelo tooltip/leitor de tela, sem poluir a barra.
                  IconButton(
                    key: const ValueKey('languageToggle'),
                    tooltip: languageNotifier.value == AppLanguage.pt
                        ? 'Mudar idioma — Português'
                        : 'Change language — English',
                    icon: const Icon(Icons.language_rounded),
                    onPressed: toggleLanguage,
                  ),
                  IconButton(
                    tooltip: tr(
                      'Como deixar o GIF mais leve',
                      'How to make the GIF lighter',
                    ),
                    icon: const Icon(Icons.help_outline),
                    onPressed: () => showGifWeightHelpSheet(context),
                  ),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeModeNotifier,
                    builder: (context, mode, _) {
                      final isDark = mode == ThemeMode.dark;
                      return IconButton(
                        tooltip: isDark
                            ? tr('Ativar modo claro', 'Switch to light mode')
                            : tr('Ativar modo escuro', 'Switch to dark mode'),
                        color: theme.colorScheme.secondary,
                        icon: Icon(
                          isDark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                        onPressed: toggleThemeMode,
                      );
                    },
                  ),
                  IconButton(
                    tooltip: tr('Sobre e licenças', 'About and licenses'),
                    icon: const Icon(Icons.info_outline),
                    onPressed: () => showAboutDialog(
                      context: context,
                      applicationName: 'GitBat',
                      applicationVersion: '1.0.0',
                      applicationLegalese: tr(
                        'Conversão feita no próprio aparelho com FFmpeg (LGPL). Nenhum vídeo é enviado para a internet.',
                        'Conversion runs on the device with FFmpeg (LGPL). No video is sent to the internet.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo sem fundo (cópia estável de assets/readme/gitbat-logo.png).
                Image.asset(
                  'recursos/marca/gitbat-logo.png',
                  key: const ValueKey('homeLogo'),
                  height: 96,
                  fit: BoxFit.contain,
                  semanticLabel: tr('Logo do GitBat', 'GitBat logo'),
                ),
                const SizedBox(height: 16),
                Text(
                  'GitBat',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    'Corte, ajuste o tamanho e a velocidade — e veja quanto o GIF vai pesar antes de converter.',
                    'Trim, resize and change the speed — and see how big the GIF will be before converting.',
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // O principal do app: mais alto e com texto maior que os
                // outros botões.
                FilledButton.icon(
                  key: const ValueKey('pickVideoButton'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    iconSize: 22,
                  ),
                  onPressed: _loading ? null : _pickVideo,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.video_library_outlined),
                  label: Text(
                    _loading
                        ? tr('Abrindo…', 'Opening…')
                        : tr('Escolher vídeo', 'Choose video'),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _loading ? null : _pickPhoto,
                  icon: const Icon(Icons.photo_filter_outlined),
                  label: Text(tr('Editar imagem', 'Edit image')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _loading ? null : _pickSvg,
                  icon: const Icon(Icons.polyline_outlined),
                  label: Text(tr('Editar SVG', 'Edit SVG')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _loading ? null : _pickPhotosForCollage,
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: Text(tr('Montagem', 'Collage')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _loading
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const QuickConvertPage(),
                          ),
                        ),
                  icon: const Icon(Icons.cached_outlined),
                  label: Text(tr('Converter formato', 'Convert format')),
                ),
                const SizedBox(height: 16),
                const _StepsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _kStepCircleSize = 44.0;

/// Etapas do fluxo de conversão, exibidas como um pequeno guia visual.
class _StepsCard extends StatelessWidget {
  const _StepsCard();

  static List<({IconData icon, String label})> get _steps => [
    (
      icon: Icons.folder_open_outlined,
      label: tr('Selecionar vídeo', 'Select video'),
    ),
    (icon: Icons.tune_rounded, label: tr('Ajustar', 'Adjust')),
    (icon: Icons.auto_fix_high_rounded, label: tr('Converter', 'Convert')),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _steps.length; i++) ...[
              if (i > 0) const Expanded(child: _StepConnector()),
              _StepIcon(icon: _steps[i].icon, label: _steps[i].label),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _kStepCircleSize,
          height: _kStepCircleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: _kStepCircleSize,
      child: Row(
        children: [
          const Expanded(child: _DashedLine()),
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary,
            ),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 13,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          const Expanded(child: _DashedLine()),
        ],
      ),
    );
  }
}

/// Linha tracejada usada para ligar os ícones de etapa em [_StepsCard].
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary.withValues(alpha: 0.4);

    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 4.0;
        const gap = 4.0;
        final count = (constraints.maxWidth / (dashWidth + gap)).floor().clamp(
          1,
          100,
        );
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(
              width: dashWidth,
              height: 2,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        );
      },
    );
  }
}
