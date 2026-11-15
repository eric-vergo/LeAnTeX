/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Doc.VList

/-!
# The page builder

TeX's page builder (`tex.web` part 45, followed from the published description of the
algorithm, *TeX: The Program* §980–§1028): items move from the contributions to the current
page one at a time; at every legal breakpoint the cost of breaking there is computed from the
page's badness, the penalty and the insertions' penalties, and the best break so far is kept;
when the page is full (the cost is infinite) or a penalty forces a break, the page is cut at
the best break and handed to the output, and what follows goes back to the contributions.

* **Breakpoints**: glue after a non-discardable item, a kern followed by glue, a penalty
  below 10000. At the top of a page glue, kerns and penalties are discarded; before the
  first box TeX's `\topskip` glue is inserted (its width less the box's height, at least 0).
* **Cost**: the badness of stretching (or shrinking) the page to `\vsize`; a penalty of
  -10000 or less forces the break with that cost; a badness of 10000 or more (but finite)
  costs 100000 (TeX's `deplorable`); a page that would have to shrink beyond its shrink costs
  TeX's `awful_bad`, and the page is cut at the best break found.
* **Depth**: a box's depth beyond `\maxdepth` is moved into the page's height.
* **Insertions** (`VNode.ins`): the first of a class on a page takes its `\skip` from the
  goal; each takes its height (scaled by `\count`) when it fits under the goal and under
  `\dimen`; otherwise it is split (TeX's `vert_break` at the height that is left) and the rest
  goes to the next page, and later insertions of that class wait for the next page.
* **Labels** (`VNode.label`) and marks are kept on the page where they fall.
* **Floats** (`VNode.float`) are handed to the caller's `onFloat`, which may change the page's
  goal (top and bottom floats take room), give items to contribute in the float's place (a
  float set here) or defer it; this is how LaTeX's output routine sees a float.

Every length is an integer of sp, so the arithmetic is TeX's exactly. The work is bounded: each
step either moves an item from the contributions to the page or discards it, or cuts a page
(which moves at least one item into it, or ends when nothing is left), and the number of steps
is capped by `maxSteps`.

## Main definitions

* `PageParams`, `InsertClass`: `\vsize`, `\maxdepth`, `\topskip` and an insertion class's
  `\skip`, `\count` and `\dimen`.
* `vertBreak`: TeX's `vert_break`.
* `PageOut`: a page as the builder hands it to the output (TeX's `\box255`, the insertions'
  boxes and the penalty broken at).
* `buildPages`: the whole contribution list into pages.
-/

namespace LeAnTeX.Doc

open LeAnTeX.Text

/-- TeX's `awful_bad`: a cost worse than any other. -/
def awfulBad : Int := 1073741823

/-- TeX's `deplorable`: the cost of a page whose badness is 10000 or more. -/
def deplorable : Int := 100000

/-- An insertion class's parameters: `\skip n` (the space above the class's material), `\count
n` (its magnification, 1000 for its natural height) and `\dimen n` (the most room it takes on
one page). -/
structure InsertClass where
  /-- `\skip n`. -/
  skip : Glue
  /-- `\count n`. -/
  count : Int := 1000
  /-- `\dimen n`. -/
  dimen : Int

/-- The page builder's parameters. -/
structure PageParams where
  /-- `\vsize`: the height of the page's text. -/
  vsize : Int
  /-- `\maxdepth`. -/
  maxDepth : Int
  /-- `\topskip`. -/
  topSkip : Glue
  /-- The insertion classes, by number. -/
  inserts : Nat → Option InsertClass := fun _ => none
  /-- The most steps the builder takes (each moves, discards or cuts). -/
  maxSteps : Nat := 10000000

/-- The badness of stretching or shrinking `t` by total `s` (TeX's `badness`, the line
breaker's). -/
def vBadness (t s : Int) : Int := LeAnTeX.Text.badness t s

/-- Whether the item before glue makes it a breakpoint (TeX's `precedes_break`: a box, a rule,
an insertion, a mark or a label). -/
def precedesBreak : Option VNode → Bool
  | some (.hbox ..) | some (.vbox ..) | some (.rule ..) | some (.ins ..) | some (.mark _)
  | some (.label _) | some (.float _) => true
  | _ => false

/-- The page so far: TeX's `page_total`, `page_depth`, `page_so_far` and `page_goal`. -/
structure Heights where
  /-- The height so far (`page_total`), the last box's depth not included. -/
  total : Int := 0
  /-- The depth of the last box. -/
  depth : Int := 0
  /-- The stretch so far, by order. -/
  stretch : Array Int := #[0, 0, 0, 0]
  /-- The shrink so far. -/
  shrink : Int := 0
  deriving Inhabited

/-- The cost of a break with penalty `pi` when the material so far has heights `hs` and the
goal is `goal`, with TeX's `insert_penalties` (TeX §974 and §1007). -/
def breakCost (hs : Heights) (goal pi : Int) (insertPenalties : Int := 0) : Int :=
  let b :=
    if hs.total < goal then
      if hs.stretch.getD 1 0 != 0 || hs.stretch.getD 2 0 != 0 || hs.stretch.getD 3 0 != 0 then 0
      else vBadness (goal - hs.total) (hs.stretch.getD 0 0)
    else if hs.total - goal > hs.shrink then awfulBad
    else vBadness (hs.total - goal) hs.shrink
  if b < awfulBad then
    if pi ≤ -10000 then pi else if b < 10000 then b + pi + insertPenalties else deplorable
  else b

/-- Adds glue or a kern to the heights (TeX's `update_heights`). Infinite shrink is taken as
finite, as TeX takes it after its error. -/
def Heights.add (hs : Heights) : VNode → Heights
  | .glue g _ =>
    { hs with stretch := hs.stretch.modify g.stretchOrder (· + g.stretch),
              shrink := hs.shrink + g.shrink, total := hs.total + hs.depth + g.width,
              depth := 0 }
  | .kern w => { hs with total := hs.total + hs.depth + w, depth := 0 }
  | _ => hs

/-- TeX's `vert_break`: the best place to break `items` for a height `h` with depths at most
`d`: the index of the break (`items.size` for the end) and the height plus depth of the
material before it. -/
def vertBreak (items : Array VNode) (h d : Int) : Nat × Int := Id.run do
  let mut hs : Heights := {}
  let mut least := awfulBad
  let mut best := items.size
  let mut bestHd : Int := 0
  for i in [0:items.size + 1] do
    let p := items[i]?
    let pi? : Option Int := match p with
      | none => some (-10000)
      | some (.glue ..) => if precedesBreak (if i == 0 then none else items[i - 1]?)
          then some 0 else none
      | some (.kern _) => match items[i + 1]? with
        | some (.glue ..) | none => some 0
        | _ => none
      | some (.penalty n) => some n
      | _ => none
    if let some pi := pi? then
      if pi < 10000 then
        let c := breakCost hs h pi
        if c ≤ least then
          best := i
          least := c
          bestHd := hs.total + hs.depth
        if c == awfulBad || pi ≤ -10000 then return (best, bestHd)
    match p with
    | some n@(.hbox ..) | some n@(.vbox ..) | some n@(.rule ..) =>
      hs := { hs with total := hs.total + hs.depth + n.height, depth := n.depth }
    | some n@(.glue ..) | some n@(.kern _) => hs := hs.add n
    | _ => pure ()
    if hs.depth > d then hs := { hs with total := hs.total + hs.depth - d, depth := d }
  return (best, bestHd)

/-- TeX's `prune_page_top`: discardable items at the top of a split-off list removed, and the
`\splittopskip` glue put before its first box (its width less the box's height, at least 0). -/
def pruneTop (items : Array VNode) (splitTop : Glue) : Array VNode := Id.run do
  let mut out := #[]
  let mut seenBox := false
  for n in items do
    if seenBox then out := out.push n
    else
      match n with
      | .hbox .. | .vbox .. | .rule .. =>
        let w := if splitTop.width > n.height then splitTop.width - n.height else 0
        out := out.push (.glue { splitTop with width := w } 11) |>.push n
        seenBox := true
      | .glue .. | .kern _ | .penalty _ => pure ()
      | n => out := out.push n
  return out

/-- The natural height plus depth of an insertion's material (TeX's `height(ins)`). -/
def insHeight (content : Array VNode) : Int :=
  let m := vmeasure content
  m.height + m.depth

/-- A page as the builder hands it to the output: the items up to the break (TeX's `\box255`
before it is packed), the size it is packed to, the insertions' material by class, and the
penalty at the break (`\outputpenalty`, 10000 when the break was not at a penalty). -/
structure PageOut where
  /-- The page's items. -/
  items : Array VNode
  /-- The height the page is packed to (TeX's `best_size`). -/
  size : Int
  /-- The material of each insertion class on the page. -/
  inserts : Array (Nat × Array VNode) := #[]
  /-- `\outputpenalty`. -/
  penalty : Int := 10000
  deriving Inhabited

/-- What a float handler answers for a float met on the page: items to contribute in its place
(a float set here; they are put at the front of the contributions), and the new page goal (a
float at the top or bottom of the page takes its room). -/
structure FloatAnswer where
  /-- Items to contribute in the float's place. -/
  here : Array VNode := #[]
  /-- The page goal after the float. -/
  goal : Int

/-- An insertion class's record on the current page (TeX's `page_ins` records): the class, the
height its material takes so far, whether it was split, the index in the page of the last
insertion that fits, the best one at the best break, and for a split one where its material
is cut. -/
structure InsRecord where
  /-- The class. -/
  cls : Nat
  /-- The height taken so far. -/
  height : Int := 0
  /-- Whether an insertion of the class was split on this page. -/
  split : Bool := false
  /-- The page index of the last insertion of the class that goes on this page. -/
  last : Option Nat := none
  /-- `last` at the best break so far. -/
  best : Option Nat := none
  /-- For a split insertion: its page index and the index in its material where it is cut. -/
  broken : Option (Nat × Nat) := none
  deriving Inhabited

/-- The state of the page builder. -/
structure Builder where
  /-- The contributions still to come, in reverse order (the next one last). -/
  contrib : Array VNode
  /-- The current page. -/
  page : Array VNode := #[]
  /-- Whether the page has a box (TeX's `page_contents = box_there`). -/
  boxThere : Bool := false
  /-- Whether the page has started (anything but discarded items: a box or an insertion). -/
  started : Bool := false
  /-- The heights so far. -/
  hs : Heights := {}
  /-- `page_goal`. -/
  goal : Int := 0
  /-- `page_max_depth`. -/
  maxDepth : Int := 0
  /-- The least cost so far and the break with it (an index in `page`), with `page_goal` then. -/
  least : Int := awfulBad
  /-- The best break so far. -/
  best : Option Nat := none
  /-- `best_size`. -/
  bestSize : Int := 0
  /-- TeX's `insert_penalties`. -/
  insertPenalties : Int := 0
  /-- The insertion records. -/
  records : Array InsRecord := #[]
  /-- The pages cut so far. -/
  pages : Array PageOut := #[]
  deriving Inhabited

namespace Builder

/-- The next contribution, if any. -/
def peek (b : Builder) : Option VNode := b.contrib.back?

/-- The contribution after the next one. -/
def peek2 (b : Builder) : Option VNode := b.contrib[b.contrib.size - 2]?

/-- Starts a page's specifications (TeX's `freeze_page_specs`). -/
def freeze (b : Builder) (p : PageParams) : Builder :=
  { b with started := true, goal := p.vsize, maxDepth := p.maxDepth, hs := {},
           least := awfulBad, best := none }

/-- Takes the next contribution onto the page, with the depth limit (TeX's `contribute`). -/
def contribute (b : Builder) (n : VNode) : Builder :=
  let hs := if b.hs.depth > b.maxDepth then
    { b.hs with total := b.hs.total + b.hs.depth - b.maxDepth, depth := b.maxDepth }
    else b.hs
  { b with page := b.page.push n, contrib := b.contrib.pop, hs }

/-- Records a legal breakpoint at the next contribution with penalty `pi`; whether the page is
to be cut there (TeX §1005). -/
def breakpoint (b : Builder) (pi : Int) : Builder × Bool := Id.run do
  if pi ≥ 10000 then return (b, false)
  let c := breakCost b.hs b.goal pi b.insertPenalties
  let c := if b.insertPenalties ≥ 10000 then awfulBad else c
  let mut b := b
  if c ≤ b.least then
    b := { b with best := some b.page.size, least := c, bestSize := b.goal,
                  records := b.records.map fun r => { r with best := r.last } }
  return (b, c == awfulBad || pi ≤ -10000)

/-- Takes an insertion onto the page (TeX §1008–§1010). -/
def insert (b : Builder) (p : PageParams) (n : VNode) : Builder := Id.run do
  let .ins cls content _ _ floatCost := n | return b.contribute n
  let some ic := p.inserts cls | return b.contribute n
  let mut b := if b.started then b else { b.freeze p with boxThere := false }
  let idx := b.page.size
  let ri ← match b.records.findIdx? (·.cls == cls) with
    | some i => pure i
    | none =>
      b := { b with records := b.records.push { cls },
                    goal := b.goal - ic.skip.width,
                    hs := { b.hs with stretch := b.hs.stretch.modify ic.skip.stretchOrder
                                        (· + ic.skip.stretch),
                                      shrink := b.hs.shrink + ic.skip.shrink } }
      pure (b.records.size - 1)
  let r := b.records.getD ri { cls }
  let h := insHeight content
  if r.split then
    b := { b with insertPenalties := b.insertPenalties + floatCost }
  else
    let delta := b.goal - b.hs.total - b.hs.depth + b.hs.shrink
    let hScaled := if ic.count == 1000 then h else h / 1000 * ic.count
    if (hScaled ≤ 0 || hScaled ≤ delta) && h + r.height ≤ ic.dimen then
      b := { b with goal := b.goal - hScaled,
                    records := b.records.modify ri fun r =>
                      { r with height := r.height + h, last := idx } }
    else
      -- split it (TeX §1010): the room left, in the class's own units
      let w0 := if ic.count ≤ 0 then awfulBad else b.goal - b.hs.total - b.hs.depth
      let w0 := if ic.count != 1000 && ic.count > 0 then w0 / ic.count * 1000 else w0
      let w := if w0 > ic.dimen - r.height then ic.dimen - r.height else w0
      let maxD := match n with | .ins _ _ _ md _ => md | _ => 0
      let (q, hd) := vertBreak content w maxD
      let hd' := if ic.count != 1000 then hd / 1000 * ic.count else hd
      let pen := match content[q]? with
        | none => -10000
        | some (.penalty k) => k
        | _ => 0
      b := { b with goal := b.goal - hd',
                    insertPenalties := b.insertPenalties + pen,
                    records := b.records.modify ri fun r =>
                      { r with height := r.height + hd, split := true, last := idx,
                               broken := some (idx, q) } }
  return b.contribute n

end Builder

/-- Cuts the page at the best break (TeX's `fire_up`): the page's items before it, the
insertions that go on the page (split ones cut, the rest of them and later ones of their
class kept for the next page), and the contributions after it: the held insertions, then the
break and everything after it. -/
def Builder.fire (b : Builder) (p : PageParams) : Builder := Id.run do
  let cut := b.best.getD b.page.size
  let before := b.page.extract 0 cut
  -- the break and what follows it go back to the contributions; the break is then the next
  -- contribution, and a penalty broken at becomes 10000 (TeX keeps the node, now inert)
  let mut contrib := b.contrib ++ (b.page.extract cut b.page.size).reverse
  let mut penalty := 10000
  if let some (VNode.penalty k) := contrib.back? then
    penalty := k
    contrib := contrib.pop.push (.penalty 10000)
  let mut items := #[]
  let mut held := #[]
  let mut ins : Array (Nat × Array VNode) := #[]
  for h : i in [0:before.size] do
    let n := before[i]
    match n with
    | .ins cls content st md fc =>
      match b.records.find? (·.cls == cls) with
      | some r =>
        match r.best with
        | some bi =>
          if i < bi then ins := ins.push (cls, content)
          else if i == bi then
            match r.broken with
            | some (j, q) =>
              if j == i then
                ins := ins.push (cls, content.extract 0 q)
                let rest := pruneTop (content.extract q content.size) st
                if !rest.isEmpty then held := held.push (.ins cls rest st md fc)
              else ins := ins.push (cls, content)
            | none => ins := ins.push (cls, content)
          else held := held.push n
        | none => held := held.push n
      | none => held := held.push n
    | n => items := items.push n
  -- the material of each class, in order
  let classes := ins.foldl (init := #[]) fun acc (c, _) =>
    if acc.contains c then acc else acc.push c
  let merged := classes.map fun c =>
    (c, ins.foldl (init := #[]) fun acc (c', m) => if c' == c then acc ++ m else acc)
  let page : PageOut := { items, size := b.bestSize, inserts := merged, penalty }
  let _ := p
  return { contrib := contrib ++ held.reverse, pages := b.pages.push page }

/-- One step of the page builder on the next contribution (TeX's `build_page` loop body);
`onFloat` answers for floats. `none` when there is nothing left. -/
def Builder.step (b : Builder) (p : PageParams)
    (onFloat : Builder → Nat → Builder × FloatAnswer) : Option Builder := do
  let n ← b.peek
  match n with
  | .hbox .. | .vbox .. | .rule .. =>
    if !b.boxThere then
      let b := if b.started then b else b.freeze p
      let w := if p.topSkip.width > n.height then p.topSkip.width - n.height else 0
      -- the \topskip glue goes before the box and is taken next (a breakpoint only after an
      -- insertion, as in TeX, whose page head counts as glue)
      let g := VNode.glue { p.topSkip with width := w } 10
      return { b with boxThere := true, contrib := b.contrib.push g }
    let b := { b with hs := { b.hs with total := b.hs.total + b.hs.depth + n.height,
                                        depth := n.depth } }
    return b.contribute n
  | .label _ | .mark _ => return b.contribute n
  | .ins .. => return b.insert p n
  | .float i =>
    let (b, ans) := onFloat b i
    let b := { b with contrib := b.contrib.pop ++ ans.here.reverse, goal := ans.goal }
    return b
  | .glue .. | .kern _ | .penalty _ =>
    if !b.boxThere then return { b with contrib := b.contrib.pop }
    let pi? : Option Int := match n with
      | .glue .. => if precedesBreak b.page.back? then some 0 else none
      | .kern _ => match b.peek2 with
        | some (.glue ..) => some 0
        | _ => none
      | .penalty k => some k
      | _ => none
    let mut b := b
    if let some pi := pi? then
      let (b', cutNow) := b.breakpoint pi
      b := b'
      if cutNow then return b.fire p
    match n with
    | .penalty _ => return b.contribute n
    | _ => return { b.contribute n with hs := b.hs.add n }

/-- Builds the pages of a contribution list (`items` in order): TeX's page builder run until
the list is used up, the last page cut at the end as `\end` cuts it (a page with material left
is cut with a forced break). The pages in order, or an error when the step cap is reached. -/
def buildPages (items : Array VNode) (p : PageParams)
    (onFloat : Builder → Nat → Builder × FloatAnswer := fun b _ => (b, { goal := b.goal })) :
    Except String (Array PageOut) := Id.run do
  let mut b : Builder := { contrib := items.reverse }
  for _ in [0:p.maxSteps] do
    match b.step p onFloat with
    | some b' => b := b'
    | none =>
      if b.page.isEmpty || !b.boxThere then return .ok b.pages
      -- the end of the document: what is left forces a page
      b := { b with contrib := #[.penalty (-10000)] }
  return .error "page builder: too many steps"

end LeAnTeX.Doc
