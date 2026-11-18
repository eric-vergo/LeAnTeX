/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import VersoManual
import LeAnTeXManual.Meta

open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean
open LeAnTeXManual

#doc (Manual) "Getting Started" =>
%%%
tag := "getting-started"
htmlSplit := .never
%%%

LeAnTeX is a library: a Lean program imports it and calls it. This chapter adds it to a Lake
project, typesets a formula, a paragraph and a short document, and writes each as an SVG
picture. Every code block on this page is compiled when the manual is built, and every picture
below it is what that code returned when the manual was built, with the fonts the repository
carries.

# Adding LeAnTeX to a Project
%%%
tag := "add-dependency"
%%%

LeAnTeX is a Lake package named `leantex`, with one library, `LeAnTeX`. It depends on Lean's
`Init` and `Std` only, so a program that cannot import the `Lean` package (or that must stay
small) can still use it. It is written for the Lean version in its {file}`lean-toolchain`
file; a project that depends on it uses the same toolchain.

In a `lakefile.lean`:

```
require leantex from git "https://github.com/eric-vergo/LeAnTeX.git" @ "main"
```

or in a `lakefile.toml`:

```
[[require]]
name = "leantex"
git = "https://github.com/eric-vergo/LeAnTeX.git"
rev = "main"
```

A commit hash in place of `main` pins a revision. Then `import LeAnTeX` gives the whole library:
the parser and the KaTeX-compatible layout (`LeAnTeX.parse`, `LeAnTeX.layout`), the TeX-rule
layout (`LeAnTeX.TeXMath`), the text and document layers (`LeAnTeX.Text`, `LeAnTeX.Doc`), the
font reader (`LeAnTeX.OpenType`) and the back ends (`LeAnTeX.Backend`).

The back ends draw with the fonts of New Computer Modern, which the repository carries in
{file}`fonts/newcomputermodern` (see {ref "fonts"}[Fonts and Metrics] for which files and under
which licence). A program reads them at run time from a folder it names; Lake does not copy them
into a dependent project, so a program either points at the dependency's copy
(`.lake/packages/leantex/fonts/newcomputermodern`) or ships its own copy of the files.

# Parsing and Laying Out a Formula
%%%
tag := "first-formula"
%%%

The math layer needs no fonts. `LeAnTeX.parse` returns KaTeX's parse tree, or KaTeX's error for
the same input:

```lean (name := parseOk)
#eval match (LeAnTeX.parse "\\frac{a}{b}^2").result with
  | .ok tree => s!"{tree.size} node(s) at the top"
  | .error e => e.message
```

```leanOutput parseOk
"1 node(s) at the top"
```

```lean (name := parseErr)
#eval match (LeAnTeX.parse "\\frac{a}").result with
  | .ok _ => "parsed"
  | .error e => e.message
```

```leanOutput parseErr
"KaTeX parse error: Unexpected end of input in a macro argument, expected '}' at end of input: \\frac{a}"
```

`LeAnTeX.layout` parses and lays the formula out into KaTeX's box tree, and
`LeAnTeX.DisplayList.ofBox` turns the box tree into positioned glyphs, rules and paths, the
neutral form every back end draws:

```lean (name := layoutEx)
#eval match (LeAnTeX.layout "\\frac{a}{b}^2").result with
  | .ok box =>
    let items := (LeAnTeX.DisplayList.ofBox box).items
    let glyphs := items.filterMap fun
      | LeAnTeX.Item.glyph _ c .. => some c
      | _ => none
    let rules := items.filter fun
      | LeAnTeX.Item.rule .. => true
      | _ => false
    s!"glyphs {glyphs.toList}, {rules.size} rule(s)"
  | .error _ => "not laid out"
```

```leanOutput layoutEx
"glyphs [b, a, 2], 1 rule(s)"
```

# A Formula as SVG
%%%
tag := "formula-svg"
%%%

`LeAnTeX.Backend.render` typesets a source and writes it as an SVG picture (or, with
`html := true`, as an HTML page). With `math := true` the source is one formula in display
mode:

```lean
open LeAnTeX.Backend in
def eulerSvg (fonts : Fonts) : Except (Nat × String) String :=
  render fonts "e^{i\\pi} + 1 = 0" { math := true }
```

:::svgOf eulerSvg
The picture `eulerSvg` returned when this manual was built. Its glyphs are outlines of New
Computer Modern Math, at the positions KaTeX's layout gives them.
:::

A program reads the fonts once and writes the picture to a file:

```lean
open LeAnTeX.Backend in
def writeEuler : IO Unit := do
  let (fonts, missing) ← Fonts.load "fonts/newcomputermodern"
  unless missing.isEmpty do
    throw (IO.userError s!"fonts missing or unreadable: {missing}")
  match eulerSvg fonts with
  | .ok svg => IO.FS.writeFile "euler.svg" svg
  | .error (pos, msg) => IO.eprintln s!"at {pos}: {msg}"
```

`Fonts.load` returns the fonts it read and the names of the files it could not read; the
picture refers to no font file afterwards (each glyph it uses is defined once inside it), so it
looks the same everywhere. An error is the position in the source (a character offset) and the
message.

# A Paragraph
%%%
tag := "first-paragraph"
%%%

Without `math := true`, `render` takes the source as LaTeX text: paragraphs broken into lines by
TeX's line-breaking algorithm, with TeX's hyphenation, in the text fonts of New Computer Modern,
at the `article` class's ten-point defaults (a line 345 pt wide):

```lean
open LeAnTeX.Backend in
def paragraphSvg (fonts : Fonts) : Except (Nat × String) String :=
  render fonts r#"A \emph{typesetter} decides where every character goes.
It reads the whole paragraph before it breaks a single line, and it chooses
the breaks that space all the lines most evenly; a formula such as
$\sum_{k=1}^n k = n(n+1)/2$ is set in the line like a word, and a long word
such as incomprehensibility may be hyphenated where the patterns allow."#
```

:::svgOf paragraphSvg
The paragraph as `paragraphSvg` returned it.
:::

# A Small Document
%%%
tag := "first-document"
%%%

The document layer takes a whole LaTeX file of the `article` class and returns its pages.
`LeAnTeX.Doc.typesetDocument` needs the text layer's font resolver, and
`LeAnTeX.Backend.svgPages` draws each page as an SVG picture of the paper's size:

```lean
def noteSource : String := r#"\documentclass{article}
\usepackage{amsthm}
\newtheorem{theorem}{Theorem}
\begin{document}
\title{A Short Note}
\author{A. Writer}
\date{1 May 2025}
\maketitle
\section{Sums}\label{sec:sums}
The sum of the first $n$ odd numbers is a square.\footnote{Draw the squares.}
\begin{theorem}\label{thm:odd}
For every $n \ge 1$,
\[ \sum_{k=1}^{n} (2k - 1) = n^2. \]
\end{theorem}
\begin{proof}
Each odd number adds an L-shaped border to the square before it.
\end{proof}
Theorem~\ref{thm:odd} in Section~\ref{sec:sums} needs no algebra:
\begin{itemize}
\item one dot,
\item three more around it,
\item five more around those.
\end{itemize}
\end{document}
"#

open LeAnTeX.Backend in
def notePages (fonts : Fonts) : Except String (Array String) :=
  match LeAnTeX.Doc.typesetDocument noteSource fonts.resolver with
  | .ok doc => .ok (svgPages fonts.set doc "A Short Note")
  | .error e => .error s!"at {e.pos}: {e.message}"
```

:::pagesOf notePages
The pages `notePages` returned: a US letter page with the title block, the numbered section,
the footnote at the foot, the theorem and the proof with its end mark, the list, the
cross-references resolved and the page number.
:::

The formula on this page was laid out by the KaTeX-compatible layout, because the program
passes no TeX metric files. Given the Computer Modern metric files of a TeX installation
(`LeAnTeX.Text.Settings.mathTfms`), the document layer lays formulas out by TeX's own rules
instead, and falls back to the KaTeX-compatible layout, with a warning, only for a formula
those rules do not build; {ref "math"}[Math] says which formulas those are.

# Where to Go Next
%%%
tag := "next"
%%%

* {ref "math"}[Math] — the two math layouts, what each accepts and how they fall back.
* {ref "text"}[Text and Line Breaking] and {ref "documents"}[Documents] — what of LaTeX is
  understood, and what is not.
* {ref "untrusted"}[Untrusted Input] — the limits that bound the work for a source from a
  stranger.
* {ref "agreement"}[Agreement with TeX and KaTeX] — what has been compared, on which inputs, and
  with what result.
