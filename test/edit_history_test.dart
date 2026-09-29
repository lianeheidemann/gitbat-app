import 'package:flutter_test/flutter_test.dart';
import 'package:gitbat/core/ui/edit_history.dart';

void main() {
  test('começa sem nada para desfazer nem refazer', () {
    final history = EditHistory<String>();
    expect(history.canUndo, isFalse);
    expect(history.canRedo, isFalse);
    expect(history.undo('a'), isNull);
    expect(history.redo('a'), isNull);
  });

  test('desfazer volta ao estado guardado e refazer traz o atual de volta', () {
    final history = EditHistory<String>()..push('a');
    expect(history.canUndo, isTrue);

    expect(history.undo('b'), 'a');
    expect(history.canUndo, isFalse);
    expect(history.canRedo, isTrue);

    expect(history.redo('a'), 'b');
    expect(history.canUndo, isTrue);
    expect(history.canRedo, isFalse);
  });

  test('desfaz na ordem inversa, um passo por vez', () {
    final history = EditHistory<String>()
      ..push('a')
      ..push('b');
    expect(history.undo('c'), 'b');
    expect(history.undo('b'), 'a');
    expect(history.undo('a'), isNull);
    expect(history.redo('a'), 'b');
    expect(history.redo('b'), 'c');
  });

  test('um estado novo depois de desfazer descarta o refazer', () {
    final history = EditHistory<String>()..push('a');
    expect(history.undo('b'), 'a');
    history.push('a');
    expect(history.canRedo, isFalse);
    expect(history.redo('c'), isNull);
  });
}
