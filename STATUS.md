# Status

What LeAnTeX does today, and what comes next.

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
  numbers written out; `DisplayOptions.fallbackAdvance` takes a back end's advances for
  characters a face does not have (the font that draws them in their place), as a browser lays
  them out. Placement trees (`Placed`) instead of copying items at every level.
  Invariants checked on every formula and 26 feature checks (`LeAnTeXTest/DisplayChecks.lean`)
  by `lake test`.
- Display list against Chromium (`tools/check-display.mjs`, 11,100 formulas, 49,234 glyphs,
  719 rules, 648 SVG images): no count, face or character differs; glyph x within 0.0049 em
  (99 % within 0.0003), baseline within 0.0002 em, rules and SVG viewports within 0.01 em
  (one-pixel least width of array rules, pixel rounding of borders).
- Settings: KaTeX's `maxSize` (`Settings.maxSize`, in em; `none` by default, as KaTeX's
  `Infinity`): every size a formula writes is cut to it in `calculateSize`, as in KaTeX. LeAnTeX's
  own `maxTokens` (20000 by default, `defaultMaxTokens`; KaTeX has no such limit) bounds the
  tokens all macro expansions produce together, an error past it, so a formula's cost stays
  linear in its source.
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
- Text-mode reference (`docs/text-reference.md`): `tools/tex-reference.sh` records LuaLaTeX's
  answers for 174 paragraphs (item lists, breaks, line glue and shifts, demerits), 1,691 words
  (hyphenation points) and 80 boxes into `fixtures/text/`; `lake test` keeps them coherent.
- Text mode (`LeAnTeX/Text*`, `docs/text.md`): Liang hyphenation with plain TeX's patterns,
  TeX's line breaker, a LaTeX front end (paragraphs, spacing, fonts and sizes, boxes, formulas
  through the math layout, macros) and the lines as a display list. Against LuaLaTeX: all 2,686
  hyphenation points of the 1,691 words; for all 174 paragraphs the breaks, total demerits, line
  lengths, natural widths and glue settings from TeX's item lists; and the front end gives TeX's
  item lists, lines and paragraph boxes from the corpus source. Theorems: legal and increasing
  breaks, the lines' nodes are the input's without the dropped ones, hyphen minima, the badness
  bound. `lake exe leantex-typeset` with goldens in `fixtures/typeset/`.
- OpenType reader (`LeAnTeX/OpenType*`, `docs/opentype.md`): every table listed there; outlines
  as `LeAnTeX.Path Int` and as display-list path items. Checked against fontTools on every glyph
  of fifteen Latin Modern fonts (when TeX Live is installed) and two committed test fonts, against
  TeX's 72 comparable boxes (glyphs, ligatures, widths, kerns), and by 1,200 mutated fonts per
  run.
- Fonts (`fonts/`, `fonts/README.md`): the 29 files of New Computer Modern 8.1.1 under the GUST
  Font License, unmodified, with the package's `README` and `License.txt` and a manifest of sizes,
  SHA-256 and licences that `lake test` checks; the files under the GPL (`NewCM10-Regular`,
  Uncial, Devanagari) are not in the repository. The text layer chooses them as the package's
  `fontspec` files do (Book weight, 8-point designs up to 8 points, slant and small capitals),
  and with them gives LuaLaTeX's lists, lines and boxes for all 174 paragraphs
  (`fixtures/text/paragraphs-ncm.jsonl`). The reader takes a font's PANOSE proportion for
  monospace, as luaotfload does, and the `MATH` table's size variants.
- Back ends (`LeAnTeX/Backend*`, `docs/back-ends.md`): SVG with glyphs as outlines defined once,
  HTML with text runs at TeX's positions in the web fonts and formulas as inline SVG;
  `leantex-render`; `examples/` (three samples as source, SVG and HTML) checked byte for byte; 21
  named checks; escaping and glyph references proved. Against LuaLaTeX's rendering
  (`tools/tex-render-compare.sh`): text within 9.4 levels on average, 89.7 % of pixels within 32
  levels; formulas within one to three pixels at 4 pixels to the point.
- Gates: `lake build --wfail` and `lake test` green; a Lean style checker (100 columns,
  headers, naming) run read-only on this tree: 0 violations.

- Documents (`LeAnTeX/Doc*`, `docs/documents.md`): `\documentclass{article}` with its size and
  paper options; vertical lists with TeX's interline glue and penalties, TeX's page builder with
  insertions, LaTeX's output routine (footnotes, top, bottom, here and page floats, deferral,
  `\clearpage`), headings, the table of contents, counters, labels and references resolved in
  repeated passes inside the engine, lists, quotations, centring, verbatim, theorems and
  proofs, equations with amsmath's `\tag`, amsmath's alignments row by row, accents, rules,
  lengths, the title and abstract, `tabular`, `\includegraphics` of PNG and SVG,
  bibliographies (`thebibliography`, `\bibitem`, `\cite`). Against LuaLaTeX
  (`tools/doc-reference.sh`, `parity/DOC.md`), line by line to the sp: the 87 reference and
  regression documents all agree, 1,810 of 1,810 lines; ten fresh documents written without
  reading the source 7 agree, 367 of 398 lines; **twenty held-out documents, written without
  reading the source and not tuned to: 9 agree in full, 398 of 469 lines at the place to the
  sp, 405 within 1 pt, page breaks 3 of 3** (before the TeX-rule layout: none, 190 and 355);
  a second held-out set of ten, written blind after the first was run and a defect it showed
  was fixed: 5 agree, 374 of 400 lines, 375 within 1 pt, page breaks 10 of 10.
  List parameters probed against LuaLaTeX at every level for three sizes
  (`tools/list-params.sh`). Paged SVG and HTML (`leantex-render --document`),
  `examples/article/`. Theorems: the pages hold the vertical list's boxes, counters,
  references, image paths. 582 mutated documents end cleanly.
- TeX-rule math layout (`LeAnTeX/TeXMath*`, `docs/math-boxes.md`): a TFM reader in pure Lean
  (checked as TeX checks a file, scaled as TeX scales it, fuzzed), TeX's Appendix G with TeX's
  rounding and LuaTeX's five differences, LaTeX's math codes recorded from LuaLaTeX, the
  commands built as LaTeX and amsmath build them, LaTeX's font setup for every size. The
  metric files are read at run time from a TeX installation (none is committed); without one
  formulas fall back to the KaTeX-compatible layout. Against LuaLaTeX (`parity/MATHBOX.md`):
  12,166 of 12,750 formula boxes to the sp (12,166 of the 12,174 it builds); `lake test` fails
  if a box that was TeX's no longer is. Inline formulas break after relations and binary
  operations as in TeX; glyphs drawn with New Computer Modern Math at TeX's positions.
  Theorems: the style lattice, the spacing table's totality and its script-style rule,
  `hpack` containing its children.

## Next

1. The constructs the TeX-rule layout refuses (`docs/math-boxes.md`): `\over` and its
   relatives (the parser's tree would have to keep them apart), arrays with rules and script
   cells, extensible arrows and braces, `\boldsymbol`, `\notin`; amsmath's `\intertext`,
   `split`, `alignat`, and a number that does not fit beside its row.
2. The held-out documents' remaining causes (`docs/documents.md`): the title block in some
   documents, `--` in bold headings, text accents, line breaks in a few paragraphs.
3. Speed: the parser's macro and symbol lookups dominate parsing; in the display list, class
   tests (`Box.hasClass`) and style lookups.

## Choices made

1. Dashed rules use LeAnTeX's own dash pattern (dashes three times the thickness, gaps at least
   twice); browsers each have theirs.
2. Lengths are TeX scaled points (2⁻¹⁶ pt = 1/655360 em); the display list advances glyphs by
   the fonts' own widths.
3. The layout fixtures (`fixtures/layout/`), the text fixtures (`fixtures/text/`) and the
   fontTools references (`fixtures/font/`) are committed, so that `lake test` needs neither KaTeX
   nor TeX; the Latin Modern fonts are not (the tests read them from TeX Live when present).
4. Contour starts of TrueType glyphs follow fontTools (the first on-curve point).

## Reference tools

- KaTeX 0.19.1 source: a checkout of tag `v0.19.1` (the generators take its path, default
  `$KATEX_SOURCE` or `.cache/katex-0.19.1`, which git ignores).
- Reference renderer: a built `katex.min.js` 0.19.1 (with `katex.min.css` and `fonts/` for the
  browser tools), passed to `tools/record.mjs`, `tools/check-display.mjs`,
  `tools/gen-advances.mjs`; Playwright from `$PLAYWRIGHT_MODULE`.
- Browser check: `lake exe leantex-display CORPUS… > dump.jsonl`, then
  `node tools/check-display.mjs KATEX_DIST dump.jsonl` (`--detail ID` for one case).
