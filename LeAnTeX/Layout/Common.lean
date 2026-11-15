/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Layout.Box
import LeAnTeX.Layout.Options
import LeAnTeX.Parse.Node

/-!
# Building blocks of the layout

The layout's monad and KaTeX's `buildCommon`: symbols in the right font with their metrics,
spans sized from their children, vertical lists, glue, and the font tables.

## Main definitions

* `BuildError`, `BuildM`: errors (KaTeX's own, or a construct LeAnTeX does not lay out yet) and
  the strict-mode warnings of a layout.
* `makeSymbol`, `mathsym`, `makeOrd`: a symbol node for a character (KaTeX's functions of the
  same names).
* `makeSpan`, `makeFragment`, `makeLineSpan`, `wrapFragment`, `tryCombineChars`.
* `VListParam`, `makeVList`: KaTeX's vertical list, positioned five ways.
* `calculateSize`, `makeGlue`: a TeX dimension in em, and a space.

## References

* KaTeX's `src/buildCommon.ts`, `src/domTree.ts` (`SymbolNode`), `src/units.ts`,
  `src/unicodeScripts.ts` and `src/strict.ts` (MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- Why a layout failed. -/
inductive BuildError where
  /-- An error KaTeX raises too (a `ParseError` or a JavaScript error). -/
  | katex (e : KError)
  /-- A construct LeAnTeX does not lay out yet (the parse node type or the detail). -/
  | unsupported (what : String)
  deriving Inhabited

/-- The layout's monad: errors, and the strict-mode warnings raised so far. -/
abbrev BuildM := StateT (Array Warning) (Except BuildError)

/-- Fail with KaTeX's `ParseError` without a location. -/
def throwParse {α : Type} (msg : String) : BuildM α := throw (.katex (.parse msg .absent))

/-- Fail with a JavaScript `Error`, as KaTeX does for an internal inconsistency. -/
def throwInternal {α : Type} (msg : String) : BuildM α := throw (.katex (.internal "Error" msg))

/-- Fail for a construct not laid out yet. -/
def throwUnsupported {α : Type} (what : String) : BuildM α := throw (.unsupported what)

/-- KaTeX's `handleStrict` with `report: true` and no location. -/
def strictReportM (strict : Strict) (code msg : String) : BuildM Unit := do
  match strictReport strict code msg .absent with
  | .ok (some w) => modify (·.push w)
  | .ok none => pure ()
  | .error e => throw (.katex e)

/-! ### Symbols -/

/-- The writing system of a code point that KaTeX supports in text, if any
(`scriptFromCodepoint`). -/
def scriptFromCodepoint (cp : Nat) : Option String :=
  let blocks : Array (String × Nat × Nat) := #[
    ("latin", 0x0100, 0x024f), ("latin", 0x0300, 0x036f), ("cyrillic", 0x0400, 0x04ff),
    ("armenian", 0x0530, 0x058f), ("brahmic", 0x0900, 0x109f), ("georgian", 0x10a0, 0x10ff),
    ("cjk", 0x3000, 0x30ff), ("cjk", 0x4e00, 0x9faf), ("cjk", 0xff00, 0xff60),
    ("hangul", 0xac00, 0xd7af)]
  (blocks.find? fun (_, a, b) => a ≤ cp && cp ≤ b).map (·.1)

/-- A symbol node (KaTeX's `SymbolNode` constructor): a class for the writing system's fallback
font, and the dotless i for an accented i. -/
def newSymbol (text font : String) (height depth italic skew width : Em)
    (classes : Array String) : Box := Id.run do
  let mut classes := classes
  if let some c := text.toList.head? then
    if let some s := scriptFromCodepoint (utf16First c) then
      classes := classes.push (s ++ "_fallback")
  let text := match text with
    | "î" => "ı̂" | "ï" => "ı̈" | "í" => "ı́"
    | "ì" => "ı̀" | t => t
  return { kind := .symbol text font, classes, height, depth, italic := some italic, skew,
           width := some width }

/-- A symbol's replacement character and its metrics (`lookupSymbol`). -/
def lookupSymbol (value font : String) (mode : Mode) : BuildM (String × Option CharMetrics) := do
  let value := match (Tables.symbolsIn mode)[value]? with
    | some { replace := some r, .. } => r
    | _ => value
  if !hasFontMetrics font then throwInternal s!"Font metrics not found for font: {font}."
  return (value, charMetrics value font mode)

/-- Classes and style that `options` gives every node: `mtight` in script styles, the
colour. -/
def Box.withOptions (b : Box) (o : Options) : Box :=
  let b := if o.style.isTight then b.addClass "mtight" else b
  match o.getColor with
  | some c => b.setStyleStr "color" c
  | none => b

/-- A symbol in a font, with its metrics (`makeSymbol`). -/
def makeSymbol (value font : String) (mode : Mode) (o : Options)
    (classes : Array String := #[]) : BuildM Box := do
  let (value, metrics) ← lookupSymbol value font mode
  let node ← match metrics with
    | some m =>
      let italic := if mode == .text || o.font == "mathit" then 0 else m.italic
      pure (newSymbol value font m.height m.depth italic m.skew m.width classes)
    | none =>
      strictReportM o.strict "symbolNotInFont"
        s!"No character metrics for '{value}' in style '{font}' and mode '{mode.name}'"
      pure (newSymbol value font 0 0 0 0 0 classes)
  let node := { node with maxFontSize := o.sizeMultiplier }
  return node.withOptions o

/-- The font a symbol table entry names (`main` or `ams`). -/
def symbolFont (mode : Mode) (value : String) : Option Font :=
  ((Tables.symbolsIn mode)[value]?).map (·.font)

/-- A symbol in Main-Regular or AMS-Regular, as relations, binary operators, delimiters and
punctuation are drawn (`mathsym`). -/
def mathsym (value : String) (mode : Mode) (o : Options) (classes : Array String := #[]) :
    BuildM Box := do
  if o.font == "boldsymbol" && ((← lookupSymbol value "Main-Bold" mode).2).isSome then
    makeSymbol value "Main-Bold" mode o (classes.push "mathbf")
  else if value == "\\" || symbolFont mode value == some .main then
    makeSymbol value "Main-Regular" mode o classes
  else if (Tables.symbolsIn mode)[value]?.isNone then
    -- KaTeX reads `.font` of a missing entry and fails
    throwInternal "Cannot read properties of undefined (reading 'font')"
  else makeSymbol value "AMS-Regular" mode o (classes.push "amsrm")

/-- The font and class of a `\boldsymbol` character (`boldSymbol`). -/
def boldSymbol (value : String) (mode : Mode) (isMathord : Bool) : BuildM (String × String) := do
  if isMathord && ((← lookupSymbol value "Math-BoldItalic" mode).2).isSome then
    return ("Math-BoldItalic", "boldsymbol")
  return ("Main-Bold", "mathbf")

/-- The metric font of a math font command (`fontMap`). -/
def fontMapName : String → Option String
  | "mathbf" => some "Main-Bold"
  | "mathrm" => some "Main-Regular"
  | "textit" => some "Main-Italic"
  | "mathit" => some "Main-Italic"
  | "mathnormal" => some "Math-Italic"
  | "mathsfit" => some "SansSerif-Italic"
  | "mathbb" => some "AMS-Regular"
  | "mathcal" => some "Caligraphic-Regular"
  | "mathfrak" => some "Fraktur-Regular"
  | "mathscr" => some "Script-Regular"
  | "mathsf" => some "SansSerif-Regular"
  | "mathtt" => some "Typewriter-Regular"
  | _ => none

/-- The metric font of a text font family, weight and shape (`retrieveTextFontName`). -/
def retrieveTextFontName (family weight shape : String) : String :=
  let base := match family with
    | "amsrm" => "AMS"
    | "textrm" => "Main"
    | "textsf" => "SansSerif"
    | "texttt" => "Typewriter"
    | f => f
  let st := if weight == "textbf" && shape == "textit" then "BoldItalic"
    else if weight == "textbf" then "Bold"
    else if shape == "textit" then "Italic"
    else "Regular"
  base ++ "-" ++ st

/-- The font and class of a character from the Mathematical Alphanumeric Symbols block
(`wideCharacterFont`): `(font, math class, text class)`, empty when KaTeX has no font. -/
def wideCharacterFont (text : String) : BuildM (String × String × String) := do
  let cp := (text.toList.head?.map (·.val.toNat)).getD 0
  let boldUpright := ("Main-Bold", "mathbf", "textbf")
  let italic := ("Math-Italic", "mathnormal", "textit")
  let boldItalic := ("Main-BoldItalic", "boldsymbol", "boldsymbol")
  let script := ("Script-Regular", "mathscr", "textscr")
  let noFont := ("", "", "")
  let fraktur := ("Fraktur-Regular", "mathfrak", "textfrak")
  let doubleStruck := ("AMS-Regular", "mathbb", "textbb")
  let boldFraktur := ("Fraktur-Regular", "mathboldfrak", "textboldfrak")
  let sansSerif := ("SansSerif-Regular", "mathsf", "textsf")
  let boldSansSerif := ("SansSerif-Bold", "mathboldsf", "textboldsf")
  let italicSansSerif := ("SansSerif-Italic", "mathitsf", "textitsf")
  let monospace := ("Typewriter-Regular", "mathtt", "texttt")
  let letters := #[boldUpright, boldUpright, italic, italic, boldItalic, boldItalic, script,
    noFont, noFont, noFont, fraktur, fraktur, doubleStruck, doubleStruck, boldFraktur,
    boldFraktur, sansSerif, sansSerif, boldSansSerif, boldSansSerif, italicSansSerif,
    italicSansSerif, noFont, noFont, monospace, monospace]
  let numerals := #[boldUpright, noFont, sansSerif, boldSansSerif, monospace]
  if 0x1D400 ≤ cp && cp < 0x1D6A4 then return letters.getD ((cp - 0x1D400) / 26) default
  else if 0x1D7CE ≤ cp && cp ≤ 0x1D7FF then return numerals.getD ((cp - 0x1D7CE) / 10) default
  else if cp == 0x1D6A5 || cp == 0x1D6A6 then return letters.getD 0 default
  else if 0x1D6A6 < cp && cp < 0x1D7CE then return noFont
  else throwParse s!"Unsupported character: {text}"

/-- The multi-character text ligatures (`ligatures`). -/
def isLigature (text : String) : Bool := ["--", "---", "``", "''"].contains text

/-- A document fragment of the given children, sized from them. -/
def sizeFromChildren (b : Box) : Box :=
  let (h, d, m) := b.children.foldl (init := ((0 : Em), (0 : Em), (0 : Em)))
    fun (h, d, m) c => (max h c.height, max d c.depth, max m c.maxFontSize)
  { b with height := h, depth := d, maxFontSize := m }

/-- A document fragment (`makeFragment`). -/
def makeFragment (children : Array Box) : Box :=
  sizeFromChildren { kind := .fragment, children }

/-- A mathord, textord or spacing symbol in its font (`makeOrd`). `isMathord` tells a mathord
from the others. -/
def makeOrd (isMathord : Bool) (mode : Mode) (text : String) (o : Options) : BuildM Box := do
  let classes := #["mord"]
  let useFont := mode == .math || (mode == .text && o.font != "")
  let fontOrFamily := if useFont then o.font else o.fontFamily
  let mut wide : String × String × String := ("", "", "")
  if (text.toList.head?.map utf16First) == some 0xD835 then
    wide ← wideCharacterFont text
  if wide.1 != "" then
    let cls := if mode == .math then wide.2.1 else wide.2.2
    return ← makeSymbol text wide.1 mode o (classes.push cls)
  if fontOrFamily != "" then
    let (fontName, fontClasses) ← do
      if fontOrFamily == "boldsymbol" then
        let (f, c) ← boldSymbol text mode isMathord
        pure (f, #[c])
      else if useFont then
        match fontMapName o.font with
        | some f => pure (f, #[o.font])
        | none => throwInternal "Cannot read properties of undefined (reading 'fontName')"
      else
        pure (retrieveTextFontName o.fontFamily o.fontWeight o.fontShape,
          #[o.fontFamily, o.fontWeight, o.fontShape])
    if ((← lookupSymbol text fontName mode).2).isSome then
      return ← makeSymbol text fontName mode o (classes ++ fontClasses)
    else if isLigature text && fontName.startsWith "Typewriter" then
      let mut parts := #[]
      for c in text.toList do
        parts := parts.push (← makeSymbol c.toString fontName mode o (classes ++ fontClasses))
      return makeFragment parts
  if isMathord then
    makeSymbol text "Math-Italic" mode o (classes.push "mathnormal")
  else
    match symbolFont mode text with
    | some .ams =>
      let fontName := retrieveTextFontName "amsrm" o.fontWeight o.fontShape
      makeSymbol text fontName mode o (classes ++ #["amsrm", o.fontWeight, o.fontShape])
    | _ =>
      let fontName := retrieveTextFontName "textrm" o.fontWeight o.fontShape
      makeSymbol text fontName mode o (classes ++ #[o.fontWeight, o.fontShape])

/-- Whether two adjacent symbols may be merged into one run (`canCombine`). Classes are compared
without the empty ones, as KaTeX's `createClass` does. -/
def canCombine (prev next : Box) : Bool :=
  let cls (b : Box) := b.classes.filter (· != "")
  cls prev == cls next && prev.skew == next.skew && prev.maxFontSize == next.maxFontSize &&
    !(prev.italicOr0 != 0 && prev.hasClass "mathnormal") &&
    !(prev.classes.size == 1 &&
      (prev.classes[0]? == some "mbin" || prev.classes[0]? == some "mord")) &&
    prev.style.sameAs next.style

/-- Merge runs of combinable symbols (`tryCombineChars`): the text is joined, height and depth
are the maxima, the italic correction is the last one's. -/
def tryCombineChars (xs : Array Box) : Array Box := Id.run do
  let mut out : Array Box := #[]
  for x in xs do
    match out.back? with
    | some p =>
      if p.isSymbol && x.isSymbol && canCombine p x then
        let kind := match p.kind with
          | .symbol t f => .symbol (t ++ x.text) f
          | k => k
        let merged : Box :=
          { p with kind, height := max p.height x.height, depth := max p.depth x.depth,
                   italic := x.italic }
        out := out.pop.push merged
      else out := out.push x
    | none => out := out.push x
  return out

/-- A span with classes, children, the options' classes and colour, and a style, sized from its
children (`makeSpan`). -/
def makeSpan (classes : Array String := #[]) (children : Array Box := #[])
    (o : Option Options := none) (style : Css := {}) : Box :=
  let b : Box := { classes, children, style }
  let b := match o with
    | some o => b.withOptions o
    | none => b
  sizeFromChildren b

/-- A span holding an SVG image; it is not sized from its children (`makeSvgSpan`). -/
def makeSvgSpan (classes : Array String) (children : Array Box) (o : Options)
    (style : Css := {}) : Box :=
  ({ classes, children, style } : Box).withOptions o

/-- A rule as an empty span with a bottom border (`makeLineSpan`). -/
def makeLineSpan (className : String) (o : Options) (thickness : Option Em := none) : Box :=
  let t := match thickness with
    | some t => if t == 0 then o.fontMetrics.defaultRuleThickness else t
    | none => o.fontMetrics.defaultRuleThickness
  let h := max t o.minRuleThickness
  let line := makeSpan #[className] #[] (some o)
  { line with height := h, maxFontSize := 1 }.setStyle "borderBottomWidth" h

/-- A fragment as a span, so that classes and styles can be set on it (`wrapFragment`). -/
def wrapFragment (b : Box) (o : Options) : Box :=
  if b.isFragment then makeSpan #[] #[b] (some o) else b

/-! ### Vertical lists -/

/-- An element of a vertical list, with how far it is shifted down (for `individualShift`),
the margins and the classes and style of the span that wraps it. -/
structure VElem where
  /-- The element. -/
  elem : Box
  /-- How far it is shifted down (`individualShift` only). -/
  shift : Em := 0
  /-- Left margin of the wrapper. -/
  marginLeft : Option Em := none
  /-- Right margin of the wrapper. -/
  marginRight : Option Em := none
  /-- Classes of the wrapper. -/
  wrapperClasses : Array String := #[]
  /-- Style of the wrapper. -/
  wrapperStyle : Css := {}
  deriving Inhabited

/-- An element or a kern of a vertical list, bottom first. -/
inductive VChild where
  /-- An element. -/
  | elem (e : VElem)
  /-- A vertical kern. -/
  | kern (size : Em)
  deriving Inhabited

/-- How a vertical list is positioned (KaTeX's `VListParam`). -/
inductive VListParam where
  /-- Each element shifted down by its own `shift`. -/
  | individualShift (children : Array VElem)
  /-- The top of the list at the given height. -/
  | top (height : Em) (children : Array VChild)
  /-- The bottom of the list at the given depth. -/
  | bottom (depth : Em) (children : Array VChild)
  /-- The baseline of the first element shifted down by the given amount. -/
  | shift (amount : Em) (children : Array VChild)
  /-- The baseline at the first element's baseline. -/
  | firstBaseline (children : Array VChild)

/-- The children with kerns between them and the depth of the list
(`getVListChildrenAndDepth`). -/
def vlistChildrenAndDepth : VListParam → BuildM (Array VChild × Em)
  | .individualShift cs => do
    let some c0 := cs[0]? | throwInternal "Cannot read properties of undefined (reading 'shift')"
    let depth := -c0.shift - c0.elem.depth
    let mut out := #[VChild.elem c0]
    let mut currPos := depth
    for i in [1:cs.size] do
      let some c := cs[i]? | break
      let some p := cs[i - 1]? | break
      let diff := -c.shift - currPos - c.elem.depth
      let size := diff - (p.elem.height + p.elem.depth)
      currPos := currPos + diff
      out := out.push (.kern size) |>.push (.elem c)
    return (out, depth)
  | .top h cs =>
    let bottom := cs.foldl (init := h) fun acc c => match c with
      | .kern s => acc - s
      | .elem e => acc - (e.elem.height + e.elem.depth)
    pure (cs, bottom)
  | .bottom d cs => pure (cs, -d)
  | .shift amount cs => do
    match (cs[0]? : Option VChild) with
    | some (.elem e) => pure (cs, -e.elem.depth - amount)
    | _ => throwInternal "First child must have type \"elem\"."
  | .firstBaseline cs => do
    match (cs[0]? : Option VChild) with
    | some (.elem e) => pure (cs, -e.elem.depth)
    | _ => throwInternal "First child must have type \"elem\"."

/-- A vertical list (`makeVList`): every element in a span with a strut taller than any element,
offset with `top` so that its baseline lands at its position. -/
def makeVList (p : VListParam) : BuildM Box := do
  let (children, depth) ← vlistChildrenAndDepth p
  let pstrutSize := children.foldl (init := (0 : Em)) (fun acc c => match c with
    | .elem e => max acc (max e.elem.maxFontSize e.elem.height)
    | .kern _ => acc) + 2
  let pstrut := (makeSpan #["pstrut"]).setStyle "height" pstrutSize
  let mut realChildren := #[]
  let mut minPos := depth
  let mut maxPos := depth
  let mut currPos := depth
  for c in children do
    match c with
    | .kern s => currPos := currPos + s
    | .elem e =>
      let mut wrap := makeSpan e.wrapperClasses #[pstrut, e.elem] none e.wrapperStyle
      wrap := wrap.setStyle "top" (-pstrutSize - currPos - e.elem.depth)
      if let some ml := e.marginLeft then wrap := wrap.setStyle "marginLeft" ml
      if let some mr := e.marginRight then wrap := wrap.setStyle "marginRight" mr
      realChildren := realChildren.push wrap
      currPos := currPos + e.elem.height + e.elem.depth
    minPos := min minPos currPos
    maxPos := max maxPos currPos
  let vlist := (makeSpan #["vlist"] realChildren).setStyle "height" maxPos
  let rows :=
    if minPos < 0 then
      let depthStrut := (makeSpan #["vlist"] #[makeSpan]).setStyle "height" (-minPos)
      let topStrut := makeSpan #["vlist-s"] #[newSymbol "\u200b" "" 0 0 0 0 0 #[]]
      #[makeSpan #["vlist-r"] #[vlist, topStrut], makeSpan #["vlist-r"] #[depthStrut]]
    else #[makeSpan #["vlist-r"] #[vlist]]
  let vtable := makeSpan #["vlist-t"] rows
  let vtable := if rows.size == 2 then vtable.addClass "vlist-t2" else vtable
  return { vtable with height := maxPos, depth := -minPos }

/-! ### Dimensions -/

/-- TeX points per unit, as a ratio (`ptPerUnit`). -/
def ptPerUnit : String → Option (Int × Int)
  | "pt" => some (1, 1)
  | "mm" => some (7227, 2540)
  | "cm" => some (7227, 254)
  | "in" => some (7227, 100)
  | "bp" => some (803, 800)
  | "pc" => some (12, 1)
  | "dd" => some (1238, 1157)
  | "cc" => some (14856, 1157)
  | "nd" => some (685, 642)
  | "nc" => some (1370, 107)
  | "sp" => some (1, 65536)
  | "px" => some (803, 800)
  | _ => none

/-- A dimension in em at the current size (`calculateSize`), capped at `maxSize`. -/
def calculateSize (m : Measurement) (o : Options) : BuildM Em := do
  let n := Em.ofFloat m.number
  let fm := o.fontMetrics
  let size ← match ptPerUnit m.unit with
    | some (p, q) =>
      -- number × (p / q) / ptPerEm / sizeMultiplier
      pure (Em.mk (Em.roundDiv (n.raw * p * Em.unit) (q * fm.ptPerEm.raw)) / o.sizeMultiplier)
    | none =>
      if m.unit == "mu" then pure (Em.mk (Em.roundDiv (n.raw * fm.quad.raw) (18 * Em.unit)))
      else
        let uo := if o.style.isTight then o.havingStyle o.style.textOf else o
        let scale ← match m.unit with
          | "ex" => pure uo.fontMetrics.xHeight
          | "em" => pure uo.fontMetrics.quad
          | u => throwParse s!"Invalid unit: '{u}'"
        let scale := if o.style.isTight then scale * uo.sizeMultiplier / o.sizeMultiplier
          else scale
        pure (n * scale)
  return match o.maxSize with
    | some mx => min size mx
    | none => size

/-- A space of the given dimension: an empty `mspace` span with a right margin (`makeGlue`). -/
def makeGlue (m : Measurement) (o : Options) : BuildM Box := do
  let size ← calculateSize m o
  return (makeSpan #["mspace"] #[] (some o)).setStyle "marginRight" size

end LeAnTeX
