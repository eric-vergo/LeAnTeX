#!/usr/bin/env bash
# Released under Apache 2.0 license as described in the file LICENSE.
# Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
#
# Records LuaLaTeX's list parameters at every probe of corpus/doc-probe/lists.tex (lists of
# every kind nested to four levels, the trivial-list environments, theorems, the abstract,
# small and footnote sizes) for the article class at 10, 11 and 12 points: the PROBE lines
# that tools/doc-reference/probe.tex writes to the log go to
# fixtures/doc/probe/lists-<size>.txt. `lake test` typesets the same document with the probes
# on and compares every line (LeAnTeXTest/DocChecks.lean).
#
# Usage, from the repository root:  bash tools/list-params.sh
# Needs a TeX Live with LuaLaTeX (TEXBIN as in doc-reference.sh). TeX's caches go to a fresh
# temporary directory, removed at the end.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
texbin=${TEXBIN:-$(dirname "$(command -v lualatex || echo /Library/TeX/texbin/lualatex)")}
lualatex="$texbin/lualatex"
[ -x "$lualatex" ] || { echo "list-params: no lualatex at $lualatex" >&2; exit 2; }
case "$root" in *[\\\{\}\%\#\$\&\~\^\"\ ]*)
  echo "list-params: unsupported characters in $root" >&2; exit 2;; esac

work=$(mktemp -d "${TMPDIR:-/tmp}/leantex-listparams.XXXXXX")
trap 'rm -rf "$work"' EXIT
export TEXMFVAR="$work/texmf-var" TEXMFCACHE="$work/texmf-var" TEXMFCONFIG="$work/texmf-config"
mkdir -p "$TEXMFVAR" "$TEXMFCONFIG" "$root/fixtures/doc/probe"
cp "$root/corpus/doc-probe/lists.tex" "$work/doc.tex"
for size in 10 11 12; do
  defs="\\PassOptionsToClass{${size}pt}{article}"
  defs="$defs\\AddToHook{class/article/after}{\\input{$root/tools/doc-reference/probe.tex}}"
  (cd "$work" && "$lualatex" --interaction=nonstopmode --halt-on-error --jobname=doc \
    "$defs\\input{doc.tex}" >"$work/run.out" 2>&1) || { grep -m1 -A8 "^!" "$work/doc.log" >&2; exit 1; }
  # a log line longer than TeX's max_print_line is wrapped: join the wrapped lines first
  tr -d '\n' < "$work/doc.log" | sed 's/PROBE /\nPROBE /g' | grep '^PROBE ' |
    sed 's/belowdisplayshortskip=\([-0-9]*,[-0-9]*,[-0-9]*\).*/belowdisplayshortskip=\1/' \
    > "$root/fixtures/doc/probe/lists-${size}pt.txt"
  echo "list-params: ${size}pt: $(wc -l < "$root/fixtures/doc/probe/lists-${size}pt.txt") probes"
done
