/// As cores que já vêm escolhidas em "Fundo" e em "Moldura"/"Borda" nas três
/// telas de edição — "Editar vídeo", "Colocar moldura" e "Montagem".
///
/// Ficam aqui, e não repetidas em cada modelo, porque o ponto delas é
/// justamente ser a mesma cor nas três telas: mudar de ideia sobre o padrão
/// é mexer num lugar só.
///
/// Nenhuma das duas liga nada sozinha. O fundo continua vindo transparente
/// por padrão (`FrameSettings.transparentBackground` e
/// `CollageBackgroundMode.transparent`) e a borda continua vindo com
/// espessura zero — estas cores são as que aparecem quando você liga o fundo
/// ou dá espessura à moldura.
library;

import 'dart:ui' show Color;

/// Azul-gelo do corpo do morceguinho (`assets/icon/icon-v2`). É uma das
/// amostras fixas da paleta, então o fundo já sai combinando com o app.
const defaultBackgroundColor = Color(0xFFB0DCFC);

/// Azul-marinho do contorno do mascote: escuro o bastante para a moldura se
/// separar do fundo azul-gelo sem virar preto.
const defaultFrameColor = Color(0xFF0C48A8);

/// Azul-noite do contorno mais escuro, para o texto da montagem — mesmo espírito das duas acima,
/// só que aqui não há "ligar/desligar": todo texto novo já nasce com esta
/// cor (ver [CollageTextItem]).
const defaultTextColor = Color(0xFF061C4B);
