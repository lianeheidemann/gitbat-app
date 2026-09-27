import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

// Os selos do topo da tela inicial são cópias sem CSS da arte de
// assets/badge (tool/gerar_selos_do_app.py): o flutter_svg ignora <style>,
// então as cores precisam estar em cada elemento.

void main() {
  for (final tema in ['claro', 'escuro']) {
    test('selos do tema $tema abrem no flutter_svg, sem classes CSS', () async {
      final svg = File(
        'recursos/marca/gitbat-selos-$tema.svg',
      ).readAsStringSync();
      expect(svg, isNot(contains('<style')));
      expect(svg, isNot(contains('class=')));
      final info = await vg.loadPicture(SvgStringLoader(svg), null);
      expect(info.size, const Size(1540, 92));
      info.picture.dispose();
    });
  }
}
