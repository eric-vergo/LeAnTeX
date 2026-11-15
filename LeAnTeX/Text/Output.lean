/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Text.Typeset
import LeAnTeX.OpenType.Display

/-!
# Set text as a display list

A typeset `Document` as LeAnTeX's display list (`LeAnTeX.DisplayList`), so that a back end
draws text and formulas with the same items:

* **Units.** The display list's em is ten points, so an `Em`'s raw value is a length in TeX's
  scaled points.
* **Lines.** Each line of the document is a `Line` of the display list: its items relative to
  its own left end and baseline, as for a formula's lines; `Line.x` is its indentation and
  `Line.y` its baseline below the first line's. The list's `width` is the text's width, its
  `height` the first line's height and its `depth` the distance from the first baseline to the
  bottom of the last line.
* **Glyphs.** A glyph is a glyph item whose `Face.font` names the font (as the caller's
  `FontResolver` named it), at the font's size; a back end maps the character to the glyph
  through that font's character map. A glyph no character maps to (a ligature of a font without
  a code point for it) is drawn as its outline, a path item, so that nothing depends on the
  back end finding it.
* **Glue** is set as TeX sets it when it ships a line out: each glue's stretch or shrink in
  proportion to the line's glue ratio, rounded so that the rounding does not accumulate along the
  line (TeX's `hlist_out`).
* **Boxes** are drawn in place, **rules** as rule items, **formulas** as the math layout's
  items scaled to the font size, and a discretionary not broken at by its unbroken text.

## Main definitions

* `Document.toDisplayList`.
* `DisplayList.textForm`: a stable text form of a display list, one item per line.
-/

namespace LeAnTeX.Text

/-- An item scaled by `k / 655360` and moved by `(dx, dy)` (a formula's item, laid out in em
of the formula, placed at a font size of `k` sp). -/
def scaleItem (k : Int) (dx dy : Int) : Item → Item
  | .glyph f c x y s e sh col src => .glyph f c (sc x + ⟨dx⟩) (sc y + ⟨dy⟩) (sc s) e sh col src
  | .rule x y w h col src => .rule (sc x + ⟨dx⟩) (sc y + ⟨dy⟩) (sc w) (sc h) col src
  | .path d vb par x y w h clip col src =>
    .path d vb par (sc x + ⟨dx⟩) (sc y + ⟨dy⟩) (sc w) (sc h)
      (clip.map fun (cx, cy, cw, ch) => (sc cx + ⟨dx⟩, sc cy + ⟨dy⟩, sc cw, sc ch)) col src
where
  /-- A length scaled. -/
  sc (e : Em) : Em := ⟨Em.roundDiv (e.raw * k) Em.unit⟩

/-- The items of a list of nodes set with glue `g` from `x0` on the baseline `y`, appended to
`acc`, with the formulas among them (their item ranges counted from `base`, the number of items
before `acc`'s): TeX's `hlist_out`; boxes nested deeper than `fuel` are left out. -/
def placeNodes (fonts : Array (FontInfo × Int)) (fuel : Nat) (nodes : Array HNode)
    (g : GlueSet) (x0 y : Int) (base : Nat := 0)
    (acc : Array Item × Array Formula := (#[], #[])) : Array Item × Array Formula := Id.run do
  let mut (out, forms) := acc
  let mut x := x0
  let mut curG : Int := 0
  let mut curGlue : Float := 0
  for n in nodes do
    match n with
    | .glyph c gid w _ _ f =>
      match fonts[f]? with
      | some (info, size) =>
        if info.glyphOf c == gid then
          let face : Face :=
            { font := some info.name, family := info.name, slant := info.slant,
              smallCaps := info.smallCaps }
          out := out.push (.glyph face c ⟨x⟩ ⟨y⟩ ⟨size⟩ true false none none)
        else
          match info.font.glyphItem gid ⟨x⟩ ⟨y⟩ ⟨size⟩ with
          | .ok (some it) => out := out.push it
          | _ => pure ()
      | none => pure ()
      x := x + w
    | .glue gl _ =>
      let mut w := gl.width - curG
      if g.sign == 1 && gl.stretchOrder == g.order then
        curGlue := curGlue + Float.ofInt gl.stretch
        curG := roundFloat (g.ratio * curGlue)
      else if g.sign == 2 && gl.shrinkOrder == g.order then
        curGlue := curGlue - Float.ofInt gl.shrink
        curG := roundFloat (g.ratio * curGlue)
      w := w + curG
      x := x + w
    | .rule w h d =>
      out := out.push (.rule ⟨x⟩ ⟨y - h⟩ ⟨w⟩ ⟨h + d⟩ none none); x := x + w
    | .box w _ _ s content =>
      match fuel with
      | 0 => pure ()
      | fuel + 1 => (out, forms) := placeNodes fonts fuel content {} x (y + s) base (out, forms)
      x := x + w
    | .math w h d dl size =>
      let start := base + out.size
      out := out ++ dl.items.map (scaleItem size x y)
      let (src, disp) := match dl.formulas[0]? with
        | some f => (f.source, f.display)
        | none => ("", false)
      -- fields in order: the item range, the box, the source and display flag
      forms := forms.push ⟨start, base + out.size, ⟨x⟩, ⟨y⟩, ⟨w⟩, ⟨h⟩, ⟨d⟩, src, disp⟩
      x := x + w
    | .disc _ _ _ r _ =>
      match fuel with
      | 0 => pure ()
      | fuel + 1 => (out, forms) := placeNodes fonts fuel r {} x y base (out, forms)
      x := x + listWidth r
    | n => x := x + n.width
  return (out, forms)
where
  /-- A float rounded to the nearest integer, within ±2³⁰ (TeX's `vet_glue` bound). -/
  roundFloat (v : Float) : Int :=
    let v := if v > 1073741823 then 1073741823 else if v < -1073741823 then -1073741823 else v
    let r := (v.abs + 0.5).floor
    let n : Int := r.toUInt64.toNat
    if v < 0 then -n else n

/-- The document as a display list (see the module docstring). -/
def Document.toDisplayList (d : Document) : DisplayList := Id.run do
  let mut items : Array Item := #[]
  let mut formulas : Array Formula := #[]
  let mut lines : Array LeAnTeX.Line := #[]
  let y0 := (d.lines[0]?.map (·.2)).getD 0
  for (l, y) in d.lines do
    let start := items.size
    let (its, fs) := placeNodes d.fonts 64 l.nodes l.glue 0 0 start
    items := items ++ its
    formulas := formulas ++ fs
    let line : LeAnTeX.Line :=
      { start, stop := items.size, width := ⟨l.width⟩, height := ⟨l.height⟩,
        depth := ⟨l.depth⟩, x := ⟨l.indent⟩, y := ⟨y - y0⟩ }
    lines := lines.push line
  let height := (d.lines[0]?.map (·.1.height)).getD 0
  let depth := (d.lines.back?.map fun (l, y) => y - y0 + l.depth).getD 0
  return { width := ⟨d.width⟩, height := ⟨height⟩, depth := ⟨depth⟩, items, lines, formulas }

/-- A display list as text: a header line with its extent, then per line its range, extent and
position, then its items, one per line, every length in sp (`Em.raw`). Stable across runs and
machines. -/
def _root_.LeAnTeX.DisplayList.textForm (dl : DisplayList) : String := Id.run do
  let mut out := s!"display width {dl.width.raw} height {dl.height.raw} depth {dl.depth.raw}\n"
  let item := fun (it : Item) => match it with
    | .glyph f c x y s _ _ col _ =>
      s!"  glyph {f.name} {s.raw} {x.raw} {y.raw} U+{hex c.toNat}{colorText col}"
    | .rule x y w h col _ => s!"  rule {x.raw} {y.raw} {w.raw} {h.raw}{colorText col}"
    | .path data vb _ x y w h _ col _ =>
      s!"  path {x.raw} {y.raw} {w.raw} {h.raw} viewBox {vb} d {data}{colorText col}"
  let whole : LeAnTeX.Line :=
    { start := 0, stop := dl.items.size, width := dl.width, height := dl.height,
      depth := dl.depth }
  let ranges := if dl.lines.isEmpty then #[whole] else dl.lines
  for l in ranges do
    out := out ++ s!"line x {l.x.raw} y {l.y.raw} width {l.width.raw} height {l.height.raw} \
      depth {l.depth.raw}\n"
    for it in dl.items.extract l.start l.stop do
      out := out ++ item it ++ "\n"
  return out
where
  /-- A number in upper-case hexadecimal, at least four digits. -/
  hex (n : Nat) : String :=
    let s := String.ofList (Nat.toDigits 16 n) |>.toUpper
    String.ofList (List.replicate (4 - s.length) '0') ++ s
  /-- A colour, if any, as ` color …`. -/
  colorText : Option String → String
    | some c => " color " ++ c
    | none => ""

end LeAnTeX.Text
