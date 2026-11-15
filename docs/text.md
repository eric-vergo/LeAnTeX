# Text mode

LeAnTeX's text layer sets paragraphs of LaTeX source into lines as TeX sets them: the same
horizontal lists, the same hyphenation points, the same line breaks, the same glue settings,
the same total demerits, the same interline spacing. It is checked against LuaLaTeX (TeX Live
2025) on every case of the text corpora (`docs/text-reference.md`). Every length is an integer
number of TeX's scaled points (sp, 2⁻¹⁶ pt), so the arithmetic is TeX's exactly.

```lean
import LeAnTeX
open LeAnTeX.Text

-- fonts are the caller's: a resolver from font keys to fonts read with `LeAnTeX.OpenType`
def resolve (fonts : Std.HashMap String FontInfo) : FontResolver :=
  fun k => fonts[latinModernFile k]?

match typeset "Hello, \\emph{world}. $x^2$ is a formula." (resolve fonts) with
| .ok doc => doc.toDisplayList        -- lines of positioned glyphs, rules and paths
| .error e => …                        -- e.message, e.pos (character offset in the source)
```

`lake exe leantex-typeset FILE` typesets a file with Latin Modern (read from TeX Live when it
is installed, else the committed test font) and prints the display list as text
(`DisplayList.textForm`); `fixtures/typeset/` holds its goldens.

## The parts

| Module | What |
|---|---|
| `LeAnTeX.Text.Node` | horizontal lists: glyphs, kerns, glue, penalties, discretionaries, boxes, rules, formulas |
| `LeAnTeX.Text.Hyphen` | Liang's hyphenation; plain TeX's English patterns (LaTeX's default) and hyph-utf8's `usenglishmax` |
| `LeAnTeX.Text.LineBreak` | TeX's line breaker (`breakParagraph`) |
| `LeAnTeX.Text.Pack` | the lines from the breaks (`setLines`): their nodes and glue settings |
| `LeAnTeX.Text.Font` | a font at a size: glyphs, TeX ligatures, the font's ligatures and kerns, discretionaries at hyphenation points, interword glue |
| `LeAnTeX.Text.Source` | tokens with LaTeX's category codes; TeX's units |
| `LeAnTeX.Text.Typeset` | the front end (`typeset`): source to a `Document` |
| `LeAnTeX.Text.LatinModern` | which Latin Modern file LaTeX loads for a font |
| `LeAnTeX.Text.Output` | a `Document` as a display list |
| `LeAnTeX.Text.Proofs` | theorems (below) |

## Agreement with TeX

| What | Cases | Agreement |
|---|---|---|
| Hyphenation points (`Patterns.english`, minima 2 and 3) | 1,691 words, 2,686 points | every point |
| Line breaker on TeX's own item lists (`breakParagraph`, `setLines`) | 174 paragraphs | every break, total demerits, line length and shift, natural width, glue sign, order and ratio |
| Front end on the corpus source (`typeset`) | 174 paragraphs | every node of the horizontal list TeX's line breaker received, every line, and the paragraph box's height and depth |
| Glyphs, ligatures, kerns and widths of boxes (font reader) | 72 boxes | every glyph and kern |

The paragraphs cover running prose at seven widths, italic, bold, sans serif, typewriter and
slanted fonts, three sizes, every line-breaking parameter (tolerance, pretolerance, looseness,
emergency stretch, the demerits, the penalties), ragged and centred setting, hanging
indentation, `\parshape`, overfull lines, ties, forced breaks, explicit glue, kerns, boxes and
explicit hyphens.

## How it reproduces LuaLaTeX

* **Line breaking** is TeX's algorithm (`tex.web` parts 38 and 39, followed from the published
  description): legal breakpoints, badness, fitness classes, demerits with the adjacent, double
  hyphen and final hyphen terms, the first pass without pattern hyphenation, the second, the
  third with `\emergencystretch`, looseness, hanging indentation and `\parshape`. Ties between
  equally good breaks are resolved as TeX resolves them (the active list in TeX's order).
* **Glue ratios** are rounded to single precision, as LuaTeX stores them.
* **Interword glue** comes from the font's space character: its width, a half of it as stretch
  and a third as shrink, a third as the extra space after a sentence, as luaotfload derives TeX's
  font dimensions from an OpenType font, scaled by TeX's space-factor rules (LaTeX's
  `\nonfrenchspacing` codes); none of the three for a monospaced font, as LaTeX's typewriter
  families set them.
* **Glyph metrics**: advances, and heights and depths from the glyphs' tight boxes, scaled and
  rounded to the nearest sp.
* **Hyphenation** as LuaTeX applies it: a run of letters that starts the list or follows a
  glue, a box or a non-letter character, not one right after a penalty, a kern, a discretionary
  or an explicit hyphen; plain TeX's patterns (TeX Live's language 0, LaTeX's default for
  English); no hyphenation in a monospaced font.
* **Discretionaries** as luaotfload builds them: a hyphenation point between two glyphs is a
  hyphen before the break and the kern between them when not broken; a point inside a ligature
  takes the ligature's characters into the discretionary (`f-` / `f` / `ff`).
* **Explicit hyphens** are followed by a discretionary that holds the hyphen, with
  `\exhyphenpenalty`.

## The front end: what it understands

Paragraphs (an empty line, `\par`, `\noindent`, `\indent`), `\\` and `\newline`, `~`, `\ `,
`\,`, `\quad`, `\qquad`, `\enspace`, `\hspace` (and `\hspace*`), `\vspace`, `\hfill`, `\hfil`,
`\hss`, `\hskip`, `\kern`, `\penalty`, `\nobreak`, `\break`, `\allowbreak`, `\-`; the font
commands `\textrm` `\textsf` `\texttt` `\textbf` `\textmd` `\textit` `\textsl` `\textsc`
`\textup` `\textnormal` `\emph` and their declarations, `\em`, the sizes `\tiny` to `\Huge`
(LaTeX's ten-point classes, with their `\baselineskip`), `\fontsize{…}{…}\selectfont`; `\hbox`,
`\mbox`; formulas `$…$`, `\(…\)`, `\[…\]`, `$$…$$` through the math layout at the text size;
`\newcommand`, `\renewcommand`, `\providecommand` (up to nine parameters, an optional first),
`\def` with undelimited parameters, all local to groups and available in formulas; TeX's
parameter assignments for the line breaker's parameters, `\hsize`, `\parindent`, `\parskip`,
`\baselineskip`, `\leftskip`, `\rightskip`, `\parfillskip`, `\hangindent`, `\hangafter`,
`\parshape`, and `\setlength`; the units `pt pc in bp cm mm dd cc sp em ex` and `fil`, `fill`,
`filll`, converted as TeX converts them; `\%`, `\&`, `\#`, `\$`, `\_`, `\{`, `\}`,
`\textbackslash`; TeX's ligatures for dashes and quotes.

The defaults are LaTeX's article class at ten points: `\hsize` 345 pt, `\parindent` 15 pt,
`\baselineskip` 12 pt, `\parskip` 0 pt plus 1 pt, `\tolerance` 200, `\pretolerance` 100,
`\hyphenpenalty` and `\exhyphenpenalty` 50.

## Not implemented, against a full LaTeX

* **Document structure**: environments (`\begin…\end`), lists, sectioning, counters,
  cross-references, footnotes, floats, tables, the title, page breaking and the page itself
  (the document layer, next).
* **Vertical material**: the lines are stacked with `\baselineskip`, `\lineskip` and
  `\lineskiplimit` and `\parskip` at its natural size; vertical glue is never stretched or
  shrunk. `\vspace` inside a paragraph takes effect after the paragraph, not after its line.
  Displayed formulas have LaTeX's 10 pt above and below at their natural size; the short skips,
  `\predisplaysize` and equation numbers placed by TeX's rules are left out (KaTeX's tags are
  drawn by the math layout).
* **TeX's programming layer**: `\let`, `\edef`, `\expandafter`, conditionals, registers,
  `\catcode`, delimited macro parameters, `\csname`; accents (`\'e`, `\"o`), `\char`,
  `\vadjust`, `\vbox`, `\raisebox`, rules (`\rule`), leaders, `\discretionary`, inserts and
  marks.
* **In the line breaker**: `\lastlinefit`, margin kerning and font expansion (off in LaTeX).
  Formulas are unbreakable boxes; TeX breaks a formula after a relation or a binary operator.
* **In the fonts**: only `liga` and `kern` (and TeX's `tlig`); no other OpenType features, no
  contextual or script-specific shaping, no font fallback. A word split by a font change is
  hyphenated as two words.

## Bounds

Source is untrusted. The front end caps the source length, the tokens all macro expansions
produce together (`Settings.maxTokens`), the number of expansions and the nesting of groups
and boxes; past a cap the result is an error, never a hang. The line breaker caps the nodes and
the active breakpoints (`Params.maxNodes`, `Params.maxActive`). There is no `partial`
definition: every loop has a bound from its input. The tests run 900 mutated sources and 400
random horizontal lists, each ending in a result or a clean error.

## Proved and tested

Proved (`LeAnTeX.Text.Proofs`, axioms `propext`, `Classical.choice`, `Quot.sound` only):

* `breakParagraph_legal`, `breakParagraph_increasing`, `breakParagraph_ends`: every break the
  line breaker returns is a legal breakpoint of its input or its end, the breaks increase, and
  the last is the end. The line breaker checks its result before returning it (`checkBreaks`),
  so these hold by construction; the algorithm itself is tested, not proved.
* `lineRanges_first`, `lineRanges_stop`, `lineRanges_next`: the lines take the input's nodes in
  order, each ending at its break, the next starting after it with only discardable nodes
  between: the lines together are the input without the nodes dropped at breaks.
* `points_minima`: no hyphenation point is closer than the minima to a word's ends.
* `badness_le`: a badness is at most 10000.

Tested only: everything else, against TeX as above.
