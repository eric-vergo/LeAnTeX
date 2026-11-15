/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.TeXMath.Tfm
import LeAnTeX.TeXMath.Node
import LeAnTeX.Text.Font

/-!
# The fonts of a formula

A formula's characters come from math families, sixteen slots each holding a font for the
three sizes (text, script, scriptscript), as in TeX. A font is a metric file at a size
(`TfmFont`), or an OpenType font of the text layer at a size (the families LaTeX's `fontspec`
gives `\mathrm`, `\mathbf`, `\operatorname` and the other alphabets): its characters are
Unicode code points, measured from the font's advances and glyph boxes as luaotfload measures
them, without italic corrections, ligatures or kerns.

## Main definitions

* `MathFont`: a metric font or an OpenType font at a size, with `char?`, `ligKern`, `param`.
* `MathSize`: text, script or scriptscript.
* `Families`: the fonts of a formula and the family table.
-/

namespace LeAnTeX.TeXMath

open LeAnTeX.Text (TextFont)

/-- A font of a math family. -/
inductive MathFont where
  /-- A TeX metric file at a size. -/
  | tfm (f : TfmFont)
  /-- An OpenType font of the text layer at a size (characters by code point). -/
  | otf (f : TextFont)
  deriving Inhabited

/-- The italic correction luaotfload gives a glyph of a slanted OpenType font (one whose `post`
italic angle is not 0): the part of its outline right of its advance plus a fiftieth of the em,
when that is positive; 0 for an upright font. Found against LuaTeX's lists. -/
def italicOf (f : TextFont) (g : Nat) : Int :=
  let angle := (f.info.font.post.map (·.italicAngle)).getD 0
  if angle == 0 then 0
  else match f.info.font.bounds g with
    | .ok (some b) =>
      let over := Em.roundDiv b.xMax 65536 - f.info.font.advance g
      let it := over + f.info.font.unitsPerEm / 50
      if it > 0 then f.scale it else 0
    | _ => 0

namespace MathFont

/-- The size, in sp. -/
def size : MathFont → Int
  | tfm f => f.size
  | otf f => f.size

/-- A name for messages and the display list. -/
def name : MathFont → String
  | tfm f => f.name
  | otf f => f.info.name

/-- The metrics of a character, if the font has it. -/
def char? : MathFont → Nat → Option CharMetrics
  | tfm f, c => f.char? c
  | otf f, c =>
    if c ≥ 0x110000 || (c ≥ 0xD800 && c < 0xE000) then none
    else
      let g := f.info.font.glyph (Char.ofNat c)
      if g == 0 then none
      else
        let (h, d) := f.info.boxes[g]?.getD (0, 0)
        some { width := f.scale (f.info.font.advance g), height := f.scale h,
               depth := f.scale d, italic := italicOf f g, tag := .none }

/-- The ligature or kern between two characters of the font (none for an OpenType font), with
the program steps walked to find it. -/
def ligKernSteps : MathFont → Nat → Nat → LigKern × Nat
  | tfm f, l, r => f.ligKernSteps l r
  | otf _, _, _ => (.none, 1)

/-- The ligature or kern between two characters of the font (none for an OpenType font). -/
def ligKern (f : MathFont) (l r : Nat) : LigKern := (f.ligKernSteps l r).1

/-- `\fontdimen n`: a metric file's parameter; for an OpenType font the interword space
(`n = 2`, which is not 0, as TeX's rule for text fonts in formulas needs) and the x-height
(`n = 5`, from the `OS/2` table), 0 otherwise. -/
def param : MathFont → Nat → Int
  | tfm f, n => f.param n
  | otf f, 2 => (f.space).width
  | otf f, 5 => f.scale (((f.info.font.os2.bind (·.xHeight)).getD 0))
  | otf _, _ => 0

/-- The number of parameters (the seven of a text font for an OpenType font). -/
def paramCount : MathFont → Nat
  | tfm f => f.paramCount
  | otf _ => 7

/-- The kern before the font's skew character (0 for an OpenType font), with the program
steps walked to find it. -/
def skewSteps : MathFont → Nat → Int × Nat
  | tfm f, c => f.skewSteps c
  | otf _, _ => (0, 1)

/-- The kern before the font's skew character (0 for an OpenType font). -/
def skew (f : MathFont) (c : Nat) : Int := (f.skewSteps c).1

/-- The extensible recipe of a character (none for an OpenType font). -/
def recipe? : MathFont → Nat → Option Recipe
  | tfm f, c => f.recipe? c
  | otf _, _ => none

end MathFont

/-- A math size: text (0), script (1) or scriptscript (2). -/
abbrev MathSize := Fin 3

/-- The fonts of a formula: the table of fonts (glyph nodes name fonts by their index in it)
and, for each of the sixteen families and three sizes, the font in that slot. -/
structure Families where
  /-- The fonts. -/
  fonts : Array MathFont := #[]
  /-- For family `f` and size `s`, at index `3 * f + s`, the index of its font. -/
  table : Array (Option Nat) := Array.replicate 48 none
  deriving Inhabited

namespace Families

/-- The font index of a family at a size. -/
def index? (fs : Families) (fam : Nat) (s : MathSize) : Option Nat :=
  if fam < 16 then (fs.table[3 * fam + s.val]?).join else none

/-- The font of a family at a size. -/
def font? (fs : Families) (fam : Nat) (s : MathSize) : Option MathFont := do
  fs.fonts[← fs.index? fam s]?

/-- The family table with font `font` (an index) in family `fam` at size `s`. -/
def set (fs : Families) (fam : Nat) (s : MathSize) (font : Nat) : Families :=
  if fam < 16 then { fs with table := fs.table.setIfInBounds (3 * fam + s.val) (some font) } else fs

/-- Adds a font to the table, returning its index (an equal entry, by name and size, is
reused). -/
def addFont (fs : Families) (f : MathFont) : Families × Nat :=
  match fs.fonts.findIdx? (fun g => g.name == f.name && g.size == f.size) with
  | some i => (fs, i)
  | none => ({ fs with fonts := fs.fonts.push f }, fs.fonts.size)

end Families

end LeAnTeX.TeXMath
