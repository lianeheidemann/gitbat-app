import 'package:flutter/material.dart';

/// Aviso curto no pé da tela, trocando o que já estiver à mostra — o mesmo
/// `SnackBar` simples de todas as telas do app.
void showAppMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
