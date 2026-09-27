#!/usr/bin/env python3
"""Gera as cópias dos selos (Flutter, Dart, Android, FFmpeg, Licença) que o
app mostra no topo da tela inicial.

A arte original fica em ``assets/badge/`` (pasta de trabalho, que muda com
frequência) e usa CSS com ``@media (prefers-color-scheme: dark)`` para se
adaptar ao tema. O ``flutter_svg`` não entende ``<style>`` nem classes, então
este script escreve duas cópias com as cores já aplicadas em cada elemento —
uma para o tema claro e outra para o escuro — na pasta estável do app,
``recursos/marca/``. A tela inicial escolhe a cópia pelo tema atual.

Rode a partir da raiz do projeto sempre que atualizar a arte:

    python3 tool/gerar_selos_do_app.py [caminho/do/selo.svg]
"""

from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
FONTE_PADRAO = RAIZ / 'assets/badge/gitbat-badges-adaptive-v10.svg'
DESTINO = RAIZ / 'recursos/marca'
SVG_NS = 'http://www.w3.org/2000/svg'

ET.register_namespace('', SVG_NS)


def regras(css: str) -> dict[str, dict[str, str]]:
    """`.classe { prop: valor; }` → {classe: {prop: valor}}."""
    saida: dict[str, dict[str, str]] = {}
    for seletor, corpo in re.findall(r'\.([\w-]+)\s*\{([^}]*)\}', css):
        props = saida.setdefault(seletor, {})
        for decl in corpo.split(';'):
            if ':' in decl:
                nome, valor = decl.split(':', 1)
                props[nome.strip()] = valor.strip()
    return saida


def expandir_font(props: dict[str, str]) -> dict[str, str]:
    """`font: 700 20px Inter,Arial` → font-weight/font-size/font-family."""
    font = props.pop('font', None)
    if font:
        m = re.match(r'(\d+)\s+([\d.]+px)\s+(.+)', font)
        if m:
            props['font-weight'], props['font-size'], props['font-family'] = (
                m.group(1),
                m.group(2),
                m.group(3),
            )
    return props


def gerar(fonte: Path, escuro: bool) -> str:
    arvore = ET.parse(fonte)
    raiz = arvore.getroot()
    estilo = raiz.find(f'{{{SVG_NS}}}style')
    css = estilo.text if estilo is not None else ''
    base_css, _, resto = css.partition('@media')
    tabela = regras(base_css)
    if escuro:
        escuro_css = resto[resto.index('{') + 1 : resto.rindex('}')]
        for classe, props in regras(escuro_css).items():
            tabela.setdefault(classe, {}).update(props)
    if estilo is not None:
        raiz.remove(estilo)
    for elemento in raiz.iter():
        classes = elemento.attrib.pop('class', '').split()
        for classe in classes:
            for nome, valor in expandir_font(dict(tabela.get(classe, {}))).items():
                # Atributo já escrito no elemento (ex.: stroke-width) vence a
                # classe, como no CSS original.
                elemento.attrib.setdefault(nome, valor)
    return ET.tostring(raiz, encoding='unicode')


def main() -> None:
    fonte = Path(sys.argv[1]) if len(sys.argv) > 1 else FONTE_PADRAO
    DESTINO.mkdir(parents=True, exist_ok=True)
    for tema, escuro in (('claro', False), ('escuro', True)):
        saida = DESTINO / f'gitbat-selos-{tema}.svg'
        saida.write_text(gerar(fonte, escuro) + '\n', encoding='utf-8')
        print(saida.relative_to(RAIZ))


if __name__ == '__main__':
    main()
