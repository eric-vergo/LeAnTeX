/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Font.Binary
import LeAnTeX.Path

/-!
# CFF outlines

The `CFF ` table of an OpenType font: its INDEX structures and DICTs, and an interpreter of
Type 2 charstrings that turns a glyph's program into a `Path` and its advance width.

## Main definitions

* `Index`, `Index.read`, `Index.item`: a CFF INDEX with its offsets checked.
* `Cff`, `Cff.read`: the charstrings, global and local subroutines, private widths, and for
  CID-keyed fonts the FDArray and FDSelect.
* `Cff.charstring`: a glyph's outline in 1/65536 font units and its width.

## Implementation notes

Numbers are Type 2's 16.16 fixed point, kept as `Int`s in 1/65536, so every coordinate is exact.
The interpreter runs on an explicit stack of call frames instead of recursion: subroutine calls
nest at most `maxCallDepth` deep (Type 2's limit of 10), the argument stack holds at most
`maxStack` numbers (48), and one glyph executes at most `charstringFuel` operators, so a hostile
charstring ends with an error, never a loop. The arithmetic and storage operators of the
original Type 2 specification (`and`, `add`, `put`, …, removed in CFF2 and absent from fonts in
practice) and `seac`-style accented `endchar` are reported as unsupported.

## References

* Adobe Technical Note #5176, "The Compact Font Format Specification", 4 December 2003.
* Adobe Technical Note #5177, "The Type 2 Charstring Format", 16 March 2000.
-/

namespace LeAnTeX.Font

/-- A CFF INDEX: an array of byte strings. -/
structure Index where
  /-- The window holding the items' data. -/
  data : Slice
  /-- Item `i` is `[offsets[i], offsets[i+1])` of `data`. -/
  offsets : Array Nat
  /-- The INDEX's total length in bytes. -/
  length : Nat

/-- The number of items. -/
def Index.count (x : Index) : Nat := x.offsets.size - 1

/-- Reads the INDEX at `off`: offsets of 1 to 4 bytes, starting at 1, never decreasing, and
inside the data. -/
def Index.read (s : Slice) (off : Nat) : Result Index := do
  let count ← s.u16 off
  if count == 0 then return ⟨← s.sub (off + 2) 0, #[0], 2⟩
  let offSize ← s.u8 (off + 2)
  unless 1 ≤ offSize && offSize ≤ 4 do s.fail s!"INDEX offSize {offSize}"
  let base := off + 3 + (count + 1) * offSize
  s.need (off + 3) ((count + 1) * offSize)
  let mut offs := Array.mkEmpty (count + 1)
  let mut prev := 1
  for i in [0:count + 1] do
    let o ← s.uN (off + 3 + i * offSize) offSize
    if (i == 0 && o != 1) || o < prev then s.fail "INDEX offsets out of order"
    offs := offs.push (o - 1)
    prev := o
  let size := prev - 1
  let data ← s.sub base size
  return ⟨data, offs, base + size - off⟩

/-- Item `i` of the INDEX. -/
def Index.item (x : Index) (i : Nat) : Result Slice :=
  match x.offsets[i]?, x.offsets[i + 1]? with
  | some a, some b => x.data.sub a (b - a)
  | _, _ => x.data.fail s!"INDEX item {i} of {x.count}"

/-- A DICT operand: an integer, or a real as an `Int` in 1/65536. -/
inductive DictNum where
  /-- An integer operand. -/
  | int (n : Int)
  /-- A real operand, in 1/65536. -/
  | real (fixed : Int)
  deriving Inhabited, Repr

/-- The operand as an integer (a real truncated towards zero). -/
def DictNum.toInt : DictNum → Int
  | .int n => n
  | .real f => f / 65536

/-- A DICT: each operator (escaped operators as `1200 + b`) with its operands, in order. -/
abbrev Dict := Array (Nat × Array DictNum)

/-- A real operand's nibbles from `off`: the value in 1/65536 (rounded towards zero, exponents
past 10⁹ saturated) and the offset after its end nibble. -/
def readReal (s : Slice) (off0 : Nat) : Result (Int × Nat) := do
  let mut off := off0
  let mut digits : Int := 0
  let mut scale : Int := 0
  let mut neg := false
  let mut afterPoint := false
  let mut expo : Int := 0
  let mut expNeg := false
  let mut inExp := false
  let mut done := false
  -- A real is at most a few dozen nibbles in any font; 64 bytes bounds it.
  for _ in [0:64] do
    if !done then
      let b ← s.u8 off
      off := off + 1
      for nib in [b >>> 4, b &&& 15] do
        if !done then
          if nib ≤ 9 then
            if inExp then expo := min (expo * 10 + nib) 1000000000
            else if digits < 10 ^ 18 then
              digits := digits * 10 + nib
              if afterPoint then scale := scale + 1
            else if !afterPoint then scale := scale - 1
          else if nib == 0xa then afterPoint := true
          else if nib == 0xb then inExp := true
          else if nib == 0xc then inExp := true; expNeg := true
          else if nib == 0xe then neg := true
          else if nib == 0xf then done := true
          else s.fail "reserved nibble in a real"
  unless done do s.fail "real without end nibble"
  let e := (if expNeg then -expo else expo) - scale
  let v : Int :=
    if e ≥ 0 then if e > 18 then 2 ^ 40 else digits * 65536 * 10 ^ e.toNat
    else if -e > 40 then 0 else digits * 65536 / 10 ^ (-e).toNat
  return (if neg then -v else v, off)

/-- Reads a DICT occupying the whole window. -/
def Dict.read (s : Slice) : Result Dict := do
  let mut out : Dict := #[]
  let mut ops : Array DictNum := #[]
  let mut off := 0
  -- Every iteration consumes at least one byte.
  for _ in [0:s.size] do
    if off < s.size then
      let b ← s.u8 off
      if b ≤ 21 then
        if b == 12 then
          out := out.push (1200 + (← s.u8 (off + 1)), ops)
          off := off + 2
        else
          out := out.push (b, ops)
          off := off + 1
        ops := #[]
      else if b == 28 then
        ops := ops.push (.int (Slice.signed (← s.u16 (off + 1)) 16)); off := off + 3
      else if b == 29 then
        ops := ops.push (.int (← s.i32 (off + 1))); off := off + 5
      else if b == 30 then
        let (v, o) ← readReal s (off + 1)
        ops := ops.push (.real v); off := o
      else if 32 ≤ b && b ≤ 246 then ops := ops.push (.int ((b : Int) - 139)); off := off + 1
      else if 247 ≤ b && b ≤ 250 then
        ops := ops.push (.int (((b : Int) - 247) * 256 + (← s.u8 (off + 1)) + 108))
        off := off + 2
      else if 251 ≤ b && b ≤ 254 then
        ops := ops.push (.int (-((b : Int) - 251) * 256 - (← s.u8 (off + 1)) - 108))
        off := off + 2
      else s.fail s!"reserved DICT byte {b}"
  return out

/-- The operands of the operator in the DICT, if present. -/
def Dict.get? (d : Dict) (op : Nat) : Option (Array DictNum) := (d.find? (·.1 == op)).map (·.2)

/-- The single integer operand of the operator, or `dflt`. -/
def Dict.int (d : Dict) (op : Nat) (dflt : Int) : Int :=
  match d.get? op with
  | some #[n] => n.toInt
  | _ => dflt

/-- The widths and local subroutines of a Private DICT. -/
structure Private where
  /-- `defaultWidthX`, in 1/65536. -/
  defaultWidth : Int
  /-- `nominalWidthX`, in 1/65536. -/
  nominalWidth : Int
  /-- The local subroutines (empty if none). -/
  subrs : Index

/-- The fixed-point value of a single operand of the operator, or `dflt`. -/
private def Dict.fixed (d : Dict) (op : Nat) (dflt : Int) : Int :=
  match d.get? op with
  | some #[.int n] => n * 65536
  | some #[.real f] => f
  | _ => dflt

/-- A non-negative integer operand as a `Nat`, or an error. -/
private def natOf (s : Slice) (v : Int) (what : String) : Result Nat :=
  if v < 0 then s.fail s!"negative {what}" else .ok v.toNat

/-- The INDEX without items. -/
def Index.empty (s : Slice) : Index := ⟨⟨s.data, s.start, 0, s.table⟩, #[0], 0⟩

/-- Reads the Private DICT given by a Top or Font DICT's `Private` operator (size, offset). -/
def Private.read (cff : Slice) (d : Dict) : Result Private := do
  let empty := Index.empty cff
  match d.get? 18 with
  | some #[size, off] =>
    let size ← natOf cff size.toInt "Private size"
    let off ← natOf cff off.toInt "Private offset"
    let p ← cff.sub off size
    let pd ← Dict.read p
    let subrs ← match pd.get? 19 with
      | some #[o] =>
        let o ← natOf cff o.toInt "Subrs offset"
        Index.read cff (off + o)
      | _ => pure empty
    return ⟨Dict.fixed pd 20 0, Dict.fixed pd 21 0, subrs⟩
  | _ => return ⟨0, 0, empty⟩

/-- A font's CFF data. -/
structure Cff where
  /-- The charstrings, one per glyph. -/
  charStrings : Index
  /-- The global subroutines. -/
  globalSubrs : Index
  /-- The Private DICTs: one for a name-keyed font, one per Font DICT for a CID-keyed font. -/
  privates : Array Private
  /-- For a CID-keyed font, the Font DICT of each glyph (FDSelect); empty otherwise. -/
  fdSelect : Array Nat

/-- Reads FDSelect (formats 0 and 3) for `n` glyphs, each Font DICT index below `fdCount`. -/
def readFdSelect (s : Slice) (n fdCount : Nat) : Result (Array Nat) := do
  let fmt ← s.u8 0
  let mut out := Array.mkEmpty n
  if fmt == 0 then
    s.need 1 n
    for i in [0:n] do out := out.push (← s.u8 (1 + i))
  else if fmt == 3 then
    let nr ← s.u16 1
    s.need 3 (3 * nr + 2)
    for i in [0:nr] do
      let first ← s.u16 (3 + 3 * i)
      let fd ← s.u8 (5 + 3 * i)
      let next ← s.u16 (6 + 3 * i)
      if first != out.size || next < first then s.fail "FDSelect ranges out of order"
      for _ in [first:min next n] do out := out.push fd
    if out.size < n then s.fail "FDSelect does not cover every glyph"
  else s.fail s!"FDSelect format {fmt}"
  if out.any (· ≥ fdCount) then s.fail "FDSelect names a missing Font DICT"
  return out

/-- Reads the `CFF ` table (version 1, one font, Type 2 charstrings). -/
def Cff.read (s : Slice) : Result Cff := do
  let major ← s.u8 0
  unless major == 1 do s.fail s!"CFF major version {major}"
  let hdr ← s.u8 2
  let names ← Index.read s hdr
  let tops ← Index.read s (hdr + names.length)
  let strings ← Index.read s (hdr + names.length + tops.length)
  let gsubrs ← Index.read s (hdr + names.length + tops.length + strings.length)
  unless tops.count ≥ 1 do s.fail "no Top DICT"
  let top ← Dict.read (← tops.item 0)
  unless top.int 1206 2 == 2 do s.fail "charstrings are not Type 2"
  let csOff ← match top.get? 17 with
    | some #[o] => natOf s o.toInt "CharStrings offset"
    | _ => s.fail "no CharStrings"
  let charStrings ← Index.read s csOff
  match top.get? 1236, top.get? 1237 with
  | some #[fa], some #[fs] =>
    let fdArray ← Index.read s (← natOf s fa.toInt "FDArray offset")
    -- FDSelect stores Font DICT indices in one byte.
    if fdArray.count > 256 then s.fail "more than 256 Font DICTs"
    let mut privates := #[]
    for i in [0:fdArray.count] do
      privates := privates.push (← Private.read s (← Dict.read (← fdArray.item i)))
    let sel ← readFdSelect (← s.drop (← natOf s fs.toInt "FDSelect offset"))
      charStrings.count fdArray.count
    return ⟨charStrings, gsubrs, privates, sel⟩
  | _, _ => return ⟨charStrings, gsubrs, #[← Private.read s top], #[]⟩

/-- Type 2's limit on the argument stack. -/
def maxStack : Nat := 48

/-- Type 2's limit on nested subroutine calls. -/
def maxCallDepth : Nat := 10

/-- The most operators and operands one glyph's charstring may execute. -/
def charstringFuel : Nat := 20000

/-- The subroutine bias for an INDEX of `n` subroutines. -/
def subrBias (n : Nat) : Int := if n < 1240 then 107 else if n < 33900 then 1131 else 32768

/-- A glyph's outline and advance width, both in 1/65536 font units. -/
structure Charstring where
  /-- The outline. -/
  path : Path Int
  /-- The advance width the charstring states (or the Private DICT's default). -/
  width : Int
  deriving Inhabited

/-- The interpreter's state. -/
private structure T2 where
  stack : Array Int := #[]
  x : Int := 0
  y : Int := 0
  cmds : Array (PathCmd Int) := #[]
  open_ : Bool := false
  stems : Nat := 0
  widthTaken : Bool := false
  width : Option Int := none

namespace T2

/-- Fail with a charstring error. -/
private def err {α : Type} (msg : String) : Result α := fail "CFF charstring" msg

/-- The width argument, taken off the bottom of the stack by the first stack-clearing operator
when the stack holds more arguments than the operator takes. -/
private def takeWidth (t : T2) (extra : Bool) (nominal : Int) : T2 :=
  if t.widthTaken then t
  else if extra then
    { t with widthTaken := true, width := some (nominal + (t.stack[0]?.getD 0)),
             stack := t.stack.extract 1 }
  else { t with widthTaken := true }

/-- Close the open subpath, if any. -/
private def closePath (t : T2) : T2 :=
  if t.open_ then { t with cmds := t.cmds.push .close, open_ := false } else t

/-- Start a subpath at the current point plus `(dx, dy)`. -/
private def moveBy (t : T2) (dx dy : Int) : T2 :=
  let t := t.closePath
  let x := t.x + dx
  let y := t.y + dy
  { t with x, y, cmds := t.cmds.push (.move ⟨x, y⟩), open_ := true }

/-- A line from the current point by `(dx, dy)`. -/
private def lineBy (t : T2) (dx dy : Int) : T2 :=
  let x := t.x + dx
  let y := t.y + dy
  { t with x, y, cmds := t.cmds.push (.line ⟨x, y⟩) }

/-- A cubic from the current point with relative control points. -/
private def curveBy (t : T2) (a b c d e f : Int) : T2 :=
  let x1 := t.x + a
  let y1 := t.y + b
  let x2 := x1 + c
  let y2 := y1 + d
  let x := x2 + e
  let y := y2 + f
  { t with x, y, cmds := t.cmds.push (.cubic ⟨x1, y1⟩ ⟨x2, y2⟩ ⟨x, y⟩) }

/-- Stack element `i` (0 at the bottom). -/
private def arg (t : T2) (i : Nat) : Int := t.stack[i]?.getD 0

/-- `rlineto`: lines by each pair of arguments. -/
private def rlineto (t : T2) (s : Array Int) : T2 := Id.run do
  let mut t := t
  for i in [0:s.size / 2] do t := t.lineBy (s[2 * i]?.getD 0) (s[2 * i + 1]?.getD 0)
  return t

/-- `hlineto` (`horizontal` first) and `vlineto`: lines alternating between horizontal and
vertical. -/
private def altLines (t : T2) (s : Array Int) (horizontal : Bool) : T2 := Id.run do
  let mut t := t
  let mut h := horizontal
  for v in s do
    t := if h then t.lineBy v 0 else t.lineBy 0 v
    h := !h
  return t

/-- `rrcurveto`: a curve by each six arguments. -/
private def rrcurveto (t : T2) (s : Array Int) : T2 := Id.run do
  let mut t := t
  for i in [0:s.size / 6] do
    let a := fun j => s[6 * i + j]?.getD 0
    t := t.curveBy (a 0) (a 1) (a 2) (a 3) (a 4) (a 5)
  return t

/-- `hvcurveto` (`horizontal` first) and `vhcurveto`: curves whose first and last tangents
alternate between horizontal and vertical; an odd last argument is the final tangent's
offset. -/
private def altCurves (t : T2) (s : Array Int) (horizontal : Bool) : T2 := Id.run do
  let mut t := t
  let mut h := horizontal
  let n := s.size / 4
  for i in [0:n] do
    let a := fun j => s[4 * i + j]?.getD 0
    let last := if i + 1 == n && s.size % 4 == 1 then s.back?.getD 0 else 0
    t := if h then t.curveBy (a 0) 0 (a 1) (a 2) last (a 3)
      else t.curveBy 0 (a 0) (a 1) (a 2) (a 3) last
    h := !h
  return t

/-- `hhcurveto` (`horizontal`) and `vvcurveto`: curves with horizontal (vertical) end tangents;
an odd first argument offsets the first curve's start tangent. -/
private def sameCurves (t : T2) (s : Array Int) (horizontal : Bool) : T2 := Id.run do
  let mut t := t
  let odd := s.size % 4 == 1
  let first := if odd then s[0]?.getD 0 else 0
  let base := if odd then 1 else 0
  for i in [0:(s.size - base) / 4] do
    let a := fun j => s[base + 4 * i + j]?.getD 0
    let off := if i == 0 then first else 0
    t := if horizontal then t.curveBy (a 0) off (a 1) (a 2) (a 3) 0
      else t.curveBy off (a 0) (a 1) (a 2) 0 (a 3)
  return t

/-- The flex operators (`12 35`, `12 34`, `12 36`, `12 37`) as their two cubics. -/
private def flex (t : T2) (op : Nat) (s : Array Int) : Result T2 := do
  let a := fun j => s[j]?.getD 0
  match op with
  | 35 =>
    unless s.size == 13 do err "flex takes 13 arguments"
    return (t.curveBy (a 0) (a 1) (a 2) (a 3) (a 4) (a 5)).curveBy (a 6) (a 7) (a 8) (a 9)
      (a 10) (a 11)
  | 34 =>
    unless s.size == 7 do err "hflex takes 7 arguments"
    return (t.curveBy (a 0) 0 (a 1) (a 2) (a 3) 0).curveBy (a 4) 0 (a 5) (-(a 2)) (a 6) 0
  | 36 =>
    unless s.size == 9 do err "hflex1 takes 9 arguments"
    let t1 := t.curveBy (a 0) (a 1) (a 2) (a 3) (a 4) 0
    return t1.curveBy (a 5) 0 (a 6) (a 7) (a 8) (-((a 1) + (a 3) + (a 7)))
  | _ =>
    unless s.size == 11 do err "flex1 takes 11 arguments"
    let dx := (a 0) + (a 2) + (a 4) + (a 6) + (a 8)
    let dy := (a 1) + (a 3) + (a 5) + (a 7) + (a 9)
    let t1 := t.curveBy (a 0) (a 1) (a 2) (a 3) (a 4) (a 5)
    return if dx.natAbs > dy.natAbs then t1.curveBy (a 6) (a 7) (a 8) (a 9) (a 10) (-dy)
      else t1.curveBy (a 6) (a 7) (a 8) (a 9) (-dx) (a 10)

end T2

/-- A call frame: the charstring or subroutine being run and the position in it. -/
private structure Frame where
  code : Slice
  pos : Nat

/-- Runs glyph `g`'s charstring: its outline (every subpath closed) and advance width. -/
def Cff.charstring (cff : Cff) (g : Nat) : Result Charstring := do
  let code ← cff.charStrings.item g
  let fd := if cff.fdSelect.isEmpty then 0 else cff.fdSelect[g]?.getD 0
  let some priv := cff.privates[fd]? | fail "CFF" "no Private DICT for the glyph"
  let lbias := subrBias priv.subrs.count
  let gbias := subrBias cff.globalSubrs.count
  let mut frames : Array Frame := #[⟨code, 0⟩]
  let mut t : T2 := {}
  let mut done := false
  for _ in [0:charstringFuel] do
    if done then break
    let some fr := frames.back? | break
    if fr.pos ≥ fr.code.size then
      -- Running off the end returns from a subroutine and ends the glyph at the top level.
      frames := frames.pop
      if frames.isEmpty then done := true
      continue
    let s := fr.code
    let b ← s.u8 fr.pos
    let setPos := fun (p : Nat) => frames.modify (frames.size - 1) fun f => { f with pos := p }
    if b ≥ 32 || b == 28 then
      let (v, len) ←
        if b ≤ 246 then pure (((b : Int) - 139) * 65536, 1)
        else if b ≤ 250 then
          pure ((((b : Int) - 247) * 256 + (← s.u8 (fr.pos + 1)) + 108) * 65536, 2)
        else if b ≤ 254 then
          pure ((-((b : Int) - 251) * 256 - (← s.u8 (fr.pos + 1)) - 108) * 65536, 2)
        else if b == 255 then pure (← s.i32 (fr.pos + 1), 5)
        else pure (Slice.signed (← s.u16 (fr.pos + 1)) 16 * 65536, 3)
      if t.stack.size ≥ maxStack then T2.err "argument stack overflow"
      t := { t with stack := t.stack.push v }
      frames := setPos (fr.pos + len)
      continue
    frames := setPos (fr.pos + 1)
    let n := t.stack.size
    match b with
    | 1 | 3 | 18 | 23 =>
      t := t.takeWidth (n % 2 == 1) priv.nominalWidth
      t := { t with stems := t.stems + t.stack.size / 2, stack := #[] }
    | 19 | 20 =>
      t := t.takeWidth (n % 2 == 1) priv.nominalWidth
      t := { t with stems := t.stems + t.stack.size / 2, stack := #[] }
      frames := setPos (fr.pos + 1 + (t.stems + 7) / 8)
    | 21 =>
      t := t.takeWidth (n > 2) priv.nominalWidth
      t := { (t.moveBy (t.arg 0) (t.arg 1)) with stack := #[] }
    | 22 =>
      t := t.takeWidth (n > 1) priv.nominalWidth
      t := { (t.moveBy (t.arg 0) 0) with stack := #[] }
    | 4 =>
      t := t.takeWidth (n > 1) priv.nominalWidth
      t := { (t.moveBy 0 (t.arg 0)) with stack := #[] }
    | 5 => t := { (t.rlineto t.stack) with stack := #[] }
    | 6 => t := { (t.altLines t.stack true) with stack := #[] }
    | 7 => t := { (t.altLines t.stack false) with stack := #[] }
    | 8 => t := { (t.rrcurveto t.stack) with stack := #[] }
    | 24 =>
      if n < 8 then T2.err "rcurveline takes at least 8 arguments"
      let t1 := t.rrcurveto (t.stack.extract 0 (n - 2))
      t := { (t1.lineBy (t.arg (n - 2)) (t.arg (n - 1))) with stack := #[] }
    | 25 =>
      if n < 8 then T2.err "rlinecurve takes at least 8 arguments"
      let t1 := t.rlineto (t.stack.extract 0 (n - 6))
      t := { (t1.rrcurveto (t.stack.extract (n - 6) n)) with stack := #[] }
    | 26 => t := { (t.sameCurves t.stack false) with stack := #[] }
    | 27 => t := { (t.sameCurves t.stack true) with stack := #[] }
    | 30 => t := { (t.altCurves t.stack false) with stack := #[] }
    | 31 => t := { (t.altCurves t.stack true) with stack := #[] }
    | 10 | 29 =>
      let some idx := t.stack.back? | T2.err "subroutine call without an index"
      t := { t with stack := t.stack.pop }
      let (subrs, bias) := if b == 10 then (priv.subrs, lbias) else (cff.globalSubrs, gbias)
      let i := idx / 65536 + bias
      if i < 0 || i.toNat ≥ subrs.count then T2.err s!"subroutine {i} of {subrs.count}"
      if frames.size > maxCallDepth then T2.err "subroutines nested too deep"
      frames := frames.push ⟨← subrs.item i.toNat, 0⟩
    | 11 =>
      frames := frames.pop
      if frames.isEmpty then done := true
    | 14 =>
      if n == 4 || n == 5 then T2.err "accented endchar (seac) is not supported"
      t := t.takeWidth (n % 2 == 1) priv.nominalWidth
      t := { t.closePath with stack := #[] }
      done := true
    | 12 =>
      let b2 ← s.u8 (fr.pos + 1)
      frames := setPos (fr.pos + 2)
      if b2 == 34 || b2 == 35 || b2 == 36 || b2 == 37 then
        t := { (← t.flex b2 t.stack) with stack := #[] }
      else T2.err s!"unsupported operator 12 {b2}"
    | _ => T2.err s!"unsupported operator {b}"
  unless done do T2.err "charstring did not end within its fuel"
  let final := t.closePath
  return ⟨⟨final.cmds⟩, final.width.getD priv.defaultWidth⟩

end LeAnTeX.Font
