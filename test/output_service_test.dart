import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:video_to_gif/core/services/output_service.dart';

// Tudo o que o app salva ou compartilha sai com o nome da marca.

void main() {
  test('nome do arquivo começa com GitBat_ e leva a data/hora', () {
    final when = DateTime(2026, 9, 7, 8, 5, 3);
    expect(
      OutputService.brandedFileName('gif', when),
      'GitBat_20260907_080503.gif',
    );
    expect(OutputService.brandedFileName('', when), 'GitBat_20260907_080503');
  });

  test('cópia com o nome da marca, sem mexer no original', () async {
    final dir = await Directory.systemTemp.createTemp('saida_');
    addTearDown(() => dir.delete(recursive: true));
    final original = await File('${dir.path}/mp4_123.mp4').writeAsString('x');

    final branded = await OutputService.brandedCopy(
      original,
      now: DateTime(2026, 1, 2, 3, 4, 5),
    );

    expect(branded.uri.pathSegments.last, 'GitBat_20260102_030405.mp4');
    expect(await branded.readAsString(), 'x');
    expect(await original.exists(), isTrue);
    // Já com a marca: usa o próprio arquivo.
    expect((await OutputService.brandedCopy(branded)).path, branded.path);
  });
}
