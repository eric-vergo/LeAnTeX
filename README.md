# LeAnTeX

A TeX math renderer in pure Lean 4, ported from [KaTeX](https://katex.org). It depends on
Lean's `Init` and `Std` only, so it can be used from any Lean program, including code that may
not import the `Lean` package.

The goal is KaTeX parity in math mode: the same formulas accepted, the same errors for the
others, and (in later stages) the same boxes, glyphs and positions, laid out to a neutral
display list that drawing back ends consume.

## Status

| Stage | State |
|---|---|
| Lexer, macro expander, parser of KaTeX 0.19.1's whole function list, KaTeX's error messages | done: every case of every corpus parses to KaTeX's tree or fails with KaTeX's error ([parity report](parity/REPORT.md)) |
| Layout to boxes (symbols, spacing, scripts, fractions, operators, delimiters, roots, arrays …) | not started |
| Display list and back ends | not started |

## Use

```lean
import LeAnTeX

#eval match (LeAnTeX.parse "\\frac{a}{b}^2").result with
  | .ok tree => toString (LeAnTeX.nodesToJson tree).compress
  | .error e => e.message
```

`LeAnTeX.parse` takes `LeAnTeX.Settings` (display mode, user macros, `strict`, `trust`,
`throwOnError`, …) with KaTeX's defaults, and returns the parse tree or the error, plus the
strict-mode warnings KaTeX would print.

## Tests

```
lake build --wfail
lake test
```

`lake test` parses every formula of the corpora in `corpus/` and compares the result with
KaTeX's answer recorded in `fixtures/`: the parse tree (as JSON, with source positions), or the
error (class, message, position, length), and the warnings. It fails if a case that matched in
`parity/baseline.tsv` no longer matches. `lake exe leantex-test --update` rewrites the baseline
and the report; `lake exe leantex-test --show PREFIX` prints the mismatched cases whose id starts
with `PREFIX`.

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
```

`tools/extract-mathlib.py` and `tools/extract-blueprint.py` build the Mathlib and blueprint
corpora from a Mathlib checkout and a built blueprint site.

## Licence

Apache License 2.0 (`LICENSE`). Parts are derived from KaTeX (MIT licence, `LICENSE-KaTeX`); see
`THIRD-PARTY.md` for which.
