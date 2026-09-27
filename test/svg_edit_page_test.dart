import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_to_gif/core/ui/editor_tabs_footer.dart';
import 'package:video_to_gif/features/svg/models/svg_info.dart';
import 'package:video_to_gif/features/svg/svg_edit_page.dart';

const _sampleSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 80" '
    'width="120" height="80">'
    '<rect x="10" y="10" width="40" height="40" fill="#ff0000"/>'
    '</svg>';

void main() {
  late Directory tempDir;
  late String svgPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('svg_edit_page_test');
    svgPath = '${tempDir.path}/exemplo.svg';
    await File(svgPath).writeAsString(_sampleSvg);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  testWidgets('abre na aba Recorte, sem erro, com as abas esperadas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SvgEditPage(svg: SvgInfo(path: svgPath, width: 120, height: 80)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Editar SVG'), findsOneWidget);
    expect(find.text('Recorte'), findsWidgets);
    expect(find.text('Girar'), findsWidgets);
    expect(find.text('Fundo'), findsWidgets);
    expect(find.text('Filtro'), findsWidgets);
    expect(find.text('Opacidade'), findsWidgets);
    await _showTab(tester, 'Configurações');
    expect(find.text('Configurações'), findsWidgets);
  });

  testWidgets('escolher uma proporção trava o recorte e some com as abas '
      'seguintes sem erro', (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SvgEditPage(svg: SvgInfo(path: svgPath, width: 120, height: 80)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, '1:1'));
    await tester.pumpAndSettle();

    // Trocar de aba não deve quebrar nada — a prévia decorada (girar/
    // espelhar/filtro/opacidade/fundo) entra no lugar do overlay de recorte.
    await tester.tap(find.text('Girar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Girar').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filtro').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preto e branco'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

/// Rola a barra de abas até [label] aparecer (as abas do fim ficam fora da
/// tela e a lista só constrói o que está visível).
Future<void> _showTab(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    120,
    scrollable: find
        .descendant(
          of: find.byType(EditorTabsFooter),
          matching: find.byType(Scrollable),
        )
        .last,
  );
  await tester.pumpAndSettle();
}
