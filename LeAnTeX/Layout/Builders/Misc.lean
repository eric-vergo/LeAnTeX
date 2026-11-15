/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Layout.Delimiter

/-!
# Boxes, rules, phantoms and other small constructs

The builders of the constructs that move, hide, overlap or decorate their contents, or draw a
rule: `\mathchoice`, `\html@mathml`, `\mathllap` and friends, `\smash`, `\phantom`,
`\vphantom`, `\rule`, `\overline`, `\underline`, `\raisebox`, `\vcenter`, `\hbox`, `\pmb`,
`\verb`, `\reflectbox`, the `\html…` commands, `\href` and `\includegraphics`; and the sized
delimiters, `\left … \right` and `\middle`.

## References

* KaTeX's `src/functions/mathchoice.ts`, `htmlmathml.ts`, `lap.ts`, `smash.ts`, `phantom.ts`,
  `rule.ts`, `overline.ts`, `underline.ts`, `raisebox.ts`, `vcenter.ts`, `hbox.ts`, `pmb.ts`,
  `verb.ts`, `reflectbox.ts`, `html.ts`, `href.ts`, `includegraphics.ts` and `delimsizing.ts`
  (MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- `\mathchoice`: the branch for the current style, as part of the surrounding list. -/
def buildMathchoice (ctx : BuildCtx) (display text script scriptscript : Array Node)
    (o : Options) : BuildM Box := do
  let body := match o.style.size with
    | 0 => display
    | 1 => text
    | 2 => script
    | _ => scriptscript
  return makeFragment (← ctx.expr body o .no)

/-- `\html@mathml`: the HTML branch, as part of the surrounding list. -/
def buildHtmlmathml (ctx : BuildCtx) (html : Array Node) (o : Options) : BuildM Box := do
  return makeFragment (← ctx.expr html o .no)

/-- `\mathllap`, `\mathrlap`, `\mathclap` and their text forms: the body overlapping its
neighbours, with a strut for its height. -/
def buildLap (ctx : BuildCtx) (alignment : String) (body : Node) (o : Options) :
    BuildM Box := do
  let built ← ctx.group body o none
  let inner := if alignment == "clap" then
      makeSpan #["katex-inner"] #[makeSpan #[] #[built]] (some o)
    else makeSpan #["katex-inner"] #[built]
  let fix := makeSpan #["katex-fix"]
  let node := makeSpan #[alignment] #[inner, fix] (some o)
  let strut := (makeSpan #["katex-strut"]).setStyle "height" (node.height + node.depth)
  let strut := if node.depth != 0 then strut.setStyle "verticalAlign" (-node.depth) else strut
  let node := { node with children := #[strut] ++ node.children }
  return makeSpan #["mord", "katex-vbox"] #[makeSpan #["katex-thinbox"] #[node] (some o)] (some o)

/-- `\smash`, `\smash[t]`, `\smash[b]`: the body with its height or depth taken as zero. -/
def buildSmash (ctx : BuildCtx) (body : Node) (smashHeight smashDepth : Bool) (o : Options) :
    BuildM Box := do
  let mut node := makeSpan #[] #[← ctx.group body o none]
  if !smashHeight && !smashDepth then return node
  if smashHeight then node := { node with height := 0 }
  if smashDepth then node := { node with depth := 0 }
  if smashHeight && smashDepth then return makeSpan #["mord", "katex-smash"] #[node] (some o)
  node := { node with children := node.children.map fun c =>
    let c := if smashHeight then { c with height := 0 } else c
    if smashDepth then { c with depth := 0 } else c }
  let smashed ← makeVList (.firstBaseline #[.elem { elem := node }])
  return makeSpan #["mord"] #[smashed] (some o)

/-- `\phantom`: the body, invisible, as part of the surrounding list. -/
def buildPhantom (ctx : BuildCtx) (body : Array Node) (o : Options) : BuildM Box := do
  return makeFragment (← ctx.expr body o.withPhantom .no)

/-- `\vphantom`: the body's height and depth with no width. -/
def buildVphantom (ctx : BuildCtx) (body : Node) (o : Options) : BuildM Box := do
  let inner := makeSpan #["katex-inner"] #[← ctx.group body o.withPhantom none]
  return makeSpan #["mord", "rlap"] #[inner, makeSpan #["katex-fix"]] (some o)

/-- `\rule`: a filled rectangle, raised by the optional shift. -/
def buildRule (shift : Option Measurement) (width height : Measurement) (o : Options) :
    BuildM Box := do
  let w ← calculateSize width o
  let h ← calculateSize height o
  let sh ← match shift with
    | some s => calculateSize s o
    | none => pure 0
  let rule := makeSpan #["mord", "katex-rule"] #[] (some o)
  let rule := ((rule.setStyle "borderRightWidth" w).setStyle "borderTopWidth" h).setStyle
    "bottom" sh
  return { rule with width := some w, height := h + sh, depth := -sh,
                     maxFontSize := h * 1.125 * o.sizeMultiplier }

/-- `\overline`: a rule above the body (cramped), TeXbook rule 9. -/
def buildOverline (ctx : BuildCtx) (body : Node) (o : Options) : BuildM Box := do
  let inner ← ctx.group body o.havingCrampedStyle none
  let line := makeLineSpan "overline-line" o
  let t := o.fontMetrics.defaultRuleThickness
  let vlist ← makeVList (.firstBaseline #[.elem { elem := inner }, .kern (3 * t),
    .elem { elem := line }, .kern t])
  return makeSpan #["mord", "katex-overline"] #[vlist] (some o)

/-- `\underline`: a rule below the body, TeXbook rule 10. -/
def buildUnderline (ctx : BuildCtx) (body : Node) (o : Options) : BuildM Box := do
  let inner ← ctx.group body o none
  let line := makeLineSpan "underline-line" o
  let t := o.fontMetrics.defaultRuleThickness
  let vlist ← makeVList (.top inner.height #[.kern t, .elem { elem := line }, .kern (3 * t),
    .elem { elem := inner }])
  return makeSpan #["mord", "katex-underline"] #[vlist] (some o)

/-- `\raisebox`: the body raised by a dimension. -/
def buildRaisebox (ctx : BuildCtx) (dy : Measurement) (body : Node) (o : Options) :
    BuildM Box := do
  let b ← ctx.group body o none
  let d ← calculateSize dy o
  makeVList (.shift (-d) #[.elem { elem := b }])

/-- `\vcenter`: the body centred on the axis. -/
def buildVcenter (ctx : BuildCtx) (body : Node) (o : Options) : BuildM Box := do
  let b ← ctx.group body o none
  let axis := o.fontMetrics.axisHeight
  let dy := Em.mk (Em.roundDiv ((b.height - axis) - (b.depth + axis)).raw 2)
  makeVList (.shift dy #[.elem { elem := b }])

/-- `\hbox`: text with the math font reset, as part of the surrounding list. -/
def buildHbox (ctx : BuildCtx) (body : Array Node) (o : Options) : BuildM Box := do
  return makeFragment (← ctx.expr body (o.withFont "") .no)

/-- `\pmb`: the body with a shadow that thickens it. -/
def buildPmb (ctx : BuildCtx) (mclass : String) (body : Array Node) (o : Options) :
    BuildM Box := do
  let node := makeSpan #[mclass] (← ctx.expr body o .yes) (some o)
  return node.setStyleStr "textShadow" "0.02em 0.01em 0.04px"

/-- `\verb`: the text in typewriter, spaces as no-break spaces (`\verb*`: open boxes). -/
def buildVerb (mode : Mode) (body : String) (star : Bool) (o : Options) : BuildM Box := do
  let text := body.replace " " (if star then "␣" else " ")
  let o' := o.havingStyle o.style.textOf
  let mut out := #[]
  for c in text.toList do
    let c := if c == '~' then "\\textasciitilde" else c.toString
    out := out.push (← makeSymbol c "Typewriter-Regular" mode o' #["mord", "texttt"])
  return makeSpan (#["mord", "text"] ++ o'.sizingClasses o) (tryCombineChars out) (some o')

/-- `\reflectbox`: the body mirrored. -/
def buildReflectbox (ctx : BuildCtx) (body : Node) (o : Options) : BuildM Box := do
  return makeSpan #["mord", "reflectbox"] #[← ctx.group body o none] (some o)

/-- `\htmlClass`, `\htmlId`, `\htmlStyle`, `\htmlData`: the body in a span with the
attributes. -/
def buildHtml (ctx : BuildCtx) (attributes : Array (String × String)) (body : Array Node)
    (o : Options) : BuildM Box := do
  let elements ← ctx.expr body o .no
  let mut classes := #["enclosing"]
  if let some (_, cls) := attributes.find? (·.1 == "class") then
    classes := classes ++ ((cls.trimAscii.toString.splitOn " ").filter (· != "")).toArray
  let span := makeSpan classes elements (some o)
  return { span with attrs := attributes.filter (·.1 != "class") }

/-- `\href` and `\url`: a link around the body. -/
def buildHref (ctx : BuildCtx) (href : String) (body : Array Node) (o : Options) :
    BuildM Box := do
  let elements ← ctx.expr body o .no
  let a := sizeFromChildren (({ kind := .anchor, children := elements } : Box).withOptions o)
  return { a with attrs := #[("href", href)] }

/-- `\includegraphics`: an image of the given size. -/
def buildIncludegraphics (alt : String) (width height totalheight : Measurement) (src : String)
    (o : Options) : BuildM Box := do
  let h ← calculateSize height o
  let d ← if totalheight.number > 0 then do pure ((← calculateSize totalheight o) - h)
    else pure 0
  let w ← if width.number > 0 then calculateSize width o else pure 0
  let mut style : Css := ({} : Css).setEm "height" (h + d)
  if w > 0 then style := style.setEm "width" w
  if d > 0 then style := style.setEm "verticalAlign" (-d)
  return { kind := .img src alt, classes := #["mord"], style, height := h, depth := d }

/-- `\big` and friends: a delimiter of one of the four large sizes. -/
def buildDelimsizing (mode : Mode) (size : Nat) (mclass delim : String) (o : Options) :
    BuildM Box := do
  if delim == "." then return makeSpan #[mclass]
  makeSizedDelim delim size o mode #[mclass]

/-- `\middle`: a delimiter that `\left … \right` rebuilds at its contents' height. -/
def buildMiddle (mode : Mode) (delim : String) (o : Options) : BuildM Box := do
  if delim == "." then return makeNullDelimiter o #[]
  let d ← makeSizedDelim delim 1 o mode #[]
  return { d with middle := some (delim, o) }

/-- `\left … \right`: the body between delimiters tall enough for it. -/
def buildLeftright (ctx : BuildCtx) (mode : Mode) (body : Array Node) (left right : String)
    (rightColor : Option String) (o : Options) : BuildM Box := do
  let inner ← ctx.expr body o .yes (some "mopen", some "mclose")
  let mut innerHeight : Em := 0
  let mut innerDepth : Em := 0
  let mut hadMiddle := false
  for n in inner do
    if n.middle.isSome then hadMiddle := true
    else
      innerHeight := max n.height innerHeight
      innerDepth := max n.depth innerDepth
  innerHeight := innerHeight * o.sizeMultiplier
  innerDepth := innerDepth * o.sizeMultiplier
  let leftDelim ← if left == "." then pure (makeNullDelimiter o #["mopen"])
    else makeLeftRightDelim left innerHeight innerDepth o mode #["mopen"]
  let mut out := #[leftDelim] ++ inner
  if hadMiddle then
    for i in [1:out.size] do
      if let some (d, mo) := out[i]?.bind (·.middle) then
        out := out.setIfInBounds i (← makeLeftRightDelim d innerHeight innerDepth mo mode #[])
  let rightDelim ← if right == "." then pure (makeNullDelimiter o #["mclose"])
    else
      let co := match rightColor with
        | some c => o.withColor c
        | none => o
      makeLeftRightDelim right innerHeight innerDepth co mode #["mclose"]
  return makeSpan #["minner"] (out.push rightDelim) (some o)

end LeAnTeX
