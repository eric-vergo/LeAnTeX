/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import VersoManual
import LeAnTeXManual.Meta

open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean
open LeAnTeXManual

#doc (Manual) "Back Ends" =>
%%%
tag := "back-ends"
htmlSplit := .never
%%%

Every layer produces a display list ({name}`LeAnTeX.DisplayList`): positioned glyphs, rules,
paths and images, in TeX's scaled points, with no assumption about how they are drawn. Two back
ends draw it, and a third writes a formula's structure:

* *SVG* ({name}`LeAnTeX.Backend.svgDocument`): glyphs as outlines, each defined once in the
  picture and placed by reference; the picture needs no font file and looks the same everywhere.
* *HTML* ({name}`LeAnTeX.Backend.htmlDocument`): text as text, set by the browser in the web
  fonts at TeX's positions; formulas as inline SVG.
* *MathML* ({name}`LeAnTeX.Backend.mathML`): a formula's parse tree as MathML Core, for
  screen readers beside a picture; it is not drawn.

{name}`LeAnTeX.Backend.render` runs the layers and a back end in one call; the program
`leantex-render` does it from the command line:

```
lake exe leantex-render FILE.tex OUT.svg                 # SVG
lake exe leantex-render --html FILE.tex OUT.html         # HTML
lake exe leantex-render --math FORMULA.tex OUT.svg       # one formula in display mode
lake exe leantex-render --document FILE.tex OUTDIR       # a whole document
```

# SVG
%%%
tag := "back-ends-svg"
%%%

{quoteSection "docs/back-ends.md" "SVG"}

# HTML
%%%
tag := "back-ends-html"
%%%

A paragraph as an HTML page. The frame below shows the page `render` wrote, in a frame that
runs no script; its text can be selected and searched:

```lean
open LeAnTeX.Backend in
def mixedHtml (fonts : Fonts) : Except (Nat × String) String :=
  render fonts r#"Text is text in the HTML back end: \emph{this sentence}
can be selected, copied and searched, while a formula such as
$\int_0^1 x^2\,dx = \frac{1}{3}$ is an inline SVG picture whose
alternative text is its source."#
    { html := true, fontUrl := "../fonts" }
```

:::htmlOf mixedHtml (height := 110)
The page `mixedHtml` returned, shown as it is (the site carries the font files it loads).
:::

The start of the page's text:

{htmlSourceOf mixedHtml (lines := 12)}

{quoteSection "docs/back-ends.md" "HTML"}

# Drawing KaTeX's Faces with New Computer Modern
%%%
tag := "back-ends-faces"
%%%

{quoteSection "docs/back-ends.md" "Fonts"}

# MathML
%%%
tag := "back-ends-mathml"
%%%

```lean (name := mathmlEx)
#eval match LeAnTeX.Backend.mathML "x^2" with
  | .ok m => m
  | .error e => e
```

```leanOutput mathmlEx
"<math xmlns=\"http://www.w3.org/1998/Math/MathML\"><semantics><mrow><msup><mrow><mi>x</mi></mrow><mrow><mn>2</mn></mrow></msup></mrow><annotation encoding=\"application/x-tex\">x^2</annotation></semantics></math>"
```

{quoteSection "docs/back-ends.md" "MathML"}

# What the Back Ends Do Not Do
%%%
tag := "back-ends-not"
%%%

{quoteSection "docs/back-ends.md" "Not implemented"}
