import '../../app/translations.dart';

/// Formatos oferecidos na tela "Converter formato" — um recurso à parte de
/// "Editar vídeo" (ver [OutputFormat] em `conversion_settings.dart`), sem
/// nenhuma configuração exposta: só escolher o arquivo de entrada e o
/// formato de saída.
enum QuickConvertFormat {
  gif('gif', 'image/gif', 'GIF'),
  webp('webp', 'image/webp', 'WebP animado'),
  mp4('mp4', 'video/mp4', 'MP4');

  const QuickConvertFormat(this.extension, this.mimeType, this.labelPt);

  /// Extensão do arquivo de saída, sem o ponto.
  final String extension;

  /// Tipo MIME usado ao compartilhar o arquivo.
  final String mimeType;

  /// Texto exibido no seletor de formato.
  final String labelPt;
  String get label => trKey(labelPt);

  /// Se este formato é uma imagem animada (GIF/WebP) — o MP4 sempre
  /// preserva áudio quando existir; os dois formatos de imagem nunca têm
  /// áudio.
  bool get isAnimatedImage =>
      this == QuickConvertFormat.gif || this == QuickConvertFormat.webp;
}
