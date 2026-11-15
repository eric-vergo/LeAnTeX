/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Text.LineBreak

/-!
# Lines from breaks

What TeX does after choosing the breaks (its `post_line_break` and `hpack`): each line's nodes,
with `\leftskip` and `\rightskip`, and the glue setting that makes it as long as its line
length.

* A line ends at its break: glue there is replaced by `\rightskip`; a penalty stays; a kern
  stays with width 0; a discretionary ends the line with its `pre` text. `\rightskip` ends every
  line and `\leftskip` (when not zero) starts it.
* The next line starts with the broken discretionary's `post` text; otherwise discardable nodes
  (glue, penalties, explicit kerns) after the break are dropped, up to the next break.
* A line's glue is set as TeX's `hpack` sets it: stretched or shrunk in the highest order of
  glue that has any, by the ratio of the difference to the total; finite shrink never beyond
  its total (an overfull line keeps glue set 1). The ratio is a `Float`, the quotient of the two
  integers rounded to single precision, as LuaTeX stores it.

## Main definitions

* `Line`, `GlueSet`: a line and its glue setting.
* `lineRanges`: the nodes of the input each line takes, and what is dropped between lines.
* `setLines`: the lines of a paragraph.
-/

namespace LeAnTeX.Text

/-- How a box's glue is set: `sign` 0 natural, 1 stretched, 2 shrunk; the order of the glue
that is set and the ratio. -/
structure GlueSet where
  /-- 0 natural, 1 stretched, 2 shrunk. -/
  sign : Nat := 0
  /-- The order of the glue that is set. -/
  order : Nat := 0
  /-- The ratio. -/
  ratio : Float := 0
  deriving Inhabited, Repr

/-- A line of a paragraph. -/
structure Line where
  /-- Its nodes, `\leftskip` and `\rightskip` included. -/
  nodes : Array HNode
  /-- Its length (`\hsize`, or the hanging indentation's or `\parshape`'s). -/
  width : Int
  /-- Its indentation from the left margin. -/
  indent : Int
  /-- Its natural width. -/
  natural : Int
  /-- Its height and depth. -/
  height : Int
  /-- Its depth. -/
  depth : Int
  /-- The glue setting. -/
  glue : GlueSet
  deriving Inhabited

/-- `x / s`, computed in double precision and rounded to single precision, as LuaTeX stores a
glue ratio (a 32-bit float). -/
def ratio32 (x s : Int) : Float := (Float.ofInt x / Float.ofInt s).toFloat32.toFloat

/-- The glue setting of a list whose natural totals are `t` (stretch and shrink of each order,
`shrinks`) in a box `width` long: TeX's `hpack`. -/
def hpackGlue (natural width : Int) (stretch shrink : Array Int) : GlueSet :=
  let x := width - natural
  let order (a : Array Int) : Nat :=
    if a[3]?.getD 0 != 0 then 3 else if a[2]?.getD 0 != 0 then 2
    else if a[1]?.getD 0 != 0 then 1 else 0
  if x == 0 then {}
  else if x > 0 then
    let o := order stretch
    let s := stretch[o]?.getD 0
    if s != 0 then { sign := 1, order := o, ratio := ratio32 x s }
    else { order := o }
  else
    let o := order shrink
    let s := shrink[o]?.getD 0
    -- TeX sets the ratio to 1 for an overfull list even when it has no shrink to set
    if s == 0 then { order := o, ratio := if o == 0 then 1 else 0 }
    else if s < -x && o == 0 then { sign := 2, order := o, ratio := 1 }
    else { sign := 2, order := o, ratio := ratio32 (-x) s }

/-- The natural width, the stretch and shrink of each order, the height and the depth of a
list of nodes. -/
def measure (nodes : Array HNode) : Int × Array Int × Array Int × Int × Int :=
  nodes.foldl (init := (0, #[0, 0, 0, 0], #[0, 0, 0, 0], 0, 0)) fun (w, st, sh, h, d) n =>
    let (st, sh) := match n with
      | .glue g _ =>
        (st.modify g.stretchOrder (· + g.stretch), sh.modify g.shrinkOrder (· + g.shrink))
      | _ => (st, sh)
    let (h, d) := match n with
      | .disc _ _ _ r _ => r.foldl (init := (h, d)) fun (h, d) m => (max h m.height, max d m.depth)
      | _ => (max h n.height, max d n.depth)
    (w + n.width, st, sh, h, d)

/-- `pruneFrom` with at most `fuel` steps. -/
def pruneGo (items : Array HNode) (stop : Nat) : Nat → Nat → Nat
  | 0, k => k
  | fuel + 1, k =>
    if k ≥ stop then k
    else match items[k]? with
      | some n => if n.discardable then pruneGo items stop fuel (k + 1) else k
      | none => k

/-- The first index at or after `j` that holds a node a line keeps at its start, stopping at
`stop` (the next break) and at the list's end: TeX's pruning after a break. -/
def pruneFrom (items : Array HNode) (j stop : Nat) : Nat := pruneGo items stop items.size j

/-- Where the line after a break at node `b` starts, the next break being at `next`: after the
break, past the nodes pruned there (none after a discretionary with a `post` text). -/
def nextStart (items : Array HNode) (b next : Nat) : Nat :=
  match items[b]? with
  | some (.disc _ _ po _ _) => if po.isEmpty then pruneFrom items (b + 1) next else b + 1
  | some (.glue ..) | some (.penalty _) | some (.kern ..) => pruneFrom items (b + 1) next
  | _ => b + 1

/-- Per line, the range of input nodes it holds (`start`, `stop`, `stop` the index of its
break), given the breaks in increasing order: the first line starts at 0, each later one where
`nextStart` puts it. -/
def lineRanges (items : Array HNode) (breaks : Array Nat) : Array (Nat × Nat) :=
  Array.ofFn fun (k : Fin breaks.size) =>
    (match k.val with
      | 0 => 0
      | j + 1 => nextStart items (breaks[j]?.getD 0) breaks[k],
     breaks[k])

/-- The lines of a paragraph broken at `breaks` (from `breakParagraph`), with their glue set to
their lengths. -/
def setLines (items : Array HNode) (p : Params) (breaks : Array Break) : Array Line := Id.run do
  let ranges := lineRanges items (breaks.map (·.pos))
  let mut out := #[]
  let mut post : Array HNode := #[]
  for h : k in [0:ranges.size] do
    let (a, b) := ranges[k]
    let l := p.prevGraf + k + 1
    let (indent, width) := lineShape p l
    let body := post ++ items.extract a b
    let (ending, nextPost) := match items[b]? with
      | some (.glue ..) => (#[], #[])
      | some (.kern _ kk) => (#[HNode.kern 0 kk], #[])
      | some (.disc _ pr po _ _) => (pr, po)
      | some n => (#[n], #[])
      | none => (#[], #[])
    post := nextPost
    let ls := if p.leftSkip == ({} : Glue) then #[] else #[HNode.glue p.leftSkip 8]
    let nodes := ls ++ body ++ ending ++ #[HNode.glue p.rightSkip 9]
    let (natural, st, sh, ht, dp) := measure nodes
    let line : Line :=
      { nodes, width, indent, natural, height := ht, depth := dp,
        glue := hpackGlue natural width st sh }
    out := out.push line
  return out
where
  /-- The indentation and length of line `l` (hanging indentation or `\parshape`). -/
  lineShape (p : Params) (l : Nat) : Int × Int :=
    if !p.parShape.isEmpty then
      (p.parShape[l - 1]?.getD ((p.parShape.back?).getD (0, p.hsize)))
    else if p.hangIndent == 0 then (0, p.hsize)
    else
      let special := if p.hangAfter < 0 then l ≤ p.hangAfter.natAbs else l > p.hangAfter.natAbs
      if !special then (0, p.hsize)
      else (if p.hangIndent ≥ 0 then p.hangIndent else 0, p.hsize - p.hangIndent.natAbs)

end LeAnTeX.Text
