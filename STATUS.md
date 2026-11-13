# Status

Resume notes for the work in progress. Updated after every step.

## State

- Parser (done): 12,272 of 12,272 corpus cases match KaTeX 0.19.1 (trees, errors, warnings).
- Layout core (done for the constructs below; `docs/layout.md`):
  - `LeAnTeX/Layout/Em.lean`: lengths as integer scaled points (2⁻¹⁶ pt, 1/655360 em).
  - Generated tables: `LeAnTeX/Data/FontMetrics.lean`, `FontParams.lean`, `SvgPaths.lean`
    (`tools/gen-layout-tables.mjs`, from KaTeX's source), `FontAdvances.lean`
    (`tools/gen-advances.mjs`, from KaTeX's fonts in headless Chromium).
  - Box tree (`Layout/Box.lean`, KaTeX's `domTree`), `Options`, `buildCommon`
    (`Layout/Common.lean`), `buildExpression` with spacing (`Layout/Html.lean`), delimiters
    (`Layout/Delimiter.lean`), stretchy images (`Layout/Stretchy.lean`), builders
    (`Layout/Builders/`), `buildHTML` and the entry point `layout` (`Layout/Build.lean`).
  - Display list (`Layout/Display.lean`, `docs/display-list.md`): glyphs, rules, paths,
    regions, parts, lines; invariants checked on every formula by `lake test`.
  - Laid out: symbols of every kind and font, spacing, groups, styles, sizes, math and text
    fonts, `\text…`, classes, colour, kerns, scripts, large operators and limits,
    `\operatorname`, fractions and generalised fractions, sized delimiters, `\left…\right`,
    `\middle`, accents (with scripts), under-accents, wide accents, `\sqrt`, phantoms, smash,
    laps, rules, over/underline, raisebox, vcenter, mathchoice, hbox, pmb, verb, reflectbox,
    `\html…`, href, images, line breaks.
  - Not yet (the next stage): arrays and environments, `\xrightarrow` and friends, enclosures
    (`\boxed`, `\cancel`, …), horizontal braces, `{CD}`.
- Layout parity (`parity/LAYOUT.md`): 10,868 of 12,272 cases identical to KaTeX, 0 differ,
  374 not yet in scope, 1,030 rejected by both. Largest deviation 1.3e-5 em.
- Display list against Chromium (`tools/check-display.mjs`, 10,721 formulas): glyph x within
  0.002 em (99 % within 0.0004), baseline within 0.0002 em, width within 0.002 em, SVG
  viewports within 0.0006 em, rules within 0.0025 em (border pixel snapping at 400 px).
- Speed (`lake exe leantex-test --bench`): 45,000 formulas/s parse + layout over all corpora,
  28,000/s with the display list; per corpus from 5,200/s (blueprint formulas with macro
  preludes, mostly parsing) to 53,000/s; slowest formula about 0.55 ms.
- Gates: `lake build --wfail` and `lake test` green; IDEiL's style checker run read-only with
  `--root` on this tree: 0 violations.

## Next

1. Layout rest: arrays and environments, extensible arrows, enclosures, braces, `{CD}`.
2. Possible speed-ups if a back end needs them: metric lookups keyed by font index instead of
   name, the spacing walk.

## Open questions for the owner

1. The Noperthedron blueprint corpus: the blueprint repository states no licence (the
   formalisation it wraps is Apache-2.0). The corpus (and its two fixtures) are kept local and
   ignored by git until the owner says whether they may be committed.
2. `corpus/blueprint-rokicki.jsonl` names its source repository (the owner's own) and commit in
   its first line; whether that may stay once this repository is public.
3. The package name `leantex`, library and namespace `LeAnTeX`, and the licence wording of
   `THIRD-PARTY.md` are the obvious defaults, not decided by the owner.
4. Lengths are TeX scaled points (2⁻¹⁶ pt = 1/655360 em) rather than 2⁻¹⁶ em: the coarser unit
   left 5e-5 em of rounding on nested scripts; scaled points leave 1.3e-5 em. Default taken.
5. The display list advances glyphs by the fonts' own widths (as browsers do), measured from
   KaTeX's fonts by `tools/gen-advances.mjs` in headless Chromium; KaTeX's metric widths differ
   by up to 5e-4 em (more for `\iint`, `\iiint`). Default taken.
6. KaTeX's font files state the SIL Open Font License 1.1 (Design Science and Khan Academy,
   Reserved Font Names `KaTeX_*`), not MIT. LeAnTeX ships no font; `FontAdvances.lean` holds
   advance widths measured from them, recorded with the OFL notice in `THIRD-PARTY.md`.
   Whether that table is acceptable as is (default) or should come from KaTeX's MIT metric
   tables only.
7. The layout fixtures (`fixtures/layout/`, about 13 MB) are committed so that `lake test`
   needs no KaTeX; alternatively they could be regenerated on demand. Default: committed.

## How to resume

- KaTeX 0.19.1 source: a checkout of tag `v0.19.1` (the generators take its path, default
  `$KATEX_SOURCE` or `.cache/katex-0.19.1`, which git ignores).
- Reference renderer: a built `katex.min.js` 0.19.1 (with `katex.min.css` and `fonts/` for the
  browser tools), passed to `tools/record.mjs`, `tools/check-display.mjs`,
  `tools/gen-advances.mjs`; Playwright from `$PLAYWRIGHT_MODULE`.
