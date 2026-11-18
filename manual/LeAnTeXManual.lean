/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import VersoManual
import LeAnTeXManual.Meta
import LeAnTeXManual.GettingStarted
import LeAnTeXManual.Guide
import LeAnTeXManual.Agreement
import LeAnTeXManual.Proofs
import LeAnTeXManual.Api
import LeAnTeXManual.Licences

open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean
open LeAnTeXManual

#doc (Manual) "LeAnTeX" =>
%%%
tag := "leantex"
authors := ["Eric Vergo", "Claude (Anthropic)"]
%%%

LeAnTeX is a TeX typesetter written in Lean 4, with no dependency beyond Lean's `Init` and
`Std`. It has a math parser and layout ported from KaTeX 0.19.1, a second math layout that
follows TeX's own rules with the metrics of the fonts LaTeX uses, a text layer that breaks
paragraphs and hyphenates as TeX does, a document layer for LaTeX's `article` class, an
OpenType font reader, and back ends that write SVG and HTML.

```lean
open LeAnTeX.Backend in
def titleSvg (fonts : Fonts) : Except (Nat × String) String :=
  render fonts r#"\int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}"#
    { math := true }
```

:::svgOf titleSvg
Typeset by LeAnTeX when this manual was built, from the source above.
:::

This manual is built from the repository: every Lean example is compiled, every picture is the
library's output, the lists of what is supported are quoted from the repository's documents, and
the agreement figures are put beside what the test driver printed in the build that wrote the
site.

* {ref "getting-started"}[Getting Started] adds LeAnTeX to a project and typesets a formula, a
  paragraph and a document.
* {ref "guide"}[Guide] has a chapter for each part: math, text, documents, fonts, back ends,
  macros and untrusted input.
* {ref "agreement"}[Agreement with TeX and KaTeX] gives the figures, what was compared and on
  which inputs.
* {ref "proofs"}[What Is Proved] lists the theorems and what each does and does not establish.
* {ref "api-reference"}[API Reference] documents every module from its docstrings.
* {ref "licences"}[Licences] quotes the repository's notices.

{include 1 LeAnTeXManual.GettingStarted}

{include 1 LeAnTeXManual.Guide}

{include 1 LeAnTeXManual.Agreement}

{include 1 LeAnTeXManual.Proofs}

{include 1 LeAnTeXManual.Api}

{include 1 LeAnTeXManual.Licences}
