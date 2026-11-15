#!/usr/bin/env bash
# Released under Apache 2.0 license as described in the file LICENSE.
# Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
#
# Records how LaTeX defines every math-mode name LeAnTeX's parser knows, so that a layout can
# look up each symbol's TeX math code: LuaLaTeX is run once on a document that loads amsmath,
# amssymb and the New Computer Modern document fonts of tools/math-box-reference.sh, and
# tools/math-codes.lua records, for each control sequence of corpus/math-codes/names.txt (made by
# tools/math-codes-names.py from the parser's tables), what TeX's `\meaning` says it is, and for
# each printable ASCII character its \mathcode and \delcode. The result is
# fixtures/math-codes/codes.tsv.
#
# Row layout, tab-separated, sorted by name (bytewise) with the recording order kept for ties:
#   name  kind  note  field...
# `name` is the control sequence with its backslash (`\alpha`) or the character itself, with
# tabs and newlines in any text escaped as \t and \n. `note` is `-` for the name's own
# definition and `inner:<csname>` for a row that follows a \protect wrapper (LaTeX's `\hat`
# expands to `\protect \hat ` whose inner control sequence is named `hat ` with a space) or a
# macro body that is just a primitive math call (`inner:body`). Integers are decimal. `kind`
# and its fields:
#   mathchar    class family slot          (\mathchar"XYZZ, \mathchardef, \Umathchardef)
#   delimiter   class sfam sslot lfam lslot  (\delimiter"cSSLL...: class, small and large)
#   mathaccent  class family slot          (\mathaccent"XYZZ)
#   radical     sfam sslot lfam lslot      (\radical"...)
#   macro       meaning                    (\meaning text: prefix, parameters, replacement)
#   primitive   meaning                    (for example \mathop or \over)
#   other       meaning                    (any other meaning, e.g. a \char constant)
#   undefined   (no fields)
#   mathcode    class family slot          (characters; class 8 is "8000, an active math char)
#   delcode     sfam sslot lfam lslot      (characters; the single field -1 if none)
#   family      number                     (\symoperators etc.: family number of a symbol font)
# The mathcode of a character is read with tex.getmathcode and its delcode with tex.getdelcode,
# and a control sequence's meaning with `\meaning` itself, parsed in Lua.
#
# Usage, from the repository root:  bash tools/math-codes.sh
# Needs a TeX Live with LuaLaTeX (TEXBIN as in doc-reference.sh). TeX's caches go to a fresh
# temporary directory, removed at the end.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
texbin=${TEXBIN:-$(dirname "$(command -v lualatex || echo /Library/TeX/texbin/lualatex)")}
lualatex="$texbin/lualatex"
[ -x "$lualatex" ] || { echo "math-codes: no lualatex at $lualatex" >&2; exit 2; }
case "$root" in *[\\\{\}\%\#\$\&\~\^\"\ ]*)
  echo "math-codes: unsupported characters in $root" >&2; exit 2;; esac

work=$(mktemp -d "${TMPDIR:-/tmp}/leantex-mathcodes.XXXXXX")
trap '[ -n "${KEEP:-}" ] || rm -rf "$work"' EXIT
export TEXMFVAR="$work/texmf-var" TEXMFCACHE="$work/texmf-var" TEXMFCONFIG="$work/texmf-config"
export LC_ALL=C
mkdir -p "$TEXMFVAR" "$TEXMFCONFIG" "$root/fixtures/math-codes"
cp "$root/corpus/math-codes/names.txt" "$work/names.txt"
{
  printf '%s\n' '\documentclass{article}' '\usepackage{amsmath,amssymb}' \
    "\\def\\LeanTeXNcm{$root/fonts/newcomputermodern}" \
    "\\input{$root/tools/tex-reference/ncm.tex}" \
    '\begin{document}' \
    "\\directlua{dofile('$root/tools/math-codes.lua') leantexMathCodes('names.txt', 'out.tsv')}" \
    'x' '\end{document}'
} > "$work/codes.tex"
(cd "$work" && "$lualatex" --interaction=nonstopmode --halt-on-error codes.tex >"$work/run.out" 2>&1) ||
  { grep -m1 -A8 "^!" "$work/codes.log" >&2; exit 1; }
mv "$work/out.tsv" "$root/fixtures/math-codes/codes.tsv"
echo "math-codes: $(wc -l < "$root/fixtures/math-codes/codes.tsv") rows"
