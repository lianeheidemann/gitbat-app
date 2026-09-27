import '../../../app/language_controller.dart';
import 'dart:convert' show base64Encode;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:xml/xml.dart';

import '../../../core/models/collage_sticker.dart';
import '../../../core/models/collage_text.dart';
import '../../../core/models/color_adjustments.dart';
import '../../../core/models/crop_rect.dart';
import '../../../core/models/frame_settings.dart';
import '../../../core/models/photo_placement.dart';
import '../models/svg_edit_settings.dart';
import '../models/svg_info.dart';

/// Erro amigável para qualquer passo de leitura/reescrita do SVG que não dá
/// pra completar — arquivo malformado, sem `viewBox`/tamanho válido, ou que o
/// `package:xml` rejeita mesmo tendo passado pelo `flutter_svg` na hora de
/// escolher o arquivo (são dois parsers independentes).
class SvgEditException implements Exception {
  const SvgEditException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Geometria resolvida da raiz `<svg>`: o `viewBox` (sempre presente depois
/// de [readSvgGeometry], sintetizado se faltava) e o tamanho de exibição
/// (`attrWidth`/`attrHeight`, vindos de [SvgInfo] — já resolvidos pelo
/// `flutter_svg`, nunca reparseados de `width`/`height`/`%` na mão aqui).
///
/// [scaleX]/[scaleY] convertem do espaço de exibição (o que `CropOverlay`/
/// `CroppedView` usam, igual a [SvgInfo.width]/[height]) para o espaço nativo
/// do `viewBox` — os dois só coincidem 1:1 quando `width`/`height` batem
/// exatamente com o `viewBox`, o que não é garantido (SVGs de ícone comuns
/// têm `viewBox="0 0 24 24"` com `width="512"`, por exemplo).
class SvgGeometry {
  const SvgGeometry({
    required this.viewBoxX,
    required this.viewBoxY,
    required this.viewBoxWidth,
    required this.viewBoxHeight,
    required this.attrWidth,
    required this.attrHeight,
  });

  final double viewBoxX;
  final double viewBoxY;
  final double viewBoxWidth;
  final double attrHeight;
  final double attrWidth;
  final double viewBoxHeight;

  double get scaleX => attrWidth == 0 ? 1 : viewBoxWidth / attrWidth;
  double get scaleY => attrHeight == 0 ? 1 : viewBoxHeight / attrHeight;
}

/// Atributo marcador usado nos elementos que este editor cria (`<g>` de
/// conteúdo, `<defs>` de filtro, `<rect>` de fundo) — para reconhecer e
/// reaproveitar/substituir o que ele mesmo já criou dentro de uma única
/// passada de [renderEditedSvg], em vez de duplicar a cada chamada.
const _marker = 'data-svgedit';

/// Lê (e normaliza) a geometria da raiz `<svg>` de [root]: se não houver
/// `viewBox`, sintetiza um a partir de [info] (ou 300x150, o padrão da
/// especificação, se nem isso existir) e já escreve esse `viewBox` de volta
/// — todo o resto deste arquivo assume que `viewBox` está presente e válido
/// depois desta chamada.
SvgGeometry readSvgGeometry(XmlElement root, SvgInfo info) {
  final attrWidth = info.width;
  final attrHeight = info.height;
  if (attrWidth <= 0 ||
      attrHeight <= 0 ||
      !attrWidth.isFinite ||
      !attrHeight.isFinite) {
    throw SvgEditException(
      tr('Este SVG não tem um tamanho válido.', 'This SVG has no valid size.'),
    );
  }

  var vbX = 0.0, vbY = 0.0, vbW = attrWidth, vbH = attrHeight;
  final viewBoxAttr = root.getAttribute('viewBox');
  if (viewBoxAttr != null) {
    final parts = viewBoxAttr
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map(double.tryParse)
        .toList();
    if (parts.length == 4 && parts.every((p) => p != null)) {
      vbX = parts[0]!;
      vbY = parts[1]!;
      vbW = parts[2]!;
      vbH = parts[3]!;
    }
  }
  if (vbW <= 0 || vbH <= 0) {
    vbX = 0;
    vbY = 0;
    vbW = attrWidth;
    vbH = attrHeight;
  }

  root.setAttribute(
    'viewBox',
    '${_num(vbX)} ${_num(vbY)} ${_num(vbW)} ${_num(vbH)}',
  );
  return SvgGeometry(
    viewBoxX: vbX,
    viewBoxY: vbY,
    viewBoxWidth: vbW,
    viewBoxHeight: vbH,
    attrWidth: attrWidth,
    attrHeight: attrHeight,
  );
}

/// Garante que todo filho visual de [root] (tudo exceto `<defs>`/`<title>`/
/// `<desc>`/`<metadata>`/`<style>`, que não são desenhados diretamente) está
/// dentro de um único `<g>` marcado, criando-o na primeira chamada e
/// reaproveitando nas seguintes (idempotente dentro de uma mesma passada de
/// [renderEditedSvg] — rotacionar, espelhar, aplicar filtro e opacidade
/// escrevem todos nesse mesmo grupo). Se a raiz já tiver um `transform`
/// próprio (incomum, mas válido), ele é movido para dentro do grupo em vez
/// de descartado.
XmlElement ensureContentGroup(XmlElement root) {
  for (final child in root.childElements) {
    if (child.name.local == 'g' && child.getAttribute(_marker) == '1') {
      return child;
    }
  }

  const excluded = {'defs', 'title', 'desc', 'metadata', 'style'};
  final moved = <XmlNode>[];
  root.children.removeWhere((node) {
    if (node is XmlElement && !excluded.contains(node.name.local)) {
      moved.add(node);
      return true;
    }
    return false;
  });

  final group = XmlElement.tag('g');
  group.setAttribute(_marker, '1');
  final rootTransform = root.getAttribute('transform');
  if (rootTransform != null && rootTransform.trim().isNotEmpty) {
    group.setAttribute('transform', rootTransform);
    root.removeAttribute('transform');
  }
  group.children.addAll(moved);
  root.children.add(group);
  return group;
}

/// Reescreve o `viewBox` de [root] para a sub-região [cropDisplayRect] (em
/// espaço de exibição, o mesmo que `CropOverlay` usa), convertida pra espaço
/// nativo via [geometry]. Quando `width`/`height` já existiam como
/// atributos, também são ajustados para o tamanho do recorte (na mesma
/// unidade de exibição) — sem isso, a proporção declarada por `width`/
/// `height` ficaria descasada da proporção do novo `viewBox`, e o SVG
/// abriria com barras vazias (`preserveAspectRatio` padrão) em vez de
/// mostrar só a janela recortada. O conteúdo em si nunca é esticado — só a
/// janela visível encolhe/cresce (ver decisão em `svg_edit_settings.dart`).
void cropSvg(XmlElement root, SvgGeometry geometry, CropRect cropDisplayRect) {
  final newX = geometry.viewBoxX + cropDisplayRect.x * geometry.scaleX;
  final newY = geometry.viewBoxY + cropDisplayRect.y * geometry.scaleY;
  final newW = cropDisplayRect.width * geometry.scaleX;
  final newH = cropDisplayRect.height * geometry.scaleY;
  root.setAttribute(
    'viewBox',
    '${_num(newX)} ${_num(newY)} ${_num(newW)} ${_num(newH)}',
  );
  if (root.getAttribute('width') != null &&
      root.getAttribute('height') != null) {
    root.setAttribute('width', _num(cropDisplayRect.width.toDouble()));
    root.setAttribute('height', _num(cropDisplayRect.height.toDouble()));
  }
}

/// Envolve o grupo de conteúdo num `rotate(graus, cx, cy)` em torno do
/// centro do `viewBox` *atual* de [root] (ou seja, já considerando um
/// recorte aplicado antes, se houver — cada passo lê a geometria corrente em
/// vez de uma copiada do início). Para 90°/270°, troca `width`/`height` (se
/// existirem como atributos literais) e os termos w/h do `viewBox`,
/// recentralizando no mesmo ponto.
void rotateSvg(XmlElement root, int quarterTurns) {
  final turns = quarterTurns % 4;
  if (turns == 0) return;

  final group = ensureContentGroup(root);
  final (vbX, vbY, vbW, vbH) = _currentViewBox(root);
  final cx = vbX + vbW / 2;
  final cy = vbY + vbH / 2;
  _composeTransform(group, 'rotate(${turns * 90} ${_num(cx)} ${_num(cy)})');

  if (turns == 1 || turns == 3) {
    final width = root.getAttribute('width');
    final height = root.getAttribute('height');
    if (width != null && height != null) {
      root.setAttribute('width', height);
      root.setAttribute('height', width);
    }
    final newVbW = vbH, newVbH = vbW;
    root.setAttribute(
      'viewBox',
      '${_num(cx - newVbW / 2)} ${_num(cy - newVbH / 2)} ${_num(newVbW)} ${_num(newVbH)}',
    );
  }
}

/// Envolve o grupo de conteúdo num espelhamento em torno do centro do
/// `viewBox` atual — mesma ideia de [rotateSvg], composto no mesmo
/// `transform` do grupo (a ordem de composição garante que espelhar depois
/// de girar espelha o resultado já girado, não o original).
void flipSvg(
  XmlElement root, {
  required bool horizontal,
  required bool vertical,
}) {
  if (!horizontal && !vertical) return;
  final group = ensureContentGroup(root);
  final (vbX, vbY, vbW, vbH) = _currentViewBox(root);
  final cx = vbX + vbW / 2;
  final cy = vbY + vbH / 2;
  final sx = horizontal ? -1 : 1;
  final sy = vertical ? -1 : 1;
  final tx = horizontal ? _num(2 * cx) : '0';
  final ty = vertical ? _num(2 * cy) : '0';
  _composeTransform(group, 'translate($tx,$ty) scale($sx,$sy)');
}

/// Insere (ou remove, com `color: null`) um `<rect>` cobrindo o `viewBox`
/// atual como primeiro filho de [root] — mesma semântica de
/// `FrameSettings.transparentBackground`: ligado (`color: null`), a área
/// fora da arte sai transparente; desligado, usa [color].
void applyBackgroundSvg(XmlElement root, Color? color) {
  root.children.removeWhere(
    (node) => node is XmlElement && node.getAttribute('$_marker-bg') == '1',
  );
  if (color == null) return;

  final (vbX, vbY, vbW, vbH) = _currentViewBox(root);
  final rect = XmlElement.tag('rect')
    ..setAttribute('x', _num(vbX))
    ..setAttribute('y', _num(vbY))
    ..setAttribute('width', _num(vbW))
    ..setAttribute('height', _num(vbH))
    ..setAttribute('fill', _colorToHex(color))
    ..setAttribute('$_marker-bg', '1');
  if (color.a < 1) {
    rect.setAttribute('fill-opacity', _num(color.a));
  }
  root.children.insert(0, rect);
}

/// Injeta (ou remove, quando não há nada ativo) um `<filter>` em `<defs>` e
/// referencia via `filter="url(#...)"` no grupo de conteúdo — combinando o
/// preset [type] com o ajuste fino [adjustments] (brilho/exposição/
/// contraste/realces/sombras/saturação/matiz/temperatura — a aba "Cor"), que
/// podem estar ativos ao mesmo tempo. Preto e branco usa `type="saturate"`
/// (o mesmo peso de luminância Rec. 709 de `color_adjustments.dart`, só que
/// nativo do SVG); inverter usa a matriz clássica de inversão, sem
/// equivalente primitivo; o ajuste fino usa a mesma matriz 4x5 de
/// `ColorAdjustments.matrix4x5`, convertida para a escala 0-1 do SVG (ver
/// [_svgColorMatrixValues]) — nenhuma fórmula é duplicada, as duas telas
/// (prévia em `SvgEditPage`, exportação aqui) usam a mesma conta.
///
/// Quando os dois estão ativos, o ajuste fino entra primeiro (mesma ordem
/// de composição da prévia em `SvgEditPage._croppedDecoratedPreview`),
/// encadeado via `in`/`result` para o preset atuar sobre o resultado já
/// ajustado, não sobre a arte original.
void applyFilterSvg(
  XmlElement root,
  SvgFilterType type, {
  ColorAdjustments adjustments = ColorAdjustments.neutral,
}) {
  final group = ensureContentGroup(root);
  group.removeAttribute('filter');
  root.children.removeWhere(
    (node) => node is XmlElement && node.getAttribute('$_marker-defs') == '1',
  );

  final matrices = <XmlElement>[];
  if (adjustments.hasAdjustments) {
    matrices.add(
      XmlElement.tag('feColorMatrix')
        ..setAttribute('type', 'matrix')
        ..setAttribute('values', _svgColorMatrixValues(adjustments.matrix4x5)),
    );
  }
  switch (type) {
    case SvgFilterType.grayscale:
      matrices.add(
        XmlElement.tag('feColorMatrix')
          ..setAttribute('type', 'saturate')
          ..setAttribute('values', '0'),
      );
    case SvgFilterType.invert:
      matrices.add(
        XmlElement.tag('feColorMatrix')
          ..setAttribute('type', 'matrix')
          ..setAttribute(
            'values',
            '-1 0 0 0 1  0 -1 0 0 1  0 0 -1 0 1  0 0 0 1 0',
          ),
      );
    case SvgFilterType.none:
      break;
  }
  if (matrices.isEmpty) return;

  for (var i = 1; i < matrices.length; i++) {
    matrices[i - 1].setAttribute('result', 'svgedit-step$i');
    matrices[i].setAttribute('in', 'svgedit-step$i');
  }

  final filter = XmlElement.tag('filter')..setAttribute('id', 'svgedit-filter');
  filter.children.addAll(matrices);
  final defs = XmlElement.tag('defs')
    ..setAttribute('$_marker-defs', '1')
    ..children.add(filter);
  root.children.insert(0, defs);
  group.setAttribute('filter', 'url(#svgedit-filter)');
}

/// Converte a matriz 4x5 de [ColorAdjustments.matrix4x5] (deslocamentos na
/// escala 0-255, convenção do `ColorFilter.matrix` do Flutter) para o
/// formato nativo de `<feColorMatrix type="matrix">` do SVG (mesma matriz,
/// só os 3 deslocamentos de cor — não o de alfa — na escala 0-1).
String _svgColorMatrixValues(List<double> matrix4x5) {
  final values = List<double>.from(matrix4x5);
  for (final i in [4, 9, 14]) {
    values[i] = values[i] / 255;
  }
  return values.map(_num).join(' ');
}

/// Define (ou remove, com `opacity: 1`) `opacity` no grupo de conteúdo.
void applyOpacitySvg(XmlElement root, double opacity) {
  final group = ensureContentGroup(root);
  final clamped = opacity.clamp(0.0, 1.0);
  if (clamped >= 1) {
    group.removeAttribute('opacity');
  } else {
    group.setAttribute('opacity', _num(clamped));
  }
}

/// Acrescenta os textos da aba "Texto" como `<text>` de verdade no fim de
/// [root] — por cima da arte e do fundo, e fora do grupo de conteúdo, então
/// o filtro e a opacidade não valem para eles (como na prévia). Cada texto
/// vira um `<g>` marcado com `translate` + `rotate` em volta do próprio
/// centro, com o fundo (`<rect>` arredondado) quando houver.
///
/// As medidas saem do `viewBox` atual (já recortado e girado): o centro é
/// normalizado a ele e o tamanho da fonte é uma fração do menor lado, a
/// mesma conta de `paintCollageTextItem`. A largura do fundo e a posição da
/// linha de base de cada linha vêm de um [TextPainter] com a mesma fonte, o
/// mesmo que a prévia usa. A fonte em si não é embutida: quem abrir o SVG
/// usa a mesma família se a tiver instalada, senão uma sem serifa.
void applyTextsSvg(XmlElement root, List<CollageTextItem> texts) {
  root.children.removeWhere(
    (node) => node is XmlElement && node.getAttribute('$_marker-text') == '1',
  );
  if (texts.isEmpty) return;

  final (vbX, vbY, vbW, vbH) = _currentViewBox(root);
  final sorted = [...texts]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
  for (final item in sorted) {
    if (item.text.trim().isEmpty) continue;
    final fontSize = math.min(vbW, vbH) * item.fontSizeRatio * item.scale;
    final painter = TextPainter(
      text: TextSpan(
        text: item.text,
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: item.fontFamily,
          fontWeight: item.bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final cx = vbX + item.centerX * vbW;
    final cy = vbY + item.centerY * vbH;
    final degrees = item.rotation * 180 / math.pi;
    final group = XmlElement.tag('g')
      ..setAttribute('$_marker-text', '1')
      ..setAttribute(
        'transform',
        'translate(${_num(cx)} ${_num(cy)})'
            '${degrees == 0 ? '' : ' rotate(${_num(degrees)})'}',
      );

    final background = item.backgroundColor;
    if (background != null) {
      final (padH, padV) = CollageTextItem.backgroundPaddingFor(fontSize);
      final w = painter.width + padH * 2;
      final h = painter.height + padV * 2;
      final radius =
          math.min(w, h) *
          item.backgroundCornerRatio.clamp(
            0.0,
            CollageTextItem.maxBackgroundCornerRatio,
          );
      final rect = XmlElement.tag('rect')
        ..setAttribute('x', _num(-w / 2))
        ..setAttribute('y', _num(-h / 2))
        ..setAttribute('width', _num(w))
        ..setAttribute('height', _num(h))
        ..setAttribute('rx', _num(radius))
        ..setAttribute('fill', _colorToHex(background));
      if (background.a < 1) {
        rect.setAttribute('fill-opacity', _num(background.a));
      }
      group.children.add(rect);
    }

    final text = XmlElement.tag('text')
      ..setAttribute('text-anchor', 'middle')
      ..setAttribute('font-size', _num(fontSize))
      ..setAttribute('font-weight', item.bold ? '700' : '400')
      ..setAttribute(
        'font-family',
        item.fontFamily == null
            ? 'sans-serif'
            : "'${item.fontFamily}', sans-serif",
      )
      ..setAttribute('fill', _colorToHex(item.color));
    if (item.color.a < 1) {
      text.setAttribute('fill-opacity', _num(item.color.a));
    }
    // Uma `<tspan>` por linha, cada uma na linha de base que o TextPainter
    // calculou — o SVG não quebra linha sozinho.
    final lines = item.text.split('\n');
    final metrics = painter.computeLineMetrics();
    for (var i = 0; i < lines.length; i++) {
      final baseline = i < metrics.length
          ? metrics[i].baseline
          : painter.height * (i + 1) / lines.length;
      text.children.add(
        XmlElement.tag('tspan')
          ..setAttribute('x', '0')
          ..setAttribute('y', _num(baseline - painter.height / 2))
          ..children.add(XmlText(lines[i])),
      );
    }
    group.children.add(text);
    painter.dispose();
    root.children.add(group);
  }
}

/// Posição livre do desenho (arrastar/pinçar/girar na prévia): o conteúdo
/// (tudo menos `<defs>` e o fundo) vai para um `<g>` com o mesmo movimento
/// da prévia — desloca o centro por `dx`/`dy` (frações do `viewBox`), gira e
/// escala em volta dele. Sem mudança, nada acontece.
void applyPlacementSvg(XmlElement root, PhotoPlacement placement) {
  if (placement.isIdentity) return;
  final (x, y, w, h) = _currentViewBox(root);
  final cx = x + w / 2;
  final cy = y + h / 2;
  final degrees = placement.rotation * 180 / math.pi;
  final group = XmlElement.tag('g')
    ..setAttribute('$_marker-placement', '1')
    ..setAttribute(
      'transform',
      'translate(${_num(cx + placement.dx * w)} ${_num(cy + placement.dy * h)}) '
          'rotate(${_num(degrees)}) scale(${_num(placement.scale)}) '
          'translate(${_num(-cx)} ${_num(-cy)})',
    );
  final content = [
    for (final node in root.children)
      if (node is XmlElement &&
          node.name.local != 'defs' &&
          node.getAttribute('$_marker-bg') != '1')
        node,
  ];
  for (final node in content) {
    root.children.remove(node);
    group.children.add(node);
  }
  root.children.add(group);
}

/// Borda da aba "Borda" em volta do resultado, vetorial: o conteúdo (tudo
/// menos `<defs>` e o fundo) vai para um `<g>` recortado no retângulo
/// arredondado de dentro, e o anel entra por cima como um `<path>` com
/// `fill-rule="evenodd"` (retângulo de fora menos o de dentro). Mesma
/// geometria de `FrameGeometry`/`paintFrame` na foto: espessura
/// proporcional à largura do `viewBox`, cantos ao menor lado dele. Sem
/// borda, nada muda.
void applyBorderSvg(XmlElement root, FrameSettings border) {
  if (border.style == FrameStyle.none) return;
  final (x, y, w, h) = _currentViewBox(root);
  final t = border.thicknessFor(w).clamp(0.0, math.min(w, h) / 2);
  final outerR = border.cornerRadiusFor(math.min(w, h));
  final innerR = (outerR - t).clamp(0.0, outerR);
  const clipId = 'svgedit-border-clip';

  final content = [
    for (final node in root.children)
      if (node is XmlElement &&
          node.name.local != 'defs' &&
          node.getAttribute('$_marker-bg') != '1')
        node,
  ];
  final group = XmlElement.tag('g')
    ..setAttribute('$_marker-border', '1')
    ..setAttribute('clip-path', 'url(#$clipId)');
  for (final node in content) {
    root.children.remove(node);
    group.children.add(node);
  }

  final clip = XmlElement.tag('clipPath')
    ..setAttribute('id', clipId)
    ..children.add(
      XmlElement.tag('path')..setAttribute(
        'd',
        _roundedRectPath(x + t, y + t, w - 2 * t, h - 2 * t, innerR),
      ),
    );
  final defs = XmlElement.tag('defs')
    ..setAttribute('$_marker-border', '1')
    ..children.add(clip);

  final ring = XmlElement.tag('path')
    ..setAttribute('$_marker-border', '1')
    ..setAttribute('fill-rule', 'evenodd')
    ..setAttribute('fill', _colorToHex(border.color))
    ..setAttribute(
      'd',
      '${_roundedRectPath(x, y, w, h, outerR)} '
          '${_roundedRectPath(x + t, y + t, w - 2 * t, h - 2 * t, innerR)}',
    );
  if (border.color.a < 1) {
    ring.setAttribute('fill-opacity', _num(border.color.a));
  }

  root.children
    ..add(defs)
    ..add(group)
    ..add(ring);
}

/// Caminho SVG de um retângulo de cantos arredondados (raio [r]).
String _roundedRectPath(double x, double y, double w, double h, double r) {
  final rr = r.clamp(0.0, math.min(w, h) / 2);
  if (rr <= 0) {
    return 'M${_num(x)} ${_num(y)}H${_num(x + w)}V${_num(y + h)}'
        'H${_num(x)}Z';
  }
  final a = '${_num(rr)} ${_num(rr)} 0 0 1';
  return 'M${_num(x + rr)} ${_num(y)}'
      'H${_num(x + w - rr)}A$a ${_num(x + w)} ${_num(y + rr)}'
      'V${_num(y + h - rr)}A$a ${_num(x + w - rr)} ${_num(y + h)}'
      'H${_num(x + rr)}A$a ${_num(x)} ${_num(y + h - rr)}'
      'V${_num(y + rr)}A$a ${_num(x + rr)} ${_num(y)}Z';
}

/// Arte de um sticker já lida para entrar no SVG exportado: o texto de um
/// sticker vetorial (que entra como `<svg>` aninhado, continua vetor) ou os
/// bytes de um importado em PNG/JPG/etc. (que entra como `<image>`).
class StickerSvgArt {
  const StickerSvgArt.vector(String this.svgSource)
    : rasterBytes = null,
      mimeType = null;
  const StickerSvgArt.raster(Uint8List this.rasterBytes, String this.mimeType)
    : svgSource = null;

  final String? svgSource;
  final Uint8List? rasterBytes;
  final String? mimeType;
}

/// Acrescenta os stickers da aba "Stickers" no fim de [root], antes dos
/// textos ([applyTextsSvg] vem depois) e fora do grupo de conteúdo — como
/// na prévia, o filtro e a opacidade não valem para eles. Cada um vira um
/// `<g>` com `translate` + `rotate` em volta do centro e a arte num quadrado
/// de lado `menor lado × 0,28 × escala` (a mesma conta de
/// `paintCollageSticker`), centralizada nele sem distorcer. Sticker sem arte
/// em [art] (arquivo sumiu) fica de fora.
void applyStickersSvg(
  XmlElement root,
  List<CollageSticker> stickers,
  Map<String, StickerSvgArt> art,
) {
  root.children.removeWhere(
    (node) =>
        node is XmlElement && node.getAttribute('$_marker-sticker') == '1',
  );
  if (stickers.isEmpty) return;

  final (vbX, vbY, vbW, vbH) = _currentViewBox(root);
  final sorted = [...stickers]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
  var n = 0;
  for (final item in sorted) {
    final a = art[item.id];
    if (a == null) continue;
    final side =
        math.min(vbW, vbH) * CollageSticker.referenceSizeRatio * item.scale;
    final cx = vbX + item.centerX * vbW;
    final cy = vbY + item.centerY * vbH;
    final degrees = item.rotation * 180 / math.pi;
    final group = XmlElement.tag('g')
      ..setAttribute('$_marker-sticker', '1')
      ..setAttribute(
        'transform',
        'translate(${_num(cx)} ${_num(cy)})'
            '${degrees == 0 ? '' : ' rotate(${_num(degrees)})'}',
      );

    final XmlElement content;
    if (a.svgSource != null) {
      final nested = _nestedStickerSvg(a.svgSource!, 'stk${n++}_');
      if (nested == null) continue;
      content = nested;
    } else {
      content = XmlElement.tag('image')
        ..setAttribute(
          'href',
          'data:${a.mimeType};base64,${base64Encode(a.rasterBytes!)}',
        );
    }
    content
      ..setAttribute('x', _num(-side / 2))
      ..setAttribute('y', _num(-side / 2))
      ..setAttribute('width', _num(side))
      ..setAttribute('height', _num(side))
      ..setAttribute('preserveAspectRatio', 'xMidYMid meet');
    group.children.add(content);
    root.children.add(group);
  }
}

/// O `<svg>` raiz de [source] pronto para entrar aninhado: com `viewBox`
/// (criado de `width`/`height` quando faltar) e com os `id`s prefixados por
/// [prefix], para não colidirem com os do SVG principal nem de outro
/// sticker. `null` se não der para ler.
XmlElement? _nestedStickerSvg(String source, String prefix) {
  try {
    final prefixed = source
        .replaceAllMapped(
          RegExp(r'''\bid\s*=\s*(["'])([^"']+)\1'''),
          (m) => 'id=${m[1]}$prefix${m[2]}${m[1]}',
        )
        .replaceAllMapped(
          RegExp(r'url\(\s*#([^)\s]+)\s*\)'),
          (m) => 'url(#$prefix${m[1]})',
        )
        .replaceAllMapped(
          RegExp(r'''(href\s*=\s*["'])#'''),
          (m) => '${m[1]}#$prefix',
        );
    final doc = XmlDocument.parse(prefixed);
    final svg = doc.rootElement.copy();
    if (svg.name.local != 'svg') return null;
    if (svg.getAttribute('viewBox') == null) {
      final w = double.tryParse(
        (svg.getAttribute('width') ?? '').replaceAll(RegExp(r'[^0-9.]'), ''),
      );
      final h = double.tryParse(
        (svg.getAttribute('height') ?? '').replaceAll(RegExp(r'[^0-9.]'), ''),
      );
      if (w == null || h == null || w <= 0 || h <= 0) return null;
      svg.setAttribute('viewBox', '0 0 ${_num(w)} ${_num(h)}');
    }
    svg.removeAttribute('width');
    svg.removeAttribute('height');
    return svg;
  } catch (_) {
    return null;
  }
}

/// Aplica [settings] inteiro sobre [originalSource] (sempre a partir do XML
/// original — nunca reedita um documento já editado numa chamada anterior,
/// pra desfazer/refazer nunca acumular grupos/transforms obsoletos) e
/// devolve o SVG resultante como texto. Ordem fixa: recorte → girar →
/// espelhar → fundo → filtro (ajuste fino + preset, nessa ordem — ver
/// [applyFilterSvg]) → opacidade → textos ([applyTextsSvg]).
String renderEditedSvg(
  String originalSource,
  SvgInfo info,
  SvgEditSettings settings, {
  Map<String, StickerSvgArt> stickerArt = const {},
}) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(originalSource);
  } on SvgEditException {
    rethrow;
  } catch (_) {
    throw SvgEditException(
      tr(
        'Não foi possível interpretar este SVG (arquivo malformado ou com codificação não suportada).',
        'Could not parse this SVG (malformed file or unsupported encoding).',
      ),
    );
  }

  try {
    final root = doc.rootElement;
    if (root.name.local != 'svg') {
      throw SvgEditException(
        tr(
          'Este arquivo não é um SVG válido.',
          'This file is not a valid SVG.',
        ),
      );
    }

    final geometry = readSvgGeometry(root, info);
    final crop = settings.crop;
    if (crop != null) {
      cropSvg(root, geometry, crop);
    }
    rotateSvg(root, settings.rotationQuarterTurns);
    flipSvg(
      root,
      horizontal: settings.flipHorizontal,
      vertical: settings.flipVertical,
    );
    // Cada passo só mexe no documento quando tem algo a fazer — como este
    // método sempre reparte do XML original (nunca reedita um já editado),
    // um ajuste neutro (fundo transparente, sem filtro, opacidade 1) nunca
    // tem nada pra desfazer, e pular a chamada evita empacotar o conteúdo
    // num `<g>` à toa quando nada mudou.
    if (!settings.transparentBackground) {
      applyBackgroundSvg(root, settings.backgroundColor);
    }
    if (settings.filterType != SvgFilterType.none ||
        settings.adjustments.hasAdjustments) {
      applyFilterSvg(
        root,
        settings.filterType,
        adjustments: settings.adjustments,
      );
    }
    if (settings.opacity < 1) {
      applyOpacitySvg(root, settings.opacity);
    }
    applyPlacementSvg(root, settings.placement);
    applyBorderSvg(root, settings.border);
    applyStickersSvg(root, settings.stickers, stickerArt);
    applyTextsSvg(root, settings.texts);

    return doc.toXmlString();
  } on SvgEditException {
    rethrow;
  } catch (_) {
    throw SvgEditException(
      tr(
        'Não foi possível gerar o SVG editado.',
        'Could not create the edited SVG.',
      ),
    );
  }
}

(double, double, double, double) _currentViewBox(XmlElement root) {
  final raw = root.getAttribute('viewBox');
  if (raw == null) {
    throw SvgEditException(
      tr(
        'Este SVG não tem um viewBox válido.',
        'This SVG has no valid viewBox.',
      ),
    );
  }
  final parts = raw.trim().split(RegExp(r'[\s,]+')).map(double.parse).toList();
  if (parts.length != 4) {
    throw SvgEditException(
      tr(
        'Este SVG não tem um viewBox válido.',
        'This SVG has no valid viewBox.',
      ),
    );
  }
  return (parts[0], parts[1], parts[2], parts[3]);
}

/// Acrescenta [fragment] à ESQUERDA do `transform` já existente em [group]
/// (se houver) — na lista de transforms do SVG, o da esquerda é aplicado por
/// último, então prepender garante que cada novo passo do pipeline atua
/// sobre o resultado do passo anterior, não o contrário.
void _composeTransform(XmlElement group, String fragment) {
  final existing = group.getAttribute('transform');
  group.setAttribute(
    'transform',
    existing == null || existing.trim().isEmpty
        ? fragment
        : '$fragment $existing',
  );
}

String _colorToHex(Color color) {
  String two(int v) => v.toRadixString(16).padLeft(2, '0');
  return '#${two((color.r * 255).round())}${two((color.g * 255).round())}${two((color.b * 255).round())}';
}

/// Formata um número para atributo XML: inteiro sem `.0` quando exato, senão
/// até 4 casas decimais sem zeros à direita — evita tanto `12.0` feio quanto
/// arrastar erro de ponto flutuante (`12.000000000000002`) pro arquivo salvo.
String _num(double value) {
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return value.toInt().toString();
  }
  var text = value.toStringAsFixed(4);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
  }
  return text;
}
