#!/usr/bin/env python3
"""Gera o ícone do app e as imagens da ficha da Play Store.

Rode a partir da raiz do projeto:

    pip install Pillow
    python3 tool/gerar_icones.py

Produz:
  android/app/src/main/res/mipmap-*/ic_launcher.png   ícone legado
  android/app/src/main/res/mipmap-*/ic_launcher_foreground.png
  android/app/src/main/res/drawable-nodpi/splash_icon.png
  loja/icone_512.png                                  ícone da ficha da loja
  loja/grafico_destaque_1024x500.png                  gráfico de destaque

O ícone é o morceguinho de ``assets/icon/icon-v2/morceguinho-icone-simples.png``
(identidade visual v2). O ícone anterior, com tudo o que era gerado a partir
dele, está guardado em ``assets/icon/icon-v1/``.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
ICONE_FONTE = RAIZ / 'assets/icon/icon-v2/morceguinho-icone-simples.png'

# Cores da identidade do morceguinho (as mesmas da paleta oficial em
# lib/app/palettes/bat_palette.dart).
AZUL_NOITE = (17, 25, 41)  # fundo do ícone, #111929
AZUL_MARINHO = (12, 72, 168)  # contorno do mascote, #0C48A8
AZUL_GELO = (176, 221, 252)  # corpo do mascote, #B0DCFC
CIANO = (34, 216, 238)  # fone de ouvido, #22D8EE
BRANCO = (255, 255, 255)

DENSIDADES = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
}


def gradiente(largura, altura, inicio, fim):
    """Gradiente diagonal, do canto superior esquerdo ao inferior direito."""
    base = Image.new('RGB', (largura, altura))
    pixels = base.load()
    for y in range(altura):
        for x in range(largura):
            t = (x / max(largura - 1, 1) + y / max(altura - 1, 1)) / 2
            pixels[x, y] = tuple(
                round(inicio[c] + (fim[c] - inicio[c]) * t) for c in range(3)
            )
    return base


def icone_completo(tamanho):
    """Ícone quadrado com fundo, para o launcher legado e para a loja."""
    with Image.open(ICONE_FONTE) as fonte:
        return fonte.convert('RGBA').resize((tamanho, tamanho), Image.LANCZOS)


def morcego_sem_fundo(tamanho):
    """Só o morceguinho, com o azul-noite do fundo trocado por transparência.

    Os pixels perto de [AZUL_NOITE] (o fundo e os contornos do fone) somem aos
    poucos, sem serrilhado. Sobre o fundo azul-noite do ícone adaptativo o
    resultado fica idêntico ao original, e a versão monocromática (ícones
    temáticos do Android 13+) ganha a silhueta do morcego em vez de um
    quadrado cheio.
    """
    with Image.open(ICONE_FONTE) as fonte:
        icone = fonte.convert('RGBA').resize((tamanho, tamanho), Image.LANCZOS)
    pixels = icone.load()
    for y in range(tamanho):
        for x in range(tamanho):
            r, g, b, a = pixels[x, y]
            distancia = max(
                abs(r - AZUL_NOITE[0]),
                abs(g - AZUL_NOITE[1]),
                abs(b - AZUL_NOITE[2]),
            )
            opacidade = min(max((distancia - 12) / 48, 0), 1)
            pixels[x, y] = (r, g, b, round(a * opacidade))
    return icone


def icone_adaptativo_frente(tamanho):
    """Camada da frente do ícone adaptativo (fundo transparente).

    O Android pode recortar o ícone em círculo, quadrado ou gota. Só os 66%
    centrais são garantidos, então a marca fica menor aqui do que no ícone
    legado. O fundo vem da cor `ic_launcher_background` (o mesmo azul-noite).
    """
    camada = Image.new('RGBA', (tamanho, tamanho), (0, 0, 0, 0))
    # O centro de 66% é a área segura do ícone adaptativo: as pontas das asas
    # ficam dentro dela com o ícone em 2/3 do tamanho.
    lado = round(tamanho * 2 / 3)
    margem = (tamanho - lado) // 2
    camada.alpha_composite(morcego_sem_fundo(lado), (margem, margem))
    return camada


def icone_abertura():
    """Ícone da splash do Android 12+ (960 px, logo na metade central).

    O sistema recorta o ícone da abertura num círculo de 2/3 do tamanho; com
    a logo na metade central, o quadrado arredondado cabe inteiro nele.
    """
    tamanho = 960
    camada = Image.new('RGBA', (tamanho, tamanho), (0, 0, 0, 0))
    lado = tamanho // 2
    camada.alpha_composite(icone_completo(lado), ((tamanho - lado) // 2,) * 2)
    return camada


def fonte(tamanho, negrito=True):
    nome = 'DejaVuSans-Bold.ttf' if negrito else 'DejaVuSans.ttf'
    return ImageFont.truetype(f'/usr/share/fonts/truetype/dejavu/{nome}', tamanho)


def grafico_destaque():
    """Banner 1024x500 exigido pela ficha da Play Store."""
    largura, altura = 1024, 500
    imagem = gradiente(largura, altura, AZUL_NOITE, AZUL_MARINHO).convert('RGBA')

    imagem.alpha_composite(icone_completo(300), (70, 100))

    desenho = ImageDraw.Draw(imagem)
    desenho.text((410, 165), 'GitBat', font=fonte(64), fill=BRANCO)
    desenho.text(
        (412, 250),
        'Saiba o peso antes de converter',
        font=fonte(30, negrito=False),
        fill=AZUL_GELO,
    )
    desenho.text(
        (412, 296),
        'Corte · proporção · velocidade · FPS',
        font=fonte(26, negrito=False),
        fill=CIANO,
    )

    return imagem.convert('RGB')


def main():
    (RAIZ / 'assets').mkdir(exist_ok=True)
    (RAIZ / 'loja').mkdir(exist_ok=True)
    res = RAIZ / 'android/app/src/main/res'

    icone_completo(512).convert('RGB').save(RAIZ / 'loja/icone_512.png')
    print('loja/icone_512.png')

    for densidade, px in DENSIDADES.items():
        pasta = res / f'mipmap-{densidade}'
        pasta.mkdir(parents=True, exist_ok=True)
        icone_completo(px).save(pasta / 'ic_launcher.png')
        # A camada adaptativa é desenhada num canvas 2,25x maior que o ícone
        # final, conforme a especificação de ícones adaptativos do Android.
        icone_adaptativo_frente(round(px * 2.25)).save(
            pasta / 'ic_launcher_foreground.png'
        )
        print(f'mipmap-{densidade}/  ({px}px)')

    icone_abertura().save(res / 'drawable-nodpi/splash_icon.png')
    print('drawable-nodpi/splash_icon.png')

    grafico_destaque().save(RAIZ / 'loja/grafico_destaque_1024x500.png')
    print('loja/grafico_destaque_1024x500.png')


if __name__ == '__main__':
    main()
