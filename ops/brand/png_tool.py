"""Decodifica, recolore e reescreve PNG usando só a biblioteca padrão.

Existe porque esta máquina não tem PIL nem ImageMagick, e a arte da marca chegou
como PNG: o logo horizontal tem o texto em branco (serve em fundo escuro) e o
painel também o exibe em fundo claro, onde ele sumiria. Recolorir o branco é a
única transformação necessária — o resto é redimensionamento, que o `sips` do
macOS já faz.

    python3 ops/brand/png_tool.py recolor entrada.png saida.png 1B1B1B
"""

import struct
import sys
import zlib


def ler_png(caminho):
    """Devolve (largura, altura, pixels RGBA como bytearray)."""
    dados = open(caminho, 'rb').read()
    assert dados[:8] == b'\x89PNG\r\n\x1a\n', 'não é PNG'

    pos, idat, largura, altura, profundidade, cor = 8, b'', 0, 0, 0, 0
    while pos < len(dados):
        (tamanho,) = struct.unpack('>I', dados[pos:pos + 4])
        tipo = dados[pos + 4:pos + 8]
        corpo = dados[pos + 8:pos + 8 + tamanho]
        if tipo == b'IHDR':
            largura, altura, profundidade, cor = struct.unpack('>IIBB', corpo[:10])
        elif tipo == b'IDAT':
            idat += corpo
        elif tipo == b'IEND':
            break
        pos += 12 + tamanho

    # Só o caso que a arte da marca usa. Falhar aqui é melhor do que gravar
    # cores erradas em silêncio.
    assert profundidade == 8, f'profundidade {profundidade} não suportada'
    assert cor == 6, f'tipo de cor {cor} não suportado (esperado RGBA)'

    bruto = zlib.decompress(idat)
    canais = 4
    passo = largura * canais
    saida = bytearray()
    anterior = bytearray(passo)

    # Desfaz os filtros por linha do PNG. Cada linha diz como foi codificada.
    for y in range(altura):
        inicio = y * (passo + 1)
        filtro = bruto[inicio]
        linha = bytearray(bruto[inicio + 1:inicio + 1 + passo])
        for x in range(passo):
            esquerda = linha[x - canais] if x >= canais else 0
            acima = anterior[x]
            diagonal = anterior[x - canais] if x >= canais else 0
            if filtro == 1:
                linha[x] = (linha[x] + esquerda) & 0xFF
            elif filtro == 2:
                linha[x] = (linha[x] + acima) & 0xFF
            elif filtro == 3:
                linha[x] = (linha[x] + (esquerda + acima) // 2) & 0xFF
            elif filtro == 4:
                p = esquerda + acima - diagonal
                pa, pb, pc = abs(p - esquerda), abs(p - acima), abs(p - diagonal)
                perto = esquerda if (pa <= pb and pa <= pc) else (acima if pb <= pc else diagonal)
                linha[x] = (linha[x] + perto) & 0xFF
            elif filtro != 0:
                raise AssertionError(f'filtro {filtro} desconhecido')
        saida += linha
        anterior = linha

    return largura, altura, saida


def gravar_png(caminho, largura, altura, pixels):
    passo = largura * 4
    # Filtro 0 em todas as linhas: o arquivo fica um pouco maior e o código,
    # muito mais simples de conferir.
    bruto = b''.join(b'\x00' + bytes(pixels[y * passo:(y + 1) * passo]) for y in range(altura))

    def bloco(tipo, corpo):
        return (struct.pack('>I', len(corpo)) + tipo + corpo
                + struct.pack('>I', zlib.crc32(tipo + corpo) & 0xFFFFFFFF))

    with open(caminho, 'wb') as arquivo:
        arquivo.write(b'\x89PNG\r\n\x1a\n')
        arquivo.write(bloco(b'IHDR', struct.pack('>IIBBBBB', largura, altura, 8, 6, 0, 0, 0)))
        arquivo.write(bloco(b'IDAT', zlib.compress(bruto, 9)))
        arquivo.write(bloco(b'IEND', b''))


def recolorir_claros(pixels, destino, limiar=200):
    """Troca o que é quase branco pela cor destino, preservando a transparência.

    O verde da marca (aprox. 106,190,124) fica muito abaixo do limiar nos três
    canais, então não é tocado. A borda suavizada do texto vira um tom
    intermediário porque só a cor muda; o alfa é preservado, e é ele que faz o
    antisserrilhado continuar correto sobre qualquer fundo.
    """
    r, g, b = destino
    trocados = 0
    for i in range(0, len(pixels), 4):
        if pixels[i + 3] == 0:
            continue
        if pixels[i] >= limiar and pixels[i + 1] >= limiar and pixels[i + 2] >= limiar:
            pixels[i], pixels[i + 1], pixels[i + 2] = r, g, b
            trocados += 1
    return trocados


def recortar(largura, altura, pixels, x0, y0, w, h):
    saida = bytearray()
    for y in range(y0, y0 + h):
        inicio = (y * largura + x0) * 4
        saida += pixels[inicio:inicio + w * 4]
    return saida


def pintar(pixels, destino):
    """Pinta todo pixel visível de uma cor só, preservando o alfa.

    Serve para o ícone do balão do widget, que fica sobre a cor escolhida pelo
    cliente e por isso é sempre monocromático — o verde da marca sobre um balão
    verde desapareceria.
    """
    r, g, b = destino
    for i in range(0, len(pixels), 4):
        if pixels[i + 3]:
            pixels[i], pixels[i + 1], pixels[i + 2] = r, g, b


def cor_de(texto):
    return tuple(int(texto[i:i + 2], 16) for i in (0, 2, 4))


def marcar_nao_lido(largura, altura, pixels, cor=(239, 68, 68)):
    """Desenha o ponto de "mensagem nova" no canto, como o favicon antigo fazia.

    Proporções medidas no arquivo que já existia (96 px): centro em 0,797 do
    lado e raio de 1/6. Mantê-las é o que faz o ícone novo piscar igual ao
    antigo em vez de parecer outro produto quando chega mensagem.
    """
    cx = cy = 0.797 * largura
    raio = largura / 6.0
    r, g, b = cor

    for y in range(altura):
        for x in range(largura):
            # Quatro amostras por pixel: sem isso a borda do ponto fica
            # serrilhada, e em 16 px isso é metade do desenho.
            cobertura = sum(
                1
                for dx, dy in ((0.25, 0.25), (0.75, 0.25), (0.25, 0.75), (0.75, 0.75))
                if (x + dx - cx) ** 2 + (y + dy - cy) ** 2 <= raio * raio
            ) / 4.0
            if not cobertura:
                continue

            i = (y * largura + x) * 4
            fundo_a = pixels[i + 3] / 255.0
            # Composição sobre o que já está lá, respeitando a transparência do
            # canto arredondado do ícone.
            saida_a = cobertura + fundo_a * (1 - cobertura)
            for canal, valor in enumerate((r, g, b)):
                atual = pixels[i + canal] * fundo_a
                pixels[i + canal] = int(round((valor * cobertura + atual * (1 - cobertura)) / saida_a))
            pixels[i + 3] = int(round(saida_a * 255))


def main():
    comando = sys.argv[1]

    if comando == 'recolor':
        entrada, saida = sys.argv[2], sys.argv[3]
        cor = sys.argv[4] if len(sys.argv) > 4 else '1B1B1B'
        largura, altura, pixels = ler_png(entrada)
        trocados = recolorir_claros(pixels, cor_de(cor))
        gravar_png(saida, largura, altura, pixels)
        print(f'{entrada} -> {saida}: {largura}x{altura}, {trocados} pixels claros viraram #{cor}')

    elif comando == 'crop-solid':
        # recorte + cor chapada, que é o que o ícone do balão precisa
        entrada, saida = sys.argv[2], sys.argv[3]
        x0, y0, w, h = (int(v) for v in sys.argv[4:8])
        cor = sys.argv[8] if len(sys.argv) > 8 else 'FFFFFF'
        largura, altura, pixels = ler_png(entrada)
        recorte = recortar(largura, altura, pixels, x0, y0, w, h)
        pintar(recorte, cor_de(cor))
        gravar_png(saida, w, h, recorte)
        print(f'{entrada} -> {saida}: recorte {w}x{h} em #{cor}')

    elif comando == 'badge':
        entrada, saida = sys.argv[2], sys.argv[3]
        largura, altura, pixels = ler_png(entrada)
        marcar_nao_lido(largura, altura, pixels)
        gravar_png(saida, largura, altura, pixels)
        print(f'{entrada} -> {saida}: ponto de nao lido em {largura}x{altura}')

    else:
        raise AssertionError(f'comando desconhecido: {comando}')


if __name__ == '__main__':
    main()
