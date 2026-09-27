import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _languageKey = 'language';

/// Idiomas da interface — o botão da tela inicial alterna entre os dois.
enum AppLanguage {
  pt('PT'),
  en('EN');

  const AppLanguage(this.code);

  /// Sigla mostrada no botão.
  final String code;
}

/// Idioma atual da interface. Carregado por [loadLanguage] antes do primeiro
/// frame e alterado por [toggleLanguage]; o app inteiro é reconstruído na
/// troca (ver `main.dart`), então os textos lidos com [tr] se atualizam.
final ValueNotifier<AppLanguage> languageNotifier = ValueNotifier(
  AppLanguage.pt,
);

/// O texto no idioma atual: [pt] em português, [en] em inglês.
String tr(String pt, String en) =>
    languageNotifier.value == AppLanguage.en ? en : pt;

/// Carrega o idioma salvo. Sem escolha salva, segue o idioma do aparelho:
/// português se ele estiver em português, inglês em qualquer outro caso.
Future<void> loadLanguage() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_languageKey);
  if (saved != null) {
    languageNotifier.value = AppLanguage.values.firstWhere(
      (l) => l.name == saved,
      orElse: () => AppLanguage.pt,
    );
    return;
  }
  final system = SchedulerBinding.instance.platformDispatcher.locale;
  languageNotifier.value = system.languageCode == 'pt'
      ? AppLanguage.pt
      : AppLanguage.en;
}

/// Alterna entre português e inglês e salva a escolha.
Future<void> toggleLanguage() async {
  final next = languageNotifier.value == AppLanguage.pt
      ? AppLanguage.en
      : AppLanguage.pt;
  languageNotifier.value = next;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_languageKey, next.name);
}
