/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import VersoManual
import LeAnTeXManual.Meta

open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean
open LeAnTeXManual

#doc (Manual) "Math" =>
%%%
tag := "math"
htmlSplit := .never
%%%

LeAnTeX has two math layouts. They share one parser and differ in what they are for:

* The *KaTeX-compatible layout* ({name}`LeAnTeX.layout`) is a port of KaTeX 0.19.1. It
  accepts what KaTeX accepts, rejects what KaTeX rejects with KaTeX's message, and builds the
  box tree KaTeX builds, with KaTeX's font metrics compiled into the library. It needs no file
  at run time. A formula on its own (the `math := true` mode of the back ends, an editor's
  formula preview) is laid out by it.
* The *TeX-rule layout* ({name}`LeAnTeX.TeXMath.mlistToHlist`) follows TeX's own rules
  (*The TeXbook*, Appendix G) with the metrics of the fonts LaTeX uses, read at run time from
  the Computer Modern metric (TFM) files of a TeX installation. The text and document layers use
  it when they are given those files, because a formula in a paragraph is material for the line
  breaker and the page builder, and its boxes must be TeX's for the lines and pages to be.

# The Parser
%%%
tag := "math-parser"
%%%

{name}`LeAnTeX.parse` is a port of KaTeX's lexer, macro expander and parser, with KaTeX's whole
function list, its environments, its built-in macros and its error messages. It takes
{name}`LeAnTeX.Settings`, KaTeX's options with KaTeX's defaults (display mode, user macros,
`strict`, `trust`, `throwOnError`, `maxSize`, …) and LeAnTeX's two limits of its own
(`maxTokens`, `maxNesting`; see {ref "untrusted"}[Untrusted Input]). It returns the parse tree
or the error, and the warnings KaTeX's strict mode would print:

```lean (name := strictWarn)
#eval (LeAnTeX.parse "\\text{é}").warnings
```

```leanOutput strictWarn
#[]
```

```lean (name := strictErr)
#eval match (LeAnTeX.parse "x^1^2").result with
  | .ok _ => "parsed"
  | .error e => e.message
```

```leanOutput strictErr
"KaTeX parse error: Double superscript at position 4: x^1^̲2"
```

Commands that make links or include files (`\href`, `\url`, `\includegraphics`, the `\html…`
commands) are refused unless `trust` is set, as in KaTeX:

```lean (name := trustEx)
#eval match (LeAnTeX.parse "\\href{https://example.org}{x}").result with
  | .ok _ => "parsed"
  | .error e => e.message
```

```leanOutput trustEx
"parsed"
```

# The KaTeX-Compatible Layout
%%%
tag := "math-katex"
%%%

{name}`LeAnTeX.layout` parses a formula and lays it out into KaTeX's box tree: the same spans,
symbols and SVG images, with the same classes, heights, depths, widths and style properties.
Numbers are exact: lengths are integers of TeX's scaled points (2⁻¹⁶ pt, ten points to the em),
so the result is the same on every machine. {name}`LeAnTeX.DisplayList.ofBox` evaluates the
part of KaTeX's style sheet the trees use and returns the display list: positioned glyphs (a
character of one of KaTeX's twenty faces at a size), rules and SVG paths, with the regions that
map positions back to the source.

```lean
open LeAnTeX.Backend in
def cdSvg (fonts : Fonts) : Except (Nat × String) String :=
  render fonts (r#"\begin{CD} A @>f>> B \\ @VgVV @VVhV \\ C @>>k> D"# ++
    r#"\end{CD} \quad \begin{pmatrix} a & b \\ c & d \end{pmatrix} \quad"# ++
    r#"|x| = \begin{cases} x & x \ge 0 \\ -x & x < 0 \end{cases}"#) { math := true }
```

:::svgOf cdSvg
A commutative diagram, a matrix and a case split, laid out by the KaTeX-compatible layout and
drawn with New Computer Modern Math.
:::


The back ends draw KaTeX's faces with New Computer Modern Math, not with KaTeX's own fonts,
which LeAnTeX does not include: each face maps a character to the Unicode mathematical character
it stands for, and the larger delimiters are the math font's size variants. The positions are
KaTeX's and the shapes New Computer Modern's; {ref "back-ends"}[Back Ends] lists where the two
do not line up.

# The TeX-Rule Layout
%%%
tag := "math-tex"
%%%

The TeX-rule layout turns the parser's tree into the math list TeX builds for the same source in
LaTeX with `amsmath` and `amssymb` ({name}`LeAnTeX.TeXMath.toMathList`), each symbol with the
math code LaTeX gives it, and converts the list into boxes by Appendix G's rules, with TeX's
rounding and the five places where LuaTeX's boxes differ from TeX82's. The metric files are
read and checked in pure Lean ({name}`LeAnTeX.TeXMath.Tfm`); a file that fails a check is
refused, not used.

*The metric files are not part of LeAnTeX.* A program reads them from a TeX installation it
has, with {name}`LeAnTeX.TeXMath.readTfmDirs`, and passes them in
`LeAnTeX.Text.Settings.mathTfms`; `leantex-render --document --tfm DIR` does the same. Without
them every formula of a paragraph or document is laid out by the KaTeX-compatible layout, whose
boxes are KaTeX's, not TeX's. The manual's own samples are built that way: the build reads no
file of a TeX installation.

## When Each Layout Is Used
%%%
tag := "math-which"
%%%

:::table +header
* * Where the formula is
  * Metric files given
  * Layout
* * A formula on its own (`render … { math := true }`, `LeAnTeX.layout`)
  * either way
  * KaTeX-compatible
* * In text or a document (`$…$`, `\[…\]`, `equation`, `align`, …)
  * no
  * KaTeX-compatible, every formula
* * In text or a document
  * yes
  * TeX-rule; KaTeX-compatible for a formula the TeX-rule layout refuses, with a warning
:::

A formula of the KaTeX-compatible layout is one box in the paragraph, which no line break
enters. One of the TeX-rule layout is TeX's list: the paragraph may break after a relation or a
binary operation inside it, where TeX would.

## Fallbacks and Their Warnings
%%%
tag := "math-fallback"
%%%

The TeX-rule layout does not build every construct the parser accepts. A formula it refuses is
laid out by the KaTeX-compatible layout instead, and the document's warnings count such
formulas and give the character offsets and reasons of the first three
({name}`LeAnTeX.Text.fallbackWarning`; the offsets are in `LeAnTeX.Doc.DocResult.mathFallbacks`).
The warning reads, for two refused formulas:

```lean (name := fallbackEx)
#eval LeAnTeX.Text.fallbackWarning #[(120, "\\over"), (348, "\\boldsymbol")]
```

```leanOutput fallbackEx
some
  "2 formulas set by the KaTeX-compatible layout, which the TeX-rule layout refused: at character 120 (\\over), at character 348 (\\boldsymbol)"
```

The refused constructs, as the formula-box document lists them:

{quoteSection "docs/math-boxes.md" "The front end"}

The figures for both layouts (how many formulas, against which recordings, with what result)
are in {ref "agreement"}[Agreement with TeX and KaTeX].
