# Documents

LeAnTeX's document layer typesets whole LaTeX documents of the `article` class into pages by
LaTeX's own constructions: TeX's vertical lists and page builder, LaTeX's output routine with
its floats and footnotes, sectioning, counters, cross-references, the table of contents, lists,
theorems, tables and figures. On documents it was not developed with, about half come out as
LuaLaTeX's line for line. It is checked against LuaLaTeX's recorded pages line by line, to the scaled
point, on 97 documents it was developed with and on two held-out sets it was not (see
*Agreement with LuaLaTeX*: the second held-out set is the figure to go by).

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
* **Environments**: `quote`, `quotation`, `verse`, `center`, `flushleft`, `flushright`, `\centering`,
  `\raggedright`, `\raggedleft`, `verbatim`, `\verb`, `\newenvironment`, `\renewenvironment`,
  `\newtheorem` (kernel and `amsthm` styles `plain`, `definition`, `remark`), `proof` with its end
  mark, `equation`, `equation*`, `displaymath`, `\[ \]`, `align`, `align*`, `gather`, `gather*`, `multline`,
  `multline*` (see *amsmath's alignments*).
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
  `\@trivlist`, `\list`, `\@item`, `\@begintheorem`, amsthm's `\@thm`, `\@verbatim`), with the
  class's parameters for each size; the levels counted as `\@listdepth` counts them.
* **Tables** are LaTeX's `array` rows: each row a box with the array strut (0.7 and 0.3 of the
  `\baselineskip`), `\tabcolsep` on each side of a cell, `|` rules `\arrayrulewidth` wide on
  the column boundaries, `\hline` rules across, rows touching; `p{w}` cells are `\vtop`
  paragraphs `w` wide, `\sloppy`, the first line with the strut's height and the last with its
  depth; `\multicolumn` widens the last column it spans when it needs more room.

## Agreement with LuaLaTeX

`tools/doc-reference.sh` typesets every document of `corpus/doc/` (written by
`tools/doc-corpus.py` and by hand) with LuaLaTeX and New Computer Modern and records each page's
lines with their positions and text, the text body's vertical list, the counter steps, the labels
and the contents (`fixtures/doc/`). `lake test` typesets the same documents and compares
(`LeAnTeXTest/DocChecks.lean`, report `parity/DOC.md`): a document agrees when every page has
the same lines in the same order at the same position (left edge and baseline, to the sp) with
the same text, and the same labels, counter steps and, when the document prints a table of
contents, contents entries. A page break is at LuaLaTeX's place when the page after it begins
with LuaLaTeX's line.

Four sets, which must be read together (`lake test` prints each row; `lake exe leantex-test
--doc-table`, `--doc-table heldout` and `--doc-table heldout-2` print a line per document):

| Set | Documents agreeing | Lines at the same place (to the sp) | Within 1 pt | Page breaks |
|---|---|---|---|---|
| reference and regression documents: 87 written to cover the features, the math ones included, or to hold a difference that was corrected (tuned on) | 87 / 87 | 1810 / 1810 | 1810 | 20 / 20 |
| fresh documents: 10 written without reading this library (corrected against afterwards) | 7 / 10 | 367 / 398 | 367 | 10 / 10 |
| first held-out set: 20 written without reading this library (8 / 20 when first run blind) | 9 / 20 | 398 / 469 | 405 | 3 / 3 |
| **second held-out set: 10 written blind after the first set was run, run once, never tuned to** | **5 / 10** | **374 / 400** | **375** | **10 / 10** |

The first held-out set gave 8 / 20 (397 lines) when it was first run blind with the TeX-rule
layout (the commit `e04b63b` prints that figure). One defect it showed (a doubled thin space
after `\cdots` before punctuation) was then fixed, which made a ninth document agree, and four
of its fixtures (`held-01`, `held-04`, `held-10`, `held-15`) were re-recorded after a fix to
the recorder (it had kept the counter steps amsmath makes while measuring): its present figure
is not a blind one. The fixture of `held-13` was recorded before the recorder gave `\today` a
fixed date and holds the day it was recorded, so that document's date line cannot agree (one of
its two lines that differ). The second set (`corpus/doc-heldout-2/`,
`tools/doc-reference.sh --held-out-2`) was written blind after that, run once, and nothing was
changed for it: its documents and fixtures have a single commit.

The figures are with the Computer Modern metric files installed (the TeX-rule math layout,
`docs/math-boxes.md`). Without them formulas are set by the KaTeX-compatible layout, whose
boxes are not TeX's, and no held-out document agrees: 0 / 20 with 194 of 469 lines at the place
and 367 within 1 pt, and 0 / 10 with 202 of 400 and 329 (`LEANTEX_TFM_DIRS=/nonexistent lake
test` prints these).

The held-out sets (`corpus/doc-heldout/`, `bash tools/doc-reference.sh --held-out`, and the
second) measure the layer on documents it was not written from: short mathematical articles
with prose, lists, theorems and proofs, inline and displayed formulas, tables, footnotes and
references, written from a list of the supported features only. `lake test` reports them and
requires nothing of them.

`lake exe leantex-test --show-vlist NAME` prints, for each page, the first node of the text
body's vertical list (glue, box, penalty, kern or rule) where it differs from LuaLaTeX's
recorded list, with the nodes around it; `--dump-vlist NAME` every node side by side;
`--show-paragraphs NAME` every paragraph's horizontal list; `--doc-table [heldout]` a line per
document. `--probes` compares the list parameters (below).

**List parameters.** `tools/list-params.sh` records, at every probe of
`corpus/doc-probe/lists.tex` (lists of every kind nested to four levels, `quote`, `quotation`,
`verse`, `center`, `flushleft`, `flushright`, theorems of the kernel and of amsthm, `proof`,
the abstract, lists in `\small` and `\footnotesize`, the bibliography), LuaLaTeX's `\topsep`,
`\partopsep`, `\itemsep`, `\parsep`, `\parskip`, `\leftmargin`, `\rightmargin`,
`\labelwidth`, `\labelsep`, `\itemindent`, `\listparindent`, `\@totalleftmargin`,
`\linewidth`, `\parindent` and the display skips, for the class at 10, 11 and 12 points
(`fixtures/doc/probe/`). The document layer records the same values for `\leantexprobe` when
`Settings.probes` is on; all 105 probes agree except the bibliography's label width at 12
points in that document (`[99]` measured 0.38 pt narrower by LaTeX there, where a document of
its own measures it as here).

**What the regression documents hold.** The behaviour below was found by comparing vertical
lists node by node; each item names the documents of the corpus that depend on it and, after
the semicolon, the regression document written for it:

* Floats: LaTeX's output routine leaves `\penalty\interlinepenalty` (10000 right after a
  heading) and `\penalty10000` where a float was given; a here float given between paragraphs
  is followed by `\vskip-\parskip`; a page with bottom floats ends without the page-depth
  correction of `\newpage`; a float in a paragraph after a space ends as `\@Esphack`
  (`\nobreak\hskip\z@skip`, spaces after it ignored); floats waiting for a page that no text
  reached go on a page of floats at `\clearpage`. `float-bottom`; `float-deferred`,
  `float-here-vertical`, `float-pagedepth`.
* Vertical material made among the glue a line break removes goes with the line before (as
  LuaTeX moves a `\vadjust`), and images are sized as graphicx computes it (`\Gscale@div`, the
  LuaTeX driver's natural size in big points): `article` (its `[ht]` table); `image-scale`.
* A `\label` written in vertical mode right after a heading is followed by two `\nobreak`
  penalties (`\protected@write`): `refs`; `label-heading`.
* `verbatim` as `\@verbatim`: the item's label starts the first line, `\vskip\parskip` after
  the item, `\penalty\interlinepenalty` after every line: `verbatim-mixed`; `verbatim-lines`.
* The space after an environment's own `\item\relax` (and after a numbered `\bibitem`) is
  ignored, as TeX ignores it in vertical mode: `quote` (quotation's first line),
  `bib-numbered`, `fresh-05`; `env-item-space`, `bib-space`.
* `description` labels as `\descriptionlabel` sets them (`\labelsep` of space, then bold):
  `description-long`, `fresh-03`; `description-label`.
* Lists follow LaTeX's depth rules (trivial lists outside the count of levels, `\labelwidth`
  kept at level 1, `\parindent` kept by trivial lists), `\small` and `\footnotesize` have their
  own `\@listi` and display skips, amsthm's theorems take `\topsep` alone above and below,
  `\partopsep` of levels 3 and 4 is 1 pt minus 1 pt: `abstract`, `article`; `lists-sizes`.
* A footnote made in the first paragraph after a heading keeps that paragraph's
  `\clubpenalty` of 10000: `article`; `footnote-club`.
* `p{}` cells are `\sloppy`, without indentation or `\parskip` (`\@startpbox`), and have no
  1 sp beside them; a word after a strut is hyphenated: `tabular-para`, `tabular-mixed`,
  `tabular-multi`, `hyphen-hard`; `tabular-sloppy`, `hyphen-strut`.
* amsmath's `align`, `gather` and `multline` as amsmath builds them (below): `align`,
  `align-rows`, `align-pairs`.
* The comparison itself reads the recorded footnote symbol, LuaTeX's numbering of glue orders
  and its rule nodes as LuaTeX writes them: `title-thanks`, `footnotes`.

**What is still different**, by cause:

| Cause | Documents | State |
|---|---|---|
| Line breaking in two paragraphs and a bibliography entry: the breaks differ from LuaLaTeX's (cause not found) | `fresh-04`, `fresh-09` | open |
| A paragraph with an inline sum in a definition breaks one word earlier than LuaLaTeX's | `fresh-02` | open |
| The held-out documents that differ (11 of 20 and 5 of 10): the title block in some, `--` in bold headings, text accents, the width of some displays, line breaks in a few paragraphs, a page one line longer or shorter | `parity/DOC.md` gives each one's first difference | open |
| `\intertext`, `split`, `alignat`, `flalign` | — | not modelled |

Formulas are set by the TeX-rule layout when the Computer Modern metric files are installed
(`docs/math-boxes.md`), inline formulas breaking after relations and binary operations as in
TeX; a formula that layout refuses is one box of the KaTeX-compatible layout, and the document's
warnings count such formulas and give the offsets of the first three (`DocResult.mathFallbacks`;
`parity/DOC.md` lists them for the corpus).

## amsmath's alignments

`align`, `align*`, `gather`, `gather*`, `multline` and `multline*` are displays whose rows are
boxes of their own: `\predisplaypenalty` and `\abovedisplayskip` (never the short skip), then
`\vskip-\jot` (for `multline` a penalty of 10000), each row with the interline glue of
`\baselineskip` plus `\jot` (`\lineskip` plus `\jot` when the rows come too close), at least a
strut high and deep, `\penalty10000` and the space of `\\[dim]` after it, then
`\postdisplaypenalty` and `\belowdisplayskip`. `align` sets its columns in pairs, right then
left aligned, the left cell after `{}` so that a relation keeps its space; the space left over
goes equally to the margins and the gaps between pairs. `gather` centres each row; `multline`
sets its first row flush left and its last flush right, `\multlinegap` from the margins.
Every row of a numbered environment steps `equation` unless it has `\notag` or `\nonumber`
(`multline` numbers its last row); a row's `\label` records its number; the number goes flush
right; a row's `\tag{x}` (`\tag*{x}`) is its number instead, set as `(x)` (`x`), and in an
`equation` amsmath's step of the counter is taken back. The cells are laid out by the math
layout. Not modelled: `\intertext`, `split`, `alignat`, `flalign`, a number that does not fit
beside its row.

## Bounds and untrusted input

Source is untrusted. The text layer's caps apply (source length, tokens, expansions, nesting);
the page builder takes at most `PageParams.maxSteps` steps; at most four passes run; verbatim
text is taken out of the source before it is read; image paths must be relative without `..`,
images are asked from the caller (`Settings.images`), at most `Settings.maxImage` bytes, PNG or
SVG with a size, and an SVG is drawn as an image (its scripts do not run in the document). A
formula is parsed under the math parser's caps (`docs/text.md`, *Bounds*). The tests run 582
mutated documents (six from each of the 97 documents of the corpus), each ending in pages or
an error, and run the command-line programs on hostile sources under CPU and memory limits
(`lake exe leantex-test --bounds`).

Past the caps, time and memory grow in proportion to the source, with large constants where
the output is large: a page costs about a millisecond and some tens of kilobytes whatever is
on it, so a source of 60,000 one-word pages (660 kB) takes more than a minute and more than a
gigabyte before `leantex-render` refuses to write more than 512 MiB. A caller that typesets sources from
strangers should set its own limits on time and memory around the call.

## Proved and tested

Proved (`LeAnTeX.Doc.Proofs`, axioms `propext`, `Classical.choice`, `Quot.sound` only):

* `buildPages_boxes`: when the page builder returns pages, the sizes (width, height, depth) of
  the boxes on them, in order, are the sizes of the vertical list's boxes in order: no box is
  lost, repeated or moved (the boxes of floats set here and the material of insertions are not
  in the count). The builder makes this comparison (`pagesPartition`) before it returns and
  gives an error otherwise, so the theorem holds by construction; it says nothing about where
  the pages are cut.
* `Counters.add_value`, `Counters.set_value`, `Counters.newCounter_value`: adding to and
  setting a defined counter give the value asked for, and a new counter is zero.
* `lookupRef_some`, `lookupRef_none`: a reference that resolves gives the text (or page) the
  table of labels holds for its key, and one that does not has no entry there.
* `safeImagePath_relative`, `safeImagePath_noParent`: a path that passes the check
  (`safeImagePath`, which the front end applies before it asks the caller for an image) does
  not start with `/` and has no `..` segment.
* `romanLower_nonpos`: `\roman` of a number that is not positive prints nothing.

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
| Mathematics: the constructs the TeX-rule layout refuses (`docs/math-boxes.md`); `\intertext`, `split`, `alignat`, numbering within sections | Small to medium each. |
| Marginal notes, `minipage`, `\parbox`, `\raisebox`, `\fbox`, `tabular*`, `longtable`, `\cline`, `array` package preambles | Small to medium each. |
| Running heads (`headings`, `myheadings`, `fancyhdr`), `\markboth` | Small for the class's own styles. |
| PDF output | Not in this layer; the SVG and HTML back ends draw the pages. |
| Fonts beyond New Computer Modern and Latin Modern, OpenType features other than `liga`, `kern`, `smcp` | See `docs/text.md`. |
