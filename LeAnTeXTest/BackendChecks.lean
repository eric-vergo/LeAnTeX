/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX
import LeAnTeXTest.MathBoxChecks

/-!
# The back ends' checks

* **Goldens.** Every `examples/*.tex` is rendered as SVG and as HTML with New Computer Modern
  (from `fonts/newcomputermodern`, the HTML pointing at `../fonts/newcomputermodern`) and must
  equal `examples/*.svg` and `examples/*.html` byte for byte; each is rendered twice to check
  that the output is deterministic. `lake exe leantex-test --update-examples` rewrites them.
* **Structure.** In every golden, each glyph drawn (`xlink:href="#…"`) has its definition
  (`id="…"`); the HTML has no script and no event handler; the text of the HTML is the source's
  words.
* **Checks.** Named checks: the mapping of KaTeX's faces to Unicode's mathematical characters,
  the choice of size variants, colours, escaping of hostile source in titles, text and colours,
  slanted and small-capital runs.
-/

namespace BackendChecks

open LeAnTeX LeAnTeX.Backend

/-- The examples' sources, sorted. -/
def sources : IO (Array System.FilePath) := do
  let entries := (← System.FilePath.readDir "examples").map (·.path)
  return (entries.filter (·.extension == some "tex")).qsort (·.toString < ·.toString)

/-- The ids a written picture or page references with `xlink:href="#…"` and those it
defines with `id="…"`. -/
def refsAndIds (s : String) : Array String × Array String :=
  let after := fun (marker : String) =>
    ((s.splitOn marker).drop 1).toArray.map fun part => (part.splitOn "\"").headD ""
  (after "xlink:href=\"#", after " id=\"")

/-- Whether `s` contains `t`. -/
def has (s t : String) : Bool := (s.splitOn t).length > 1

/-- The structural checks of a written picture or page. -/
def structure_ (name s : String) : Array String := Id.run do
  let mut fails := #[]
  let (refs, ids) := refsAndIds s
  for r in refs do
    if !ids.contains r then fails := fails.push s!"{name}: #{r} drawn but not defined"
  for bad in ["<script", "javascript:", " onload=", " onclick=", " onerror=", "<foreignObject"] do
    if has s.toLower bad then fails := fails.push s!"{name}: contains {bad}"
  return fails

/-- The goldens: compares (or with `update` writes) every example's SVG and HTML. -/
def goldens (fonts : Fonts) (update : Bool) : IO (Array String) := do
  let mut fails := #[]
  let mut n := 0
  for path in ← sources do
    let src ← IO.FS.readFile path
    for (html, ext) in [(false, "svg"), (true, "html")] do
      let opts : RenderOptions := { html, fontUrl := "../fonts/newcomputermodern" }
      let out := match render fonts src opts with
        | .ok s => s
        | .error (p, m) => s!"error at {p}: {m}\n"
      let gold := path.withExtension ext
      n := n + 1
      if (render fonts src opts).toOption != some out then
        fails := fails.push s!"{gold}: not deterministic"
      fails := fails ++ structure_ gold.toString out
      if update then IO.FS.writeFile gold out
      else
        let have_ ← if ← gold.pathExists then IO.FS.readFile gold else pure ""
        if have_ != out then
          fails := fails.push s!"{gold}: differs (`lake exe leantex-test --update-examples` \
            after checking the change)"
  IO.println s!"  back-end goldens: {n - fails.size} of {n} pictures and pages as recorded"
  return fails

/-- The named checks. -/
def checks (fonts : Fonts) : Array (String × Bool) :=
  let fs := fonts.set
  let svg := fun (src : String) => (render fonts src).toOption.getD ""
  let html := fun (src : String) => (render fonts src { html := true }).toOption.getD ""
  let mathSvg := fun (src : String) => (render fonts src { math := true }).toOption.getD ""
  let face := fun (n : String) => ({ family := n } : Face)
  let hostile := "a <script>alert(1)</script> & \"q\" 'a' b"
  #[("faces: Math-Italic x is U+1D465, h is ℎ, α is U+1D6FC",
      mathAlphanumeric "Math-Italic" 'x' == some (Char.ofNat 0x1D465) &&
      mathAlphanumeric "Math-Italic" 'h' == some (Char.ofNat 0x210E) &&
      mathAlphanumeric "Math-Italic" 'α' == some (Char.ofNat 0x1D6FC)),
    ("faces: AMS R is ℝ, A is U+1D538; Fraktur g; script F is ℱ",
      mathAlphanumeric "AMS-Regular" 'R' == some 'ℝ' &&
      mathAlphanumeric "AMS-Regular" 'A' == some (Char.ofNat 0x1D538) &&
      mathAlphanumeric "Fraktur-Regular" 'g' == some (Char.ofNat 0x1D524) &&
      mathAlphanumeric "Caligraphic-Regular" 'F' == some (Char.ofNat 0x2131)),
    ("faces: Main-Regular draws characters as themselves",
      mathAlphanumeric "Main-Regular" '+' == none),
    ("faces: every face's glyph of x is found",
      ["Main-Regular", "Math-Italic", "Main-Bold", "Main-Italic", "SansSerif-Regular",
        "Typewriter-Regular", "Fraktur-Regular"].all fun n =>
        let f : Face :=
          { family := (n.splitOn "-").headD n, bold := has n "Bold", italic := has n "Italic" }
        (fs.resolve f 'x').isSome),
    ("size variants: Size2's ∑ is a larger glyph than Main's",
      match fs.resolve (face "Size2") '∑', fs.resolve (face "Main") '∑' with
      | some a, some b => a.glyph != b.glyph
      | _, _ => false),
    ("size variants: Size4's ( is larger than Size1's",
      match fs.resolve (face "Size4") '(', fs.resolve (face "Size1") '(' with
      | some a, some b => a.glyph != b.glyph
      | _, _ => false),
    ("colours: hexadecimal and names pass, anything else is dropped",
      cssColor? "#933" == some "#933" && cssColor? "red" == some "red" &&
      cssColor? "#12345" == none && cssColor? "red;x" == none &&
      cssColor? "url(#a)" == none && cssColor? "" == none),
    ("escape: markup characters become entities", escape hostile ==
      "a &lt;script&gt;alert(1)&lt;/script&gt; &amp; &quot;q&quot; &#39;a&#39; b"),
    ("escape: characters XML cannot carry are dropped",
      escape (String.ofList ['a', Char.ofNat 1, 'b', Char.ofNat 0xFFFE]) == "ab"),
    ("svg: hostile source stays text in the title",
      let s := svg ("\\texttt{" ++ "x</title><script>y</script>" ++ "}")
      !has s "<script" && has s "&lt;script&gt;"),
    ("html: hostile source stays text", let s := html "a \\& b <b>c</b>"
      !has s "<b>" && has s "&lt;b&gt;"),
    ("svg: a colour that is not a CSS colour is dropped",
      !has (mathSvg "\\color{red\" onload=\"x}{a}") " onload=\""),
    ("svg: a colour is written as the item's fill",
      has (mathSvg "\\color{#933}{a}") "fill=\"#933\""),
    ("svg: every glyph drawn is defined",
      (structure_ "mixed" (svg "$\\int_0^1 x\\,dx = \\frac{1}{2}$")).isEmpty),
    ("svg: the picture has its title, description and role",
      let s := svg "Hello"
      has s "role=\"img\"" && has s "<title>Hello</title>" && has s "<desc>"),
    ("html: words are text, ligatures written as letters",
      let s := html "office fluffy"
      has s ">office </span>" && has s ">fluffy</span>" && !has s "ﬃ"),
    ("html: slanted text is skewed, small capitals use smcp",
      has (html "\\textsl{a}") "matrix(1,0,-0.25,1,0,0)" &&
      has (html "\\textsc{a}") "&quot;smcp&quot;"),
    ("html: a formula is an inline picture with its source as alternative text",
      let s := html "see $x^2$"
      has s "aria-label=\"x^2\"" && has s "class=\"ltx-a\">$x^2$"),
    ("html: lengths in CSS points (345 TeX points are 343.711)",
      has (html "Some text.") "width:343.711pt"),
    ("svg: an empty source gives an empty picture", has (svg "") "<svg"),
    ("svg: deterministic", svg "$a+b$ and text" == svg "$a+b$ and text")]

/-- The horizontal centre of the ink of the glyph a back end draws for a glyph item, in
scaled points of the em: its position, the shift `FontSet.shift` gives and the middle of its
outline's box. -/
def inkCentre (fs : FontSet) (it : Item) : Option Int := do
  let .glyph face c x _ size .. := it | none
  let r ← fs.resolve face c
  let f ← fs.fonts[r.font]?
  let b ← (f.bounds r.glyph).toOption.join
  let mid : Int := (b.xMin + b.xMax) / 2 + (fs.placement face c).dx * 65536
  return x.raw + mid * size.raw / (65536 * (f.unitsPerEm : Int))

/-- The vertical extent of the ink of the glyph a back end draws for a glyph item, in scaled
points of the em above the item's baseline (lowest, highest), with its placement. -/
def inkHeight (fs : FontSet) (it : Item) : Option (Int × Int) := do
  let .glyph face c _ _ size .. := it | none
  let r ← fs.resolve face c
  let f ← fs.fonts[r.font]?
  let b ← (f.bounds r.glyph).toOption.join
  let pl := fs.placement face c
  let em := fun (v : Int) => v * size.raw / (65536 * (f.unitsPerEm : Int))
  let y := fun (v : Int) => em (v * pl.yScale / 1000 + pl.dy * 65536)
  return (y b.yMin, y b.yMax)

/-- The display list of the KaTeX-compatible layout of `src` with the back end's advances for
characters KaTeX's fonts lack, as `render` makes it. -/
def mathList (fs : FontSet) (src : String) : Array Item :=
  match (LeAnTeX.layout src).result with
  | .error _ => #[]
  | .ok b => (DisplayList.ofBox b { fallbackAdvance := fs.fallbackAdvance }).items

/-- The glyph items for `c` in the display list of `src`. -/
def glyphsFor (fs : FontSet) (src : String) (c : Char) : Array Item :=
  (mathList fs src).filter fun | .glyph _ c' .. => c' == c | _ => false

/-- Checks of the glyphs the sweep against KaTeX's drawing found misplaced: `\surd` stands on
the baseline as KaTeX's does (its ink from at most 0.25 em below to at least 0.7 em above),
the short bars are at most half an em tall, and a symbol KaTeX's fonts lack (`\origof`) gets
its glyph's room (the next glyph starts at least 0.9 em further on). -/
def placementChecks (fs : FontSet) : Array (String × Bool) :=
  let em := fun (n d : Int) => n * (Em.unit : Int) / d
  let surd := (glyphsFor fs "\\surd" (Char.ofNat 0x221A))[0]?.bind (inkHeight fs)
  let short := ["\\shortmid", "\\shortparallel", "\\nshortmid", "\\nshortparallel"].all
    fun src => match ((mathList fs src).filter (· matches .glyph ..))[0]?.bind (inkHeight fs) with
      | some (lo, hi) => hi - lo ≤ em 1 2
      | none => false
  let items := mathList fs "a\\origof b"
  let xs := items.filterMap fun | .glyph _ c x .. => some (c, x.raw) | _ => none
  let origof := match xs.toList with
    | [_, (_, x1), (_, x2)] => x2 - x1 ≥ em 9 10
    | _ => false
  #[("placement: \\surd stands on the baseline", match surd with
      | some (lo, hi) => lo ≥ -em 1 4 && hi ≥ em 7 10
      | none => false),
    ("placement: the short bars are short", short),
    ("placement: \\origof gets the room of its glyph", origof)]

/-- Whether, in the items, the ink of every glyph for `c` is centred within 0.08 em of the ink
of the glyph after it (`\not`'s slash over its relation), and there is one. -/
def overlaysIn (fs : FontSet) (items : Array Item) (c : Char) : Bool :=
    let pairs : List (Item × Option Item) := (List.range items.size).filterMap fun i =>
      match items[i]? with
      | some it => match it with
        | .glyph _ c' .. => if c' == c then some (it, items[i + 1]?) else none
        | _ => none
      | none => none
    !pairs.isEmpty && pairs.all fun (it, next) =>
      match inkCentre fs it, next.bind (inkCentre fs) with
      | some a, some b => (a - b).natAbs * 100 ≤ 8 * Em.unit
      | _, _ => false

/-- `overlaysIn` for the display list of the KaTeX-compatible layout of `src`. -/
def overlays (fs : FontSet) (src : String) (c : Char) : Bool :=
  match (LeAnTeX.layout src).result with
  | .error _ => false
  | .ok b => overlaysIn fs (DisplayList.ofBox b).items c

/-- `overlaysIn` for the display list of the TeX-rule layout of `src` at ten points (`none`
without the metric files). -/
def texOverlays (fs : FontSet) (src : String) (c : Char) : IO (Option Bool) := do
  let .ok m ← MathBoxChecks.fontSet | return none
  let .ok fams := m.families 655360 | return none
  match MathBoxChecks.texLayout m fams 10 src false with
  | .error _ => return some false
  | .ok l =>
    -- the display list is in em of the size: items' positions and sizes are scaled alike
    return some (overlaysIn fs (TeXMath.displayListOf fams l 655360).items c)

/-- The negation and private-use glyphs: `\not`'s slash is drawn over the relation after it,
and every math symbol whose character is one of KaTeX's private-use characters is drawn with a
glyph `privateUse` names (never with the math font's own glyph of that code point, which is a
different symbol). -/
def privateUseChecks (fs : FontSet) : Array (String × Bool) :=
  let pua := LeAnTeX.Data.mathSymbolList.filterMap fun (name, info) =>
    match info.replace with
    | some r => match r.toList with
      | [c] => if 0xE000 ≤ c.toNat && c.toNat ≤ 0xF8FF then some (name, info.font, c) else none
      | _ => none
    | none => none
  let faceOf : LeAnTeX.Font → String := fun
    | .ams => "AMS-Regular"
    | .main => "Main-Regular"
  let unmapped := pua.filter fun (name, font, c) =>
    let face := if name == "\\@imath" || name == "\\@jmath" then "Math-Italic" else faceOf font
    (privateUse face c).isNone
  #[("not: the slash of \\ne is centred on the =", overlays fs "a\\ne b" (Char.ofNat 0xE020)),
    ("not: the slash of \\not< is centred on the <", overlays fs "a\\not< b" (Char.ofNat 0xE020)),
    ("not: the bold slash of \\boldsymbol{\\ne} is centred on the =",
      overlays fs "\\boldsymbol{a\\ne b}" (Char.ofNat 0xE020)),
    (s!"private use: every symbol drawn with one of KaTeX's private-use characters has its \
      glyph ({pua.size} symbols; unmapped: {unmapped.map (·.1)})", unmapped.isEmpty)]

/-- Runs the back ends' checks (with `update`, rewrites the goldens); prints the summaries,
returns the failures. -/
def run (update : Bool := false) : IO (Array String) := do
  let (fonts, missing) ← Fonts.load "fonts/newcomputermodern"
  if !missing.isEmpty then return missing.map (s!"fonts: " ++ ·)
  let g ← goldens fonts update
  let mut cs := checks fonts ++ privateUseChecks fonts.set ++ placementChecks fonts.set
  for src in ["a\\ne b", "a\\not< b"] do
    if let some ok ← texOverlays fonts.set src (Char.ofNat 0x0338) then
      cs := cs.push (s!"not: the TeX-rule layout's slash of {src} is centred on the relation", ok)
  let bad := cs.filter (!·.2)
  IO.println s!"  back-end checks: {cs.size - bad.size} of {cs.size} hold"
  return g ++ bad.map (s!"check: " ++ ·.1)

end BackendChecks
