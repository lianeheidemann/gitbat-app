import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitbat/features/collage/widgets/folder_tab.dart';

// O contorno da pasta sai de um caminho só (sem `Path.combine`, que no
// celular deixava vazias as pastas de rótulo curto).

void main() {
  for (final width in [60.0, 86.0, 99.0, 170.0]) {
    test('pasta de $width px tem abinha e corpo', () {
      final rect = Rect.fromLTWH(0, 0, width, 36);
      final path = const FolderTabShape().getOuterPath(rect);
      final bounds = path.getBounds();
      expect(bounds.width, closeTo(width, 0.01));
      expect(bounds.height, closeTo(36, 0.01));
      // Meio do corpo e a abinha (topo à esquerda) estão dentro; o topo à
      // direita (fora da abinha) não.
      expect(path.contains(Offset(width / 2, 24)), isTrue);
      expect(path.contains(const Offset(16, 4)), isTrue);
      expect(path.contains(Offset(width - 6, 3)), isFalse);
    });
  }
}
