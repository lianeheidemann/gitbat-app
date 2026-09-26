import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:video_to_gif/features/photo/services/opaque_bounds.dart';

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

  test('alfa mínimo ainda conta como conteúdo', () {
    final bounds = opaqueBounds(_image(6, 6, [(1, 2)], alpha: 1), 6, 6)!;
    expect((bounds.x, bounds.y), (1, 2));
  });

  test('imagem toda transparente devolve null', () {
    expect(opaqueBounds(_image(4, 3, const []), 4, 3), isNull);
  });

  test('imagem sem margem transparente devolve a foto inteira', () {
    final bounds = opaqueBounds(_image(3, 2, [(0, 0), (2, 1)]), 3, 2)!;
    expect((bounds.x, bounds.y, bounds.width, bounds.height), (0, 0, 3, 2));
  });
}
