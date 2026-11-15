/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.OpenType
import LeAnTeX.Text.Node
import LeAnTeX.Text.Hyphen
import LeAnTeX.Layout.Em

/-!
# Text fonts

An OpenType font at a size, and how a run of characters becomes glyphs and kerns in it, as
LuaLaTeX's font loader (luaotfload, in its `node` mode with LaTeX's default features) sets
text:

* **Glyphs**: each character's glyph through the font's character map; its width is the
  glyph's advance and its height and depth those of its tight box (above and below the
  baseline, none below 0), scaled to the size and rounded to the nearest scaled point.
* **TeX ligatures** (`tlig`), before the font's own: ``--`` an en dash, ``---`` an em dash,
  `` ` `` and `'` single quotes, ``` `` ``` and `''` double quotes, `!``, `?`` inverted marks.
* **Ligatures** of the font's `liga` feature (`ff`, `fi`, `fl`, `ffi`, `ffl` in Latin Modern)
  and **kerns** from its `kern` feature (or `kern` table) between consecutive glyphs.
* **Hyphenation points** become discretionaries: a point between two glyphs not joined by a
  ligature is a discretionary with a hyphen before the break and, when not broken, the kern the
  two glyphs had; a point inside a ligature is a discretionary holding the ligature's
  characters set before the break (with a hyphen), after it, and unbroken.
* **Interword space** from the font's space character: its advance; stretch a half and shrink
  a third of it, and an extra space after a sentence of a third of it, as luaotfload derives
  TeX's font dimensions; none of these three for a font whose `post` table marks it
  monospaced.

## Main definitions

* `FontInfo`, `FontInfo.ofFont`: what the text layer needs of a font, read once.
* `TextFont`: a font at a size, with its index in a document's table of fonts.
* `TextFont.space`: the interword glue at a space factor.
* `TextFont.shapeRun`: a run of characters as glyphs, kerns and discretionaries.
* `texLigatures`: the `tlig` replacements.

## References

* luaotfload's documentation (the `tlig` feature; how TeX's font dimensions are derived) and
  the OpenType specification (`GSUB`, `GPOS`): the behaviour, written from their descriptions.
-/

namespace LeAnTeX.Text

open LeAnTeX.OpenType

/-- What the text layer needs of a font, read once: the font, its name, the glyphs' boxes in
font units and the characters that map to each glyph. -/
structure FontInfo where
  /-- The font. -/
  font : OpenType.Font
  /-- A name for the font (its file name), written to the output. -/
  name : String
  /-- Per glyph, the height and depth of its tight box in font units. -/
  boxes : Array (Int × Int)
  /-- The character each glyph comes from, for glyphs a character maps to (the least such
  character). -/
  chars : Std.HashMap Nat Char
  /-- Whether the font is monospaced (`post`'s `isFixedPitch`). -/
  mono : Bool
  /-- A slant drawn onto the glyphs, in thousandths (horizontal shift per unit of height, as
  `FakeSlant` gives it to `fontspec`); `0` for none. Metrics are unchanged, as in luaotfload. -/
  slant : Int := 0
  /-- Whether the text is set in the font's small capitals (its `smcp` feature, before the
  ligatures). -/
  smallCaps : Bool := false

/-- The information of a font read from its bytes. The glyph boxes are read for every glyph
(an outline that fails to read gives an empty box); the character map is inverted over the
Basic Multilingual Plane and the ligature block. -/
def FontInfo.ofFont (f : OpenType.Font) (name : String) : FontInfo := Id.run do
  let mut boxes := Array.mkEmpty f.numGlyphs
  for g in [0:f.numGlyphs] do
    let b := match f.bounds g with
      | .ok (some b) => (Em.roundDiv b.yMax 65536, Em.roundDiv (-b.yMin) 65536)
      | _ => (0, 0)
    boxes := boxes.push (max 0 b.1, max 0 b.2)
  let mut chars : Std.HashMap Nat Char := {}
  for c in [0x20:0x10000] do
    if c < 0xD800 || c ≥ 0xE000 then
      let g := f.glyph (Char.ofNat c)
      if g != 0 && !chars.contains g then chars := chars.insert g (Char.ofNat c)
  let mono := (f.post.map (·.isFixedPitch)).getD false
  return { font := f, name, boxes, chars, mono }

/-- The `GSUB` features the text layer applies to a run in this font: `smcp` for small
capitals, then `liga`. -/
def FontInfo.features (i : FontInfo) : List String :=
  if i.smallCaps then ["smcp", "liga"] else ["liga"]

/-- The glyphs of characters after the font's substitutions (`FontInfo.features`). -/
def FontInfo.substitute (i : FontInfo) (gs : Array Nat) : Array Nat :=
  match i.font.gsub with
  | some g => g.apply i.features gs
  | none => gs

/-- The glyph a single character is set with, after the substitutions. -/
def FontInfo.glyphOf (i : FontInfo) (c : Char) : Nat :=
  (i.substitute #[i.font.glyph c])[0]?.getD (i.font.glyph c)

/-- A font at a size (in sp) with its index in the document's table of fonts. -/
structure TextFont where
  /-- The font. -/
  info : FontInfo
  /-- The size: the length of one em, in sp. -/
  size : Int
  /-- The index in the document's table of fonts, written into glyph nodes. -/
  index : Nat

namespace TextFont

variable (t : TextFont)

/-- Font units scaled to the size, rounded to the nearest sp. -/
def scale (v : Int) : Int := Em.roundDiv (v * t.size) t.info.font.unitsPerEm

/-- The glyph node of glyph `g`, whose character is `c`. -/
def glyphNode (g : Nat) (c : Char) : HNode :=
  let (h, d) := t.info.boxes[g]?.getD (0, 0)
  .glyph c g (t.scale (t.info.font.advance g)) (t.scale h) (t.scale d) t.index

/-- The space's advance in font units. -/
def spaceUnits : Int := t.info.font.advance (t.info.font.glyph ' ')

/-- The interword glue (TeX's font dimensions 2, 3, 4 and 7, as luaotfload derives them) at
space factor `sf` (1000 normal): from 2000 the extra space is added, and the stretch is scaled
by `sf / 1000` and the shrink by `1000 / sf`, TeX's rules. -/
def space (sf : Nat := 1000) : Glue :=
  let u := t.spaceUnits
  let w := t.scale u
  let (st, sh, ex) := if t.info.font.unitsPerEm == 0 || t.info.mono then (0, 0, 0)
    else (Em.roundDiv (u * t.size) (2 * t.info.font.unitsPerEm),
      Em.roundDiv (u * t.size) (3 * t.info.font.unitsPerEm),
      Em.roundDiv (u * t.size) (3 * t.info.font.unitsPerEm))
  if sf == 1000 || sf == 0 then { width := w, stretch := st, shrink := sh }
  else
    { width := if sf ≥ 2000 then w + ex else w, stretch := st * sf / 1000,
      shrink := sh * 1000 / sf }

/-- The glyphs of a run of characters after ligatures, each with the characters it stands
for (its cluster). -/
def clusters (cs : Array Char) : Array (Nat × Array Char) := Id.run do
  let f := t.info.font
  let gs := t.info.substitute (cs.map f.glyph)
  let mut out := #[]
  let mut i := 0
  for g in gs do
    let c := cs[i]?.getD ' '
    if t.info.glyphOf c == g || i + 1 ≥ cs.size then
      out := out.push (g, #[c]); i := i + 1
    else
      -- a ligature: the fewest characters from `i` that ligate to it (at most 8)
      let mut k := 2
      for _ in [0:7] do
        if i + k ≥ cs.size || t.info.substitute ((cs.extract i (i + k)).map f.glyph) == #[g]
          then break
        k := k + 1
      out := out.push (g, cs.extract i (i + k)); i := i + k
  return out

/-- The character a glyph node shows: the cluster's own character for a single one, else the
character the font maps to the glyph. -/
def clusterChar (g : Nat) (cl : Array Char) : Char :=
  if cl.size == 1 then cl[0]?.getD ' ' else t.info.chars[g]?.getD (cl[0]?.getD ' ')

/-- Glyphs and kerns of a run without hyphenation. -/
def shape (cs : Array Char) : Array HNode := Id.run do
  let cl := t.clusters cs
  let mut out := #[]
  for h : j in [0:cl.size] do
    let (g, chs) := cl[j]
    out := out.push (t.glyphNode g (t.clusterChar g chs))
    if let some (r, _) := cl[j + 1]? then
      let k := t.info.font.kerning g r
      if k != 0 then out := out.push (.kern (t.scale k) .font)
  return out

/-- The kern between the last glyph of `a` and the first of `b`, in sp, if any. -/
def kernBetween (a b : Array Char) : Int :=
  match (t.clusters a).back?, (t.clusters b)[0]? with
  | some (l, _), some (r, _) => t.scale (t.info.font.kerning l r)
  | _, _ => 0

/-- A run of characters as glyphs, kerns and discretionaries, with a discretionary at each of
the given hyphenation points (`k` for a point after the `k`th character), whose penalty is
`penalty`. A point inside a ligature takes the ligature's characters into its discretionary; a
point whose ligature overlaps an earlier point's is left out. -/
def shapeRun (cs : Array Char) (points : Array Nat) (penalty : Int) : Array HNode := Id.run do
  if points.isEmpty then return t.shape cs
  let cl := t.clusters cs
  -- the character offsets where clusters start, and the run's end
  let mut bounds : Array Nat := #[]
  let mut off := 0
  for (_, chs) in cl do
    bounds := bounds.push off; off := off + chs.size
  bounds := bounds.push cs.size
  let hyphen := #['-']
  let mut out := #[]
  let mut from_ := 0
  for p in points do
    if p ≤ from_ || p ≥ cs.size then continue
    -- the cluster boundaries around the point
    let a := (bounds.filter (· ≤ p)).back?.getD 0
    let b := (bounds.filter (· ≥ p))[0]?.getD cs.size
    if a < from_ then continue
    let left := cs.extract from_ a
    if a == p then
      out := out ++ t.shape left
      let k := t.kernBetween (cs.extract from_ p) (cs.extract p (cs.size))
      let rep := if k != 0 then #[HNode.kern k .font] else #[]
      out := out.push (.disc penalty (t.shape hyphen) #[] rep .syllable)
      from_ := p
    else
      out := out ++ t.shape left
      let k := t.kernBetween left (cs.extract a b)
      if !left.isEmpty && k != 0 then out := out.push (.kern k .font)
      out := out.push (.disc penalty (t.shape (cs.extract a p ++ hyphen))
        (t.shape (cs.extract p b)) (t.shape (cs.extract a b)) .syllable)
      let k2 := t.kernBetween (cs.extract a b) (cs.extract b cs.size)
      if b < cs.size && k2 != 0 then out := out.push (.kern k2 .font)
      from_ := b
  return out ++ t.shape (cs.extract from_ cs.size)

end TextFont

/-- TeX's ligatures for text (`tlig`): dashes from hyphens, curly quotes from straight ones and
grave accents, inverted marks. -/
def texLigatures (cs : Array Char) : Array Char := Id.run do
  let mut out := #[]
  let mut i := 0
  for _ in [0:cs.size] do
    if i ≥ cs.size then break
    let c := cs[i]?.getD ' '
    let n := cs[i + 1]?.getD ' '
    let n2 := cs[i + 2]?.getD ' '
    if c == '-' && n == '-' && n2 == '-' then out := out.push '—'; i := i + 3
    else if c == '-' && n == '-' then out := out.push '–'; i := i + 2
    else if c == '`' && n == '`' then out := out.push '“'; i := i + 2
    else if c == '\'' && n == '\'' then out := out.push '”'; i := i + 2
    else if c == '!' && n == '`' then out := out.push '¡'; i := i + 2
    else if c == '?' && n == '`' then out := out.push '¿'; i := i + 2
    else if c == '`' then out := out.push '‘'; i := i + 1
    else if c == '\'' then out := out.push '’'; i := i + 1
    else out := out.push c; i := i + 1
  return out

end LeAnTeX.Text
