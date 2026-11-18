/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import VersoManual
import LeAnTeXManual.Meta

open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean
open LeAnTeXManual

#doc (Manual) "Documents" =>
%%%
tag := "documents"
htmlSplit := .never
%%%

The document layer typesets a whole LaTeX document of the `article` class into pages by LaTeX's
own constructions: TeX's vertical lists and page builder, LaTeX's output routine with its floats
and footnotes, sectioning, counters, cross-references resolved in repeated passes, the table of
contents, lists, theorems, tables, figures and bibliographies. How closely its pages agree with
LuaLaTeX's, on documents it was developed with and on documents it was not, is in
{ref "agreement"}[Agreement with TeX and KaTeX].

# Typesetting a Document
%%%
tag := "documents-typeset"
%%%

{name}`LeAnTeX.Doc.typesetDocument` returns a {name}`LeAnTeX.Doc.DocResult`: the pages, the
labels, the table of contents, the counter steps, the number of passes and the warnings. The
back ends draw it as one SVG picture per page ({name}`LeAnTeX.Backend.svgPages`), all pages in
one picture ({name}`LeAnTeX.Backend.svgCombined`) or an HTML page of sheets
({name}`LeAnTeX.Backend.htmlPages`); `leantex-render --document FILE OUTDIR` writes all of them.

Images are the caller's: `LeAnTeX.Text.Settings.images` gives the bytes for a path the document
names, after the path has passed the check of {ref "untrusted"}[Untrusted Input]. A document
never reads a file by itself, and its output never depends on the clock (`\today` prints
`Settings.today`).

```lean
def listsSource : String := r#"\documentclass{article}
\begin{document}
\section*{Lists and a table}
\begin{enumerate}
\item First, a numbered item.
\item Second, with a nested list:
  \begin{itemize}
  \item a bullet,
  \item another one.
  \end{itemize}
\end{enumerate}
\begin{center}
\begin{tabular}{|l|c|r|}
\hline
Left & Centre & Right \\
\hline
a & b & c \\
\multicolumn{2}{|l|}{two columns} & 3 \\
\hline
\end{tabular}
\end{center}
\begin{description}
\item[Term] its description.
\end{description}
\end{document}
"#

open LeAnTeX.Backend in
def listsPages (fonts : Fonts) : Except String (Array String) :=
  match LeAnTeX.Doc.typesetDocument listsSource fonts.resolver with
  | .ok doc => .ok (svgPages fonts.set doc "Lists and a table")
  | .error e => .error s!"at {e.pos}: {e.message}"
```

:::pagesOf listsPages
Nested lists with the class's labels and indents, a `tabular` with rules and
`\multicolumn`, and a description list.
:::

# What a Document Can Use
%%%
tag := "documents-supported"
%%%

Quoted from the document layer's own document as committed:

{quoteSection "docs/documents.md" "What a document can use"}

amsmath's alignments are set as amsmath builds them, row by row:

{quoteSection "docs/documents.md" "amsmath's alignments"}

# What a Full LaTeX Has That This Does Not
%%%
tag := "documents-unsupported"
%%%

{quoteSection "docs/documents.md" "What a full LaTeX has that this does not"}

There is no PDF output: pages are SVG pictures and HTML sheets ({ref "back-ends"}[Back Ends]).
