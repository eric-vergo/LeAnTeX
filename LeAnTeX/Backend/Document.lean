/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Backend.Html
import LeAnTeX.Doc.Front
import LeAnTeX.Text.Output

/-!
# Documents in the back ends

A typeset document (`LeAnTeX.Doc.typesetDocument`) as pictures and pages:

* `pageDisplayList`: one page as a display list in sp from the paper's top-left corner: every
  box placed as TeX's shipping out places it (`vlist_out`, `hlist_out`), rules, formulas,
  images, and the table of contents' dotted leaders (`\leaders` of a dot box `2 × 4.5 mu`
  wider than the dot, aligned on the line's left edge, as LaTeX's `\@dottedtocline` sets them).
* `svgPages`: an SVG picture per page, the paper's size; `svgCombined`: all pages in one
  picture, one below the other with a gap, each on a white sheet with a thin border.
* `htmlPages`: an HTML page holding every page as a sheet (text as positioned runs in the web
  fonts, formulas and rules as inline SVG, as the HTML back end sets a fragment); with
  `HtmlDocOptions.externalStyles` the positions and sizes go into a generated style sheet
  (classes instead of `style` attributes), so that a content policy without
  `'unsafe-inline'` styles can be met. The default is inline styles: one self-contained file.
  The continuous "web" view is the same back end on a document typeset with
  `Settings.continuous` (one tall page, floats where they are given).
-/

namespace LeAnTeX.Backend

open LeAnTeX.Text LeAnTeX.Doc

/-- A horizontal list with its leaders (glue of subtype 100) replaced by dots: the leader's
size under the box's glue setting, filled with the line font's dot in boxes aligned on the
list's left edge `x0` (the list starts at `cx`). The rest of the list keeps its glue sizes:
returns the new list with every glue fixed at its size. -/
def expandLeaders (fonts : Array (FontInfo × Int)) (nodes : Array HNode) (g : GlueSet)
    (cx x0 : Int) : Array HNode := Id.run do
  if !nodes.any (fun n => match n with | .glue _ 100 => true | _ => false) then return nodes
  let fixed := Typeset.freezeGlue nodes g
  -- the font of the first glyph, for the dots
  let font := nodes.findSome? fun n => match n with
    | .glyph _ _ _ _ _ f => some f
    | _ => none
  let mut out := #[]
  let mut x := cx
  for h : i in [0:fixed.size] do
    let n := fixed[i]
    match nodes[i]?, n with
    | some (.glue _ 100), .glue gl _ =>
      match font.bind (fun f => (fonts[f]?).map (f, ·)) with
      | some (fi, (info, size)) =>
        let tf : TextFont := { info, size, index := fi }
        let dot := tf.shape #['.']
        let dw := listWidth dot
        let mu := size / 18
        let bw := dw + 9 * mu / 2 * 2
        if bw ≤ 0 then out := out.push n
        else
          let start := x0 + (x - x0 + bw - 1) / bw * bw
          let count := if x + gl.width ≥ start then (x + gl.width - start) / bw else 0
          let mut nodesOut : Array HNode := #[.kern (start - x) .explicit]
          for _ in [0:count.toNat] do
            nodesOut := nodesOut.push (.kern (9 * mu / 2) .explicit) ++ dot |>.push
              (.kern (9 * mu / 2) .explicit)
          nodesOut := nodesOut.push (.kern (x + gl.width - start - count * bw) .explicit)
          out := out ++ (if count > 0 then nodesOut else #[n])
      | none => out := out.push n
      x := x + gl.width
    | _, n =>
      out := out.push n
      x := x + n.width
  return out

/-- The items of a vertical list set with `g` whose top is at `(x, y)`, `fuel` levels deep. -/
def vItems (fonts : Array (FontInfo × Int)) (items : Array VNode) (g : GlueSet) (x y w : Int) :
    Nat → Array Item × Array Formula
  | 0 => (#[], #[])
  | fuel + 1 => Id.run do
    let tops := positions items g
    let mut acc : Array Item × Array Formula := (#[], #[])
    for h : i in [0:items.size] do
      let top := y + tops.getD i 0
      match items[i] with
      | .hbox _ bh _ s c gl =>
        let c' := expandLeaders fonts c gl (x + s) (x + s)
        let gl' := if c'.size != c.size then ({} : GlueSet) else gl
        acc := placeNodes fonts 64 c' gl' (x + s) (top + bh) acc.1.size acc
      | .vbox bw _ _ s c gl =>
        let (its, fs) := vItems fonts c gl (x + s) top bw fuel
        acc := (acc.1 ++ its, acc.2 ++ fs)
      | .rule rw rh rd =>
        acc := (acc.1.push (.rule ⟨x⟩ ⟨top⟩ ⟨rw.getD w⟩ ⟨rh + rd⟩ none none), acc.2)
      | _ => pure ()
    return acc

/-- One page as a display list (see the module docstring): its width the paper's, its depth
the paper's height, one line holding every item. -/
def pageDisplayList (fonts : Array (FontInfo × Int)) (p : Page) : DisplayList :=
  let (items, forms) := vItems fonts p.body.content p.body.glue p.bodyX p.bodyY p.body.width 64
  let (items, forms) := match p.foot with
    | some (.hbox _ _ _ _ c gl) =>
      placeNodes fonts 64 c gl p.footX p.footY items.size (items, forms)
    | _ => (items, forms)
  { width := ⟨p.width⟩, height := 0, depth := ⟨p.height⟩, items, formulas := forms,
    lines := #[{ start := 0, stop := items.size, width := ⟨p.width⟩, height := 0,
                 depth := ⟨p.height⟩ }] }

/-- Every page as an SVG picture. -/
def svgPages (fs : FontSet) (r : DocResult) (title : String := "") : Array String :=
  r.pages.map fun p =>
    svgDocument fs (pageDisplayList r.fonts p)
      { padding := 0, title := s!"{title} page {p.text}", desc := "Typeset by LeAnTeX" }

/-- The gap between pages in the combined views, in sp (18 pt). -/
def pageGap : Int := 18 * 65536

/-- All pages in one SVG picture, each on a white sheet with a thin border, one below the
other. -/
def svgCombined (fs : FontSet) (r : DocResult) (title : String := "") : String := Id.run do
  let w := r.pages.foldl (init := 0) fun m p => max m p.width
  let h := r.pages.foldl (init := 0) fun acc p => acc + p.height + pageGap
  let mut out := #[s!"<svg xmlns=\"http://www.w3.org/2000/svg\" \
    viewBox=\"0 0 {ptText w} {ptText (max 0 (h - pageGap))}\" width=\"{bpText w}pt\" \
    height=\"{bpText (max 0 (h - pageGap))}pt\">",
    s!"<title>{escape title}</title><desc>Typeset by LeAnTeX</desc>",
    -- every image once, however many pages use it
    imageDefs (r.pages.map (pageDisplayList r.fonts)) ({} : SvgOptions).imagePrefix]
  let mut y : Int := 0
  for h : k in [0:r.pages.size] do
    let p := r.pages[k]
    out := out.push s!"<rect x=\"0\" y=\"{ptText y}\" width=\"{ptText p.width}\" \
      height=\"{ptText p.height}\" fill=\"#fff\" stroke=\"#999\" stroke-width=\"0.5\"/>"
    let el := svgElement fs (pageDisplayList r.fonts p)
      { padding := 0, title := s!"page {p.text}", idPrefix := s!"p{k}g",
        writeImageDefs := false }
    out := out.push (el.replace "<svg xmlns=\"http://www.w3.org/2000/svg\""
      s!"<svg y=\"{ptText y}\" xmlns=\"http://www.w3.org/2000/svg\"")
    y := y + p.height + pageGap
  out := out.push "</svg>"
  return "\n".intercalate out.toList

/-- Options of the HTML views of a document. -/
structure HtmlDocOptions where
  /-- Where the page finds the fonts. -/
  fontUrl : String := "fonts/newcomputermodern"
  /-- The document's title. -/
  title : String := ""
  /-- Put positions and sizes into a generated style sheet instead of `style` attributes;
  the sheet is returned beside the page and linked as `styleUrl`. -/
  externalStyles : Bool := false
  /-- Where the page finds the generated style sheet. -/
  styleUrl : String := "document.css"
  deriving Inhabited

/-- Moves every `style="…"` attribute of HTML text (each written as `class="…" style="…"` by
the back end) into a class of its own (`<prefix>-s<n>`) and returns the text with the rules
of those classes. -/
def externalizeStyles (html prefix_ : String) : String × String := Id.run do
  let parts := (html.splitOn "\" style=\"").toArray
  let mut out := parts[0]?.getD ""
  let mut css : Array String := #[]
  for h : k in [1:parts.size] do
    let part := parts[k]
    match part.splitOn "\"" with
    | style :: rest =>
      let cls := s!"{prefix_}-s{k}"
      let decl := (style.replace "&quot;" "\"").replace "&amp;" "&"
      css := css.push s!".{cls} \{ {decl} }"
      out := out ++ " " ++ cls ++ "\"" ++ "\"".intercalate rest
    | [] => out := out ++ part
  return (out, "\n".intercalate css.toList)

/-- Every page as a sheet of one HTML page; with `externalStyles` also the generated style
sheet (else empty). -/
def htmlPages (fs : FontSet) (r : DocResult) (o : HtmlDocOptions := {}) : String × String :=
  Id.run do
  let mut body : Array String := #[]
  let mut sheets : Array String := #[]
  for h : k in [0:r.pages.size] do
    let p := r.pages[k]
    let opts : HtmlOptions :=
      { fontUrl := o.fontUrl, idPrefix := s!"ltx{k}", writeImageDefs := false }
    let (frag, fonts) := htmlFragment fs (pageDisplayList r.fonts p) opts
    sheets := sheets.push (htmlStyleSheet fonts opts)
    body := body.push s!"<section class=\"ltx-page\" aria-label=\"Page {escape p.text}\">\
      {frag}</section>"
  let base := ".ltx-page { background: #fff; color: #000; margin: 18pt auto; \
    box-shadow: 0 0 4pt #999; width: fit-content; }\n" ++ "\n".intercalate sheets.toList
  -- every image once for the whole page, however many sheets use it
  let defs := imageDefs (r.pages.map (pageDisplayList r.fonts)) ({} : HtmlOptions).imagePrefix
  if !defs.isEmpty then body := #[hiddenSvg defs] ++ body
  let bodyText := "\n".intercalate body.toList
  let (bodyText, extra) := if o.externalStyles then externalizeStyles bodyText "ltxs"
    else (bodyText, "")
  let head := if o.externalStyles then
      s!"<link rel=\"stylesheet\" href=\"{escape o.styleUrl}\">"
    else s!"<style>\n{base}\n</style>"
  let page := s!"<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n\
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n\
    <title>{escape o.title}</title>\n{head}\n</head>\n<body>\n{bodyText}\n</body>\n</html>\n"
  return (page, if o.externalStyles then base ++ "\n" ++ extra ++ "\n" else "")

end LeAnTeX.Backend
