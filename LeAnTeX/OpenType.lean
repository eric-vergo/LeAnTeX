/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.OpenType.Tables
import LeAnTeX.OpenType.Cff
import LeAnTeX.OpenType.Glyf
import LeAnTeX.OpenType.Layout
import LeAnTeX.OpenType.Math

/-!
# OpenType fonts

An OpenType font read from its bytes, in pure Lean: metrics, the character map, glyph
outlines (CFF or TrueType), ligatures and pair kerning, and the `MATH` table's constants.

A font file is untrusted input. `Font.read` checks every offset and length it follows, and
every query on the result is total: a malformed font is a `FontError`, never a crash, a hang
or an unbounded allocation (`LeAnTeX.OpenType.Binary`, and the limits in `Cff`, `Glyf` and
`Layout`).

## Main definitions

* `Font`, `Font.read`: the font. `Font.read` fails if a table it reads is malformed, the
  optional ones (`OS/2`, `post`, `kern`, `GSUB`, `GPOS`, `MATH`) included.
* `Font.glyph`, `Font.advance`, `Font.outline`, `Font.bounds`: a character's glyph, a glyph's
  advance width (font units), outline and tight box (1/65536 font units).
* `Font.ligate`, `Font.kerning`: the `liga` ligatures of a run of glyphs, and a pair's kerning.
* `Font.layoutText`: a string's glyphs with their advances after ligatures and kerning.
* `Font.mathConstant?`: a `MATH` constant by name.
-/

namespace LeAnTeX.OpenType

/-- Where a font's outlines are. -/
inductive Outlines where
  /-- The `CFF ` table. -/
  | cff (c : Cff)
  /-- The `glyf` and `loca` tables. -/
  | glyf (g : Glyf)

/-- A font, read. -/
structure Font where
  /-- The header. -/
  head : Head
  /-- The horizontal header. -/
  hhea : Hhea
  /-- The number of glyphs. -/
  numGlyphs : Nat
  /-- Horizontal metrics. -/
  hmtx : Hmtx
  /-- `OS/2`, if present. -/
  os2 : Option Os2
  /-- `post`, if present. -/
  post : Option Post
  /-- The names. -/
  names : Names
  /-- The character map. -/
  cmap : Cmap
  /-- The outlines. -/
  outlines : Outlines
  /-- Substitutions, if present. -/
  gsub : Option Gsub
  /-- Positioning, if present. -/
  gpos : Option Gpos
  /-- The old kerning table, if present. -/
  kern : Option KernTable
  /-- The `MATH` constants, if present, in the order of `mathConstantNames`. -/
  math : Option (Array Int)

/-- The optional table with the tag, read by `f` if present. -/
private def optional {α : Type} (d : Directory) (tag : String) (f : Slice → Result α) :
    Result (Option α) :=
  match d.find? tag with
  | some s => some <$> f s
  | none => .ok none

namespace Font

/-- Reads a font from the bytes of an OpenType file (one font, not a collection). -/
def read (data : ByteArray) : Result Font := do
  let d ← Directory.read data
  let head ← Head.read (← d.get "head")
  let hhea ← Hhea.read (← d.get "hhea")
  let n ← readNumGlyphs (← d.get "maxp")
  let hmtx ← Hmtx.read (← d.get "hmtx") n hhea.numberOfHMetrics
  let outlines ← match d.find? "CFF ", d.find? "glyf", d.find? "loca" with
    | some c, _, _ =>
      let c ← Cff.read c
      if c.charStrings.count < n then fail "CFF " "fewer charstrings than glyphs"
      pure (Outlines.cff c)
    | none, some g, some l => Outlines.glyf <$> Glyf.read l g n (head.indexToLocFormat == 1)
    | _, _, _ => fail "font" "no outlines (neither CFF nor glyf)"
  return {
    head, hhea, numGlyphs := n, hmtx, outlines
    os2 := ← optional d "OS/2" Os2.read
    post := ← optional d "post" Post.read
    names := (← optional d "name" Names.read).getD ⟨#[]⟩
    cmap := (← optional d "cmap" Cmap.read).getD .empty
    gsub := ← optional d "GSUB" Gsub.read
    gpos := ← optional d "GPOS" Gpos.read
    kern := ← optional d "kern" KernTable.read
    math := ← optional d "MATH" readMathConstants }

variable (f : Font)

/-- Font units per em. -/
def unitsPerEm : Nat := f.head.unitsPerEm

/-- The glyph of a character, 0 (`.notdef`) if the font has none or the map names a glyph
past the last. -/
def glyph (c : Char) : Nat :=
  let g := f.cmap.glyph c.toNat
  if g < f.numGlyphs then g else 0

/-- A glyph's advance width in font units (0 past the last glyph). -/
def advance (g : Nat) : Nat := f.hmtx.advances[g]?.getD 0

/-- A glyph's outline, in 1/65536 font units. -/
def outline (g : Nat) : Result (Path Int) :=
  if g ≥ f.numGlyphs then fail "font" s!"no glyph {g}"
  else match f.outlines with
    | .cff c => (·.path) <$> c.charstring g
    | .glyf gl => gl.outline g

/-- A glyph's tight box, in 1/65536 font units; `none` for a glyph without points. -/
def bounds (g : Nat) : Result (Option (Bounds Int)) := (·.bounds) <$> f.outline g

/-- The kerning of a pair of glyphs in font units: `GPOS`'s `kern` feature if the font has
`GPOS`, else the `kern` table. -/
def kerning (l r : Nat) : Int :=
  match f.gpos, f.kern with
  | some p, _ => p.kerning l r
  | none, some k => k.get l r
  | none, none => 0

/-- The glyphs after the standard ligatures (`GSUB` feature `liga`). -/
def ligate (gs : Array Nat) : Array Nat :=
  match f.gsub with
  | some g => g.apply ["liga"] gs
  | none => gs

/-- A string's glyphs, after the standard ligatures, each with its advance plus the kerning
between it and the next glyph, in font units. -/
def layoutText (s : String) : Array (Nat × Int) :=
  let gs := f.ligate (s.toList.toArray.map f.glyph)
  (List.range gs.size).toArray.map fun i =>
    let g := gs[i]?.getD 0
    (g, (f.advance g : Int) + (match gs[i + 1]? with | some r => f.kerning g r | none => 0))

/-- A `MATH` constant by its name in `mathConstantNames`, in font units (a percentage for the
three `…Percent…` constants). -/
def mathConstant? (name : String) : Option Int := do
  let vs ← f.math
  let i ← mathConstantNames.findIdx? (· == name)
  vs[i]?

end Font

end LeAnTeX.OpenType
