/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Backend.Svg

/-!
# The HTML back end

A display list of the text layer as HTML: the text as real text, which a reader can select,
copy and search, in the fonts it was set in, each run of glyphs at the place TeX put it, and
each formula as an inline SVG picture (`LeAnTeX.Backend.Svg`) with a text alternative.

* **Runs.** Consecutive glyphs of one font, size and colour that sit where the font's advances
  and kerning put them form a run, written as one `span` at the run's position; a gap (an
  interword space, stretched or shrunk) or any other move starts a new run, so justified and
  hyphenated lines keep TeX's positions while the browser shapes each run with the same font
  (its ligatures and kerning are those the text layer applied). A run followed by a gap of at
  least a sixth of its size ends with a space, so copied text has its spaces. A ligature
  character (`ﬁ`, `ﬂ`, …, U+FB00–U+FB06) is written as its letters, which the browser ligates
  again.
* **Units.** Lengths are written in CSS's `pt` (1/72 inch), converted from TeX's points
  (1/72.27 inch), so the text has TeX's size.
* **Baselines.** A run is placed by its baseline without knowing the font's ascent: its box is
  a baseline-aligned flex box whose first item is an empty strut two ems tall, so the box's top
  is two ems above the baseline (`.ltx-w` in the style sheet).
* **Fonts.** One `@font-face` per font used, loading the font file from `HtmlOptions.fontUrl`
  (the files of `fonts/newcomputermodern`); the page refers to no other resource. Slanted
  fonts are skewed (`transform`), small capitals use the font's `smcp` feature.
* **Formulas** (`DisplayList.formulas`) are inline SVG pictures with `role="img"`, the source
  as their `aria-label` and `<title>`, and the source again as visually hidden text, so that
  copying and searching find it. Rules and outline glyphs outside formulas are drawn by one
  SVG picture per line.
* **Policy.** The page has no script and no event handler, one style sheet (`<style>` in the
  head), and positions in `style` attributes; it works under a content security policy that
  forbids scripts and allows the page's own styles and fonts (`script-src 'none';
  style-src 'unsafe-inline'; font-src <fonts>`). Everything from TeX source is escaped.

## Main definitions

* `HtmlOptions`, `htmlFragment`, `htmlStyleSheet`, `htmlDocument`.
-/

namespace LeAnTeX.Backend

open LeAnTeX.OpenType

/-- How a display list is written as HTML. -/
structure HtmlOptions where
  /-- The length of the display list's em, in sp (ten points). -/
  em : Int := 10 * 65536
  /-- Where the font files are, as a URL prefix (a directory, without the final `/`). -/
  fontUrl : String := "fonts/newcomputermodern"
  /-- The page's title (`htmlDocument`). -/
  title : String := ""
  /-- The page's language. -/
  lang : String := "en"
  /-- The prefix of ids and classes the fragment's pictures use, for pages that hold several
  fragments. -/
  idPrefix : String := "ltx"
  deriving Inhabited

/-- A run of text: its font's name, size (sp), slant, small capitals, colour, position (sp, in
the fragment's box) and text. -/
structure HtmlRun where
  /-- The font's name. -/
  font : String
  /-- The size, in sp. -/
  size : Int
  /-- The slant, in thousandths. -/
  slant : Int
  /-- Small capitals. -/
  smallCaps : Bool
  /-- The colour, if any. -/
  color : Option String
  /-- The left end of the run's baseline. -/
  x : Int
  /-- The baseline. -/
  y : Int
  /-- The text. -/
  text : String
  deriving Inhabited

/-- A character as it is written into HTML text: ligature characters as their letters. -/
def htmlChars (c : Char) : String :=
  match c.toNat with
  | 0xFB00 => "ff" | 0xFB01 => "fi" | 0xFB02 => "fl" | 0xFB03 => "ffi" | 0xFB04 => "ffl"
  | 0xFB05 | 0xFB06 => "st"
  | _ => String.singleton c

/-- A string as a CSS string literal: quoted, with `"`, `\`, `<` and every character outside
printable ASCII as CSS escapes. -/
def cssString (s : String) : String :=
  let esc := fun (c : Char) =>
    if c.toNat < 0x20 || c.toNat > 0x7E || c == '"' || c == '\\' || c == '<' then
      "\\" ++ String.ofList (Nat.toDigits 16 c.toNat) ++ " "
    else String.singleton c
  "\"" ++ String.join (s.toList.map esc) ++ "\""

/-- The font family name a page gives a font file. -/
def familyOf (font : String) : String := "LeAnTeX " ++ (font.dropSuffix ".otf").toString

/-- The runs of text and the items of each line that are drawn as pictures (outside formulas),
for a display list drawn with the fonts of `fs`. Positions are in the fragment's box: its
left edge and the first baseline at `top` sp below its top. -/
def htmlRuns (fs : FontSet) (dl : DisplayList) (em top : Int) :
    Array HtmlRun × Array (Array Nat) := Id.run do
  let sp := spOf em
  let inFormula := fun (i : Nat) => dl.formulas.any fun f => f.start ≤ i && i < f.stop
  let mut runs : Array HtmlRun := #[]
  let mut others : Array (Array Nat) := #[]
  for (line, lx, ly) in linePlacement dl em do
    let mut cur : Option (HtmlRun × Int) := none
    let mut rest : Array Nat := #[]
    for i in [line.start:line.stop] do
      if inFormula i then continue
      let some it := dl.items[i]? | continue
      match it with
      | .glyph face c x y size _ false col _ =>
        let some name := face.font | rest := rest.push i; continue
        let some r := fs.resolve face c | continue
        if r.font != name then rest := rest.push i; continue
        let some f := fs.fonts[name]? | continue
        let s := sp size
        let gx := lx + sp x
        let gy := top + ly + sp y
        let adv := Em.roundDiv ((f.advance r.glyph : Int) * s) f.unitsPerEm
        let fresh : HtmlRun := ⟨name, s, face.slant, face.smallCaps, col, gx, gy, htmlChars c⟩
        match cur with
        | some (run, endX) =>
          if run.font == name && run.size == s && run.color == col && run.y == gy &&
              run.slant == face.slant && run.smallCaps == face.smallCaps && endX == gx then
            cur := some ({ run with text := run.text ++ htmlChars c }, gx + adv)
          else
            let gap := gx - endX
            runs := runs.push <|
              if gap ≥ run.size / 6 && run.y == gy then { run with text := run.text ++ " " }
              else run
            cur := some (fresh, gx + adv)
        | none => cur := some (fresh, gx + adv)
        -- the kerning to the next glyph moves where the next one is expected
        if let some (run, endX) := cur then
          match dl.items[i + 1]? with
          | some (.glyph f2 c2 _ _ _ _ _ _ _) =>
            if let some r2 := fs.resolve f2 c2 then
              if r2.font == name then
                let k := Em.roundDiv (f.kerning r.glyph r2.glyph * s) f.unitsPerEm
                cur := some (run, endX + k)
          | _ => pure ()
      | .glyph .. => pure ()
      | _ => rest := rest.push i
    if let some (r, _) := cur then runs := runs.push r
    others := others.push rest
  return (runs, others)

/-- The fonts the runs use, in order of first use. -/
private def runFonts (runs : Array HtmlRun) : Array String :=
  runs.foldl (fun acc r => if acc.contains r.font then acc else acc.push r.font) #[]

/-- The style sheet of a fragment whose runs use `fonts`: the `@font-face` rules and the
classes of `htmlFragment`. -/
def htmlStyleSheet (fonts : Array String) (opts : HtmlOptions := {}) : String := Id.run do
  let p := opts.idPrefix
  let mut out : Array String := #[]
  for f in fonts do
    out := out.push s!"@font-face \{ font-family: {cssString (familyOf f)}; \
      src: url({cssString (opts.fontUrl ++ "/" ++ f)}) format(\"opentype\"); }"
  for h : i in [0:fonts.size] do
    out := out.push s!".{p}-f{i} \{ font-family: {cssString (familyOf fonts[i])}, serif; }"
  out := out ++ #[
    s!".{p} \{ position: relative; margin: 1em 0; color: inherit; }",
    s!".{p}-w \{ position: absolute; display: inline-flex; align-items: baseline; \
      margin-top: -2em; white-space: pre; line-height: 1; font-kerning: normal; \
      font-variant-ligatures: common-ligatures; transform-origin: 0 2em; }",
    s!".{p}-w::before \{ content: \"\"; height: 2em; }",
    s!".{p}-m, .{p}-g \{ position: absolute; overflow: visible; }",
    s!".{p}-a \{ position: absolute; width: 1px; height: 1px; overflow: hidden; \
      clip-path: inset(50%); white-space: nowrap; }"]
  return "\n".intercalate out.toList

/-- The display list as an HTML fragment (a `div`) and the fonts it uses (for
`htmlStyleSheet`): see the module docstring. -/
def htmlFragment (fs : FontSet) (dl : DisplayList) (opts : HtmlOptions := {}) :
    String × Array String := Id.run do
  let p := opts.idPrefix
  let em := opts.em
  let sp := spOf em
  let top := sp dl.height
  let placed := linePlacement dl em
  let bottom := placed.foldl (fun acc (l, _, ly) => max acc (top + ly + sp l.depth)) top
  let (runs, others) := htmlRuns fs dl em top
  let fonts := runFonts runs
  let mut out : Array String := #[]
  out := out.push s!"<div class=\"{escape p}\" style=\"width:{bpText (sp dl.width)}pt;\
    height:{bpText bottom}pt\">"
  for r in runs do
    let fi := (fonts.idxOf? r.font).getD 0
    let mut style := s!"left:{bpText r.x}pt;top:{bpText r.y}pt;font-size:{bpText r.size}pt"
    if r.slant != 0 then
      style := style ++ s!";transform:matrix(1,0,{fixed (-r.slant) 1000 3},1,0,0)"
    if r.smallCaps then style := style ++ ";font-feature-settings:\"smcp\""
    if let some c := r.color.bind cssColor? then style := style ++ s!";color:{c}"
    out := out.push s!"<span class=\"{escape p}-w {escape p}-f{fi}\" style=\"{escape style}\">\
      {escape r.text}</span>"
  -- the formulas, each an SVG picture with its source as alternative text
  for h : k in [0:dl.formulas.size] do
    let f := dl.formulas[k]
    let some (_, lx, ly) := placed.find? fun (l, _, _) => l.start ≤ f.start && f.start < l.stop
      | continue
    let sub : DisplayList :=
      { width := f.width, height := f.height, depth := f.depth,
        items := (dl.items.extract f.start f.stop).map (Item.shift (-f.x) (-f.y)) }
    let pad := 2 * 65536
    let svg := svgElement fs sub
      { em, padding := pad, title := f.source, desc := "Formula", idPrefix := s!"{p}-f{k}-" }
    let left := lx + sp f.x - pad
    let ftop := top + ly + sp f.y - sp f.height - pad
    let svg := svg.replace "<svg xmlns=\"http://www.w3.org/2000/svg\""
      s!"<svg class=\"{escape p}-m\" style=\"left:{bpText left}pt;top:{bpText ftop}pt\" \
        aria-label=\"{escape f.source}\" xmlns=\"http://www.w3.org/2000/svg\""
    out := out.push svg
    let delim := if f.display then ("\\[", "\\]") else ("$", "$")
    out := out.push s!"<span class=\"{escape p}-a\">{escape (delim.1 ++ f.source ++ delim.2)} \
      </span>"
  -- rules and outline glyphs outside formulas, a picture per line
  for h : k in [0:others.size] do
    let idx := others[k]
    if idx.isEmpty then continue
    let some (line, lx, ly) := placed[k]? | continue
    let sub : DisplayList :=
      { width := line.width, height := line.height, depth := line.depth,
        items := idx.filterMap (dl.items[·]?) }
    let pad := 2 * 65536
    let svg := svgElement fs sub { em, padding := pad, desc := "", idPrefix := s!"{p}-l{k}-" }
    let left := lx - pad
    let ltop := top + ly - sp line.height - pad
    out := out.push (svg.replace "<svg xmlns=\"http://www.w3.org/2000/svg\""
      s!"<svg class=\"{escape p}-g\" style=\"left:{bpText left}pt;top:{bpText ltop}pt\" \
        aria-hidden=\"true\" xmlns=\"http://www.w3.org/2000/svg\"")
  out := out.push "</div>"
  return ("\n".intercalate out.toList, fonts)

/-- The display list as an HTML page: the fragment with its style sheet. -/
def htmlDocument (fs : FontSet) (dl : DisplayList) (opts : HtmlOptions := {}) : String :=
  let (body, fonts) := htmlFragment fs dl opts
  s!"<!DOCTYPE html>\n<html lang=\"{escape opts.lang}\">\n<head>\n<meta charset=\"utf-8\">\n\
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n\
    <title>{escape opts.title}</title>\n<style>\n{htmlStyleSheet fonts opts}\n</style>\n\
    </head>\n<body>\n{body}\n</body>\n</html>\n"

end LeAnTeX.Backend
