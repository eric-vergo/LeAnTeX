/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Text.Pack

/-!
# Vertical lists

TeX's vertical lists: boxes stacked from top to bottom with glue, kerns and penalties between
them, as TeX's main vertical list and the pages built from it hold them. Lengths are in sp.

* `VNode`: an item of a vertical list. A horizontal box holds an `HNode` list with its glue
  setting (a paragraph's line is one); a vertical box holds a vertical list; an insertion
  holds the material of a footnote; `label` and `float` are what LaTeX keeps in the list for a
  `\label` and for a floating figure or table, to be resolved when the page is built.
* `vpack`: TeX's `vpack`: a vertical list in a box of a given height (or its natural height),
  the depth limited to a maximum, the glue set as TeX sets it.
* `appendBox`: TeX's `append_to_vlist`: a box added below the list with the interline glue
  (`\baselineskip`, `\lineskip`, `\lineskiplimit`) from the previous box's depth.
* `positions`: where every item of a set vertical list goes, as TeX's `vlist_out` places it
  (the glue's stretch or shrink accumulated and the running total rounded).

## Implementation notes

TeX's glue orders are 0 finite, 1 `fil`, 2 `fill`, 3 `filll` (as `Glue` has them). A glue
ratio is the quotient rounded to single precision, as LuaTeX stores it (`ratio32`).
-/

namespace LeAnTeX.Doc

open LeAnTeX.Text

/-- An item of a vertical list. -/
inductive VNode where
  /-- A horizontal box: its width, height, depth, shift right, content and glue setting. -/
  | hbox (width height depth shift : Int) (content : Array HNode) (glue : GlueSet)
  /-- A vertical box: its width, height, depth, shift right, content and glue setting. -/
  | vbox (width height depth shift : Int) (content : Array VNode) (glue : GlueSet)
  /-- Glue, with LuaTeX's subtype (0 user glue, 1 `\lineskip`, 2 `\baselineskip`, 3
  `\parskip`, 10 `\topskip`). -/
  | glue (g : Glue) (subtype : Nat)
  /-- A kern. -/
  | kern (width : Int)
  /-- A penalty. -/
  | penalty (p : Int)
  /-- A rule: its width (`none` for the width of the box it is in), height and depth. -/
  | rule (width : Option Int) (height depth : Int)
  /-- An insertion of class `n` (LaTeX's footnotes are class 254 here): its material, the
  `\splittopskip` and `\splitmaxdepth` in force, and its `\floatingpenalty`. -/
  | ins (n : Nat) (content : Array VNode) (splitTop : Glue) (splitMaxDepth : Int)
      (floatCost : Int)
  /-- Where a `\label` (or another reference to the page) was set: its key. -/
  | label (key : String)
  /-- A floating figure or table: its index in the document's table of floats. -/
  | float (index : Nat)
  /-- A mark: a heading's text for running heads. -/
  | mark (text : String)
  deriving Inhabited

namespace VNode

/-- The height of an item as a vertical list stacks it: a box's or rule's height, 0 for the
rest. -/
def height : VNode → Int
  | hbox _ h _ _ _ _ | vbox _ h _ _ _ _ | rule _ h _ => h
  | _ => 0

/-- The depth of an item: a box's or rule's depth, 0 for the rest. -/
def depth : VNode → Int
  | hbox _ _ d _ _ _ | vbox _ _ d _ _ _ | rule _ _ d => d
  | _ => 0

/-- The width of an item with its shift: what it takes from the box's width. -/
def extent : VNode → Int
  | hbox w _ _ s _ _ | vbox w _ _ s _ _ => w + s
  | rule (some w) _ _ => w
  | _ => 0

/-- Whether the item is a box or a rule (TeX's `hlist`, `vlist` and `rule` nodes). -/
def isBox : VNode → Bool
  | hbox .. | vbox .. | rule .. => true
  | _ => false

/-- Whether TeX discards the item after a page break: glue, kerns and penalties. -/
def discardable : VNode → Bool
  | glue .. | kern _ | penalty _ => true
  | _ => false

end VNode

/-- The natural measures of a vertical list, as TeX's `vpack` takes them: the natural height
(boxes' heights and depths, glue and kerns, the last box's depth not included), the stretch
and shrink in each order, the depth of the last item and the widest item. -/
structure VMeasure where
  /-- The natural height, the last item's depth not included. -/
  height : Int := 0
  /-- The depth of the last item (0 after glue or a kern). -/
  depth : Int := 0
  /-- The stretch, by order. -/
  stretch : Array Int := #[0, 0, 0, 0]
  /-- The shrink, by order. -/
  shrink : Array Int := #[0, 0, 0, 0]
  /-- The widest item, its shift included. -/
  width : Int := 0
  deriving Inhabited

/-- The measures of a vertical list (TeX's `vpack`, before the glue is set). -/
def vmeasure (items : Array VNode) : VMeasure := Id.run do
  let mut m : VMeasure := {}
  for n in items do
    match n with
    | .hbox .. | .vbox .. | .rule .. =>
      m := { m with height := m.height + m.depth + n.height, depth := n.depth,
                    width := max m.width n.extent }
    | .glue g _ =>
      m := { m with height := m.height + m.depth + g.width, depth := 0,
                    stretch := m.stretch.modify g.stretchOrder (· + g.stretch),
                    shrink := m.shrink.modify g.shrinkOrder (· + g.shrink) }
    | .kern w => m := { m with height := m.height + m.depth + w, depth := 0 }
    | _ => pure ()
  return m

/-- A set vertical box: its width, height, depth, content and glue setting, with the badness
of the setting and whether it is overfull or underfull (TeX's `vpack`). -/
structure VBox where
  /-- The width. -/
  width : Int
  /-- The height. -/
  height : Int
  /-- The depth. -/
  depth : Int
  /-- The content. -/
  content : Array VNode
  /-- The glue setting. -/
  glue : GlueSet
  /-- The badness of the setting (TeX's `badness`), 0 when natural or set in infinite glue;
  for shrinking beyond the total shrink TeX's 1000000 is not used here: the badness is that of
  the total. -/
  badness : Int := 0
  deriving Inhabited

/-- The highest order with nonzero stretch (or shrink) among four totals. -/
def highestOrder (totals : Array Int) : Nat :=
  if totals.getD 3 0 != 0 then 3 else if totals.getD 2 0 != 0 then 2
  else if totals.getD 1 0 != 0 then 1 else 0

/-- TeX's `vpack`: `items` in a box of height `target` (`none` for the natural height), the
depth limited to `maxDepth` (the excess moved into the height, as TeX moves it). The glue is
set in the highest order that has stretch (or shrink); finite shrink never beyond its total. -/
def vpack (items : Array VNode) (target : Option Int := none)
    (maxDepth : Int := 1073741823) : VBox :=
  let m := vmeasure items
  let (natural, depth) := if m.depth > maxDepth then (m.height + m.depth - maxDepth, maxDepth)
    else (m.height, m.depth)
  let h := target.getD natural
  let x := h - natural
  let glue : GlueSet :=
    if x > 0 then
      let o := highestOrder m.stretch
      let s := m.stretch.getD o 0
      if s != 0 then { sign := 1, order := o, ratio := ratio32 x s } else {}
    else if x < 0 then
      let o := highestOrder m.shrink
      let s := m.shrink.getD o 0
      if s == 0 then {}
      else if o == 0 && -x > s then { sign := 2, order := 0, ratio := 1 }
      else { sign := 2, order := o, ratio := ratio32 (-x) s }
    else {}
  let bad :=
    if x > 0 then
      if highestOrder m.stretch != 0 then 0 else badness x (m.stretch.getD 0 0)
    else if x < 0 then
      if highestOrder m.shrink != 0 then 0 else badness (-x) (m.shrink.getD 0 0)
    else 0
  { width := m.width, height := h, depth, content := items, glue, badness := bad }

/-- The box as a list item. -/
def VBox.toNode (b : VBox) (shift : Int := 0) : VNode :=
  .vbox b.width b.height b.depth shift b.content b.glue

/-- The interline parameters: `\baselineskip`, `\lineskip`, `\lineskiplimit`. -/
structure Interline where
  /-- `\baselineskip`. -/
  baselineSkip : Glue := { width := 12 * 65536 }
  /-- `\lineskip`. -/
  lineSkip : Glue := { width := 65536 }
  /-- `\lineskiplimit`. -/
  lineSkipLimit : Int := 0
  deriving Inhabited

/-- `\prevdepth`'s value that suppresses interline glue (TeX's `ignore_depth`, -1000 pt). -/
def ignoreDepth : Int := -65536000

/-- TeX's `append_to_vlist`: the interline glue for a box of `height` below a list whose last
box has depth `prevDepth`, unless `prevDepth` is `ignoreDepth` or less: `\baselineskip` less
the depth and the height, or `\lineskip` if that is less than `\lineskiplimit`. -/
def interlineGlue (p : Interline) (prevDepth height : Int) : Option VNode :=
  if prevDepth ≤ ignoreDepth then none
  else
    let d := p.baselineSkip.width - prevDepth - height
    if d < p.lineSkipLimit then some (.glue p.lineSkip 1)
    else some (.glue { p.baselineSkip with width := d } 2)

/-- Appends a box (TeX's `append_to_vlist`): the interline glue first (`interlineGlue`), then
the box; returns the list and the new `\prevdepth` (the box's depth). -/
def appendBox (list : Array VNode) (p : Interline) (prevDepth : Int) (b : VNode) :
    Array VNode × Int :=
  let list := match interlineGlue p prevDepth b.height with
    | some g => list.push g
    | none => list
  (list.push b, b.depth)

/-- A float rounded to the nearest integer, within ±2³⁰ (TeX's `vet_glue` bound). -/
def roundGlue (v : Float) : Int :=
  let v := if v > 1073741823 then 1073741823 else if v < -1073741823 then -1073741823 else v
  let r := (v.abs + 0.5).floor
  let n : Int := r.toUInt64.toNat
  if v < 0 then -n else n

/-- The size each glue of a box set with `g` takes, in order (TeX's `vlist_out` and
`hlist_out`: the stretch or shrink of the set order accumulated and the running total
rounded): from the glue items' specifications, their sizes. -/
def glueSizes (g : GlueSet) (glues : Array Glue) : Array Int := Id.run do
  let mut out := #[]
  let mut total : Float := 0
  let mut done : Int := 0
  for gl in glues do
    let mut w := gl.width
    if g.sign == 1 && gl.stretchOrder == g.order then
      total := total + Float.ofInt gl.stretch
      let now := roundGlue (g.ratio * total)
      w := w + now - done
      done := now
    else if g.sign == 2 && gl.shrinkOrder == g.order then
      total := total - Float.ofInt gl.shrink
      let now := roundGlue (g.ratio * total)
      w := w + now - done
      done := now
    out := out.push w
  return out

/-- Where the items of a vertical box set with `g` go: for each item, its top below the box's
top (TeX's `vlist_out`). A box's baseline is its top plus its height. -/
def positions (items : Array VNode) (g : GlueSet) : Array Int := Id.run do
  let glues := items.filterMap fun n => match n with | .glue gl _ => some gl | _ => none
  let sizes := glueSizes g glues
  let mut out := #[]
  let mut y : Int := 0
  let mut k := 0
  for n in items do
    out := out.push y
    match n with
    | .hbox .. | .vbox .. | .rule .. => y := y + n.height + n.depth
    | .glue .. =>
      y := y + sizes.getD k 0
      k := k + 1
    | .kern w => y := y + w
    | _ => pure ()
  return out

end LeAnTeX.Doc
