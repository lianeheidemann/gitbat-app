import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _previewCheckerboardKey = 'previewCheckerboardEnabled';

/// Liga um fundo quadriculado (indicador universal de transparência, como em
/// editores de imagem) atrás da prévia nas telas de edição (vídeo, imagem,
/// SVG e montagem), no lugar da cor de fundo padrão do tema — preferência
/// global, a mesma em todas. Carregado por [loadPreviewCheckerboardPreference]
/// antes do primeiro frame, mesmo padrão de `theme_controller.dart`.
///
/// **Ligado por padrão**: o app é feito para conteúdo transparente, e sem o
/// xadrez a transparência se confunde com o fundo da tela. Desligar é
/// lembrado, e o app abre desligado das próximas vezes.
final ValueNotifier<bool> previewCheckerboardNotifier = ValueNotifier(true);

/// Carrega a preferência salva (ou `true`, se ainda não houver nenhuma) em
/// [previewCheckerboardNotifier]. Deve ser chamada antes de `runApp`.
Future<void> loadPreviewCheckerboardPreference() async {
  final prefs = await SharedPreferences.getInstance();
  previewCheckerboardNotifier.value =
      prefs.getBool(_previewCheckerboardKey) ?? true;
}

/// Liga/desliga o fundo quadriculado e salva a nova preferência.
Future<void> setPreviewCheckerboardEnabled(bool enabled) async {
  previewCheckerboardNotifier.value = enabled;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_previewCheckerboardKey, enabled);
}
