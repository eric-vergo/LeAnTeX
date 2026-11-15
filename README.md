# LeAnTeX

A TeX math renderer in pure Lean 4, ported from [KaTeX](https://katex.org), growing into a
typesetter for documents. It depends on Lean's `Init` and `Std` only, so it can be used from
any Lean program, including code that may not import the `Lean` package.

It aims at KaTeX parity in math mode: the same formulas accepted, the same errors for the
others, the same boxes, glyphs and positions, laid out to a neutral display list that drawing
back ends consume.

## Status

| Stage | State |
|---|---|
| Lexer, macro expander, parser of KaTeX 0.19.1's whole function list, KaTeX's error messages | done: every case of every corpus parses to KaTeX's tree or fails with KaTeX's error ([parity report](parity/REPORT.md)) |
| Layout to KaTeX's box tree: every construct, from symbols, scripts and fractions to arrays and environments, `{CD}`, enclosures, extensible arrows and braces | done: every corpus formula KaTeX lays out gets KaTeX's box tree ([layout parity report](parity/LAYOUT.md)) |
| Display list (positioned glyphs, rules, paths; mirrored material, display-mode placement, equation numbers) | done ([definition](docs/display-list.md)); checked against KaTeX in a browser |
| OpenType font reader: metrics, character maps, CFF and TrueType outlines, ligatures, pair kerning, `MATH` constants; untrusted input checked ([reader](docs/opentype.md)) | done: every glyph of fifteen Latin Modern fonts as fontTools reads it; TeX's boxes reproduced; fuzzed |
| Text mode: reference harness against real TeX for line breaks, hyphenation and boxes ([reference](docs/text-reference.md)) | done: 174 paragraphs, 1,691 words, 80 boxes recorded from LuaLaTeX |
| Text mode: Liang hyphenation, Knuth–Plass line breaking, a LaTeX front end (paragraphs, spacing, fonts and sizes, boxes, formulas, macros), lines as a display list ([text mode](docs/text.md)) | done: every hyphenation point, every break, demerit and glue setting, and every horizontal list TeX built for the corpus, reproduced |
| Documents: the `article` class to pages: vertical lists, TeX's page builder, LaTeX's output routine with floats and footnotes, sectioning, counters, references, contents, lists, theorems, tables, figures; paged SVG and HTML ([documents](docs/documents.md)) | 39 of 47 corpus documents agree with LuaLaTeX line by line to the sp, 1,088 of 1,142 lines ([report](parity/DOC.md)) |
| Back ends: SVG (glyphs as outlines, self-contained) and HTML (text as text, formulas as inline SVG), with New Computer Modern ([back ends](docs/back-ends.md)) | done: examples in `examples/`; escaping proved; compared with LuaLaTeX's rendering |
| Fonts: New Computer Modern, the files under the GUST Font License, unmodified ([fonts](fonts/README.md)) | committed with a manifest; the text layer agrees with LuaLaTeX on all 174 paragraphs with them too |

## Use

```lean
import LeAnTeX

#eval match (LeAnTeX.parse "\\frac{a}{b}^2").result with
  | .ok tree => toString (LeAnTeX.nodesToJson tree).compress
  | .error e => e.message

#eval match (LeAnTeX.layout "\\frac{a}{b}^2").result with
  | .ok box => s!"{(LeAnTeX.DisplayList.ofBox box).items.size} items"
  | .error _ => "not laid out"
```

`LeAnTeX.parse` takes `LeAnTeX.Settings` (display mode, user macros, `strict`, `trust`,
`throwOnError`, `maxSize`, …) with KaTeX's defaults, and returns the parse tree or the error,
plus the strict-mode warnings KaTeX would print. `LeAnTeX.layout` parses and lays the formula
out into KaTeX's box tree (`docs/layout.md`); `DisplayList.ofBox` turns that into positioned
glyphs, rules and paths for a drawing back end (`docs/display-list.md`).

## Tests

```
lake build --wfail
lake test
```

`lake test` parses every formula of the corpora in `corpus/` and compares the result with
KaTeX's answer recorded in `fixtures/`: the parse tree (as JSON, with source positions), or the
error (class, message, position, length), and the warnings. It then lays every formula out and
compares the box tree with KaTeX's, recorded in `fixtures/layout/` (`docs/layout.md` gives the
tolerances), checks the display list's invariants on every formula and its features on chosen
ones. It fails if a case that matched in `parity/baseline.tsv` or `parity/layout-baseline.tsv`
no longer does, or a display-list check fails. `lake exe leantex-test --update` rewrites the
baselines and the reports; `--show PREFIX` and `--show-layout PREFIX` print the mismatched cases
whose id starts with `PREFIX`; `--bench` and `--bench-matrix` time the stages.

It also checks the text-mode fixtures (`fixtures/text/`, real TeX's line breaks, hyphenation
points and boxes) against their corpora and the font reader against fontTools and TeX
(`docs/opentype.md`); `lake exe leantex-test --text` runs those checks alone, with the text layer's: hyphenation,
line breaking and the front end against TeX, the typesetting goldens (`fixtures/typeset/`,
`--update-typeset` rewrites them), the front-end checks and fuzzing. `lake exe leantex-typeset
FILE` typesets a LaTeX file and prints its display list; `lake exe leantex-render FILE OUT`
writes it as SVG or HTML (`docs/back-ends.md`), and the back ends' checks compare `examples/`
byte for byte (`--update-examples` rewrites them).

The corpora: KaTeX's own parser and error tests (`katex-spec`), its screenshot cases, the examples
of its support table, a few formulas per KaTeX name (`katex-names`), the formulas of Mathlib's doc
comments and of a Verso blueprint site.

## Regenerating

The tables and fixtures come from KaTeX itself; Node 22 or later is needed, nothing else.

```
# tables (LeAnTeX/Data/*.lean, parity/names.tsv), from a checkout of KaTeX's source at v0.19.1
node --experimental-strip-types --no-warnings --import ./tools/ts-register.mjs \
     tools/gen-tables.mjs KATEX_SOURCE
# corpora from KaTeX's tests and docs
node --experimental-strip-types --no-warnings --import ./tools/ts-register.mjs \
     tools/harvest-katex.mjs KATEX_SOURCE
python3 -I tools/names-corpus.py
# KaTeX's answers, from the built katex.min.js of the same version
node tools/record.mjs path/to/katex.min.js
node tools/record.mjs --layout path/to/katex.min.js
# layout tables, and the fonts' advances (headless Chromium through Playwright)
node --experimental-strip-types --no-warnings --import ./tools/ts-register.mjs \
     tools/gen-layout-tables.mjs KATEX_SOURCE
PLAYWRIGHT_MODULE=path/to/playwright node tools/gen-advances.mjs KATEX_DIST
```

`KATEX_SOURCE` defaults to `$KATEX_SOURCE`, else `.cache/katex-0.19.1` (ignored by git);
`KATEX_DIST` is a directory with KaTeX's built `katex.min.js`, `katex.min.css` and `fonts/`.
`tools/check-display.mjs` compares display lists with a browser's rendering of KaTeX
(`docs/display-list.md`).

The text-mode corpora and TeX's answers (LuaLaTeX from TeX Live, with the Latin Modern
OpenType fonts), and fontTools' reading of the fonts:

```
python3 -I tools/text-corpus.py
bash tools/tex-reference.sh
python3 -I tools/test-fonts.py && python3 -I tools/font-reference.py --test-fonts
python3 -I tools/font-reference.py
```

`tools/extract-mathlib.py` and `tools/extract-blueprint.py` build the Mathlib and blueprint
corpora from a Mathlib checkout and a built blueprint site.

## Licence

Apache License 2.0 (`LICENSE`). Parts are derived from KaTeX (MIT licence, `LICENSE-KaTeX`), and
one table from KaTeX's fonts (SIL Open Font License 1.1); `fonts/` holds fonts of New Computer
Modern under the GUST Font License; see `THIRD-PARTY.md` for which.
