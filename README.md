# LeAnTeX

A TeX math renderer in pure Lean 4, ported from [KaTeX](https://katex.org), growing into a
typesetter for documents. It depends on Lean's `Init` and `Std` only, so it can be used from
any Lean program, including code that may not import the `Lean` package.

It aims at KaTeX parity in math mode: the same formulas accepted, the same errors for the
others, the same boxes, glyphs and positions, laid out to a neutral display list that drawing
back ends consume. It has two limits of its own, so that a formula from a stranger costs no
more than its length allows: on the tokens macros produce and arguments re-read
(`Settings.maxTokens`) and on nesting (`Settings.maxNesting`), both far above what a formula
written by hand reaches. What agrees with KaTeX and with TeX, on which inputs, and how to
check it, is in *The figures, and how to reproduce them* below.

## Status

| Stage | State |
|---|---|
| Lexer, macro expander, parser of KaTeX 0.19.1's whole function list, KaTeX's error messages | done: each of the 11,885 corpus cases parses to the tree KaTeX's recorded answer has, or fails with its error ([parity report](parity/REPORT.md)) |
| Layout to KaTeX's box tree: every construct, from symbols, scripts and fractions to arrays and environments, `{CD}`, enclosures, extensible arrows and braces | done: each of the 10,855 corpus formulas KaTeX lays out gets KaTeX's recorded box tree, numbers within the tolerances of `docs/layout.md` ([layout parity report](parity/LAYOUT.md)) |
| Display list (positioned glyphs, rules, paths; mirrored material, display-mode placement, equation numbers) | done ([definition](docs/display-list.md)); compared with KaTeX in a browser by a tool that is not part of `lake test` |
| OpenType font reader: metrics, character maps, CFF and TrueType outlines, ligatures, pair kerning, `MATH` constants; untrusted input checked ([reader](docs/opentype.md)) | done: every glyph of fifteen Latin Modern fonts as fontTools reads it; 72 of TeX's 80 recorded boxes reproduced (8 are left out, see below); fuzzed |
| Text mode: reference harness against real TeX for line breaks, hyphenation and boxes ([reference](docs/text-reference.md)) | done: 174 paragraphs, 1,691 words, 80 boxes recorded from LuaLaTeX |
| Text mode: Liang hyphenation, Knuth–Plass line breaking, a LaTeX front end (paragraphs, spacing, fonts and sizes, boxes, formulas, macros), lines as a display list ([text mode](docs/text.md)) | done: for the recorded corpus (174 paragraphs, 1,691 words) every hyphenation point, every break, demerit and glue setting, and every horizontal list LuaLaTeX built, reproduced |
| Documents: the `article` class to pages: vertical lists, TeX's page builder, LaTeX's output routine with floats and footnotes, sectioning, counters, references, contents, lists, theorems, tables, figures, bibliographies; paged SVG and HTML ([documents](docs/documents.md)) | Second held-out set (10 documents written without reading the library after the first set was run, run once, never tuned to): 5 of 10 agree in full, 374 of 400 lines at LuaLaTeX's place to the sp; first held-out set (20 written the same way): 8 of 20 when first run blind, 9 of 20 and 398 of 469 lines now, after a defect it showed was fixed and four of its fixtures were re-recorded for a recorder fix; reference documents (tuned on): 87 of 87, 1,810 of 1,810 lines; fresh documents (written blind, tuned on): 7 of 10 ([report](parity/DOC.md)) |
| TeX-rule math layout for documents: TeX's Appendix G with the Computer Modern metric files read from a TeX installation, LaTeX's and amsmath's constructions, inline formulas breaking as in TeX ([formula boxes](docs/math-boxes.md)) | 12,162 of the 12,174 recorded formula boxes it builds are TeX's to the sp, of 12,750 recorded (2,125 formulas, text and display style, 10, 11 and 12 pt); the other 576 are of formulas it refuses, which the KaTeX-compatible layout sets (4 of those are TeX's) ([report](parity/MATHBOX.md)) |
| Back ends: SVG (glyphs as outlines, self-contained) and HTML (text as text, formulas as inline SVG), with New Computer Modern; MathML of the parse tree ([back ends](docs/back-ends.md)) | done: examples in `examples/`; the escaping function proved to leave no `<`, `>`, `"` or `'` and to decode back to its input (less the characters XML cannot carry; that every `&` it writes starts an entity is read from its definition, not stated by that theorem) (that every writer passes all text through it is tested, not proved); compared with LuaLaTeX's rendering by a tool that is not part of `lake test` |
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
baselines and the reports from the corpora it finds (to be run in a checkout that has the
committed corpora only); `--show PREFIX` and `--show-layout PREFIX` print the mismatched cases
whose id starts with `PREFIX`; `--bench` and `--bench-matrix` time the stages.

It also checks the text-mode fixtures (`fixtures/text/`, LuaLaTeX's line breaks, hyphenation
points and boxes) against their corpora and the font reader against fontTools and TeX
(`docs/opentype.md`); `lake exe leantex-test --text` runs those checks alone, with the text
layer's: hyphenation, line breaking and the front end against TeX, the typesetting goldens
(`fixtures/typeset/`, `--update-typeset` rewrites them), the front-end checks and fuzzing.
Then the documents against LuaLaTeX's recorded pages (`docs/documents.md`), the formula boxes
against LuaLaTeX's (`docs/math-boxes.md`; `--update-doc` rewrites `parity/DOC.md`,
`parity/MATHBOX.md` and their baselines), and the bounded-work checks, which run the
command-line programs on hostile sources under CPU and memory limits (`--bounds`).
`lake exe leantex-typeset FILE` typesets a LaTeX file and prints its display list;
`lake exe leantex-render FILE OUT` writes it as SVG or HTML (`docs/back-ends.md`), and the back
ends' checks compare `examples/` byte for byte (`--update-examples` rewrites them).

The corpora: KaTeX's own parser and error tests (`katex-spec`), its screenshot cases, the examples
of its support table, a few formulas per KaTeX name (`katex-names`), the formulas of Mathlib's doc
comments and of a Verso blueprint site.

## The figures, and how to reproduce them

Every figure in this file, in `STATUS.md` and in `docs/` is printed by the command beside it
from the committed corpora and fixtures. The fixtures are the reference programs' answers as
recorded (KaTeX 0.19.1, LuaLaTeX of TeX Live 2025, fontTools); the tests compare with the
recordings and run none of those programs. A comparison that says "to the sp" is exact:
integers compared for equality.

| Figure | Printed by | What it shows | What it does not show |
|---|---|---|---|
| Parser: 11,885 of 11,885 cases. Layout: 10,855 laid out as KaTeX does, the other 1,030 rejected by both | `lake test` (its first lines); `parity/REPORT.md`, `parity/LAYOUT.md` | the parse tree or error, and the box tree with every number within 1e-4 em (`docs/layout.md`), equal KaTeX's recorded ones for every case of the committed corpora | anything about formulas outside the corpora. A corpus file that is present locally but not committed is counted too, so a checkout with one prints larger totals (`LEANTEX_COMMITTED_CORPORA=1 lake test` leaves such a file out; the manual runs the driver that way) |
| Text: 174 of 174 paragraphs, 1,691 of 1,691 words (2,686 hyphenation points), 72 boxes | `lake exe leantex-test --text` | LuaLaTeX's recorded horizontal lists, breaks, demerits, glue settings, hyphenation points and boxes, reproduced exactly | with Latin Modern only where TeX Live's fonts are installed (else those rows are skipped with a note; the New Computer Modern rows always run). 8 of the 80 recorded boxes are left out: they need TeX's own ligature characters or a character the font lacks |
| Formula boxes: 12,166 of 12,750 the same to the sp: 12,162 of the 12,174 the TeX-rule layout builds and 4 of the 576 it refuses | `lake test`, `lake exe leantex-test --math-boxes`; `parity/MATHBOX.md` | width, height and depth equal LuaLaTeX's for 2,125 formulas in two styles at three sizes | needs the Computer Modern metric files of a TeX installation (skipped with a note without them). The boxes of formulas the layout refuses are set by the KaTeX-compatible layout and are not TeX's but for 4. The formulas were chosen and generated here and the layout was developed against them |
| Documents developed with: 87 of 87 reference and regression documents (1,810 of 1,810 lines), 7 of 10 fresh documents (367 of 398 lines) | `lake test`, `lake exe leantex-test --doc-table`; `parity/DOC.md` | every line of every page at LuaLaTeX's position to the sp with its text, and the labels, contents and counter steps | how the layer does on documents it was not tuned on: these were written for it or it was corrected against them. The 18 with formulas need the metric files |
| First held-out set: 9 of 20 documents, 398 of 469 lines | `lake test`, `lake exe leantex-test --doc-table heldout` | the same comparison on twenty documents written without reading the library | a blind result: one defect the set showed was fixed afterwards and four fixtures were re-recorded. The blind run gave 8 of 20 and 397 lines; `git checkout e04b63b && lake test` prints it |
| Second held-out set: 5 of 10 documents, 374 of 400 lines, page breaks 10 of 10 | `lake test`, `lake exe leantex-test --doc-table heldout-2` | the same comparison on ten documents written blind after the first set was run; run once, nothing changed for them (their files have one commit, `648d738`) | more than ten short mathematical articles can show: it is a small sample, and the figure to go by all the same |
| Display list against a browser; rendering against LuaLaTeX's (`STATUS.md`, `docs/display-list.md`, `docs/back-ends.md`) | `tools/check-display.mjs`, `tools/tex-render-compare.sh`, `tools/doc-render-compare.sh` | what those documents say | reproducible from the commit alone: they need KaTeX's built distribution and Chromium, or LuaLaTeX and macOS, and are not part of `lake test`; their figures are those of the last run |

The theorems (`docs/text.md`, `docs/documents.md`, `docs/back-ends.md`, `docs/math-boxes.md`,
each under *Proved and tested*) are stated about the functions the library calls;
`lake build LeAnTeXTest.TextAxioms LeAnTeXTest.DocAxioms LeAnTeXTest.BackendAxioms
LeAnTeXTest.TeXMathAxioms` prints the axioms of each (`propext`, `Classical.choice`,
`Quot.sound` and no other).

Without a TeX installation `lake test` still passes: the comparisons that need its metric files
or Latin Modern are skipped, each with a note (`LEANTEX_TFM_DIRS=/nonexistent
LEANTEX_FONT_DIRS=/nonexistent lake test` shows it on a machine that has one).

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

## Manual

`manual/` is a Lake package that builds LeAnTeX's manual, a Verso web site: getting started,
a guide to each layer, the agreement figures, the theorems, the API reference of every module,
and the licences.

```
cd manual
lake exe leantex-manual        # writes the site to manual/_out/html-multi
```

Its Lean examples are compiled and its pictures are typeset by LeAnTeX while the pages are
built; the lists of what is supported are quoted from `docs/`; the agreement chapter runs
`leantex-test` and puts what it prints beside the figures of this file; a public declaration
without a docstring fails the build unless `manual/api-allow.txt` names it. After adding,
removing or renaming a module, `lake exe leantex-manual-api` (in `manual/`) writes the API
reference's pages. The workflow `.github/workflows/manual.yml`, started by hand, builds the site
and uploads it as a GitHub Pages artifact.

## Licence

Apache License 2.0 (`LICENSE`). Parts are derived from KaTeX (MIT licence, `LICENSE-KaTeX`), and
one table from KaTeX's fonts (SIL Open Font License 1.1); `fonts/` holds fonts of New Computer
Modern under the GUST Font License; see `THIRD-PARTY.md` for which.
