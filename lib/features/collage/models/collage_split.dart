import 'dart:ui' show Rect;

/// Lado de um espaço da montagem "Personalizada" onde o "+" cria um espaço
/// novo.
enum CollageSide { left, right, top, bottom }

/// Árvore de divisões do layout "Personalizada": cada nó é um espaço de foto
/// (folha, com o índice da célula) ou um retângulo cortado em dois — lado a
/// lado ([vertical], divisor em pé) ou um em cima do outro. [ratio] é quanto
/// do retângulo fica com [first] (o da esquerda ou o de cima).
///
/// Assim saem montagens que não são grades regulares: tocar no "+" de um
/// lado de um espaço troca aquela folha por uma divisão com o espaço antigo
/// e um novo daquele lado ([split]).
class CollageSplit {
  const CollageSplit.leaf(int this.cell)
    : vertical = false,
      ratio = 0.5,
      first = null,
      second = null;

  const CollageSplit.node({
    required this.vertical,
    required this.ratio,
    required CollageSplit this.first,
    required CollageSplit this.second,
  }) : cell = null;

  final int? cell;
  final bool vertical;
  final double ratio;
  final CollageSplit? first;
  final CollageSplit? second;

  bool get isLeaf => cell != null;

  /// Menor e maior [ratio] de uma divisão — nenhum lado some de vez.
  static const minRatio = 0.1;
  static const maxRatio = 0.9;

  int get leafCount => isLeaf ? 1 : first!.leafCount + second!.leafCount;

  /// Quantos espaços cabem enfileirados na horizontal ([horizontal]) ou na
  /// vertical — é o que decide a divisão "igual" ([equalized]).
  int tracks({required bool horizontal}) {
    if (isLeaf) return 1;
    final a = first!.tracks(horizontal: horizontal);
    final b = second!.tracks(horizontal: horizontal);
    return vertical == horizontal ? a + b : (a > b ? a : b);
  }

  /// Proporção "igual" desta divisão: cada espaço enfileirado no eixo dela
  /// com o mesmo tamanho.
  double get equalRatio {
    final a = first!.tracks(horizontal: vertical);
    final b = second!.tracks(horizontal: vertical);
    return a / (a + b);
  }

  CollageSplit withRatio(double value) => CollageSplit.node(
    vertical: vertical,
    ratio: value.clamp(minRatio, maxRatio),
    first: first!,
    second: second!,
  );

  /// A mesma árvore com todas as divisões na proporção "igual".
  CollageSplit get equalized {
    if (isLeaf) return this;
    final a = first!.equalized;
    final b = second!.equalized;
    final node = CollageSplit.node(
      vertical: vertical,
      ratio: ratio,
      first: a,
      second: b,
    );
    return CollageSplit.node(
      vertical: vertical,
      ratio: node.equalRatio,
      first: a,
      second: b,
    );
  }

  /// `true` se alguma divisão saiu da proporção "igual".
  bool get hasCustomRatios {
    if (isLeaf) return false;
    return (ratio - equalRatio).abs() > 1e-6 ||
        first!.hasCustomRatios ||
        second!.hasCustomRatios;
  }

  /// Os dois pedaços de [rect] com [gap] entre eles. Cada lado leva sua
  /// parte de `largura + gap` menos um `gap` — assim espaços "iguais" em
  /// divisões encadeadas saem mesmo iguais, como numa grade.
  (Rect, Rect) childRects(Rect rect, double gap) {
    if (vertical) {
      final a = ((rect.width + gap) * ratio - gap).clamp(0.0, rect.width);
      final left = rect.left + a + gap;
      return (
        Rect.fromLTWH(rect.left, rect.top, a, rect.height),
        Rect.fromLTRB(
          left.clamp(rect.left, rect.right),
          rect.top,
          rect.right,
          rect.bottom,
        ),
      );
    }
    final a = ((rect.height + gap) * ratio - gap).clamp(0.0, rect.height);
    final top = rect.top + a + gap;
    return (
      Rect.fromLTWH(rect.left, rect.top, rect.width, a),
      Rect.fromLTRB(
        rect.left,
        top.clamp(rect.top, rect.bottom),
        rect.right,
        rect.bottom,
      ),
    );
  }

  /// Retângulo de cada célula (pelo índice) dentro de [rect].
  void collectRects(Rect rect, double gap, Map<int, Rect> out) {
    if (isLeaf) {
      out[cell!] = rect;
      return;
    }
    final (a, b) = childRects(rect, gap);
    first!.collectRects(a, gap, out);
    second!.collectRects(b, gap, out);
  }

  /// Cada divisão com o caminho até ela (`'0'` = [first], `'1'` =
  /// [second]) e o retângulo que ela corta.
  void collectNodes(
    Rect rect,
    double gap,
    String path,
    List<(String path, CollageSplit node, Rect rect)> out,
  ) {
    if (isLeaf) return;
    out.add((path, this, rect));
    final (a, b) = childRects(rect, gap);
    first!.collectNodes(a, gap, '${path}0', out);
    second!.collectNodes(b, gap, '${path}1', out);
  }

  /// O nó no caminho [path].
  CollageSplit at(String path) {
    var node = this;
    for (final step in path.split('')) {
      node = step == '0' ? node.first! : node.second!;
    }
    return node;
  }

  /// Esta árvore com o nó em [path] trocado por [replacement].
  CollageSplit replaced(String path, CollageSplit replacement) {
    if (path.isEmpty) return replacement;
    final goFirst = path[0] == '0';
    final rest = path.substring(1);
    return CollageSplit.node(
      vertical: vertical,
      ratio: ratio,
      first: goFirst ? first!.replaced(rest, replacement) : first!,
      second: goFirst ? second! : second!.replaced(rest, replacement),
    );
  }

  /// Caminho até a folha da célula [target], ou `null` se ela não existe.
  String? pathOf(int target, [String path = '']) {
    if (isLeaf) return cell == target ? path : null;
    return first!.pathOf(target, '${path}0') ??
        second!.pathOf(target, '${path}1');
  }

  /// Índices das células (folhas) debaixo deste nó.
  List<int> get cells => isLeaf ? [cell!] : [...first!.cells, ...second!.cells];

  /// Troca a folha da célula [target] por uma divisão com ela e a célula
  /// nova [newCell] do lado [side], meio a meio.
  CollageSplit split(int target, CollageSide side, int newCell) {
    final path = pathOf(target);
    if (path == null) return this;
    final old = CollageSplit.leaf(target);
    final added = CollageSplit.leaf(newCell);
    final newFirst = side == CollageSide.left || side == CollageSide.top;
    return replaced(
      path,
      CollageSplit.node(
        vertical: side == CollageSide.left || side == CollageSide.right,
        ratio: 0.5,
        first: newFirst ? added : old,
        second: newFirst ? old : added,
      ),
    );
  }

  /// Tira a célula [target]: a irmã dela ocupa o lugar da divisão, e as
  /// células de índice maior descem uma posição. Sem efeito com uma célula
  /// só.
  CollageSplit removed(int target) {
    final path = pathOf(target);
    if (path == null || path.isEmpty) return this;
    final parentPath = path.substring(0, path.length - 1);
    final parent = at(parentPath);
    final sibling = path.endsWith('0') ? parent.second! : parent.first!;
    return replaced(parentPath, sibling)._renumberedAfter(target);
  }

  CollageSplit _renumberedAfter(int removed) {
    if (isLeaf) {
      return cell! > removed ? CollageSplit.leaf(cell! - 1) : this;
    }
    return CollageSplit.node(
      vertical: vertical,
      ratio: ratio,
      first: first!._renumberedAfter(removed),
      second: second!._renumberedAfter(removed),
    );
  }

  /// Árvore que reproduz uma grade de [columnWeights].length colunas: cada
  /// coluna `c` com as linhas de `rowWeights[c]`, células em ordem de
  /// leitura (linha por linha), como em `CollageLayout.cellRectsFor`.
  static CollageSplit fromGrid(
    List<double> columnWeights,
    List<List<double>> rowWeights,
  ) {
    final cols = columnWeights.length;
    CollageSplit chain(
      int start,
      List<double> weights,
      bool vertical,
      CollageSplit Function(int i) item,
    ) {
      if (start == weights.length - 1) return item(start);
      final rest = weights.skip(start).fold<double>(0, (a, b) => a + b);
      return CollageSplit.node(
        vertical: vertical,
        ratio: rest <= 0 ? 0.5 : weights[start] / rest,
        first: item(start),
        second: chain(start + 1, weights, vertical, item),
      );
    }

    return chain(
      0,
      columnWeights,
      true,
      (c) => chain(
        0,
        rowWeights[c],
        false,
        (r) => CollageSplit.leaf(r * cols + c),
      ),
    );
  }
}
