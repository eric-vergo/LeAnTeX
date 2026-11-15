#!/usr/bin/env bash
# Released under Apache 2.0 license as described in the file LICENSE.
# Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
#
# Compares LeAnTeX's picture of one page of a LaTeX document with LuaLaTeX's, pixel by pixel:
# `leantex-render --document` (as built) writes the pages as SVG; LuaLaTeX typesets the document
# with New Computer Modern (tools/tex-reference/ncm.tex), keeping only page N (LaTeX's
# \DiscardShipoutBox for the others); macOS's Quick Look renders both at the same width; then
# tools/compare-pixels.py compares them. TeX's caches and HOME go to a temporary directory that
# is removed at the end.
#
# Usage, from the repository root: bash tools/doc-render-compare.sh DOC.tex N [compare options]
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
doc=$1; page=$2; shift 2
texbin=${TEXBIN:-/Library/TeX/texbin}
work=$(mktemp -d "${TMPDIR:-/tmp}/leantex-doccmp.XXXXXX")
trap '[ -n "${KEEP:-}" ] || rm -rf "$work"' EXIT
# the renderer is run as built (`lake build leantex-render` first), never through `lake` or
# `elan` here: with HOME moved to the scratch directory a toolchain proxy would fetch a toolchain
render="$root/.lake/build/bin/leantex-render"
[ -x "$render" ] || { echo "doc-render-compare: build leantex-render first" >&2; exit 2; }
"$render" --document "$doc" "$work/ours" >/dev/null
export HOME="$work/home" TEXMFVAR="$work/var" TEXMFCACHE="$work/var" TEXMFCONFIG="$work/cfg"
mkdir -p "$HOME"
dir=$(cd "$(dirname "$doc")" && pwd)
cp "$doc" "$work/doc.tex"
[ -d "$dir/images" ] && cp -R "$dir/images" "$work/images"
tools="$root/tools/tex-reference"
defs="\\def\\LeanTeXNcm{$root/fonts/newcomputermodern}"
defs="$defs\\AddToHook{class/article/after}{\\input{$tools/ncm.tex}}"
defs="$defs\\AddToHook{shipout/before}{\\ifnum\\value{page}<$page \\DiscardShipoutBox\\fi}"
defs="$defs\\input{doc.tex}"
for _ in 1 2 3; do
  (cd "$work" && "$texbin/lualatex" --interaction=nonstopmode --jobname=tex "$defs" \
    >/dev/null 2>&1) || true
done
# Quick Look draws an SVG as a square picture, so each page is compared in two squares, its
# top and its bottom (the TeX page is drawn 1584 pixels high and cut into the same squares)
cd "$work"
qlmanage -t -s 1584 -o . tex.pdf >/dev/null 2>&1
w=$(sed -n 's/.*viewBox="0 0 \([0-9.]*\) \([0-9.]*\)".*/\1/p' "ours/page-$page.svg" | head -1)
h=$(sed -n 's/.*viewBox="0 0 \([0-9.]*\) \([0-9.]*\)".*/\2/p' "ours/page-$page.svg" | head -1)
off=$(python3 -I -c "print($h - $w)")
for part in top bottom; do
  y=0; [ "$part" = bottom ] && y=$off
  sed -e "s/viewBox=\"0 0 $w $h\"/viewBox=\"0 $y $w $w\"/" \
    -e 's/ height="[0-9.]*pt"/ height="'"$w"'pt"/' "ours/page-$page.svg" > "$part.svg"
  qlmanage -t -s 1224 -o . "$part.svg" >/dev/null 2>&1
  cp tex.pdf.png "tex-$part.png"
  if [ "$part" = top ]; then sips -c 1224 1224 --cropOffset 0 0 "tex-$part.png" >/dev/null
  else sips -c 1224 1224 --cropOffset 360 0 "tex-$part.png" >/dev/null; fi
  printf '%s: ' "$part"
  python3 -I "$root/tools/compare-pixels.py" "tex-$part.png" "$part.svg.png" "$@"
done
