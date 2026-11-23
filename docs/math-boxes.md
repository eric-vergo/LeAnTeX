# Formula boxes in documents

A formula in a paragraph or a display is material to the line breaker and boxes to the page
builder: its width, height and depth decide where lines break, how far apart they are and where
pages end. The text and document layers lay formulas out with the **TeX-rule layout**
(`LeAnTeX.TeXMath`), which follows TeX's own rules with the metrics of the fonts LaTeX uses, so
that the boxes it builds are TeX's to the sp for all but twelve of the recorded ones (*How far
apart they are*, below). The KaTeX-compatible layout (`docs/layout.md`) stays beside it for its
own use (a formula on its own, the 11,885 parity cases of `parity/REPORT.md`) and takes over
for a formula the TeX-rule layout does not build.

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

**The metric files are not part of this library.** The terms known for them: Knuth's statement
for Computer Modern (the fonts may be used freely and must not be changed under the same names;
TeX Live's catalogue calls it Knuth's licence), and the SIL Open Font License that the catalogue
names for the AMS fonts. No formal licence text accompanies the metric files in the TeX Live
installation the tests run against (its documentation tree is not installed; the METAFONT
sources say only that the fonts must not be changed under the same names). The files are not
committed: a program reads them at run time from a TeX installation
(`LeAnTeX.TeXMath.readTfmDirs`, `leantex-render --document --tfm DIR`, in the tests
`LEANTEX_TFM_DIRS`, by default the directories of `/usr/local/texlive/*`); without one,
formulas are laid out by the KaTeX-compatible layout, and `lake test` skips the comparisons
below and the baselined documents that have formulas, each with a note. The committed
recordings of TeX's output (`fixtures/math-box/`) are LuaLaTeX's typeset results for the
corpus's formulas: each formula's box and its whole node list, which holds for every character
the font, the size, the slot and the width, height and depth TeX set it at, and the kerns, glue
and boxes between them. They are the numbers any DVI or PDF file made with these fonts carries,
and for the characters the formulas use they are the metric files' own dimensions at those
sizes; they hold no ligature or kern program, no parameters and no italic corrections.

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
`parity/MATHBOX.md` with its reason; in a document every such formula is counted, and the
document's warnings give the number with the offsets and reasons of the first three, which
`leantex-render --document` prints and `parity/DOC.md` reports): `\over`, `\atop`, `\choose`
and their relatives (the tree
does not tell them from `\frac`), glue with `plus` or `minus`, arrays with rules, row gaps or
script-style cells (`smallmatrix`, `\substack`, `aligned`, `gathered`), extensible arrows,
`\overbrace`, `\overrightarrow`, `\boldsymbol`, `\notin`, `\iint` with explicit limits,
`\cong`, `\models`, `\hbar`, `\ddots`, `\varvdots`, raw boxes and rules, size commands; and a
formula past the layout's work budget (a million steps: an inline formula of some ten thousand
atoms or more). Set by the KaTeX-compatible layout, an inline formula is one box, which no line
break enters: a formula of 16,000 atoms is one line far wider than the page, with the
warning. The parser's tree cannot tell `\mkern3mu` from `\,` (nor 4mu, 5mu from `\:`, `\;`): they are read
as the glue, whose width is the same.

## How far apart they are

`tools/math-box-reference.sh` records TeX's box and whole node list for each formula of
`corpus/math-box/formulas.tsv` (2,125 formulas: the first 209 hand-picked, then systematic
families for every construct and the formulas of the reference documents,
`tools/math-box-harvest.py`) in text and display style at 10, 11 and 12 points: 12,750 boxes.
`lake test` compares the TeX-rule layout's boxes with them (`parity/MATHBOX.md`, per construct,
with the first differing node of every box that is not TeX's) and fails when a box that was
TeX's to the sp (`parity/mathbox-baseline.tsv`) no longer is.

Of the 12,750 boxes the TeX-rule layout builds 12,174, and **12,162 of those are TeX's to the
sp** in width, height and depth. The twelve it builds and misses are two formulas in both
styles at the three sizes: a radical in scriptscript style inside a superscript (1,218 or
2,435 sp in height) and `\genfrac` with `\|` delimiters in scriptscript style (TeX takes a
wider delimiter). The other 576 boxes are of formulas it refuses; the KaTeX-compatible layout
sets those, and 4 of them (two `\rule`s) come out as TeX's, so the total `lake test` prints is
12,166 of 12,750. (The KaTeX-compatible layout on its own gives TeX's box for 10 of the
12,750.) Of the 12,162 boxes the TeX-rule layout builds that are TeX's to the sp, 2,760 differ
from TeX's in some field of their lists without a difference in the box's dimensions: most in
a kern's subtype (an italic correction where TeX has an explicit kern, or the other way) or a
glue's subtype, others in the structure (LuaTeX wraps some material in boxes of its own). The
whole node list is TeX's for 9,402: every node's kind and subtype, a character's font, size
and code, every dimension, glue's stretch and shrink orders, a box's glue sign, order and
ratio (to one part in a million), as the recorder writes them (`MathBoxChecks.sameNode`).

What the figure shows: for these formulas, chosen and generated in this repository and used
while the layout was written, the boxes are LuaLaTeX's. It does not show how often a formula
from elsewhere is built and right: in the thirty held-out documents the layout refused three
formulas, and three of the documents that differ do so first at a displayed formula's width
(`parity/DOC.md`).

## Proved and tested

Proved (`LeAnTeX.TeXMath.Proofs`, axioms `propext`, `Classical.choice`, `Quot.sound` only),
each about a function the layout calls:

* The style functions (`Style.sub`, `sup`, `num`, `denom`, `cramped`, `size`):
  `Style.sub_isCramped` and `Style.denom_isCramped` (a subscript's and a denominator's style
  is cramped), `Style.sup_isCramped_of` (a cramped style's superscript is cramped),
  `Style.cramped_cramped`, `Style.size_le_sub` and `Style.size_le_num` (a script or a
  numerator is never set at a larger size than what it belongs to),
  `Style.sub_size_eq_sup_size`, `Style.sub_of_script` (the scripts of a script style are
  scriptscript).
* The spacing table as it is written here (`spacingTable`): `spacingTable_eq_two_iff` (the
  unconditional thin space stands between an operator and an ordinary atom or another
  operator, and before an operator after a closing or an inner atom, and nowhere else),
  `spacingTable_after_open` (no space after an opening atom), `spacingTable_before_close` (none
  before a closing atom except after punctuation). That these are the entries of *The
  TeXbook*'s table is a reading of the two tables side by side, and is tested through the
  boxes.
* `interAtomGlue_script`: in a script style there is glue between two atoms only where the
  table has the unconditional thin space.
* `hpack_width`, `le_hpack_height`, `le_hpack_depth`: a box packed at its natural width is as
  wide as its children together and at least as high and as deep as each of them, a box child
  counted with its shift.

Tested only: everything else, against LuaLaTeX's boxes as above; in particular that the rules
of Appendix G are followed is shown by the boxes, not proved.

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
