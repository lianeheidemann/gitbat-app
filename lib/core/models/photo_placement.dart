import 'dart:math' as math;
import 'dart:ui' show Canvas, Rect;

/// Posição livre da foto dentro da janela dela em "Editar imagem" —
/// arrastar com um dedo, pinçar e girar com dois, direto na prévia.
///
/// Tudo é relativo à caixa onde a foto é desenhada (a janela do recorte, ou
/// o espaço da foto dentro da moldura de imagem), então vale igual na
/// prévia e na exportação, em qualquer resolução: [dx]/[dy] são frações da
/// largura/altura dessa caixa, [scale] multiplica o tamanho e [rotation]
/// gira (radianos, horário) em volta do centro da foto.
class PhotoPlacement {
  const PhotoPlacement({
    this.dx = 0,
    this.dy = 0,
    this.scale = 1,
    this.rotation = 0,
  });

  final double dx;
  final double dy;
  final double scale;
  final double rotation;

  static const identity = PhotoPlacement();

  static const minScale = 0.1;
  static const maxScale = 8.0;

  bool get isIdentity => dx == 0 && dy == 0 && scale == 1 && rotation == 0;

  PhotoPlacement copyWith({
    double? dx,
    double? dy,
    double? scale,
    double? rotation,
  }) => PhotoPlacement(
    dx: dx ?? this.dx,
    dy: dy ?? this.dy,
    scale: (scale ?? this.scale).clamp(minScale, maxScale).toDouble(),
    rotation: rotation ?? this.rotation,
  );

  /// Aplica a posição no [canvas] para desenhar a foto em [box]: move o
  /// centro, gira e escala em volta dele. Mesma ordem da prévia
  /// (`FractionalTranslation` > `Transform.rotate` > `Transform.scale`).
  void applyTo(Canvas canvas, Rect box) {
    if (isIdentity) return;
    final center = box.center;
    canvas.translate(center.dx + dx * box.width, center.dy + dy * box.height);
    canvas.rotate(rotation);
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);
  }

  /// Giro em graus, entre -180 e 180 — para mostrar na tela.
  double get rotationDegrees {
    var degrees = rotation * 180 / math.pi % 360;
    if (degrees > 180) degrees -= 360;
    return degrees;
  }

  @override
  bool operator ==(Object other) =>
      other is PhotoPlacement &&
      other.dx == dx &&
      other.dy == dy &&
      other.scale == scale &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(dx, dy, scale, rotation);
}
