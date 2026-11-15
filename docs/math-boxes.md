# Formula boxes in documents

A formula in a paragraph or a display is material to the line breaker and boxes to the page
builder: its width, height and depth decide where lines break, how far apart they are and where
pages end. The text and document layers lay formulas out with the **TeX-rule layout**
(`LeAnTeX.TeXMath`), which follows TeX's own rules with the metrics of the fonts LaTeX uses, so
that the boxes are TeX's to the sp. The KaTeX-compatible layout (`docs/layout.md`) stays beside
it for its own use (the editor preview, the 11,885 parity cases of `parity/REPORT.md`) and
takes over for a formula the TeX-rule layout does not build.

## The metrics

LuaLaTeX with the `article` class sets formulas in TeX's Computer Modern math fonts, a metric
file of its own design for each size: `cmmi10`, `cmmi7` and `cmmi5` for a ten-point formula's
three sizes, `cmmi8` and `cmmi6` at eleven and twelve points, `cmsy`, `cmr` and `cmex` likewise,
`msam` and `msbm` with `amssymb`, `eufm` for `\mathfrak`, `cmmib` and `cmbsy` in the bold math
version. `LeAnTeX.TeXMath.Tfm` reads TFM files in pure Lean: the twelve lengths of the header
checked against each other and the file, every index, every step of every ligature and kern
program, every chain of larger characters and every extensible recipe, every scaled number's
form; a file that fails is an error, every query on a font read returns. Sizes are scaled as
TeX scales them (`store_scaled`), so the widths are TeX's at every size, design size or not.

**The metric files are not part of this library.** Their licences were looked for in the TeX
Live installation the tests run against: TeX Live's catalogue names Knuth's licence for the
Computer Modern fonts and the SIL Open Font License for the AMS fonts, but the installation
holds no statement of the terms beside the metric files (its documentation tree is not
installed; the METAFONT sources say only that they must not be changed under the same name).
Redistribution of data derived from them is not clearly allowed by what is there, so nothing
derived from the metric files is committed: a program reads them at run time from a TeX
installation (`LeAnTeX.TeXMath.readTfmDirs`, `leantex-render --tfm DIR`, by default the
directories of `/usr/local/texlive/*`); without one, formulas are laid out by the
KaTeX-compatible layout and the comparisons below are skipped with a note. The committed
recordings of TeX's output (`fixtures/math-box/`, the boxes and node lists TeX made) are TeX's
typeset results, as the document fixtures are.

The OpenType text fonts are a family of their own in LaTeX's setup with `fontspec`: `\mathrm`,
`\operatorname`, `\mathbf`, `\mathit`, `\mathsf`, `\mathtt` and `\text` use New Computer Modern,
measured as luaotfload measures it (advances, glyph boxes, and the italic correction of a
slanted font: the part of the outline right of the advance plus a fiftieth of the em, when that
is positive).

## The rules

`LeAnTeX.TeXMath.mlistToHlist` is TeX's conversion of a math list into boxes, implemented from
*The TeXbook*'s Appendix G (rules 1–22) and the algorithm *TeX: The Program* documents
(§699–§767): styles and cramped styles; atoms of the eight classes with rules 5 and 6; the
inter-atom spacing table of Chapter 18 with `\thinmuskip`, `\medmuskip` and `\thickmuskip`,
suppressed in script styles where the table says; characters with their italic corrections and
rule 14's ligatures and kerns; superscripts and subscripts with all of rule 18's clearances and
`\scriptspace`; generalised fractions with and without a rule (rule 15) and their delimiters;
radicals (rule 11); large operators with limits, `\limits` and `\nolimits` (rule 13); accents
with the skew of the skew character and the largest variant not wider than the nucleus (rule
12); `\overline`, `\underline`, `\vcenter`; `\left`, `\middle` and `\right` sized with
`\delimiterfactor` and `\delimitershortfall` by TeX's delimiter search, extensible delimiters
from their recipes; `\mathchoice`; mu glue and kerns, `\nonscript`; and in a paragraph's
formula the penalties after relations and binary operations (`\relpenalty`, `\binoppenalty`).
Every length is integer sp and every division rounds as TeX's (`half`, `x_over_n`,
`xn_over_d`, `nx_plus_y`).

The boxes are LuaTeX's, and LuaTeX differs from TeX82 in a few places, all found against its
lists and followed here:

1. A delimiter of `\left`, `\right` or a radical is looked for at the current size only; TeX82
   goes on to the larger sizes (§707). A fraction's delimiters are looked for down to text
   size, as in TeX82.
2. A delimiter is centred on the axis of the size it was found at.
3. An extensible delimiter's box has its whole size as height (TeX82: the top piece's height,
   the rest as depth); it is centred afterwards either way.
4. `\left.` and `\right.` give an empty box that is not shifted.
5. An accent over a nucleus that is not a single character is placed 1 sp further right.

Everything the layout reads is bounded: the nesting of lists inside lists (400 levels) and a
work budget over every step (an atom set, a delimiter variant looked at, an extensible piece, a
ligature applied); past either the result is an error, never a hang.

## The front end

The parser's tree (KaTeX's) is turned into the math list TeX builds for the same source in
LaTeX with amsmath and amssymb (`LeAnTeX.TeXMath.toMathList`). Each symbol takes the math code
LaTeX gives it, recorded from LuaLaTeX (`tools/math-codes.sh`, `fixtures/math-codes/codes.tsv`,
the table `LeAnTeX/TeXMath/Data/MathCodes.lean`): its class, family and slot; a letter or digit
(class 7) takes the family of the alphabet around it. The commands are built as LaTeX's and
amsmath's macros build them, read from their sources and checked against the recordings:

* groups as ordinary atoms, a group of one ordinary atom without scripts reduced to that atom's
  nucleus (§1186); scripts on the atom before them;
* `\frac`, `\dfrac`, `\tfrac`, `\binom`, `\genfrac` inside amsmath's groups; `\sqrt` as
  `\radical"270370`, `\sqrt[n]` as amsmath's `\root` (`\mathpalette`, the index raised by 0.6
  of the radical's height less depth, `\mkern5mu` before and `\mkern-10mu` after);
* large operators with amsmath's limits (`\displaylimits` for sums, `\nolimits` for integrals),
  `\iint`, `\iiint`, `\iiiint` as amsmath's `\MultiIntegral`; `\lim`, `\max`, `\sin` and the
  other named operators, `\operatorname` and `\operatorname*` as amsmath's `\qopname`;
* `\bigl` … `\Biggr` as amsmath's `\bBigg@` (a `\left…\right.` around a `\vcenter` of 1, 1.5,
  2 or 2.5 times 1.2 the height plus 1.2 the depth of `(`);
* `\widehat` and `\widetilde` choosing the `msbm` accent for a nucleus wider than 2em;
* `\text`, `\textrm`, `\textbf`, `\textit`, `\mbox`, `\hbox` with the text font at the size of
  the style, shaped by the text layer's font;
* `\ldots`, `\cdots` and amsmath's `\dots`, `\dotsc`, `\dotsb`, … with amsmath's thin space
  after them before punctuation, a closing delimiter or the end of the formula;
* `\ne`, `\neq`, `\not` as `\not`'s slash before the relation; `\mapsto`, `\longrightarrow`,
  `\Longrightarrow`, `\iff`, `\implies`, `\hookrightarrow` and their relatives from their
  pieces with `\joinrel`;
* `\pmod`, `\pod`, `\mod` with amsmath's spaces (18mu in a displayed formula);
* matrices (`matrix`, `pmatrix`, `bmatrix`, `Bmatrix`, `vmatrix`, `Vmatrix`), `cases` and
  `array` with `l`, `c`, `r` columns as LaTeX's `\@array` sets them in a `\vcenter`;
* spacing commands, styles, `\mathchoice`, `\mathord` … `\mathinner`, colours, phantoms,
  `\smash`.

Refused, and laid out by the KaTeX-compatible layout instead (each listed in
`parity/MATHBOX.md` with its reason): `\over`, `\atop`, `\choose` and their relatives (the tree
does not tell them from `\frac`), glue with `plus` or `minus`, arrays with rules, row gaps or
script-style cells (`smallmatrix`, `\substack`, `aligned`, `gathered`), extensible arrows,
`\overbrace`, `\overrightarrow`, `\boldsymbol`, `\notin`, `\iint` with explicit limits,
`\cong`, `\models`, `\hbar`, `\ddots`, `\varvdots`, raw boxes and rules, size commands. The
parser's tree cannot tell `\mkern3mu` from `\,` (nor 4mu, 5mu from `\:`, `\;`): they are read
as the glue, whose width is the same.

## How far apart they are

`tools/math-box-reference.sh` records TeX's box and whole node list for each formula of
`corpus/math-box/formulas.tsv` (2,125 formulas: the first 209 hand-picked, then systematic
families for every construct and the formulas of the reference documents,
`tools/math-box-harvest.py`) in text and display style at 10, 11 and 12 points: 12,750 boxes.
`lake test` compares the TeX-rule layout's boxes with them (`parity/MATHBOX.md`, per construct,
with the first differing node of every box that is not TeX's) and fails when a box that was
TeX's to the sp (`parity/mathbox-baseline.tsv`) no longer is.

At the time of writing: **12,166 of 12,750 boxes are TeX's to the sp** in width, height and
depth (the KaTeX-compatible layout: 10 of them); of the 12,174 the TeX-rule layout builds,
12,166, and 576 boxes are of formulas it refuses. The eight it builds and misses are a
radical in scriptscript style inside a superscript (1,218 or 2,435 sp in height) and
`\genfrac` with `\|` delimiters in scriptscript style (TeX takes a wider delimiter). Of the
boxes TeX's to the sp, a few hundred differ from TeX's in the structure of their lists (LuaTeX
wraps some material in boxes of its own) without a difference in any dimension.

## Drawing

The Computer Modern metric files have no outlines here. A character of a metric font is drawn
with the glyph of New Computer Modern Math (`NewCMMath-Book.otf`, committed under the GUST Font
License) that shows the same symbol, at the position and size TeX's metrics give it
(`LeAnTeX.TeXMath.Data.Glyphs`: every slot of the fonts' encodings to its Unicode character);
a `cmex` size variant is drawn through the back ends' `Size1`–`Size4` faces, which pick the
math font's `MATH` variant, centred on TeX's box. The positions are TeX's; the shapes are New
Computer Modern's, which follow Computer Modern closely; differences show in the script sizes
(New Computer Modern scales one design where TeX has a design per size) and in a few symbols
(the bar of `\mapsto` and the hooks of `\hookrightarrow` are pieces without a Unicode
character and are not drawn). Against LuaLaTeX's rendering of the math reference documents
(`tools/doc-render-compare.sh`): math-display 4.3 levels mean difference at the page top, 1.6
at the bottom, 97–99 % of pixels within 32 levels; the KaTeX-compatible drawing of the same
pages scores the same within 0.3 levels, the difference being in the glyph shapes, not the
positions.
