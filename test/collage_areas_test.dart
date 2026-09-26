import 'package:flutter_test/flutter_test.dart';
import 'dart:ui';
import 'package:video_to_gif/features/collage/models/collage_layout.dart';

// Aba "Áreas" da montagem: arrastar um divisor muda só as duas áreas que ele
// separa, e trocar o layout volta tudo ao tamanho padrão.

const _size = Size(400, 400);

List<Rect> _rects(CollageLayout layout) =>
    layout.cellRectsFor(_size, outerMarginRatio: 0, innerMarginRatio: 0);

CollageLayout _drag(CollageLayout layout, CollageDivider d, double delta) =>
    layout.resizedBy(d, delta, _size, outerMarginRatio: 0, innerMarginRatio: 0);

List<CollageDivider> _dividers(CollageLayout layout) =>
    layout.dividersFor(_size, outerMarginRatio: 0, innerMarginRatio: 0);

void main() {
  test('sem arrastar nada, a geometria é a de sempre', () {
    final rects = _rects(const CollageLayout(kind: CollageLayoutKind.grid2x2));
    expect(rects, [
      const Rect.fromLTWH(0, 0, 200, 200),
      const Rect.fromLTWH(200, 0, 200, 200),
      const Rect.fromLTWH(0, 200, 200, 200),
      const Rect.fromLTWH(200, 200, 200, 200),
    ]);
  });

  test('uma grade 2x2 tem 1 divisor vertical e 1 horizontal por coluna', () {
    final dividers = _dividers(
      const CollageLayout(kind: CollageLayoutKind.grid2x2),
    );
    expect(dividers.where((d) => d.vertical).length, 1);
    expect(dividers.where((d) => !d.vertical).length, 2);
    final vertical = dividers.firstWhere((d) => d.vertical);
    expect(vertical.center, const Offset(200, 200));
    expect(vertical.length, 400);
  });

  test('o divisor horizontal mexe só nas duas fotos daquela coluna', () {
    const layout = CollageLayout(kind: CollageLayoutKind.grid2x2);
    final leftH = _dividers(
      layout,
    ).firstWhere((d) => !d.vertical && d.column == 0);
    final rects = _rects(_drag(layout, leftH, 100));
    expect(rects[0].height, 300);
    expect(rects[2].height, 100);
    // A coluna da direita não muda.
    expect(rects[1].height, 200);
    expect(rects[3].height, 200);
  });

  test('o divisor vertical muda a largura das duas colunas', () {
    const layout = CollageLayout(kind: CollageLayoutKind.row, columns: 3);
    final first = _dividers(layout).first;
    final rects = _rects(_drag(layout, first, -40));
    expect(rects[0].width, closeTo(400 / 3 - 40, 0.001));
    expect(rects[1].width, closeTo(400 / 3 + 40, 0.001));
    expect(rects[2].width, closeTo(400 / 3, 0.001));
  });

  test('nenhuma área fica menor que o mínimo', () {
    const layout = CollageLayout(kind: CollageLayoutKind.column, rows: 2);
    final divider = _dividers(layout).single;
    final rects = _rects(_drag(layout, divider, -1000));
    expect(rects[0].height, closeTo(200 * CollageLayout.minWeight, 0.001));
    expect(rects[0].height + rects[1].height, closeTo(400, 0.001));
  });

  test('trocar arranjo ou contagem volta os tamanhos ao padrão', () {
    const layout = CollageLayout(kind: CollageLayoutKind.column, rows: 2);
    final resized = _drag(layout, _dividers(layout).single, 80);
    expect(resized.hasCustomSizes, isTrue);
    expect(resized.copyWith(rows: 3).hasCustomSizes, isFalse);
    expect(resized.withEqualSizes().hasCustomSizes, isFalse);
    expect(_rects(resized.withEqualSizes())[0].height, 200);
  });

  test('alças da foto selecionada ficam no meio das bordas dela', () {
    const grid = CollageLayout(kind: CollageLayoutKind.grid2x2);
    final corner = grid.handlesAround(
      0,
      _size,
      outerMarginRatio: 0,
      innerMarginRatio: 0,
    );
    expect(corner.length, 2);
    expect(
      corner.firstWhere((h) => h.divider.vertical).center,
      const Offset(200, 100),
    );
    expect(
      corner.firstWhere((h) => !h.divider.vertical).center,
      const Offset(100, 200),
    );

    const column = CollageLayout(kind: CollageLayoutKind.column, rows: 3);
    final middle = column.handlesAround(
      1,
      _size,
      outerMarginRatio: 0,
      innerMarginRatio: 0,
    );
    expect(middle.map((h) => h.divider.vertical), [false, false]);
    expect(middle.map((h) => h.divider.index), [0, 1]);
  });

  test('destaque: quais fotos cada divisor redimensiona', () {
    const grid = CollageLayout(kind: CollageLayoutKind.grid2x2);
    final dividers = _dividers(grid);
    expect(grid.cellsTouching(dividers.firstWhere((d) => d.vertical)), [
      0,
      1,
      2,
      3,
    ]);
    final rightH = dividers.firstWhere((d) => !d.vertical && d.column == 1);
    expect(grid.cellsTouching(rightH), [1, 3]);
  });
}
