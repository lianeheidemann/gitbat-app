import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitbat/core/services/opaque_bounds.dart';

/// Buffer RGBA [width]x[height] todo transparente, com alfa [alpha] nos
/// pixels listados em [visible].
Uint8List _image(
  int width,
  int height,
  List<(int, int)> visible, {
  int alpha = 255,
}) {
  final rgba = Uint8List(width * height * 4);
  for (final (x, y) in visible) {
    rgba[(y * width + x) * 4 + 3] = alpha;
  }
  return rgba;
}

void main() {
  test('corta só a margem transparente em volta do desenho', () {
    final rgba = _image(10, 8, [(2, 3), (6, 1), (4, 5)]);
    final bounds = opaqueBounds(rgba, 10, 8)!;
    expect(bounds.x, 2);
    expect(bounds.y, 1);
    expect(bounds.width, 5);
    expect(bounds.height, 5);
  });

  test('um pixel isolado no canto vira um recorte 1x1', () {
    final bounds = opaqueBounds(_image(5, 5, [(4, 4)]), 5, 5)!;
    expect((bounds.x, bounds.y, bounds.width, bounds.height), (4, 4, 1, 1));
  });

  test('alfa logo acima do limiar ainda conta como conteúdo', () {
    final rgba = _image(6, 6, [(1, 2)], alpha: invisibleAlphaThreshold + 1);
    final bounds = opaqueBounds(rgba, 6, 6)!;
    expect((bounds.x, bounds.y), (1, 2));
  });

  test('ignora a sujeira quase invisível de removedores de fundo', () {
    // Conteúdo de verdade no meio, cercado de pixels com alfa 1–8 nas
    // bordas, como nos PNGs que seguravam o recorte.
    final rgba = _image(20, 20, [(8, 8), (11, 12)]);
    for (final (x, y) in [(0, 0), (19, 3), (2, 19), (15, 17)]) {
      rgba[(y * 20 + x) * 4 + 3] = 1 + (x + y) % invisibleAlphaThreshold;
    }
    final bounds = opaqueBounds(rgba, 20, 20)!;
    expect((bounds.x, bounds.y, bounds.width, bounds.height), (8, 8, 4, 5));
  });

  test('só sujeira invisível conta como toda transparente', () {
    final rgba = _image(4, 4, [(1, 1), (3, 2)], alpha: invisibleAlphaThreshold);
    expect(opaqueBounds(rgba, 4, 4), isNull);
  });

  test('imagem toda transparente devolve null', () {
    expect(opaqueBounds(_image(4, 3, const []), 4, 3), isNull);
  });

  test('imagem sem margem transparente devolve a foto inteira', () {
    final bounds = opaqueBounds(_image(3, 2, [(0, 0), (2, 1)]), 3, 2)!;
    expect((bounds.x, bounds.y, bounds.width, bounds.height), (0, 0, 3, 2));
  });
}
