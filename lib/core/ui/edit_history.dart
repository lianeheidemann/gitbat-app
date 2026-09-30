/// Pilhas de desfazer/refazer de uma tela de edição — o mesmo histórico em
/// Editar vídeo, Editar imagem, Editar SVG e Montagem, cada uma com o próprio
/// tipo de estado [T].
///
/// Quem aplica o estado continua sendo a tela, dentro do `setState` dela:
/// aqui só fica guardado o que ficou para trás e o que foi desfeito. Um gesto
/// contínuo (slider, arrasto) chama [push] uma vez no começo e segue sem
/// empilhar nada — o gesto inteiro vira UM passo de desfazer.
class EditHistory<T extends Object> {
  final List<T> _undo = [];
  final List<T> _redo = [];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Guarda [current] como ponto de retorno e descarta o que havia para
  /// refazer.
  void push(T current) {
    _undo.add(current);
    _redo.clear();
  }

  /// O estado anterior, guardando [current] para refazer — ou `null` quando
  /// não há nada para desfazer.
  T? undo(T current) {
    if (_undo.isEmpty) return null;
    _redo.add(current);
    return _undo.removeLast();
  }

  /// O estado desfeito por último, guardando [current] para desfazer de
  /// novo — ou `null` quando não há nada para refazer.
  T? redo(T current) {
    if (_redo.isEmpty) return null;
    _undo.add(current);
    return _redo.removeLast();
  }
}
