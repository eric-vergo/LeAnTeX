/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Text.Pack

/-!
# TeX's boxes

The horizontal and vertical lists TeX's math layout builds: characters of fonts, boxes with
their glue setting, rules, glue, kerns, penalties and the math nodes that open and close an
inline formula. Lengths are sp. `hpack` and `vpack` are TeX's packaging of a list into a box at
its natural size or to a given size; boxes keep their content, so a box can be drawn and its
dimensions checked against its children.

## Main definitions

* `Node`: a node of a list.
* `hpack`, `vpack`: TeX's `hpack` and `vpackage` (natural, or exactly to a size).
* `Node.width`, `height`, `depth`: a node's extent in a horizontal list.

## References

* D. E. Knuth, *TeX: The Program*, §133–§159 (the node types), §649–§679 (`hpack`,
  `vpackage`).
-/

namespace LeAnTeX.TeXMath

open LeAnTeX.Text (Glue KernKind GlueSet hpackGlue)

/-- A node of a horizontal or vertical list. -/
inductive Node where
  /-- A character of a font (an index into the layout's font table), with its width, height
  and depth. -/
  | char (font : Nat) (code : Nat) (width height depth : Int)
  /-- A glyph of an OpenType font set by the text layer's shaping (text inside a formula): the
  font's index, the character it shows, the glyph and its width, height and depth. -/
  | glyph (font : Nat) (char : Char) (glyph : Nat) (width height depth : Int)
  /-- A box: vertical or horizontal, its width, height, depth, its shift (down for a box in a
  horizontal list, right in a vertical one), its glue setting and its content. -/
  | box (vertical : Bool) (width height depth shift : Int) (set : GlueSet) (list : Array Node)
  /-- A rule; `none` for a running dimension (the enclosing box's). -/
  | rule (width height depth : Option Int)
  /-- Glue, with LuaTeX's subtype (0 user glue, 17–19 `\thinmuskip`, `\medmuskip`,
  `\thickmuskip`, 99 math glue). -/
  | glue (g : Glue) (subtype : Nat)
  /-- A kern. -/
  | kern (width : Int) (kind : KernKind)
  /-- A penalty. -/
  | penalty (p : Int)
  /-- The start (`after = false`) or end of an inline formula, with `\mathsurround`. -/
  | math (after : Bool) (surround : Int)
  deriving Inhabited

namespace Node

/-- The width a node takes in a horizontal list (glue at its natural width). -/
def width : Node → Int
  | char _ _ w _ _ | glyph _ _ _ w _ _ | box _ w _ _ _ _ _ | kern w _ | math _ w => w
  | rule w _ _ => w.getD 0
  | glue g _ => g.width
  | penalty _ => 0

/-- The height of a node in a horizontal list (a box's less its shift). -/
def height : Node → Int
  | char _ _ _ h _ | glyph _ _ _ _ h _ => h
  | box _ _ h _ s _ _ => h - s
  | rule _ h _ => h.getD 0
  | _ => 0

/-- The depth of a node in a horizontal list (a box's plus its shift). -/
def depth : Node → Int
  | char _ _ _ _ d | glyph _ _ _ _ _ d => d
  | box _ _ _ d s _ _ => d + s
  | rule _ _ d => d.getD 0
  | _ => 0

/-- The extent a node takes in a vertical list: its height plus depth for a box or rule, a
kern's or glue's width. -/
def vSize : Node → Int
  | box _ _ h d _ _ _ => h + d
  | rule _ h d => h.getD 0 + d.getD 0
  | kern w _ => w
  | glue g _ => g.width
  | char _ _ _ h d => h + d
  | _ => 0

/-- The width a node takes in a vertical list (a box's plus its shift). -/
def vWidth : Node → Int
  | box _ w _ _ s _ _ => w + s
  | rule w _ _ => w.getD 0
  | char _ _ w _ _ => w
  | _ => 0

/-- A box's shift set to `s` (other nodes unchanged). -/
def withShift (s : Int) : Node → Node
  | box v w h d _ g l => box v w h d s g l
  | n => n

/-- A box's width set to `w` (other nodes unchanged), as TeX assigns `width(b)`. -/
def withWidth (w : Int) : Node → Node
  | box v _ h d s g l => box v w h d s g l
  | n => n

/-- A box's height and depth set (other nodes unchanged). -/
def withHD (h d : Int) : Node → Node
  | box v w _ _ s g l => box v w h d s g l
  | n => n

/-- A box's own height, its shift not counted (a node's `height` otherwise). -/
def boxHeight : Node → Int
  | box _ _ h _ _ _ _ => h
  | n => n.height

/-- A box's own depth, its shift not counted (a node's `depth` otherwise). -/
def boxDepth : Node → Int
  | box _ _ _ d _ _ _ => d
  | n => n.depth

/-- A box's shift (0 for other nodes). -/
def shift : Node → Int
  | box _ _ _ _ s _ _ => s
  | _ => 0

/-- Whether the node is a box. -/
def isBox : Node → Bool
  | box .. => true
  | _ => false

/-- A box's content (empty for other nodes). -/
def list : Node → Array Node
  | box _ _ _ _ _ _ l => l
  | _ => #[]

end Node

/-- The stretch and shrink totals of each order of a list's glue. -/
def glueTotals (l : Array Node) : Array Int × Array Int :=
  l.foldl (init := (#[0, 0, 0, 0], #[0, 0, 0, 0])) fun (st, sh) n => match n with
    | .glue g _ => (st.modify g.stretchOrder (· + g.stretch), sh.modify g.shrinkOrder (· + g.shrink))
    | _ => (st, sh)

/-- TeX's `hpack`: a horizontal box of the list, at its natural width (`to = none`) or exactly
`to` wide with its glue set. Height and depth are the largest of the children's (with their
shifts), never below 0. -/
def hpack (l : Array Node) (to : Option Int := none) : Node :=
  let w := l.foldl (init := 0) fun a n => a + n.width
  let h := l.foldl (init := 0) fun a n => max a n.height
  let d := l.foldl (init := 0) fun a n => max a n.depth
  match to with
  | none => .box false w h d 0 {} l
  | some t =>
    let (st, sh) := glueTotals l
    .box false t h d 0 (hpackGlue w t st sh) l

/-- TeX's `vpackage` at natural height with no depth limit: a vertical box whose height is the
sum of the children's sizes except the last box's depth, which is its depth (0 when the list
ends with glue or a kern), and whose width is the largest of the children's (with shifts). -/
def vpack (l : Array Node) : Node := Id.run do
  let mut w := 0
  let mut x := 0
  let mut d := 0
  for n in l do
    match n with
    | .box _ bw bh bd s _ _ =>
      x := x + d + bh
      d := bd
      w := max w (bw + s)
    | .rule rw rh rd =>
      x := x + d + rh.getD 0
      d := rd.getD 0
      w := max w (rw.getD 0)
    | .glue g _ => x := x + d + g.width; d := 0
    | .kern k _ => x := x + d + k; d := 0
    | .char _ _ cw ch cd => x := x + d + ch; d := cd; w := max w cw
    | _ => pure ()
  return .box true w x d 0 {} l

end LeAnTeX.TeXMath
