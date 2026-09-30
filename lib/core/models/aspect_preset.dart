import '../../app/language_controller.dart';

/// Proporções oferecidas em toda tela de recorte do app (vídeo, foto e
/// montagem) — a mesma lista em todo lugar, para o usuário encontrar as
/// mesmas opções não importa qual recorte esteja usando.
class AspectPreset {
  const AspectPreset(
    this.labelPt,
    this.ratio, {
    this.hintPt = '',
    this.labelEn,
    this.hintEn = '',
  });

  /// Rótulo e dica em português; [labelEn]/[hintEn] são as versões em
  /// inglês (sem [labelEn], o rótulo é o mesmo nos dois idiomas, ex.: "4:5").
  final String labelPt;
  final double? ratio; // null = manter a proporção original
  final String hintPt;
  final String? labelEn;
  final String hintEn;

  String get label => tr(labelPt, labelEn ?? labelPt);
  String get hint => tr(hintPt, hintEn);

  static const presets = <AspectPreset>[
    AspectPreset('Original', null),
    AspectPreset('1:1', 1.0, hintPt: 'Quadrado', hintEn: 'Square'),
    AspectPreset('4:5', 4 / 5, hintPt: 'Retrato', hintEn: 'Portrait'),
    AspectPreset('5:4', 5 / 4),
    AspectPreset('2:3', 2 / 3),
    AspectPreset('3:2', 3 / 2, hintPt: 'Foto', hintEn: 'Photo'),
    AspectPreset('3:4', 3 / 4),
    AspectPreset('4:3', 4 / 3, hintPt: 'Clássico', hintEn: 'Classic'),
    AspectPreset('9:16', 9 / 16, hintPt: 'Stories', hintEn: 'Stories'),
    AspectPreset('16:9', 16 / 9, hintPt: 'Paisagem', hintEn: 'Landscape'),
    AspectPreset('2:1', 2.0),
    AspectPreset('1:2', 0.5),
  ];

  /// "Personalizado", o recorte livre de Editar imagem e Editar SVG: não é
  /// uma proporção de verdade (o -1 nunca vira razão), só marca que cada
  /// alça mexe no seu lado/canto sem travar largura e altura entre si.
  static const custom = AspectPreset('Personalizado', -1, labelEn: 'Custom');

  /// "Ajustar": também não é uma proporção (o -2 nunca vira razão). Tocar
  /// nele encosta o recorte nos pixels visíveis, cortando só a margem
  /// totalmente transparente (ver `opaque_bounds.dart`); depois disso o
  /// recorte fica livre como em [custom], para a pessoa refinar se quiser.
  static const trim = AspectPreset('Ajustar', -2, labelEn: 'Fit');
}
