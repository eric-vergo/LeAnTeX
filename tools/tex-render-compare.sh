#!/usr/bin/env bash
# Released under Apache 2.0 license as described in the file LICENSE.
# Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
#
# Compares LeAnTeX's SVG picture of a LaTeX fragment with LuaLaTeX's own rendering of it, pixel
# by pixel: `lake exe leantex-render` writes the SVG; LuaLaTeX sets the fragment on a page of the
# same size (tools/tex-render/page.tex, the text in New Computer Modern from fonts/); macOS's
# Quick Look renders both at the same width (qlmanage, already on every Mac); then
# tools/compare-pixels.py compares them. TeX's caches and HOME go to a temporary directory that
# is removed at the end.
#
# Usage, from the repository root: bash tools/tex-render-compare.sh FRAGMENT.tex [compare options]
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
src=$(cd "$(dirname "$1")" && pwd)/$(basename "$1"); shift
texbin=${TEXBIN:-$(dirname "$(command -v lualatex || echo /Library/TeX/texbin/lualatex)")}
work=$(mktemp -d "${TMPDIR:-/tmp}/leantex-cmp.XXXXXX")
trap 'rm -rf "$work"' EXIT
case "$root$src" in *[\\\{\}\%\#\$\&\~\^\"\ ]*) echo "unsupported characters in a path" >&2; exit 2;; esac
(cd "$root" && lake exe leantex-render "$src" "$work/ours.svg")
# the picture's size and first baseline, from its root element (TeX points)
read -r w h top < <(python3 -I -c 'import re,sys
s=open(sys.argv[1]).read(); v=re.search(r"viewBox=\"([-0-9.]+) ([-0-9.]+) ([0-9.]+) ([0-9.]+)\"",s)
print(v.group(3), v.group(4), -float(v.group(2)))' "$work/ours.svg")
defs="\\def\\LeanTeXNcm{$root/fonts/newcomputermodern}\\def\\LeanTeXTools{$root/tools/tex-reference}"
defs="$defs\\def\\TOPSKIP{${top}pt}\\def\\PAGEW{${w}pt}\\def\\PAGEH{${h}pt}\\def\\SRC{$src}"
(cd "$work" && env HOME="$work" TEXMFHOME="$work/texmf" TEXMFVAR="$work/var" \
  TEXMFCACHE="$work/var" TEXMFCONFIG="$work/config" "$texbin/lualatex" \
  --interaction=nonstopmode --halt-on-error --jobname=tex "$defs\\input{$root/tools/tex-render/page.tex}" \
  >"$work/run.out" 2>&1) || { tail -30 "$work/tex.log" >&2; exit 1; }
(cd "$work" && qlmanage -t -s 1396 -o . tex.pdf >/dev/null 2>&1 && \
  qlmanage -t -s 1396 -o . ours.svg >/dev/null 2>&1)
python3 -I "$root/tools/compare-pixels.py" "$work/tex.pdf.png" "$work/ours.svg.png" "$@"
