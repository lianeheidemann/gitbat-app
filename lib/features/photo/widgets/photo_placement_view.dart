import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/photo_placement.dart';

/// Desenha [child] (a foto) na posição de [placement] e, com [enabled],
/// deixa mudar essa posição com os dedos: um dedo arrasta, dois pinçam e
/// giram, dois toques voltam ao original.
///
/// Como nos editores de imagem, a foto "gruda" no centro horizontal e
/// vertical da caixa (com uma guia enquanto está travada), no tamanho
/// original e nos ângulos retos quando chega perto — seguindo o gesto, ela
/// solta.
class PhotoPlacementView extends StatefulWidget {
  const PhotoPlacementView({
    super.key,
    required this.placement,
    required this.enabled,
    required this.onGestureStart,
    required this.onChanged,
    required this.child,
    this.mirrored = false,
  });

  final PhotoPlacement placement;
  final bool enabled;

  /// Começo de um gesto — ponto de desfazer.
  final VoidCallback onGestureStart;
  final ValueChanged<PhotoPlacement> onChanged;
  final Widget child;

  /// A prévia está espelhada por fora (aba "Girar"): o giro dos dedos vira
  /// o contrário para a foto.
  final bool mirrored;

  /// Distância do centro, em fração da caixa, em que a foto gruda nele.
  static const centerSnap = 0.02;

  /// Quanto (em graus) perto de um ângulo reto o giro gruda nele.
  static const angleSnapDegrees = 4.0;

  /// Quanto perto de 100% o tamanho gruda nele.
  static const scaleSnap = 0.03;

  /// Aplica as travas a uma posição "livre" (a que os dedos pedem) numa
  /// caixa.
  static PhotoPlacement snapped(PhotoPlacement free) {
    final dx = free.dx.abs() <= centerSnap ? 0.0 : free.dx;
    final dy = free.dy.abs() <= centerSnap ? 0.0 : free.dy;
    const quarter = math.pi / 2;
    final nearestRight = (free.rotation / quarter).round() * quarter;
    final rotation =
        (free.rotation - nearestRight).abs() <= angleSnapDegrees * math.pi / 180
        ? nearestRight
        : free.rotation;
    final scale = (free.scale - 1).abs() <= scaleSnap ? 1.0 : free.scale;
    return free.copyWith(dx: dx, dy: dy, rotation: rotation, scale: scale);
  }

  @override
  State<PhotoPlacementView> createState() => _PhotoPlacementViewState();
}

class _PhotoPlacementViewState extends State<PhotoPlacementView> {
  PhotoPlacement _start = PhotoPlacement.identity;
  Offset _startFocal = Offset.zero;
  int _pointers = 0;
  bool _active = false;

  void _begin(Offset focal, int pointers) {
    _start = _free ?? widget.placement;
    _startFocal = focal;
    _pointers = pointers;
  }

  /// Posição sem as travas durante o gesto — para soltar do centro basta
  /// seguir arrastando.
  PhotoPlacement? _free;

  @override
  Widget build(BuildContext context) {
    final p = widget.placement;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        Widget content = FractionalTranslation(
          translation: Offset(p.dx, p.dy),
          child: Transform.rotate(
            angle: p.rotation,
            child: Transform.scale(scale: p.scale, child: widget.child),
          ),
        );
        if (!widget.enabled) return content;

        const guide = Color(0xFFFF4FD8);
        content = Stack(
          fit: StackFit.passthrough,
          children: [
            content,
            if (_active && p.dx == 0)
              Positioned(
                key: const ValueKey('photoCenterGuideVertical'),
                left: size.width / 2 - 0.75,
                width: 1.5,
                top: 0,
                bottom: 0,
                child: const IgnorePointer(child: ColoredBox(color: guide)),
              ),
            if (_active && p.dy == 0)
              Positioned(
                key: const ValueKey('photoCenterGuideHorizontal'),
                top: size.height / 2 - 0.75,
                height: 1.5,
                left: 0,
                right: 0,
                child: const IgnorePointer(child: ColoredBox(color: guide)),
              ),
          ],
        );

        return GestureDetector(
          key: const ValueKey('photoPlacementGesture'),
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () {
            widget.onGestureStart();
            widget.onChanged(PhotoPlacement.identity);
          },
          onScaleStart: (details) {
            widget.onGestureStart();
            _free = widget.placement;
            _begin(details.localFocalPoint, details.pointerCount);
            setState(() => _active = true);
          },
          onScaleUpdate: (details) {
            if (details.pointerCount != _pointers) {
              // Entrou ou saiu um dedo: recomeça a conta daqui, sem pular.
              _begin(details.localFocalPoint, details.pointerCount);
              return;
            }
            if (size.width <= 0 || size.height <= 0) return;
            final move = details.localFocalPoint - _startFocal;
            final turn = details.rotation * (widget.mirrored ? -1 : 1);
            final free = _start.copyWith(
              dx: _start.dx + move.dx / size.width,
              dy: _start.dy + move.dy / size.height,
              scale: _pointers >= 2 ? _start.scale * details.scale : null,
              rotation: _pointers >= 2 ? _start.rotation + turn : null,
            );
            // Guarda a livre para os próximos quadros, mas mostra a travada.
            _free = free;
            widget.onChanged(PhotoPlacementView.snapped(free));
          },
          onScaleEnd: (_) {
            _free = null;
            _pointers = 0;
            setState(() => _active = false);
          },
          child: content,
        );
      },
    );
  }
}
