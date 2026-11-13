/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Layout.Common

/-!
# Lists of atoms

KaTeX's `buildExpression`: a list of parse nodes laid out side by side, with TeX's rules for
binary operators (TeXbook Appendix G, rules 5 and 6) and the spacing between atom classes
(rule 20, the table on page 170).

## Main definitions

* `BuildCtx`: what a construct's builder calls back into: the layout of a node in given options.
* `RealGroup`: whether a list is a group of its own, a part of one, or the whole formula.
* `buildExpressionWith`: KaTeX's `buildExpression`, given how to lay out one node.
* `getTypeOfDomTree`, `makeNullDelimiter`: helpers several builders share.

## Implementation notes

KaTeX inserts the spaces by walking the laid-out boxes with a callback that mutates classes and
splices glue into whichever array holds the previous box, descending into document fragments,
links and `enclosing` spans. Here the walk first lists the boxes it visits with their paths,
decides the class changes and the insertions on that list, then applies them to the tree:
class changes first, insertions deepest first and right to left, so that no recorded path is
invalidated by an earlier edit.

## References

* KaTeX's `src/buildHTML.ts` and `src/spacingData.ts` (MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- Whether a list is a group of its own (`true`), part of one (`false`: no spaces are inserted,
as for the body of `\color`) or the whole formula (`"root"`: `\newline` restarts the line). -/
inductive RealGroup where
  /-- Part of a group. -/
  | no
  /-- A group of its own. -/
  | yes
  /-- The whole formula. -/
  | root
  deriving BEq, Inhabited

/-- What a builder calls back into: the layout of one node in the given options, wrapped in a
size change when `baseOptions` (the parent's options) has a different size (KaTeX's
`buildGroup`). -/
structure BuildCtx where
  /-- Lay out a node: the node, its options, the parent's options. -/
  group : Node → Options → Option Options → BuildM Box

/-- The atom class of a box (`getTypeOfDomTree`): its first class, if that is one of the eight
atom classes. -/
def atomType (classes : Array String) : Option String :=
  match classes[0]? with
  | some c => if ["mord", "mop", "mbin", "mrel", "mopen", "mclose", "mpunct",
      "minner"].contains c then some c else none
  | none => none

/-- Whether a box is a partial group the spacing walk descends into (`checkPartialGroup`). -/
def isPartialGroup (b : Box) : Bool :=
  b.kind == .fragment || b.kind == .anchor || (b.kind == .span && b.hasClass "enclosing")

/-- The box at the left or right end of a box, through partial groups (`getOutermostNode`). -/
def outermost (b : Box) (right : Bool) : Box := Id.run do
  let mut cur := b
  -- each step goes one level down; the depth of a box tree bounds the steps
  for _ in [0:1 <<< 16] do
    if isPartialGroup cur then
      let next := if right then cur.children.back? else cur.children[0]?
      match next with
      | some c => cur := c
      | none => break
    else break
  return cur

/-- The atom class of a box, seen from one side (`getTypeOfDomTree` with a side). -/
def getTypeOfDomTree (b : Box) (side : Option Bool := none) : Option String :=
  match side with
  | some right => atomType (outermost b right).classes
  | none => atomType b.classes

/-- The space between atoms of two classes in mu, in display and text style (`spacings`). -/
def atomSpacing (left right : String) : Option Nat :=
  match left, right with
  | "mord", "mop" | "mord", "minner" => some 3
  | "mord", "mbin" => some 4
  | "mord", "mrel" => some 5
  | "mop", "mord" | "mop", "mop" | "mop", "minner" => some 3
  | "mop", "mrel" => some 5
  | "mbin", "mord" | "mbin", "mop" | "mbin", "mopen" | "mbin", "minner" => some 4
  | "mrel", "mord" | "mrel", "mop" | "mrel", "mopen" | "mrel", "minner" => some 5
  | "mclose", "mop" | "mclose", "minner" => some 3
  | "mclose", "mbin" => some 4
  | "mclose", "mrel" => some 5
  | "mpunct", "mrel" => some 5
  | "mpunct", _ =>
    if ["mord", "mop", "mopen", "mclose", "mpunct", "minner"].contains right then some 3
    else none
  | "minner", "mbin" => some 4
  | "minner", "mrel" => some 5
  | "minner", _ =>
    if ["mord", "mop", "mopen", "mpunct", "minner"].contains right then some 3 else none
  | _, _ => none

/-- The space between atoms in script and scriptscript style (`tightSpacings`). -/
def tightAtomSpacing (left right : String) : Option Nat :=
  match left, right with
  | "mord", "mop" | "mop", "mord" | "mop", "mop" | "mclose", "mop" | "minner", "mop" => some 3
  | _, _ => none

/-- A null delimiter: an empty span 0.12 em wide at the base size (`makeNullDelimiter`). -/
def makeNullDelimiter (o : Options) (classes : Array String) : Box :=
  makeSpan (classes ++ #["nulldelimiter"] ++ o.baseSizingClasses)

/-! ### The spacing walk -/

/-- A box the spacing walk visits: its path through partial groups, its classes, and whether it
is a space or a line break. -/
structure WalkLeaf where
  /-- Indices from the list down to the box. -/
  path : Array Nat
  /-- The box's classes. -/
  classes : Array String
  /-- An `mspace` box (skipped by the rules, but glue may follow it). -/
  isSpace : Bool
  /-- A `\newline`. -/
  isNewline : Bool
  /-- The box has `mtight`. -/
  tight : Bool
  deriving Inhabited

/-- The boxes of a list in the walk's order, descending into partial groups; `fuel` bounds the
nesting. -/
def walkLeaves : Nat → Array Box → Array Nat → Array WalkLeaf
  | 0, _, _ => #[]
  | fuel + 1, xs, pre => Id.run do
    let mut out := #[]
    for h : i in [0:xs.size] do
      let b := xs[i]
      if isPartialGroup b then
        out := out ++ walkLeaves fuel b.children (pre.push i)
      else
        out := out.push
          { path := pre.push i, classes := b.classes, isSpace := b.hasClass "mspace",
            isNewline := b.hasClass "katex-newline", tight := b.hasClass "mtight" }
    return out

/-- Apply `f` to the array of children at `path` (the list itself for the empty path). -/
def modifyArrayAt (xs : Array Box) : List Nat → (Array Box → Array Box) → Array Box
  | [], f => f xs
  | i :: rest, f =>
    if h : i < xs.size then
      let b := xs[i]
      xs.set i { b with children := modifyArrayAt b.children rest f }
    else xs

/-- Apply `f` to the box at `path`. -/
def modifyBoxAt (xs : Array Box) (path : Array Nat) (f : Box → Box) : Array Box :=
  match path.back? with
  | some i => modifyArrayAt xs path.pop.toList fun ys => ys.modify i f
  | none => xs

/-- The `mbin` and `mrel` rules (TeXbook rules 5 and 6) and the spacing (rule 20) over a list
(KaTeX's two `traverseNonSpaceNodes` passes), with the classes of the boxes assumed before and
after it. -/
def insertSpacing (groups : Array Box) (o glueOptions : Options) (isRoot : Bool)
    (before after : String) : BuildM (Array Box) := do
  let leaves := walkLeaves (1 <<< 16) groups #[]
  let n := leaves.size
  -- pass 1: a binary operator after nothing, an operator, a relation, an opening or punctuation,
  -- or before a relation, a closing or punctuation, becomes an ordinary atom
  let leftCancel := ["leftmost", "mbin", "mopen", "mrel", "mop", "mpunct"]
  let rightCancel := ["rightmost", "mrel", "mclose", "mpunct"]
  let mut cls := leaves.map (·.classes)
  let mut prev : Option Nat := none
  let mut prevDummy : Array String := #[before]
  for i in [0:n + 1] do
    let isNext := i == n
    if !isNext && leaves[i]!.isSpace then
      if isRoot && leaves[i]!.isNewline then
        prev := none
        prevDummy := #["leftmost"]
      continue
    let nodeCls := if isNext then #[after] else cls[i]!
    let prevCls := match prev with
      | some j => cls[j]!
      | none => prevDummy
    if prevCls[0]? == some "mbin" && rightCancel.contains (nodeCls[0]?.getD "") then
      match prev with
      | some j => cls := cls.modify j (·.set! 0 "mord")
      | none => prevDummy := prevDummy.set! 0 "mord"
    else if nodeCls[0]? == some "mbin" && leftCancel.contains (prevCls[0]?.getD "") then
      if !isNext then cls := cls.modify i (·.set! 0 "mord")
    prev := if isNext then prev else some i
  -- pass 2: glue between atoms, after the box visited last before the right one
  let mut inserts : Array (Array Nat × Nat × Box) := #[]
  let mut prev2 : Option Nat := none
  let mut prevDummy2 : Array String := prevDummy
  prevDummy2 := #[before]
  let mut insertAfter : Option (Array Nat) := none
  for i in [0:n + 1] do
    let isNext := i == n
    let isSpace := !isNext && leaves[i]!.isSpace
    if !isSpace then
      let nodeCls := if isNext then #[after] else cls[i]!
      let prevCls := match prev2 with
        | some j => cls[j]!
        | none => prevDummy2
      let tight := !isNext && leaves[i]!.tight
      let space := match atomType prevCls, atomType nodeCls with
        | some a, some b => if tight then tightAtomSpacing a b else atomSpacing a b
        | _, _ => none
      if let some mu := space then
        let glue ← makeGlue ⟨mu.toFloat, "mu"⟩ glueOptions
        match insertAfter with
        | some p => inserts := inserts.push (p.pop, p.back! + 1, glue)
        | none =>
          let frame := if isNext then #[] else leaves[i]!.path.pop
          inserts := inserts.push (frame, 0, glue)
      if !isNext then prev2 := some i
    else if isRoot && leaves[i]!.isNewline then
      prev2 := none
      prevDummy2 := #["leftmost"]
    if !isNext then insertAfter := some leaves[i]!.path
  let _ := o
  -- apply: class changes, then insertions deepest first and right to left
  let mut out := groups
  for i in [0:n] do
    if cls[i]! != leaves[i]!.classes then
      let c := cls[i]!
      out := modifyBoxAt out leaves[i]!.path fun b => { b with classes := c }
  let sorted := inserts.qsort fun (p, i, _) (q, j, _) =>
    p.size > q.size || (p.size == q.size && (p.toList > q.toList ||
      (p.toList == q.toList && i > j)))
  for (frame, idx, glue) in sorted do
    out := modifyArrayAt out frame.toList fun ys => ys.insertIdxIfInBounds idx glue
  return out

/-- KaTeX's `buildExpression`: each node laid out (fragments flattened), adjacent symbols
merged, and for a real group the binary-operator rules and the spacing applied, with the
classes `surrounding` assumed on either side. -/
def buildExpressionWith (ctx : BuildCtx) (expression : Array Node) (o : Options)
    (isRealGroup : RealGroup) (surrounding : Option String × Option String := (none, none)) :
    BuildM (Array Box) := do
  let mut groups := #[]
  for n in expression do
    let out ← ctx.group n o none
    if out.isFragment then groups := groups ++ out.children else groups := groups.push out
  groups := tryCombineChars groups
  if isRealGroup == .no then return groups
  let glueOptions := match expression with
    | #[.sizing _ _ size _] => o.havingSize size
    | #[.styling _ _ style _ _] => o.havingStyle (MathStyle.ofName style)
    | _ => o
  insertSpacing groups o glueOptions (isRealGroup == .root)
    (surrounding.1.getD "leftmost") (surrounding.2.getD "rightmost")

/-- A node laid out in `o`, or an empty span for a missing node. -/
def BuildCtx.groupOpt (ctx : BuildCtx) (n : Option Node) (o : Options)
    (base : Option Options := none) :
    BuildM Box :=
  match n with
  | some n => ctx.group n o base
  | none => pure (makeSpan)

/-- `buildExpression` through the context. -/
def BuildCtx.expr (ctx : BuildCtx) (expression : Array Node) (o : Options) (isRealGroup : RealGroup)
    (surrounding : Option String × Option String := (none, none)) : BuildM (Array Box) :=
  buildExpressionWith ctx expression o isRealGroup surrounding

end LeAnTeX
