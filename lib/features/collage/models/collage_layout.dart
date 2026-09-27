import 'dart:ui' show Offset, Rect, Size;

import 'collage_split.dart';
import '../../../app/translations.dart';

export 'collage_split.dart' show CollageSide, CollageSplit;

/// Como as células de uma montagem estão organizadas: modelos prontos (linha,
/// coluna, grades fixas) ou uma grade livre com número de linhas/colunas
/// escolhido pelo usuário.
enum CollageLayoutKind {
  row('Linha'),
  column('Coluna'),
  grid2x2('Grade 2x2'),
  grid2x3('Grade 2x3'),
  grid3x3('Grade 3x3'),
  freeGrid('Grade livre'),
  custom('Personalizada');

  const CollageLayoutKind(this.labelPt);

  final String labelPt;
  String get label => trKey(labelPt);
}

/// Organização das fotos dentro da montagem: quantas células existem e como
/// elas se distribuem em linhas/colunas. [columns]/[rows] só têm significado
/// para [CollageLayoutKind.row] (usa [columns] como quantidade de fotos),
/// [CollageLayoutKind.column] (usa [rows]) e [CollageLayoutKind.freeGrid]
/// (usa os dois) — as grades fixas (2x2/2x3/3x3) já têm sua contagem
/// implícita no próprio nome.
///
/// O tamanho de cada área pode ser mudado na aba "Áreas", arrastando os
/// divisores entre as fotos. A grade é dividida primeiro em colunas
/// ([columnWeights]) e depois cada coluna nas suas linhas ([rowWeights],
/// uma lista por coluna) — assim um divisor horizontal mexe só nas duas
/// fotos daquela coluna, e um vertical nas duas colunas que ele separa.
/// `null` é tudo igual, o padrão. Qualquer troca de arranjo ou de contagem
/// ([copyWith]) volta os tamanhos para o padrão.
class CollageLayout {
  const CollageLayout({
    required this.kind,
    this.columns = 1,
    this.rows = 1,
    this.columnWeights,
    this.rowWeights,
    this.split,
  });

  /// Árvore de divisões do layout [CollageLayoutKind.custom] — ver
  /// [CollageSplit]. Nos outros layouts fica `null`.
  final CollageSplit? split;

  /// A árvore do "Personalizada" (uma célula só se ainda não houver).
  CollageSplit get _tree => split ?? const CollageSplit.leaf(0);

  bool get _isCustom => kind == CollageLayoutKind.custom;

  /// Maior número de espaços do "Personalizada".
  static const maxCustomCells = 16;

  final CollageLayoutKind kind;
  final int columns;
  final int rows;

  /// Largura relativa de cada coluna (uma por coluna). `null` = iguais.
  final List<double>? columnWeights;

  /// Altura relativa de cada linha, **por coluna**: `rowWeights![c][r]`.
  /// `null` = iguais.
  final List<List<double>>? rowWeights;

  /// Menor peso de uma área ao arrastar um divisor — 25% do tamanho padrão,
  /// para nenhuma foto sumir de vez.
  static const minWeight = 0.25;

  /// `true` quando algum tamanho foi mudado na aba "Áreas".
  bool get hasCustomSizes => _isCustom
      ? _tree.hasCustomRatios
      : columnWeights != null || rowWeights != null;

  /// Os mesmos arranjo e contagem, com todas as áreas do mesmo tamanho.
  CollageLayout withEqualSizes() => _isCustom
      ? CollageLayout(kind: kind, split: _tree.equalized)
      : CollageLayout(kind: kind, columns: columns, rows: rows);

  /// Pesos válidos de [count] áreas (somando [count]): os guardados, se
  /// baterem com a contagem atual, senão todos 1.
  static List<double> _weightsOr(List<double>? weights, int count) {
    if (weights == null || weights.length != count) {
      return List.filled(count, 1.0);
    }
    final sum = weights.fold<double>(0, (a, b) => a + b);
    if (sum <= 0) return List.filled(count, 1.0);
    return [for (final w in weights) w * count / sum];
  }

  List<double> _columnWeights() => _weightsOr(columnWeights, _effectiveColumns);

  List<double> _rowWeightsOf(int column) => _weightsOr(
    rowWeights != null && column < rowWeights!.length
        ? rowWeights![column]
        : null,
    _effectiveRows,
  );

  /// Quantas colunas a grade realmente tem, resolvendo os nomes fixos.
  int get _effectiveColumns => switch (kind) {
    CollageLayoutKind.row => columns < 1 ? 1 : columns,
    CollageLayoutKind.column => 1,
    CollageLayoutKind.grid2x2 => 2,
    CollageLayoutKind.grid2x3 => 2,
    CollageLayoutKind.grid3x3 => 3,
    CollageLayoutKind.freeGrid => columns < 1 ? 1 : columns,
    CollageLayoutKind.custom => _customTracks(horizontal: true),
  };

  /// Quantas linhas a grade realmente tem, resolvendo os nomes fixos.
  int get _effectiveRows => switch (kind) {
    CollageLayoutKind.row => 1,
    CollageLayoutKind.column => rows < 1 ? 1 : rows,
    CollageLayoutKind.grid2x2 => 2,
    CollageLayoutKind.grid2x3 => 3,
    CollageLayoutKind.grid3x3 => 3,
    CollageLayoutKind.freeGrid => rows < 1 ? 1 : rows,
    CollageLayoutKind.custom => _customTracks(horizontal: false),
  };

  int _customTracks({required bool horizontal}) =>
      _tree.tracks(horizontal: horizontal);

  /// Número de fotos que esta organização comporta.
  int get cellCount =>
      _isCustom ? _tree.leafCount : _effectiveColumns * _effectiveRows;

  /// Colunas e linhas que este layout ocupa de fato (os prontos, como a
  /// grade 3×3, também) — para trocar para "Grade livre" sem mudar a grade.
  int get columnCount => _effectiveColumns;
  int get rowCount => _effectiveRows;

  /// Retângulos de cada célula dentro de um canvas de [canvasSize], já
  /// aplicando [outerMarginRatio] (da borda da montagem até as fotos) e
  /// [innerMarginRatio] (só entre as fotos) — ambos proporcionais ao menor
  /// lado do canvas, mesmo espírito de [FrameSettings.cornerRatio], e
  /// independentes entre si. Única fonte de geometria: usada pela prévia ao
  /// vivo e pela exportação, para as duas nunca ficarem fora de sincronia.
  List<Rect> cellRectsFor(
    Size canvasSize, {
    required double outerMarginRatio,
    required double innerMarginRatio,
  }) {
    if (_isCustom) {
      final outerMargin = canvasSize.shortestSide * outerMarginRatio;
      final innerMargin = canvasSize.shortestSide * innerMarginRatio;
      final byCell = <int, Rect>{};
      _tree.collectRects(
        _customRoot(canvasSize, outerMargin),
        innerMargin,
        byCell,
      );
      return [for (var i = 0; i < cellCount; i++) byCell[i] ?? Rect.zero];
    }
    final cols = _effectiveColumns;
    final rowsN = _effectiveRows;
    final outerMargin = canvasSize.shortestSide * outerMarginRatio;
    final innerMargin = canvasSize.shortestSide * innerMarginRatio;

    final availableWidth =
        (canvasSize.width - outerMargin * 2 - innerMargin * (cols - 1)).clamp(
          0.0,
          canvasSize.width,
        );
    final availableHeight =
        (canvasSize.height - outerMargin * 2 - innerMargin * (rowsN - 1)).clamp(
          0.0,
          canvasSize.height,
        );
    final colW = _columnWeights();
    final lefts = <double>[];
    final widths = <double>[];
    var x = outerMargin;
    for (var c = 0; c < cols; c++) {
      final w = availableWidth * colW[c] / cols;
      lefts.add(x);
      widths.add(w);
      x += w + innerMargin;
    }

    // Células em ordem de leitura (linha por linha), como sempre foi — cada
    // coluna calcula as alturas das suas linhas com os próprios pesos.
    final rects = List<Rect>.filled(rowsN * cols, Rect.zero);
    for (var c = 0; c < cols; c++) {
      final rowW = _rowWeightsOf(c);
      var y = outerMargin;
      for (var r = 0; r < rowsN; r++) {
        final h = availableHeight * rowW[r] / rowsN;
        rects[r * cols + c] = Rect.fromLTWH(lefts[c], y, widths[c], h);
        y += h + innerMargin;
      }
    }
    return rects;
  }

  /// Troca arranjo/contagem. Sempre volta os tamanhos das áreas para o
  /// padrão: pesos de uma grade não servem para outra.
  CollageLayout copyWith({CollageLayoutKind? kind, int? columns, int? rows}) =>
      CollageLayout(
        kind: kind ?? this.kind,
        columns: columns ?? this.columns,
        rows: rows ?? this.rows,
        split: split,
      );

  /// Retângulo onde a árvore do "Personalizada" é dividida: o canvas menos
  /// a margem externa.
  static Rect _customRoot(Size canvasSize, double outerMargin) => Rect.fromLTRB(
    outerMargin,
    outerMargin,
    (canvasSize.width - outerMargin).clamp(outerMargin, double.infinity),
    (canvasSize.height - outerMargin).clamp(outerMargin, double.infinity),
  );

  /// Cada divisão do "Personalizada" com o retângulo que ela corta.
  List<(String path, CollageSplit node, Rect rect)> _customNodes(
    Size canvasSize,
    double outerMarginRatio,
    double innerMarginRatio,
  ) {
    final out = <(String, CollageSplit, Rect)>[];
    _tree.collectNodes(
      _customRoot(canvasSize, canvasSize.shortestSide * outerMarginRatio),
      canvasSize.shortestSide * innerMarginRatio,
      '',
      out,
    );
    return out;
  }

  static CollageDivider _customDivider(
    String path,
    CollageSplit node,
    Rect rect,
    double gap,
  ) {
    final (a, b) = node.childRects(rect, gap);
    return node.vertical
        ? CollageDivider(
            vertical: true,
            column: -1,
            index: -1,
            path: path,
            center: Offset((a.right + b.left) / 2, rect.center.dy),
            length: rect.height,
          )
        : CollageDivider(
            vertical: false,
            column: -1,
            index: -1,
            path: path,
            center: Offset(rect.center.dx, (a.bottom + b.top) / 2),
            length: rect.width,
          );
  }

  /// Divisões acima da célula [cell], da mais próxima para a raiz: o
  /// caminho, o nó e se a célula está no primeiro lado dele.
  List<(String path, CollageSplit node, bool inFirst)> _ancestorsOf(int cell) {
    final path = _tree.pathOf(cell);
    if (path == null) return const [];
    return [
      for (var i = path.length - 1; i >= 0; i--)
        (path.substring(0, i), _tree.at(path.substring(0, i)), path[i] == '0'),
    ];
  }

  /// Fração da largura ([horizontal]) ou da altura que a célula ocupa no
  /// "Personalizada" (sem contar as margens).
  double _customFraction(int cell, {required bool horizontal}) {
    var f = 1.0;
    for (final (_, node, inFirst) in _ancestorsOf(cell)) {
      if (node.vertical != horizontal) continue;
      f *= inFirst ? node.ratio : 1 - node.ratio;
    }
    return f;
  }

  /// A célula [cell] com [fraction] da largura/altura, mexendo só na divisão
  /// mais próxima dela naquele eixo.
  CollageLayout _withCustomFraction(
    int cell,
    double fraction, {
    required bool horizontal,
  }) {
    for (final (path, node, inFirst) in _ancestorsOf(cell)) {
      if (node.vertical != horizontal) continue;
      final own = inFirst ? node.ratio : 1 - node.ratio;
      final current = _customFraction(cell, horizontal: horizontal);
      if (current <= 0 || own <= 0) return this;
      final outside = current / own;
      final want = fraction / outside;
      final ratio = inFirst ? want : 1 - want;
      return CollageLayout(
        kind: kind,
        split: _tree.replaced(path, node.withRatio(ratio)),
      );
    }
    return this;
  }

  /// "+" do "Personalizada": a célula [cell] vira duas, com a nova (índice
  /// [cellCount]) do lado [side].
  CollageLayout splitCell(int cell, CollageSide side) {
    if (!_isCustom || cellCount >= maxCustomCells) return this;
    return CollageLayout(kind: kind, split: _tree.split(cell, side, cellCount));
  }

  /// "Remover espaço" do "Personalizada": a célula [cell] sai e a vizinha
  /// da mesma divisão ocupa o lugar dela.
  CollageLayout removeCell(int cell) {
    if (!_isCustom || cellCount <= 1) return this;
    return CollageLayout(kind: kind, split: _tree.removed(cell));
  }

  /// Este layout como "Personalizada", com as mesmas células nos mesmos
  /// lugares (e os tamanhos da aba "Áreas").
  CollageLayout toCustom() {
    if (_isCustom) return this;
    final cols = _effectiveColumns;
    return CollageLayout(
      kind: CollageLayoutKind.custom,
      split: CollageSplit.fromGrid(_columnWeights(), [
        for (var c = 0; c < cols; c++) _rowWeightsOf(c),
      ]),
    );
  }

  /// Os divisores arrastáveis da aba "Áreas" num canvas de [canvasSize],
  /// com as mesmas margens de [cellRectsFor]: um vertical entre cada par de
  /// colunas (da altura toda) e um horizontal entre cada par de linhas
  /// dentro de cada coluna.
  List<CollageDivider> dividersFor(
    Size canvasSize, {
    required double outerMarginRatio,
    required double innerMarginRatio,
  }) {
    if (_isCustom) {
      final gap = canvasSize.shortestSide * innerMarginRatio;
      return [
        for (final (path, node, rect) in _customNodes(
          canvasSize,
          outerMarginRatio,
          innerMarginRatio,
        ))
          _customDivider(path, node, rect, gap),
      ];
    }
    final rects = cellRectsFor(
      canvasSize,
      outerMarginRatio: outerMarginRatio,
      innerMarginRatio: innerMarginRatio,
    );
    final cols = _effectiveColumns;
    final rowsN = _effectiveRows;
    final dividers = <CollageDivider>[];
    for (var c = 0; c < cols - 1; c++) {
      final left = rects[c];
      final right = rects[c + 1];
      final top = rects[c].top;
      final bottom = rects[(rowsN - 1) * cols + c].bottom;
      dividers.add(
        CollageDivider(
          vertical: true,
          column: c,
          index: c,
          center: Offset((left.right + right.left) / 2, (top + bottom) / 2),
          length: bottom - top,
        ),
      );
    }
    for (var c = 0; c < cols; c++) {
      for (var r = 0; r < rowsN - 1; r++) {
        final above = rects[r * cols + c];
        final below = rects[(r + 1) * cols + c];
        dividers.add(
          CollageDivider(
            vertical: false,
            column: c,
            index: r,
            center: Offset(above.center.dx, (above.bottom + below.top) / 2),
            length: above.width,
          ),
        );
      }
    }
    return dividers;
  }

  /// Alças da célula [cellIndex] (em ordem de leitura) na aba "Áreas": um
  /// divisor para cada borda que ela divide com uma vizinha, com a alça no
  /// meio daquela borda (no meio da margem entre as duas fotos) — não no
  /// meio do divisor inteiro, que num vertical vai de cima a baixo.
  List<CollageEdgeHandle> handlesAround(
    int cellIndex,
    Size canvasSize, {
    required double outerMarginRatio,
    required double innerMarginRatio,
  }) {
    if (_isCustom) {
      return _customHandlesAround(
        cellIndex,
        canvasSize,
        outerMarginRatio,
        innerMarginRatio,
      );
    }
    final cols = _effectiveColumns;
    final rowsN = _effectiveRows;
    if (cellIndex < 0 || cellIndex >= cols * rowsN) return const [];
    final rects = cellRectsFor(
      canvasSize,
      outerMarginRatio: outerMarginRatio,
      innerMarginRatio: innerMarginRatio,
    );
    final dividers = dividersFor(
      canvasSize,
      outerMarginRatio: outerMarginRatio,
      innerMarginRatio: innerMarginRatio,
    );
    final r = cellIndex ~/ cols;
    final c = cellIndex % cols;
    final cell = rects[cellIndex];
    CollageDivider vertical(int index) =>
        dividers.firstWhere((d) => d.vertical && d.index == index);
    CollageDivider horizontal(int index) => dividers.firstWhere(
      (d) => !d.vertical && d.column == c && d.index == index,
    );

    return [
      if (c > 0)
        CollageEdgeHandle(
          vertical(c - 1),
          Offset((rects[cellIndex - 1].right + cell.left) / 2, cell.center.dy),
        ),
      if (c < cols - 1)
        CollageEdgeHandle(
          vertical(c),
          Offset((cell.right + rects[cellIndex + 1].left) / 2, cell.center.dy),
        ),
      if (r > 0)
        CollageEdgeHandle(
          horizontal(r - 1),
          Offset(
            cell.center.dx,
            (rects[cellIndex - cols].bottom + cell.top) / 2,
          ),
        ),
      if (r < rowsN - 1)
        CollageEdgeHandle(
          horizontal(r),
          Offset(
            cell.center.dx,
            (cell.bottom + rects[cellIndex + cols].top) / 2,
          ),
        ),
    ];
  }

  List<CollageEdgeHandle> _customHandlesAround(
    int cellIndex,
    Size canvasSize,
    double outerMarginRatio,
    double innerMarginRatio,
  ) {
    if (cellIndex < 0 || cellIndex >= cellCount) return const [];
    final cell = cellRectsFor(
      canvasSize,
      outerMarginRatio: outerMarginRatio,
      innerMarginRatio: innerMarginRatio,
    )[cellIndex];
    final gap = canvasSize.shortestSide * innerMarginRatio;
    final nodes = {
      for (final (path, node, rect) in _customNodes(
        canvasSize,
        outerMarginRatio,
        innerMarginRatio,
      ))
        path: _customDivider(path, node, rect, gap),
    };
    final handles = <CollageEdgeHandle>[];
    // Um lado de cada vez: a divisão mais próxima que tem a célula do lado
    // certo dela é a que passa rente àquela borda.
    for (final (vertical, inFirst) in const [
      (true, false),
      (true, true),
      (false, false),
      (false, true),
    ]) {
      for (final (path, node, first) in _ancestorsOf(cellIndex)) {
        if (node.vertical != vertical || first != inFirst) continue;
        final divider = nodes[path]!;
        final center = vertical
            ? Offset(
                inFirst ? cell.right + gap / 2 : cell.left - gap / 2,
                cell.center.dy,
              )
            : Offset(
                cell.center.dx,
                inFirst ? cell.bottom + gap / 2 : cell.top - gap / 2,
              );
        handles.add(CollageEdgeHandle(divider, center));
        break;
      }
    }
    return handles;
  }

  /// Células (em ordem de leitura) que [divider] redimensiona — as colunas
  /// inteiras dos dois lados num vertical, as duas fotos da coluna num
  /// horizontal. É o que fica em destaque enquanto a alça é arrastada.
  List<int> cellsTouching(CollageDivider divider) {
    if (_isCustom) {
      final path = divider.path;
      if (path == null) return const [];
      return _tree.at(path).cells;
    }
    final cols = _effectiveColumns;
    final rowsN = _effectiveRows;
    if (divider.vertical) {
      return [
        for (var r = 0; r < rowsN; r++) ...[
          r * cols + divider.index,
          r * cols + divider.index + 1,
        ],
      ];
    }
    return [
      divider.index * cols + divider.column,
      (divider.index + 1) * cols + divider.column,
    ];
  }

  /// Largura da coluna da célula [cellIndex], como fração (0 a 1) da
  /// largura disponível para as fotos — o "Largura" da aba "Áreas".
  double widthFractionOf(int cellIndex) {
    if (_isCustom) return _customFraction(cellIndex, horizontal: true);
    final cols = _effectiveColumns;
    return _columnWeights()[cellIndex % cols] / cols;
  }

  /// Altura da célula [cellIndex] dentro da coluna dela, como fração (0 a 1)
  /// da altura disponível — o "Altura" da aba "Áreas".
  double heightFractionOf(int cellIndex) {
    if (_isCustom) return _customFraction(cellIndex, horizontal: false);
    final cols = _effectiveColumns;
    final rowsN = _effectiveRows;
    return _rowWeightsOf(cellIndex % cols)[cellIndex ~/ cols] / rowsN;
  }

  /// Menor e maior fração que uma área pode ter numa fileira de [count]
  /// áreas, deixando pelo menos [minWeight] para cada uma das outras.
  static (double, double) fractionRange(int count) {
    if (count <= 1) return (1, 1);
    return (minWeight / count, 1 - (count - 1) * minWeight / count);
  }

  (double, double) get widthFractionRange => _isCustom
      ? (CollageSplit.minRatio / 2, CollageSplit.maxRatio)
      : fractionRange(_effectiveColumns);
  (double, double) get heightFractionRange => _isCustom
      ? (CollageSplit.minRatio / 2, CollageSplit.maxRatio)
      : fractionRange(_effectiveRows);

  /// [weights] (somando `weights.length`) com a posição [i] valendo
  /// [fraction] do total; as outras encolhem ou crescem na mesma proporção
  /// entre si, sem nenhuma ficar abaixo de [minWeight].
  static List<double> _withFraction(
    List<double> weights,
    int i,
    double fraction,
  ) {
    final n = weights.length;
    if (n <= 1) return weights;
    final (lo, hi) = fractionRange(n);
    final target = fraction.clamp(lo, hi) * n;
    final result = [...weights]..[i] = target;
    // Distribui o resto entre as outras, proporcional ao que elas já
    // tinham; quem cair abaixo do mínimo fica no mínimo e sai da conta.
    final free = <int>{
      for (var k = 0; k < n; k++)
        if (k != i) k,
    };
    var remaining = n - target;
    while (free.isNotEmpty) {
      final sum = free.fold<double>(0, (a, k) => a + weights[k]);
      var clamped = false;
      for (final k in [...free]) {
        final value = sum <= 0
            ? remaining / free.length
            : weights[k] / sum * remaining;
        if (value < minWeight) {
          result[k] = minWeight;
          remaining -= minWeight;
          free.remove(k);
          clamped = true;
        }
      }
      if (clamped) continue;
      for (final k in free) {
        result[k] = sum <= 0
            ? remaining / free.length
            : weights[k] / sum * remaining;
      }
      break;
    }
    return result;
  }

  /// A coluna da célula [cellIndex] com [fraction] da largura disponível;
  /// as outras colunas se ajustam na mesma proporção entre si.
  CollageLayout withWidthFraction(int cellIndex, double fraction) {
    if (_isCustom) {
      return _withCustomFraction(cellIndex, fraction, horizontal: true);
    }
    final cols = _effectiveColumns;
    return CollageLayout(
      kind: kind,
      columns: columns,
      rows: rows,
      columnWeights: _withFraction(
        _columnWeights(),
        cellIndex % cols,
        fraction,
      ),
      rowWeights: rowWeights,
    );
  }

  /// A célula [cellIndex] com [fraction] da altura da coluna dela; as outras
  /// fotos da mesma coluna se ajustam, as outras colunas não mudam.
  CollageLayout withHeightFraction(int cellIndex, double fraction) {
    if (_isCustom) {
      return _withCustomFraction(cellIndex, fraction, horizontal: false);
    }
    final cols = _effectiveColumns;
    final c = cellIndex % cols;
    final perColumn = [for (var k = 0; k < cols; k++) _rowWeightsOf(k)];
    perColumn[c] = _withFraction(perColumn[c], cellIndex ~/ cols, fraction);
    return CollageLayout(
      kind: kind,
      columns: columns,
      rows: rows,
      columnWeights: columnWeights,
      rowWeights: perColumn,
    );
  }

  /// Largura e altura da célula [cellIndex] multiplicadas pelo mesmo fator
  /// [factor] — com "Bloquear proporção" ligado, o formato da área não
  /// muda. O fator é limitado para os dois caberem nos seus intervalos.
  CollageLayout scaledArea(int cellIndex, double factor) {
    final w = widthFractionOf(cellIndex);
    final h = heightFractionOf(cellIndex);
    final (wLo, wHi) = widthFractionRange;
    final (hLo, hHi) = heightFractionRange;
    final lo = [wLo / w, hLo / h].reduce((a, b) => a > b ? a : b);
    final hi = [wHi / w, hHi / h].reduce((a, b) => a < b ? a : b);
    final k = lo > hi ? 1.0 : factor.clamp(lo, hi);
    return withWidthFraction(
      cellIndex,
      w * k,
    ).withHeightFraction(cellIndex, h * k);
  }

  /// "Redefinir área": a célula [cellIndex] volta à largura e à altura
  /// padrão (a mesma de todas numa grade igual); as vizinhas se ajustam.
  CollageLayout resetArea(int cellIndex) => _isCustom
      ? _customResetArea(cellIndex)
      : withWidthFraction(
          cellIndex,
          1 / _effectiveColumns,
        ).withHeightFraction(cellIndex, 1 / _effectiveRows);

  /// "Redefinir área" do "Personalizada": as divisões mais próximas da
  /// célula, uma em cada eixo, voltam à proporção igual.
  CollageLayout _customResetArea(int cellIndex) {
    var tree = _tree;
    for (final horizontal in const [true, false]) {
      for (final (path, node, _) in _ancestorsOf(cellIndex)) {
        if (node.vertical != horizontal) continue;
        tree = tree.replaced(path, node.withRatio(node.equalRatio));
        break;
      }
    }
    return CollageLayout(kind: kind, split: tree);
  }

  /// [divider] arrastado [delta] pixels (para a direita num vertical, para
  /// baixo num horizontal) num canvas de [canvasSize]. Só as duas áreas que
  /// ele separa mudam, e nenhuma fica menor que [minWeight].
  CollageLayout resizedBy(
    CollageDivider divider,
    double delta,
    Size canvasSize, {
    required double outerMarginRatio,
    required double innerMarginRatio,
  }) {
    if (_isCustom) {
      final path = divider.path;
      if (path == null) return this;
      for (final (p, node, rect) in _customNodes(
        canvasSize,
        outerMarginRatio,
        innerMarginRatio,
      )) {
        if (p != path) continue;
        final gap = canvasSize.shortestSide * innerMarginRatio;
        final span = (node.vertical ? rect.width : rect.height) + gap;
        if (span <= 0) return this;
        return CollageLayout(
          kind: kind,
          split: _tree.replaced(
            path,
            node.withRatio(node.ratio + delta / span),
          ),
        );
      }
      return this;
    }
    final cols = _effectiveColumns;
    final rowsN = _effectiveRows;
    final outerMargin = canvasSize.shortestSide * outerMarginRatio;
    final innerMargin = canvasSize.shortestSide * innerMarginRatio;

    List<double> shifted(List<double> weights, int i, double available) {
      if (available <= 0 || i < 0 || i + 1 >= weights.length) return weights;
      final dw = delta / available * weights.length;
      final total = weights[i] + weights[i + 1];
      final a = (weights[i] + dw).clamp(minWeight, total - minWeight);
      return [...weights]
        ..[i] = a
        ..[i + 1] = total - a;
    }

    if (divider.vertical) {
      final available =
          canvasSize.width - outerMargin * 2 - innerMargin * (cols - 1);
      return CollageLayout(
        kind: kind,
        columns: columns,
        rows: rows,
        columnWeights: shifted(_columnWeights(), divider.index, available),
        rowWeights: rowWeights,
      );
    }
    final available =
        canvasSize.height - outerMargin * 2 - innerMargin * (rowsN - 1);
    final perColumn = [for (var c = 0; c < cols; c++) _rowWeightsOf(c)];
    perColumn[divider.column] = shifted(
      perColumn[divider.column],
      divider.index,
      available,
    );
    return CollageLayout(
      kind: kind,
      columns: columns,
      rows: rows,
      columnWeights: columnWeights,
      rowWeights: perColumn,
    );
  }

  /// [resizedBy] respeitando as áreas travadas ([locked]): elas não mudam
  /// de tamanho, mas podem andar inteiras — quando o divisor arrastado
  /// encosta numa travada, o divisor do outro lado dela anda junto, e quem
  /// encolhe é a vizinha seguinte. `null` quando não tem como (a travada
  /// está na beirada da montagem, ou a vizinha não tem mais espaço).
  CollageLayout? resizedKeepingLocked(
    CollageDivider divider,
    double delta,
    Size canvasSize, {
    required Set<int> locked,
    required double outerMarginRatio,
    required double innerMarginRatio,
  }) {
    List<Rect> rectsOf(CollageLayout l) => l.cellRectsFor(
      canvasSize,
      outerMarginRatio: outerMarginRatio,
      innerMarginRatio: innerMarginRatio,
    );
    // Bem apertado: mesmo passos de arrasto pequenininhos contam.
    const tolerance = 0.01;
    final before = rectsOf(this);
    var next = resizedBy(
      divider,
      delta,
      canvasSize,
      outerMarginRatio: outerMarginRatio,
      innerMarginRatio: innerMarginRatio,
    );
    // Cada passo desloca uma travada; várias travadas em fila pedem mais
    // de um.
    for (var step = 0; step <= cellCount; step++) {
      final after = rectsOf(next);
      int? broken;
      for (final cell in locked) {
        if (cell >= before.length || cell >= after.length) continue;
        if ((after[cell].width - before[cell].width).abs() > tolerance ||
            (after[cell].height - before[cell].height).abs() > tolerance) {
          broken = cell;
          break;
        }
      }
      if (broken == null) return next;

      final orig = before[broken];
      final cur = after[broken];
      final vertical = divider.vertical;
      if (vertical
          ? (cur.height - orig.height).abs() > tolerance
          : (cur.width - orig.width).abs() > tolerance) {
        return null; // mudou no outro eixo: não dá para compensar
      }
      // Qual beirada da travada andou: a outra acompanha na mesma medida.
      final nearMoved = vertical
          ? (cur.left - orig.left).abs() >= (cur.right - orig.right).abs()
          : (cur.top - orig.top).abs() >= (cur.bottom - orig.bottom).abs();
      final double shift;
      if (vertical) {
        shift = nearMoved
            ? (cur.left + orig.width) - cur.right
            : (cur.right - orig.width) - cur.left;
      } else {
        shift = nearMoved
            ? (cur.top + orig.height) - cur.bottom
            : (cur.bottom - orig.height) - cur.top;
      }
      if (shift.abs() <= tolerance) return null;
      // O divisor do lado que ainda não andou.
      CollageDivider? far;
      for (final h in next.handlesAround(
        broken,
        canvasSize,
        outerMarginRatio: outerMarginRatio,
        innerMarginRatio: innerMarginRatio,
      )) {
        if (h.divider.vertical != vertical) continue;
        final onFarSide = vertical
            ? (nearMoved
                  ? h.center.dx > cur.center.dx
                  : h.center.dx < cur.center.dx)
            : (nearMoved
                  ? h.center.dy > cur.center.dy
                  : h.center.dy < cur.center.dy);
        if (onFarSide) {
          far = h.divider;
          break;
        }
      }
      if (far == null) return null;
      next = next.resizedBy(
        far,
        shift,
        canvasSize,
        outerMarginRatio: outerMarginRatio,
        innerMarginRatio: innerMarginRatio,
      );
    }
    return null;
  }

  /// [count] fotos lado a lado, uma única linha.
  factory CollageLayout.row(int count) =>
      CollageLayout(kind: CollageLayoutKind.row, columns: count, rows: 1);

  /// [count] fotos empilhadas, uma única coluna.
  factory CollageLayout.column(int count) =>
      CollageLayout(kind: CollageLayoutKind.column, columns: 1, rows: count);

  /// Grade livre de [columns] colunas por [rows] linhas.
  factory CollageLayout.grid(int columns, int rows) => CollageLayout(
    kind: CollageLayoutKind.freeGrid,
    columns: columns,
    rows: rows,
  );

  static const minFreeGridSpan = 1;
  static const maxFreeGridSpan = 6;

  /// Faixa de contagem de fotos para os layouts [CollageLayoutKind.row]/
  /// [CollageLayoutKind.column] — mesmos limites já usados como padrão ao
  /// trocar para um desses dois layouts.
  static const minRowColumnCount = 2;
  static const maxRowColumnCount = 8;
}

/// Um divisor arrastável da aba "Áreas" — ver [CollageLayout.dividersFor].
class CollageDivider {
  const CollageDivider({
    required this.vertical,
    required this.column,
    required this.index,
    required this.center,
    required this.length,
    this.path,
  });

  /// No "Personalizada", o caminho da divisão na árvore ([CollageSplit]);
  /// `null` nos outros layouts, que usam [column]/[index].
  final String? path;

  /// `true` entre duas colunas (arrasta na horizontal); `false` entre duas
  /// linhas de uma coluna (arrasta na vertical).
  final bool vertical;

  /// Coluna do divisor horizontal (num vertical, a da esquerda).
  final int column;

  /// Qual par ele separa: colunas `index`/`index + 1` num vertical, linhas
  /// `index`/`index + 1` da [column] num horizontal.
  final int index;

  /// Centro do divisor, no espaço de [CollageLayout.cellRectsFor].
  final Offset center;

  /// Comprimento do divisor (altura num vertical, largura num horizontal).
  final double length;
}

/// Uma alça da aba "Áreas" presa à borda de uma célula — ver
/// [CollageLayout.handlesAround].
class CollageEdgeHandle {
  const CollageEdgeHandle(this.divider, this.center);

  final CollageDivider divider;

  /// Onde a alça fica: no meio da borda da célula, no espaço de
  /// [CollageLayout.cellRectsFor].
  final Offset center;
}

/// Dois divisores são o mesmo quando separam as mesmas áreas — o objeto é
/// recriado a cada quadro, então a tela compara por aqui.
bool sameDivider(CollageDivider? a, CollageDivider? b) =>
    a != null &&
    b != null &&
    a.vertical == b.vertical &&
    a.column == b.column &&
    a.index == b.index &&
    a.path == b.path;
