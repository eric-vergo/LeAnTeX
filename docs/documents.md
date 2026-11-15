# Documents

LeAnTeX's document layer typesets whole LaTeX documents of the `article` class into pages, as
LaTeX does: TeX's vertical lists and page builder, LaTeX's output routine with its floats and
footnotes, sectioning, counters, cross-references, the table of contents, lists, theorems,
tables and figures. It is checked against LuaLaTeX on a corpus of 74 documents, line by line, to
the scaled point.

```lean
import LeAnTeX
open LeAnTeX.Doc

match typesetDocument src resolver { images := fun path => myImages[path]? } with
| .ok doc => doc.pages            -- each page: its boxes, where everything goes, its number
| .error e => …                    -- e.message, e.pos (character offset in the source)
```

```
lake exe leantex-render --document [--external-css] article.tex OUTDIR
```

writes `page-N.svg` per page, `document.svg` (every page in one picture), `document.html` (the
pages as sheets) and `web.html` (one continuous page, no page breaks, floats where they are
given). `examples/article/article.tex` and `examples/article/` show the result.

## What a document can use

* **Class**: `\documentclass[10pt|11pt|12pt, letterpaper|a4paper]{article}` (one-sided, one
  column; `twocolumn` is an error); the class's page layout, sizes and spacing for each option,
  taken from LuaLaTeX (`fixtures/doc/class/`). Packages: `amsmath`, `amssymb`, `amsthm`,
  `graphicx` change what they change here; others are reported and ignored.
* **Structure**: `\title`, `\author` (`\and`), `\date` (`\today` is `Settings.today`: output never
  depends on the clock), `\thanks`, `\maketitle`; `abstract`; `\section` … `\subparagraph` with
  starred forms and an optional short title, numbered to the third level; `\tableofcontents`.
* **Counters**: `\newcounter{x}[y]`, `\setcounter`, `\addtocounter`, `\stepcounter`,
  `\refstepcounter`, `\value`, `\the\value`, `\the<x>` (redefinable), `\arabic`, `\roman`,
  `\Roman`, `\alph`, `\Alph`, `\fnsymbol`.
* **References**: `\label`, `\ref`, `\pageref`, `\eqref`, resolved by repeated passes inside the
  engine (no auxiliary files): the front end runs until labels and contents stop changing, at
  most four times. An undefined reference prints a bold `??` and is reported in the warnings.
* **Lengths**: `\newlength`, `\setlength`, `\addtolength` of user lengths and of the layout's
  (`\parindent`, `\parskip`, `\textwidth`, `\baselineskip`, …).
* **Lists**: `itemize`, `enumerate`, `description` nested to six levels in all, `itemize` and `enumerate` to four each (counted apart, as LaTeX counts them), with the class's labels
  and indents; `\item[label]`.
* **Environments**: `quote`, `quotation`, `center`, `flushleft`, `flushright`, `\centering`,
  `\raggedright`, `\raggedleft`, `verbatim`, `\verb`, `\newenvironment`, `\renewenvironment`,
  `\newtheorem` (kernel and `amsthm` styles `plain`, `definition`, `remark`), `proof` with its end
  mark, `equation`, `equation*`, `displaymath`, `\[ \]`, `align`, `gather`, `multline` (see
  below).
* **Text**: everything the text layer sets (`docs/text.md`), `\footnote`, `\emph` nesting,
  accents `\'` `` \` `` `\^` `\"` `\~` `\=` `\.` `\u` `\v` `\H` `\c` `\r` `\k` (composed through the
  font when it has the character, else built as TeX's `\accent` builds it), `\i`, `\j`, `\aa`,
  `\ae`, `\oe`, `\o`, `\ss`, `\l` and their capitals, `\rule`, `\hrule`, `\vrule`.
* **Tables**: `tabular` with `l`, `c`, `r`, `p{w}`, `|`, `@{}`, `\hline`, `\multicolumn`, `\\[d]`,
  positions `[t]`, `[c]`, `[b]`.
* **Floats**: `figure`, `table` (and starred) with `[htbp]`, `\caption`; `\includegraphics` of PNG
  and SVG files with `width`, `height`, `scale`.
* **Line breaks**: `\linebreak[n]`, `\nolinebreak[n]` (LaTeX's penalties), `\newline`, `\\`.
* **Bibliographies**: `thebibliography{widest}` (an unnumbered section "References" and a list
  whose labels are as wide as `[widest]`, set `\sloppy`, with `\clubpenalty` and
  `\widowpenalty` 4000 and no extra space after a full stop), `\bibitem{key}` (numbered) and
  `\bibitem[label]{key}` (the label flush left), `\cite{key}`, `\cite{a,b}` (`[1, 2]`, the keys
  apart by `,\penalty1000\ `) and `\cite[note]{key}` (`[1, note]`); citations are resolved in the
  same passes as labels; an unknown key prints a bold `?` and is reported. No BibTeX.
* **Pages**: `\newpage`, `\clearpage`, `\pagebreak[n]`, `\nopagebreak[n]`, `\vfill`, `\vskip`,
  `\vspace`, `\smallskip`, `\medskip`, `\bigskip`, `\addvspace`; `\pagestyle` and
  `\thispagestyle` with `plain` (centred page number in the foot) and `empty`.

## How it works

* **Vertical lists** (`LeAnTeX.Doc.VList`): the front end builds TeX's main vertical list: lines
  with their interline glue (`\baselineskip`, `\lineskip`, `\lineskiplimit`), `\parskip`, the
  penalties between lines (`\interlinepenalty`, `\clubpenalty`, `\widowpenalty`,
  `\displaywidowpenalty`, `\brokenpenalty`), displays with TeX's skips (the short ones when the
  formula starts right of `\predisplaysize`), and material made inside a line (labels,
  footnotes, floats, `\vspace`) after that line, as TeX moves it.
* **The page builder** (`LeAnTeX.Doc.PageBuilder`) is TeX's (*TeX: The Program* §980–§1028):
  breakpoints, the cost from badness, penalties and insertion penalties, `\topskip`, `\maxdepth`,
  insertions with `\skip`, `\count`, `\dimen`, split by TeX's `vert_break` when they do not fit.
  Before returning, it checks that the pages hold the list's boxes, each once, in order
  (`buildPages_boxes`).
* **The output routine** (`LeAnTeX.Doc.Output`): LaTeX's `\@makecol` and `\@outputpage` for one
  column: footnotes below `\skip\footins` and the footnote rule; top and bottom floats with
  `\floatsep` and `\textfloatsep`; pages of floats with `\@fptop`, `\@fpsep`, `\@fpbot`; the
  column packed to `\textheight` with `\raggedbottom`'s glue; the head and foot at their places.
* **Floats** follow LaTeX's documented placement (`\@addtocurcol`, `\@startcolumn`,
  `\@tryfcolumn`, `\@doclearpage`): here (`h`, when the page has room for it with `\intextsep`),
  top (`t`, within `topnumber` and `\topfraction`), bottom (`b`, within `bottomnumber` and
  `\bottomfraction`), with `\textfraction` of text left and `totalnumber` floats at most; else
  deferred, a later float of the same type behind an earlier one; at each new page a page of
  floats when the deferred ones fill `\floatpagefraction`, then the deferred floats at its top
  or bottom; `\clearpage` and the document's end put out every deferred float. Not implemented:
  `!` (accepted, ignored), `H`, two-column floats, `\suppressfloats`, `\FloatBarrier`.
* **Headings, lists, theorems** are LaTeX's own definitions carried out (`\@startsection`,
  `\@trivlist`, `\list`, `\@item`, `\@begintheorem`), with the class's parameters.

## Agreement with LuaLaTeX

`tools/doc-reference.sh` typesets every document of `corpus/doc/` (written by
`tools/doc-corpus.py`) with LuaLaTeX and New Computer Modern and records each page's lines with
their positions and text, the text body's vertical list, the counter steps, the labels and the
contents (`fixtures/doc/`). `lake test` typesets the same documents and compares
(`LeAnTeXTest/DocChecks.lean`, report `parity/DOC.md`): a document agrees when every page has
the same lines in the same order at the same position (left edge and baseline, to the sp) with
the same text, and the same labels, contents and counter steps.

| Feature | Documents agreeing | Lines at the same place (to the sp) | Within 1 pt |
|---|---|---|---|
| structure | 15 / 17 | 456 / 457 | 457 |
| environments | 9 / 13 | 87 / 114 | 92 |
| combined | 5 / 8 | 158 / 209 | 171 |
| lists | 3 / 4 | 28 / 35 | 28 |
| floats | 4 / 5 | 114 / 115 | 115 |
| footnotes | 3 / 3 | 205 / 205 | 205 |
| page breaking | 7 / 7 | 312 / 312 | 312 |
| tables | 1 / 4 | 18 / 67 | 20 |
| bibliographies | 2 / 3 | 67 / 69 | 67 |
| **all of the above** | **49 / 64** | **1445 / 1583** | **1467** |
| fresh documents (below) | 0 / 10 | 212 / 398 | 268 |

**Fresh documents.** Ten small documents (`corpus/doc/fresh-*.tex`) were written by someone who
had not read this library's source, each mixing two to four of the features listed above, and
recorded with LuaLaTeX as they came: they measure how well the layer does on documents it was
not tuned to. None agrees in full; half of their lines are at LuaLaTeX's place to the sp and two
thirds within 1 pt. The differences start mostly in what the corpus covers least: `\maketitle`
with an abstract, `align`, displays and lists after them, and inline math with limits.

`lake exe leantex-test --show-vlist NAME` prints, for each page, the first node of the text
body's vertical list (glue, box, penalty, kern or rule) where it differs from LuaLaTeX's recorded
list, with the nodes around it; the causes below were found with it.

Every disagreement, with its cause (the first differing node of the vertical list named where it
says where to look):

* `align` (1 of 15 lines): LaTeX sets each row of an alignment as a line of its own; here the
  whole alignment is one box from the math layout's `aligned`, and the row numbers are not
  drawn. The first differing node is the skip above the display (`\abovedisplayskip`, 10 pt,
  in LuaLaTeX; a single box here).
* `equation` (8 of 13), `refs` (30 of 31): every line at its place vertically; a formula's left
  edge differs by up to 0.73 pt (47,590 sp) because the math layout's widths are KaTeX's, not
  TeX's Computer Modern math fonts, and amsmath centres a numbered formula by its own rule. In
  `equation` the first differing node is the baseline skip under a display, 69 sp short: the
  display's depth is the math layout's.
* `inline-limits` (1 of 9): the first line's box is 290 sp less high and 171 sp deeper than
  LuaLaTeX's: an inline `\sum` with limits gets its height and depth from the math layout
  (KaTeX's metrics), not from TeX's math fonts' parameters. Not changed here: the math layout's
  outer box would have to follow TeX's rules for `\textstyle` limits and the MATH table of the
  font, which the 12,272 cases of the math parity do not check; it is the largest remaining
  source of differences in the fresh documents.
* `float-bottom` (13 of 14): LuaLaTeX's list has a `\penalty 0` after the last line before the
  bottom float where this layer has the baseline skip of the next line: the float's own
  penalty (LaTeX's `\@xfloat` in vertical mode) is not put into the list here; the caption then
  moves by 16 sp.
* `footnotes`: the page's final glue is `0pt plus 1fill` in LuaLaTeX's list and `plus 1fil`
  here (LaTeX's `\newpage` at the end of the document); no line moves.
* `quote` (20 of 23): the first differing node is the baseline skip of the line after the first
  line of a `quotation` paragraph (7,209 sp more here), because that line holds other words:
  the paragraph's first line breaks one word earlier than LuaLaTeX's. Its line breaking
  parameters (the item's paragraph inside the list) are the place to look; not found.
* `description-long` (5 of 12): the baseline skip after the line with the long label is 7,209 sp
  short, because the next line holds other words (the following lines break one word earlier);
  the long label's box or the glue after it differs from LaTeX's `\descriptionlabel`; not found.
* `verbatim-mixed` (6 of 11): right after the skip that closes the `verbatim` list, LuaLaTeX's
  list has a `0pt plus 1pt` skip (user glue) and, after the next line, a `\penalty 0`, which this
  layer has not; the 12 pt shift of the later lines follows from there. The cause is the end of
  LaTeX's verbatim environment (`\@endparenv` and the paragraph after it), not modelled.
* Tables: `tabular-para`, `tabular-mixed`, `tabular-multi`, `hyphen-hard`. In `tabular-para` the
  first differing node is the box of the row with `p{}` cells: 6 pt less high and deep than
  LuaLaTeX's (the cells' paragraphs as `\vtop` boxes with LaTeX's `\@arstrut` and
  `\@finalstrut` are not modelled exactly); in `tabular-multi` and `hyphen-hard` the table's
  box is 6 pt less high and deep for the same reason; in `tabular-mixed` LuaLaTeX has
  `\vskip -5pt` (the `center` environment's `\topsep` taken back by `\par` before the table)
  where this layer has `\parskip`. The `p{}` cells' line breaking (LuaLaTeX hyphenates "col-umn"
  where this layer does not) follows from the same cell parameters. Not fixed.
* `article` (32 of 52): on page 2 LuaLaTeX puts the table (`[ht]`) one line earlier; the first
  differing node is on page 1, the skip after a theorem (`\topsep` of the environment's
  `\@endparenv`): 10 pt plus 3 minus 5 here, 6 pt plus 3 minus 3 in LuaLaTeX (the theorem
  environment's end uses the list parameters of its own level); not fixed.
* `title-thanks`: lines agree; the recorded counter step differs only in how the symbol is
  printed (`\ensuremath{\ast}` in LuaLaTeX's record); the page's final glue is `plus 1fil`
  here and `plus 1fill` in LuaLaTeX, as in `footnotes`.
* `bib-numbered` (14 of 16): one reference's lines break differently: here the line breaker
  hyphenates "succes-sive", LuaLaTeX does not; the first differing node is the penalty between
  two lines of that item (8,100 here, 8,000 in LuaLaTeX: the hyphenated line's `\brokenpenalty`
  added to the club penalty), so the break itself differs; not found.
* `theorem-amsthm` agreed only after taking amsthm's theorems without `\partopsep`, found from
  LuaLaTeX's output rather than from amsthm's documentation.

Found and fixed with the vertical-list comparison: a list right after a heading now gets
LaTeX's `\@nbitem` (the outer `\parskip` less the list's), which put every such list 4 pt
low; `\addpenalty` takes back the last box's depth with the skip and gives it back after the
penalty, as LaTeX's current `\addpenalty` does; and the recorder of counter steps now also
records in documents that load amsmath (it patched `\stepcounter` too early).

Pixel comparison of the example article's pages with LuaLaTeX's PDF
(`tools/doc-render-compare.sh examples/article/article.tex N`, Quick Look renderings at 2 pixels per
point, each page as two squares): page 1 mean 8.7 levels (top) and 5.8 (bottom), 94 % and
96 % of pixels within 32 levels; page 2 (with the table placed one line later) 18.4 and 9.4
levels, 87 % and 93 %. The text is New Computer Modern in both; the formulas' fonts differ
(KaTeX's against Computer Modern).

## Bounds and untrusted input

Source is untrusted. The text layer's caps apply (source length, tokens, expansions, nesting);
the page builder takes at most `PageParams.maxSteps` steps; at most four passes run; verbatim
text is taken out of the source before it is read; image paths must be relative without `..`,
images are asked from the caller (`Settings.images`), at most `Settings.maxImage` bytes, PNG or
SVG with a size, and an SVG is drawn as an image (its scripts do not run in the document). The
tests run 282 mutated documents, each ending in pages or a clean error.

## Proved and tested

Proved (`LeAnTeX.Doc.Proofs`, axioms `propext`, `Classical.choice`, `Quot.sound` only):

* `buildPages_boxes`: the pages hold exactly the boxes of the vertical list, each once, in order
  (checked by the builder before it returns, so it holds by construction).
* `Counters.add_value`, `Counters.set_value`, `Counters.newCounter_value`: counters change as
  specified.
* `lookupRef_some`, `lookupRef_none`: a reference's text is its label's text from the previous
  pass, or there is no label of that key (and it is reported).
* `safeImagePath_relative`, `safeImagePath_noParent`: image paths asked for are relative and
  have no `..` segment.
* `romanLower_nonpos`.

Tested only: everything else, against LuaLaTeX as above.

## What a full LaTeX has that this does not

| Missing | How far away |
|---|---|
| Other classes (`report`, `book`, `letter`), `titlepage`, two-sided layout, `twocolumn` | Medium: the class table and the output routine's two-column and two-sided cases. |
| Packages (`geometry`, `hyperref`, `xcolor`, `tikz`, `booktabs`, `enumitem`, `natbib`, …) | Each its own work; `geometry` and `booktabs` are small, `hyperref` medium (links in SVG and HTML), `tikz` very large. |
| TeX's programming layer (`\let`, `\edef`, `\expandafter`, conditionals, registers, `\catcode`, delimited parameters, `\csname`) | Large: a TeX macro processor; the front end expands LaTeX's user commands only. |
| BibTeX and biblatex, `natbib` citation styles | Large (BibTeX's style language); `thebibliography` and `\cite` are here. |
| Indexes, glossaries | Medium (sorting and pages, no external program). |
| Colour | Small in the display list, medium with every package's colour model. |
| Graphics beyond PNG and SVG files: EPS, PDF, `\rotatebox`, `\scalebox`, `picture`, `tikz` | PDF and EPS need their own readers (large); rotations and scaling are small. |
| Mathematics: equation numbers on alignment rows, `\intertext`, `\tag`, `split`, numbering within sections | Medium: alignments set row by row with TeX's spacing. |
| Marginal notes, `minipage`, `\parbox`, `\raisebox`, `\fbox`, `tabular*`, `longtable`, `\cline`, `array` package preambles | Small to medium each. |
| Running heads (`headings`, `myheadings`, `fancyhdr`), `\markboth` | Small for the class's own styles. |
| PDF output | Not in this layer; the SVG and HTML back ends draw the pages. |
| Fonts beyond New Computer Modern and Latin Modern, OpenType features other than `liga`, `kern`, `smcp` | See `docs/text.md`. |
