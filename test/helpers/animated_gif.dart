import 'dart:io';
import 'dart:typed_data';

/// GIF animado mínimo, montado à mão: [frames] quadros de 40x40, cada um de
/// uma cor da tabela global, com [delayCentiseconds] de atraso por quadro.
/// Escrever os bytes na mão evita depender de qualquer encoder no teste.
Future<void> writeAnimatedGif(
  String path, {
  required int frames,
  required int delayCentiseconds,
}) async {
  final bytes = BytesBuilder();
  void byte(int value) => bytes.addByte(value);
  void short(int value) {
    bytes.addByte(value & 0xFF);
    bytes.addByte((value >> 8) & 0xFF);
  }

  bytes.add('GIF89a'.codeUnits);
  short(40); // largura
  short(40); // altura
  byte(0x80 | 0x01); // tabela global de 4 cores
  byte(0); // índice de fundo
  byte(0); // proporção do pixel
  // 4 cores: vermelho, verde, azul, branco.
  for (final color in [
    [255, 0, 0],
    [0, 255, 0],
    [0, 0, 255],
    [255, 255, 255],
  ]) {
    for (final channel in color) {
      byte(channel);
    }
  }

  bytes.add([0x21, 0xFF, 0x0B]); // extensão de aplicação (loop infinito)
  bytes.add('NETSCAPE2.0'.codeUnits);
  bytes.add([0x03, 0x01]);
  short(0);
  byte(0);

  for (var i = 0; i < frames; i++) {
    bytes.add([0x21, 0xF9, 0x04, 0x00]); // controle gráfico
    short(delayCentiseconds);
    bytes.add([0x00, 0x00]);

    byte(0x2C); // descritor de imagem
    short(0);
    short(0);
    short(40);
    short(40);
    byte(0);

    // Bloco LZW sem compressão de verdade: com o código mínimo de 2 bits, os
    // códigos têm 3 bits e a tabela cresce a cada par de literais — mandar um
    // "clear" (4) a cada 2 pixels reseta a tabela antes de o código precisar
    // de 4 bits, então a largura fica fixa em 3 bits o arquivo inteiro. É a
    // saída legal mais simples possível, e todo decodificador aceita.
    byte(2); // tamanho mínimo do código LZW
    final codes = <int>[];
    for (var p = 0; p < 1600; p += 2) {
      codes.add(4); // clear
      codes.add(i % 4);
      codes.add(i % 4);
    }
    codes.add(5); // fim da informação
    final bits = <int>[];
    for (final code in codes) {
      for (var b = 0; b < 3; b++) {
        bits.add((code >> b) & 1);
      }
    }
    final data = <int>[];
    for (var b = 0; b < bits.length; b += 8) {
      var value = 0;
      for (var k = 0; k < 8 && b + k < bits.length; k++) {
        value |= bits[b + k] << k;
      }
      data.add(value);
    }
    for (var offset = 0; offset < data.length; offset += 255) {
      final chunk = data.sublist(
        offset,
        offset + 255 > data.length ? data.length : offset + 255,
      );
      byte(chunk.length);
      bytes.add(chunk);
    }
    byte(0); // fim dos blocos
  }

  byte(0x3B); // fim do GIF
  await File(path).writeAsBytes(bytes.toBytes());
}
