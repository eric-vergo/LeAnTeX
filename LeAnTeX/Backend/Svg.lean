/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Backend.Escape
import LeAnTeX.Backend.Fonts

/-!
# The SVG back end

A display list (a paragraph of the text layer, a formula, or both) as an SVG picture that
needs nothing else: every glyph is drawn as its outline, read from the font with
`LeAnTeX.OpenType`, so the picture refers to no font file and looks the same everywhere.

* **Units.** One SVG user unit is one of TeX's points; `width` and `height` are given in CSS's
  `pt` (1/72 inch, which is 72.27/72 of TeX's point), so the picture has TeX's size. A display
  list's em is `SvgOptions.em` scaled points (ten points by default, the text layer's em; a
  formula laid out alone may be given its own size).
* **Glyphs.** Each glyph used is defined once, in `<defs>`, as a `<path>` in its font's units
  (`y` down), and drawn with `<use>` and a transformation that scales it to its size, places
  its origin, slants it (`Face.slant`) or mirrors it (`DisplayList.mirrored`). `\pmb`'s shadow
  copies are offset by (0.02 em, 0.01 em) of their size. A glyph no font of the `FontSet` has is
  not drawn.
* **Rules** are `<rect>`s; **paths** are nested `<svg>` elements with the item's `viewBox` and
  `preserveAspectRatio`, which clip to their rectangle as the display list's paths are drawn;
  an item's own clip is one more nested `<svg>`.
* **Lines.** Each line is placed at its `Line.x` and `Line.y` (the text layer's lines); the
  lines of a formula broken with `\\`, which have no position, are stacked with their height and
  depth and a gap of a fifth of an em.
* **Colour.** An item's colour, if it is a colour CSS can read (`cssColor?`), is its `fill`;
  others take the picture's colour (`SvgOptions.color`, else the SVG default, black).
* **Accessibility.** The picture has `role="img"`, a `<title>` (`SvgOptions.title`: the source
  text by default) and a `<desc>`.
* **Untrusted input.** Every string from TeX source or from the display list is escaped
  (`escape`); colours are checked. The bytes are a function of the display list, the fonts and
  the options, the same on every machine.

`LeAnTeX.Backend.Proofs` proves that every glyph the picture draws has its definition in it
(`refsDefined`).

## Main definitions

* `SvgOptions`, `SvgUse`, `SvgPicture`.
* `picture`: the picture's parts as values.
* `svgElement`, `svgDocument`: as an `<svg>` element and as a file.
* `glyphPathData`: a glyph outline as SVG path data.
-/

namespace LeAnTeX.Backend

open LeAnTeX.OpenType

/-- How a display list is drawn as SVG. -/
structure SvgOptions where
  /-- The length of the display list's em, in sp (ten points). -/
  em : Int := 10 * 65536
  /-- The margin around the display list's box, in sp. -/
  padding : Int := 2 * 65536
  /-- The picture's accessible name, `<title>` (the source text, typically). -/
  title : String := ""
  /-- The picture's description, `<desc>`. -/
  desc : String := "Typeset by LeAnTeX"
  /-- The colour of material without a colour of its own; `none` leaves SVG's default. -/
  color : Option String := none
  /-- The prefix of the glyph definitions' ids, for pictures that share a page. -/
  idPrefix : String := "g"
  deriving Inhabited

/-- A glyph drawn: the id of its definition, its transformation (`a b c d e f` of SVG's
`matrix`) and its colour. -/
structure SvgUse where
  /-- The id of the glyph's definition. -/
  ref : String
  /-- The transformation's six numbers, written. -/
  matrix : String
  /-- The `fill`, if any. -/
  fill : Option String
  deriving Inhabited, BEq

/-- The parts of a picture: its box (in sp: left, top, width, height), the glyph definitions
(id and path data), and the body, in painting order: glyphs drawn (`Sum.inl`) and other
elements, written (`Sum.inr`). -/
structure SvgPicture where
  /-- The box's left edge, in sp. -/
  left : Int
  /-- The box's top edge, in sp. -/
  top : Int
  /-- The width, in sp. -/
  width : Int
  /-- The height, in sp. -/
  height : Int
  /-- The glyph definitions: ids and path data. -/
  defs : Array (String × String)
  /-- The body. -/
  body : Array (SvgUse ⊕ String)
  deriving Inhabited

/-- A number of 1/65536 font units in font units with at most two decimals. -/
private def fu (v : Int) : String := fixed v 65536 2

/-- A glyph outline (in 1/65536 font units, `y` up) as SVG path data in font units with `y`
down. -/
def glyphPathData (p : Path Int) : String := Id.run do
  let pt := fun (q : Point Int) => s!"{fu q.x} {fu (-q.y)}"
  let mut out : Array String := #[]
  for c in p.cmds do
    out := out.push <| match c with
      | .move q => "M" ++ pt q
      | .line q => "L" ++ pt q
      | .quad a q => s!"Q{pt a} {pt q}"
      | .cubic a b q => s!"C{pt a} {pt b} {pt q}"
      | .close => "Z"
  return String.join out.toList

/-- Where each line's origin is, in sp, for a display list whose em is `em` sp (see the module
docstring), with the lines themselves (one covering every item when the list has none). -/
def linePlacement (dl : DisplayList) (em : Int) : Array (LeAnTeX.Line × Int × Int) := Id.run do
  let lines := if dl.lines.isEmpty then
      #[{ start := 0, stop := dl.items.size, width := dl.width, height := dl.height,
          depth := dl.depth }]
    else dl.lines
  let stacked := lines.size > 1 && lines.all fun l => l.x.raw == 0 && l.y.raw == 0
  let mut out := #[]
  let mut y : Int := 0
  for h : i in [0:lines.size] do
    let l := lines[i]
    if stacked then
      if i > 0 then
        y := y + (lines[i - 1]?.map fun p => spOf em p.depth).getD 0 + spOf em l.height +
          em / 5
      out := out.push (l, 0, y)
    else out := out.push (l, spOf em l.x, spOf em l.y)
  return out

/-- Whether item `i` is drawn mirrored. -/
private def mirroredAt (dl : DisplayList) (i : Nat) : Bool :=
  dl.mirrored.any fun (a, b) => a ≤ i && i < b

/-- An attribute ` name="value"` with the value escaped. -/
private def attr (name value : String) : String := s!" {name}=\"{escape value}\""

/-- The `fill` attribute of an item's colour, if CSS can read it. -/
private def fillAttr (c : Option String) : String :=
  match c.bind cssColor? with
  | some c => attr "fill" c
  | none => ""

/-- Whether a body element may be written next to `defs`: a glyph whose definition is among
them, or any other element. -/
def keepElement (defs : Array (String × String)) : SvgUse ⊕ String → Bool
  | .inl u => (defs.map (·.1)).contains u.ref
  | .inr _ => true

/-- A picture from its box (left, top, width, height), its glyph definitions and its body; the
glyphs without a definition are dropped from the body (`keepElement`). -/
def SvgPicture.ofParts (box : Int × Int × Int × Int) (defs : Array (String × String))
    (body : Array (SvgUse ⊕ String)) : SvgPicture :=
  { left := box.1, top := box.2.1, width := box.2.2.1, height := box.2.2.2, defs,
    body := body.filter (keepElement defs) }

/-- The parts of the picture of a display list drawn with the fonts of `fs` (see the module
docstring): its box, its glyph definitions and its body before `SvgPicture.ofParts`. -/
def pictureParts (fs : FontSet) (dl : DisplayList) (opts : SvgOptions) :
    (Int × Int × Int × Int) × Array (String × String) × Array (SvgUse ⊕ String) := Id.run do
  let em := opts.em
  let sp := spOf em
  let placed := linePlacement dl em
  -- the glyphs used, in order of first use, each with its id
  let mut index : Std.HashMap GlyphRef String := {}
  let mut order : Array GlyphRef := #[]
  let mut fontIds : Std.HashMap String Nat := {}
  let mut body : Array (SvgUse ⊕ String) := #[]
  let mut bottom : Int := 0
  for (line, lx, ly) in placed do
    bottom := max bottom (ly + sp line.depth)
    for i in [line.start:line.stop] do
      let some it := dl.items[i]? | continue
      match it with
      | .glyph face c x y size _ shadow col _ =>
        let some r := fs.resolve face c | continue
        let id ← match index[r]? with
          | some id => pure id
          | none =>
            let fi := (fontIds[r.font]?).getD fontIds.size
            fontIds := fontIds.insert r.font fi
            let id := s!"{opts.idPrefix}{fi}-{r.glyph}"
            index := index.insert r id
            order := order.push r
            pure id
        let s := sp size
        let upem : Int := ((fs.fonts[r.font]?).map (·.unitsPerEm)).getD 1000
        let (dx, dy) := if shadow then (Em.roundDiv (s * 2) 100, Em.roundDiv s 100) else (0, 0)
        let k := fixed s (65536 * upem) 6
        let a := if mirroredAt dl i then "-" ++ k else k
        let c := fixed (-(face.slant * s)) (1000 * 65536 * upem) 6
        let m := s!"{a} 0 {c} {k} {ptText (lx + sp x + dx)} {ptText (ly + sp y + dy)}"
        body := body.push (.inl { ref := id, matrix := m, fill := col })
      | .rule x y w h col _ =>
        body := body.push (.inr s!"<rect{attr "x" (ptText (lx + sp x))}\
          {attr "y" (ptText (ly + sp y))}{attr "width" (ptText (sp w))}\
          {attr "height" (ptText (sp h))}{fillAttr col}/>")
      | .path data vb par x y w h clip col _ =>
        let (px, py) := (lx + sp x, ly + sp y)
        let inner := fun (ox oy : Int) =>
          s!"<svg{attr "x" (ptText (px - ox))}{attr "y" (ptText (py - oy))}\
            {attr "width" (ptText (sp w))}{attr "height" (ptText (sp h))}{attr "viewBox" vb}\
            {attr "preserveAspectRatio" par}><path{attr "d" data}/></svg>"
        let el := match clip with
          | some (cx, cy, cw, ch) =>
            s!"<svg{attr "x" (ptText (lx + sp cx))}{attr "y" (ptText (ly + sp cy))}\
              {attr "width" (ptText (sp cw))}{attr "height" (ptText (sp ch))}>\
              {inner (lx + sp cx) (ly + sp cy)}</svg>"
          | none => inner 0 0
        let el := if mirroredAt dl i then
            s!"<g{attr "transform" s!"matrix(-1 0 0 1 {ptText (2 * px + sp w)} 0)"}>{el}</g>"
          else el
        let el := match col.bind cssColor? with
          | some c => s!"<g{attr "fill" c}>{el}</g>"
          | none => el
        body := body.push (.inr el)
  -- the definitions of the glyphs that have outlines
  let mut defs : Array (String × String) := #[]
  for r in order do
    let some f := fs.fonts[r.font]? | continue
    let some id := index[r]? | continue
    match f.outline r.glyph with
    | .ok p => if p.cmds.size > 0 then defs := defs.push (id, glyphPathData p)
    | .error _ => pure ()
  let pad := opts.padding
  let top := -(sp dl.height) - pad
  return ((-pad, top, sp dl.width + 2 * pad, bottom - top + pad), defs, body)

/-- The picture of a display list drawn with the fonts of `fs` (see the module docstring): only
glyphs with a definition are drawn. -/
def picture (fs : FontSet) (dl : DisplayList) (opts : SvgOptions := {}) : SvgPicture :=
  let (box, defs, body) := pictureParts fs dl opts
  SvgPicture.ofParts box defs body

/-- The picture as an `<svg>` element (for a page that holds several, give each its own
`SvgOptions.idPrefix`). -/
def svgElement (fs : FontSet) (dl : DisplayList) (opts : SvgOptions := {}) : String := Id.run do
  let p := picture fs dl opts
  let mut out : Array String := #[]
  out := out.push s!"<svg xmlns=\"http://www.w3.org/2000/svg\" \
    xmlns:xlink=\"http://www.w3.org/1999/xlink\"{attr "width" (bpText p.width ++ "pt")}\
    {attr "height" (bpText p.height ++ "pt")}\
    {attr "viewBox" s!"{ptText p.left} {ptText p.top} {ptText p.width} {ptText p.height}"}\
    {match opts.color.bind cssColor? with | some c => attr "fill" c | none => ""} role=\"img\">"
  out := out.push s!"<title>{escape opts.title}</title><desc>{escape opts.desc}</desc>"
  if !p.defs.isEmpty then
    out := out.push "<defs>"
    for (id, d) in p.defs do out := out.push s!"<path{attr "id" id}{attr "d" d}/>"
    out := out.push "</defs>"
  for e in p.body do
    out := out.push <| match e with
      | .inl u => s!"<use{attr "xlink:href" ("#" ++ u.ref)}\
          {attr "transform" s!"matrix({u.matrix})"}{fillAttr u.fill}/>"
      | .inr s => s
  out := out.push "</svg>"
  return "\n".intercalate out.toList

/-- The picture as an SVG file: an XML declaration and the element. -/
def svgDocument (fs : FontSet) (dl : DisplayList) (opts : SvgOptions := {}) : String :=
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" ++ svgElement fs dl opts ++ "\n"

end LeAnTeX.Backend
