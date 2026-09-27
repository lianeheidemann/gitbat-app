import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitbat/features/collage/models/collage_layout.dart';

// Layout "Personalizada": uma árvore de divisões em que o "+" de um lado de
// um espaço o divide em dois.

const _size = Size(300, 300);

List<Rect> _rects(CollageLayout layout, {double inner = 0, double outer = 0}) =>
    layout.cellRectsFor(
      _size,
      outerMarginRatio: outer,
      innerMarginRatio: inner,
    );

void expectRectsClose(List<Rect> a, List<Rect> b) {
  expect(a.length, b.length);
  for (var i = 0; i < a.length; i++) {
    expect(a[i].left, closeTo(b[i].left, 1e-6), reason: 'left $i');
    expect(a[i].top, closeTo(b[i].top, 1e-6), reason: 'top $i');
    expect(a[i].width, closeTo(b[i].width, 1e-6), reason: 'width $i');
    expect(a[i].height, closeTo(b[i].height, 1e-6), reason: 'height $i');
  }
}

void main() {
  const grid = CollageLayout(kind: CollageLayoutKind.grid3x3);

  test('virar "Personalizada" mantém os mesmos espaços, com margens', () {
    final custom = grid.toCustom();
    expect(custom.kind, CollageLayoutKind.custom);
    expect(custom.cellCount, 9);
    expectRectsClose(_rects(custom), _rects(grid));
    expectRectsClose(
      _rects(custom, inner: 0.03, outer: 0.05),
      _rects(grid, inner: 0.03, outer: 0.05),
    );
    expect(custom.hasCustomSizes, isFalse);
  });

  test('o + da direita divide só aquele espaço em duas metades', () {
    final custom = grid.toCustom();
    final split = custom.splitCell(4, CollageSide.right);
    expect(split.cellCount, 10);
    final before = _rects(custom);
    final after = _rects(split);
    for (var i = 0; i < 9; i++) {
      if (i == 4) continue;
      expect(after[i], before[i]);
    }
    expect(after[4].left, before[4].left);
    expect(after[4].width, closeTo(before[4].width / 2, 1e-6));
    expect(after[9].left, closeTo(before[4].center.dx, 1e-6));
    expect(after[9].right, closeTo(before[4].right, 1e-6));
  });

  test('o + de cima põe o espaço novo em cima', () {
    final split = grid.toCustom().splitCell(0, CollageSide.top);
    final r = _rects(split);
    expect(r[9].top, 0);
    expect(r[0].top, closeTo(r[9].bottom, 1e-6));
  });

  test('remover espaço devolve o lugar e renumera', () {
    final custom = grid.toCustom();
    final split = custom.splitCell(4, CollageSide.right);
    final removed = split.removeCell(9);
    expectRectsClose(_rects(removed), _rects(custom));
    final removedOld = split.removeCell(4);
    expect(removedOld.cellCount, 9);
    // A célula nova (antes 9, agora 8) ocupa o espaço todo do meio.
    expectRectsClose([_rects(removedOld)[8]], [_rects(custom)[4]]);
  });

  test('o divisor da divisão nova só mexe nas duas metades', () {
    final split = grid.toCustom().splitCell(4, CollageSide.right);
    final handles = split.handlesAround(
      9,
      _size,
      outerMarginRatio: 0,
      innerMarginRatio: 0,
    );
    final left = handles.firstWhere(
      (h) => h.divider.vertical && h.center.dx < 180,
    );
    expect(split.cellsTouching(left.divider), [4, 9]);
    final moved = split.resizedBy(
      left.divider,
      20,
      _size,
      outerMarginRatio: 0,
      innerMarginRatio: 0,
    );
    final a = _rects(split);
    final b = _rects(moved);
    expect(b[4].width, closeTo(a[4].width + 20, 1e-6));
    expect(b[9].width, closeTo(a[9].width - 20, 1e-6));
    expect(b[3], a[3]);
    expect(moved.hasCustomSizes, isTrue);
    // "Tamanhos iguais": todo espaço enfileirado com a mesma largura — a
    // coluna do meio, com dois, fica com o dobro.
    final equal = _rects(moved.withEqualSizes());
    expect(equal[4].width, closeTo(equal[0].width, 1e-6));
    expect(equal[9].width, closeTo(equal[0].width, 1e-6));
  });

  test('largura pela aba Áreas mexe na divisão mais próxima', () {
    final split = grid.toCustom().splitCell(4, CollageSide.right);
    expect(split.widthFractionOf(9), closeTo(1 / 6, 1e-6));
    final wider = split.withWidthFraction(9, 0.25);
    expect(wider.widthFractionOf(9), closeTo(0.25, 1e-6));
    expect(wider.widthFractionOf(0), closeTo(1 / 3, 1e-6));
  });

  test('para em 16 espaços', () {
    var layout = const CollageLayout(
      kind: CollageLayoutKind.grid2x2,
    ).toCustom();
    for (var i = 0; i < 20; i++) {
      layout = layout.splitCell(0, CollageSide.right);
    }
    expect(layout.cellCount, CollageLayout.maxCustomCells);
  });

  group('área travada anda inteira', () {
    CollageLayout? drag(
      CollageLayout layout,
      CollageDivider d,
      double delta,
      Set<int> locked,
    ) => layout.resizedKeepingLocked(
      d,
      delta,
      _size,
      locked: locked,
      outerMarginRatio: 0,
      innerMarginRatio: 0.02,
    );

    for (final (name, layout) in [
      ('grade', const CollageLayout(kind: CollageLayoutKind.row, columns: 3)),
      (
        'personalizada',
        const CollageLayout(kind: CollageLayoutKind.row, columns: 3).toCustom(),
      ),
    ]) {
      test('$name: empurrar a vizinha move a travada sem mudar o tamanho', () {
        final before = _rects(layout, inner: 0.02);
        final d = layout
            .handlesAround(
              0,
              _size,
              outerMarginRatio: 0,
              innerMarginRatio: 0.02,
            )
            .single
            .divider;
        final next = drag(layout, d, 30, {1});
        expect(next, isNotNull);
        final after = _rects(next!, inner: 0.02);
        expect(after[0].width, closeTo(before[0].width + 30, 0.6));
        expect(after[1].width, closeTo(before[1].width, 0.6));
        expect(after[1].left, closeTo(before[1].left + 30, 0.6));
        expect(after[2].width, closeTo(before[2].width - 30, 0.6));
      });

      test('$name: passos pequenos somados desde o começo não encolhem a '
          'travada', () {
        final before = _rects(layout, inner: 0.02);
        final d = layout
            .handlesAround(
              0,
              _size,
              outerMarginRatio: 0,
              innerMarginRatio: 0.02,
            )
            .single
            .divider;
        // Como a tela faz: sempre a partir do layout do começo do arrasto,
        // com o total andado até aqui (100 passos de 0,3 px).
        var current = layout;
        for (var i = 1; i <= 100; i++) {
          current = drag(layout, d, 0.3 * i, {1}) ?? current;
        }
        final after = _rects(current, inner: 0.02);
        expect(after[1].width, closeTo(before[1].width, 0.05));
        expect(after[1].left, closeTo(before[1].left + 30, 0.05));
      });

      test('$name: travada na beirada não deixa a vizinha empurrar', () {
        final d = layout
            .handlesAround(
              2,
              _size,
              outerMarginRatio: 0,
              innerMarginRatio: 0.02,
            )
            .single
            .divider;
        expect(drag(layout, d, -30, {2}), isNull);
      });
    }
  });
}
