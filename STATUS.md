# Status

Resume notes for the work in progress. Updated after every step.

## State

- Parser (done): 12,272 of 12,272 corpus cases match KaTeX 0.19.1 (trees, errors, warnings).
- Layout core (in progress):
  - `LeAnTeX/Layout/Em.lean`: lengths as integer scaled points (2⁻¹⁶ pt, 1/655360 em).
  - Generated tables: `LeAnTeX/Data/FontMetrics.lean`, `FontParams.lean`, `SvgPaths.lean`
    (`tools/gen-layout-tables.mjs`, from KaTeX's source), `FontAdvances.lean`
    (`tools/gen-advances.mjs`, from KaTeX's fonts in headless Chromium).
  - Box tree (`Layout/Box.lean`, KaTeX's `domTree`), `Options`, `buildCommon`
    (`Layout/Common.lean`), `buildExpression` with spacing (`Layout/Html.lean`), delimiters
    (`Layout/Delimiter.lean`), builders (`Layout/Builders/`), `buildHTML` and the entry point
    `layout` (`Layout/Build.lean`), JSON form (`Layout/BoxJson.lean`).
  - Display list (`Layout/Display.lean`): glyphs, rules, paths, regions, parts.
  - Constructs laid out: symbols of every kind and font, spacing, groups, styles, sizes, math
    and text fonts, `\text…`, `\math…` classes, colour, kerns, scripts, large operators and
    limits, `\operatorname`, fractions and generalised fractions with delimiters.
- Harness: `tools/record.mjs --layout` records KaTeX's box trees (`fixtures/layout/`);
  `lake test` compares (`LeAnTeXTest/Layout.lean`), report `parity/LAYOUT.md`, baseline
  `parity/layout-baseline.tsv`. `tools/check-display.mjs` compares display lists with Chromium.
- Layout parity: 9,756 of 12,272 cases identical to KaTeX, 0 differ, 1,486 not yet in scope.
- Display list against Chromium (9,634 formulas): glyph x within 0.0009 em, baseline within
  0.0002 em, width within 0.0009 em, fraction bars within 0.002 em (border pixel snapping).

## Next

1. Docs: `docs/display-list.md`, `docs/layout.md`, README, THIRD-PARTY rows.
2. More constructs (in order of formulas they unblock): `htmlmathml`, accents, `\left…\right`,
   `\big…`, `\sqrt`, phantoms, smash, lap, rules, overline/underline, mathchoice, …
3. Gates: style check (IDEiL's checker, read-only), `lake build --wfail`, `lake test`.

## Open questions for the owner

1. The Noperthedron blueprint corpus: the blueprint repository states no licence (the
   formalisation it wraps is Apache-2.0). The corpus (and its layout fixture) are kept local
   and ignored by git until the owner says whether they may be committed.
2. `corpus/blueprint-rokicki.jsonl` names its source repository (the owner's own) and commit in
   its first line; whether that may stay once this repository is public.
3. The package name `leantex`, library and namespace `LeAnTeX`, and the licence wording of
   `THIRD-PARTY.md` are the obvious defaults, not decided by the owner.
4. Lengths are TeX scaled points (2⁻¹⁶ pt = 1/655360 em) rather than 2⁻¹⁶ em: the coarser unit
   left 5e-5 em of rounding on nested scripts; scaled points leave 1.3e-5 em. Default taken.
5. The display list advances glyphs by the fonts' own widths (as browsers do), measured from
   KaTeX's fonts by `tools/gen-advances.mjs` in headless Chromium; KaTeX's metric widths differ
   by up to 5e-4 em (more for `\iint`, `\iiint`). Default taken.

## How to resume

- KaTeX 0.19.1 source: a checkout of tag `v0.19.1` (the generators take its path, default
  `$KATEX_SOURCE` or `.cache/katex-0.19.1`, which git ignores).
- Reference renderer: a built `katex.min.js` 0.19.1 (with `katex.min.css` and `fonts/` for the
  browser tools), passed to `tools/record.mjs`, `tools/check-display.mjs`,
  `tools/gen-advances.mjs`; Playwright from `$PLAYWRIGHT_MODULE`.
