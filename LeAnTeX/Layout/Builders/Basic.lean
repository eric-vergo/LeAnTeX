/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Layout.Html

/-!
# Symbols, groups, styles, sizes, fonts and colours

The builders of the constructs that lay out their contents in a changed context, or a single
symbol: ordinary symbols and atoms, spaces, groups, `\displaystyle` and friends, `\large` and
friends, `\mathbf` and friends, `\text` and friends, `\mathrel` and friends, colour, kerns.

## Main definitions

* `buildSymbol`: mathord, textord, atoms and spaces.
* `sizingGroup`: a list in a new size, its spans tagged with the size change.
* `buildOrdgroup`, `buildStyling`, `buildSizing`, `buildFont`, `buildText`, `buildMclass`,
  `buildColor`, `buildKern`.

## References

* KaTeX's `src/functions/symbolsOrd.ts`, `symbolsOp.ts`, `symbolsSpacing.ts`, `ordgroup.ts`,
  `styling.ts`, `sizing.ts`, `font.ts`, `text.ts`, `mclass.ts`, `color.ts` and `kern.ts`
  (MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- A symbol node: a mathord or textord in its font, an atom in Main or AMS with its class, or
a space. -/
def buildSymbol (mode : Mode) (group : Group) (text : String) (o : Options) : BuildM Box := do
  match group with
  | .mathord => makeOrd true mode text o
  | .textord => makeOrd false mode text o
  | .spacing =>
    let regular : Option String := match text with
      | " " | "\\ " | "\\space" => some ""
      | "~" | "\\nobreakspace" => some "nobreak"
      | _ => none
    let css : Option String := match text with
      | "\\nobreak" => some "nobreak"
      | "\\allowbreak" => some "allowbreak"
      | _ => none
    match regular, css with
    | some cls, _ =>
      if mode == .text then
        let ord ← makeOrd false mode text o
        return ord.addClass cls
      else
        return makeSpan #["mspace", cls] #[← mathsym text mode o] (some o)
    | none, some cls => return makeSpan #["mspace", cls] #[] (some o)
    | none, none => throwParse s!"Unknown type of space \"{text}\""
  | .opToken => throwParse "Got group of unknown type: 'op-token'"
  | .accentToken => throwParse "Got group of unknown type: 'accent-token'"
  | g => mathsym text mode o #["m" ++ g.name]

/-- A group: a span of class `mord`, or for `\begingroup … \endgroup` the bare list. -/
def buildOrdgroup (ctx : BuildCtx) (body : Array Node) (semisimple : Option Bool) (o : Options) :
    BuildM Box := do
  if semisimple == some true then return makeFragment (← ctx.expr body o .no)
  return makeSpan #["mord"] (← ctx.expr body o .yes) (some o)

/-- A list laid out in `o`, a size change from `base`: each box gets the sizing classes (or has
its reset class rewritten to the outer size) and its height and depth scaled to the outer size
(`sizingGroup`). -/
def sizingGroup (ctx : BuildCtx) (body : Array Node) (o base : Options) : BuildM Box := do
  let inner ← ctx.expr body o .no
  let multiplier := o.sizeMultiplier / base.sizeMultiplier
  let out := inner.map fun b =>
    let b := match b.classes.idxOf? "katex-sizing" with
      | none => { b with classes := b.classes ++ o.sizingClasses base }
      | some pos =>
        if b.classes[pos + 1]? == some s!"reset-size{o.size}" then
          { b with classes := b.classes.set! (pos + 1) s!"reset-size{base.size}" }
        else b
    { b with height := b.height * multiplier, depth := b.depth * multiplier }
  return makeFragment out

/-- `\displaystyle` and friends. -/
def buildStyling (ctx : BuildCtx) (style : String) (resetFont : Option Bool) (body : Array Node)
    (o : Options) : BuildM Box := do
  let o' := o.havingStyle (MathStyle.ofName style)
  let o' := if resetFont == some true then o'.withFont "" else o'
  sizingGroup ctx body o' o

/-- `\tiny` … `\Huge`. -/
def buildSizing (ctx : BuildCtx) (size : Nat) (body : Array Node) (o : Options) : BuildM Box :=
  sizingGroup ctx body (o.havingSize size) o

/-- `\mathbf` and the other math fonts. -/
def buildFont (ctx : BuildCtx) (font : String) (body : Node) (o : Options) : BuildM Box :=
  ctx.group body (o.withFont font) none

/-- The options of a `\text`-like command (`optionsWithFont`). -/
def textOptions (font : Option String) (o : Options) : Options :=
  match font with
  | none => o
  | some f =>
    match f with
    | "\\textrm" | "\\textnormal" => o.withTextFontFamily "textrm"
    | "\\textsf" => o.withTextFontFamily "textsf"
    | "\\texttt" => o.withTextFontFamily "texttt"
    | "\\textbf" => o.withTextFontWeight "textbf"
    | "\\textmd" => o.withTextFontWeight "textmd"
    | "\\emph" => o.withTextFontShape (if o.fontShape == "textit" then "textup" else "textit")
    | "\\textit" => o.withTextFontShape "textit"
    | "\\textup" => o.withTextFontShape "textup"
    | _ => o.withTextFontShape ""

/-- `\text` and the other text commands. -/
def buildText (ctx : BuildCtx) (body : Array Node) (font : Option String) (o : Options) :
    BuildM Box := do
  let o' := textOptions font o
  return makeSpan #["mord", "text"] (← ctx.expr body o' .yes) (some o')

/-- `\mathrel` and the other class commands. -/
def buildMclass (ctx : BuildCtx) (mclass : String) (body : Array Node) (o : Options) :
    BuildM Box := do
  return makeSpan #[mclass] (← ctx.expr body o .yes) (some o)

/-- `\color` and `\textcolor`: the body in the colour, as part of the surrounding list. -/
def buildColor (ctx : BuildCtx) (color : String) (body : Array Node) (o : Options) :
    BuildM Box := do
  return makeFragment (← ctx.expr body (o.withColor color) .no)

/-- `\kern` and the other explicit spaces. -/
def buildKern (dimension : Measurement) (o : Options) : BuildM Box := makeGlue dimension o

end LeAnTeX
