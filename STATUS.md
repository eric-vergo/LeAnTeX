# Status

Resume notes for the work in progress. Updated after every step.

## State

- Parser (done): 12,272 of 12,272 corpus cases match KaTeX 0.19.1 (trees, errors, warnings).
- Layout (done, `docs/layout.md`): every parse node type KaTeX builds is laid out, arrays and
  environments (`Layout/Builders/Array.lean`), `{CD}`, enclosures, extensible arrows and
  horizontal braces (`Layout/Builders/Enclose.lean`) included.
- Layout parity (`parity/LAYOUT.md`): 11,242 of 12,272 cases identical to KaTeX, 0 differ,
  none out of scope, 1,030 rejected by both. Largest deviation 1.3e-5 em.
- Display list (`Layout/Display.lean`, `docs/display-list.md`): glyphs, rules (dashed rules as
  runs of dashes, box borders and backgrounds), paths (strokes of `\cancel` as outlines),
  regions, parts, lines; mirrored ranges for `\reflectbox`; `DisplayOptions` (line width for
  display mode: centring and the tag at the end of the line; first equation number); equation
  numbers written out. Placement trees (`Placed`) instead of copying items at every level.
  Invariants checked on every formula and 19 feature checks (`LeAnTeXTest/DisplayChecks.lean`)
  by `lake test`.
- Display list against Chromium (`tools/check-display.mjs`, 11,100 formulas, 49,234 glyphs,
  719 rules, 648 SVG images): no count, face or character differs; glyph x within 0.0049 em
  (99 % within 0.0003), baseline within 0.0002 em, rules and SVG viewports within 0.01 em
  (one-pixel least width of array rules, pixel rounding of borders).
- Box tree JSON (`Layout/BoxJson.lean`): total, by well-founded recursion. `partial` remains in
  the parse stage, `Json.lean` and `Parse/NodeJson.lean` (`docs/layout.md`, *Termination*).
- Speed, 10 × 10 matrix (`lake exe leantex-test --bench-matrix`), in processor cycles on one
  core of an Apple M2 Ultra under a load average of about 75 (wall-clock times were not
  usable): parse 2.4 M cycles, parse + layout 4.7 M, display list 3.6 M; about 0.7 ms, 1.3 ms
  and 1.0 ms at 3.5 GHz. The budget of 1 ms for laying out this formula is met by the layout
  alone (about 0.6 ms) but not with parsing included. To re-measure on a quiet machine.
- Notices: every module derived from KaTeX names its sources under *References* and has a row
  in `THIRD-PARTY.md`; `LICENSE-KaTeX` holds KaTeX's MIT notice; the font-advance table states
  the fonts' SIL Open Font License 1.1 (Reserved Font Names `KaTeX_*`).
- Gates: `lake build --wfail` and `lake test` green; a Lean style checker (100 columns,
  headers, naming) run read-only on this tree: 0 violations.

## Next

1. Back ends (outside this repository's layout work).
2. Speed: the parser's macro and symbol lookups dominate parsing; in the display list, class
   tests (`Box.hasClass`) and style lookups.

## Open questions for the owner

1. The Apache `LICENSE` file had the appendix's copyright template filled in with a name; it
   was restored to the template (`Copyright [yyyy] [name of copyright owner]`), following the
   preference for no copyright lines. Default taken.
2. Dashed rules: LeAnTeX's own dash pattern (dashes three times the thickness, gaps at least
   twice); browsers each have theirs. Default taken.
3. Lengths are TeX scaled points (2⁻¹⁶ pt = 1/655360 em) rather than 2⁻¹⁶ em; the display list
   advances glyphs by the fonts' own widths. Defaults taken earlier.
4. The layout fixtures (`fixtures/layout/`, about 13 MB) are committed so that `lake test`
   needs no KaTeX. Default: committed.

Decided: package `leantex`, namespace `LeAnTeX`; the Noperthedron corpus stays local and
ignored by git; the Rokicki corpus keeps its attribution line.

## How to resume

- KaTeX 0.19.1 source: a checkout of tag `v0.19.1` (the generators take its path, default
  `$KATEX_SOURCE` or `.cache/katex-0.19.1`, which git ignores).
- Reference renderer: a built `katex.min.js` 0.19.1 (with `katex.min.css` and `fonts/` for the
  browser tools), passed to `tools/record.mjs`, `tools/check-display.mjs`,
  `tools/gen-advances.mjs`; Playwright from `$PLAYWRIGHT_MODULE`.
- Browser check: `lake exe leantex-display CORPUS… > dump.jsonl`, then
  `node tools/check-display.mjs KATEX_DIST dump.jsonl` (`--detail ID` for one case).
