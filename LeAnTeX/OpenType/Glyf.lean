/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.OpenType.Binary
import LeAnTeX.Path

/-!
# TrueType outlines

The `loca` and `glyf` tables of a font with TrueType outlines: simple glyphs as quadratic
paths (the on-curve points TrueType leaves implied between two off-curve points made explicit),
and composite glyphs as their components placed by offset and 2×2 transform.

## Main definitions

* `Glyf`, `Glyf.read`: the glyph offsets, checked to ascend inside `glyf`.
* `Glyf.outline`: a glyph's path in 1/65536 font units.

## Implementation notes

Composites nest at most `maxComponentDepth` deep and a glyph has at most `maxOutlinePoints`
points with its components, so a cyclic or exponentially shared composite ends with an error.
Components positioned by matching points (not by offsets) are reported as unsupported.
Instructions (hinting) are skipped.

## References

* The OpenType specification 1.9.1, "loca", "glyf".
-/

namespace LeAnTeX.OpenType

/-- How deep composite glyphs may nest. -/
def maxComponentDepth : Nat := 8

/-- The most points (and components) one glyph may have, its components' included. -/
def maxOutlinePoints : Nat := 65536

/-- The glyph data of a TrueType font. -/
structure Glyf where
  /-- The `glyf` table. -/
  glyf : Slice
  /-- Glyph `g` is `[offsets[g], offsets[g+1])` of `glyf`. -/
  offsets : Array Nat

/-- Reads `loca` (`long` for 32-bit offsets) for `numGlyphs` glyphs. -/
def Glyf.read (loca glyf : Slice) (numGlyphs : Nat) (long : Bool) : Result Glyf := do
  let mut offs := Array.mkEmpty (numGlyphs + 1)
  for i in [0:numGlyphs + 1] do
    let o ← if long then loca.u32 (4 * i) else pure (2 * (← loca.u16 (2 * i)))
    if o < (offs.back?.getD 0) || o > glyf.size then loca.fail "glyph offsets out of order"
    offs := offs.push o
  return ⟨glyf, offs⟩

/-- A 2×2 transform and offset, in 1/65536. -/
private structure Affine where
  a : Int := 65536
  b : Int := 0
  c : Int := 0
  d : Int := 65536
  dx : Int := 0
  dy : Int := 0

/-- The point under the transform (`x' = a x + c y + dx`, `y' = b x + d y + dy`), rounded to the
nearest 1/65536. -/
private def Affine.apply (m : Affine) (p : Point Int) : Point Int :=
  let r := fun (v : Int) => (v + 32768) / 65536
  ⟨r (m.a * p.x + m.c * p.y) + m.dx, r (m.b * p.x + m.d * p.y) + m.dy⟩

/-- `m` after `n`: the transform that applies `n`, then `m`. -/
private def Affine.comp (m n : Affine) : Affine :=
  let r := fun (v : Int) => (v + 32768) / 65536
  { a := r (m.a * n.a + m.c * n.b), b := r (m.b * n.a + m.d * n.b),
    c := r (m.a * n.c + m.c * n.d), d := r (m.b * n.c + m.d * n.d),
    dx := (m.apply ⟨n.dx, n.dy⟩).x, dy := (m.apply ⟨n.dx, n.dy⟩).y }

/-- The quadratic path of one contour's points (`on` marks on-curve points). It starts at the
first on-curve point, or (no point on the curve) at the implied point between the last and the
first; a closing line back to the start is left to `close`. These are the start and segments
fontTools' reader gives. -/
private def contourPath (pts : Array (Point Int × Bool)) : Array (PathCmd Int) := Id.run do
  let n := pts.size
  let mid := fun (p q : Point Int) => (⟨(p.x + q.x) / 2, (p.y + q.y) / 2⟩ : Point Int)
  let some (p0, _) := pts[0]? | return #[]
  let some (pl, _) := pts[n - 1]? | return #[]
  let (start, others) : Point Int × Array (Point Int × Bool) :=
    match pts.findIdx? (·.2) with
    | some k => ((pts[k]?.map (·.1)).getD p0, pts.extract (k + 1) n ++ pts.extract 0 k)
    | none => (mid pl p0, pts)
  let mut out : Array (PathCmd Int) := #[.move start]
  let mut ctrl : Option (Point Int) := none
  for (p, on) in others do
    if on then
      out := out.push (match ctrl with | some c => .quad c p | none => .line p)
      ctrl := none
    else
      match ctrl with
      | some c => out := out.push (.quad c (mid c p)); ctrl := some p
      | none => ctrl := some p
  match ctrl with
  | some c => out := out.push (.quad c start)
  | none => pure ()
  return out.push .close

/-- The points of a simple glyph's contours, in font units. -/
private def simplePoints (s : Slice) (contours : Nat) :
    Result (Array (Array (Point Int × Bool))) := do
  let ends ← (List.range contours).toArray.mapM fun i => s.u16 (10 + 2 * i)
  let n := (ends.back?.getD 0) + 1
  if n > maxOutlinePoints then s.fail "too many points"
  for i in [1:ends.size] do
    if (ends[i]?.getD 0) ≤ (ends[i - 1]?.getD 0) then s.fail "contour ends out of order"
  let insLen ← s.u16 (10 + 2 * contours)
  let mut off := 12 + 2 * contours + insLen
  let mut flags := Array.mkEmpty n
  for _ in [0:n] do
    if flags.size < n then
      let f ← s.u8 off
      off := off + 1
      flags := flags.push f
      if f &&& 8 != 0 then
        let r ← s.u8 off
        off := off + 1
        for _ in [0:r] do flags := flags.push f
  if flags.size < n then s.fail "flags shorter than the points"
  let readCoords := fun (short same : Nat) (off0 : Nat) => do
    let mut p := off0
    let mut v : Int := 0
    let mut out := Array.mkEmpty n
    for i in [0:n] do
      let f := flags[i]?.getD 0
      if f &&& short != 0 then
        let d ← s.u8 p
        p := p + 1
        v := v + (if f &&& same != 0 then (d : Int) else -(d : Int))
      else if f &&& same == 0 then
        v := v + (← s.i16 p)
        p := p + 2
      out := out.push v
    return (out, p)
  let (xs, yOff) ← readCoords 2 16 off
  let (ys, _) ← readCoords 4 32 yOff
  let mut out := #[]
  let mut startIdx := 0
  for e in ends do
    let pts := (List.range (e + 1 - startIdx)).toArray.map fun j =>
      let i := startIdx + j
      ((⟨(xs[i]?.getD 0) * 65536, (ys[i]?.getD 0) * 65536⟩ : Point Int),
        (flags[i]?.getD 0) &&& 1 != 0)
    out := out.push pts
    startIdx := e + 1
  return out

/-- Glyph `g`'s outline under the transform, appended to `acc`, at composite depth `depth`;
the count of points so far is kept in `acc.2`. -/
private def outlineInto (gl : Glyf) (g : Nat) (m : Affine) :
    Nat → Array (PathCmd Int) × Nat → Result (Array (PathCmd Int) × Nat)
  | 0, _ => fail "glyf" "composite glyphs nested too deep"
  | depth + 1, (acc, npts) => do
    let some a := gl.offsets[g]? | fail "glyf" s!"no glyph {g}"
    let some b := gl.offsets[g + 1]? | fail "glyf" s!"no glyph {g}"
    if a == b then return (acc, npts)
    let s ← gl.glyf.sub a (b - a)
    let nc ← s.i16 0
    if nc ≥ 0 then
      let contours ← simplePoints s nc.toNat
      let np := contours.foldl (fun k c => k + c.size) npts
      if np > maxOutlinePoints then s.fail "too many points"
      let mut acc := acc
      for c in contours do
        acc := acc ++ contourPath (c.map fun (p, on) => (m.apply p, on))
      return (acc, np)
    else
      let mut off := 10
      let mut st := (acc, npts)
      let mut more := true
      -- Each component takes at least four bytes.
      for _ in [0:s.size / 4 + 1] do
        if more then
          let flags ← s.u16 off
          let child ← s.u16 (off + 2)
          off := off + 4
          let (dx, dy) ← if flags &&& 1 != 0 then do
              let r := (← s.i16 off, ← s.i16 (off + 2)); off := off + 4; pure r
            else do
              let r := (Slice.signed (← s.u8 off) 8, Slice.signed (← s.u8 (off + 1)) 8)
              off := off + 2; pure r
          if flags &&& 2 == 0 then s.fail "components placed by points are not supported"
          let mut n : Affine := { dx := dx * 65536, dy := dy * 65536 }
          if flags &&& 8 != 0 then
            let k ← s.f2dot14 off; off := off + 2
            n := { n with a := k, d := k }
          else if flags &&& 64 != 0 then
            n := { n with a := ← s.f2dot14 off, d := ← s.f2dot14 (off + 2) }; off := off + 4
          else if flags &&& 128 != 0 then
            n := { n with a := ← s.f2dot14 off, b := ← s.f2dot14 (off + 2),
                          c := ← s.f2dot14 (off + 4), d := ← s.f2dot14 (off + 6) }
            off := off + 8
          -- A component counts as a point, so empty components cannot multiply without end.
          if st.2 + 1 > maxOutlinePoints then s.fail "too many components"
          st ← outlineInto gl child (m.comp n) depth (st.1, st.2 + 1)
          more := flags &&& 32 != 0
      if more then s.fail "composite glyph without an end"
      return st

/-- Glyph `g`'s outline in 1/65536 font units. -/
def Glyf.outline (gl : Glyf) (g : Nat) : Result (Path Int) := do
  let (cmds, _) ← outlineInto gl g {} (maxComponentDepth + 1) (#[], 0)
  return ⟨cmds⟩

end LeAnTeX.OpenType
