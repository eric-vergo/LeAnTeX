/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import VersoManual
import LeAnTeXManual.Meta

open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean
open LeAnTeXManual

#doc (Manual) "Untrusted Input" =>
%%%
tag := "untrusted"
htmlSplit := .never
%%%

LeAnTeX treats every source as untrusted: a formula from a web page, a document from a stranger,
a font file. Each layer bounds the work its input can cause, and past a bound the result is an
error, never a hang. The defaults on this page are the library's own values, evaluated when the
manual is built.

# Formulas
%%%
tag := "untrusted-math"
%%%

KaTeX limits the number of macro expansions (`maxExpand`). LeAnTeX adds two limits of its own
on the work a formula can cause:

* `Settings.maxTokens` bounds the tokens all macro expansions produce together, and, a fixed
  factor over, the tokens read as arguments (an argument inside others is read once per level).
* `Settings.maxNesting` bounds the nesting of groups, arguments and environments, and with it
  the depth of the parser's recursion.

KaTeX's `maxSize` cuts every size a formula writes (`\rule`, `\kern`, a row gap) to that many em;
KaTeX's default is no limit, and so is LeAnTeX's.

```lean (name := mathDefaults)
#eval (LeAnTeX.defaultMaxTokens, LeAnTeX.argumentReadFactor, LeAnTeX.defaultMaxNesting,
  ({} : LeAnTeX.Settings).maxExpand, ({} : LeAnTeX.Settings).maxSize)
```

```leanOutput mathDefaults
(20000, 50, 1000, 1000, none)
```

Past a limit, the parse is an error with a message of its own:

```lean (name := nestRefusal)
#eval match (LeAnTeX.parse "{{{{{{x}}}}}}" { maxNesting := some 4 }).result with
  | .ok _ => "parsed"
  | .error e => e.message
```

```leanOutput nestRefusal
"KaTeX parse error: Too deeply nested: more than 4 levels (maxNesting setting) at position 5: {{{{{̲{x}}}}}}"
```

```lean (name := tokenRefusal)
#eval match (LeAnTeX.parse "\\def\\a{xxxxxxxxxx}\\a\\a\\a\\a\\a\\a"
    { maxTokens := some 40 }).result with
  | .ok _ => "parsed"
  | .error e => e.message
```

```leanOutput tokenRefusal
"KaTeX parse error: Too many tokens: the macros expand to more than 40 tokens (maxTokens setting)"
```

# Text and Documents
%%%
tag := "untrusted-text"
%%%

The text layer caps the source's length, the tokens all macro expansions produce, the number of
expansions and the nesting of groups and boxes (`LeAnTeX.Text.Settings`). The line breaker caps
the nodes of a paragraph, its active breakpoints and its steps (`LeAnTeX.Text.Params`, per
paragraph) and the steps over the whole document (`Settings.maxBreakWork`), so a paragraph costs
at most its step budget plus a constant per node, whatever its parameters. The page builder
takes at most `PageParams.maxSteps` steps, and at most four passes resolve references. The
TeX-rule layout has a budget of steps over each formula and caps the nesting of lists inside
lists.

```lean (name := textDefaults)
#eval let s : LeAnTeX.Text.Settings := {}
  (s.maxSource, s.maxTokens, s.maxExpansions, s.maxDepth, s.maxBreakWork)
```

```leanOutput textDefaults
(4000000, 1000000, 100000, 200, 100000000)
```

```lean (name := breakDefaults)
#eval let p : LeAnTeX.Text.Params := {}
  let pages : LeAnTeX.Doc.PageParams := { vsize := 0, maxDepth := 0, topSkip := {} }
  (p.maxNodes, p.maxActive, p.maxWork, pages.maxSteps, LeAnTeX.TeXMath.Budget.default)
```

```leanOutput breakDefaults
(1000000, 20000, 20000000, 10000000, 1000000)
```

A document asks for its images: `Settings.images` is the caller's function from a path to the
file's bytes. Before it is called, the path is checked: relative, no `..` segment, and only
letters, digits, `.`, `_`, `-` and `/`. Each image may have at most `Settings.maxImage` bytes and
the distinct images of a document together `Settings.maxImagesTotal`; an image is PNG or SVG
with a size, and an SVG image is drawn as an image, so its scripts do not run in the document.

```lean (name := imageDefaults)
#eval let s : LeAnTeX.Text.Settings := {}
  (s.maxImage, s.maxImagesTotal, LeAnTeX.Text.Typeset.safeImagePath "images/a.png",
    LeAnTeX.Text.Typeset.safeImagePath "../secret.png")
```

```leanOutput imageDefaults
(16777216, 33554432, true, false)
```

Past the caps, time and memory still grow with the source, with large constants where the output
is large. The document layer's own document gives an example and the advice that follows from
it:

{quoteSection "docs/documents.md" "Bounds and untrusted input"}

# Fonts
%%%
tag := "untrusted-fonts"
%%%

A font file is untrusted input too. The OpenType reader checks every offset against the end of
the table it is in, has no `partial` definition and no operation that can panic, and bounds its
work by the input (charstring operators, subroutine nesting, composite glyphs, the entries read
from layout tables). The TFM reader checks a metric file as TeX does before any of it is used.

{quoteSection "docs/opentype.md" "Untrusted input"}

# Output
%%%
tag := "untrusted-output"
%%%

Everything the SVG and HTML back ends write that comes from the source — text, the formula's
source in titles and alternative text, colour names — is escaped or checked against a strict
form ({name}`LeAnTeX.Backend.escape`, {name}`LeAnTeX.Backend.cssColor?`). The output holds no
script and no event handler. What of this is proved and what is tested is stated in
{ref "proofs"}[What Is Proved]:

{quoteSection "docs/back-ends.md" "Untrusted input"}

The library's tests run the command-line programs on hostile sources (deep nesting, runaway
macros, paragraphs with thousands of active breakpoints, oversized files, images included many
times) under a limit on processor time, and hold each to its exit status and to ceilings on its
peak memory and processor time, measured after the run: `lake exe leantex-test --bounds`.

These are budgets on particular operations and ceilings measured on those sources, not a proof
that every stage costs time or memory in proportion to its input, and the tests set no limit on
memory: a program that takes sources from strangers runs LeAnTeX under hard limits of its own
(a time-out, a memory limit on the process). With `trust` set, `\href`, `\url`,
`\includegraphics` and the other commands KaTeX gates are accepted for any URL whose protocol
parses, as in KaTeX: `trust` is not a list of safe schemes.
