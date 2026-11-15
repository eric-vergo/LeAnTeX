# Documents

LeAnTeX's document layer typesets whole LaTeX documents of the `article` class into pages, as
LaTeX does: TeX's vertical lists and page builder, LaTeX's output routine with its floats and
footnotes, sectioning, counters, cross-references, the table of contents, lists, theorems,
tables and figures. It is checked against LuaLaTeX line by line, to the scaled point, on 89
documents it was developed with and on 20 held-out documents it was not (see *Agreement with
LuaLaTeX*: the second figure is the one to go by).

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
the same text, and the same labels, contents and counter steps. A page break is at LuaLaTeX's
place when the page after it begins with LuaLaTeX's line.

Three sets, which must be read together:

| Set | Documents agreeing | Lines at the same place (to the sp) | Within 1 pt | Page breaks |
|---|---|---|---|---|
| reference documents: the 64 written to cover the features (tuned on) | 60 / 64 | 1562 / 1583 | 1577 | 17 / 17 |
| regression documents: 15, one or more per difference fixed | 13 / 15 | 109 / 143 | 143 | 3 / 3 |
| fresh documents: 10 written without reading this library | 2 / 10 | 204 / 398 | 299 | 9 / 10 |
| **held-out documents: 20 written without reading this library, not tuned to** | **0 / 20** | **190 / 469** | **355** | **3 / 3** |

The held-out set (`corpus/doc-heldout/`, `bash tools/doc-reference.sh --held-out`) is the honest
measure of the layer on documents it was not shaped by: short mathematical articles with
prose, lists, theorems and proofs, inline and displayed formulas, tables, footnotes and
references, written from a list of the supported features only. `lake test` reports it and
requires nothing of it. Before the changes listed below the same set gave 0 / 20, 156 of 469
lines and 280 within 1 pt; the fresh documents 0 / 10, 212 of 398 and 268 (fewer of their
lines are at the place to the sp now, more within 1 pt: their pages are filled with glue set by
the boxes of their formulas, see below).

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

**Differences found with the vertical-list comparison and fixed**, each with the documents that
agree since and its regression document:

* Floats: LaTeX's output routine leaves `\penalty\interlinepenalty` (10000 right after a
  heading) and `\penalty10000` where a float was given; a here float given between paragraphs
  is followed by `\vskip-\parskip`; a page with bottom floats ends without the page-depth
  correction of `\newpage`; a float in a paragraph after a space ends as `\@Esphack`
  (`\nobreak\hskip\z@skip`, spaces after it ignored); floats waiting for a page that no text
  reached go on a page of floats at `\clearpage`. `float-bottom`; `float-deferred`,
  `float-here-vertical`, `float-pagedepth`.
* Vertical material made among the glue a line break removes goes with the line before (as
  LuaTeX moves a `\vadjust`), and images are sized as graphicx computes it (`\Gscale@div`, the
  LuaTeX driver's natural size in big points): `article` (the `[ht]` table no longer a line
  late); `image-scale`.
* A `\label` written in vertical mode right after a heading is followed by two `\nobreak`
  penalties (`\protected@write`): `refs` now differs only in formula widths; `label-heading`.
* `verbatim` as `\@verbatim`: the item's label starts the first line, `\vskip\parskip` after
  the item, `\penalty\interlinepenalty` after every line: `verbatim-mixed`; `verbatim-lines`.
* The space after an environment's own `\item\relax` (and after a numbered `\bibitem`) is
  ignored, as TeX ignores it in vertical mode: `quote` (quotation's first line), `bib-numbered`
  (the hyphen that was not LaTeX's), `fresh-05`; `env-item-space`, `bib-space`.
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
* amsmath's `align`, `gather` and `multline` as amsmath builds them (below): every line of
  `align`, `align-rows` and `align-pairs` within 1 pt, the vertical list LuaLaTeX's; their
  remaining differences are the formulas' widths.
* `title-thanks` and the final `plus 1fill` of `footnotes` were differences of the comparison
  itself (the recorded footnote symbol, LuaTeX's numbering of glue orders and its rule nodes).

**What is still different**, by cause:

| Cause | Documents | State |
|---|---|---|
| Formula boxes: KaTeX's metrics and rules where TeX uses the Computer Modern math fonts of each size and Appendix G (`docs/math-boxes.md`) | `equation`, `refs`, `inline-limits`, `align`, `align-rows`, `align-pairs`, `fresh-02`, `fresh-04`, `fresh-06`, `fresh-07`, `fresh-08`, `fresh-09`, `fresh-10`; most of the held-out differences | not modelled: the second, TeX-rule layout is designed, not written |
| The footnote mark's raise in the footnote size of the 11-point class (the 9-point math fonts' parameters) | `fresh-01` | not modelled |
| `\today` prints `Settings.today`, LuaLaTeX the recording date | held-out `held-13` | by design: output never depends on the clock |
| `\flushright` as a declaration | held-out `held-10` (an error) | not supported (the environment is) |

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
right. The cells are laid out by the math layout. Not modelled: `\tag`, `\intertext`, `split`,
`alignat`, `flalign`, a number that does not fit beside its row.

## Bounds and untrusted input

Source is untrusted. The text layer's caps apply (source length, tokens, expansions, nesting);
the page builder takes at most `PageParams.maxSteps` steps; at most four passes run; verbatim
text is taken out of the source before it is read; image paths must be relative without `..`,
images are asked from the caller (`Settings.images`), at most `Settings.maxImage` bytes, PNG or
SVG with a size, and an SVG is drawn as an image (its scripts do not run in the document). The
tests run 534 mutated documents (six from each document of the corpus), each ending in pages or
a clean error.

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
| Mathematics: TeX's own formula boxes (`docs/math-boxes.md`); `\intertext`, `\tag`, `split`, `alignat`, numbering within sections | Large for the boxes (a second, TeX-rule math layout with the Computer Modern metrics of each size); small to medium for the rest. |
| Marginal notes, `minipage`, `\parbox`, `\raisebox`, `\fbox`, `tabular*`, `longtable`, `\cline`, `array` package preambles | Small to medium each. |
| Running heads (`headings`, `myheadings`, `fancyhdr`), `\markboth` | Small for the class's own styles. |
| PDF output | Not in this layer; the SVG and HTML back ends draw the pages. |
| Fonts beyond New Computer Modern and Latin Modern, OpenType features other than `liga`, `kern`, `smcp` | See `docs/text.md`. |
