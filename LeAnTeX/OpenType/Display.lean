/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.OpenType
import LeAnTeX.Layout.Display

/-!
# Glyph outlines in the display list

A glyph of a font read by `LeAnTeX.OpenType` drawn as a display-list `Item.path`: its outline
as SVG path data in font units, with `y` pointing down as the display list's does, in the
rectangle of the glyph's tight box placed at the glyph's baseline origin. A back end draws it
like any other path, without the font.

## Main definitions

* `fixedText`: an `Int` in 1/65536 as an exact decimal.
* `Font.glyphPathData`: a glyph's outline as SVG path data and its view box.
* `Font.glyphItem`: the glyph as a path item at a size and position.
-/

namespace LeAnTeX.OpenType

/-- `v / 65536` as an exact decimal: no exponent, no trailing zeros, no point for an integer
(`-1.5`, `0.0000152587890625`, `3`). -/
def fixedText (v : Int) : String :=
  let a := v.natAbs
  let whole := a / 65536
  let frac := a % 65536
  -- frac / 2¹⁶ = frac · 5¹⁶ / 10¹⁶, sixteen exact decimals.
  let digits := Nat.toDigits 10 (frac * 5 ^ 16)
  let padded := List.replicate (16 - digits.length) '0' ++ digits
  let trimmed := (padded.reverse.dropWhile (· == '0')).reverse
  (if v < 0 then "-" else "") ++ toString whole ++
    (if trimmed.isEmpty then "" else "." ++ String.ofList trimmed)

namespace Font

variable (f : Font)

/-- A glyph's outline as SVG path data in font units with `y` pointing down, and its view box
(`xMin -yMax width height`, the glyph's tight box); `none` for a glyph without points. -/
def glyphPathData (g : Nat) : Result (Option (String × String × Bounds Int)) := do
  let p ← f.outline g
  let some b := p.bounds | return none
  let down : Path Int := ⟨p.cmds.map fun
    | .move q => .move ⟨q.x, -q.y⟩
    | .line q => .line ⟨q.x, -q.y⟩
    | .quad c q => .quad ⟨c.x, -c.y⟩ ⟨q.x, -q.y⟩
    | .cubic c1 c2 q => .cubic ⟨c1.x, -c1.y⟩ ⟨c2.x, -c2.y⟩ ⟨q.x, -q.y⟩
    | .close => .close⟩
  let vb := s!"{fixedText b.xMin} {fixedText (-b.yMax)} {fixedText (b.xMax - b.xMin)} \
    {fixedText (b.yMax - b.yMin)}"
  return some (down.svgData fixedText, vb, b)

/-- Glyph `g` at `size` (em per em of the font) with its baseline origin at `(x, y)`, as a
display-list path item filling the glyph's tight box; `none` for a glyph without points. -/
def glyphItem (g : Nat) (x y size : Em) (color : Option String := none)
    (source : Option SourceRange := none) : Result (Option Item) := do
  let some (data, vb, b) ← f.glyphPathData g | return none
  let scale := fun (v : Int) => (⟨Em.roundDiv (v * size.raw) (f.unitsPerEm * 65536)⟩ : Em)
  return some (.path data vb "none" (x + scale b.xMin) (y - scale b.yMax)
    (scale (b.xMax - b.xMin)) (scale (b.yMax - b.yMin)) none color source)

end Font

end LeAnTeX.OpenType
