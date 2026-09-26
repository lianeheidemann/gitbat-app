import 'dart:ui' show Offset, Rect, Size;

/// Como as células de uma montagem estão organizadas: modelos prontos (linha,
/// coluna, grades fixas) ou uma grade livre com número de linhas/colunas
/// escolhido pelo usuário.
enum CollageLayoutKind {
  row('Linha'),
  column('Coluna'),
  grid2x2('Grade 2x2'),
  grid2x3('Grade 2x3'),
  grid3x3('Grade 3x3'),
  freeGrid('Grade livre');

  const CollageLayoutKind(this.label);

  final String label;
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
  });

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
  bool get hasCustomSizes => columnWeights != null || rowWeights != null;

  /// Os mesmos arranjo e contagem, com todas as áreas do mesmo tamanho.
  CollageLayout withEqualSizes() =>
      CollageLayout(kind: kind, columns: columns, rows: rows);

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
  };

  /// Quantas linhas a grade realmente tem, resolvendo os nomes fixos.
  int get _effectiveRows => switch (kind) {
    CollageLayoutKind.row => 1,
    CollageLayoutKind.column => rows < 1 ? 1 : rows,
    CollageLayoutKind.grid2x2 => 2,
    CollageLayoutKind.grid2x3 => 3,
    CollageLayoutKind.grid3x3 => 3,
    CollageLayoutKind.freeGrid => rows < 1 ? 1 : rows,
  };

  /// Número de fotos que esta organização comporta.
  int get cellCount => _effectiveColumns * _effectiveRows;

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
      );

  /// Os divisores arrastáveis da aba "Áreas" num canvas de [canvasSize],
  /// com as mesmas margens de [cellRectsFor]: um vertical entre cada par de
  /// colunas (da altura toda) e um horizontal entre cada par de linhas
  /// dentro de cada coluna.
  List<CollageDivider> dividersFor(
    Size canvasSize, {
    required double outerMarginRatio,
    required double innerMarginRatio,
  }) {
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

  /// Células (em ordem de leitura) que [divider] redimensiona — as colunas
  /// inteiras dos dois lados num vertical, as duas fotos da coluna num
  /// horizontal. É o que fica em destaque enquanto a alça é arrastada.
  List<int> cellsTouching(CollageDivider divider) {
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
  static const maxFreeGridSpan = 4;

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
  });

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
    a.index == b.index;
