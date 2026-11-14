# LeAnTeX

A TeX math renderer in pure Lean 4, ported from [KaTeX](https://katex.org). It depends on
Lean's `Init` and `Std` only, so it can be used from any Lean program, including code that may
not import the `Lean` package.

It aims at KaTeX parity in math mode: the same formulas accepted, the same errors for the
others, the same boxes, glyphs and positions, laid out to a neutral display list that drawing
back ends consume.

## Status

| Stage | State |
|---|---|
| Lexer, macro expander, parser of KaTeX 0.19.1's whole function list, KaTeX's error messages | done: every case of every corpus parses to KaTeX's tree or fails with KaTeX's error ([parity report](parity/REPORT.md)) |
| Layout to KaTeX's box tree: every construct, from symbols, scripts and fractions to arrays and environments, `{CD}`, enclosures, extensible arrows and braces | done: every corpus formula KaTeX lays out gets KaTeX's box tree ([layout parity report](parity/LAYOUT.md)) |
| Display list (positioned glyphs, rules, paths; mirrored material, display-mode placement, equation numbers) | done ([definition](docs/display-list.md)); checked against KaTeX in a browser |
| Back ends | not started |

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
plus the strict-mode warnings KaTeX would print. `LeAnTeX.layout` parses and lays the formula out into
KaTeX's box tree (`docs/layout.md`); `DisplayList.ofBox` turns that into positioned glyphs,
rules and paths for a drawing back end (`docs/display-list.md`).

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

`tools/extract-mathlib.py` and `tools/extract-blueprint.py` build the Mathlib and blueprint
corpora from a Mathlib checkout and a built blueprint site.

## Licence

Apache License 2.0 (`LICENSE`). Parts are derived from KaTeX (MIT licence, `LICENSE-KaTeX`), and
one table from KaTeX's fonts (SIL Open Font License 1.1); see `THIRD-PARTY.md` for which.
