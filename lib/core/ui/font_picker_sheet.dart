import '../../app/language_controller.dart';
import '../../app/translations.dart';
import 'package:flutter/material.dart';

import '../models/collage_text.dart';
import '../services/imported_font_store.dart';
import 'font_thumb.dart';

/// Folha de escolher a fonte de um texto: as embutidas
/// ([bundledCollageFonts]) e as importadas em miniaturas "Aa", cada uma
/// desenhada na própria fonte, e o ladrilho de importar. Tocar escolhe e
/// fecha a folha. A mesma folha na Montagem e nos outros editores.
///
/// Com [onRemoveImported], segurar uma fonte importada remove — só a
/// Montagem oferece isso.
void showFontPickerSheet(
  BuildContext context, {
  required String? selectedFamily,
  required List<ImportedFont> importedFonts,
  required ValueChanged<String?> onSelected,
  required VoidCallback onImport,
  ValueChanged<ImportedFont>? onRemoveImported,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Fonte', 'Font'),
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final font in bundledCollageFonts)
                  CollageFontThumb(
                    family: font.$1,
                    label: trKey(font.$2),
                    selected: selectedFamily == font.$1,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onSelected(font.$1);
                    },
                  ),
                // As importadas ficam na mesma grade das embutidas.
                for (final font in importedFonts)
                  CollageFontThumb(
                    family: font.family,
                    label: font.label,
                    selected: selectedFamily == font.family,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onSelected(font.family);
                    },
                    onLongPress: onRemoveImported == null
                        ? null
                        : () {
                            Navigator.of(sheetContext).pop();
                            onRemoveImported(font);
                          },
                  ),
                CollageFontThumb(
                  family: null,
                  label: tr('Importar', 'Import'),
                  selected: false,
                  icon: Icons.font_download_outlined,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onImport();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
