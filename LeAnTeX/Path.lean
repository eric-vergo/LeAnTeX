/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/

/-!
# Paths

Outlines as sequences of moves, lines, quadratic and cubic Béziers and closes, over any
coordinate type. Glyph outlines from fonts (`LeAnTeX.Font`) are paths of exact fixed-point
coordinates (`Int`, in 1/65536 of a font unit); `Path.svgData` writes a path as SVG path data,
the form the display list's `Item.path` carries.

## Main definitions

* `Point`, `PathCmd`, `Path`: the path type; `Path.map` changes the coordinates.
* `Path.controlBounds`: the box of all points of the path, control points included.
* `Path.bounds`: the tight box of an `Int` path, curves' extrema included.
* `Path.svgData`: SVG path data with absolute commands (`M`, `L`, `Q`, `C`, `Z`).
-/

namespace LeAnTeX

/-- A point of the plane. -/
structure Point (α : Type) where
  /-- The abscissa. -/
  x : α
  /-- The ordinate. -/
  y : α
  deriving BEq, DecidableEq, Hashable, Inhabited, Repr

/-- A drawing command of a path, in absolute coordinates. -/
inductive PathCmd (α : Type) where
  /-- Start a new subpath at the point. -/
  | move (p : Point α)
  /-- A straight line to the point. -/
  | line (p : Point α)
  /-- A quadratic Bézier with control point `c` to `p`. -/
  | quad (c p : Point α)
  /-- A cubic Bézier with control points `c1`, `c2` to `p`. -/
  | cubic (c1 c2 p : Point α)
  /-- Close the subpath with a line back to its start. -/
  | close
  deriving BEq, Inhabited, Repr

/-- A path: its commands in order. A path that does not start with `move` starts at the
origin, as in SVG. -/
structure Path (α : Type) where
  /-- The commands. -/
  cmds : Array (PathCmd α) := #[]
  deriving BEq, Inhabited, Repr

/-- An axis-aligned box: its least and greatest coordinates. -/
structure Bounds (α : Type) where
  /-- The least abscissa. -/
  xMin : α
  /-- The least ordinate. -/
  yMin : α
  /-- The greatest abscissa. -/
  xMax : α
  /-- The greatest ordinate. -/
  yMax : α
  deriving BEq, DecidableEq, Inhabited, Repr

namespace Point

variable {α β : Type}

/-- The point with both coordinates mapped by `f`. -/
def map (f : α → β) (p : Point α) : Point β := ⟨f p.x, f p.y⟩

end Point

namespace PathCmd

variable {α β : Type}

/-- The command with every coordinate mapped by `f`. -/
def map (f : α → β) : PathCmd α → PathCmd β
  | .move p => .move (p.map f)
  | .line p => .line (p.map f)
  | .quad c p => .quad (c.map f) (p.map f)
  | .cubic c1 c2 p => .cubic (c1.map f) (c2.map f) (p.map f)
  | .close => .close

/-- The command's points, control points included, in order. -/
def points : PathCmd α → List (Point α)
  | .move p | .line p => [p]
  | .quad c p => [c, p]
  | .cubic c1 c2 p => [c1, c2, p]
  | .close => []

end PathCmd

namespace Bounds

variable {α : Type}

/-- The smallest box containing both boxes. -/
def union [Min α] [Max α] (a b : Bounds α) : Bounds α :=
  ⟨min a.xMin b.xMin, min a.yMin b.yMin, max a.xMax b.xMax, max a.yMax b.yMax⟩

/-- The box of one point. -/
def ofPoint (p : Point α) : Bounds α := ⟨p.x, p.y, p.x, p.y⟩

/-- The smallest box containing the box and the point. -/
def add [Min α] [Max α] (b : Bounds α) (p : Point α) : Bounds α := b.union (ofPoint p)

end Bounds

namespace Path

variable {α β : Type}

/-- The path with every coordinate mapped by `f`. -/
def map (f : α → β) (p : Path α) : Path β := ⟨p.cmds.map (·.map f)⟩

/-- The number of commands. -/
def size (p : Path α) : Nat := p.cmds.size

/-- The box of every point of the path, control points included; `none` for a path without
points. -/
def controlBounds [Min α] [Max α] (p : Path α) : Option (Bounds α) :=
  p.cmds.foldl (init := none) fun acc c =>
    c.points.foldl (init := acc) fun b q =>
      some (match b with | none => Bounds.ofPoint q | some b => b.add q)

/-- The parameters in `(0, 1)` where the derivative of the quadratic or cubic Bézier with
coefficients `p0 … p3` (one coordinate) vanishes. -/
private def extremaParams (cs : List Float) : List Float :=
  let inside (t : Float) : Bool := t > 0 && t < 1
  match cs with
  | [a, b, c] =>
    -- B'(t) = 2((1-t)(b-a) + t(c-b)) = 0 at t = (a-b)/(a-2b+c).
    let d := a - 2 * b + c
    if d == 0 then [] else [(a - b) / d].filter inside
  | [a, b, c, e] =>
    -- B'(t)/3 = A t² + B t + C with A = -a+3b-3c+e, B = 2(a-2b+c), C = b-a.
    let qa := -a + 3 * b - 3 * c + e
    let qb := 2 * (a - 2 * b + c)
    let qc := b - a
    if qa.abs < 1e-12 then
      if qb == 0 then [] else [-qc / qb].filter inside
    else
      let disc := qb * qb - 4 * qa * qc
      if disc < 0 then []
      else
        let r := disc.sqrt
        [(-qb + r) / (2 * qa), (-qb - r) / (2 * qa)].filter inside
  | _ => []

/-- The value at `t` of the Bézier with coefficients `cs` (one coordinate). -/
private def bezierAt (cs : List Float) (t : Float) : Float :=
  match cs with
  | [a, b, c] => (1 - t) * (1 - t) * a + 2 * (1 - t) * t * b + t * t * c
  | [a, b, c, e] =>
    let s := 1 - t
    s * s * s * a + 3 * s * s * t * b + 3 * s * t * t * c + t * t * t * e
  | _ => 0

/-- The tight box of a path with `Int` coordinates: the end points of every segment and the
extrema of its curves, the extrema rounded outwards to whole units. `none` for a path without
points. A subpath's start counts even when nothing is drawn from it, as in fontTools' and
FreeType's bounds of glyph outlines. -/
def bounds (p : Path Int) : Option (Bounds Int) := Id.run do
  let mut b : Option (Bounds Int) := none
  let mut cur : Point Int := ⟨0, 0⟩
  let mut start : Point Int := ⟨0, 0⟩
  let addPt := fun (b : Option (Bounds Int)) (q : Point Int) =>
    some (match b with | none => Bounds.ofPoint q | some b => b.add q)
  for c in p.cmds do
    match c with
    | .move q => b := addPt b q; cur := q; start := q
    | .line q => b := addPt b q; cur := q
    | .close => cur := start
    | .quad c1 q =>
      b := addPt b q
      b := extrema b [cur, c1, q]
      cur := q
    | .cubic c1 c2 q =>
      b := addPt b q
      b := extrema b [cur, c1, c2, q]
      cur := q
  return b
where
  /-- The box widened by the extrema of one curve. -/
  extrema (b : Option (Bounds Int)) (pts : List (Point Int)) : Option (Bounds Int) := Id.run do
    let xs := pts.map fun q => Float.ofInt q.x
    let ys := pts.map fun q => Float.ofInt q.y
    let mut out := b
    for t in extremaParams xs do
      let v := bezierAt xs t
      out := out.map fun bb =>
        { bb with xMin := min bb.xMin (floorInt v), xMax := max bb.xMax (ceilInt v) }
    for t in extremaParams ys do
      let v := bezierAt ys t
      out := out.map fun bb =>
        { bb with yMin := min bb.yMin (floorInt v), yMax := max bb.yMax (ceilInt v) }
    return out
  /-- `⌊v⌋` as an integer (`0` for a non-finite value). -/
  floorInt (v : Float) : Int :=
    if v.isNaN || v.isInf then 0
    else if v ≥ 0 then v.floor.toUInt64.toNat else -((-v).ceil.toUInt64.toNat : Int)
  /-- `⌈v⌉` as an integer (`0` for a non-finite value). -/
  ceilInt (v : Float) : Int :=
    if v.isNaN || v.isInf then 0
    else if v ≥ 0 then v.ceil.toUInt64.toNat else -((-v).floor.toUInt64.toNat : Int)

/-- SVG path data for the path, with absolute commands and each coordinate written by `fmt`:
`M x y`, `L x y`, `Q cx cy x y`, `C c1x c1y c2x c2y x y`, `Z`, separated by spaces. -/
def svgData (fmt : α → String) (p : Path α) : String :=
  let pt (q : Point α) : String := fmt q.x ++ " " ++ fmt q.y
  let parts := p.cmds.toList.map fun
    | .move q => "M" ++ pt q
    | .line q => "L" ++ pt q
    | .quad c q => "Q" ++ pt c ++ " " ++ pt q
    | .cubic c1 c2 q => "C" ++ pt c1 ++ " " ++ pt c2 ++ " " ++ pt q
    | .close => "Z"
  " ".intercalate parts

end Path

end LeAnTeX
