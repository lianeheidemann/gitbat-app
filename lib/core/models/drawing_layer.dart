import 'dart:math' as math;
import 'dart:ui' show Color, Offset, Rect, Size;

import '../../app/translations.dart';

/// Ferramenta da aba "Pincel".
///
/// [eraser] apaga só o que o pincel pintou — a imagem fica intacta.
/// [cutout] apaga a própria imagem, deixando-a transparente: só é oferecida
/// para foto parada (Editar imagem e o "..." de uma foto parada da
/// Montagem), nunca no SVG nem em foto animada.
enum DrawingTool {
  pen('Pincel'),
  eraser('Borracha'),
  cutout('Transparência');

  const DrawingTool(this.labelPt);

  final String labelPt;
  String get label => trKey(labelPt);
}

/// Um traço do desenho.
///
/// Os pontos são **normalizados** (0 a 1) à caixa da imagem de origem e a
/// espessura é uma fração do menor lado dela: o mesmo traço serve para a
/// prévia, para a exportação em resolução cheia, para a foto decodificada
/// menor da exportação animada da Montagem e para o `viewBox` de um SVG,
/// sem nunca guardar pixel nenhum.
class DrawingStroke {
  const DrawingStroke({
    required this.tool,
    required this.points,
    required this.widthRatio,
    this.color = const Color(0xFF000000),
  });

  final DrawingTool tool;

  /// O caminho do dedo, normalizado à caixa da imagem.
  final List<Offset> points;

  /// Espessura do traço como fração do menor lado da imagem.
  final double widthRatio;

  /// Cor (já com a opacidade escolhida) — só vale para [DrawingTool.pen].
  final Color color;

  double widthIn(Size box) => widthRatio * box.shortestSide;

  /// [points] na escala de [box].
  List<Offset> pointsIn(Size box) => [
    for (final p in points) Offset(p.dx * box.width, p.dy * box.height),
  ];

  /// Caixa que envolve o traço em [box], já com a espessura somada.
  Rect? boundsIn(Size box) {
    if (points.isEmpty) return null;
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    for (final p in pointsIn(box)) {
      left = math.min(left, p.dx);
      top = math.min(top, p.dy);
      right = math.max(right, p.dx);
      bottom = math.max(bottom, p.dy);
    }
    final half = widthIn(box) / 2;
    return Rect.fromLTRB(left - half, top - half, right + half, bottom + half);
  }
}

/// O desenho inteiro de uma imagem: os traços **em ordem**, porque a
/// borracha só apaga o que foi pintado antes dela.
///
/// Imutável, como os outros estados das telas de edição: cada traço novo é
/// um objeto novo, e o histórico de desfazer guarda o anterior.
class DrawingLayer {
  const DrawingLayer({this.strokes = const []});

  static const empty = DrawingLayer();

  final List<DrawingStroke> strokes;

  bool get isEmpty => strokes.isEmpty;
  bool get isNotEmpty => strokes.isNotEmpty;

  /// Algum traço de [DrawingTool.pen] — sem ele não há o que pintar.
  bool get hasPaint => strokes.any((s) => s.tool == DrawingTool.pen);

  /// Algum traço de [DrawingTool.cutout] — a imagem precisa de uma camada
  /// própria para ganhar os buracos.
  bool get hasCutout => strokes.any((s) => s.tool == DrawingTool.cutout);

  DrawingLayer add(DrawingStroke stroke) =>
      DrawingLayer(strokes: [...strokes, stroke]);

  DrawingLayer removeLast() => strokes.isEmpty
      ? this
      : DrawingLayer(strokes: strokes.sublist(0, strokes.length - 1));

  /// Caixa de tudo o que o pincel pintou em [box], cortada a ela — `null`
  /// sem pintura. Por cima: um traço apagado depois ainda conta, o que só
  /// faz o "Ajustar" deixar um pouco mais de margem.
  Rect? paintBoundsIn(Size box) {
    Rect? result;
    for (final stroke in strokes) {
      if (stroke.tool != DrawingTool.pen) continue;
      final bounds = stroke.boundsIn(box);
      if (bounds == null) continue;
      result = result == null ? bounds : result.expandToInclude(bounds);
    }
    if (result == null) return null;
    final clipped = result.intersect(Offset.zero & box);
    return clipped.isEmpty ? null : clipped;
  }
}

/// O pincel em uso: ferramenta, cor, opacidade e tamanho. Estado de tela,
/// não de edição — trocar de cor não é um passo de desfazer, só o traço que
/// sai com ela.
class DrawingBrush {
  const DrawingBrush({
    required this.color,
    this.tool = DrawingTool.pen,
    this.opacity = 1,
    this.penPercent = 1.5,
    this.eraserPercent = 5,
    this.pencilMode = DrawingTool.pen,
  });

  /// Limites do tamanho, em % do menor lado da imagem.
  static const minPercent = 0.3;
  static const maxPercent = 15.0;

  final DrawingTool tool;
  final Color color;

  /// 0,1 a 1 — só no pincel.
  final double opacity;

  /// Tamanho do pincel e o das duas borrachas, guardados à parte: apagar
  /// costuma pedir um traço bem mais grosso que o de pintar.
  final double penPercent;
  final double eraserPercent;

  /// O último modo do grupo "Pincel" — [DrawingTool.pen] (Pintar) ou
  /// [DrawingTool.eraser] (Borracha, que só apaga o que o pincel pintou e
  /// por isso é uma subopção dele). Voltar ao Pincel depois da Transparência
  /// ou da Borracha mágica volta a ele.
  final DrawingTool pencilMode;

  double get sizePercent =>
      tool == DrawingTool.pen ? penPercent : eraserPercent;

  DrawingBrush copyWith({
    DrawingTool? tool,
    Color? color,
    double? opacity,
    double? penPercent,
    double? eraserPercent,
  }) {
    final next = tool ?? this.tool;
    return DrawingBrush(
      tool: next,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
      penPercent: penPercent ?? this.penPercent,
      eraserPercent: eraserPercent ?? this.eraserPercent,
      pencilMode: next == DrawingTool.pen || next == DrawingTool.eraser
          ? next
          : pencilMode,
    );
  }

  /// Novo tamanho para a ferramenta em uso.
  DrawingBrush withSizePercent(double percent) => tool == DrawingTool.pen
      ? copyWith(penPercent: percent)
      : copyWith(eraserPercent: percent);

  /// O traço que este pincel deixa pelos [points] já normalizados.
  DrawingStroke stroke(List<Offset> points) => DrawingStroke(
    tool: tool,
    points: points,
    widthRatio: sizePercent / 100,
    color: tool == DrawingTool.pen
        ? color.withValues(alpha: color.a * opacity)
        : const Color(0xFF000000),
  );
}
