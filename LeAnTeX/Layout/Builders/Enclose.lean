/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Layout.Stretchy
import LeAnTeX.Layout.Html
import LeAnTeX.Parse.Functions

/-!
# Enclosures, extensible arrows and horizontal braces

The constructs that draw a stretchy element around, across, over or under their contents:
boxes and strikes (`\fbox`, `\boxed`, `\colorbox`, `\fcolorbox`, `\cancel`, `\bcancel`,
`\xcancel`, `\sout`, `\angl`, `\phase`), the extensible arrows with labels above and below
(`\xrightarrow` and friends, and the horizontal arrows of `{CD}`), and the horizontal braces and
brackets (`\overbrace`, `\underbrace`, `\overbracket`, `\underbracket`) with their notes.

## Main definitions

* `stretchyEnclose`: the box, border or strike lines of an enclosure.
* `buildEnclose`: an enclosure.
* `buildXArrow`: an extensible arrow.
* `buildHorizBrace`: a horizontal brace, with the note a script puts beyond it.

## References

* KaTeX's `src/functions/enclose.ts`, `src/functions/arrow.ts`, `src/functions/horizBrace.ts`,
  `src/stretchy.ts` (`stretchyEnclose`) and `src/svgGeometry.ts` (`phasePath`) (MIT licence,
  see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- The image of an enclosure (`stretchyEnclose`): a bordered or filled span for the boxes and
`\angl`, an SVG image of one or two diagonal lines for the strikes, as tall as the contents with
the padding. `label` is the command without its backslash. -/
def stretchyEnclose (inner : Box) (label : String) (topPad bottomPad : Em) (o : Options) : Box :=
  let totalHeight := inner.height + inner.depth + topPad + bottomPad
  let img :=
    if ["fbox", "color", "angl"].any (label.contains ·) then
      let img := makeSpan #["katex-stretchy", label] #[] (some o)
      match label == "fbox", o.getColor with
      | true, some c => img.setStyleStr "borderColor" c
      | _, _ => img
    else
      let down : SvgChild := .line #[("x1", "0"), ("y1", "0"), ("x2", "100%"), ("y2", "100%"),
        ("stroke-width", "0.046em")]
      let up : SvgChild := .line #[("x1", "0"), ("y1", "100%"), ("x2", "100%"), ("y2", "0"),
        ("stroke-width", "0.046em")]
      let lines := (if label == "bcancel" || label == "xcancel" then #[down] else #[]) ++
        (if label == "cancel" || label == "xcancel" then #[up] else #[])
      let svg : Box :=
        { kind := .svg lines, attrs := #[("width", "100%"), ("height", totalHeight.css)] }
      makeSvgSpan #[] #[svg] o
  { img with height := totalHeight }.setStyle "height" totalHeight

/-- The path of `\phase`'s angle (`phasePath`): a rule along the bottom and a slanted stroke up
to the top, `y` units tall. -/
def phasePath (y : Int) : String :=
  let x := Em.ofRatio y 2
  s!"M400000 {y} H0 L{x.decimal 5} 0 l65 45 L145 {y - 80} H400000z"

/-- An enclosure: `\fbox`, `\colorbox`, `\fcolorbox`, the strikes `\cancel`, `\bcancel`,
`\xcancel`, `\sout`, and `\angl`, `\phase` (KaTeX's `enclose` HTML builder). -/
def buildEnclose (ctx : BuildCtx) (label : String) (backgroundColor borderColor : Option String)
    (body : Node) (o : Options) : BuildM Box := do
  let mut inner := wrapFragment (← ctx.group body o none) o
  let label := (label.drop 1).toString
  let fm := o.fontMetrics
  let mut scale := o.sizeMultiplier
  -- the cancel package draws the lines of a single character steeper
  let isSingleChar := isCharacterBox body
  let isCancel := label.contains "cancel"
  let mut img : Box := {}
  let mut imgShift : Em := 0
  if label == "sout" then
    img := { makeSpan #["katex-stretchy", "katex-sout"] with
             height := fm.defaultRuleThickness / scale }
    imgShift := -(Em.mk (Em.roundDiv fm.xHeight.raw 2))
  else if label == "phase" then
    -- the dimensions of the steinmetz package
    let lineWeight ← calculateSize ⟨0.6, "pt"⟩ o
    let clearance ← calculateSize ⟨0.35, "ex"⟩ o
    -- a size change such as `\Huge` leaves the line's thickness alone
    scale := scale / o.havingBaseSizing.sizeMultiplier
    let angleHeight := inner.height + inner.depth + lineWeight + clearance
    inner := inner.setStyle "paddingLeft" (Em.mk (Em.roundDiv angleHeight.raw 2) + lineWeight)
    let viewBoxHeight := (angleHeight * scale * 1000).floor
    let svg : Box :=
      { kind := .svg #[.path "phase" (some (phasePath viewBoxHeight))]
        attrs := #[("width", "400em"), ("height", (Em.ofRatio viewBoxHeight 1000).css),
          ("viewBox", s!"0 0 400000 {viewBoxHeight}"),
          ("preserveAspectRatio", "xMinYMin slice")] }
    img := (makeSvgSpan #["hide-tail"] #[svg] o).setStyle "height" angleHeight
    imgShift := inner.depth + lineWeight + clearance
  else
    -- horizontal padding
    if isCancel then
      if !isSingleChar then inner := inner.addClass "cancel-pad"
    else if label == "angl" then inner := inner.addClass "anglpad"
    else inner := inner.addClass "boxpad"
    -- vertical padding
    let mut topPad : Em := 0
    let mut bottomPad : Em := 0
    let mut ruleThickness : Em := 0
    if label.contains "box" then
      ruleThickness := max fm.fboxrule o.minRuleThickness
      topPad := fm.fboxsep + (if label == "colorbox" then 0 else ruleThickness)
      bottomPad := topPad
    else if label == "angl" then
      ruleThickness := max fm.defaultRuleThickness o.minRuleThickness
      topPad := 4 * ruleThickness
      bottomPad := max 0 (0.25 - inner.depth)
    else
      topPad := if isSingleChar then 0.2 else 0
      bottomPad := topPad
    img := stretchyEnclose inner label topPad bottomPad o
    if label == "fbox" || label == "fcolorbox" then
      img := (img.setStyleStr "borderStyle" "solid").setStyle "borderWidth" ruleThickness
    else if label == "angl" && ruleThickness != 0.049 then
      img := (img.setStyle "borderTopWidth" ruleThickness).setStyle "borderRightWidth"
        ruleThickness
    imgShift := inner.depth + bottomPad
    if let some bg := backgroundColor then
      img := img.setStyleStr "backgroundColor" bg
      if let some bc := borderColor then img := img.setStyleStr "borderColor" bc
  let mut vlist ← if backgroundColor.isSome then
      -- the background behind the contents
      makeVList (.individualShift #[{ elem := img, shift := imgShift }, { elem := inner }])
    else
      -- the strike over the contents
      let classes := if isCancel || label == "phase" then #["svg-align"] else #[]
      makeVList (.individualShift #[{ elem := inner },
        { elem := img, shift := imgShift, wrapperClasses := classes }])
  -- the cancel lines add no height, and no width beyond a single character
  if isCancel then vlist := { vlist with height := inner.height, depth := inner.depth }
  if isCancel && !isSingleChar then return makeSpan #["mord", "cancel-lap"] #[vlist] (some o)
  return makeSpan #["mord"] #[vlist] (some o)

/-- An extensible arrow with its label above and the optional label below, in script style
with 2 mu of space from the arrow (amsmath's `\ext@arrow`; KaTeX's `xArrow` HTML builder). A
missing label (the horizontal `=` of `{CD}`) is an empty span. -/
def buildXArrow (ctx : BuildCtx) (label : String) (body : Option Node)
    (below : Option (Option Node)) (o : Options) : BuildM Box := do
  let style := o.style
  let arrowPrefix := if label.startsWith "\\x" then "x" else "cd"
  let upperGroup := (wrapFragment (← ctx.groupOpt body (o.havingStyle style.sup) (some o)) o)
    |>.addClass (arrowPrefix ++ "-arrow-pad")
  let lowerGroup ← match below with
    | some (some b) => do
      let g ← ctx.group b (o.havingStyle style.sub) (some o)
      pure (some ((wrapFragment g o).addClass (arrowPrefix ++ "-arrow-pad")))
    | _ => pure none
  let arrowBody ← stretchySvg label none o
  let axis := o.fontMetrics.axisHeight
  let half := Em.mk (Em.roundDiv arrowBody.height.raw 2)
  -- the middle of the arrow on the math axis
  let arrowShift := -axis + half
  let mut upperShift := -axis - half - 0.111
  if upperGroup.depth > 0.25 || label == "\\xleftequilibrium" then
    upperShift := upperShift - upperGroup.depth
  let upper : VElem := { elem := upperGroup, shift := upperShift }
  let arrow : VElem := { elem := arrowBody, shift := arrowShift, wrapperClasses := #["svg-align"] }
  let vlist ← match lowerGroup with
    | some lg =>
      let lowerShift := -axis + lg.height + half + 0.111
      makeVList (.individualShift #[upper, arrow, { elem := lg, shift := lowerShift }])
    | none => makeVList (.individualShift #[upper, arrow])
  return makeSpan #["mrel", "x-arrow"] #[vlist] (some o)

/-- A horizontal brace or bracket over or under its base, in display style at the base size;
with `note`, the superscript of an over-brace or the subscript of an under-brace, set beyond
it (KaTeX's `horizBrace` HTML builder, which also builds such a `supsub` node). -/
def buildHorizBrace (ctx : BuildCtx) (label : String) (isOver : Bool) (base : Node)
    (note : Option Node) (isSup : Bool) (o : Options) : BuildM Box := do
  let style := o.style
  let supSubGroup ← match note with
    | some n => do
      let o' := o.havingStyle (if isSup then style.sup else style.sub)
      pure (some (← ctx.group n o' (some o)))
    | none => pure none
  let body ← ctx.group base (o.havingBaseStyle MathStyle.display) none
  let braceBody ← stretchySvg label none o
  let mut vlist ← if isOver then
      makeVList (.firstBaseline #[.elem { elem := body }, .kern 0.1,
        .elem { elem := braceBody, wrapperClasses := #["svg-align"] }])
    else
      makeVList (.bottom (body.depth + 0.1 + braceBody.height)
        #[.elem { elem := braceBody, wrapperClasses := #["svg-align"] }, .kern 0.1,
          .elem { elem := body }])
  let cls := if isOver then "mover" else "munder"
  if let some s := supSubGroup then
    -- the note goes in a second list, so that the base alone sets the brace's width
    let vSpan := makeSpan #["minner", cls] #[vlist] (some o)
    vlist ← if isOver then
        makeVList (.firstBaseline #[.elem { elem := vSpan }, .kern 0.2, .elem { elem := s }])
      else
        makeVList (.bottom (vSpan.depth + 0.2 + s.height + s.depth)
          #[.elem { elem := s }, .kern 0.2, .elem { elem := vSpan }])
  return makeSpan #["minner", cls] #[vlist] (some o)

end LeAnTeX
