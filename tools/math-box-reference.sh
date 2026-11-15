#!/usr/bin/env bash
# Released under Apache 2.0 license as described in the file LICENSE.
# Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
#
# Records the box TeX makes for every formula of corpus/math-box/formulas.tsv (a construct and
# a formula per line) in LuaLaTeX with the document fonts of tools/doc-reference.sh (New
# Computer Modern text, TeX's default math fonts, amsmath and amssymb loaded), in the article
# class at 10, 11 and 12 points: \hbox{$f$} (text style) and \hbox{$\displaystyle f$}, each
# as its width, height, depth and whole node list (tools/math-box-reference.lua), one JSON line
# per formula and style, into fixtures/math-box/boxes-<size>pt.jsonl. `lake test` compares
# LeAnTeX's boxes with them and reports the agreement per construct (parity/MATHBOX.md).
#
# Usage, from the repository root:  bash tools/math-box-reference.sh [size …]
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
trap '[ -n "${KEEP:-}" ] || rm -rf "$work"' EXIT
export TEXMFVAR="$work/texmf-var" TEXMFCACHE="$work/texmf-var" TEXMFCONFIG="$work/texmf-config"
mkdir -p "$TEXMFVAR" "$TEXMFCONFIG" "$root/fixtures/math-box"
sizes=("$@")
[ ${#sizes[@]} -eq 0 ] && sizes=(10 11 12)
for size in "${sizes[@]}"; do
  case "$size" in 10|11|12) ;; *) echo "math-box-reference: size $size" >&2; exit 2;; esac
  out="$root/fixtures/math-box/boxes-${size}pt.jsonl"
  {
    printf '%s\n' "\\documentclass[${size}pt]{article}" '\usepackage{amsmath,amssymb}' \
      "\\def\\LeanTeXNcm{$root/fonts/newcomputermodern}" \
      "\\input{$root/tools/tex-reference/ncm.tex}" \
      "\\directlua{dofile('$root/tools/math-box-reference.lua') leantexMathBoxOpen('out.jsonl')}" \
      '\def\leantexbox#1#2{\setbox0\hbox{$#2$}\directlua{leantexMathBox(#1, "text")}%' \
      '  \setbox0\hbox{$\displaystyle #2$}\directlua{leantexMathBox(#1, "display")}}' \
      '\begin{document}'
    n=0
    while IFS=$'\t' read -r construct formula; do
      n=$((n + 1))
      printf '\\leantexbox{%s}{%s}\n' "$n" "$formula"
    done < "$root/corpus/math-box/formulas.tsv"
    printf '%s\n' '\directlua{leantexMathBoxClose()}' 'x' '\end{document}'
  } > "$work/boxes.tex"
  (cd "$work" && "$lualatex" --interaction=nonstopmode --halt-on-error boxes.tex >"$work/run.out" 2>&1) ||
    { grep -m1 -A8 "^!" "$work/boxes.log" >&2; exit 1; }
  mv "$work/out.jsonl" "$out"
  echo "math-box-reference: ${size}pt: $(wc -l < "$out") boxes"
done
