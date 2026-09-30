import '../../../app/editor_defaults.dart';
import 'collage_background.dart';
import 'collage_cell.dart';

/// As cores da paleta atual ([EditorDefaults]) aplicadas aos modelos da
/// montagem — lidas na hora em que a montagem começa ou a área é criada, como
/// as das outras telas.
abstract final class CollageDefaults {
  static CollageBackground background() =>
      CollageBackground(color: EditorDefaults.background);

  /// Estilo de uma área nova da montagem.
  static CollageCellSettings cell() => CollageCellSettings(
    borderColor: EditorDefaults.frame,
    background: background(),
  );
}
