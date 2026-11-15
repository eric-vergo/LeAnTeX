#!/usr/bin/env bash
# Released under Apache 2.0 license as described in the file LICENSE.
# Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
#
# Records LuaLaTeX's answers for the document corpus: for every corpus/doc/<name>.tex (or the
# names given) it typesets the document with LuaLaTeX, New Computer Modern as the fonts
# (tools/tex-reference/ncm.tex), and writes fixtures/doc/<name>.json: every page's lines with
# their positions and text, the text body's vertical list, the counter steps, the labels and
# the table of contents (tools/doc-reference/doc-reference.lua). LaTeX runs until its auxiliary
# file stops changing (at most five runs), so references and the contents are resolved. The
# fixtures are committed, so `lake test` needs no TeX.
#
# Usage, from the repository root:  bash tools/doc-reference.sh [--held-out] [name …]
# With --held-out the documents are corpus/doc-heldout/<name>.tex and the fixtures go to
# fixtures/doc-heldout/ (the held-out set, which the layer is not tuned to).
# Needs a TeX Live with LuaLaTeX (TEXBIN, default the directory of `lualatex` on PATH or
# /Library/TeX/texbin). TeX's caches go to a fresh temporary directory, removed at the end;
# HOME is set to it as well, so nothing is written into the user's own directories.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
texbin=${TEXBIN:-$(dirname "$(command -v lualatex || echo /Library/TeX/texbin/lualatex)")}
lualatex="$texbin/lualatex"
[ -x "$lualatex" ] || { echo "doc-reference: no lualatex at $lualatex" >&2; exit 2; }
case "$root" in *[\\\{\}\%\#\$\&\~\^\"\ ]*)
  echo "doc-reference: unsupported characters in $root" >&2; exit 2;; esac

work=$(mktemp -d "${TMPDIR:-/tmp}/leantex-docref.XXXXXX")
trap '[ -n "${KEEP:-}" ] || rm -rf "$work"' EXIT
export HOME="$work/home" TEXMFVAR="$work/texmf-var" TEXMFCACHE="$work/texmf-var"
export TEXMFCONFIG="$work/texmf-config"
mkdir -p "$HOME" "$TEXMFVAR" "$TEXMFCONFIG"

corpus="$root/corpus/doc" fixtures="$root/fixtures/doc"
if [ "${1:-}" = --held-out ]; then
  corpus="$root/corpus/doc-heldout" fixtures="$root/fixtures/doc-heldout"
  shift
fi
mkdir -p "$fixtures"
names=("$@")
if [ ${#names[@]} -eq 0 ]; then
  for f in "$corpus"/*.tex; do names+=("$(basename "$f" .tex)"); done
fi

tools="$root/tools/doc-reference"
for name in "${names[@]}"; do
  src="$corpus/$name.tex"
  [ -f "$src" ] || { echo "doc-reference: no document $src" >&2; exit 2; }
  run="$work/run-$name"
  mkdir -p "$run"
  cp "$src" "$run/doc.tex"
  [ -d "$root/corpus/doc/images" ] && cp -R "$root/corpus/doc/images" "$run/images"
  defs="\\def\\LeanTeXTools{$tools}\\def\\LeanTeXNcm{$root/fonts/newcomputermodern}"
  defs="$defs\\AddToHook{class/article/after}{\\input{$tools/doc-reference.tex}}"
  defs="$defs\\input{doc.tex}"
  stable=no
  for i in 1 2 3 4 5; do
    [ -f "$run/doc.aux" ] && cp "$run/doc.aux" "$run/prev.aux"
    (cd "$run" && "$lualatex" --interaction=nonstopmode --halt-on-error --jobname=doc "$defs" \
      >"$run/run.out" 2>&1) || { grep -m1 -A14 "^!" "$run/doc.log" >&2; exit 1; }
    if [ -f "$run/prev.aux" ] && cmp -s "$run/doc.aux" "$run/prev.aux"; then stable=yes; break; fi
  done
  [ "$stable" = yes ] || { echo "doc-reference: $name: references did not settle" >&2; exit 1; }
  mv "$run/out.json" "$fixtures/$name.json"
  echo "doc-reference: $name: $i runs"
done
