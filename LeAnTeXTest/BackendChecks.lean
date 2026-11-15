/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX

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
      if (render fonts src opts).toOption != some out then fails := fails.push s!"{gold}: not deterministic"
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

/-- Runs the back ends' checks (with `update`, rewrites the goldens); prints the summaries,
returns the failures. -/
def run (update : Bool := false) : IO (Array String) := do
  let (fonts, missing) ← Fonts.load "fonts/newcomputermodern"
  if !missing.isEmpty then return missing.map (s!"fonts: " ++ ·)
  let g ← goldens fonts update
  let cs := checks fonts
  let bad := cs.filter (!·.2)
  IO.println s!"  back-end checks: {cs.size - bad.size} of {cs.size} hold"
  return g ++ bad.map (s!"check: " ++ ·.1)

end BackendChecks
