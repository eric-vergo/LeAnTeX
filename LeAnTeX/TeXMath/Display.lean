/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.TeXMath.Font
import LeAnTeX.TeXMath.Data.Glyphs
import LeAnTeX.Layout.Display

/-!
# Drawing the TeX-rule layout's boxes

A list of boxes as positioned drawing operations, as TeX's `hlist_out` and `vlist_out` place
them (glue at its set size, the stretch or shrink of the set order accumulated and the running
total rounded): glyphs and rules of the display list (`LeAnTeX.DisplayList`).

The Computer Modern metric files have no outlines here: a character of a metric font is drawn
with the glyph of New Computer Modern Math (`NewCMMath-Book.otf`) that shows the same symbol
(`LeAnTeX.TeXMath.Data.Glyphs`), at the position and size TeX's metrics give it, a `cmex` size
variant through the back ends' `Size1`–`Size4` faces (the math font's `MATH` variants); a
character of an OpenType text font with that font. The drawing is a choice of shapes, not of positions:
every box keeps TeX's dimensions.

## Main definitions

* `drawFont`: the face and character a font's character is drawn with.
* `itemsOf`: a list's items at a position.
* `displayListOf`: a formula's list as a display list in em of its size.
-/

namespace LeAnTeX.TeXMath

open LeAnTeX.Text (GlueSet)

/-- The file of the font metric characters are drawn with. -/
def mathDrawFont : String := "NewCMMath-Book.otf"

/-- The face and character a font's character is drawn with: a metric font's by
`Data.Glyphs.unicodeOf`, an OpenType font's as itself in that font. -/
def drawFont (f : MathFont) (code : Nat) : Option (Face × Char) :=
  match f with
  | .tfm t =>
    match Data.largeOf t.name code with
    | some (face, u) =>
      -- a size variant: the back end's KaTeX `Size` faces pick the math font's variant
      if face.isEmpty then some ({ font := some mathDrawFont, family := mathDrawFont }, u)
      else some ({ family := face }, u)
    | none =>
      (Data.unicodeOf t.name code).map fun u =>
        ({ font := some mathDrawFont, family := mathDrawFont }, u)
  | .otf t =>
    some ({ font := some t.info.name, family := t.info.name, slant := t.info.slant,
            smallCaps := t.info.smallCaps }, Char.ofNat code)

/-- A float rounded to the nearest integer, within ±2³⁰ (TeX's glue bound). -/
def roundGlueFloat (v : Float) : Int :=
  let v := if v > 1073741823 then 1073741823 else if v < -1073741823 then -1073741823 else v
  let r := (v.abs + 0.5).floor
  let n : Int := r.toUInt64.toNat
  if v < 0 then -n else n

/-- The size each glue of a box set with `g` takes, in order. -/
def glueSizesOf (g : GlueSet) (l : Array Node) : Array Int := Id.run do
  let mut out := #[]
  let mut total : Float := 0
  let mut done : Int := 0
  for n in l do
    if let .glue gl _ := n then
      let mut w := gl.width
      if g.sign == 1 && gl.stretchOrder == g.order then
        total := total + Float.ofInt gl.stretch
        let now := roundGlueFloat (g.ratio * total)
        w := w + now - done
        done := now
      else if g.sign == 2 && gl.shrinkOrder == g.order then
        total := total - Float.ofInt gl.shrink
        let now := roundGlueFloat (g.ratio * total)
        w := w + now - done
        done := now
      out := out.push w
  return out

/-- The items of a list (lengths in sp): horizontal from `x` on the baseline `y`, or vertical
from the top `y` at the left edge `x`, of a box `boxW` wide, `boxH` high and `boxD` deep (for
running rules); boxes nested deeper than `fuel` are left out. -/
def itemsOf (fs : Families) : Nat → Bool → Array Node → GlueSet → Int → Int → Int → Int →
    Int → Array Item
  | 0, _, _, _, _, _, _, _, _ => #[]
  | fuel + 1, vertical, l, g, x, y, boxW, boxH, boxD => Id.run do
    let sizes := glueSizesOf g l
    let mut out : Array Item := #[]
    let mut k := 0
    let mut cx := x
    let mut cy := y
    for n in l do
      match n with
      | .char f c w h d =>
        if let some font := fs.fonts[f]? then
          if let some (face, u) := drawFont font c then
            let base := if vertical then cy + h else cy
            out := out.push (.glyph face u ⟨cx⟩ ⟨base⟩ ⟨font.size⟩ true false none none)
        if vertical then cy := cy + h + d else cx := cx + w
      | .glyph f c _ w h d =>
        if let some font := fs.fonts[f]? then
          if let some (face, _) := drawFont font c.toNat then
            let base := if vertical then cy + h else cy
            out := out.push (.glyph face c ⟨cx⟩ ⟨base⟩ ⟨font.size⟩ true false none none)
        if vertical then cy := cy + h + d else cx := cx + w
      | .box v w h d s bg bl =>
        if vertical then
          out := out ++ itemsOf fs fuel v bl bg (cx + s) (if v then cy else cy + h) w h d
          cy := cy + h + d
        else
          out := out ++ itemsOf fs fuel v bl bg cx (if v then cy + s - h else cy + s) w h d
          cx := cx + w
      | .rule rw rh rd =>
        if vertical then
          let w := rw.getD boxW
          let h := rh.getD 0
          let d := rd.getD 0
          if w > 0 && h + d > 0 then out := out.push (.rule ⟨cx⟩ ⟨cy⟩ ⟨w⟩ ⟨h + d⟩ none none)
          cy := cy + h + d
        else
          let w := rw.getD 0
          let h := rh.getD boxH
          let d := rd.getD boxD
          if w > 0 && h + d > 0 then
            out := out.push (.rule ⟨cx⟩ ⟨cy - h⟩ ⟨w⟩ ⟨h + d⟩ none none)
          cx := cx + w
      | .glue .. =>
        let w := sizes.getD k 0
        k := k + 1
        if vertical then cy := cy + w else cx := cx + w
      | .kern w _ => if vertical then cy := cy + w else cx := cx + w
      | .math _ w => if !vertical then cx := cx + w
      | .penalty _ => pure ()
    return out

/-- A length in sp as em of a formula of size `size` (sp), rounded. -/
def emOf (size v : Int) : Em := ⟨Em.roundDiv (v * Em.unit) size⟩

/-- A list (horizontal, at its natural width) as a display list in em of `size`: its items,
width, height and depth. -/
def displayListOf (fs : Families) (l : Array Node) (size : Int) : DisplayList :=
  let b := hpack l
  let items := itemsOf fs 400 false l {} 0 0 b.width b.height b.depth
  let conv := fun (e : Em) => emOf size e.raw
  let items := items.map fun it => match it with
    | .glyph f c x y s e sh col src => .glyph f c (conv x) (conv y) (conv s) e sh col src
    | .rule x y w h col src => .rule (conv x) (conv y) (conv w) (conv h) col src
    | it => it
  let line : Line :=
    { start := 0, stop := items.size, width := emOf size b.width,
      height := emOf size b.height, depth := emOf size b.depth }
  { width := emOf size b.width, height := emOf size b.height, depth := emOf size b.depth,
    items, lines := #[line] }

end LeAnTeX.TeXMath
