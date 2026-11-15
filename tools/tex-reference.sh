#!/usr/bin/env bash
# Released under Apache 2.0 license as described in the file LICENSE.
# Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
#
# Records real TeX's answers for the text-mode corpora: for every corpus/text/<name>.jsonl (or
# the names given) it runs LuaLaTeX on tools/tex-reference/reference.tex, which writes
# fixtures/text/<name>.jsonl (line breaks, hyphenation points, box dimensions; see
# tools/tex-reference/reference.lua). The fixtures are committed, so `lake test` needs no TeX.
#
# Usage, from the repository root:  bash tools/tex-reference.sh [name …]
# Needs a TeX Live with LuaLaTeX and the Latin Modern OpenType fonts on PATH, or TEXBIN set to
# its binary directory. TeX writes the fixture into its working directory (TeX Live forbids
# writing elsewhere) and the script moves it into place. TeX's caches (luaotfload's font
# database) go to a fresh temporary directory, never to the user's TEXMFVAR, and that directory
# is removed at the end.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
texbin=${TEXBIN:-$(dirname "$(command -v lualatex || echo /Library/TeX/texbin/lualatex)")}
lualatex="$texbin/lualatex"
[ -x "$lualatex" ] || { echo "tex-reference: no lualatex at $lualatex" >&2; exit 2; }

work=$(mktemp -d "${TMPDIR:-/tmp}/leantex-texref.XXXXXX")
trap 'rm -rf "$work"' EXIT
export TEXMFVAR="$work/texmf-var" TEXMFCACHE="$work/texmf-var" TEXMFCONFIG="$work/texmf-config"
mkdir -p "$TEXMFVAR" "$TEXMFCONFIG" "$root/fixtures/text"

names=("$@")
if [ ${#names[@]} -eq 0 ]; then
  for f in "$root"/corpus/text/*.jsonl; do names+=("$(basename "$f" .jsonl)"); done
fi

for name in "${names[@]}"; do
  corpus="$root/corpus/text/$name.jsonl"
  fixture="$root/fixtures/text/$name.jsonl"
  [ -f "$corpus" ] || { echo "tex-reference: no corpus $corpus" >&2; exit 2; }
  # Paths go to TeX inside \def; refuse characters TeX or Lua would read specially.
  case "$root" in *[\\\{\}\%\#\$\&\~\^\"\ ]*)
    echo "tex-reference: unsupported characters in $root" >&2; exit 2;; esac
  (cd "$work" && "$lualatex" --interaction=nonstopmode --halt-on-error --jobname=ref \
    "\\def\\LeanTeXCorpus{$corpus}\\def\\LeanTeXFixture{out.jsonl}\\def\\LeanTeXTools{$root/tools/tex-reference}\\input{$root/tools/tex-reference/reference.tex}" \
    >"$work/run.out" 2>&1) || { tail -40 "$work/ref.log" >&2; exit 1; }
  mv "$work/out.jsonl" "$fixture"
  grep -o 'leantex-reference: .*' "$work/ref.log" | tr -d '\n'; echo
done
