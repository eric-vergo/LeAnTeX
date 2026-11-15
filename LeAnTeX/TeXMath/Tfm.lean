/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/

/-!
# TeX font metric files

A reader of TFM files, the metric files TeX sets type with, and the font they describe at a
size: each character's width, height, depth and italic correction, its ligature and kern
program, its chain of larger variants or its extensible recipe, and the font's parameters
(`\fontdimen`). The Computer Modern math fonts' parameters σ and ξ come from here.

A metric file is untrusted input. `Tfm.read` checks the file as TeX's `read_font_info` does:
the twelve lengths of its header against each other and the file's size, the indices of every
character into the width, height, depth and italic tables, the first entry of each table, every
step of every ligature and kern program, every next-larger character and extensible recipe
(their characters must exist), and the form of every scaled number (first byte 0 or 255). A
file that fails a check is a `TfmError`, never a panic. Chains of larger characters are
followed at most 256 steps, and ligature programs at most their length, so every query on a
font returns.

## Main definitions

* `Tfm`, `Tfm.read`: the file's tables, unscaled.
* `TfmFont`, `Tfm.at`: the font at a size, its numbers in sp as TeX scales them.
* `TfmFont.char?`, `TfmFont.ligKern`, `TfmFont.param`.

## Implementation notes

Scaling follows TeX exactly: a fix-word's four bytes are multiplied by the size in steps that
keep every intermediate value below 2³¹, as `store_scaled` does, so the scaled widths are TeX's
to the sp at every size, design size or not.

## References

* D. E. Knuth, *TeX: The Program*, §539–§545 (the TFM format), §560–§575 (`read_font_info`,
  its checks and `store_scaled`), §557 (the lig/kern program's indexing).
* D. E. Knuth, *The TeXbook*, Appendix F (the font parameters of math fonts).
-/

namespace LeAnTeX.TeXMath

/-- Why a metric file was refused. -/
structure TfmError where
  /-- What was wrong. -/
  message : String
  deriving BEq, Inhabited, Repr

instance : ToString TfmError := ⟨fun e => "TFM: " ++ e.message⟩

/-- What follows a character: nothing, a ligature and kern program (its first step), the next
larger character, or an extensible recipe (its index). -/
inductive Tag where
  /-- Nothing. -/
  | none
  /-- A ligature and kern program from this step. -/
  | lig (start : Nat)
  /-- The next larger character. -/
  | list (next : Nat)
  /-- An extensible recipe. -/
  | ext (recipe : Nat)
  deriving BEq, Inhabited, Repr

/-- One step of a ligature and kern program: TeX's four bytes `skip_byte`, `next_char`,
`op_byte`, `remainder`. -/
structure LigStep where
  /-- `skip_byte`: above 128 the last step; up to 128, the steps to skip to the next one. -/
  skip : Nat
  /-- The character to the right this step applies to. -/
  next : Nat
  /-- `op_byte`: 128 or more for a kern, below for a ligature of that kind. -/
  op : Nat
  /-- `remainder`: the ligature's character, or the low byte of the kern's index. -/
  rem : Nat
  deriving Inhabited, Repr

/-- An extensible recipe: top, middle, bottom (0 when absent) and the repeated piece. -/
structure Recipe where
  /-- The top piece. -/
  top : Nat
  /-- The middle piece. -/
  mid : Nat
  /-- The bottom piece. -/
  bot : Nat
  /-- The repeated piece. -/
  rep : Nat
  deriving Inhabited, Repr

/-- A character's entry: indices into the dimension tables and its tag. -/
structure CharEntry where
  /-- Index into the widths. -/
  width : Nat
  /-- Index into the heights. -/
  height : Nat
  /-- Index into the depths. -/
  depth : Nat
  /-- Index into the italic corrections. -/
  italic : Nat
  /-- What follows it. -/
  tag : Tag
  deriving Inhabited, Repr

/-- A metric file read and checked; numbers are fix-words (signed, in 2⁻²⁰ of the size). -/
structure Tfm where
  /-- The check sum. -/
  checksum : Nat
  /-- The design size, a fix-word in points. -/
  designSize : Int
  /-- The smallest character code. -/
  bc : Nat
  /-- The largest character code. -/
  ec : Nat
  /-- The characters `bc … ec`; `none` for a code the font does not have. -/
  chars : Array (Option CharEntry)
  /-- The widths. -/
  widths : Array Int
  /-- The heights. -/
  heights : Array Int
  /-- The depths. -/
  depths : Array Int
  /-- The italic corrections. -/
  italics : Array Int
  /-- The ligature and kern steps. -/
  ligKern : Array LigStep
  /-- The kerns. -/
  kerns : Array Int
  /-- The extensible recipes. -/
  recipes : Array Recipe
  /-- The parameters, `\fontdimen1` first (the slant unscaled, the others fix-words). -/
  params : Array Int
  deriving Inhabited

namespace Tfm

/-- The 32-bit word at word index `i`. -/
private def word (b : ByteArray) (i : Nat) : Nat × Nat × Nat × Nat :=
  let at_ := fun (k : Nat) => (b[k]?.getD 0).toNat
  (at_ (4 * i), at_ (4 * i + 1), at_ (4 * i + 2), at_ (4 * i + 3))

/-- A fix-word from its bytes, checked as TeX checks scaled numbers (first byte 0 or 255). -/
private def fix (w : Nat × Nat × Nat × Nat) (what : String) : Except TfmError Int :=
  let (a, b, c, d) := w
  let v : Int := ((b * 256 + c) * 256 + d : Nat)
  if a == 0 then .ok v
  else if a == 255 then .ok (v - 16777216)
  else .error ⟨s!"{what} out of range"⟩

/-- Reads and checks a metric file (see the module docstring for the checks). -/
def read (b : ByteArray) : Except TfmError Tfm := do
  if b.size < 24 then throw ⟨"file shorter than its header"⟩
  let h := fun (i : Nat) => (b[2 * i]?.getD 0).toNat * 256 + (b[2 * i + 1]?.getD 0).toNat
  let (lf, lh, bc, ec) := (h 0, h 1, h 2, h 3)
  let (nw, nh, nd, ni, nl, nk, ne, np) := (h 4, h 5, h 6, h 7, h 8, h 9, h 10, h 11)
  if lf ≥ 32768 || lh ≥ 32768 || nl ≥ 32768 || nk ≥ 32768 || np ≥ 32768 then
    throw ⟨"a length is negative"⟩
  if bc > ec + 1 || ec > 255 then throw ⟨"character range"⟩
  let (bc, ec) := if bc > 255 then (1, 0) else (bc, ec)
  let nc := ec + 1 - bc
  if lf ≠ 6 + lh + nc + nw + nh + nd + ni + nl + nk + ne + np then
    throw ⟨"lengths do not add up"⟩
  if nw == 0 || nh == 0 || nd == 0 || ni == 0 then throw ⟨"an empty dimension table"⟩
  if lh < 2 then throw ⟨"header too short"⟩
  if nh > 16 || nd > 16 || ni > 64 || ne > 256 then throw ⟨"a table too long"⟩
  if b.size < 4 * lf then throw ⟨"file shorter than its lengths"⟩
  let w := fun (i : Nat) => word b (6 + i)
  let (c0, c1, c2, c3) := w 0
  let checksum := ((c0 * 256 + c1) * 256 + c2) * 256 + c3
  let (d0, d1, d2, d3) := w 1
  if d0 ≥ 128 then throw ⟨"design size negative"⟩
  let designSize : Int := (((d0 * 256 + d1) * 256 + d2) * 256 + d3 : Nat)
  if designSize < 1048576 then throw ⟨"design size below 1pt"⟩
  let ci := lh
  let wi := ci + nc
  let hi := wi + nw
  let di := hi + nh
  let ii := di + nd
  let li := ii + ni
  let ki := li + nl
  let ei := ki + nk
  let pi := ei + ne
  let table := fun (start n : Nat) (what : String) => do
    let mut out : Array Int := #[]
    for k in [0:n] do out := out.push (← fix (w (start + k)) what)
    return out
  let widths ← table wi nw "width"
  let heights ← table hi nh "height"
  let depths ← table di nd "depth"
  let italics ← table ii ni "italic correction"
  let first := fun (xs : Array Int) => xs.getD 0 0
  if first widths ≠ 0 || first heights ≠ 0 || first depths ≠ 0 || first italics ≠ 0 then
    throw ⟨"a dimension table does not start with 0"⟩
  let kerns ← table ki nk "kern"
  let ligKern := (Array.range nl).map fun k =>
    let (s, n, o, r) := w (li + k)
    ({ skip := s, next := n, op := o, rem := r } : LigStep)
  let recipes := (Array.range ne).map fun k =>
    let (t, m, bo, r) := w (ei + k)
    ({ top := t, mid := m, bot := bo, rep := r } : Recipe)
  let mut params : Array Int := #[]
  for k in [0:np] do
    if k == 0 then
      let (a, b1, c, d) := w pi
      let v : Int := (((a * 256 + b1) * 256 + c) * 256 + d : Nat)
      params := params.push (if a ≥ 128 then v - 4294967296 else v)
    else params := params.push (← fix (w (pi + k)) "parameter")
  let mut chars : Array (Option CharEntry) := #[]
  for k in [0:nc] do
    let (a, bb, c, d) := w (ci + k)
    if a == 0 then chars := chars.push none
    else
      if a ≥ nw || bb / 16 ≥ nh || bb % 16 ≥ nd || c / 4 ≥ ni then
        throw ⟨s!"character {bc + k}: index out of range"⟩
      let tag : Tag := match c % 4 with
        | 1 => .lig d | 2 => .list d | 3 => .ext d | _ => .none
      chars := chars.push (some
        { width := a, height := bb / 16, depth := bb % 16, italic := c / 4, tag })
  let exists_ := fun (c : Nat) => c ≥ bc && c ≤ ec && (chars[c - bc]?.join).isSome
  -- the boundary character of the first step, which programs may name though it is absent
  let bchar := match ligKern[0]? with
    | some s => if s.skip == 255 then some s.next else none
    | none => none
  -- ligature and kern steps: the indices they reach and the characters they make
  for k in [0:nl] do
    let s := ligKern.getD k default
    if s.skip < 128 && k + s.skip + 1 ≥ nl then throw ⟨s!"lig/kern step {k}: skip past the end"⟩
    if s.op ≥ 128 && 256 * (s.op - 128) + s.rem ≥ nk then
      throw ⟨s!"lig/kern step {k}: kern index"⟩
    if s.op < 128 && s.skip ≤ 128 && !exists_ s.rem then
      throw ⟨s!"lig/kern step {k}: ligature character"⟩
    if s.op < 128 && s.skip ≤ 128 && !([0, 1, 2, 3, 5, 6, 7, 11] : List Nat).contains s.op then
      throw ⟨s!"lig/kern step {k}: ligature kind"⟩
    if s.skip ≤ 128 && !exists_ s.next && bchar != some s.next then
      throw ⟨s!"lig/kern step {k}: character {s.next} absent"⟩
  for k in [0:nc] do
    match chars.getD k none with
    | some e =>
      match e.tag with
      | .lig start =>
        if start ≥ nl then throw ⟨s!"character {bc + k}: lig/kern start"⟩
        let s := ligKern.getD start default
        if s.skip > 128 && 256 * s.op + s.rem ≥ nl then
          throw ⟨s!"character {bc + k}: lig/kern restart"⟩
      | .list n => if !exists_ n then throw ⟨s!"character {bc + k}: next larger absent"⟩
      | .ext r =>
        match recipes[r]? with
        | none => throw ⟨s!"character {bc + k}: recipe index"⟩
        | some rc =>
          if !exists_ rc.rep then throw ⟨s!"character {bc + k}: recipe piece absent"⟩
          for p in [rc.top, rc.mid, rc.bot] do
            if p ≠ 0 && !exists_ p then throw ⟨s!"character {bc + k}: recipe piece absent"⟩
      | .none => pure ()
    | none => pure ()
  return { checksum, designSize, bc, ec, chars, widths, heights, depths, italics, ligKern,
           kerns, recipes, params }

/-- The entry of a character code, if the font has it. -/
def entry? (t : Tfm) (c : Nat) : Option CharEntry :=
  if c < t.bc || c > t.ec then none else (t.chars[c - t.bc]?).join

end Tfm

/-- A character's metrics in sp at a font's size, with its tag. -/
structure CharMetrics where
  /-- The width. -/
  width : Int
  /-- The height. -/
  height : Int
  /-- The depth. -/
  depth : Int
  /-- The italic correction. -/
  italic : Int
  /-- What follows it. -/
  tag : Tag
  deriving Inhabited, Repr

/-- The result of a ligature and kern program for a pair: a kern (sp), a ligature (TeX's kind
`op_byte` and the character it makes), or nothing. -/
inductive LigKern where
  /-- No step for the pair. -/
  | none
  /-- A kern between the two. -/
  | kern (width : Int)
  /-- A ligature of this kind making this character. -/
  | lig (op char : Nat)
  deriving BEq, Inhabited, Repr

/-- A metric file at a size: its tables scaled to sp as TeX scales them. -/
structure TfmFont where
  /-- The file's name without extension (`cmmi7`), for the display list and messages. -/
  name : String
  /-- The size, in sp. -/
  size : Int
  /-- The tables, unscaled. -/
  tfm : Tfm
  /-- The widths in sp. -/
  widths : Array Int
  /-- The heights in sp. -/
  heights : Array Int
  /-- The depths in sp. -/
  depths : Array Int
  /-- The italic corrections in sp. -/
  italics : Array Int
  /-- The kerns in sp. -/
  kerns : Array Int
  /-- The parameters in sp (`\fontdimen1`, the slant, unscaled). -/
  params : Array Int
  /-- `\skewchar`, the character whose kerns place accents (`none` for -1). -/
  skewChar : Option Nat := none
  deriving Inhabited

/-- TeX's scaling of a fix-word to a size in sp (`store_scaled`): the size is halved until it
is below 2²³, and the bytes of the fix-word are multiplied in turn so no product exceeds 2³¹.
`size` must be positive and below 2048 pt. -/
def scaleFix (size : Int) (fw : Int) : Int := Id.run do
  let mut z := size
  let mut alpha : Int := 16
  for _ in [0:8] do
    if z ≥ 8388608 then
      z := z / 2
      alpha := alpha + alpha
  let beta := 256 / alpha
  let whole := alpha * z
  let neg := fw < 0
  let v := if neg then fw + 16777216 else fw
  let b := v / 65536
  let c := (v / 256) % 256
  let d := v % 256
  let sw := ((((d * z) / 256) + (c * z)) / 256 + (b * z)) / beta
  return if neg then sw - whole else sw

/-- The largest size a font may be loaded at (TeX's limit, 2048 pt, exclusive). -/
def maxFontSize : Int := 2048 * 65536

/-- The font at `size` sp (`none` for its design size). A size of 0 or less, or of 2048 pt or
more, is refused, as TeX refuses it. -/
def Tfm.at (t : Tfm) (name : String) (size : Option Int := none) (skewChar : Option Nat := none) :
    Except TfmError TfmFont := do
  let s := size.getD (t.designSize / 16)
  if s ≤ 0 || s ≥ maxFontSize then throw ⟨s!"size {s}sp out of range"⟩
  let sc := fun (xs : Array Int) => xs.map (scaleFix s)
  let params := t.params.mapIdx fun i v => if i == 0 then v else scaleFix s v
  return { name, size := s, tfm := t, widths := sc t.widths, heights := sc t.heights,
           depths := sc t.depths, italics := sc t.italics, kerns := sc t.kerns, params,
           skewChar }

namespace TfmFont

/-- The metrics of a character, if the font has it. -/
def char? (f : TfmFont) (c : Nat) : Option CharMetrics := do
  let e ← f.tfm.entry? c
  return { width := f.widths.getD e.width 0, height := f.heights.getD e.height 0,
           depth := f.depths.getD e.depth 0, italic := f.italics.getD e.italic 0, tag := e.tag }

/-- `\fontdimen n` (from 1), 0 when the font has fewer parameters. -/
def param (f : TfmFont) (n : Nat) : Int := if n == 0 then 0 else f.params.getD (n - 1) 0

/-- The number of parameters. -/
def paramCount (f : TfmFont) : Nat := f.params.size

/-- The first step of a character's ligature and kern program, after TeX's restart for a
program whose first step's `skip_byte` exceeds 128. -/
def ligStart (f : TfmFont) (c : Nat) : Option Nat := do
  let e ← f.tfm.entry? c
  let .lig start := e.tag | none
  let s ← f.tfm.ligKern[start]?
  if s.skip > 128 then some (256 * s.op + s.rem) else some start

/-- What the program of `left` does before `right`: the first step for `right` that is not
past the program's last step. At most the program's length in steps. -/
def ligKern (f : TfmFont) (left right : Nat) : LigKern := Id.run do
  let some start := f.ligStart left | return .none
  let mut k := start
  for _ in [0:f.tfm.ligKern.size + 1] do
    let some s := f.tfm.ligKern[k]? | return .none
    if s.next == right && s.skip ≤ 128 then
      if s.op ≥ 128 then return .kern (f.kerns.getD (256 * (s.op - 128) + s.rem) 0)
      else return .lig s.op s.rem
    if s.skip ≥ 128 then return .none
    k := k + s.skip + 1
  return .none

/-- The kern of `left`'s program before the skew character (TeX's skew of an accent): the
first step naming the skew character decides; a ligature step there gives 0. -/
def skew (f : TfmFont) (left : Nat) : Int :=
  match f.skewChar with
  | none => 0
  | some sc => Id.run do
    let some start := f.ligStart left | return 0
    let mut k := start
    for _ in [0:f.tfm.ligKern.size + 1] do
      let some s := f.tfm.ligKern[k]? | return 0
      if s.next == sc then
        if s.op ≥ 128 && s.skip ≤ 128 then return f.kerns.getD (256 * (s.op - 128) + s.rem) 0
        return 0
      if s.skip ≥ 128 then return 0
      k := k + s.skip + 1
    return 0

/-- The extensible recipe of a character, if it has one. -/
def recipe? (f : TfmFont) (c : Nat) : Option Recipe := do
  let e ← f.tfm.entry? c
  let .ext r := e.tag | none
  f.tfm.recipes[r]?

end TfmFont

end LeAnTeX.TeXMath
