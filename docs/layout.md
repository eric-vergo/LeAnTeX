# The layout

How LeAnTeX lays a parsed formula out, and how the layout is kept identical to KaTeX's.

## Pipeline

```
TeX ──parse──▶ parse tree ──buildHTML──▶ box tree ──DisplayList.ofBox──▶ display list
     (Parse/)    (Parse/Node.lean)  (Layout/Build.lean)   (Layout/Box.lean)  (Layout/Display.lean)
```

`LeAnTeX.layout tex settings` parses and builds the box tree; `DisplayList.ofBox` turns it into
positioned drawing operations (`docs/display-list.md`).

## The box tree is KaTeX's

The layout is a port of KaTeX's `buildHTML`: every builder produces the same box tree as
KaTeX's (`domTree.ts`: spans, symbol nodes, SVG nodes), with the same classes, heights, depths,
`maxFontSize`, italic corrections, skews, widths, CSS properties in the same order, and the same
attributes. That makes parity checkable node by node against KaTeX itself, and it is the form a
build-time HTML back end prints as KaTeX's markup. The display list is computed from the tree,
by evaluating the subset of KaTeX's style sheet (`katex.scss`) the trees use.

| Module | Port of |
|---|---|
| `Layout/Em.lean` | the numbers (fixed point instead of JavaScript doubles) |
| `Layout/Metrics.lean`, `Data/FontMetrics.lean`, `Data/FontParams.lean` | `fontMetrics.ts`, `fontMetricsData.js` |
| `Layout/Options.lean` | `Style.ts`, `Options.ts` |
| `Layout/Box.lean`, `Layout/BoxJson.lean` | `domTree.ts`, `tree.ts` |
| `Layout/Common.lean` | `buildCommon.ts`, `units.ts`, `SymbolNode`, `unicodeScripts.ts` |
| `Layout/Html.lean` | `buildExpression` and the spacing walk of `buildHTML.ts`, `spacingData.ts` |
| `Layout/Delimiter.lean` | `delimiter.ts`, the delimiter paths of `svgGeometry.ts` |
| `Layout/Stretchy.lean` | `stretchy.ts` |
| `Layout/Builders/Basic.lean` | `symbolsOrd`, `symbolsOp`, `symbolsSpacing`, `ordgroup`, `styling`, `sizing`, `font`, `text`, `mclass`, `color`, `kern` |
| `Layout/Builders/Scripts.lean` | `op`, `operatorname`, `supsub`, `genfrac`, `utils/assembleSupSub`, `staticSvg` |
| `Layout/Builders/Misc.lean` | `mathchoice`, `htmlmathml`, `lap`, `smash`, `phantom`, `rule`, `overline`, `underline`, `raisebox`, `vcenter`, `hbox`, `pmb`, `verb`, `reflectbox`, `html`, `href`, `includegraphics`, `delimsizing` |
| `Layout/Builders/Accents.lean` | `accent`, `accentunder`, `sqrt`, `cr`, `makeSqrtImage`, `sqrtPath` |
| `Layout/Build.lean` | the dispatch, `buildGroup`, `buildHTML`, `buildTree`, `renderError` |
| `Layout/Display.lean` | `katex.scss` (as evaluated by a browser) |

Constructs not laid out yet fail with `BuildError.unsupported` and the parse node type: arrays
and environments, `\xrightarrow` and the other extensible arrows, `\boxed`, `\cancel` and the
other enclosures, horizontal braces, `{CD}`.

### Where KaTeX mutates

KaTeX's builders change boxes after building them (classes, heights, splices of glue into the
array that holds a box). The port does the same with values: a builder returns a changed copy.
The spacing walk of `buildExpression`, which splices glue into whichever nested array holds the
previous box, is done in two steps: list the boxes with their paths, decide, then apply the
changes deepest first (`Layout/Html.lean`).

### Termination

The builders call back into one function, `buildGroupF` (`Layout/Build.lean`), through a
context; it is structurally recursive on a depth bound, so the layout is a total function
without `partial`. The display-list evaluation (`Display.lay`) is structurally recursive on a
depth bound too. The JSON conversion of box trees (`Layout/BoxJson.lean`) and the test
harness use `partial` (they are not part of the layout's semantics).

## Numbers

KaTeX computes in JavaScript doubles. LeAnTeX computes with `Em`: an integer number of TeX's
scaled points (2⁻¹⁶ pt; KaTeX has ten points to the em, so 1/655360 em), with products and
quotients rounded to the nearest unit. The results are exact and the same on every platform,
and open to proof. The metric tables are stored exactly, in units of 1e-5 em (KaTeX's tables
have five decimals), and converted once.

Where KaTeX's output depends on a floating-point accident (a shift that is zero in exact
arithmetic but 1e-17 in doubles, which makes KaTeX write `top: 0em`), the port reproduces the
double computation from the exact table values (`buildOp`).

## The differential test

`tools/record.mjs --layout KATEX` records, for every case of every corpus, KaTeX's box tree from
`katex.__renderToHTMLTree` (numbers rounded to 1e-6 em) into `fixtures/layout/<corpus>.jsonl`,
with the strict-mode warnings. `lake test` lays every case out and compares the trees
(`LeAnTeXTest/Layout.lean`): kinds, texts, classes (without KaTeX's empty ones), style keys and
attributes exactly; numbers within the tolerance:

- unrounded numbers (heights, depths, widths, `maxFontSize`, italic corrections, skews):
  1e-4 em; the largest deviation measured is 1.3e-5 em;
- CSS lengths, which KaTeX rounds to four decimals: one unit of that rounding, 1e-4 em (two
  correct values a hair apart can round to neighbouring four-decimal strings);
- numbers in SVG data, which KaTeX rounds to whole SVG units: one unit, 1/1000 em (none
  measured).

The report (`parity/LAYOUT.md`) gives per corpus and per construct the cases laid out
identically, those that differ and those not yet in scope; `parity/layout-baseline.tsv` holds
the status of every case, and `lake test` fails if a case laid out identically stops being so.
`lake exe leantex-test --show-layout PREFIX` prints the differences of the cases with that
prefix; `--worst-layout` the cases with the largest deviations.

## Regenerating

```
# tables from KaTeX's source (default $KATEX_SOURCE, else .cache/katex-0.19.1)
node --experimental-strip-types --no-warnings --import ./tools/ts-register.mjs \
     tools/gen-layout-tables.mjs [KATEX_SOURCE]
# the fonts' advances, and the browser check (KATEX_DIST: katex.min.js, .css and fonts/)
PLAYWRIGHT_MODULE=path/to/playwright node tools/gen-advances.mjs KATEX_DIST
lake exe leantex-display CORPUS… > dump.jsonl
PLAYWRIGHT_MODULE=path/to/playwright node tools/check-display.mjs KATEX_DIST dump.jsonl
# KaTeX's box trees
node tools/record.mjs --layout path/to/katex.min.js
```
