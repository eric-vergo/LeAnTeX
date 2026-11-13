/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Layout.Html

/-!
# Delimiters

Delimiters of a given size: the glyph of Main at script, text or display size, the Size1–Size4
glyphs, or a stack of pieces with an SVG image for the extensible part (TeXbook chapter 17 and
Appendix G rule 19, as KaTeX builds them).

## Main definitions

* `makeSizedDelim`: `\big` … `\Bigg`: one of the four large sizes.
* `makeCustomSizedDelim`: the smallest delimiter at least as tall as asked, centred on the axis
  or not.
* `makeLeftRightDelim`: the delimiter `\left` and `\right` put around material of a given
  height and depth.
* `jsNumber`: a number as JavaScript prints it, for the SVG data.

## References

* KaTeX's `src/delimiter.ts` and `src/svgGeometry.ts` (MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- An integer number of SVG units (1000 an em) as text. -/
def jsInt (n : Int) : String := toString n

/-- A length in em as JavaScript prints it: the shortest decimal (at most five decimals here,
enough for the SVG numbers KaTeX writes, which have at most two). -/
def jsNumber (x : Em) : String := x.decimal 5

/-- The metrics of a delimiter's glyph in a font; KaTeX fails if there are none (`getMetrics`). -/
def delimMetrics (symbol font : String) (mode : Mode) : BuildM CharMetrics := do
  let replace := match Tables.mathSymbols[symbol]? with
    | some { replace := some r, .. } => r
    | _ => symbol
  match charMetrics replace font mode with
  | some m => pure m
  | none => throwInternal s!"Unsupported symbol {symbol} and font size {font}."

/-- A delimiter in a span that changes to the base size of `toStyle` (`styleWrap`). -/
def styleWrap (delim : Box) (toStyle : MathStyle) (o : Options) (classes : Array String) : Box :=
  let o' := o.havingBaseStyle toStyle
  let span := makeSpan (classes ++ o'.sizingClasses o) #[delim] (some o)
  let k := o'.sizeMultiplier / o.sizeMultiplier
  { span with height := span.height * k, depth := span.depth * k,
              maxFontSize := o'.sizeMultiplier }

/-- Centre a delimiter that was drawn at another size on the axis of the current size
(`centerSpan`). -/
def centerSpan (span : Box) (o : Options) (style : MathStyle) : Box :=
  let o' := o.havingBaseStyle style
  let shift := (1 - o.sizeMultiplier / o'.sizeMultiplier) * o.fontMetrics.axisHeight
  let span := (span.addClass "delimcenter").setStyle "top" shift
  { span with height := span.height - shift, depth := span.depth + shift }

/-- A delimiter in Main at the size of `style` (`makeSmallDelim`). -/
def makeSmallDelim (delim : String) (style : MathStyle) (center : Bool) (o : Options)
    (mode : Mode) (classes : Array String) : BuildM Box := do
  let text ← makeSymbol delim "Main-Regular" mode o
  let span := styleWrap text style o classes
  return if center then centerSpan span o style else span

/-- A delimiter in one of the fonts Size1–Size4 (`makeLargeDelim`). -/
def makeLargeDelim (delim : String) (size : Nat) (center : Bool) (o : Options) (mode : Mode)
    (classes : Array String) : BuildM Box := do
  let inner ← makeSymbol delim s!"Size{size}-Regular" mode o
  let span := styleWrap (makeSpan #["delimsizing", s!"size{size}"] #[inner] (some o))
    MathStyle.text o classes
  return if center then centerSpan span o MathStyle.text else span

/-- A piece of a stacked delimiter (`makeGlyphSpan`). -/
def makeGlyphSpan (symbol font : String) (mode : Mode) (o : Options) : BuildM VChild := do
  let sizeClass := if font == "Size1-Regular" then "delim-size1" else "delim-size4"
  let sym ← makeSymbol symbol font mode o
  return .elem { elem := makeSpan #["delimsizinginner", sizeClass] #[makeSpan #[] #[sym]] }

/-- Two copies of a path, for crisper edges at low resolution (`doubleBrushStroke`). -/
def doubleBrushStroke (p : String) : String := p ++ " " ++ p

/-- The path of the extensible part of a stacked delimiter (`innerPath`). -/
def innerPath (name : String) (height : Int) : String :=
  let h := jsInt height
  match name with
  | "⎜" => doubleBrushStroke s!"M291 0 H417 V{h} H291z"
  | "∣" => doubleBrushStroke s!"M145 0 H188 V{h} H145z"
  | "∥" => doubleBrushStroke s!"M145 0 H188 V{h} H145z" ++
      doubleBrushStroke s!"M367 0 H410 V{h} H367z"
  | "⎟" => doubleBrushStroke s!"M457 0 H583 V{h} H457z"
  | "⎢" => doubleBrushStroke s!"M319 0 H403 V{h} H319z"
  | "⎥" => doubleBrushStroke s!"M263 0 H347 V{h} H263z"
  | "⎪" => doubleBrushStroke s!"M384 0 H504 V{h} H384z"
  | "⏐" => doubleBrushStroke s!"M312 0 H355 V{h} H312z"
  | "‖" => doubleBrushStroke s!"M257 0 H300 V{h} H257z" ++
      doubleBrushStroke s!"M478 0 H521 V{h} H478z"
  | _ => ""

/-- The path of a tall delimiter drawn as one SVG image, with `midHeight` SVG units of
extension (`tallDelim`). -/
def tallDelim (label : String) (midHeight : Int) : BuildM String := do
  let m := jsInt midHeight
  let nm := jsInt (-midHeight)
  match label with
  | "lbrack" => pure (s!"M403 1759 V84 H666 V0 H319 V1759 v{m} v1759 v84 h347 v-84\n" ++
      s!"H403z M403 1759 V0 H319 V1759 v{m} v1759 v84 h84z")
  | "rbrack" => pure (s!"M347 1759 V0 H0 V84 H263 V1759 v{m} v1759 H0 v84 H347z\n" ++
      s!"M347 1759 V0 H263 V1759 v{m} v1759 h84z")
  | "vert" => pure (s!"M145 15 v585 v{m} v585 c2.667,10,9.667,15,21,15\n" ++
      s!"c10,0,16.667,-5,20,-15 v-585 v{nm} v-585 c-2.667,-10,-9.667,-15,-21,-15\n" ++
      s!"c-10,0,-16.667,5,-20,15z M188 15 H145 v585 v{m} v585 h43z")
  | "doublevert" => pure (s!"M145 15 v585 v{m} v585 c2.667,10,9.667,15,21,15\n" ++
      s!"c10,0,16.667,-5,20,-15 v-585 v{nm} v-585 c-2.667,-10,-9.667,-15,-21,-15\n" ++
      s!"c-10,0,-16.667,5,-20,15z M188 15 H145 v585 v{m} v585 h43z\n" ++
      s!"M367 15 v585 v{m} v585 c2.667,10,9.667,15,21,15\n" ++
      s!"c10,0,16.667,-5,20,-15 v-585 v{nm} v-585 c-2.667,-10,-9.667,-15,-21,-15\n" ++
      s!"c-10,0,-16.667,5,-20,15z M410 15 H367 v585 v{m} v585 h43z")
  | "lfloor" => pure (s!"M319 602 V0 H403 V602 v{m} v1715 h263 v84 H319z\n" ++
      s!"MM319 602 V0 H403 V602 v{m} v1715 H319z")
  | "rfloor" => pure (s!"M319 602 V0 H403 V602 v{m} v1799 H0 v-84 H319z\n" ++
      s!"MM319 602 V0 H403 V602 v{m} v1715 H319z")
  | "lceil" => pure (s!"M403 1759 V84 H666 V0 H319 V1759 v{m} v602 h84z\n" ++
      s!"M403 1759 V0 H319 V1759 v{m} v602 h84z")
  | "rceil" => pure (s!"M347 1759 V0 H0 V84 H263 V1759 v{m} v602 h84z\n" ++
      s!"M347 1759 V0 h-84 V1759 v{m} v602 h84z")
  | "lparen" => pure ("M863,9c0,-2,-2,-5,-6,-9c0,0,-17,0,-17,0c-12.7,0,-19.3,0.3,-20,1\n" ++
      "c-5.3,5.3,-10.3,11,-15,17c-242.7,294.7,-395.3,682,-458,1162c-21.3,163.3,-33.3,349,\n" ++
      s!"-36,557 l0,{jsInt (midHeight + 84)}c0.2,6,0,26,0,60c2,159.3,10,310.7,24,454c53.3," ++
      "528,210,\n" ++
      "949.7,470,1265c4.7,6,9.7,11.7,15,17c0.7,0.7,7,1,19,1c0,0,18,0,18,0c4,-4,6,-7,6,-9\n" ++
      "c0,-2.7,-3.3,-8.7,-10,-18c-135.3,-192.7,-235.5,-414.3,-300.5,-665c-65,-250.7,-102.5,\n" ++
      "-544.7,-112.5,-882c-2,-104,-3,-167,-3,-189\n" ++
      s!"l0,-{jsInt (midHeight + 92)}c0,-162.7,5.7,-314,17,-454c20.7,-272,63.7,-513,129," ++
      "-723c65.3,\n" ++
      "-210,155.3,-396.3,270,-559c6.7,-9.3,10,-15.3,10,-18z")
  | "rparen" => pure ("M76,0c-16.7,0,-25,3,-25,9c0,2,2,6.3,6,13c21.3,28.7,42.3,60.3,\n" ++
      "63,95c96.7,156.7,172.8,332.5,228.5,527.5c55.7,195,92.8,416.5,111.5,664.5\n" ++
      s!"c11.3,139.3,17,290.7,17,454c0,28,1.7,43,3.3,45l0,{jsInt (midHeight + 9)}\n" ++
      "c-3,4,-3.3,16.7,-3.3,38c0,162,-5.7,313.7,-17,455c-18.7,248,-55.8,469.3,-111.5,664\n" ++
      "c-55.7,194.7,-131.8,370.3,-228.5,527c-20.7,34.7,-41.7,66.3,-63,95c-2,3.3,-4,7,-6,11\n" ++
      "c0,7.3,5.7,11,17,11c0,0,11,0,11,0c9.3,0,14.3,-0.3,15,-1c5.3,-5.3,10.3,-11,15,-17\n" ++
      "c242.7,-294.7,395.3,-681.7,458,-1161c21.3,-164.7,33.3,-350.7,36,-558\n" ++
      s!"l0,-{jsInt (midHeight + 144)}c-2,-159.3,-10,-310.7,-24,-454c-53.3,-528,-210," ++
      "-949.7,\n" ++
      "-470,-1265c-4.7,-6,-9.7,-11.7,-15,-17c-0.7,-0.7,-6.7,-1,-18,-1z")
  | _ => throwInternal "Unknown stretchy delimiter."

/-- The extensible part of a stacked delimiter as an SVG image `height` em tall (`makeInner`). -/
def makeInner (ch : String) (height : Em) (o : Options) : VChild :=
  let code := (utf16FirstOf ch).getD 0
  let width := match (Metrics.table["Size4-Regular"]?).bind (·[code]?) with
    | some m => m.width
    | none => (((Metrics.table["Size1-Regular"]?).bind (·[code]?)).map (·.width)).getD 0
  let h := (height * 1000).round
  let svg : Box :=
    { kind := .svg #[.path "inner" (some (innerPath ch h))]
      attrs := #[("width", width.css), ("height", height.css), ("style", "width:" ++ width.css),
      ("viewBox", s!"0 0 {jsNumber (width * 1000)} {jsInt h}"),
      ("preserveAspectRatio", "xMinYMin")] }
  let span := makeSvgSpan #[] #[svg] o
  .elem { elem := ({ span with height }.setStyle "height" height).setStyle "width" width }

/-- The overlap of the pieces of a stacked delimiter. -/
def lapInEms : Em := 0.008

/-- A delimiter built from pieces (top, repeated middle, optional middle, bottom), at least
`heightTotal` em tall (`makeStackedDelim`). -/
def makeStackedDelim (delim : String) (heightTotal : Em) (center : Bool) (o : Options)
    (mode : Mode) (classes : Array String) : BuildM Box := do
  let verts := ["|", "\\lvert", "\\rvert", "\\vert"]
  let doubleVerts := ["\\|", "\\lVert", "\\rVert", "\\Vert"]
  -- (top, middle, repeat, bottom, font, SVG label, viewBox width)
  let pieces : String × Option String × String × String × String × String × Nat :=
    let s1 := "Size1-Regular"
    let s4 := "Size4-Regular"
    if delim == "\\uparrow" then (delim, none, "⏐", "⏐", s1, "", 0)
    else if delim == "\\Uparrow" then (delim, none, "‖", "‖", s1, "", 0)
    else if delim == "\\downarrow" then ("⏐", none, "⏐", delim, s1, "", 0)
    else if delim == "\\Downarrow" then ("‖", none, "‖", delim, s1, "", 0)
    else if delim == "\\updownarrow" then ("\\uparrow", none, "⏐", "\\downarrow", s1, "", 0)
    else if delim == "\\Updownarrow" then
      ("\\Uparrow", none, "‖", "\\Downarrow", s1, "", 0)
    else if verts.contains delim then (delim, none, "∣", delim, s1, "vert", 333)
    else if doubleVerts.contains delim then (delim, none, "∥", delim, s1, "doublevert", 556)
    else if delim == "[" || delim == "\\lbrack" then
      ("⎡", none, "⎢", "⎣", s4, "lbrack", 667)
    else if delim == "]" || delim == "\\rbrack" then
      ("⎤", none, "⎥", "⎦", s4, "rbrack", 667)
    else if delim == "\\lfloor" || delim == "⌊" then
      ("⎢", none, "⎢", "⎣", s4, "lfloor", 667)
    else if delim == "\\lceil" || delim == "⌈" then
      ("⎡", none, "⎢", "⎢", s4, "lceil", 667)
    else if delim == "\\rfloor" || delim == "⌋" then
      ("⎥", none, "⎥", "⎦", s4, "rfloor", 667)
    else if delim == "\\rceil" || delim == "⌉" then
      ("⎤", none, "⎥", "⎥", s4, "rceil", 667)
    else if delim == "(" || delim == "\\lparen" then
      ("⎛", none, "⎜", "⎝", s4, "lparen", 875)
    else if delim == ")" || delim == "\\rparen" then
      ("⎞", none, "⎟", "⎠", s4, "rparen", 875)
    else if delim == "\\{" || delim == "\\lbrace" then
      ("⎧", some "⎨", "⎪", "⎩", s4, "", 0)
    else if delim == "\\}" || delim == "\\rbrace" then
      ("⎫", some "⎬", "⎪", "⎭", s4, "", 0)
    else if delim == "\\lgroup" || delim == "⟮" then
      ("⎧", none, "⎪", "⎩", s4, "", 0)
    else if delim == "\\rgroup" || delim == "⟯" then
      ("⎫", none, "⎪", "⎭", s4, "", 0)
    else if delim == "\\lmoustache" || delim == "⎰" then
      ("⎧", none, "⎪", "⎭", s4, "", 0)
    else if delim == "\\rmoustache" || delim == "⎱" then
      ("⎫", none, "⎪", "⎩", s4, "", 0)
    else (delim, none, delim, delim, s1, "", 0)
  let (top, middle, rep, bottom, font, svgLabel, viewBoxWidth) := pieces
  let tm ← delimMetrics top font mode
  let topHeightTotal := tm.height + tm.depth
  let rm ← delimMetrics rep font mode
  let repeatHeightTotal := rm.height + rm.depth
  let bm ← delimMetrics bottom font mode
  let bottomHeightTotal := bm.height + bm.depth
  let mut middleHeightTotal : Em := 0
  let mut middleFactor : Int := 1
  if let some mid := middle then
    let mm ← delimMetrics mid font mode
    middleHeightTotal := mm.height + mm.depth
    middleFactor := 2
  let minHeight := topHeightTotal + bottomHeightTotal + middleHeightTotal
  let repeatCount : Int :=
    max 0 ((heightTotal - minHeight) / (middleFactor * repeatHeightTotal)).ceil
  let realHeightTotal := minHeight + (repeatCount * middleFactor) * repeatHeightTotal
  let axisHeight := if center then o.fontMetrics.axisHeight * o.sizeMultiplier
    else o.fontMetrics.axisHeight
  let depth := Em.mk (Em.roundDiv realHeightTotal.raw 2) - axisHeight
  let mut stack : Array VChild := #[]
  if svgLabel != "" then
    let midHeight := realHeightTotal - topHeightTotal - bottomHeightTotal
    let viewBoxHeight := (realHeightTotal * 1000).round
    let pathStr ← tallDelim svgLabel (midHeight * 1000).round
    let width := (Em.ofRatio viewBoxWidth 1000).css
    let height := (Em.ofRatio viewBoxHeight 1000).css
    let svg : Box :=
      { kind := .svg #[.path svgLabel (some pathStr)]
        attrs := #[("width", width), ("height", height),
        ("viewBox", s!"0 0 {viewBoxWidth} {jsInt viewBoxHeight}")] }
    let wrapper := makeSvgSpan #[] #[svg] o
    let wrapper := { wrapper with height := Em.ofRatio viewBoxHeight 1000 }
    let wrapper := (wrapper.setStyleStr "width" width).setStyleStr "height" height
    stack := stack.push (.elem { elem := wrapper })
  else
    stack := stack.push (← makeGlyphSpan bottom font mode o)
    stack := stack.push (.kern (-lapInEms))
    match middle with
    | none =>
      let innerHeight := realHeightTotal - topHeightTotal - bottomHeightTotal + 2 * lapInEms
      stack := stack.push (makeInner rep innerHeight o)
    | some mid =>
      let innerHeight := Em.mk (Em.roundDiv
        (realHeightTotal - topHeightTotal - bottomHeightTotal - middleHeightTotal).raw 2) +
        2 * lapInEms
      stack := stack.push (makeInner rep innerHeight o)
      stack := stack.push (.kern (-lapInEms))
      stack := stack.push (← makeGlyphSpan mid font mode o)
      stack := stack.push (.kern (-lapInEms))
      stack := stack.push (makeInner rep innerHeight o)
    stack := stack.push (.kern (-lapInEms))
    stack := stack.push (← makeGlyphSpan top font mode o)
  let o' := o.havingBaseStyle MathStyle.text
  let inner ← makeVList (.bottom depth stack)
  return styleWrap (makeSpan #["delimsizing", "mult"] #[inner] (some o')) MathStyle.text o
    classes

/-- Delimiters that come in four large sizes and then stack. -/
def stackLargeDelimiters : List String :=
  ["(", "\\lparen", ")", "\\rparen", "[", "\\lbrack", "]", "\\rbrack", "\\{", "\\lbrace", "\\}",
   "\\rbrace", "\\lfloor", "\\rfloor", "⌊", "⌋", "\\lceil", "\\rceil", "⌈",
   "⌉", "\\surd"]

/-- Delimiters that stack above the text size. -/
def stackAlwaysDelimiters : List String :=
  ["\\uparrow", "\\downarrow", "\\updownarrow", "\\Uparrow", "\\Downarrow", "\\Updownarrow",
   "|", "\\|", "\\vert", "\\Vert", "\\lvert", "\\rvert", "\\lVert", "\\rVert", "\\lgroup",
   "\\rgroup", "⟮", "⟯", "\\lmoustache", "\\rmoustache", "⎰", "⎱"]

/-- Delimiters that never stack. -/
def stackNeverDelimiters : List String :=
  ["<", ">", "\\langle", "\\rangle", "/", "\\backslash", "\\lt", "\\gt"]

/-- The height of the four large sizes (`sizeToMaxHeight`). -/
def sizeToMaxHeight : Array Em := #[0, 1.2, 1.8, 2.4, 3.0]

/-- `<` and `>` (and their names) become angle brackets. -/
def normalizeDelim (delim : String) : String :=
  if delim == "<" || delim == "\\lt" || delim == "⟨" then "\\langle"
  else if delim == ">" || delim == "\\gt" || delim == "⟩" then "\\rangle"
  else delim

/-- A delimiter of large size 1–4 (`makeSizedDelim`). -/
def makeSizedDelim (delim : String) (size : Nat) (o : Options) (mode : Mode)
    (classes : Array String) : BuildM Box := do
  let delim := normalizeDelim delim
  if stackLargeDelimiters.contains delim || stackNeverDelimiters.contains delim then
    makeLargeDelim delim size false o mode classes
  else if stackAlwaysDelimiters.contains delim then
    makeStackedDelim delim sizeToMaxHeight[size]! false o mode classes
  else throwParse s!"Illegal delimiter: '{delim}'"

/-- A delimiter kind: Main at a style's size, a large size, or stacked. -/
inductive DelimType where
  /-- Main at the size of the style. -/
  | small (style : MathStyle)
  /-- One of Size1–Size4. -/
  | large (size : Nat)
  /-- Stacked pieces. -/
  | stack
  deriving Inhabited

/-- The kinds tried in order for a delimiter that never stacks. -/
def stackNeverSequence : Array DelimType :=
  #[.small .scriptscript, .small .script, .small .text, .large 1, .large 2, .large 3, .large 4]

/-- The kinds tried in order for a delimiter that always stacks above the text size. -/
def stackAlwaysSequence : Array DelimType :=
  #[.small .scriptscript, .small .script, .small .text, .stack]

/-- The kinds tried in order for a delimiter with large sizes that then stacks. -/
def stackLargeSequence : Array DelimType :=
  #[.small .scriptscript, .small .script, .small .text, .large 1, .large 2, .large 3, .large 4,
    .stack]

/-- The metric font of a delimiter kind (`delimTypeToFont`). -/
def DelimType.font : DelimType → String
  | .small _ => "Main-Regular"
  | .large s => s!"Size{s}-Regular"
  | .stack => "Size4-Regular"

/-- The first kind in the sequence whose delimiter is taller than `height`, from the current
style's size on, or the last kind (`traverseSequence`). -/
def traverseSequence (delim : String) (height : Em) (seq : Array DelimType) (o : Options) :
    BuildM DelimType := do
  let start := min 2 (3 - o.style.size)
  for i in [start:seq.size] do
    let t := seq[i]!
    if let .stack := t then break
    let m ← delimMetrics delim t.font .math
    let mut heightDepth := m.height + m.depth
    if let .small st := t then
      heightDepth := heightDepth * (o.havingBaseStyle st).sizeMultiplier
    if heightDepth > height then return t
  return seq.back!

/-- The smallest delimiter taller than `height` (`makeCustomSizedDelim`). -/
def makeCustomSizedDelim (delim : String) (height : Em) (center : Bool) (o : Options)
    (mode : Mode) (classes : Array String) : BuildM Box := do
  let delim := normalizeDelim delim
  let seq := if stackNeverDelimiters.contains delim then stackNeverSequence
    else if stackLargeDelimiters.contains delim then stackLargeSequence
    else stackAlwaysSequence
  match ← traverseSequence delim height seq o with
  | .small st => makeSmallDelim delim st center o mode classes
  | .large s => makeLargeDelim delim s center o mode classes
  | .stack => makeStackedDelim delim height center o mode classes

/-- The delimiter `\left` or `\right` puts around material of the given height and depth: tall
enough to cover it symmetrically about the axis, to TeX's `\delimiterfactor` and
`\delimitershortfall` (`makeLeftRightDelim`). -/
def makeLeftRightDelim (delim : String) (height depth : Em) (o : Options) (mode : Mode)
    (classes : Array String) : BuildM Box := do
  let axisHeight := o.fontMetrics.axisHeight * o.sizeMultiplier
  let delimiterExtend := 5 / o.fontMetrics.ptPerEm
  let maxDistFromAxis := max (height - axisHeight) (depth + axisHeight)
  let totalHeight := max (Em.mk (Em.roundDiv (maxDistFromAxis.raw * 901) 500))
    (2 * maxDistFromAxis - delimiterExtend)
  makeCustomSizedDelim delim totalHeight true o mode classes

end LeAnTeX
