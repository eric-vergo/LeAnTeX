/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.OpenType.Binary

/-!
# The basic OpenType tables

The table directory and the tables every OpenType font has: `head`, `hhea`, `maxp`, `hmtx`,
`OS/2`, `post`, `name` and `cmap`, and the old `kern` table. Each reader takes the table's
`Slice` and checks every offset and count against it.

## Main definitions

* `Directory.read`: the table directory (`sfntVersion` `0x00010000`, `OTTO` or `true`).
* `Head`, `Hhea`, `Os2`, `Post`, `Names`, `Cmap`, `KernTable` and their readers.
* `Hmtx`: advance widths and left side bearings by glyph.
* `Cmap.glyph`: the glyph of a code point under the Unicode subtable the font prefers.

## Implementation notes

`cmap` subtables of formats 0, 4, 6 and 12 are read; a format-4 subtable keeps its slice and
reads `glyphIdArray` entries when looked up, and format 12 keeps its groups, so a subtable
claiming millions of code points costs only its bytes. Names are decoded from UTF-16BE
(platforms 0 and 3) or as ASCII (platform 1, other bytes become U+FFFD).

## References

* The OpenType specification 1.9.1, "Font file", "head", "hhea", "hmtx", "maxp", "OS/2",
  "post", "name", "cmap", "kern".
-/

namespace LeAnTeX.OpenType

/-- The index of the first element of the sorted array `xs` whose key is at least `k`
(`xs.size` if none). -/
def lowerBound {α : Type} (xs : Array α) (key : α → Nat) (k : Nat) : Nat := Id.run do
  let mut lo := 0
  let mut hi := xs.size
  -- Each step halves `hi - lo`; 64 steps cover any array.
  for _ in [0:64] do
    if lo < hi then
      let mid := (lo + hi) / 2
      match xs[mid]? with
      | some v => if key v < k then lo := mid + 1 else hi := mid
      | none => hi := mid
  return lo

/-- The table directory: each table's tag and window. -/
structure Directory where
  /-- Whether the font has CFF outlines (`sfntVersion` is `OTTO`). -/
  cff : Bool
  /-- The tables in file order. -/
  tables : Array (String × Slice)

/-- The table directory of a font file. A table record whose window does not fit in the file is
an error. -/
def Directory.read (data : ByteArray) : Result Directory := do
  let s := Slice.ofBytes data "table directory"
  let version ← s.u32 0
  let cff := version == 0x4F54544F
  unless cff || version == 0x00010000 || version == 0x74727565 do
    if version == 0x74746366 then s.fail "font collections are not read"
    else s.fail s!"not an OpenType font (sfntVersion 0x{String.ofList (Nat.toDigits 16 version)})"
  let n ← s.u16 4
  s.need 12 (16 * n)
  let mut tables := #[]
  for i in [0:n] do
    let r := 12 + 16 * i
    let tag ← s.tag r
    let off ← s.u32 (r + 8)
    let len ← s.u32 (r + 12)
    tables := tables.push (tag, ← s.sub off len tag)
  return ⟨cff, tables⟩

/-- The first table with the tag, if any. -/
def Directory.find? (d : Directory) (tag : String) : Option Slice :=
  (d.tables.find? (·.1 == tag)).map (·.2)

/-- The table with the tag, or an error that it is missing. -/
def Directory.get (d : Directory) (tag : String) : Result Slice :=
  match d.find? tag with
  | some s => .ok s
  | none => fail tag "required table missing"

/-- The font header. -/
structure Head where
  /-- Font units per em, 16 to 16384. -/
  unitsPerEm : Nat
  /-- The box of all glyphs: least x. -/
  xMin : Int
  /-- Least y. -/
  yMin : Int
  /-- Greatest x. -/
  xMax : Int
  /-- Greatest y. -/
  yMax : Int
  /-- Style bits (bold 1, italic 2, …). -/
  macStyle : Nat
  /-- `loca` offsets: 0 for 16-bit, 1 for 32-bit. -/
  indexToLocFormat : Int
  deriving Repr, Inhabited

/-- Reads `head`. -/
def Head.read (s : Slice) : Result Head := do
  s.need 0 54
  let upem ← s.u16 18
  unless 16 ≤ upem && upem ≤ 16384 do s.fail s!"unitsPerEm {upem} outside 16..16384"
  return ⟨upem, ← s.i16 36, ← s.i16 38, ← s.i16 40, ← s.i16 42, ← s.u16 44, ← s.i16 50⟩

/-- The horizontal header. -/
structure Hhea where
  /-- Typographic ascender. -/
  ascender : Int
  /-- Typographic descender (negative below the baseline). -/
  descender : Int
  /-- Line gap. -/
  lineGap : Int
  /-- The largest advance width. -/
  advanceWidthMax : Nat
  /-- The number of full records in `hmtx`. -/
  numberOfHMetrics : Nat
  deriving Repr, Inhabited

/-- Reads `hhea`. -/
def Hhea.read (s : Slice) : Result Hhea := do
  s.need 0 36
  return ⟨← s.i16 4, ← s.i16 6, ← s.i16 8, ← s.u16 10, ← s.u16 34⟩

/-- The number of glyphs, from `maxp`. -/
def readNumGlyphs (s : Slice) : Result Nat := do
  let n ← s.u16 4
  if n == 0 then s.fail "no glyphs" else return n

/-- Horizontal metrics by glyph. -/
structure Hmtx where
  /-- Advance widths, one per glyph. -/
  advances : Array Nat
  /-- Left side bearings, one per glyph. -/
  lsbs : Array Int
  deriving Inhabited

/-- Reads `hmtx` for `numGlyphs` glyphs with `numberOfHMetrics` full records (between 1 and
`numGlyphs`); the glyphs after them repeat the last advance. -/
def Hmtx.read (s : Slice) (numGlyphs numberOfHMetrics : Nat) : Result Hmtx := do
  unless 1 ≤ numberOfHMetrics && numberOfHMetrics ≤ numGlyphs do
    s.fail s!"numberOfHMetrics {numberOfHMetrics} outside 1..{numGlyphs}"
  s.need 0 (4 * numberOfHMetrics + 2 * (numGlyphs - numberOfHMetrics))
  let mut adv := Array.mkEmpty numGlyphs
  let mut lsb := Array.mkEmpty numGlyphs
  for i in [0:numberOfHMetrics] do
    adv := adv.push (← s.u16 (4 * i))
    lsb := lsb.push (← s.i16 (4 * i + 2))
  let last := adv.back?.getD 0
  for i in [0:numGlyphs - numberOfHMetrics] do
    adv := adv.push last
    lsb := lsb.push (← s.i16 (4 * numberOfHMetrics + 2 * i))
  return ⟨adv, lsb⟩

/-- The `OS/2` table's metrics. -/
structure Os2 where
  /-- Table version. -/
  version : Nat
  /-- Average advance of the lower-case letters (or all glyphs). -/
  xAvgCharWidth : Int
  /-- Weight class (400 regular, 700 bold). -/
  weightClass : Nat
  /-- Width class (5 normal). -/
  widthClass : Nat
  /-- Embedding permissions (`fsType`): 0 installable, bit 1 restricted, bit 2 preview and
  print, bit 3 editable, bit 8 no subsetting, bit 9 bitmap only. -/
  fsType : Nat
  /-- Typographic ascender. -/
  typoAscender : Int
  /-- Typographic descender. -/
  typoDescender : Int
  /-- Typographic line gap. -/
  typoLineGap : Int
  /-- Windows ascent. -/
  winAscent : Nat
  /-- Windows descent. -/
  winDescent : Nat
  /-- x-height (version 2 and later). -/
  xHeight : Option Int
  /-- Cap height (version 2 and later). -/
  capHeight : Option Int
  /-- The PANOSE classification's proportion (its fourth byte): 9 for a monospaced font. -/
  panoseProportion : Nat := 0
  deriving Repr, Inhabited

/-- Reads `OS/2`. -/
def Os2.read (s : Slice) : Result Os2 := do
  s.need 0 78
  let v ← s.u16 0
  let (xh, ch) ← if v ≥ 2 && s.fits 0 90 then
      pure (some (← s.i16 86), some (← s.i16 88)) else pure (none, none)
  return ⟨v, ← s.i16 2, ← s.u16 4, ← s.u16 6, ← s.u16 8, ← s.i16 68, ← s.i16 70, ← s.i16 72,
    ← s.u16 74, ← s.u16 76, xh, ch, ← s.u8 35⟩

/-- The `post` table's metrics (glyph names come from the CFF charset). -/
structure Post where
  /-- Italic angle in degrees, 16.16 fixed point. -/
  italicAngle : Int
  /-- Underline position. -/
  underlinePosition : Int
  /-- Underline thickness. -/
  underlineThickness : Int
  /-- Whether the font is monospaced. -/
  isFixedPitch : Bool
  deriving Repr, Inhabited

/-- Reads `post`. -/
def Post.read (s : Slice) : Result Post := do
  s.need 0 32
  return ⟨← s.fixed1616 4, ← s.i16 8, ← s.i16 10, (← s.u32 12) != 0⟩

/-- Text decoded from UTF-16BE; unpaired surrogates become U+FFFD. -/
def decodeUtf16 (s : Slice) : Result String := do
  let mut out := ""
  let mut i := 0
  for _ in [0:s.size / 2] do
    if i + 1 < s.size then
      let u ← s.u16 i
      i := i + 2
      if 0xD800 ≤ u && u < 0xDC00 && i + 1 < s.size then
        let l ← s.u16 i
        if 0xDC00 ≤ l && l < 0xE000 then
          i := i + 2
          out := out.push (Char.ofNat (0x10000 + (u - 0xD800) * 0x400 + (l - 0xDC00)))
        else out := out.push '�'
      else if 0xD800 ≤ u && u < 0xE000 then out := out.push '�'
      else out := out.push (Char.ofNat u)
  return out

/-- The font's names by name id (0 copyright, 1 family, 2 subfamily, 4 full name, 5 version,
6 PostScript name, 13 licence, 14 licence URL, …), one string each. -/
structure Names where
  /-- `(nameID, text)` pairs, ascending by id. -/
  entries : Array (Nat × String)
  deriving Inhabited

/-- The name with the id, if the font has it. -/
def Names.get? (n : Names) (id : Nat) : Option String := (n.entries.find? (·.1 == id)).map (·.2)

/-- Reads `name`, choosing for each id the record of the most preferred platform: Windows
Unicode in US English, then other Windows Unicode, then Unicode, then Macintosh Roman. -/
def Names.read (s : Slice) : Result Names := do
  let count ← s.u16 2
  let strings ← s.drop (← s.u16 4)
  s.need 6 (12 * count)
  -- Best record per id: (rank, text); a lower rank is preferred.
  let mut best : Array (Nat × Nat × String) := #[]
  for i in [0:count] do
    let r := 6 + 12 * i
    let platform ← s.u16 r
    let encoding ← s.u16 (r + 2)
    let language ← s.u16 (r + 4)
    let id ← s.u16 (r + 6)
    let len ← s.u16 (r + 8)
    let off ← s.u16 (r + 10)
    let rank? : Option Nat :=
      if platform == 3 && (encoding == 1 || encoding == 10) then
        some (if language == 0x409 then 0 else 1)
      else if platform == 0 then some 2
      else if platform == 1 && encoding == 0 then some 3
      else none
    if let some rank := rank? then
      if (best.find? (fun e => e.1 == id && e.2.1 ≤ rank)).isNone then
        let bytes ← strings.sub off len
        let text ← if platform == 1 then macText bytes else decodeUtf16 bytes
        best := (best.filter (·.1 != id)).push (id, rank, text)
  let sorted := best.qsort (fun a b => a.1 < b.1)
  return ⟨sorted.map fun e => (e.1, e.2.2)⟩
where
  /-- Macintosh Roman text: ASCII kept, other bytes U+FFFD. -/
  macText (b : Slice) : Result String := do
    let mut out := ""
    for i in [0:b.size] do
      let c ← b.u8 i
      out := out.push (if c < 128 then Char.ofNat c else '�')
    return out

/-- A segment of a format-4 `cmap` subtable. -/
structure Seg4 where
  /-- First code. -/
  startCode : Nat
  /-- Last code. -/
  endCode : Nat
  /-- Added to the code (or the looked-up glyph) modulo 65536. -/
  idDelta : Nat
  /-- Offset from this segment's `idRangeOffset` entry into `glyphIdArray`, or 0. -/
  idRangeOffset : Nat
  /-- The position of this segment's `idRangeOffset` entry in the subtable. -/
  rangePos : Nat
  deriving Inhabited

/-- A `cmap` subtable mapping code points to glyphs. -/
inductive Cmap where
  /-- No usable subtable: every code point maps to glyph 0. -/
  | empty
  /-- Format 4: segments, read through the subtable's window. -/
  | segments (s : Slice) (segs : Array Seg4)
  /-- Format 12: groups `(startCode, endCode, startGlyph)`, ascending. -/
  | groups (gs : Array (Nat × Nat × Nat))
  /-- Formats 0 and 6: glyphs of consecutive codes from `first`. -/
  | trimmed (first : Nat) (glyphs : Array Nat)
  deriving Inhabited

/-- Reads one `cmap` subtable of format 0, 4, 6 or 12; other formats give `none`. -/
def Cmap.readSubtable (s : Slice) : Result (Option Cmap) := do
  match ← s.u16 0 with
  | 0 =>
    s.need 6 256
    let mut g := #[]
    for i in [0:256] do g := g.push (← s.u8 (6 + i))
    return some (.trimmed 0 g)
  | 4 =>
    let len ← s.u16 2
    let t ← s.sub 0 (min len s.size)
    let segX2 ← t.u16 6
    let n := segX2 / 2
    t.need 14 (8 * n + 2)
    let mut segs := #[]
    for i in [0:n] do
      let e ← t.u16 (14 + 2 * i)
      let st ← t.u16 (16 + segX2 + 2 * i)
      let d ← t.u16 (16 + 2 * segX2 + 2 * i)
      let rp := 16 + 3 * segX2 + 2 * i
      segs := segs.push ⟨st, e, d, ← t.u16 rp, rp⟩
    -- Segments must ascend by end code for the binary search.
    for i in [1:segs.size] do
      if (segs[i]?.map (·.endCode)).getD 0 < (segs[i - 1]?.map (·.endCode)).getD 0 then
        t.fail "format 4 segments not in order"
    return some (.segments t segs)
  | 6 =>
    let first ← s.u16 6
    let count ← s.u16 8
    s.need 10 (2 * count)
    let mut g := #[]
    for i in [0:count] do g := g.push (← s.u16 (10 + 2 * i))
    return some (.trimmed first g)
  | 12 =>
    let n ← s.u32 12
    s.need 16 (12 * n)
    let mut gs := #[]
    let mut prev := 0
    for i in [0:n] do
      let r := 16 + 12 * i
      let st ← s.u32 r
      let e ← s.u32 (r + 4)
      if e < st || (i > 0 && st ≤ prev) || e > 0x10FFFF then
        s.fail "format 12 groups not in order"
      gs := gs.push (st, e, ← s.u32 (r + 8))
      prev := e
    return some (.groups gs)
  | _ => return none

/-- Reads `cmap`, choosing a full-repertoire Unicode subtable (3,10 or 0,4/0,6) over a BMP one
(3,1 or 0,3 and older Unicode encodings) over a symbol one (3,0). -/
def Cmap.read (s : Slice) : Result Cmap := do
  let n ← s.u16 2
  s.need 4 (8 * n)
  let mut best : Option (Nat × Cmap) := none
  for i in [0:n] do
    let r := 4 + 8 * i
    let p ← s.u16 r
    let e ← s.u16 (r + 2)
    let rank? : Option Nat :=
      if (p == 3 && e == 10) || (p == 0 && (e == 4 || e == 6)) then some 0
      else if (p == 3 && e == 1) || p == 0 then some 1
      else if p == 3 && e == 0 then some 2
      else none
    if let some rank := rank? then
      if best.all (·.1 > rank) then
        if let some c ← Cmap.readSubtable (← s.drop (← s.u32 (r + 4))) then
          best := some (rank, c)
  return (best.map (·.2)).getD .empty

/-- The glyph of the code point `c`, 0 (`.notdef`) when the subtable does not map it. -/
def Cmap.glyph (m : Cmap) (c : Nat) : Nat :=
  match m with
  | .empty => 0
  | .trimmed first gs => if first ≤ c then gs[c - first]?.getD 0 else 0
  | .groups gs =>
    let i := lowerBound gs (·.2.1) c
    match gs[i]? with
    | some (st, _, g) => if st ≤ c then g + (c - st) else 0
    | none => 0
  | .segments s segs =>
    let i := lowerBound segs (·.endCode) c
    match segs[i]? with
    | some seg =>
      if seg.startCode ≤ c && c ≤ seg.endCode then
        if seg.idRangeOffset == 0 then (c + seg.idDelta) % 65536
        else
          match s.u16 (seg.rangePos + seg.idRangeOffset + 2 * (c - seg.startCode)) with
          | .ok 0 => 0
          | .ok g => (g + seg.idDelta) % 65536
          | .error _ => 0
      else 0
    | none => 0

/-- Pair kerning from the old `kern` table: `(left, right, value)`, ascending by pair. -/
structure KernTable where
  /-- The pairs, ascending by `left * 65536 + right`. -/
  pairs : Array (Nat × Int)
  deriving Inhabited

/-- Reads the horizontal format-0 subtables of a version-0 `kern` table (other versions and
formats are skipped). Values of the same pair in several subtables add up. -/
def KernTable.read (s : Slice) : Result KernTable := do
  if (← s.u16 0) != 0 then return ⟨#[]⟩
  let n ← s.u16 2
  let mut off := 4
  let mut pairs : Array (Nat × Int) := #[]
  for _ in [0:n] do
    let len ← s.u16 (off + 2)
    let coverage ← s.u16 (off + 4)
    if coverage >>> 8 == 0 && coverage &&& 1 == 1 && coverage &&& 6 == 0 then
      let np ← s.u16 (off + 6)
      s.need (off + 14) (6 * np)
      for i in [0:np] do
        let r := off + 14 + 6 * i
        pairs := pairs.push ((← s.u16 r) * 65536 + (← s.u16 (r + 2)), ← s.i16 (r + 4))
    if len < 6 then s.fail "subtable shorter than its header"
    off := off + len
  let sorted := pairs.qsort (fun a b => a.1 < b.1)
  return ⟨sorted⟩

/-- The kerning of the pair, 0 if the table has none. -/
def KernTable.get (k : KernTable) (left right : Nat) : Int :=
  let key := left * 65536 + right
  Id.run do
    let mut total : Int := 0
    let mut i := lowerBound k.pairs (·.1) key
    for _ in [0:k.pairs.size] do
      match k.pairs[i]? with
      | some (p, v) => if p == key then total := total + v; i := i + 1 else break
      | none => break
    return total

end LeAnTeX.OpenType
