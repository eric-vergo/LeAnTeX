/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Layout.Stretchy
import LeAnTeX.Layout.Builders.Scripts

/-!
# Accents and radicals

Accents over and under their base (TeXbook Appendix G rule 12, with the base's skew), wide and
stretchy accents as SVG images, and square roots with an SVG surd (rule 11), as KaTeX builds
them.

## Main definitions

* `buildAccent`: `\hat`, `\vec`, `\widehat`, `\overrightarrow`, the text accents `\'` …, with
  scripts when the base is a single character.
* `buildAccentUnder`: `\underrightarrow`, `\utilde` and friends.
* `makeSqrtImage`, `buildSqrt`: the surd sized to the radicand, and `\sqrt[n]{…}`.

## References

* KaTeX's `src/functions/accent.ts`, `accentunder.ts`, `sqrt.ts`, `src/delimiter.ts`
  (`makeSqrtImage`) and `src/svgGeometry.ts` (`sqrtPath`) (MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- The single symbol at the bottom of a chain of one-child boxes (`getBaseSymbol`). -/
def getBaseSymbol : Nat → Box → Option Box
  | 0, _ => none
  | fuel + 1, b =>
    if b.isSymbol then some b
    else if b.children.size == 1 then getBaseSymbol fuel b.children[0]! else none

/-- An accent over its base; with `scripts`, the base's sub- and superscripts, which a
single-character base takes beside the accent (KaTeX's `accent` builder). -/
def buildAccent (ctx : BuildCtx) (mode : Mode) (label : String) (isStretchy isShifty : Bool)
    (base : Node) (scripts : Option (Option Node × Option Node)) (o : Options) :
    BuildM Box := do
  let supSubGroup ← match scripts with
    | some (sup, sub) => do
      some <$> buildSupsub ctx (some base) sup sub o
    | none => pure none
  let body ← ctx.group base o.havingCrampedStyle none
  let mustShift := isShifty && isCharacterBox base
  let skew := if mustShift then ((getBaseSymbol (1 <<< 16) body).map (·.skew)).getD 0 else 0
  let accentBelow := label == "\\c"
  let mut clearance := if accentBelow then body.height + body.depth
    else min body.height o.fontMetrics.xHeight
  let accentBody ← do
    if !isStretchy then
      let (accent, width) ← do
        if label == "\\vec" then pure (← staticSvg "vec" o, (0.471 : Em))
        else
          let a ← makeOrd false mode label o
          let a := { a with italic := some 0 }
          if accentBelow then clearance := clearance + a.depth
          pure (a, a.width.getD 0)
      let mut accentBody := makeSpan #["accent-body"] #[accent]
      let accentFull := label == "\\textcircled"
      if accentFull then
        accentBody := accentBody.addClass "accent-full"
        clearance := body.height
      let left := if accentFull then skew else skew - Em.mk (Em.roundDiv width.raw 2)
      accentBody := accentBody.setStyle "left" left
      if accentFull then accentBody := accentBody.setStyleStr "top" ".2em"
      makeVList (.firstBaseline #[.elem { elem := body }, .kern (-clearance),
        .elem { elem := accentBody }])
    else
      let img ← stretchySvg label (some base) o
      let wrapperStyle : Css := if skew > 0 then
          (({} : Css).set "width" (.str s!"calc(100% - {(2 * skew).css})")).setEm "marginLeft"
            (2 * skew)
        else {}
      makeVList (.firstBaseline #[.elem { elem := body },
        .elem { elem := img, wrapperClasses := #["svg-align"], wrapperStyle }])
  let accentWrap := makeSpan #["mord", "katex-accent"] #[accentBody] (some o)
  match supSubGroup with
  | some s =>
    let children := if s.children.isEmpty then #[accentWrap] else s.children.set! 0 accentWrap
    let classes := if s.classes.isEmpty then #["mord"] else s.classes.set! 0 "mord"
    return { s with children, height := max accentWrap.height s.height, classes }
  | none => return accentWrap

/-- A stretchy accent under its base. -/
def buildAccentUnder (ctx : BuildCtx) (label : String) (base : Node) (o : Options) :
    BuildM Box := do
  let inner ← ctx.group base o none
  let body ← stretchySvg label (some base) o
  let kern : Em := if label == "\\utilde" then 0.12 else 0
  let vlist ← makeVList (.top inner.height #[.elem { elem := body, wrapperClasses :=
    #["svg-align"] }, .kern kern, .elem { elem := inner }])
  return makeSpan #["mord", "accentunder"] #[vlist] (some o)

/-- The padding above a surd, in viewBox units and in em. -/
def vbPad : Int := 80

/-- A number of SVG units as JavaScript prints it. -/
def svgNum (x : Em) : String := x.decimal 5

/-- The path of a surd (`sqrtPath`): one of the font's five sizes, or the tall surd with a
vertical segment that reaches `viewBoxHeight`; `extraVinculum` thickens the rule (in em). -/
def sqrtPath (size : String) (extraVinculum : Em) (viewBoxHeight : Int) : String :=
  let ev := extraVinculum * 1000
  let e := svgNum ev
  let p (n : Int) := svgNum (Em.ofInt n + ev)
  let hp := toString vbPad
  let r (k : Em) := svgNum (ev / k)
  match size with
  | "sqrtMain" =>
    s!"M95,{p (622 + vbPad)}\nc-2.7,0,-7.17,-2.7,-13.5,-8c-5.8,-5.3,-9.5,-10,-9.5,-14\n" ++
    "c0,-2,0.3,-3.3,1,-4c1.3,-2.7,23.83,-20.7,67.5,-54\n" ++
    "c44.2,-33.3,65.8,-50.3,66.5,-51c1.3,-1.3,3,-2,5,-2c4.7,0,8.7,3.3,12,10\n" ++
    "s173,378,173,378c0.7,0,35.3,-71,104,-213c68.7,-142,137.5,-285,206.5,-429\n" ++
    s!"c69,-144,104.5,-217.7,106.5,-221\nl{r 2.075} -{e}\nc5.3,-9.3,12,-14,20,-14\n" ++
    s!"H400000v{p 40}H845.2724\n" ++
    "s-225.272,467,-225.272,467s-235,486,-235,486c-2.7,4.7,-9,7,-19,7\n" ++
    "c-6,0,-10,-1,-12,-3s-194,-422,-194,-422s-65,47,-65,47z\n" ++
    s!"M{p 834} {hp}h400000v{p 40}h-400000z"
  | "sqrtSize1" =>
    s!"M263,{p (601 + vbPad)}c0.7,0,18,39.7,52,119\n" ++
    "c34,79.3,68.167,158.7,102.5,238c34.3,79.3,51.8,119.3,52.5,120\n" ++
    s!"c340,-704.7,510.7,-1060.3,512,-1067\nl{r 2.084} -{e}\nc4.7,-7.3,11,-11,19,-11\n" ++
    s!"H40000v{p 40}H1012.3\n" ++
    "s-271.3,567,-271.3,567c-38.7,80.7,-84,175,-136,283c-52,108,-89.167,185.3,-111.5,232\n" ++
    "c-22.3,46.7,-33.8,70.3,-34.5,71c-4.7,4.7,-12.3,7,-23,7s-12,-1,-12,-1\n" ++
    "s-109,-253,-109,-253c-72.7,-168,-109.3,-252,-110,-252c-10.7,8,-22,16.7,-34,26\n" ++
    "c-22,17.3,-33.3,26,-34,26s-26,-26,-26,-26s76,-59,76,-59s76,-60,76,-60z\n" ++
    s!"M{p 1001} {hp}h400000v{p 40}h-400000z"
  | "sqrtSize2" =>
    s!"M983 {p (10 + vbPad)}\nl{r 3.13} -{e}\nc4,-6.7,10,-10,18,-10 H400000v{p 40}\n" ++
    "H1013.1s-83.4,268,-264.1,840c-180.7,572,-277,876.3,-289,913c-4.7,4.7,-12.7,7,-24,7\n" ++
    "s-12,0,-12,0c-1.3,-3.3,-3.7,-11.7,-7,-25c-35.3,-125.3,-106.7,-373.3,-214,-744\n" ++
    "c-10,12,-21,25,-33,39s-32,39,-32,39c-6,-5.3,-15,-14,-27,-26s25,-30,25,-30\n" ++
    "c26.7,-32.7,52,-63,76,-91s52,-60,52,-60s208,722,208,722\n" ++
    "c56,-175.3,126.3,-397.3,211,-666c84.7,-268.7,153.8,-488.2,207.5,-658.5\n" ++
    "c53.7,-170.3,84.5,-266.8,92.5,-289.5z\n" ++
    s!"M{p 1001} {hp}h400000v{p 40}h-400000z"
  | "sqrtSize3" =>
    s!"M424,{p (2398 + vbPad)}\n" ++
    "c-1.3,-0.7,-38.5,-172,-111.5,-514c-73,-342,-109.8,-513.3,-110.5,-514\n" ++
    "c0,-2,-10.7,14.3,-32,49c-4.7,7.3,-9.8,15.7,-15.5,25c-5.7,9.3,-9.8,16,-12.5,20\n" ++
    "s-5,7,-5,7c-4,-3.3,-8.3,-7.7,-13,-13s-13,-13,-13,-13s76,-122,76,-122s77,-121,77,-121\n" ++
    "s209,968,209,968c0,-2,84.7,-361.7,254,-1079c169.3,-717.3,254.7,-1077.7,256,-1081\n" ++
    s!"l{r 4.223} -{e}c4,-6.7,10,-10,18,-10 H400000\nv{p 40}H1014.6\n" ++
    "s-87.3,378.7,-272.6,1166c-185.3,787.3,-279.3,1182.3,-282,1185\nc-2,6,-10,9,-24,9\n" ++
    s!"c-8,0,-12,-0.7,-12,-2z M{p 1001} {hp}\nh400000v{p 40}h-400000z"
  | "sqrtSize4" =>
    s!"M473,{p (2713 + vbPad)}\n" ++
    s!"c339.3,-1799.3,509.3,-2700,510,-2702 l{r 5.298} -{e}\n" ++
    s!"c3.3,-7.3,9.3,-11,18,-11 H400000v{p 40}H1017.7\n" ++
    "s-90.5,478,-276.2,1466c-185.7,988,-279.5,1483,-281.5,1485c-2,6,-10,9,-24,9\n" ++
    "c-8,0,-12,-0.7,-12,-2c0,-1.3,-5.3,-32,-16,-92c-50.7,-293.3,-119.7,-693.3,-207,-1200\n" ++
    "c0,-1.3,-5.3,8.7,-16,30c-10.7,21.3,-21.3,42.7,-32,64s-16,33,-16,33s-26,-26,-26,-26\n" ++
    "s76,-153,76,-153s77,-151,77,-151c0.7,0.7,35.7,202,105,604c67.3,400.7,102,602.7,104,\n" ++
    s!"606zM{p 1001} {hp}h400000v{p 40}H1017.7z"
  | _ =>
    let vert := svgNum (Em.ofInt (viewBoxHeight - 54 - vbPad) - ev)
    s!"M702 {p vbPad}H400000{p 40}\n" ++
    s!"H742v{vert}l-4 4-4 4c-.667.7 -2 1.5-4 2.5s-4.167 1.833-6.5 2.5-5.5 1-9.5 1\n" ++
    "h-12l-28-84c-16.667-52-96.667 -294.333-240-727l-212 -643 -85 170\n" ++
    "c-4-3.333-8.333-7.667-13 -13l-13-13l77-155 77-156c66 199.333 139 419.667\n" ++
    s!"219 661 l218 661zM702 {hp}H400000v{p 40}H742z"

/-- A surd of the given SVG size in a clipping span (`sqrtSvg`). -/
def sqrtSvg (name : String) (height : Em) (viewBoxHeight : Int) (extraVinculum : Em)
    (o : Options) : Box :=
  let svg : Box :=
    { kind := .svg #[.path name (some (sqrtPath name extraVinculum viewBoxHeight))]
      attrs := #[("width", "400em"), ("height", height.css),
        ("viewBox", s!"0 0 400000 {viewBoxHeight}"),
        ("preserveAspectRatio", "xMinYMin slice")] }
  makeSvgSpan #["hide-tail"] #[svg] o

/-- The surd for a radicand of the given height: its span, the thickness of its rule and its
advance (`makeSqrtImage`). -/
def makeSqrtImage (height : Em) (o : Options) : BuildM (Box × Em × Em) := do
  let o' := o.havingBaseSizing
  let delim ← traverseSequence "\\surd" (height * o'.sizeMultiplier) stackLargeSequence o'
  let mut sm := o'.sizeMultiplier
  let ev := max 0 (o.minRuleThickness - o.fontMetrics.sqrtRuleThickness)
  let (span, spanHeight, texHeight, advance) ← match delim with
    | .small _ =>
      let vbh := (1000 + ev * 1000 + Em.ofInt vbPad).round
      sm := if height < 1.0 then 1.0 else if height < 1.4 then 0.7 else sm
      let spanHeight := (1 + ev + 0.08) / sm
      let span := (sqrtSvg "sqrtMain" spanHeight vbh ev o).setStyleStr "minWidth" "0.853em"
      pure (span, spanHeight, (1 + ev) / sm, (0.833 : Em) / sm)
    | .large s =>
      let maxH := sizeToMaxHeight[s]!
      let vbh := ((1000 + Em.ofInt vbPad) * maxH).round
      let spanHeight := (maxH + ev + 0.08) / sm
      let span := (sqrtSvg s!"sqrtSize{s}" spanHeight vbh ev o).setStyleStr "minWidth" "1.02em"
      pure (span, spanHeight, (maxH + ev) / sm, (1.0 : Em) / sm)
    | .stack =>
      let spanHeight := height + ev + 0.08
      let vbh := (height * 1000 + ev).floor + vbPad
      let span := (sqrtSvg "sqrtTall" spanHeight vbh ev o).setStyleStr "minWidth" "0.742em"
      pure (span, spanHeight, height + ev, (1.056 : Em))
  let span := { span with height := texHeight }.setStyle "height" spanHeight
  return (span, (o.fontMetrics.sqrtRuleThickness + ev) * sm, advance)

/-- `\sqrt{…}` and `\sqrt[n]{…}` (TeXbook rule 11). -/
def buildSqrt (ctx : BuildCtx) (body : Node) (index : Option Node) (o : Options) :
    BuildM Box := do
  let mut inner ← ctx.group body o.havingCrampedStyle none
  if inner.height == 0 then inner := { inner with height := o.fontMetrics.xHeight }
  inner := wrapFragment inner o
  let theta := o.fontMetrics.defaultRuleThickness
  let phi := if o.style.id < MathStyle.text.id then o.fontMetrics.xHeight else theta
  let mut lineClearance := theta + phi / 4
  let minDelimiterHeight := inner.height + inner.depth + lineClearance + theta
  let (img, ruleWidth, advanceWidth) ← makeSqrtImage minDelimiterHeight o
  let delimDepth := img.height - ruleWidth
  if delimDepth > inner.height + inner.depth + lineClearance then
    lineClearance := Em.mk (Em.roundDiv
      (lineClearance + delimDepth - inner.height - inner.depth).raw 2)
  let imgShift := img.height - inner.height - lineClearance - ruleWidth
  inner := inner.setStyle "paddingLeft" advanceWidth
  let body ← makeVList (.firstBaseline #[.elem { elem := inner, wrapperClasses := #["svg-align"] },
    .kern (-(inner.height + imgShift)), .elem { elem := img }, .kern ruleWidth])
  match index with
  | none => return makeSpan #["mord", "sqrt"] #[body] (some o)
  | some idx =>
    let o' := o.havingStyle MathStyle.scriptscript
    let rootm ← ctx.group idx o' (some o)
    let toShift := 0.6 * (body.height - body.depth)
    let rootVList ← makeVList (.shift (-toShift) #[.elem { elem := rootm }])
    return makeSpan #["mord", "sqrt"] #[makeSpan #["katex-root"] #[rootVList], body] (some o)

/-- A line break: an `mspace`, marked as a new line for `\\` and `\newline`, with the extra
space below. -/
def buildCr (newLine : Bool) (size : Option Measurement) (o : Options) : BuildM Box := do
  let span := makeSpan #["mspace"] #[] (some o)
  if !newLine then return span
  let span := span.addClass "katex-newline"
  match size with
  | some s => return span.setStyle "marginTop" (← calculateSize s o)
  | none => return span

end LeAnTeX
