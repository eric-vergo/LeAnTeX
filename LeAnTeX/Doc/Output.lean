/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Doc.PageBuilder
import LeAnTeX.Doc.Class

/-!
# Pages

What LaTeX's output routine makes of a page the page builder cut (its `\@makecol` and
`\@outputpage`, one column, one-sided), and where everything on a page goes:

* **The column**: the page's items (TeX's `\box255`, unpacked); when there are footnotes,
  `\skip\footins`, the footnote rule (`\kern-3pt`, a rule 0.4 pt high and 0.4 `\columnwidth`
  wide, `\kern2.6pt`) and the footnotes; top floats before it, each followed by `\floatsep`
  and the last by `\textfloatsep`, bottom floats after it, preceded by `\textfloatsep` and
  separated by `\floatsep`; all packed to `\textheight` with the column's depth taken back
  (`\vskip -\dp`) and `\vskip 0pt plus 0.0001fil` at the bottom (`\raggedbottom`, the article
  class's default for one-sided documents).
* **The page**: the paper's size; the text body's top-left corner one inch plus
  `\oddsidemargin` from the left and one inch plus `\topmargin`, `\headheight` and `\headsep`
  from the top; the foot's baseline `\footskip` below the body's bottom; the head (empty in the
  `plain` and `empty` styles).
* **Positions**: `Page.lines` lists every line on a page (a horizontal box that holds
  characters directly, not inside another such box) with the position of its left edge and
  baseline from the paper's top-left corner, as TeX's shipping out places them
  (`vlist_out`, `hlist_out`); this is what the tests compare with LuaLaTeX.

## Main definitions

* `Page`, `makeColumn`, `Page.lines`, `PlacedLine`.
-/

namespace LeAnTeX.Doc

open LeAnTeX.Text

/-- One inch in sp (TeX's origin is one inch from the paper's top and left edges). -/
def inch : Int := 4736286

/-- A page: its number (`\c@page`) and its printed number, the paper's size, the text body
(a vertical box `\textheight` tall) with its top-left corner, the foot line (a horizontal box)
with its left edge and baseline, the floats on it and the anchors (labels) it holds. -/
structure Page where
  /-- The page counter's value. -/
  number : Int
  /-- The page number as printed. -/
  text : String
  /-- The paper's width. -/
  width : Int
  /-- The paper's height. -/
  height : Int
  /-- The text body. -/
  body : VBox
  /-- The body's left edge. -/
  bodyX : Int
  /-- The body's top. -/
  bodyY : Int
  /-- The foot line, if the page style has one. -/
  foot : Option VNode := none
  /-- The foot line's left edge. -/
  footX : Int := 0
  /-- The foot line's baseline. -/
  footY : Int := 0
  /-- The anchors on the page. -/
  anchors : Array String := #[]
  deriving Inhabited

/-- The footnote rule (LaTeX's `\footnoterule`) for a column width. -/
def footnoteRule (colWidth : Int) : Array VNode :=
  #[.kern (-3 * 65536), .rule (some (colWidth * 2 / 5)) 26214 0, .kern 170394]

/-- The column of a page (see the module docstring): its items, footnotes and floats, packed
to `textHeight`; the boxes of the floats by index. A page of floats only is its floats between
`\@fptop` and `\@fpbot`, `\@fpsep` between them. -/
def makeColumn (cp : ClassParams) (p : PageOut) (colWidth : Int) (floats : Array VNode) :
    VBox := Id.run do
  let box := fun (i : Nat) => floats[i]?.getD (.kern 0)
  let fil : Glue := { stretch := 65536, stretchOrder := 1 }
  if !p.floatPage.isEmpty then
    let back : Glue :=
      { cp.fpSep with width := -cp.fpSep.width, stretch := -cp.fpSep.stretch }
    let mut items : Array VNode := #[.glue fil 0, .glue back 0]
    for i in p.floatPage do
      items := items.push (.glue cp.fpSep 0) |>.push (box i)
    items := items.push (.glue fil 0)
    return vpack items (some cp.textHeight)
  let mut items := p.items
  match p.inserts.find? (·.1 == footnoteClass) with
  | some (_, fn) =>
    if !fn.isEmpty then
      items := items.push (.glue cp.footinsSkip 0) ++ footnoteRule colWidth ++ fn
  | none => pure ()
  let negSep : Glue :=
    { cp.floatSep with
      width := -cp.floatSep.width, stretch := -cp.floatSep.stretch,
      shrink := -cp.floatSep.shrink }
  if !p.top.isEmpty then
    let mut pre := #[]
    for i in p.top do
      pre := pre.push (box i) |>.push (.glue cp.floatSep 0)
    items := pre ++ #[.glue negSep 0, .glue cp.textFloatSep 0] ++ items
  if !p.bottom.isEmpty then
    let mut post := #[VNode.glue cp.textFloatSep 0]
    for i in p.bottom do
      post := post.push (box i) |>.push (.glue cp.floatSep 0)
    items := items ++ post.push (.glue negSep 0)
  let dp := (vmeasure items).depth
  items := items.push (.glue { width := -dp } 0)
  items := items.push (.glue { stretch := 7, stretchOrder := 1 } 0)
  return vpack items (some cp.textHeight)
where
  /-- The insertion class of footnotes. -/
  footnoteClass : Nat := 254

/-- The anchors (labels) in a vertical list and in the lists nested in it, `fuel` levels. -/
def anchorsOf (items : Array VNode) : Nat → Array String
  | 0 => #[]
  | fuel + 1 => items.foldl (init := #[]) fun acc n => match n with
    | .label k => acc.push k
    | .vbox _ _ _ _ c _ => acc ++ anchorsOf c fuel
    | .ins _ c _ _ _ => acc ++ anchorsOf c fuel
    | _ => acc

/-- A line placed on a page: its left edge and baseline, its box, its text (characters, a
space for each visible glue; formulas as `$…$` with their source) and whether it holds a
formula. -/
structure PlacedLine where
  /-- The left edge. -/
  x : Int
  /-- The baseline. -/
  y : Int
  /-- The width. -/
  w : Int
  /-- The height. -/
  h : Int
  /-- The depth. -/
  d : Int
  /-- The text. -/
  text : String
  /-- Whether it holds a formula. -/
  math : Bool := false
  deriving Inhabited, Repr

/-- The text of a horizontal list (see `PlacedLine`), `fuel` levels deep. -/
def hText (nodes : Array HNode) : Nat → String × Bool
  | 0 => ("", false)
  | fuel + 1 => nodes.foldl (init := ("", false)) fun (s, m) n => match n with
    | .glyph c .. => (s ++ ligatureText c, m)
    | .glue g _ => (if g.width > 0 || g.stretch > 0 then s ++ " " else s, m)
    | .disc _ _ _ r _ => let (t, m') := hText r fuel; (s ++ t, m || m')
    | .box _ _ _ _ c => let (t, m') := hText c fuel; (s ++ t, m || m')
    | .math _ _ _ dl _ =>
      (s ++ "$" ++ ((dl.formulas[0]?.map (·.source)).getD "") ++ "$", true)
    | _ => (s, m)
where
  /-- A ligature's characters (as TeX records its components). -/
  ligatureText (c : Char) : String :=
    match c with
    | 'ﬀ' => "ff" | 'ﬁ' => "fi" | 'ﬂ' => "fl" | 'ﬃ' => "ffi" | 'ﬄ' => "ffl"
    | c => c.toString

/-- Whether a horizontal list holds a character (or a formula) directly. -/
def holdsText (nodes : Array HNode) : Bool :=
  nodes.any fun n => match n with
    | .glyph .. | .disc .. => true
    -- a formula, not an image (an image's display list records no formula)
    | .math _ _ _ dl _ => !dl.formulas.isEmpty
    | _ => false

/-- The lines in a horizontal list set with `g` at `(x, y)` (its baseline), not inside a line,
`fuel` levels deep. -/
def hLines (nodes : Array HNode) (g : GlueSet) (x y : Int) : Nat → Array PlacedLine
  | 0 => #[]
  | fuel + 1 => Id.run do
    let glues := nodes.filterMap fun n => match n with | .glue gl _ => some gl | _ => none
    let sizes := glueSizes g glues
    let mut out := #[]
    let mut cx := x
    let mut k := 0
    for n in nodes do
      match n with
      | .box w h d s c =>
        if holdsText c then
          let (t, m) := hText c 64
          out := out.push { x := cx, y := y + s, w, h, d, text := t, math := m }
        else out := out ++ hLines c {} cx (y + s) fuel
        cx := cx + w
      | .glue .. =>
        cx := cx + sizes.getD k 0
        k := k + 1
      | n => cx := cx + n.width
    return out

/-- The lines in a vertical list set with `g` whose top is at `(x, y)`, `fuel` levels deep
(TeX's `vlist_out`). -/
def vLines (items : Array VNode) (g : GlueSet) (x y : Int) : Nat → Array PlacedLine
  | 0 => #[]
  | fuel + 1 => Id.run do
    let tops := positions items g
    let mut out := #[]
    for h : i in [0:items.size] do
      let top := y + tops.getD i 0
      match items[i] with
      | .hbox w h d s c gl =>
        if holdsText c then
          let (t, m) := hText c 64
          out := out.push { x := x + s, y := top + h, w, h, d, text := t, math := m }
        else out := out ++ hLines c gl (x + s) (top + h) fuel
      | .vbox _ _ _ s c gl => out := out ++ vLines c gl (x + s) top fuel
      | _ => pure ()
    return out

/-- Every line on a page, in the order TeX ships them: the body's, then the foot's. -/
def Page.lines (p : Page) : Array PlacedLine :=
  let body := vLines p.body.content p.body.glue p.bodyX p.bodyY 64
  match p.foot with
  | some (.hbox w h d _ c _) =>
    if holdsText c then
      let (t, m) := hText c 64
      body.push { x := p.footX, y := p.footY, w, h, d, text := t, math := m }
    else body
  | _ => body

end LeAnTeX.Doc
