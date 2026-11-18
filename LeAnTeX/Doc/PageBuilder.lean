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
* **Floats** (`VNode.float`) are placed as LaTeX's output routine places them (its
  `\@addtocurcol`, `\@startcolumn`, `\@tryfcolumn` and `\@doclearpage`, see `placeFloat`).

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

/-- A float as the page builder sees it: its box (a vertical box), the placements it allows
(`h`, `t`, `b`, `p`), and its type (`figure`, `table`): floats of one type keep their order. -/
structure FloatSpec where
  /-- The box. -/
  box : VNode
  /-- `h` allowed. -/
  here : Bool := false
  /-- `t` allowed. -/
  top : Bool := true
  /-- `b` allowed. -/
  bottom : Bool := true
  /-- `p` allowed. -/
  page : Bool := true
  /-- The type. -/
  kind : String := "figure"
  /-- The penalty LaTeX's output routine leaves where the float was given (`\interlinepenalty`,
  or 10000 right after a heading, LaTeX's `\if@nobreak\nobreak`); a penalty of 10000 follows
  it. -/
  penalty : Int := 0
  /-- `\parskip` taken back after a float set here when the float began between paragraphs
  (LaTeX's `\vskip-\parskip` in `\@addtocurcol`); `none` when it began in a paragraph. -/
  unskip : Option Glue := none
  deriving Inhabited

/-- The height a float takes (its box's height and depth). -/
def FloatSpec.size (f : FloatSpec) : Int := f.box.height + f.box.depth

/-- LaTeX's float parameters (the article class's values by default; fractions in
thousandths). -/
structure FloatParams where
  /-- `\floatsep`. -/
  floatSep : Glue := { width := 12 * 65536, stretch := 2 * 65536, shrink := 2 * 65536 }
  /-- `\textfloatsep`. -/
  textFloatSep : Glue := { width := 20 * 65536, stretch := 2 * 65536, shrink := 4 * 65536 }
  /-- `\intextsep`. -/
  inTextSep : Glue := { width := 12 * 65536, stretch := 2 * 65536, shrink := 2 * 65536 }
  /-- `\@fpsep`. -/
  fpSep : Glue := { width := 8 * 65536, stretch := 2 * 65536, stretchOrder := 1 }
  /-- `topnumber`. -/
  topNumber : Nat := 2
  /-- `bottomnumber`. -/
  bottomNumber : Nat := 1
  /-- `totalnumber`. -/
  totalNumber : Nat := 3
  /-- `\topfraction`. -/
  topFraction : Int := 700
  /-- `\bottomfraction`. -/
  bottomFraction : Int := 300
  /-- `\textfraction`. -/
  textFraction : Int := 200
  /-- `\floatpagefraction`. -/
  floatPageFraction : Int := 500
  deriving Inhabited

/-- LaTeX's float bookkeeping for the current page (`\@colroom`, `\@toproom`, `\@botroom`,
`\@topnum`, `\@botnum`, `\@colnum`, `\@textfloatsheight`, `\@toplist`, `\@botlist`,
`\@deferlist`). -/
structure FloatSt where
  /-- The room for text and floats. -/
  colRoom : Int := 0
  /-- The room left for top floats. -/
  topRoom : Int := 0
  /-- The room left for bottom floats. -/
  botRoom : Int := 0
  /-- Top floats still allowed. -/
  topNum : Nat := 0
  /-- Bottom floats still allowed. -/
  botNum : Nat := 0
  /-- Floats still allowed on the page. -/
  colNum : Nat := 0
  /-- The height of the floats set here. -/
  textFloatsHeight : Int := 0
  /-- The top floats. -/
  top : Array Nat := #[]
  /-- The bottom floats. -/
  bot : Array Nat := #[]
  /-- The deferred floats, in order. -/
  deferred : Array Nat := #[]
  deriving Inhabited

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
  /-- The floats, by index. -/
  floats : Array FloatSpec := #[]
  /-- The float parameters. -/
  fp : FloatParams := {}

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
  /-- The top floats. -/
  top : Array Nat := #[]
  /-- The bottom floats. -/
  bottom : Array Nat := #[]
  /-- For a page of floats only: its floats. -/
  floatPage : Array Nat := #[]
  deriving Inhabited

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
  /-- The page's `\vsize` (the text height less the room the page's floats take). -/
  vsize : Int := 0
  /-- The floats' bookkeeping. -/
  fl : FloatSt := {}
  deriving Inhabited

namespace Builder

/-- The next contribution, if any. -/
def peek (b : Builder) : Option VNode := b.contrib.back?

/-- The contribution after the next one. -/
def peek2 (b : Builder) : Option VNode := b.contrib[b.contrib.size - 2]?

/-- Starts a page's specifications (TeX's `freeze_page_specs`). -/
def freeze (b : Builder) (p : PageParams) : Builder :=
  { b with started := true, goal := b.vsize, maxDepth := p.maxDepth, hs := {},
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

/-- A fraction in thousandths of a length (LaTeX's `\topfraction\textheight`). -/
def fracOf (k x : Int) : Int := x * k / 1000

/-- Starts a page's float bookkeeping (LaTeX's `\@startcolumn`): a page of floats is made
from the deferred floats while they fill at least `\floatpagefraction` of it (`\@tryfcolumn`);
then the deferred floats go to the top or bottom of the new page where they fit, in order, a
float waiting behind an earlier one of its type. -/
def Builder.startPage (b : Builder) (p : PageParams) (deferred : Array Nat) : Builder := Id.run do
  let fp := p.fp
  let mut b := b
  let mut deferred := deferred
  for _ in [0:deferred.size + 1] do
    let (taken, rest, total) := takeFloatPage p deferred false
    if taken.isEmpty || total < fracOf fp.floatPageFraction p.vsize then break
    b := { b with pages := b.pages.push { items := #[], size := p.vsize, floatPage := taken } }
    deferred := rest
  let mut fl : FloatSt :=
    { colRoom := p.vsize, topRoom := fracOf fp.topFraction p.vsize,
      botRoom := fracOf fp.bottomFraction p.vsize, topNum := fp.topNumber,
      botNum := fp.bottomNumber, colNum := fp.totalNumber }
  for i in deferred do
    let some f := p.floats[i]? | continue
    let req := fracOf fp.textFraction p.vsize + f.size
    let blocked := fl.deferred.any fun j => (p.floats[j]?.map FloatSpec.kind) == some f.kind
    if fl.colRoom > req && fl.colNum > 0 && !blocked then
      match topOrBottom p fl f i req with
      | some fl' => fl := fl'
      | none => fl := { fl with deferred := fl.deferred.push i }
    else fl := { fl with deferred := fl.deferred.push i }
  return { b with fl, vsize := fl.colRoom }
where
  /-- A float at the top or the bottom of the page if it may go there and fits (LaTeX's
  `\@addtotoporbot`): the new bookkeeping. -/
  topOrBottom (p : PageParams) (fl : FloatSt) (f : FloatSpec) (i : Nat) (req : Int) :
      Option FloatSt :=
    let fp := p.fp
    let tsep := if fl.top.isEmpty then fp.textFloatSep.width else fp.floatSep.width
    let bsep := if fl.bot.isEmpty then fp.textFloatSep.width else fp.floatSep.width
    if f.top && fl.topNum > 0 && f.size ≤ fl.topRoom && fl.colRoom ≥ req + tsep then
      some { fl with top := fl.top.push i, topNum := fl.topNum - 1, colNum := fl.colNum - 1,
                     topRoom := fl.topRoom - f.size - fp.floatSep.width,
                     colRoom := fl.colRoom - f.size - tsep }
    else if f.bottom && fl.botNum > 0 && f.size ≤ fl.botRoom && fl.colRoom ≥ req + bsep then
      some { fl with bot := fl.bot.push i, botNum := fl.botNum - 1, colNum := fl.colNum - 1,
                     botRoom := fl.botRoom - f.size - fp.floatSep.width,
                     colRoom := fl.colRoom - f.size - bsep }
    else none
  /-- The floats of a page of floats from the deferred ones (in order; with `force` every
  float may go, else only those that allow `p`), the ones left, and the height they fill. -/
  takeFloatPage (p : PageParams) (deferred : Array Nat) (force : Bool) :
      Array Nat × Array Nat × Int := Id.run do
    let mut taken := #[]
    let mut rest := #[]
    let mut total : Int := 0
    for i in deferred do
      let some f := p.floats[i]? | continue
      let blocked := rest.any fun j => (p.floats[j]?.map FloatSpec.kind) == some f.kind
      let add := if taken.isEmpty then f.size else f.size + p.fp.fpSep.width
      if (f.page || force) && !blocked && total + add ≤ p.vsize then
        taken := taken.push i
        total := total + add
      else rest := rest.push i
    if force && taken.isEmpty then
      if let some i := rest[0]? then return (#[i], rest.extract 1 rest.size, 0)
    return (taken, rest, total)

/-- A float met on the page (LaTeX's `\@addtocurcol`): set here (with `\intextsep` above and
below) when `h` allows it and the page has room; else at the top or bottom of the page; else
deferred. A float of a type that has deferred floats is deferred too. When the page's room
changes, the page so far goes back to the contributions to be built again with the new goal,
as LaTeX's output routine gives it back. -/
def Builder.placeFloat (b : Builder) (p : PageParams) (i : Nat) : Builder := Id.run do
  let fp := p.fp
  let b := { b with contrib := b.contrib.pop }
  let some f := p.floats[i]? | return b
  let fl := b.fl
  let textMin := fracOf fp.textFraction p.vsize + fl.textFloatsHeight
  let req := max b.hs.total textMin + f.size
  let blocked := fl.deferred.any fun j => (p.floats[j]?.map FloatSpec.kind) == some f.kind
  let restart := fun (b : Builder) (fl : FloatSt) (here : Array VNode) =>
    ({ contrib := b.contrib ++ here.reverse ++ b.page.reverse, pages := b.pages, fl,
       vsize := fl.colRoom } : Builder)
  if fl.colRoom > req && fl.colNum > 0 && !blocked then
    if f.here && fl.colRoom > req + fp.inTextSep.width then
      let fl := { fl with colNum := fl.colNum - 1,
                          textFloatsHeight := fl.textFloatsHeight + f.size +
                            2 * fp.inTextSep.width }
      let back := match f.unskip with
        | some g =>
          let neg : Glue := { g with width := -g.width, stretch := -g.stretch, shrink := -g.shrink }
          #[VNode.glue neg 0]
        | none => #[]
      let here := #[VNode.penalty f.penalty, .glue fp.inTextSep 0, .mark "@float", f.box,
        .penalty 0, .glue fp.inTextSep 0] ++ back ++ #[.penalty 10000]
      return restart b fl here
    match Builder.startPage.topOrBottom p fl f i req with
    | some fl => return restart b fl #[.penalty f.penalty, .penalty 10000]
    | none => pure ()
  return { b with fl := { fl with deferred := fl.deferred.push i },
                  contrib := b.contrib ++ #[.penalty 10000, .penalty f.penalty] }

/-- Puts out every deferred float on pages of floats (LaTeX's `\clearpage`), with the floats
already given to the top or bottom of the page when no text came to it. -/
def Builder.flushFloats (b : Builder) (p : PageParams) : Builder := Id.run do
  let mut b := b
  let mut deferred := (b.fl.top ++ b.fl.bot ++ b.fl.deferred).qsort (· < ·)
  b := { b with fl := { b.fl with top := #[], bot := #[] } }
  for _ in [0:deferred.size + 1] do
    if deferred.isEmpty then break
    let (taken, rest, _) := Builder.startPage.takeFloatPage p deferred true
    b := { b with pages := b.pages.push { items := #[], size := p.vsize, floatPage := taken } }
    deferred := rest
  return { b with fl := { b.fl with deferred := #[] } }

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
  let page : PageOut :=
    { items, size := b.bestSize, inserts := merged, penalty, top := b.fl.top,
      bottom := b.fl.bot }
  let nb : Builder := { contrib := contrib ++ held.reverse, pages := b.pages.push page }
  return nb.startPage p b.fl.deferred

/-- One step of the page builder on the next contribution (TeX's `build_page` loop body);
the builder unchanged when there is nothing left. The builder is passed on, never kept beside
the result, so that its lists are changed in place. -/
def Builder.step (b : Builder) (p : PageParams) : Builder := Id.run do
  let some n := b.peek | return b
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
  | .mark "@pagedepth" =>
    -- `\vskip -\pagedepth` (LaTeX's `\newpage`): the depth of the page's last box, as far
    -- as `\maxdepth` lets it count; nothing on a page with bottom floats (as LuaLaTeX shows:
    -- the output routine that placed them gave the page back after its last box)
    let g := VNode.glue { width := if b.boxThere && b.fl.bot.isEmpty then -b.hs.depth else 0 } 0
    return { b with contrib := b.contrib.pop.push g }
  | .mark "@clearpage" =>
    if !b.page.isEmpty then return b.contribute n
    return { b with contrib := b.contrib.pop }.flushFloats p
  | .label _ | .mark _ => return b.contribute n
  | .ins .. => return b.insert p n
  | .float i => return b.placeFloat p i
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
    | _ =>
      let hs := b.hs.add n
      return { b.contribute n with hs }

/-- The boxes of a list in order, by their sizes (width, height, depth), without the boxes of
floats set here (each follows a `@float` mark) and without the material of insertions. -/
def boxSizes (items : Array VNode) : Array (Int × Int × Int) := Id.run do
  let mut out := #[]
  let mut skip := false
  for n in items do
    match n with
    | .mark "@float" => skip := true
    | .hbox .. | .vbox .. | .rule .. =>
      if skip then skip := false else out := out.push (n.extent, n.height, n.depth)
    | _ => pure ()
  return out

/-- The boxes of every page in order (see `boxSizes`). -/
def pagesBoxSizes (pages : Array PageOut) : Array (Int × Int × Int) :=
  pages.foldl (init := #[]) fun acc p => acc ++ boxSizes p.items

/-- Whether the boxes on the pages have, in order, the sizes of the input's boxes (`boxSizes`):
the page builder cuts the list, adding only `\topskip` glue and discarding only glue, kerns and
penalties, so the boxes' sizes must come out unchanged and in order (`buildPages_boxes` states
that every result of `buildPages` passes). -/
def pagesPartition (items : Array VNode) (pages : Array PageOut) : Bool :=
  pagesBoxSizes pages == boxSizes items

/-- The page builder's loop (see `buildPages`). -/
def buildPagesCore (items : Array VNode) (p : PageParams) :
    Except String (Array PageOut) := Id.run do
  let mut b : Builder := ({ contrib := items.reverse } : Builder).startPage p #[]
  for _ in [0:p.maxSteps] do
    if b.contrib.isEmpty then
      if b.page.isEmpty || !b.boxThere then
        return .ok (if b.fl.deferred.isEmpty then b.pages else (b.flushFloats p).pages)
      -- the end of the document: what is left forces a page
      b := { b with contrib := #[.penalty (-10000)] }
    else b := b.step p
  return .error "page builder: too many steps"

/-- Builds the pages of a contribution list (`items` in order): TeX's page builder run until
the list is used up, the last page cut at the end as `\end` cuts it (a page with material left
is cut with a forced break). The pages in order, or an error when the step cap is reached.
The result is checked before it is returned: the boxes on the pages have the sizes of the
list's boxes, in order (`pagesPartition`, `buildPages_boxes`). -/
def buildPages (items : Array VNode) (p : PageParams) :
    Except String (Array PageOut) :=
  match buildPagesCore items p with
  | .ok pages =>
    if pagesPartition items pages then .ok pages
    else .error "page builder: the pages do not hold the list's boxes"
  | .error e => .error e

end LeAnTeX.Doc
