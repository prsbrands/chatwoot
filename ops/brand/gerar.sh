#!/bin/bash
# Gera todos os arquivos de marca a partir das duas artes de origem.
#
#   app/assets/images/ico.png  512x512  icone quadrado, fundo escuro
#   app/assets/images/cga.png  350x100  logo horizontal, texto BRANCO
#
# Roda do raiz do repositorio. Idempotente: pode rodar de novo quando a arte
# mudar. Usa `sips` (nativo do macOS) para redimensionar e o png_tool.py para o
# que ele nao faz — recolorir e recortar.
set -euo pipefail
cd "$(dirname "$0")/../.."

ICO=app/assets/images/ico.png
CGA=app/assets/images/cga.png
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

[ -f "$ICO" ] && [ -f "$CGA" ] || { echo "faltam as artes de origem em app/assets/images/"; exit 1; }

# O texto do logo e branco, entao serve em fundo escuro. Em fundo claro ele
# sumiria, e o painel usa os dois (block dark:hidden / hidden dark:block).
python3 ops/brand/png_tool.py recolor "$CGA" "$TMP/cga-claro.png" 1B1B1B

# O icone do balao do widget fica sobre a cor que o cliente escolhe, entao e
# monocromatico: so o simbolo, em branco. O texto comeca na coluna 108.
python3 ops/brand/png_tool.py crop-solid "$CGA" "$TMP/simbolo-branco.png" 0 0 108 100 FFFFFF

redim() { sips -s format png --resampleHeightWidthMax "$2" "$1" --out "$3" >/dev/null; }

# Um SVG que carrega o PNG embutido. Nao vetoriza nada — mantem os nomes de
# arquivo que o codigo e o installation_config.yml ja apontam, sem ter que
# caçar referencia por referencia. Os logos aparecem a 32-40px de altura, bem
# abaixo da resolucao da arte, entao nao ha perda visivel.
svg_com_png() {
  local png=$1 w=$2 h=$3 destino=$4 vb_w=${5:-$2} vb_h=${6:-$3} x=${7:-0} y=${8:-0}
  {
    printf '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="0 0 %s %s">' "$vb_w" "$vb_h" "$vb_w" "$vb_h"
    printf '<image x="%s" y="%s" width="%s" height="%s" href="data:image/png;base64,' "$x" "$y" "$w" "$h"
    base64 < "$png" | tr -d '\n'
    printf '"/></svg>'
  } > "$destino"
}

echo "== icones quadrados =="
for tamanho in 16 32 96 512; do
  redim "$ICO" "$tamanho" "public/favicon-${tamanho}x${tamanho}.png"
done
for tamanho in 36 48 72 96 144 192; do
  redim "$ICO" "$tamanho" "public/android-icon-${tamanho}x${tamanho}.png"
done
for tamanho in 57 60 72 76 114 120 144 152 180; do
  redim "$ICO" "$tamanho" "public/apple-icon-${tamanho}x${tamanho}.png"
done
for tamanho in 70 144 150 310; do
  redim "$ICO" "$tamanho" "public/ms-icon-${tamanho}x${tamanho}.png"
done
for arquivo in apple-icon.png apple-icon-precomposed.png apple-touch-icon.png apple-touch-icon-precomposed.png; do
  redim "$ICO" 180 "public/$arquivo"
done
echo "   $(ls public/*.png | grep -vc badge) arquivos"

echo "== favicon com ponto de nao lido =="
for tamanho in 16 32 96; do
  python3 ops/brand/png_tool.py badge "public/favicon-${tamanho}x${tamanho}.png" \
    "public/favicon-badge-${tamanho}x${tamanho}.png" >/dev/null
done

echo "== logo horizontal =="
svg_com_png "$TMP/cga-claro.png" 350 100 public/brand-assets/logo.svg
svg_com_png "$CGA"               350 100 public/brand-assets/logo_dark.svg
redim "$TMP/cga-claro.png" 294 app/javascript/design-system/images/logo.png
redim "$CGA"               294 app/javascript/design-system/images/logo-dark.png

echo "== marca quadrada em svg =="
svg_com_png "$ICO" 512 512 public/brand-assets/logo_thumbnail.svg
svg_com_png "$ICO" 512 512 app/javascript/design-system/images/logo-thumbnail.svg
svg_com_png "$ICO" 512 512 app/javascript/widget/assets/images/logo.svg

echo "== balao do widget =="
redim "$TMP/simbolo-branco.png" 66 "$TMP/balao.png"
altura=$(sips -g pixelHeight "$TMP/balao.png" | awk '/pixelHeight/{print $2}')
# Centralizado num quadro 66x66, que e o viewBox que o componente espera.
svg_com_png "$TMP/balao.png" 66 "$altura" app/javascript/dashboard/assets/images/bubble-logo.svg 66 66 0 "$(( (66 - altura) / 2 ))"

echo "pronto"
