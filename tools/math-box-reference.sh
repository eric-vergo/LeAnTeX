#!/usr/bin/env bash
# Released under Apache 2.0 license as described in the file LICENSE.
# Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
#
# Records the box TeX makes for every formula of corpus/math-box/formulas.tsv (a construct and
# a formula per line) in LuaLaTeX with the document fonts of tools/doc-reference.sh (New
# Computer Modern text, TeX's default math fonts) at ten points: the width, height and depth
# of \hbox{$f$} (text style) and of \hbox{$\displaystyle f$}, in sp, one line per formula and
# style, into fixtures/math-box/boxes.tsv. `lake test` compares the math layout's boxes with
# them and reports the agreement per construct (parity/MATHBOX.md); it requires nothing.
#
# Usage, from the repository root:  bash tools/math-box-reference.sh
# Needs a TeX Live with LuaLaTeX (TEXBIN as in doc-reference.sh). TeX's caches go to a fresh
# temporary directory, removed at the end.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
texbin=${TEXBIN:-$(dirname "$(command -v lualatex || echo /Library/TeX/texbin/lualatex)")}
lualatex="$texbin/lualatex"
[ -x "$lualatex" ] || { echo "math-box-reference: no lualatex at $lualatex" >&2; exit 2; }
case "$root" in *[\\\{\}\%\#\$\&\~\^\"\ ]*)
  echo "math-box-reference: unsupported characters in $root" >&2; exit 2;; esac

work=$(mktemp -d "${TMPDIR:-/tmp}/leantex-mathbox.XXXXXX")
trap 'rm -rf "$work"' EXIT
export TEXMFVAR="$work/texmf-var" TEXMFCACHE="$work/texmf-var" TEXMFCONFIG="$work/texmf-config"
mkdir -p "$TEXMFVAR" "$TEXMFCONFIG" "$root/fixtures/math-box"
{
  printf '%s\n' '\documentclass{article}' '\usepackage{amsmath,amssymb}' \
    "\\def\\LeanTeXNcm{$root/fonts/newcomputermodern}" \
    "\\input{$root/tools/tex-reference/ncm.tex}" \
    '\def\leantexbox#1#2{\setbox0\hbox{$#2$}\typeout{BOX #1 text \number\wd0 \space\number\ht0 \space\number\dp0 }%' \
    '  \setbox0\hbox{$\displaystyle #2$}\typeout{BOX #1 display \number\wd0 \space\number\ht0 \space\number\dp0 }}' \
    '\begin{document}'
  n=0
  while IFS=$'\t' read -r construct formula; do
    n=$((n + 1))
    printf '\\leantexbox{%s}{%s}\n' "$n" "$formula"
  done < "$root/corpus/math-box/formulas.tsv"
  printf '%s\n' 'x' '\end{document}'
} > "$work/boxes.tex"
(cd "$work" && "$lualatex" --interaction=nonstopmode --halt-on-error boxes.tex >"$work/run.out" 2>&1) ||
  { grep -m1 -A8 "^!" "$work/boxes.log" >&2; exit 1; }
grep '^BOX ' "$work/boxes.log" | sed 's/^BOX //' | tr ' ' '\t' > "$root/fixtures/math-box/boxes.tsv"
echo "math-box-reference: $(wc -l < "$root/fixtures/math-box/boxes.tsv") boxes"
