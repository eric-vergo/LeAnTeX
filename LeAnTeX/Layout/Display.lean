/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Layout.Box
import LeAnTeX.Layout.Metrics
import LeAnTeX.Data.FontAdvances
import LeAnTeX.Data.SvgPaths

/-!
# The display list

A laid-out formula as positioned drawing operations, for back ends that draw it (an editor's
glyph renderer, a rasteriser, SVG) without a browser: glyphs, filled rectangles and SVG paths,
in em, with the source range of what they were built from. `DisplayList.ofBox` computes it from
the box tree by evaluating the part of KaTeX's style sheet (`katex.scss`) that its trees use:
inline flow with margins, the tables of `makeVList`, size changes, fonts, colours, alignment.

## The display list

* **Units.** Every length is an `Em`: a multiple of the formula's font size, which is the font
  size of KaTeX's `katex` element (KaTeX sets it to 1.21 times the surrounding text).
* **Coordinates.** The origin is the left end of the formula's baseline; `x` grows to the right
  and `y` downwards, as on a screen, so a point above the baseline has a negative `y`.
* **Extent.** `width` is the formula's advance; `height` and `depth` its extent above and below
  the baseline as KaTeX's struts give it. Ink may extend beyond this box (italic overhangs,
  the tails of SVG images), as it does in KaTeX's rendering.
* **Glyphs.** A glyph is one character of one of KaTeX's font faces (`Face`, named as KaTeX's
  font files are, e.g. `Main-Regular`), at a font size, with its baseline origin at `(x, y)`.
  The character is a Unicode scalar value; a back end maps it to a glyph of the face's font
  (through the font's `cmap`). Advances are the fonts' own, as a browser uses them (they differ
  from the widths of KaTeX's metric tables by up to 5e-4 em, and for a few glyphs, such as
  `\iint`, by more). `exact` is false for a
  character KaTeX has no metrics for in that face (characters of other scripts, which KaTeX
  measures as an `M` and leaves to the browser's fallback fonts, and a few symbols KaTeX lays
  out with no width): a back end draws it with a fallback font, and its advance, here KaTeX's
  stand-in, is only an estimate.
* **Rules.** A rule is a filled rectangle: top-left corner, width and height (fraction bars,
  overlines, the rules of `\rule`).
* **Paths.** A path is SVG path data with its `viewBox` and `preserveAspectRatio`, drawn into
  the rectangle given (the surd of `\sqrt`, stretchy delimiters and accents). `clip`, when set,
  is the rectangle the image is clipped to.
* **Shadows.** `\pmb` thickens its material with a copy offset by (0.02 em, 0.01 em) of its
  font size, drawn first (KaTeX's `text-shadow`, whose 0.04 px blur is left out); those glyphs
  are marked `shadow`.
* **Colour.** Every item has the colour it is drawn in (a CSS colour as the formula gave it), or
  none for the surrounding text's colour. Material inside `\phantom` is not drawn and has no
  items.
* **Source.** Items and `regions` carry the source range (start and end offsets, in UTF-16 code
  units of the formula, end exclusive) of the innermost parse node that has one.
* **Order.** Items are in the order of KaTeX's markup, which is the order a browser paints them.

## Invariants

* Every glyph's face is one of KaTeX's twenty font files, and its size is positive.
* Rules and path rectangles have non-negative width and height.
* `parts` lists the formula's unbreakable parts (KaTeX's `katex-base` spans) in order, without
  gaps on a line: a back end that breaks lines may break between them, as a browser does. The
  equation tag, if any, is the last part, marked as such and placed after the formula; in
  display mode KaTeX puts it at the right end of the line instead (a back end moves the items
  from the tag's left end on).
* `lines` partitions `items` into the lines that `\\` and `\newline` break the formula into
  (one line otherwise). Each line's items are relative to that line's own baseline and left
  end; a back end stacks the lines with the spacing of its surrounding text, as a browser
  does. `width` is the widest line's.

## Main definitions

* `Face`, `Item`, `Region`, `Part`, `Line`, `DisplayList`.
* `DisplayList.ofBox`: the display list of a box tree.
* `DisplayList.wellFormed`: the invariants, as a check.

## References

* KaTeX's `src/styles/katex.scss`, `src/buildCommon.ts` (`makeVList`) and KaTeX's fonts
  (`LeAnTeX.Data.FontAdvances`) (MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- One of KaTeX's font faces: a family (`Main`, `Math`, `AMS`, `Caligraphic`, `Fraktur`,
`SansSerif`, `Script`, `Size1`–`Size4`, `Typewriter`) in a weight and a style. -/
structure Face where
  /-- The family, without KaTeX's `KaTeX_` prefix. -/
  family : String := "Main"
  /-- Bold. -/
  bold : Bool := false
  /-- Italic. -/
  italic : Bool := false
  deriving BEq, Inhabited, Repr

/-- The name of the face's font file (and metric table): `Main-BoldItalic`, `Math-Italic`,
`Size2-Regular`, …. A weight or style the family does not have falls back to the nearest face
it has, as a browser's font matching does with KaTeX's `@font-face` rules. -/
def Face.name (f : Face) : String :=
  let styles : List String := match f.family with
    | "Main" => ["Regular", "Bold", "Italic", "BoldItalic"]
    | "Math" => ["Italic", "BoldItalic"]
    | "Caligraphic" | "Fraktur" => ["Regular", "Bold"]
    | "SansSerif" => ["Regular", "Bold", "Italic"]
    | _ => ["Regular"]
  let want := if f.bold && f.italic then "BoldItalic" else if f.bold then "Bold"
    else if f.italic then "Italic" else "Regular"
  let pick := if styles.contains want then want
    else if f.bold && styles.contains "Bold" then "Bold"
    else if f.bold && styles.contains "BoldItalic" then "BoldItalic"
    else if f.italic && styles.contains "Italic" then "Italic"
    else styles.head!
  f.family ++ "-" ++ pick

/-- A source range: start and end offsets in UTF-16 code units, end exclusive. -/
abbrev SourceRange := Nat × Nat

/-- A drawing operation. -/
inductive Item where
  /-- A character of a face at a size, its baseline origin at `(x, y)`; `exact` when KaTeX has
  the character's own metrics in the face; `shadow` for the offset copy that `\pmb` draws
  under its material (CSS `text-shadow`). -/
  | glyph (face : Face) (char : Char) (x y size : Em) (exact shadow : Bool)
      (color : Option String) (source : Option SourceRange)
  /-- A filled rectangle with its top-left corner at `(x, y)`. -/
  | rule (x y width height : Em) (color : Option String) (source : Option SourceRange)
  /-- SVG path data drawn into the rectangle with top-left corner `(x, y)`. -/
  | path (data viewBox preserveAspectRatio : String) (x y width height : Em)
      (clip : Option (Em × Em × Em × Em)) (color : Option String) (source : Option SourceRange)
  deriving Inhabited, Repr

/-- The rectangle of a laid-out parse node, for mapping a position back to the source: its left
end and width, its baseline, and its height and depth. -/
structure Region where
  /-- Left end. -/
  x : Em
  /-- Baseline. -/
  y : Em
  /-- Width. -/
  width : Em
  /-- Height above the baseline. -/
  height : Em
  /-- Depth below the baseline. -/
  depth : Em
  /-- The source range. -/
  source : SourceRange
  deriving Inhabited, Repr

/-- An unbreakable part of a formula (KaTeX's `katex-base` spans) or its equation tag: left end
and width on its line. -/
structure Part where
  /-- Left end. -/
  x : Em
  /-- Width. -/
  width : Em
  /-- The line it is on. -/
  line : Nat
  /-- Whether it is the equation tag. -/
  tag : Bool
  deriving Inhabited, Repr

/-- A line of a formula that `\\` or `\newline` breaks: its items (a range of `items`), its
width, and its height and depth (those of its parts). -/
structure Line where
  /-- The first item. -/
  start : Nat
  /-- One past the last item. -/
  stop : Nat
  /-- Width. -/
  width : Em
  /-- Height above the baseline. -/
  height : Em
  /-- Depth below the baseline. -/
  depth : Em
  deriving Inhabited, Repr

/-- A formula laid out as positioned drawing operations (see the module docstring). -/
structure DisplayList where
  /-- The advance width. -/
  width : Em := 0
  /-- The extent above the baseline. -/
  height : Em := 0
  /-- The extent below the baseline. -/
  depth : Em := 0
  /-- The drawing operations. -/
  items : Array Item := #[]
  /-- The rectangles of the parse nodes, outermost first. -/
  regions : Array Region := #[]
  /-- The unbreakable parts. -/
  parts : Array Part := #[]
  /-- The lines; one unless the formula breaks lines with `\\` or `\newline`. -/
  lines : Array Line := #[]
  deriving Inhabited

/-- An item moved by `(dx, dy)`. -/
def Item.shift (dx dy : Em) : Item → Item
  | .glyph f c x y s e sh col src => .glyph f c (x + dx) (y + dy) s e sh col src
  | .rule x y w h col src => .rule (x + dx) (y + dy) w h col src
  | .path d vb par x y w h clip col src =>
    .path d vb par (x + dx) (y + dy) w h
      (clip.map fun (cx, cy, cw, ch) => (cx + dx, cy + dy, cw, ch)) col src

namespace Display

/-- Horizontal alignment of the lines of a block (CSS `text-align`). -/
inductive Align where
  /-- Left. -/
  | left
  /-- Centred. -/
  | center
  /-- Right. -/
  | right
  deriving BEq, Inhabited

/-- The inherited CSS state of an element. -/
structure Ctx where
  /-- Font size, in em of the formula. -/
  scale : Em := 1
  /-- The font face the element's text is in. -/
  face : Face := {}
  /-- The colour. -/
  color : Option String := none
  /-- `text-align`. -/
  align : Align := .left
  /-- The source range of the innermost enclosing parse node. -/
  source : Option SourceRange := none
  deriving Inhabited

/-- A laid-out element: its advance width (margins excluded), its left and right margins, and
its items and regions relative to its own baseline origin. -/
structure Laid where
  /-- Advance width, margins excluded. -/
  width : Em := 0
  /-- Left margin. -/
  marginLeft : Em := 0
  /-- Right margin. -/
  marginRight : Em := 0
  /-- The items. -/
  items : Array Item := #[]
  /-- The regions. -/
  regions : Array Region := #[]
  /-- The unbreakable parts (only for the formula's top-level span). -/
  parts : Array Part := #[]
  /-- The lines (only for the formula's top-level span). -/
  lines : Array Line := #[]
  deriving Inhabited

/-- Items and regions moved by `(dx, dy)`. -/
def Laid.shift (l : Laid) (dx dy : Em) : Array Item × Array Region :=
  (l.items.map (Item.shift dx dy),
   l.regions.map fun r => { r with x := r.x + dx, y := r.y + dy })

/-- The source range of a location. -/
def sourceOf : OLoc → Option SourceRange
  | .at l => some (l.start, l.stop)
  | _ => none

/-- KaTeX's size multipliers, sizes 1 to 11. -/
def sizeMultiplier (n : Nat) : Em :=
  #[(0.5 : Em), 0.6, 0.7, 0.8, 0.9, 1.0, 1.2, 1.44, 1.728, 2.074, 2.488][n - 1]?.getD 1

/-- The font size factor of a `katex-sizing reset-sizeA sizeB` element: B's multiplier over
A's. -/
def sizingFactor (classes : Array String) : Option Em := do
  if !(classes.contains "katex-sizing" || classes.contains "fontsize-ensurer") then none
  let a ← classes.findSome? fun c =>
    if c.startsWith "reset-size" then (c.drop 10).toString.toNat? else none
  let b ← classes.findSome? fun c =>
    if c.startsWith "size" then (c.drop 4).toString.toNat? else none
  return sizeMultiplier b / sizeMultiplier a

/-- The font rules of `katex.scss` with one class, in the style sheet's order: the class and
what it sets (family, weight, style). -/
def fontRules : Array (String × Option String × Option Bool × Option Bool) := #[
  ("textbf", none, some true, none), ("textit", none, none, some true),
  ("textrm", some "Main", none, none), ("textsf", some "SansSerif", none, none),
  ("texttt", some "Typewriter", none, none), ("mathnormal", some "Math", none, some true),
  ("mathit", some "Main", none, some true), ("mathrm", none, none, some false),
  ("mathbf", some "Main", some true, none), ("boldsymbol", some "Math", some true, some true),
  ("amsrm", some "AMS", none, none), ("mathbb", some "AMS", none, none),
  ("textbb", some "AMS", none, none), ("mathcal", some "Caligraphic", none, none),
  ("mathfrak", some "Fraktur", none, none), ("textfrak", some "Fraktur", none, none),
  ("mathboldfrak", some "Fraktur", some true, none),
  ("textboldfrak", some "Fraktur", some true, none), ("mathtt", some "Typewriter", none, none),
  ("mathscr", some "Script", none, none), ("textscr", some "Script", none, none),
  ("mathsf", some "SansSerif", none, none), ("textsf", some "SansSerif", none, none),
  ("mathboldsf", some "SansSerif", some true, none),
  ("textboldsf", some "SansSerif", some true, none),
  ("mathsfit", some "SansSerif", none, some true),
  ("mathitsf", some "SansSerif", none, some true),
  ("textitsf", some "SansSerif", none, some true), ("mainrm", some "Main", none, some false)]

/-- The face of an element from its classes and its parent's face and classes. -/
def faceOf (classes parentClasses : Array String) (inMult : Bool) (parent : Face) : Face :=
  Id.run do
    let mut f := parent
    for (c, fam, w, s) in fontRules do
      if classes.contains c then
        if let some x := fam then f := { f with family := x }
        if let some x := w then f := { f with bold := x }
        if let some x := s then f := { f with italic := x }
    -- rules with two or more classes (higher specificity) come last
    if classes.contains "delimsizing" then
      for n in [1:5] do
        if classes.contains s!"size{n}" then f := { f with family := s!"Size{n}" }
    if classes.contains "op-symbol" then
      if classes.contains "small-op" then f := { f with family := "Size1" }
      if classes.contains "large-op" then f := { f with family := "Size2" }
    if inMult && parentClasses.contains "delim-size1" then f := { f with family := "Size1" }
    if inMult && parentClasses.contains "delim-size4" then f := { f with family := "Size4" }
    return f

/-- The CSS length of a style property in em of the element's font size, as a length of the
formula. -/
def styleEm (b : Box) (key : String) (scale : Em) : Option Em :=
  match b.style.get? key with
  | some (.em x) => some (x * scale)
  | some (.str s) => match CssValue.ofText s with
    | .em x => some (x * scale)
    | _ => none
  | none => none

/-- The data of one of KaTeX's named SVG paths. -/
def svgPathData (name : String) : Option String :=
  (Data.svgPathList.find? (·.1 == name)).map (·.2)

/-- The advances of the characters of KaTeX's fonts, as the fonts give them, by face name and
code point. -/
def advances : Std.HashMap String (Std.HashMap Nat Em) := Id.run do
  let mut out := {}
  for (face, flat) in Data.fontAdvanceTables do
    let mut m : Std.HashMap Nat Em := {}
    for i in [0:flat.size / 2] do
      m := m.insert flat[2 * i]! (Em.ofRatio flat[2 * i + 1]! 1000)
    out := out.insert face m
  return out

/-- The advance of one character of a face, and whether the character is the face's own: the
font's advance, or the metric width, or for a character the face does not have KaTeX's
stand-in (the metrics of a look-alike, or of `M` for a character of another script), or
zero. A character of KaTeX's metric table that the font does not have is not the face's
own. -/
def charWidth (face : Face) (c : Char) : Em × Bool :=
  match (advances[face.name]?).bind (·[c.val.toNat]?) with
  | some w => (w, true)
  | none =>
    -- a character of the metric table that the font itself lacks is drawn from a fallback
    let inFont := !(advances.contains face.name)
    match (Metrics.table[face.name]?).bind (·[utf16First c]?) with
    | some m => (m.width, inFont)
    | none => (((charMetrics c.toString face.name .text).map (·.width)).getD 0, false)

/-- Spans that are as wide as their containing block (`width: 100%`) and drawn as a rule from
their bottom border. -/
def isFullWidthRule (b : Box) : Bool :=
  ["frac-line", "overline-line", "underline-line", "katex-hline", "katex-hdashline"].any
    b.hasClass

/-- Whether a box holds an SVG image. -/
def hasSvgChild (b : Box) : Bool := b.children.any (·.kind matches .svg _)

/-- Spans as wide as their containing block (`width: 100%`): the clipping span of a single
stretchy image or a surd, and the span of a multi-piece image. -/
def fillsWidth (b : Box) : Bool := b.hasClass "hide-tail" || b.hasClass "katex-stretchy"

/-- An element's `min-width`. -/
def minWidthOf (b : Box) (scale : Em) : Em :=
  match b.style.get? "minWidth" with
  | some (.em x) => x * scale
  | some (.str s) => match CssValue.ofText s with
    | .em x => x * scale
    | _ => 0
  | none => 0

/-- The left end and width of a piece of a multi-piece stretchy image within the image's width
(`halfarrow-left`, `brace-center`, …: KaTeX's percentages of the width). -/
def pieceRect (piece : Box) (w : Em) : Em × Em :=
  let pct (n : Int) : Em := Em.mk (Em.roundDiv (w.raw * n) 1000)
  if piece.hasClass "halfarrow-left" then (0, pct 502)
  else if piece.hasClass "halfarrow-right" then (w - pct 502, pct 502)
  else if piece.hasClass "brace-left" then (0, pct 251)
  else if piece.hasClass "brace-center" then (pct 250, pct 500)
  else if piece.hasClass "brace-right" then (w - pct 251, pct 251)
  else (0, w)

/-- The paths of the SVG images of a span, drawn into the rectangle given. -/
def svgItems (b : Box) (x y w h : Em) (clip : Option (Em × Em × Em × Em))
    (color : Option String) (source : Option SourceRange) : Array Item :=
  (b.children.filter (·.kind matches .svg _)).flatMap fun svg =>
    let attr (k : String) := ((svg.attrs.find? (·.1 == k)).map (·.2)).getD ""
    match svg.kind with
    | .svg paths => paths.filterMap fun
      | .path name alt =>
        some (Item.path ((alt.orElse fun _ => svgPathData name).getD name) (attr "viewBox")
          (attr "preserveAspectRatio") x y w h clip color source)
      | .line _ => none
    | _ => #[]

/-- Place children side by side, each at its left margin, from `x = 0`. -/
def flow (laid : Array Laid) : Laid := Id.run do
  let mut x : Em := 0
  let mut items := #[]
  let mut regions := #[]
  for l in laid do
    x := x + l.marginLeft
    let (is, rs) := l.shift x 0
    items := items ++ is
    regions := regions ++ rs
    x := x + l.width + l.marginRight
  return { width := x, items, regions }

/-- Lay out a box in its parent's context; `inMult` tells whether it is inside a stacked
delimiter's `delimsizing mult` span (whose pieces take their face from the parent's class);
`cb` is the width of the containing block, for elements as wide as it; `fuel` bounds the
depth. -/
def lay : Nat → Box → Ctx → Array String → Bool → Option Em → Laid
  | 0, _, _, _, _, _ => {}
  | fuel + 1, b, parent, parentClasses, inMult, cb => Id.run do
    -- the element's own context
    let scale := match sizingFactor b.classes with
      | some k => parent.scale * k
      | none => parent.scale
    let face := faceOf b.classes parentClasses inMult parent.face
    let color := match b.style.get? "color" with
      | some v => some v.text
      | none => parent.color
    let source := (sourceOf b.loc).orElse fun _ => parent.source
    let align := if b.hasClass "msupsub" || b.hasClass "svg-align" then Align.left
      else if ["x-arrow", "mover", "munder"].any b.hasClass then .center
      else parent.align
    let ctx : Ctx := { scale, face, color, align, source }
    let inMult := inMult || (b.hasClass "delimsizing" && b.hasClass "mult")
    let ml := (styleEm b "marginLeft" scale).getD 0
    let mr := (styleEm b "marginRight" scale).getD 0
    let visible := color != some "transparent"
    -- positioned elements: `top`, `left` move the drawing, not the flow
    let dx := (styleEm b "left" scale).getD 0
    let dy := ((styleEm b "top" scale).getD 0) -
      ((styleEm b "verticalAlign" scale).getD 0) -
      (if b.hasClass "katex-rule" then 0 else (styleEm b "bottom" scale).getD 0)
    let region (w : Em) : Array Region := match sourceOf b.loc with
      | some src =>
        if b.isFragment then #[]
        else #[{ x := 0, y := 0, width := w, height := b.height * parent.scale,
                 depth := b.depth * parent.scale, source := src }]
      | none => #[]
    let finish (l : Laid) : Laid :=
      let (is, rs) := l.shift dx dy
      { l with marginLeft := ml, marginRight := mr, items := is,
               regions := region l.width ++ rs }
    match b.kind with
    | .symbol text _ =>
      -- a symbol with a style is a span: `padding-left` (the radicand of `\sqrt`) comes first
      let padL := (styleEm b "paddingLeft" scale).getD 0
      let mut x : Em := padL
      let mut items := #[]
      for c in text.toList do
        let (w, exact) := charWidth face c
        if visible && c != '\u200b' then
          items := items.push (.glyph face c x 0 scale exact false color source)
        x := x + w * scale
      -- KaTeX writes the italic correction as `margin-right`, before the node's own style
      let italic := b.italicOr0
      let mr := if b.style.get? "marginRight" |>.isSome then mr
        else if italic > 0 then italic * scale else 0
      let (is, _) := ({ items } : Laid).shift dx dy
      return { width := x, marginLeft := ml, marginRight := mr, items := is,
               regions := region x }
    | .svg _ => return {}
    | .img .. => return finish { width := (styleEm b "width" scale).getD 0 }
    | _ =>
      if b.hasClass "nulldelimiter" then return finish { width := 0.12 * scale }
      if b.hasClass "vlist-s" then return {}
      if isFullWidthRule b then
        let w := cb.getD 0
        let h := (styleEm b "borderBottomWidth" scale).getD 0
        let items := if visible then #[Item.rule 0 (-h) w h color source] else #[]
        return finish { width := w, items }
      if b.hasClass "katex-rule" then
        -- an empty inline block whose borders are the rule, raised by `bottom`
        let w := (styleEm b "borderRightWidth" scale).getD 0
        let h := (styleEm b "borderTopWidth" scale).getD 0
        let up := (styleEm b "bottom" scale).getD 0
        let items := if visible then #[Item.rule 0 (-h - up) w h color source] else #[]
        return finish { width := w, items }
      if hasSvgChild b then
        -- a span with an SVG image as wide as its containing block (`svg { width: 100% }`)
        let w := (styleEm b "width" scale).getD
          (if fillsWidth b then max (cb.getD 0) (minWidthOf b scale) else 0)
        let iw := if fillsWidth b || (styleEm b "width" scale).isSome then w else cb.getD 0
        let h := (styleEm b "height" scale).getD 0
        let clip := if b.hasClass "hide-tail" then some ((0 : Em), -h, iw, h) else none
        let items := if visible then svgItems b 0 (-h) iw h clip color source else #[]
        return finish { width := w, items }
      if b.hasClass "katex-stretchy" then
        -- the pieces of a stretchy image, each clipped to its share of the width
        let w := max (cb.getD 0) (minWidthOf b scale)
        let mut items := #[]
        for piece in b.children do
          let h := (styleEm piece "height" scale).getD 0
          let (px, pw) := pieceRect piece w
          let clip := some (px, -h, pw, h)
          if visible then items := items ++ svgItems piece px (-h) pw h clip color source
        return finish { width := w, items }
      if b.hasClass "vlist-t" then
        -- the first row's `vlist` cell holds the elements; the second row only the depth
        let some row := b.children[0]? | return finish {}
        let some cell := row.children[0]? | return finish {}
        let wraps := cell.children
        -- first pass: lay out the elements, find the cell's width
        let mut laidOut : Array (Box × Box × Laid × Em × Em × Em) := #[]
        let mut cellWidth : Em := 0
        for w in wraps do
          let wml := (styleEm w "marginLeft" scale).getD 0
          let wmr := (styleEm w "marginRight" scale).getD 0
          let top := (styleEm w "top" scale).getD 0
          let pstrut := ((w.children[0]?).bind fun p => styleEm p "height" scale).getD 0
          let some elem := w.children[1]? | continue
          let wctx := if w.hasClass "svg-align" then { ctx with align := .left } else ctx
          let l := lay fuel elem wctx w.classes inMult none
          -- the elements of a vertical list are inline blocks, never narrower than nothing
          let l := { l with width := max 0 l.width }
          -- an element as wide as the list adds only its least width
          let lw := if isFullWidthRule elem || fillsWidth elem then minWidthOf elem scale
            else l.marginLeft + l.width + l.marginRight
          cellWidth := max cellWidth (lw + wml + wmr)
          laidOut := laidOut.push (w, elem, l, wml, wmr, top + pstrut)
        -- second pass: place them, re-laying those that depend on the cell's width
        let mut items := #[]
        let mut regions := #[]
        for (w, elem, l0, wml, wmr, baseline) in laidOut do
          let inner := cellWidth - wml - wmr
          let wctx := if w.hasClass "svg-align" then { ctx with align := .left } else ctx
          let l := if isFullWidthRule elem || fillsWidth elem || hasSvgChild elem then
              lay fuel elem wctx w.classes inMult (some inner)
            else l0
          let l := { l with width := max 0 l.width }
          let lineWidth := l.marginLeft + l.width + l.marginRight
          let offset := match wctx.align with
            | .left => 0
            | .center => Em.mk (Em.roundDiv (inner - lineWidth).raw 2)
            | .right => inner - lineWidth
          let (is, rs) := l.shift (wml + offset + l.marginLeft) baseline
          items := items ++ is
          regions := regions ++ rs
        return finish { width := cellWidth, items, regions }
      if b.hasClass "llap" || b.hasClass "rlap" || b.hasClass "clap" then
        -- no width; the absolutely placed `katex-inner` ends (llap), starts (rlap) or is
        -- centred (clap) at the left end
        let mut items := #[]
        let mut regions := #[]
        for c in b.children do
          if c.hasClass "katex-inner" then
            let l := lay fuel c ctx b.classes inMult cb
            let w := l.marginLeft + l.width + l.marginRight
            let off := if b.hasClass "llap" then -w
              else if b.hasClass "clap" then -Em.mk (Em.roundDiv w.raw 2) else 0
            let (is, rs) := l.shift (off + l.marginLeft) 0
            items := items ++ is
            regions := regions ++ rs
        return finish { width := 0, items, regions }
      -- inline flow; text-align for the rows of a fraction and the tables of limits
      let mut laid := #[]
      for c in b.children do
        let childCtx := if b.hasClass "mfrac" then { ctx with align := .center } else ctx
        let childCtx := if b.hasClass "op-limits" || b.hasClass "katex-accent" ||
            b.classes.any (·.startsWith "col-align-") then
            { childCtx with align := match b.classes.find? (·.startsWith "col-align-") with
              | some "col-align-l" => .left
              | some "col-align-r" => .right
              | _ => .center }
          else childCtx
        laid := laid.push (lay fuel c childCtx b.classes inMult cb)
      let fl := flow laid
      let padL := (styleEm b "paddingLeft" scale).getD 0
      let contentWidth := padL + fl.width
      -- inline blocks are never narrower than nothing, nor than their `min-width`
      let width := (styleEm b "width" scale).getD
        (if b.hasClass "katex-base" then max 0 contentWidth else contentWidth)
      let width := if b.hasClass "katex-thinbox" then 0
        else if b.hasClass "accent-body" && !b.hasClass "accent-full" then 0
        else if b.style.get? "minWidth" |>.isSome then max width (minWidthOf b scale)
        else width
      -- the index of a root sits 5 mu right and overlaps the surd by 10 mu
      let (ml, mr) := if b.hasClass "katex-root" && parentClasses.contains "sqrt" then
          (Em.ofRatio 5 18 * scale, Em.ofRatio (-10) 18 * scale)
        else (ml, mr)
      let (items, regions) := ({ fl with } : Laid).shift padL 0
      -- `\pmb`'s shadow: a copy of the glyphs, offset, painted first
      let items := match b.style.get? "textShadow" with
        | some _ =>
          let shadow := items.filterMap fun
            | .glyph f c x y sz e _ col src =>
              some (Item.glyph f c (x + 0.02 * scale) (y + 0.01 * scale) sz e true col src)
            | _ => none
          shadow ++ items
        | none => items
      if b.hasClass "katex-html" then
        -- the top-level spans are the unbreakable parts; a `katex-newline` starts a new line,
        -- whose items are relative to its own baseline and left end
        let mut x : Em := 0
        let mut line := 0
        let mut items := #[]
        let mut regions := #[]
        let mut parts := #[]
        let mut lines := #[]
        let mut start := 0
        let mut lh : Em := 0
        let mut ld : Em := 0
        for (c, l) in b.children.zip laid do
          if c.hasClass "katex-newline" then
            lines := lines.push { start, stop := items.size, width := x, height := lh, depth := ld }
            start := items.size
            x := 0
            lh := 0
            ld := 0
            line := line + 1
            continue
          x := x + l.marginLeft
          let (is, rs) := l.shift x 0
          items := items ++ is
          regions := regions ++ rs
          if c.hasClass "katex-base" || c.hasClass "katex-tag" then
            parts := parts.push { x, width := l.width, line, tag := c.hasClass "katex-tag" }
          lh := max lh (c.height * scale)
          ld := max ld (c.depth * scale)
          x := x + l.width + l.marginRight
        lines := lines.push { start, stop := items.size, width := x, height := lh, depth := ld }
        let width := lines.foldl (fun m (ln : Line) => max m ln.width) 0
        return { width, items, regions, parts, lines }
      let l := finish { width, items, regions }
      return { l with marginLeft := ml, marginRight := mr }

/-- The nesting depth the evaluation follows. -/
def fuel : Nat := 1 <<< 20

end Display

/-- KaTeX's twenty font faces, by file name. -/
def Face.katexFaces : List String :=
  ["AMS-Regular", "Caligraphic-Bold", "Caligraphic-Regular", "Fraktur-Bold", "Fraktur-Regular",
   "Main-Bold", "Main-BoldItalic", "Main-Italic", "Main-Regular", "Math-BoldItalic",
   "Math-Italic", "SansSerif-Bold", "SansSerif-Italic", "SansSerif-Regular", "Script-Regular",
   "Size1-Regular", "Size2-Regular", "Size3-Regular", "Size4-Regular", "Typewriter-Regular"]

/-- Whether a display list keeps the invariants of the module docstring: every glyph in one of
KaTeX's faces at a positive size, rules and path rectangles of non-negative size, and the lines
a partition of the items into consecutive ranges. -/
def DisplayList.wellFormed (d : DisplayList) : Bool :=
  let itemsOk := d.items.all fun
    | .glyph f _ _ _ size _ _ _ _ => Face.katexFaces.contains f.name && size > 0
    | .rule _ _ w h _ _ => w ≥ 0 && h ≥ 0
    | .path _ _ _ _ _ w h _ _ _ => w ≥ 0 && h ≥ 0
  let (linesOk, next) := d.lines.foldl (init := (true, 0)) fun (ok, k) ln =>
    (ok && ln.start == k && ln.start ≤ ln.stop, ln.stop)
  itemsOk && linesOk && next == d.items.size && !d.lines.isEmpty

/-- The `katex-html` span of a box tree (the `katex` span, or `katex-display` around it). -/
def Display.htmlOf (b : Box) : Box := Id.run do
  let mut html := b
  for _ in [0:3] do
    if html.hasClass "katex-html" then break
    match html.children[0]? with
    | some c => html := c
    | none => break
  return html

/-- The display list of a box tree (the `katex` span, or `katex-display` around it). In display
mode the material is centred within its own width, as KaTeX's display style centres every
table cell. -/
def DisplayList.ofBox (b : Box) : DisplayList :=
  let display := b.hasClass "katex-display"
  let html := Display.htmlOf b
  let l := Display.lay Display.fuel html { align := if display then .center else .left } #[]
    false none
  -- a box without `katex-html` (KaTeX's error box for a rejected formula) is one line
  let lines := if l.lines.isEmpty then
      #[{ start := 0, stop := l.items.size, width := l.width, height := html.height,
          depth := html.depth }]
    else l.lines
  { width := l.width, height := html.height, depth := html.depth, items := l.items,
    regions := l.regions, parts := l.parts, lines }

end LeAnTeX
