/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import VersoManual
import LeAnTeXManual.Meta

open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean
open LeAnTeXManual

#doc (Manual) "Macros" =>
%%%
tag := "macros"
htmlSplit := .never
%%%

Macros can be given in three places: to the math parser as settings, in a formula, and in the
text of a paragraph or document. Macros defined in the text are available in its formulas.

# In Formulas
%%%
tag := "macros-math"
%%%

The math parser is KaTeX's, with KaTeX's macro expander: `\def`, `\gdef`, `\newcommand`,
`\renewcommand`, `\providecommand`, `\let` and the rest of KaTeX's macro commands work as in
KaTeX, and KaTeX's built-in macros are defined. A program can also pass macros in
`LeAnTeX.Settings.macros`, as names and bodies, as KaTeX's `macros` option does:

```lean (name := macroSetting)
#eval [#[], #[("\\RR", "\\mathbb{R}")]].map fun ms =>
  match (LeAnTeX.parse "\\RR^n" { macros := ms }).result with
  | .ok tree => s!"parsed: {tree.size} node(s)"
  | .error e => e.message
```

```leanOutput macroSetting
["KaTeX parse error: Undefined control sequence: \\RR at position 1: \\̲R̲R̲^n", "parsed: 1 node(s)"]
```

```lean (name := macroInFormula)
#eval match (LeAnTeX.parse "\\newcommand{\\sq}[1]{#1^2} \\sq{x} + \\sq{y}").result with
  | .ok tree => s!"{tree.size} nodes"
  | .error e => e.message
```

```leanOutput macroInFormula
"3 nodes"
```

Expansion is bounded: `Settings.maxExpand` counts expansions, as in KaTeX, and LeAnTeX's own
`Settings.maxTokens` counts the tokens they produce ({ref "untrusted"}[Untrusted Input]).

# In Text and Documents
%%%
tag := "macros-text"
%%%

The text layer expands LaTeX's user commands: `\newcommand`, `\renewcommand` and
`\providecommand` with up to nine parameters and an optional first one, and `\def` with
undelimited parameters. Definitions are local to groups, as in TeX. A document adds
`\newenvironment` and `\renewenvironment`. TeX's programming layer (`\let`, `\edef`,
`\expandafter`, conditionals, registers, `\catcode`, delimited parameters, `\csname`) is not
implemented ({ref "text-unsupported"}[What It Does Not Do]).

```lean
open LeAnTeX.Backend in
def macrosSvg (fonts : Fonts) : Except (Nat × String) String :=
  render fonts r#"\newcommand{\R}{\mathbb{R}}
\newcommand{\norm}[1]{\left\lVert #1 \right\rVert}
\newcommand{\term}[1]{\emph{#1}}
\newcommand{\greet}[2][friend]{Hello, #1 and #2!}
A \term{norm} on a vector space $V$ over $\R$ is a function
$\norm{\cdot} : V \to \R$ with $\norm{x + y} \le \norm{x} + \norm{y}$;
the macros of the text work in its formulas.
\greet{reader} \greet[dear]{patient reader}"#
```

:::svgOf macrosSvg
Macros defined in the text, used in the text and in its formulas; `\greet` has an optional
first argument with the default `friend`.
:::

The text layer's expansion is bounded too: `LeAnTeX.Text.Settings.maxTokens` and
`maxExpansions` cap the tokens produced and the expansions, over the whole source.
