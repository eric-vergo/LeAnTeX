/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Layout.Delimiter
import LeAnTeX.Parse.Functions

/-!
# Scripts, large operators and fractions

TeXbook Appendix G rules 13 (operators and their limits), 15 (fractions and generalised
fractions) and 17–18 (sub- and superscripts), as KaTeX implements them.

## Main definitions

* `assembleSupSub`: limits above and below an operator.
* `buildOp`: large operators (`\sum`, `\int`, `\lim`, `\mathop{…}`).
* `buildOperatorname`: `\operatorname`.
* `buildSupsub`: a nucleus with scripts, or the operator it hands them to.
* `buildGenfrac`: `\frac`, `\binom`, `\genfrac` and the rest.
* `staticSvg`: one of KaTeX's fixed SVG images (the ovals of `\oiint`).

## References

* KaTeX's `src/functions/op.ts`, `operatorname.ts`, `supsub.ts`, `genfrac.ts`,
  `utils/assembleSupSub.ts` and `src/buildCommon.ts` (`staticSvg`) (MIT licence, see
  `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- A fixed SVG image: path name, width and height in em (`svgData`). -/
def svgData : String → Option (String × Em × Em × String)
  | "vec" => some ("vec", 0.471, 0.714, "0 0 471 714")
  | "oiintSize1" => some ("oiintSize1", 0.957, 0.499, "0 0 957 499")
  | "oiintSize2" => some ("oiintSize2", 1.472, 0.659, "0 0 1472 659")
  | "oiiintSize1" => some ("oiiintSize1", 1.304, 0.499, "0 0 1304 499")
  | "oiiintSize2" => some ("oiiintSize2", 1.98, 0.659, "0 0 1980 659")
  | _ => none

/-- A span with one of KaTeX's fixed SVG images (`staticSvg`). -/
def staticSvg (value : String) (o : Options) : BuildM Box := do
  let some (pathName, width, height, viewBox) := svgData value
    | throwInternal s!"Unknown SVG image {value}"
  let svg : Box :=
    { kind := .svg #[.path pathName none]
      attrs := #[("width", width.css), ("height", height.css), ("style", "width:" ++ width.css),
      ("viewBox", viewBox), ("preserveAspectRatio", "xMinYMin")] }
  let span := makeSvgSpan #["katex-overlay"] #[svg] o
  return ({ span with height }.setStyle "height" height).setStyle "width" width

/-- Limits above and below a large operator (TeXbook rule 13a; `assembleSupSub`). `slant` is
the operator's italic correction, by which the limits are shifted apart; `baseShift` how far the
operator symbol was moved down to centre it on the axis. -/
def assembleSupSub (ctx : BuildCtx) (base : Box) (supGroup subGroup : Option Node) (o : Options)
    (style : MathStyle) (slant baseShift : Em) : BuildM Box := do
  let base := makeSpan #[] #[base]
  let subIsSingleCharacter := match subGroup with
    | some g => isCharacterBox g
    | none => false
  let fm := o.fontMetrics
  let sup ← match supGroup with
    | some g => do
      let elem ← ctx.group g (o.havingStyle style.sup) (some o)
      pure (some (elem, max fm.bigOpSpacing1 (fm.bigOpSpacing3 - elem.depth)))
    | none => pure none
  let sub ← match subGroup with
    | some g => do
      let elem ← ctx.group g (o.havingStyle style.sub) (some o)
      pure (some (elem, max fm.bigOpSpacing2 (fm.bigOpSpacing4 - elem.height)))
    | none => pure none
  let finalGroup ← match sup, sub with
    | some (supE, supK), some (subE, subK) =>
      let bottom := fm.bigOpSpacing5 + subE.height + subE.depth + subK + base.depth + baseShift
      makeVList (.bottom bottom #[.kern fm.bigOpSpacing5,
        .elem { elem := subE, marginLeft := some (-slant) }, .kern subK, .elem { elem := base },
        .kern supK, .elem { elem := supE, marginLeft := some slant }, .kern fm.bigOpSpacing5])
    | none, some (subE, subK) =>
      makeVList (.top (base.height - baseShift) #[.kern fm.bigOpSpacing5,
        .elem { elem := subE, marginLeft := some (-slant) }, .kern subK, .elem { elem := base }])
    | some (supE, supK), none =>
      makeVList (.bottom (base.depth + baseShift) #[.elem { elem := base }, .kern supK,
        .elem { elem := supE, marginLeft := some slant }, .kern fm.bigOpSpacing5])
    | none, none => return base
  let mut parts := #[finalGroup]
  if sub.isSome && slant != 0 && !subIsSingleCharacter then
    let spacer := (makeSpan #["mspace"] #[] (some o)).setStyle "marginRight" slant
    parts := #[spacer] ++ parts
  return makeSpan #["mop", "op-limits"] parts (some o)

/-- The font of a large operator symbol: Size2 in display style, else Size1. -/
def opFont (large : Bool) : String := if large then "Size2-Regular" else "Size1-Regular"

/-- The symbol drawn for an operator: `\oiint` and `\oiiint` are drawn as `\iint` and
`\iiint` with an oval over them. -/
def symName (name : String) : String :=
  if name == "\\oiint" then "\\iint" else if name == "\\oiiint" then "\\iiint" else name

/-- A large operator (TeXbook rule 13): a symbol from Size1 (text) or Size2 (display) centred on
the axis, a name in roman, or a body; with limits when `hasLimits` (KaTeX's `op` builder). -/
def buildOp (ctx : BuildCtx) (mode : Mode) (symbol : Bool) (name : Option String)
    (body : Option (Array Node)) (suppressBaseShift : Option Bool) (supGroup subGroup : Option Node)
    (hasLimits : Bool) (o : Options) : BuildM Box := do
  let style := o.style
  let name0 := name.getD ""
  let large := style.size == MathStyle.display.size && symbol && name0 != "\\smallint"
  let isOiint := name0 == "\\oiint" || name0 == "\\oiiint"
  let mut base : Box := {}
  if symbol then
    base ← makeSymbol (symName name0) (opFont large) .math o
      #["mop", "op-symbol", if large then "large-op" else "small-op"]
    if isOiint then
      let symbolItalic := base.italic
      let oval ← staticSvg ((name0.drop 1).toString ++ "Size" ++ if large then "2" else "1") o
      base ← makeVList (.individualShift #[{ elem := base, shift := 0 },
        { elem := oval, shift := if large then 0.08 else 0 }])
      base := { base with classes := #["mop"] ++ base.classes, italic := symbolItalic }
  else if let some b := body then
    let inner ← ctx.expr b o .yes
    if h : inner.size = 1 then
      if inner[0].isSymbol then
        let s := inner[0]
        base := { s with classes := if s.classes.isEmpty then #["mop"] else s.classes.set! 0 "mop" }
      else base := makeSpan #["mop"] inner (some o)
    else base := makeSpan #["mop"] inner (some o)
  else
    let mut output := #[]
    for c in (name0.drop 1).toString.toList do
      output := output.push (← mathsym c.toString mode o)
    base := makeSpan #["mop"] output (some o)
  let mut baseShift : Em := 0
  let mut slant : Em := 0
  -- whether KaTeX's floating-point shift is non-zero: it moves the symbol (even by `0em`) only
  -- then; the symbol's height and depth are the table's, so the double is reproduced exactly
  let mut shifted := false
  if (base.isSymbol || isOiint) && suppressBaseShift != some true then
    baseShift := Em.mk (Em.roundDiv (base.height - base.depth).raw 2) - o.fontMetrics.axisHeight
    slant := base.italicOr0
    shifted := baseShift != 0
    if symbol && !isOiint then
      if let some m := charMetrics (← lookupSymbol (symName name0) (opFont large) .math).1
          (opFont large) .math then
        shifted := (m.exactFloat 1 - m.exactFloat 0) / 2 - 0.25 != 0
  if hasLimits then
    assembleSupSub ctx base supGroup subGroup o style slant baseShift
  else
    if shifted then
      base := (base.setStyleStr "position" "relative").setStyle "top" baseShift
    return base

/-- `\operatorname`: the body in roman with symbols as text, minus signs as hyphens, with limits
when `hasLimits`. -/
def buildOperatorname (ctx : BuildCtx) (body : Array Node) (supGroup subGroup : Option Node)
    (hasLimits : Bool) (o : Options) : BuildM Box := do
  let mut base := makeSpan #["mop"] #[] (some o)
  if !body.isEmpty then
    let body := body.map fun c => match c with
      | .sym mode _ _ text => Node.sym mode .absent .textord text
      | c => c
    let expression ← ctx.expr body (o.withFont "mathrm") .yes
    let expression := expression.map fun c => match c.kind with
      | .symbol t f =>
        { c with kind := .symbol (((t.replace "−" "-").replace "∗" "*")) f }
      | _ => c
    base := makeSpan #["mop"] expression (some o)
  if hasLimits then assembleSupSub ctx base supGroup subGroup o o.style 0 0
  else return base

/-- A nucleus with scripts (TeXbook rules 17–18): the scripts in a vertical list beside the
nucleus, or, for an operator with limits in display style, the operator's own layout. -/
def buildSupsub (ctx : BuildCtx) (valueBase valueSup valueSub : Option Node) (o : Options) :
    BuildM Box := do
  match valueBase with
  | some (.op _ _ limits alwaysHandle suppress _ symbol name body) =>
    if limits && (o.style.size == MathStyle.display.size || alwaysHandle == some true) then
      return ← buildOp ctx .math symbol name body suppress valueSup valueSub true o
  | some (.operatorname _ _ body alwaysHandle limits _) =>
    if alwaysHandle && (o.style.size == MathStyle.display.size || limits) then
      return ← buildOperatorname ctx body valueSup valueSub true o
  | some (.accent _ _ _ _ _ b) =>
    if isCharacterBox b then throwUnsupported "accent with scripts"
  | some (.horizBrace _ _ _ isOver _) =>
    if valueSub.isNone == isOver then throwUnsupported "horizBrace with scripts"
  | _ => pure ()
  let base ← ctx.groupOpt valueBase o
  let fm := o.fontMetrics
  let mut supShift : Em := 0
  let mut subShift : Em := 0
  let isCharBox := match valueBase with
    | some b => isCharacterBox b
    | none => false
  let mut supm : Option Box := none
  let mut subm : Option Box := none
  if let some g := valueSup then
    let o' := o.havingStyle o.style.sup
    supm := some (← ctx.group g o' (some o))
    if !isCharBox then
      supShift := base.height - o'.fontMetrics.supDrop * o'.sizeMultiplier / o.sizeMultiplier
  if let some g := valueSub then
    let o' := o.havingStyle o.style.sub
    subm := some (← ctx.group g o' (some o))
    if !isCharBox then
      subShift := base.depth + o'.fontMetrics.subDrop * o'.sizeMultiplier / o.sizeMultiplier
  let minSupShift := if o.style == MathStyle.display then fm.sup1
    else if o.style.cramped then fm.sup3 else fm.sup2
  -- \scriptspace, 0.5pt at any size
  let marginRight := (0.05 : Em) / o.sizeMultiplier
  let mut marginLeft : Option Em := none
  if subm.isSome then
    let isOiint := match valueBase with
      | some (.op _ _ _ _ _ _ _ (some n) _) => n == "\\oiint" || n == "\\oiiint"
      | _ => false
    if base.isSymbol || isOiint then marginLeft := some (-base.italicOr0)
  let supsub ← match supm, subm with
    | some sp, some sb =>
      supShift := max (max supShift minSupShift) (sp.depth + 0.25 * fm.xHeight)
      subShift := max subShift fm.sub2
      let maxWidth := 4 * fm.defaultRuleThickness
      if (supShift - sp.depth) - (sb.height - subShift) < maxWidth then
        subShift := maxWidth - (supShift - sp.depth) + sb.height
        let psi := 0.8 * fm.xHeight - (supShift - sp.depth)
        if psi > 0 then
          supShift := supShift + psi
          subShift := subShift - psi
      makeVList (.individualShift #[
        { elem := sb, shift := subShift, marginRight := some marginRight, marginLeft },
        { elem := sp, shift := -supShift, marginRight := some marginRight }])
    | none, some sb =>
      subShift := max (max subShift fm.sub1) (sb.height - 0.8 * fm.xHeight)
      makeVList (.shift subShift
        #[.elem { elem := sb, marginLeft, marginRight := some marginRight }])
    | some sp, none =>
      supShift := max (max supShift minSupShift) (sp.depth + 0.25 * fm.xHeight)
      makeVList (.shift (-supShift) #[.elem { elem := sp, marginRight := some marginRight }])
    | none, none => throwInternal "supsub must have either sup or sub."
  let mclass := (getTypeOfDomTree base (some true)).getD "mord"
  return makeSpan #[mclass] #[base, makeSpan #["msupsub"] #[supsub]] (some o)

/-- A fraction or generalised fraction (TeXbook rule 15): numerator and denominator in the
styles below the current one, the bar on the axis, delimiters of the size the style asks for. -/
def buildGenfrac (ctx : BuildCtx) (mode : Mode) (continued : Bool) (numer denom : Node)
    (hasBarLine : Bool) (leftDelim rightDelim : Option String) (barSize : Option Measurement)
    (o : Options) : BuildM Box := do
  let style := o.style
  let fm := o.fontMetrics
  let mut numerm ← ctx.group numer (o.havingStyle style.fracNum) (some o)
  if continued then
    let hStrut := (8.5 : Em) / fm.ptPerEm
    let dStrut := (3.5 : Em) / fm.ptPerEm
    numerm := { numerm with height := max numerm.height hStrut,
                            depth := max numerm.depth dStrut }
  let denomm ← ctx.group denom (o.havingStyle style.fracDen) (some o)
  let mut rule : Option Box := none
  let mut ruleWidth : Em := 0
  let mut ruleSpacing : Em := fm.defaultRuleThickness
  if hasBarLine then
    let r ← match barSize with
      | some bs => do pure (makeLineSpan "frac-line" o (some (← calculateSize bs o)))
      | none => pure (makeLineSpan "frac-line" o)
    rule := some r
    ruleWidth := r.height
    ruleSpacing := r.height
  let display := style.size == MathStyle.display.size
  let mut numShift := if display then fm.num1 else if ruleWidth > 0 then fm.num2 else fm.num3
  let clearance := if display then (if ruleWidth > 0 then 3 * ruleSpacing else 7 * ruleSpacing)
    else (if ruleWidth > 0 then ruleSpacing else 3 * ruleSpacing)
  let mut denomShift := if display then fm.denom1 else fm.denom2
  let frac ← match rule with
    | none =>
      let candidate := (numShift - numerm.depth) - (denomm.height - denomShift)
      if candidate < clearance then
        let half := Em.mk (Em.roundDiv (clearance - candidate).raw 2)
        numShift := numShift + half
        denomShift := denomShift + half
      makeVList (.individualShift #[{ elem := denomm, shift := denomShift },
        { elem := numerm, shift := -numShift }])
    | some r =>
      let axisHeight := fm.axisHeight
      let halfRule := Em.mk (Em.roundDiv ruleWidth.raw 2)
      if (numShift - numerm.depth) - (axisHeight + halfRule) < clearance then
        numShift := numShift + (clearance - ((numShift - numerm.depth) - (axisHeight + halfRule)))
      if (axisHeight - halfRule) - (denomm.height - denomShift) < clearance then
        denomShift := denomShift +
          (clearance - ((axisHeight - halfRule) - (denomm.height - denomShift)))
      makeVList (.individualShift #[{ elem := denomm, shift := denomShift },
        { elem := r, shift := -(axisHeight - halfRule) }, { elem := numerm, shift := -numShift }])
  let delimSize := if display then fm.delim1
    else if style.size == MathStyle.scriptscript.size then
      (o.havingStyle MathStyle.script).fontMetrics.delim2
    else fm.delim2
  let leftD ← match leftDelim with
    | none => pure (makeNullDelimiter o #["mopen"])
    | some d => makeCustomSizedDelim d delimSize true (o.havingStyle style) mode #["mopen"]
  let rightD ← if continued then pure (makeSpan)
    else match rightDelim with
      | none => pure (makeNullDelimiter o #["mclose"])
      | some d => makeCustomSizedDelim d delimSize true (o.havingStyle style) mode #["mclose"]
  return makeSpan #["mord"] #[leftD, makeSpan #["mfrac"] #[frac], rightD] (some o)

end LeAnTeX
