import 'dart:ui' show Offset;

import '../../models/crop_rect.dart';
import 'crop_overlay.dart';

/// Regras de recorte comuns às três telas que recortam uma fonte de tamanho
/// fixo: Editar vídeo (vídeo), Moldura (foto) e Editar SVG.
///
/// Guarda só o que as três compartilham — os limites da fonte, o mínimo de
/// cada lado e a sobra fracionária do arrasto. Quem grava o recorte continua
/// sendo a página, porque cada uma o guarda num lugar diferente
/// (`ConversionSettings.crop`, `FrameSettings.crop`, `SvgEditSettings.crop`)
/// e com a própria pilha de desfazer.
///
/// Os deltas de arrasto chegam **já convertidos para pixels da fonte**. Essa
/// conversão é a única parte do arrasto que não é comum: o vídeo e a foto
/// escalam pela prévia, e o SVG ainda desfaz rotação e espelho antes.
class CropController {
  CropController({
    required this.sourceWidth,
    required this.sourceHeight,
    this.evenOnly = false,
    this.accumulateDragRemainder = true,
    this.minHandleSize,
  });

  final int sourceWidth;
  final int sourceHeight;

  /// Arredonda largura e altura para baixo até o par mais próximo, com
  /// mínimo 2. Exigência dos filtros `crop`/`scale` do FFmpeg, então só a
  /// tela de vídeo liga isso — foto e SVG aceitam qualquer inteiro ≥ 1.
  final bool evenOnly;

  /// Acumula a sobra fracionária de um frame de gesto para o próximo, em vez
  /// de descartá-la. Sem isso, uma fonte de baixa resolução exibida bem maior
  /// que o tamanho nativo faz o arrasto parecer travado e depois "pular",
  /// porque cada frame sozinho não fecha um pixel inteiro da fonte.
  ///
  /// A tela de vídeo não acumula — mantido como estava para não mudar o
  /// comportamento dela nesta refatoração.
  final bool accumulateDragRemainder;

  /// Janela mínima arrastável pela alça, quando diferente do padrão de
  /// [resizeFreeCrop]/[resizeLockedCrop]. O SVG usa um valor menor: 32
  /// quebraria um ícone de 24x24, bem comum no formato.
  final double? minHandleSize;

  Offset _resizeRemainder = Offset.zero;
  Offset _moveRemainder = Offset.zero;

  /// Menor valor aceito para cada lado do recorte.
  int get minSide => evenOnly ? 2 : 1;

  /// Arredonda para o número par mais próximo abaixo (mínimo 2) quando
  /// [evenOnly] está ligado; caso contrário devolve o valor intacto.
  int snap(int value) {
    if (!evenOnly) return value;
    if (value <= 2) return 2;
    return value.isEven ? value : value - 1;
  }

  /// Monta um [CropRect] com o tamanho dado, centralizado em [around] (ou no
  /// centro da fonte, se omitido), sem ultrapassar as bordas.
  CropRect centeredOn(int width, int height, {CropRect? around}) {
    final safeWidth = snap(width.clamp(minSide, sourceWidth));
    final safeHeight = snap(height.clamp(minSide, sourceHeight));

    final centerX = around == null
        ? sourceWidth / 2
        : around.x + around.width / 2;
    final centerY = around == null
        ? sourceHeight / 2
        : around.y + around.height / 2;

    final maxX = sourceWidth - safeWidth;
    final maxY = sourceHeight - safeHeight;
    final x = (centerX - safeWidth / 2).round().clamp(0, maxX);
    final y = (centerY - safeHeight / 2).round().clamp(0, maxY);

    return CropRect(x: x, y: y, width: safeWidth, height: safeHeight);
  }

  /// Maior janela com o formato de [crop] (largura ÷ altura) que cabe na
  /// fonte — o 100% do controle "Tamanho da janela".
  (double, double) _maxSizeFor(CropRect crop) {
    final aspect = crop.aspectRatio;
    var width = sourceWidth.toDouble();
    var height = width / aspect;
    if (height > sourceHeight) {
      height = sourceHeight.toDouble();
      width = height * aspect;
    }
    return (width, height);
  }

  /// Tamanho de [crop] em relação à maior janela do mesmo formato que cabe
  /// na fonte, em % (1 a 100) — o valor do controle "Tamanho da janela".
  int sizePercentOf(CropRect crop) {
    final (maxWidth, _) = _maxSizeFor(crop);
    return (crop.width / maxWidth * 100).round().clamp(1, 100);
  }

  /// [crop] redimensionada para [percent]% da maior janela do mesmo formato
  /// que cabe na fonte — o controle "Tamanho da janela". Mantém o formato e
  /// o centro (encostando nas bordas quando precisar).
  CropRect scaledTo(int percent, {required CropRect crop}) {
    final (maxWidth, maxHeight) = _maxSizeFor(crop);
    final factor = percent.clamp(1, 100) / 100;
    return centeredOn(
      (maxWidth * factor).round(),
      (maxHeight * factor).round(),
      around: crop,
    );
  }

  /// A mesma janela ([crop], com o mesmo tamanho) movida para o centro da
  /// fonte — o botão "Centralizar".
  CropRect centered(CropRect crop) => centeredOn(crop.width, crop.height);

  /// Recorte inicial do preset "Personalizado": 80% da fonte, centralizado.
  CropRect defaultCustomCrop() {
    final width = (sourceWidth * 0.8).round().clamp(minSide, sourceWidth);
    final height = (sourceHeight * 0.8).round().clamp(minSide, sourceHeight);
    return centeredOn(width, height);
  }

  /// Recorte centralizado na fonte inteira para uma proporção travada.
  CropRect forRatio(double ratio) =>
      CropRect.centeredIn(sourceWidth, sourceHeight, ratio);

  /// Aplica uma nova largura, ajustando a altura para manter [ratio] quando
  /// um preset fixo está selecionado (passe `null` para largura livre).
  CropRect withWidth(int width, {required CropRect crop, double? ratio}) {
    var w = snap(width.clamp(minSide, sourceWidth));
    int h;
    if (ratio != null) {
      h = snap((w / ratio).round().clamp(minSide, sourceHeight));
      w = snap((h * ratio).round().clamp(minSide, sourceWidth));
    } else {
      h = crop.height;
    }
    return centeredOn(w, h, around: crop);
  }

  /// Espelho de [withWidth] para a altura.
  CropRect withHeight(int height, {required CropRect crop, double? ratio}) {
    var h = snap(height.clamp(minSide, sourceHeight));
    int w;
    if (ratio != null) {
      w = snap((h * ratio).round().clamp(minSide, sourceWidth));
      h = snap((w / ratio).round().clamp(minSide, sourceHeight));
    } else {
      w = crop.width;
    }
    return centeredOn(w, h, around: crop);
  }

  /// Recalcula o recorte a partir do arrasto de uma alça, livre ou travado a
  /// [ratio]. Devolve `null` quando nada mudou — com [accumulateDragRemainder]
  /// ligado, a sobra fica guardada para o próximo frame do gesto.
  CropRect? resizeBy({
    required CropRect crop,
    required CropHandle handle,
    required Offset sourceDelta,
    double? ratio,
  }) {
    final dx = _resizeRemainder.dx + sourceDelta.dx;
    final dy = _resizeRemainder.dy + sourceDelta.dy;

    final next = ratio == null
        ? resizeFreeCrop(
            crop,
            handle,
            dx,
            dy,
            boundsWidth: sourceWidth,
            boundsHeight: sourceHeight,
            minSize: minHandleSize ?? 32,
          )
        : resizeLockedCrop(
            crop,
            handle,
            dx,
            dy,
            ratio,
            boundsWidth: sourceWidth,
            boundsHeight: sourceHeight,
            minSide: minHandleSize ?? 32,
          );

    if (next.width == crop.width &&
        next.height == crop.height &&
        next.x == crop.x &&
        next.y == crop.y) {
      if (accumulateDragRemainder) _resizeRemainder = Offset(dx, dy);
      return null;
    }

    _resizeRemainder = Offset.zero;
    return next;
  }

  /// Desloca a janela inteira, sem deixá-la sair da área da fonte. Devolve
  /// `null` quando nada mudou.
  ///
  /// Com [snapDistance] (em pixels da fonte, por eixo), a janela "gruda" no
  /// centro horizontal e/ou vertical da fonte quando o centro dela chega a
  /// essa distância — como nos editores de imagem. A posição sem a trava
  /// continua sendo acompanhada durante o gesto, então basta seguir
  /// arrastando para soltar do centro.
  CropRect? moveBy({
    required CropRect crop,
    required Offset sourceDelta,
    Offset? snapDistance,
  }) {
    final maxX = (sourceWidth - crop.width).clamp(0, sourceWidth);
    final maxY = (sourceHeight - crop.height).clamp(0, sourceHeight);

    int x;
    int y;
    if (snapDistance != null) {
      // Recomeça do recorte atual quando ele mudou por fora (outro gesto,
      // preset, desfazer) desde o último movimento.
      var free = _freeMove;
      if (free == null || !_same(_lastMoved, crop)) {
        free = Offset(crop.x.toDouble(), crop.y.toDouble());
      }
      free = Offset(
        (free.dx + sourceDelta.dx).clamp(0.0, maxX.toDouble()),
        (free.dy + sourceDelta.dy).clamp(0.0, maxY.toDouble()),
      );
      _freeMove = free;
      final centeredX = (sourceWidth - crop.width) / 2;
      final centeredY = (sourceHeight - crop.height) / 2;
      x = ((free.dx - centeredX).abs() <= snapDistance.dx ? centeredX : free.dx)
          .round()
          .clamp(0, maxX);
      y = ((free.dy - centeredY).abs() <= snapDistance.dy ? centeredY : free.dy)
          .round()
          .clamp(0, maxY);
    } else if (accumulateDragRemainder) {
      final dx = sourceDelta.dx + _moveRemainder.dx;
      final dy = sourceDelta.dy + _moveRemainder.dy;
      final rawX = (crop.x + dx).clamp(0.0, maxX.toDouble());
      final rawY = (crop.y + dy).clamp(0.0, maxY.toDouble());
      x = rawX.round();
      y = rawY.round();
      // Guarda só o resto do arredondamento, nunca o quanto passou do limite
      // já clampado — senão arrastar bem além da borda exigiria arrastar de
      // volta o mesmo tanto antes da janela voltar a se mexer.
      _moveRemainder = Offset(rawX - x, rawY - y);
    } else {
      x = (crop.x + sourceDelta.dx.round()).clamp(0, maxX);
      y = (crop.y + sourceDelta.dy.round()).clamp(0, maxY);
    }

    if (x == crop.x && y == crop.y) return null;
    final next = crop.copyWith(x: x, y: y);
    _lastMoved = next;
    return next;
  }

  /// Se o centro de [crop] está no centro horizontal/vertical da fonte (a
  /// menos de meio pixel, por causa do arredondamento) — para a prévia
  /// mostrar as guias da trava.
  (bool horizontal, bool vertical) centerAlignment(CropRect crop) => (
    ((crop.x + crop.width / 2) - sourceWidth / 2).abs() <= 0.5,
    ((crop.y + crop.height / 2) - sourceHeight / 2).abs() <= 0.5,
  );

  Offset? _freeMove;
  CropRect? _lastMoved;
  CropRect? _pinchStart;

  /// Começo de uma pinça sobre a janela: guarda o recorte de partida.
  void pinchStart(CropRect crop) => _pinchStart = crop;

  /// A janela da pinça com [scale] vezes o tamanho de quando ela começou,
  /// mesmo formato e mesmo centro (encostando nas bordas quando precisar).
  /// Devolve `null` sem pinça começada ou quando nada muda.
  CropRect? pinchTo(double scale, {required CropRect crop}) {
    final start = _pinchStart;
    if (start == null || scale <= 0) return null;
    final minScale = [
      minSide / start.width,
      minSide / start.height,
      (minHandleSize ?? 32) / start.width,
      (minHandleSize ?? 32) / start.height,
    ].reduce((a, b) => a > b ? a : b);
    final maxScale = [
      sourceWidth / start.width,
      sourceHeight / start.height,
    ].reduce((a, b) => a < b ? a : b);
    final k = maxScale < minScale ? 1.0 : scale.clamp(minScale, maxScale);
    final next = centeredOn(
      (start.width * k).round(),
      (start.height * k).round(),
      around: crop,
    );
    if (_same(next, crop)) return null;
    return next;
  }

  static bool _same(CropRect? a, CropRect b) =>
      a != null &&
      a.x == b.x &&
      a.y == b.y &&
      a.width == b.width &&
      a.height == b.height;
}
