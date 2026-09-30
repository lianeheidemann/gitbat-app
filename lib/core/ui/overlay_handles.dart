import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Estado de um arrasto das alças de redimensionar e girar do sticker/texto
/// selecionado, entre um quadro do gesto e o próximo — as alças são
/// `Listener`s soltos na pilha, sem `State` próprio, então quem guarda isto
/// é o dono da pilha.
///
/// As contas são as mesmas na Montagem e nos outros editores: [resize] e
/// [rotate] devolvem o valor novo (ou `null` quando nada muda) e chamam o
/// `onFirstChange` uma vez por arrasto, antes da primeira mudança — o ponto
/// de desfazer.
class OverlayHandleDrag {
  bool _resizeCheckpointPushed = false;
  bool _rotateCheckpointPushed = false;

  /// Posição do dedo durante o arrasto da alça de girar, acumulada a partir
  /// de `event.delta` — não há `RenderBox` para medir o dedo direto, então
  /// ela parte de onde a alça estava no toque inicial.
  Offset? _rotatePointerPos;
  double? _lastRotateAngle;

  /// O dedo tocou a alça de redimensionar.
  void startResize() => _resizeCheckpointPushed = false;

  /// O dedo tocou a alça de girar, centrada em [handleCenter].
  void startRotate(Offset handleCenter) {
    _rotateCheckpointPushed = false;
    _rotatePointerPos = handleCenter;
    _lastRotateAngle = null;
  }

  /// A escala depois de um passo do arrasto da alça de redimensionar. Desfaz
  /// a rotação atual do vetor de arrasto e soma as duas componentes locais —
  /// arrastar para longe do centro (direita/baixo, sem girar) cresce; para
  /// perto, encolhe —, como fração do menor lado de [canvasSize].
  double? resize(
    PointerMoveEvent event, {
    required double scale,
    required double rotation,
    required double minScale,
    required double maxScale,
    required Size canvasSize,
    VoidCallback? onFirstChange,
  }) {
    final reference = canvasSize.shortestSide;
    if (reference <= 0) return null;
    final cosA = math.cos(rotation);
    final sinA = math.sin(rotation);
    final local = Offset(
      event.delta.dx * cosA + event.delta.dy * sinA,
      -event.delta.dx * sinA + event.delta.dy * cosA,
    );
    final scaleDelta = (local.dx + local.dy) / reference;
    if (scaleDelta == 0) return null;
    final newScale = (scale + scale * scaleDelta).clamp(minScale, maxScale);
    if (newScale == scale) return null;
    if (!_resizeCheckpointPushed) {
      _resizeCheckpointPushed = true;
      onFirstChange?.call();
    }
    return newScale;
  }

  /// A rotação depois de um passo do arrasto da alça de girar em volta de
  /// [center]: o ângulo que o dedo andou desde o passo anterior.
  double? rotate(
    PointerMoveEvent event, {
    required Offset center,
    required double rotation,
    VoidCallback? onFirstChange,
  }) {
    final pos = (_rotatePointerPos ?? center) + event.delta;
    _rotatePointerPos = pos;
    final vector = pos - center;
    if (vector.distance < 1) return null;
    final angle = math.atan2(vector.dy, vector.dx);
    final last = _lastRotateAngle;
    _lastRotateAngle = angle;
    if (last == null) return null;
    var delta = angle - last;
    // Normaliza a virada de -pi/pi, senão passar por trás do item daria um
    // giro de volta inteira num quadro só.
    while (delta > math.pi) {
      delta -= 2 * math.pi;
    }
    while (delta < -math.pi) {
      delta += 2 * math.pi;
    }
    if (delta == 0) return null;
    if (!_rotateCheckpointPushed) {
      _rotateCheckpointPushed = true;
      onFirstChange?.call();
    }
    return rotation + delta;
  }
}

/// Onde ficam as alças de um item sobreposto no canvas de [canvasSize]: o
/// centro dele e três cantos da caixa girada ([naturalSize] vezes [scale]).
/// Calculado, sem medir nada em tempo de execução.
({Offset center, Offset topLeft, Offset topRight, Offset bottomRight})
overlayHandlePoints({
  required double centerX,
  required double centerY,
  required Size naturalSize,
  required double scale,
  required double rotation,
  required Size canvasSize,
}) {
  final center = Offset(
    centerX * canvasSize.width,
    centerY * canvasSize.height,
  );
  final halfW = naturalSize.width * scale / 2;
  final halfH = naturalSize.height * scale / 2;
  final cosR = math.cos(rotation);
  final sinR = math.sin(rotation);
  Offset rotate(Offset local) => Offset(
    local.dx * cosR - local.dy * sinR,
    local.dx * sinR + local.dy * cosR,
  );
  return (
    center: center,
    topLeft: center + rotate(Offset(-halfW, -halfH)),
    topRight: center + rotate(Offset(halfW, -halfH)),
    bottomRight: center + rotate(Offset(halfW, halfH)),
  );
}

/// Uma alça (redimensionar, girar ou remover) do item selecionado: um
/// círculo de 24 centrado em [center], com área de toque de 48 — o mínimo
/// recomendado, para não ficar difícil de acertar em telas pequenas.
///
/// Arrastável ([onPointerDown]/[onPointerMove]) ou de toque ([onTap]).
class OverlayHandle extends StatelessWidget {
  const OverlayHandle({
    super.key,
    required this.center,
    required this.icon,
    required this.iconSize,
    this.destructive = false,
    this.onPointerDown,
    this.onPointerMove,
    this.onTap,
  });

  final Offset center;
  final IconData icon;
  final double iconSize;

  /// Na cor de erro do tema (remover), em vez da primária.
  final bool destructive;

  final void Function(PointerDownEvent)? onPointerDown;
  final void Function(PointerMoveEvent)? onPointerMove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const diameter = 24.0;
    const tapSize = 48.0;
    final circle = SizedBox(
      width: tapSize,
      height: tapSize,
      child: Center(
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            color: destructive
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.surface, width: 2),
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: destructive
                ? theme.colorScheme.onError
                : theme.colorScheme.onPrimary,
          ),
        ),
      ),
    );
    return Positioned(
      left: center.dx - tapSize / 2,
      top: center.dy - tapSize / 2,
      child: onTap != null
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: circle,
            )
          : Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: onPointerDown,
              onPointerMove: onPointerMove,
              child: circle,
            ),
    );
  }
}
