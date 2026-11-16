/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Text.Node

/-!
# Breaking a paragraph into lines

TeX's line breaker: the total-fit algorithm of Knuth and Plass, as TeX runs it, on a horizontal
list in scaled points. Given the paragraph's list (ending with `\penalty10000` and
`\parfillskip`, as TeX's is) and the parameters, it chooses the breaks with the fewest total
demerits by TeX's rules: for every paragraph of the recorded corpus the same breaks and the
same demerits as LuaLaTeX's, with TeX's order of preference when two choices tie.

## What TeX does, and what this module does

* **Legal breakpoints.** Glue after a non-discardable node (a glyph, a box, a rule, a
  discretionary, a font kern); an explicit kern or italic correction followed by glue; a
  penalty below 10000; a discretionary; the end of the paragraph.
* **Badness** of a line from its shortfall and its stretch or shrink (TeX's `badness`, an
  approximation of 100 (t/s)³ in integers); a line with infinite stretch has badness 0.
* **Fitness classes**: very loose (badness above 99 when stretched), loose (above 12), decent,
  tight (above 12 when shrunk).
* **Demerits**: `(\linepenalty + b)²` (10⁸ when that sum reaches 10000), plus the square of a
  positive penalty, minus the square of a negative one above -10000, plus
  `\doublehyphendemerits` for two hyphenated lines in a row, `\finalhyphendemerits` when the
  second-last line ends hyphenated, `\adjdemerits` between lines whose fitness classes are not
  adjacent.
* **Passes.** A first pass with `\pretolerance` that does not break at the hyphenation points
  the patterns found (skipped when `\pretolerance` is negative), a second with `\tolerance`, and
  when `\emergencystretch` is positive a third with that much more stretch on every line; on
  the last pass a line that no break can make feasible is accepted with an overfull or
  underfull line, as TeX does.
* **Looseness**: among the feasible solutions, the one whose line count is closest to the
  optimum plus `\looseness`.
* **Line lengths**: `\hsize`, `\hangindent` with `\hangafter`, and `\parshape`; `\leftskip`
  and `\rightskip` on every line.
* **Discretionaries**: a break ends the line with the `pre` text and starts the next with the
  `post` text; when `post` is empty, discardable nodes after the discretionary are dropped as
  after any break.

Not done here: `\lastlinefit` (TeX's ε-TeX extension, 0 in LaTeX), margin kerning and font
expansion (pdfTeX's and LuaTeX's extensions, off in LaTeX), insertions, marks and adjust
material (a document layer's concern), and math nodes (a formula is an unbreakable box, see
`HNode.math`).

## Main definitions

* `Params`: the parameters, with LaTeX's defaults.
* `breakParagraph`: the breaks, the demerits and the pass that found them, checked
  (`checkBreaks`) before they are returned.
* `legalBreak`: whether an index of a list is a legal breakpoint.

## Implementation notes

TeX keeps the active breakpoints in a list with *delta nodes* between them holding differences
of widths. Here each active breakpoint stores the totals (width, stretch of each order, shrink)
of the material before the place where its line starts, and a line's totals are the difference
of two prefix sums: the same integers, so the same badness. The active list is an array in TeX's
order, and new breakpoints are inserted where TeX inserts them, so ties are resolved as in TeX.

Work is bounded: the input may have at most `Params.maxNodes` nodes, the active list at most
`Params.maxActive` breakpoints, and all passes together at most `Params.maxWork` steps (a visit
of an active breakpoint, or an insertion or removal counted at the length of the list); beyond
any of them `breakParagraph` returns an error naming the limit. So the work of a paragraph is
at most `maxWork` plus a constant times its number of nodes, whatever its parameters: without
the step budget a paragraph with `\tolerance=10000` and a wide `\hsize` keeps thousands of
breakpoints active and its work grows with their product.

## References

* Donald E. Knuth and Michael F. Plass, "Breaking paragraphs into lines", *Software—Practice and
  Experience* 11 (1981), 1119–1184.
* Donald E. Knuth, *TeX: The Program* (`tex.web`), parts 38 and 39, and *The TeXbook*,
  chapter 14: the specification this module follows (written from the published description;
  no program text copied).
-/

namespace LeAnTeX.Text

/-- The parameters of the line breaker, with LaTeX's defaults at `\hsize` 345 pt. -/
structure Params where
  /-- `\hsize`. -/
  hsize : Int := 345 * 65536
  /-- `\pretolerance`; negative skips the first pass. -/
  pretolerance : Int := 100
  /-- `\tolerance`. -/
  tolerance : Int := 200
  /-- `\looseness`. -/
  looseness : Int := 0
  /-- `\linepenalty`. -/
  linePenalty : Int := 10
  /-- `\adjdemerits`. -/
  adjDemerits : Int := 10000
  /-- `\doublehyphendemerits`. -/
  doubleHyphenDemerits : Int := 10000
  /-- `\finalhyphendemerits`. -/
  finalHyphenDemerits : Int := 5000
  /-- `\emergencystretch`. -/
  emergencyStretch : Int := 0
  /-- `\leftskip`. -/
  leftSkip : Glue := {}
  /-- `\rightskip`. -/
  rightSkip : Glue := {}
  /-- `\hangindent`. -/
  hangIndent : Int := 0
  /-- `\hangafter`. -/
  hangAfter : Int := 1
  /-- `\parshape`: an indentation and a length per line, the last repeated; empty for none. -/
  parShape : Array (Int × Int) := #[]
  /-- `\prevgraf` before the paragraph (lines of an earlier part of it). -/
  prevGraf : Nat := 0
  /-- The most nodes accepted. -/
  maxNodes : Nat := 1000000
  /-- The most active breakpoints at any time. -/
  maxActive : Nat := 20000
  /-- The most steps all passes together may take: a step is a visit of an active breakpoint at
  a legal breakpoint, and inserting or removing an active breakpoint counts as many steps as the
  active list is long. -/
  maxWork : Nat := 20000000
  deriving Inhabited, Repr

/-- Why a paragraph could not be broken. -/
inductive BreakError where
  /-- More nodes than `Params.maxNodes`. -/
  | tooManyNodes (n : Nat)
  /-- More active breakpoints than `Params.maxActive`. -/
  | tooManyActive
  /-- More steps than `Params.maxWork`. -/
  | tooMuchWork (limit : Nat)
  /-- A discretionary's text holds a node other than a glyph, kern, box or rule. -/
  | improperDiscretionary (index : Nat)
  /-- A glue order above 3, or a `\parshape` entry with a negative length. -/
  | badParameter (what : String)
  deriving BEq, Inhabited, Repr

/-- The message of a `BreakError`. -/
def BreakError.message : BreakError → String
  | .tooManyNodes n => s!"paragraph too long: {n} nodes"
  | .tooManyActive => "too many active breakpoints"
  | .tooMuchWork n => s!"paragraph too costly to break: more than {n} steps"
  | .improperDiscretionary i => s!"improper discretionary list at node {i}"
  | .badParameter w => s!"bad parameter: {w}"

/-- How a line ends. -/
structure Break where
  /-- The node the line breaks at; the list's size for the end of the paragraph. -/
  pos : Nat
  /-- The line's fitness class: 0 very loose, 1 loose, 2 decent, 3 tight. -/
  fitness : Nat
  /-- Whether the break is at a discretionary (or the end of the paragraph). -/
  hyphenated : Bool
  deriving BEq, Inhabited, Repr

/-- The breaks TeX chooses. -/
structure Breaks where
  /-- The breaks, one per line, in order; the last at the end of the paragraph. -/
  breaks : Array Break
  /-- The total demerits of the chosen breaks. -/
  demerits : Int
  /-- The pass that found them: 1, 2, or 3 (with `\emergencystretch`). -/
  pass : Nat
  /-- Notes for the user: glue with infinite shrink made finite, as TeX does. -/
  warnings : Array String
  /-- The steps all passes took (see `Params.maxWork`). -/
  work : Nat := 0
  deriving Inhabited

/-- TeX's `inf_bad`. -/
def infBad : Int := 10000

/-- TeX's `awful_bad`. -/
def awfulBad : Int := 0x3FFFFFFF

/-- TeX's badness of a line with shortfall or excess `t` against stretch or shrink `s`: about
`100 (t/s)³`, at most 10000, in TeX's integer approximation. -/
def badness (t s : Int) : Int :=
  if t == 0 then 0
  else if s ≤ 0 then infBad
  else
    let r := if t ≤ 7230584 then (t * 297) / s
      else if s ≥ 1663497 then t / (s / 297) else t
    if r > 1290 then infBad else (r * r * r + 0x20000) / 0x40000

/-- The totals of a stretch of material: width, stretch of each order, finite shrink. -/
structure Totals where
  /-- The natural width. -/
  w : Int := 0
  /-- Finite stretch. -/
  s0 : Int := 0
  /-- `fil` stretch. -/
  s1 : Int := 0
  /-- `fill` stretch. -/
  s2 : Int := 0
  /-- `filll` stretch. -/
  s3 : Int := 0
  /-- Shrink. -/
  sh : Int := 0
  deriving BEq, Inhabited, Repr

instance : Add Totals :=
  ⟨fun a b => ⟨a.w + b.w, a.s0 + b.s0, a.s1 + b.s1, a.s2 + b.s2, a.s3 + b.s3, a.sh + b.sh⟩⟩
instance : Sub Totals :=
  ⟨fun a b => ⟨a.w - b.w, a.s0 - b.s0, a.s1 - b.s1, a.s2 - b.s2, a.s3 - b.s3, a.sh - b.sh⟩⟩

/-- The totals of one glue. -/
def Totals.ofGlue (g : Glue) : Totals :=
  let s := g.stretch
  { w := g.width, sh := g.shrink
    s0 := if g.stretchOrder == 0 then s else 0, s1 := if g.stretchOrder == 1 then s else 0
    s2 := if g.stretchOrder == 2 then s else 0, s3 := if g.stretchOrder == 3 then s else 0 }

/-- The totals of one node outside a discretionary's text (widths only, but glue's stretch and
shrink). -/
def Totals.ofNode : HNode → Totals
  | .glue g _ => Totals.ofGlue g
  | n => { w := n.width }

/-- The glue with its shrink made finite, if its shrink is infinite (TeX's `finite_shrink`). -/
def Glue.finiteShrink (g : Glue) : Glue :=
  if g.shrinkOrder != 0 && g.shrink != 0 then { g with shrinkOrder := 0 } else g

/-- Whether node `i` of `items` is a legal breakpoint, given whether the node before it is one
that a glue may follow with a break (`prevBreakable`): TeX's rules, the hyphenation points of
the patterns only when `hyphenate`. The end of the list (`i = items.size`) is legal. -/
def legalAt (items : Array HNode) (i : Nat) (prevBreakable hyphenate : Bool) : Bool :=
  match items[i]? with
  | none => i == items.size
  | some (.glue ..) => prevBreakable
  | some (.kern _ k) => (k == .explicit || k == .italic) &&
      match items[i + 1]? with | some (.glue ..) => true | _ => false
  | some (.penalty p) => p < 10000
  | some (.disc _ _ _ _ k) => hyphenate || k != .syllable
  | _ => false

/-- Whether glue after this node is a legal breakpoint: after a glyph, box, rule, formula,
discretionary or font kern. -/
def precedesBreak : HNode → Bool
  | .glyph .. | .box .. | .rule .. | .math .. | .disc .. => true
  | .kern _ k => !(k == .explicit || k == .italic)
  | _ => false

/-- Whether node `i` of `items` is a legal breakpoint in the second pass (all hyphenation points
allowed). -/
def legalBreak (items : Array HNode) (i : Nat) : Bool :=
  legalAt items i (i > 0 && (items[i - 1]?.map precedesBreak).getD false) true

/-- The first index at or after `j` that holds a node not dropped at the start of a line, or the
list's size. -/
def firstKept (items : Array HNode) (j : Nat) : Nat := Id.run do
  let mut k := j
  for _ in [j:items.size] do
    match items[k]? with
    | some n => if n.discardable then k := k + 1 else break
    | none => break
  return k

namespace LineBreak

/-- An active breakpoint: the line number of the line that starts after it, its fitness class
and kind, its total demerits, its passive record, and the totals of the material before its
line's start. -/
structure Active where
  /-- The number of the line starting here. -/
  line : Nat
  /-- The fitness class of the line ending here. -/
  fitness : Nat
  /-- Whether this is a discretionary break. -/
  hyphenated : Bool
  /-- The total demerits of the best way here. -/
  total : Int
  /-- The passive record of the break, `none` for the start of the paragraph. -/
  passive : Option Nat
  /-- The totals before the line's start. -/
  start : Totals
  deriving Inhabited

/-- A break that some active breakpoint goes through: its node and the break before it. -/
structure Passive where
  /-- The node. -/
  pos : Nat
  /-- The line's fitness class. -/
  fitness : Nat
  /-- Whether it is a discretionary break. -/
  hyphenated : Bool
  /-- The break before, `none` for the start of the paragraph. -/
  prev : Option Nat
  deriving Inhabited

/-- The state of a pass. -/
structure State where
  /-- The active breakpoints, in TeX's order. -/
  act : Array Active
  /-- Every break recorded. -/
  passive : Array Passive := #[]
  /-- Per fitness class, the fewest demerits of a feasible break at the current node. -/
  minimal : Array Int := #[awfulBad, awfulBad, awfulBad, awfulBad]
  /-- Per fitness class, the passive record of that break's predecessor. -/
  bestPlace : Array (Option Nat) := #[none, none, none, none]
  /-- Per fitness class, the line number of the line ending there. -/
  bestPlLine : Array Nat := #[0, 0, 0, 0]
  /-- The least of `minimal`. -/
  minimum : Int := awfulBad
  /-- Whether the active list outgrew its cap. -/
  overflow : Bool := false
  /-- The steps taken so far (see `Params.maxWork`). -/
  work : Nat := 0
  deriving Inhabited

/-- What a pass knows besides its state. -/
structure Pass where
  /-- The parameters. -/
  p : Params
  /-- `\leftskip` and `\rightskip`, with the emergency stretch on the third pass. -/
  background : Totals
  /-- The badness above which a line is infeasible. -/
  threshold : Int
  /-- Whether this is the last pass. -/
  final : Bool
  /-- The last line whose length is special (hanging indentation or `\parshape`). -/
  lastSpecial : Nat
  /-- The last line whose length matters to which breaks are equivalent (TeX's `easy_line`). -/
  easyLine : Nat
  /-- The length of the lines after `lastSpecial`. -/
  secondWidth : Int
  /-- The length of the lines up to `lastSpecial` without `\parshape`. -/
  firstWidth : Int

/-- The length of line `l` (TeX's line width computation). -/
def Pass.lineWidth (ps : Pass) (l : Nat) : Int :=
  if l > ps.lastSpecial then ps.secondWidth
  else if ps.p.parShape.isEmpty then ps.firstWidth
  else ((ps.p.parShape[l - 1]?).map (·.2)).getD ps.secondWidth

/-- The demerits of a line of badness `b` ending at a break of penalty `pi` (TeX's formula,
without the two hyphen terms and the fitness term). -/
def lineDemerits (linePenalty b pi : Int) : Int :=
  let d := linePenalty + b
  let d := if d.natAbs ≥ 10000 then 100000000 else d * d
  if pi > 0 then d + pi * pi else if pi > -10000 && pi != 0 then d - pi * pi else d

/-- The badness and fitness class of a line with these totals against length `width`
(TeX's computation, `inf_bad + 1` for a line that cannot shrink enough). -/
def fit (t : Totals) (width : Int) : Int × Nat :=
  let shortfall := width - t.w
  if shortfall > 0 then
    if t.s1 != 0 || t.s2 != 0 || t.s3 != 0 then (0, 2)
    else if shortfall > 7230584 && t.s0 < 1663497 then (infBad, 0)
    else
      let b := badness shortfall t.s0
      (b, if b > 12 then (if b > 99 then 0 else 1) else 2)
  else
    let b := if -shortfall > t.sh then infBad + 1 else badness (-shortfall) t.sh
    (b, if b > 12 then 3 else 2)

/-- Inserts the new active breakpoints for the best feasible breaks found at node `pos` before
position `j` of the active list; returns the state and the position after them. -/
def createActive (ps : Pass) (s : State) (j pos : Nat) (hyph : Bool) (start : Totals) :
    State × Nat := Id.run do
  let mut s := s
  let mut j := j
  let adj := ps.p.adjDemerits.natAbs
  s := { s with minimum := if (adj : Int) ≥ awfulBad - s.minimum then awfulBad - 1
    else s.minimum + adj }
  for fc in [0:4] do
    let m := s.minimal[fc]?.getD awfulBad
    if m ≤ s.minimum then
      if s.act.size ≥ ps.p.maxActive then
        s := { s with overflow := true }
      else
        let q := s.passive.size
        let pv : Passive :=
          { pos, fitness := fc, hyphenated := hyph, prev := s.bestPlace[fc]?.getD none }
        s := { s with passive := s.passive.push pv }
        let a : Active :=
          { line := s.bestPlLine[fc]?.getD 0 + 1, fitness := fc, hyphenated := hyph,
            total := m, passive := some q, start }
        s := { s with act := s.act.insertIdxIfInBounds j a, work := s.work + s.act.size }
        j := j + 1
    s := { s with minimal := s.minimal.setIfInBounds fc awfulBad }
  return ({ s with minimum := awfulBad }, j)

/-- TeX's `try_break` at node `pos` with penalty `pi`: `cur` are the totals of the material up
to the break (a discretionary's `pre` text included), `start` the totals before the start of a
line after it. -/
def tryBreak (ps : Pass) (s : State) (pi : Int) (hyph : Bool) (pos : Nat) (atEnd : Bool)
    (cur start : Totals) : State := Id.run do
  if pi.natAbs ≥ 10000 && pi > 0 then return s
  let pi := if pi ≤ -10000 then -10000 else pi
  let mut s := s
  let mut j := 0
  let mut oldL := 0
  let mut lineWidth : Int := 0
  let fuel := 8 * (s.act.size + 2)
  for _ in [0:fuel] do
    s := { s with work := s.work + 1 }
    let atLast := j ≥ s.act.size
    let l := (s.act[j]?.map (·.line)).getD 0
    if atLast || l > oldL then
      if s.minimum < awfulBad && (oldL != ps.easyLine || atLast) then
        let (s', j') := createActive ps s j pos hyph start
        s := s'; j := j'
      if j ≥ s.act.size then break
      if l > ps.easyLine then
        lineWidth := ps.secondWidth; oldL := 0x3FFFFFFE
      else
        oldL := l; lineWidth := ps.lineWidth l
    let some r := s.act[j]? | break
    let t := cur - r.start + ps.background
    let (b, fc) := fit t lineWidth
    let mut artificial := false
    let mut stays := true
    let mut consider := true
    if b > infBad || pi == -10000 then
      if ps.final && s.minimum == awfulBad && s.act.size == 1 && j == 0 then
        artificial := true
      else if b > ps.threshold then consider := false
      stays := false
    else if b > ps.threshold then consider := false
    if consider then
      let d := if artificial then 0 else
        let d := lineDemerits ps.p.linePenalty b pi
        let d := if hyph && r.hyphenated then
          d + (if atEnd then ps.p.finalHyphenDemerits else ps.p.doubleHyphenDemerits) else d
        if (fc : Int) - r.fitness > 1 || (r.fitness : Int) - fc > 1 then
          d + ps.p.adjDemerits else d
      let d := d + r.total
      if d ≤ s.minimal[fc]?.getD awfulBad then
        s := { s with
          minimal := s.minimal.setIfInBounds fc d
          bestPlace := s.bestPlace.setIfInBounds fc r.passive
          bestPlLine := s.bestPlLine.setIfInBounds fc l
          minimum := min s.minimum d }
    if stays then j := j + 1
    else s := { s with act := s.act.eraseIdxIfInBounds j, work := s.work + s.act.size }
  return s

/-- The outcome of one pass: the steps taken so far (starting from `work`, the steps of the
earlier passes), and the active list after the final break if the pass reached the end of the
paragraph with breakpoints left. -/
def runPass (ps : Pass) (items : Array HNode) (prefixes : Array Totals) (hyphenate : Bool)
    (work : Nat := 0) : Except BreakError (Nat × Option State) := Id.run do
  let n := items.size
  let pre := fun (i : Nat) => prefixes[i]?.getD default
  let initial : Active :=
    { line := ps.p.prevGraf + 1, fitness := 2, hyphenated := false, total := 0,
      passive := none, start := {} }
  let mut s : State := { act := #[initial], work }
  let mut prevBreakable := false
  for i in [0:n] do
    if s.act.isEmpty then break
    let node := items[i]?.getD default
    if legalAt items i prevBreakable hyphenate then
      match node with
      | .disc pen pr po _ _ =>
        let cur := pre i + { w := listWidth pr }
        let start := if po.isEmpty then pre (firstKept items (i + 1))
          else pre (i + 1) - { w := listWidth po }
        s := tryBreak ps s pen true i false cur start
      | _ =>
        let pen := match node with | .penalty p => p | _ => 0
        s := tryBreak ps s pen false i false (pre i) (pre (firstKept items i))
      if s.overflow then return .error .tooManyActive
      if s.work > ps.p.maxWork then return .error (.tooMuchWork ps.p.maxWork)
    prevBreakable := precedesBreak node
  if s.act.isEmpty then return .ok (s.work, none)
  s := tryBreak ps s (-10000) true n true (pre n) (pre n)
  if s.overflow then return .error .tooManyActive
  if s.work > ps.p.maxWork then return .error (.tooMuchWork ps.p.maxWork)
  return .ok (s.work, if s.act.isEmpty then none else some s)

/-- The breaks of an active breakpoint, from the start of the paragraph. -/
def chain (s : State) (a : Active) : Array Break := Id.run do
  let mut out := #[]
  let mut q := a.passive
  for _ in [0:s.passive.size + 1] do
    match q with
    | none => break
    | some k =>
      let some pv := s.passive[k]? | break
      out := out.push { pos := pv.pos, fitness := pv.fitness, hyphenated := pv.hyphenated }
      q := pv.prev
  return out.reverse

/-- The chosen breakpoint: fewest demerits (the first of equals), then the one whose line count
best meets `\looseness`; and whether the looseness asked for was met. -/
def best (looseness : Int) (act : Array Active) : Active × Bool := Id.run do
  let mut bestA := act[0]?.getD default
  let mut fewest := awfulBad
  for a in act do
    if a.total < fewest then fewest := a.total; bestA := a
  if looseness == 0 then return (bestA, true)
  let bestLine : Int := bestA.line
  let mut actual : Int := 0
  for a in act do
    let diff := (a.line : Int) - bestLine
    if (diff < actual && looseness ≤ diff) || (diff > actual && looseness ≥ diff) then
      bestA := a; actual := diff; fewest := a.total
    else if diff == actual && a.total < fewest then
      bestA := a; fewest := a.total
  return (bestA, actual == looseness)

end LineBreak

/-- Whether a list of numbers is strictly increasing. -/
def increasing : List Nat → Bool
  | a :: b :: t => a < b && increasing (b :: t)
  | _ => true

/-- The checks `breakParagraph` makes of its result before returning it: every break a legal
breakpoint of `items` or the end, the breaks increasing, the last at the end. -/
def checkBreaks (items : Array HNode) (r : Breaks) : Except BreakError Breaks :=
  if r.breaks.all (fun b => b.pos == items.size || legalBreak items b.pos) &&
      increasing (r.breaks.toList.map (·.pos)) && (r.breaks.back?.map (·.pos)) == some items.size
  then .ok r
  else .error (.badParameter "internal: the breaks found are not a breaking of the list")

open LineBreak in
/-- The line breaker before its result is checked (`breakParagraph`). -/
def breakParagraphCore (items : Array HNode) (p : Params := {}) : Except BreakError Breaks := do
  if items.size > p.maxNodes then throw (.tooManyNodes items.size)
  let mut warnings := #[]
  let mut nodes := #[]
  for h : i in [0:items.size] do
    let n := items[i]
    match n with
    | .disc _ pr po rp _ =>
      if !(pr.all (·.allowedInDisc) && po.all (·.allowedInDisc) && rp.all (·.allowedInDisc))
      then throw (.improperDiscretionary i)
      nodes := nodes.push n
    | .glue g st =>
      if g.stretchOrder > 3 || g.shrinkOrder > 3 then throw (.badParameter "glue order")
      if g.finiteShrink != g then
        warnings := warnings.push s!"infinite glue shrinkage found in a paragraph (node {i})"
      nodes := nodes.push (.glue g.finiteShrink st)
    | _ => nodes := nodes.push n
  if p.parShape.any (·.2 < 0) then throw (.badParameter "parshape")
  let mut prefixes : Array Totals := Array.mkEmpty (nodes.size + 1)
  let mut acc : Totals := {}
  prefixes := prefixes.push acc
  for n in nodes do
    acc := acc + Totals.ofNode n
    prefixes := prefixes.push acc
  let bg := Totals.ofGlue p.leftSkip.finiteShrink + Totals.ofGlue p.rightSkip.finiteShrink
  let (lastSpecial, firstWidth, secondWidth) :=
    if !p.parShape.isEmpty then
      (p.parShape.size - 1, p.hsize, ((p.parShape.back?.map (·.2)).getD p.hsize))
    else if p.hangIndent == 0 then (0, p.hsize, p.hsize)
    else if p.hangAfter < 0 then (p.hangAfter.natAbs, p.hsize - p.hangIndent.natAbs, p.hsize)
    else (p.hangAfter.natAbs, p.hsize, p.hsize - p.hangIndent.natAbs)
  let easyLine := if p.looseness == 0 then lastSpecial else 0x3FFFFFFF
  let mk := fun (bgr : Totals) (th : Int) (final : Bool) => (
    { p, background := bgr, threshold := min th infBad, final, lastSpecial, easyLine,
      secondWidth, firstWidth } : Pass)
  -- the passes TeX would run, in order: (pass number, pass, hyphenation points allowed)
  let second := mk bg p.tolerance (p.emergencyStretch ≤ 0)
  let third := mk (bg + { s0 := p.emergencyStretch }) p.tolerance true
  let passes := (if p.pretolerance ≥ 0 then #[(1, mk bg p.pretolerance false, false)] else #[])
    ++ #[(2, second, true)] ++ (if p.emergencyStretch > 0 then #[(3, third, true)] else #[])
  let mut result : Option Breaks := none
  let mut work := 0
  for (num, ps, hyphenate) in passes do
    let (w, r) ← runPass ps nodes prefixes hyphenate work
    work := w
    match r with
    | none => pure ()
    | some s =>
      let (a, met) := best p.looseness s.act
      if met || ps.final then
        result := some { breaks := chain s a, demerits := a.total, pass := num, warnings, work }
        break
  match result with
  | some r => return r
  | none => throw (.badParameter "internal: no pass reached the end")

/-- Breaks a paragraph into lines as TeX does (see the module docstring). `items` is the
paragraph's horizontal list, normally ending with `\penalty10000` and `\parfillskip`. The
result's breaks are legal breakpoints of `items` (`legalBreak`) or the end, in increasing order,
the last at the end (`checkBreaks`, proved in `LeAnTeX.Text.Proofs`); an error for an input
beyond the caps or a malformed discretionary. -/
def breakParagraph (items : Array HNode) (p : Params := {}) : Except BreakError Breaks :=
  (breakParagraphCore items p).bind (checkBreaks items)

end LeAnTeX.Text
