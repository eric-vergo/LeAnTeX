# Formula boxes in documents

A formula in a paragraph or a display is one box to the line breaker and the page builder: its
width, height and depth decide where lines break, how far apart they are and where pages end.
This page says where those boxes come from today, how far they are from TeX's, and how the
document layer is to get TeX's boxes.

## Where the boxes come from today

The text and document layers lay formulas out with the math layout (`docs/layout.md`), which
reproduces KaTeX 0.19.1: KaTeX's rules and KaTeX's font metrics (the metrics of the KaTeX fonts,
taken from Computer Modern at its ten-point design and scaled for every size). The box of the
whole formula is scaled to the current font size (`LeAnTeX.Text.Typeset.formula`).

TeX, in the LuaLaTeX setup the document fixtures are recorded with (New Computer Modern text,
TeX's default math fonts), sets a formula from the metric files of the Computer Modern math
fonts, with a font of its own design for each of the three sizes (`cmmi10`, `cmmi7`, `cmmi5`
and their symbol, extension and roman fonts at ten points), and with the rules of *The TeXbook*,
Appendix G.

## How far apart they are

`tools/math-box-reference.sh` records TeX's box (width, height and depth) for each of the 209
formulas of `corpus/math-box/formulas.tsv`, in text and in display style (418 boxes, in
`fixtures/math-box/boxes.tsv`); `lake test` compares the math layout's boxes with them and
writes the agreement per construct to `parity/MATHBOX.md`. The comparison is reported, never
required.

At the time of writing: no box is TeX's to the sp, 214 of 418 are within 0.1 pt in all three
dimensions and 339 within 1 pt. The differences have three sources, in order of size:

1. **Script sizes.** TeX sets a superscript or subscript in the seven-point fonts (and a
   second level in the five-point fonts), whose letters are wider and heavier than the
   ten-point ones scaled down; KaTeX scales the ten-point metrics. `x^2` is 0.48 pt narrower
   here than in TeX.
2. **`\scriptspace` and other TeX rules KaTeX leaves out or changes**: the 0.5 pt after a
   script, the italic correction at the end of a formula, the limits of a text-style `\sum`,
   the placement of fractions and radicals from the fonts' parameters (`\fontdimen` of `cmsy`
   and `cmex`).
3. **Rounding.** KaTeX's metrics are rounded to five decimals of an em; TeX scales the metric
   files' values exactly. A letter is up to 725 sp off, a line's depth 1 sp.

These are the largest remaining cause of disagreement in the documents written without reading
this library (`parity/DOC.md`): a paragraph whose formulas are a little wider breaks a word
earlier, and a page whose lines are a little taller is set with other glue.

## What the document layer needs

The boxes the paragraph and page see must be TeX's, while the KaTeX-compatible layout remains
for its own use (the editor preview, the 11,885 parity cases of `parity/REPORT.md`). Two ways
were weighed:

* **Correcting the outer box** of the KaTeX layout to TeX's size. Rejected: the outer box is
  the sum of the inner ones, the error is spread through the formula (every script, every
  fraction), and a corrected outer box would no longer contain what the display list draws.
* **A second layout that follows TeX's rules** for documents, the KaTeX one kept beside it.
  Chosen. It takes the parse tree the parser already makes, and builds boxes as Appendix G of
  *The TeXbook* builds them (styles, atoms and their spacing, scripts with the `\fontdimen`
  parameters σ and ξ, limits, fractions, radicals, delimiters, accents, `\left`/`\right`, the
  spacing table) from the metric files of the fonts LaTeX uses for each size. The display list
  of such a box is drawn with the same glyph and rule items as today.

What it needs that the library does not have yet:

1. The Computer Modern math metrics for the sizes LaTeX loads (`cmr`, `cmmi`, `cmsy` at 5, 7
   and 10 points, `cmex10`, and `msam`/`msbm` for `amssymb`): widths, heights, depths, italic
   corrections, kerns and ligatures, extensible recipes, and the `\fontdimen` parameters,
   generated into a data module from the metric files with a notice for their licences (Knuth's
   for Computer Modern, the SIL Open Font License for the AMS fonts).
2. The layout itself, in the order the corpus shows the differences: characters and spacing,
   scripts, operators and limits, fractions, radicals, delimiters, accents, arrays.
3. The text and document layers calling it, and `parity/MATHBOX.md` as its measure: the target
   is every box of the corpus to the sp.

The recording harness and the per-construct report are in place; the second layout is not
written yet.
