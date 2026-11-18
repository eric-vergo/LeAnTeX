/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import VersoManual
import LeAnTeXManual.Meta

open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean
open LeAnTeXManual

#doc (Manual) "Text and Line Breaking" =>
%%%
tag := "text"
htmlSplit := .never
%%%

The text layer sets paragraphs of LaTeX source into lines by TeX's algorithms: Liang's
hyphenation with TeX's patterns, the Knuth–Plass line breaker, TeX's space factor and interword
glue, and the lines stacked with TeX's interline glue. Every length is an integer number of
scaled points, computed with TeX's rounding.

# Typesetting a Fragment
%%%
tag := "text-typeset"
%%%

{name}`LeAnTeX.Text.typeset` takes source and a font resolver (a function from a font key — the
family, series, shape and size LaTeX would select — to a font read with `LeAnTeX.OpenType`) and
returns a document of lines, or an error with its position. The back ends' `Fonts.load` builds
the resolver for New Computer Modern; `LeAnTeX.Text.latinModernFile` names the Latin Modern
files instead. The display list of the lines is `Document.toDisplayList`.

```lean
open LeAnTeX.Backend in
def raggedSvg (fonts : Fonts) : Except (Nat × String) String :=
  render fonts r#"\hsize=220pt \rightskip=0pt plus 40pt
Stretchable glue at the right of every line lets the margin vary while
the interword spaces stay close to their natural width; the line
breaker still chooses all the breaks of the paragraph together.\par
\hsize=220pt \parindent=0pt \hangindent=30pt \hangafter=1
Hanging indentation: every line after the first is indented by thirty
points, a form often used for lists of references and glossaries."#
```

:::svgOf raggedSvg
Two paragraphs with TeX's parameters set in the source: stretchable `\rightskip`, and
hanging indentation.
:::

# The Line Breaker
%%%
tag := "line-breaking"
%%%

{name}`LeAnTeX.Text.breakParagraph` is TeX's algorithm, implemented from Knuth and Plass's paper,
*The TeXbook* and the algorithm *TeX: The Program* documents: legal breakpoints, badness,
fitness classes, demerits with the adjacent, double-hyphen and final-hyphen terms, the first
pass without hyphenation, the second with it, the third with `\emergencystretch`, looseness,
hanging indentation and `\parshape`. Ties between equally good breaks are resolved as TeX
resolves them. {name}`LeAnTeX.Text.setLines` builds the lines from the breaks, with their glue
settings rounded to single precision as LuaTeX stores them.

The line breaker checks its own result before returning it: every break is a legal breakpoint
or the end, the breaks increase, and the last is the end of the paragraph. The theorems of
{ref "proofs"}[What Is Proved] state exactly that, and say what they do not cover: that the
breaks are TeX's is shown by comparison with TeX, not proved.

# Hyphenation
%%%
tag := "hyphenation"
%%%

{name}`LeAnTeX.Text.Patterns.points` applies Liang's patterns as LuaTeX applies them, with the
minima `\lefthyphenmin` and `\righthyphenmin` (2 and 3 by default). The library carries plain
TeX's English patterns, which LaTeX uses by default (`Patterns.english`), and hyph-utf8's
`usenglishmax`:

```lean (name := hyphenEx)
#eval LeAnTeX.Text.Patterns.english.points "hyphenation" 2 3
```

```leanOutput hyphenEx
#[2, 6]
```

The result lists the positions of the hyphenation points: `hy-phen-ation`.

# What the Front End Understands
%%%
tag := "text-supported"
%%%

The list below is the text layer's own document's, quoted as it is committed, so that it is
exactly what the code supports:

{quoteSection "docs/text.md" "The front end: what it understands"}

# What It Does Not Do
%%%
tag := "text-unsupported"
%%%

{quoteSection "docs/text.md" "Not implemented, against a full LaTeX"}
