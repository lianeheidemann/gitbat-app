import 'package:flutter/material.dart';

/// Zoom máximo da superfície de desenho. Oito vezes já deixa pincelar em
/// cima de um detalhe pequeno numa foto de 12 MP sem virar uma sopa de
/// pixels.
const _maxZoom = 8.0;

/// Zoom e deslocamento de uma [ZoomableDrawSurface]. Passar o mesmo
/// controlador a duas superfícies da mesma imagem (o Pincel e a Borracha
/// mágica, na mesma aba) mantém o enquadramento ao trocar de ferramenta.
class DrawZoomController extends ValueNotifier<({double zoom, Offset pan})> {
  DrawZoomController() : super((zoom: 1, pan: Offset.zero));

  /// `true` quando a imagem está ampliada ou deslocada — é quando vale
  /// mostrar o botão "Enquadrar".
  bool get isZoomed => value.zoom > 1.001 || value.pan != Offset.zero;

  /// Volta ao enquadramento inteiro.
  void reset() => value = (zoom: 1, pan: Offset.zero);
}

/// O que desenhar na superfície: a imagem e, por cima, o traço em andamento
/// [drawing] (em unidades da origem, `null` sem dedo na tela). [scale] leva
/// unidades da origem para a caixa, antes do zoom — quem pinta por cima
/// aplica essa escala e não precisa saber do zoom.
typedef DrawSurfaceBuilder =
    Widget Function(BuildContext context, List<Offset>? drawing, double scale);

/// Uma área de desenho com zoom: a base da seleção da Borracha mágica e do
/// Pincel.
///
/// Gestos, que é onde isto podia dar errado: **um dedo desenha, dois dedos
/// dão zoom e arrastam**. A decisão é tomada por contagem de ponteiros no
/// início do gesto, não por arena de reconhecedores — um `InteractiveViewer`
/// por fora brigaria com o arrasto do pincel pelo mesmo ponteiro, e quem
/// ganha aí depende de detalhe de ordem na árvore. Contar dedo é chato de
/// escrever uma vez e previsível para sempre.
///
/// Se um segundo dedo encosta no meio de um traço, o traço em andamento é
/// descartado e o gesto vira zoom: é quase sempre o que a pessoa queria, e
/// deixar meio traço seria pior.
///
/// Os pontos saem em **unidades da origem** ([sourceWidth] × [sourceHeight],
/// em geral pixels da foto), não da tela: assim um traço cobre a mesma área
/// com qualquer zoom.
class ZoomableDrawSurface extends StatefulWidget {
  const ZoomableDrawSurface({
    super.key,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.builder,
    required this.onStrokeEnd,
    this.enabled = true,
    this.onZoomChanged,
    this.zoom,
  });

  final double sourceWidth;
  final double sourceHeight;

  final DrawSurfaceBuilder builder;

  /// O traço terminado (o dedo saiu da tela), em unidades da origem. Só
  /// aqui ele vira estado de quem chama — cada traço é exatamente um passo.
  final ValueChanged<List<Offset>> onStrokeEnd;

  final bool enabled;

  /// Avisa quando a superfície passa de enquadrada para ampliada e
  /// vice-versa. Sem isso o botão "Enquadrar" do painel só apareceria na
  /// próxima vez que a tela se reconstruísse por outro motivo — o zoom
  /// acontece no estado deste widget, que a tela não observa.
  final ValueChanged<bool>? onZoomChanged;

  /// Enquadramento compartilhado com outra superfície; sem ele, cada uma
  /// guarda o próprio.
  final DrawZoomController? zoom;

  @override
  State<ZoomableDrawSurface> createState() => ZoomableDrawSurfaceState();
}

class ZoomableDrawSurfaceState extends State<ZoomableDrawSurface> {
  DrawZoomController? _ownZoom;
  late DrawZoomController _controller;
  late bool _wasZoomed;

  double get _zoom => _controller.value.zoom;
  Offset get _pan => _controller.value.pan;

  /// Traço sendo desenhado agora, em unidades da origem.
  List<Offset>? _drawing;

  /// Estado do gesto de dois dedos, congelado no início para o cálculo ser
  /// relativo e não acumular erro.
  double _zoomAtGestureStart = 1;
  Offset _panAtGestureStart = Offset.zero;
  Offset _focalAtGestureStart = Offset.zero;
  bool _transforming = false;

  @override
  void initState() {
    super.initState();
    _attach(widget.zoom);
  }

  @override
  void didUpdateWidget(ZoomableDrawSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zoom != widget.zoom) {
      _controller.removeListener(_onZoom);
      _attach(widget.zoom);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onZoom);
    _ownZoom?.dispose();
    super.dispose();
  }

  void _attach(DrawZoomController? shared) {
    _controller = shared ?? (_ownZoom ??= DrawZoomController());
    _wasZoomed = _controller.isZoomed;
    _controller.addListener(_onZoom);
  }

  /// Redesenha a cada mudança de enquadramento (venha ela daqui ou da outra
  /// superfície que divide o controlador) e avisa a tela só quando o estado
  /// "ampliado ou não" realmente virou.
  void _onZoom() {
    if (!mounted) return;
    setState(() {});
    final zoomed = _controller.isZoomed;
    if (zoomed != _wasZoomed) {
      _wasZoomed = zoomed;
      widget.onZoomChanged?.call(zoomed);
    }
  }

  /// `true` quando a superfície está ampliada — a tela usa isso para mostrar
  /// o botão de voltar ao enquadramento.
  bool get isZoomed => _controller.isZoomed;

  void resetZoom() => _controller.reset();

  void _setZoom(double zoom, Offset pan) =>
      _controller.value = (zoom: zoom, pan: pan);

  /// Escala entre a origem e a caixa (antes do zoom).
  double _baseScale(Size box) => box.width / widget.sourceWidth;

  /// Tela → unidades da origem. Desfaz o zoom e depois a escala da caixa.
  Offset _toSource(Offset local, Size box) {
    final unzoomed = (local - _pan) / _zoom;
    return unzoomed / _baseScale(box);
  }

  /// Mantém a imagem ancorada: nunca dá para arrastá-la para fora da caixa.
  Offset _clampPan(Offset pan, Size box, double zoom) {
    final slackX = box.width * (zoom - 1);
    final slackY = box.height * (zoom - 1);
    return Offset(pan.dx.clamp(-slackX, 0.0), pan.dy.clamp(-slackY, 0.0));
  }

  void _onScaleStart(ScaleStartDetails details, Size box) {
    _zoomAtGestureStart = _zoom;
    _panAtGestureStart = _pan;
    _focalAtGestureStart = details.localFocalPoint;

    if (details.pointerCount >= 2) {
      _transforming = true;
      return;
    }
    _transforming = false;
    setState(() => _drawing = [_toSource(details.localFocalPoint, box)]);
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size box) {
    // Segundo dedo no meio do traço: o traço em andamento é jogado fora e o
    // gesto vira zoom.
    if (details.pointerCount >= 2 && !_transforming) {
      _transforming = true;
      setState(() => _drawing = null);
      _zoomAtGestureStart = _zoom;
      _panAtGestureStart = _pan;
      _focalAtGestureStart = details.localFocalPoint;
      return;
    }

    if (_transforming) {
      final zoom = (_zoomAtGestureStart * details.scale).clamp(1.0, _maxZoom);
      // O ponto sob os dedos tem que continuar sob os dedos: é o que faz o
      // zoom parecer que gruda na imagem em vez de escorregar.
      final anchor =
          (_focalAtGestureStart - _panAtGestureStart) / _zoomAtGestureStart;
      final pan = details.localFocalPoint - anchor * zoom;
      _setZoom(zoom, _clampPan(pan, box, zoom));
      return;
    }

    final drawing = _drawing;
    if (drawing == null) return;
    final point = _toSource(details.localFocalPoint, box);
    // Descarta micro-movimentos: sem isso um arrasto lento vira centenas de
    // pontos praticamente iguais, e o caminho fica caro de desenhar à toa.
    if (drawing.isNotEmpty && (drawing.last - point).distance < 1) return;
    setState(() => drawing.add(point));
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_transforming) {
      _transforming = false;
      return;
    }
    final drawing = _drawing;
    setState(() => _drawing = null);
    if (drawing == null || drawing.isEmpty) return;
    widget.onStrokeEnd(drawing);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.sourceWidth / widget.sourceHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final box = Size(constraints.maxWidth, constraints.maxHeight);
          final content = ClipRect(
            child: Transform(
              transform: Matrix4.identity()
                ..translateByDouble(_pan.dx, _pan.dy, 0, 1)
                ..scaleByDouble(_zoom, _zoom, 1, 1),
              child: widget.builder(context, _drawing, _baseScale(box)),
            ),
          );

          if (!widget.enabled) return content;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (d) => _onScaleStart(d, box),
            onScaleUpdate: (d) => _onScaleUpdate(d, box),
            onScaleEnd: _onScaleEnd,
            child: content,
          );
        },
      ),
    );
  }
}
