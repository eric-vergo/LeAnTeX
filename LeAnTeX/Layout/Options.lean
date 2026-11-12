/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Layout.Metrics
import LeAnTeX.Parse.Base

/-!
# Styles and options

TeX's eight math styles and the options a group is laid out with: style, size, font, colour.

## Main definitions

* `MathStyle`: display, text, script, scriptscript, each cramped or not, with TeX's transitions
  (KaTeX's `Style`).
* `Options`: KaTeX's `Options`, with `havingStyle`, `havingSize`, `withFont` and the rest, and
  the sizing classes a size change puts on a span.

## References

* KaTeX's `src/Style.ts` and `src/Options.ts` (MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- A math style: KaTeX's style id, 0 to 7 (`D`, `D'`, `T`, `T'`, `S`, `S'`, `SS`, `SS'`). -/
structure MathStyle where
  /-- The id: twice the size, plus one when cramped. -/
  id : Nat
  deriving BEq, DecidableEq, Inhabited, Repr

namespace MathStyle

/-- Display style. -/
def display : MathStyle := ⟨0⟩
/-- Text style. -/
def text : MathStyle := ⟨2⟩
/-- Script style. -/
def script : MathStyle := ⟨4⟩
/-- Scriptscript style. -/
def scriptscript : MathStyle := ⟨6⟩

/-- The size: 0 display, 1 text, 2 script, 3 scriptscript. -/
def size (s : MathStyle) : Nat := s.id / 2

/-- Whether the style is cramped. -/
def cramped (s : MathStyle) : Bool := s.id % 2 == 1

/-- The style id after a transition table. -/
private def step (table : Array Nat) (s : MathStyle) : MathStyle := ⟨table[s.id]!⟩

/-- The style of a superscript. -/
def sup : MathStyle → MathStyle := step #[4, 5, 4, 5, 6, 7, 6, 7]
/-- The style of a subscript. -/
def sub : MathStyle → MathStyle := step #[5, 5, 5, 5, 7, 7, 7, 7]
/-- The style of a numerator. -/
def fracNum : MathStyle → MathStyle := step #[2, 3, 4, 5, 6, 7, 6, 7]
/-- The style of a denominator. -/
def fracDen : MathStyle → MathStyle := step #[3, 3, 5, 5, 7, 7, 7, 7]
/-- The cramped version. -/
def cramp : MathStyle → MathStyle := step #[1, 1, 3, 3, 5, 5, 7, 7]
/-- The text style of the same crampedness (for display and text) or text style. -/
def textOf : MathStyle → MathStyle := step #[0, 1, 2, 3, 2, 3, 2, 3]

/-- Script and scriptscript styles are tight (`mtight`). -/
def isTight (s : MathStyle) : Bool := s.size ≥ 2

/-- The style a `\displaystyle`-like command names (`display`, `text`, `script`,
`scriptscript`). -/
def ofName : String → MathStyle
  | "display" => display
  | "text" => text
  | "script" => script
  | _ => scriptscript

end MathStyle

/-- KaTeX's size multipliers, sizes 1 to 11 (`\tiny` … `\Huge`; 6 is `\normalsize`). -/
def sizeMultipliers : Array Em :=
  #[0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.2, 1.44, 1.728, 2.074, 2.488]

/-- The size of script and scriptscript material at each size (KaTeX's `sizeStyleMap`). -/
def sizeStyleMap : Array (Nat × Nat × Nat) :=
  #[(1, 1, 1), (2, 1, 1), (3, 1, 1), (4, 2, 1), (5, 2, 1), (6, 3, 1), (7, 4, 2), (8, 6, 3),
    (9, 7, 6), (10, 8, 7), (11, 10, 9)]

/-- The size of material in `style` at text size `size` (KaTeX's `sizeAtStyle`). -/
def sizeAtStyle (size : Nat) (style : MathStyle) : Nat :=
  if style.size < 2 then size
  else
    let (_, b, c) := sizeStyleMap[size - 1]!
    if style.size == 2 then b else c

/-- The options a group is laid out with (KaTeX's `Options`). -/
structure Options where
  /-- The math style. -/
  style : MathStyle
  /-- The colour, if set. -/
  color : Option String := none
  /-- The size, 1 to 11. -/
  size : Nat := 6
  /-- The size of text style at this point (the size before script styles shrank it). -/
  textSize : Nat := 6
  /-- Inside a phantom: drawn transparent. -/
  phantom : Bool := false
  /-- The math font (`mathbf`, `mathrm`, …), or empty. -/
  font : String := ""
  /-- The text font family (`textrm`, `textsf`, `texttt`), or empty. -/
  fontFamily : String := ""
  /-- The text font weight (`textbf`, `textmd`), or empty. -/
  fontWeight : String := ""
  /-- The text font shape (`textit`, `textup`), or empty. -/
  fontShape : String := ""
  /-- The size's multiplier. -/
  sizeMultiplier : Em := 1
  /-- The largest size a user may give (`maxSize`); `none` for no limit. -/
  maxSize : Option Em := none
  /-- The least rule thickness (`minRuleThickness`). -/
  minRuleThickness : Em := 0
  /-- The strict-mode behaviour. -/
  strict : Strict := .warn
  deriving Inhabited

namespace Options

/-- The base size (`\normalsize`). -/
def baseSize : Nat := 6

/-- `o` with a new size: the size's multiplier follows. -/
def withSize (o : Options) (size : Nat) : Options :=
  { o with size, sizeMultiplier := sizeMultipliers[size - 1]! }

/-- The options in another style (`havingStyle`). -/
def havingStyle (o : Options) (style : MathStyle) : Options :=
  if o.style == style then o
  else { o.withSize (sizeAtStyle o.textSize style) with style }

/-- The options in the cramped style. -/
def havingCrampedStyle (o : Options) : Options := o.havingStyle o.style.cramp

/-- The options at another size, in text style (`havingSize`). -/
def havingSize (o : Options) (size : Nat) : Options :=
  if o.size == size && o.textSize == size then o
  else { o.withSize size with style := o.style.textOf, textSize := size }

/-- The options of `style` at the base size (`havingBaseStyle`). -/
def havingBaseStyle (o : Options) (style : MathStyle) : Options :=
  let want := sizeAtStyle baseSize style
  if o.size == want && o.textSize == baseSize && o.style == style then o
  else { o.withSize want with style }

/-- The options at the normal size for the current style class (`havingBaseSizing`). -/
def havingBaseSizing (o : Options) : Options :=
  let size := match o.style.id with
    | 4 | 5 => 3
    | 6 | 7 => 1
    | _ => 6
  { o.withSize size with style := o.style.textOf }

/-- The options with a colour. -/
def withColor (o : Options) (color : String) : Options := { o with color := some color }

/-- The options inside a phantom. -/
def withPhantom (o : Options) : Options := { o with phantom := true }

/-- The options with a math font. -/
def withFont (o : Options) (font : String) : Options := { o with font }

/-- The options with a text font family; the math font is reset. -/
def withTextFontFamily (o : Options) (fontFamily : String) : Options :=
  { o with fontFamily, font := "" }

/-- The options with a text font weight; the math font is reset. -/
def withTextFontWeight (o : Options) (fontWeight : String) : Options :=
  { o with fontWeight, font := "" }

/-- The options with a text font shape; the math font is reset. -/
def withTextFontShape (o : Options) (fontShape : String) : Options :=
  { o with fontShape, font := "" }

/-- The classes that change the font size from `old`'s to `o`'s (`sizingClasses`). -/
def sizingClasses (o old : Options) : Array String :=
  if old.size != o.size then
    #["katex-sizing", s!"reset-size{old.size}", s!"size{o.size}"]
  else #[]

/-- The classes that reset the font size to the base size (`baseSizingClasses`). -/
def baseSizingClasses (o : Options) : Array String :=
  if o.size != baseSize then
    #["katex-sizing", s!"reset-size{o.size}", s!"size{baseSize}"]
  else #[]

/-- The font parameters at this size. -/
def fontMetrics (o : Options) : FontParams := fontParams o.size

/-- The colour to draw with: transparent in a phantom. -/
def getColor (o : Options) : Option String :=
  if o.phantom then some "transparent" else o.color

end Options

end LeAnTeX
