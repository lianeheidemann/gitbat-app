import 'dart:math' as math;

import 'package:flutter/gestures.dart'
    show Drag, ImmediateMultiDragGestureRecognizer;
import 'package:flutter/material.dart';

import '../models/photo_placement.dart';

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

  /// Foto tocada: mostra o contorno e as alças de redimensionar e girar.
  bool _selected = false;

  /// Quantas unidades da caixa cabem num pixel da tela — dentro da moldura
  /// de imagem a caixa passa por um `FittedBox`, e sem isto as alças
  /// sairiam minúsculas ou enormes.
  double _unitsPerPixel = 1;
  final _boxKey = GlobalKey();

  // Arrasto de uma alça: posição do dedo (na caixa) e o ponto de partida.
  Offset _handlePos = Offset.zero;
  Offset _handleStart = Offset.zero;

  void _begin(Offset focal, int pointers) {
    _start = _free ?? widget.placement;
    _startFocal = focal;
    _pointers = pointers;
  }

  /// Posição sem as travas durante o gesto — para soltar do centro basta
  /// seguir arrastando.
  PhotoPlacement? _free;

  @override
  void didUpdateWidget(covariant PhotoPlacementView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _selected = false;
  }

  void _measure() {
    final box = _boxKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final a = box.localToGlobal(Offset.zero);
    final b = box.localToGlobal(const Offset(100, 0));
    final pixels = (b - a).distance / 100;
    if (pixels <= 0) return;
    final units = 1 / pixels;
    if ((units - _unitsPerPixel).abs() > 0.01 && mounted) {
      setState(() => _unitsPerPixel = units);
    }
  }

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
        WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

        const guide = Color(0xFFFF4FD8);
        content = Stack(
          key: _boxKey,
          fit: StackFit.passthrough,
          children: [
            content,
            if (_active && p.dx == 0)
              Positioned(
                key: const ValueKey('photoCenterGuideVertical'),
                left: size.width / 2 - 0.75 * _unitsPerPixel,
                width: 1.5 * _unitsPerPixel,
                top: 0,
                bottom: 0,
                child: const IgnorePointer(child: ColoredBox(color: guide)),
              ),
            if (_active && p.dy == 0)
              Positioned(
                key: const ValueKey('photoCenterGuideHorizontal'),
                top: size.height / 2 - 0.75 * _unitsPerPixel,
                height: 1.5 * _unitsPerPixel,
                left: 0,
                right: 0,
                child: const IgnorePointer(child: ColoredBox(color: guide)),
              ),
            if (_selected) ..._handles(context, size, p),
          ],
        );

        return GestureDetector(
          key: const ValueKey('photoPlacementGesture'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _selected = !_selected),
          onDoubleTap: () {
            widget.onGestureStart();
            widget.onChanged(PhotoPlacement.identity);
          },
          onScaleStart: (details) {
            widget.onGestureStart();
            _free = widget.placement;
            _begin(details.localFocalPoint, details.pointerCount);
            setState(() {
              _active = true;
              _selected = true;
            });
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

  /// Contorno da foto (já movida, escalada e girada) e as duas alças: a de
  /// baixo à direita redimensiona com um dedo, a de cima à direita gira.
  /// As alças ficam sempre dentro da caixa, para o recorte da prévia não
  /// escondê-las.
  List<Widget> _handles(BuildContext context, Size size, PhotoPlacement p) {
    final center = Offset(
      size.width / 2 + p.dx * size.width,
      size.height / 2 + p.dy * size.height,
    );
    final hw = size.width * p.scale / 2;
    final hh = size.height * p.scale / 2;
    final cosR = math.cos(p.rotation);
    final sinR = math.sin(p.rotation);
    Offset rotate(Offset o) =>
        Offset(o.dx * cosR - o.dy * sinR, o.dx * sinR + o.dy * cosR);
    final corners = [
      center + rotate(Offset(-hw, -hh)),
      center + rotate(Offset(hw, -hh)),
      center + rotate(Offset(hw, hh)),
      center + rotate(Offset(-hw, hh)),
    ];
    final u = _unitsPerPixel;
    final touch = 44 * u;
    Offset clampIn(Offset o) => Offset(
      o.dx.clamp(touch / 2, math.max(touch / 2, size.width - touch / 2)),
      o.dy.clamp(touch / 2, math.max(touch / 2, size.height - touch / 2)),
    );
    final scheme = Theme.of(context).colorScheme;

    Widget handle({
      required Key key,
      required Offset at,
      required IconData icon,
      required void Function(Offset delta) onDrag,
    }) {
      final pos = clampIn(at);
      return Positioned(
        key: key,
        left: pos.dx - touch / 2,
        top: pos.dy - touch / 2,
        width: touch,
        height: touch,
        // Pega o dedo na hora (sem disputar com a rolagem da página nem com
        // o arrasto da foto), como as alças de texto e sticker.
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            ImmediateMultiDragGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  ImmediateMultiDragGestureRecognizer
                >(ImmediateMultiDragGestureRecognizer.new, (recognizer) {
                  recognizer.onStart = (_) {
                    widget.onGestureStart();
                    _handleStart = at;
                    _handlePos = at;
                    _start = widget.placement;
                    setState(() => _active = true);
                    return _HandleDrag(
                      onUpdate: onDrag,
                      onEnd: () {
                        if (mounted) setState(() => _active = false);
                      },
                    );
                  };
                }),
          },
          child: Center(
            child: Container(
              width: 24 * u,
              height: 24 * u,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2 * u),
              ),
              child: Icon(icon, size: 13 * u, color: scheme.onPrimary),
            ),
          ),
        ),
      );
    }

    return [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _OutlinePainter(
              corners: corners,
              color: scheme.primary,
              width: 1.5 * u,
            ),
          ),
        ),
      ),
      handle(
        key: const ValueKey('photoResizeHandle'),
        at: corners[2],
        icon: Icons.open_in_full_rounded,
        onDrag: (delta) {
          _handlePos += delta;
          final startDist = (_handleStart - center).distance;
          if (startDist < 1) return;
          final ratio = (_handlePos - center).distance / startDist;
          widget.onChanged(
            PhotoPlacementView.snapped(
              _start.copyWith(scale: _start.scale * ratio),
            ),
          );
        },
      ),
      handle(
        key: const ValueKey('photoRotateHandle'),
        at: corners[1],
        icon: Icons.rotate_right_rounded,
        onDrag: (delta) {
          _handlePos += delta;
          final a0 = (_handleStart - center).direction;
          final a1 = (_handlePos - center).direction;
          final turn = (a1 - a0) * (widget.mirrored ? -1 : 1);
          widget.onChanged(
            PhotoPlacementView.snapped(
              _start.copyWith(rotation: _start.rotation + turn),
            ),
          );
        },
      ),
    ];
  }
}

/// Arrasto de uma alça: repassa só o deslocamento de cada quadro.
class _HandleDrag extends Drag {
  _HandleDrag({required this.onUpdate, required this.onEnd});

  final void Function(Offset delta) onUpdate;
  final VoidCallback onEnd;

  @override
  void update(DragUpdateDetails details) => onUpdate(details.delta);

  @override
  void end(DragEndDetails details) => onEnd();

  @override
  void cancel() => onEnd();
}

class _OutlinePainter extends CustomPainter {
  const _OutlinePainter({
    required this.corners,
    required this.color,
    required this.width,
  });

  final List<Offset> corners;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addPolygon(corners, true);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(covariant _OutlinePainter old) =>
      old.color != color || old.width != width || old.corners != corners;
}
