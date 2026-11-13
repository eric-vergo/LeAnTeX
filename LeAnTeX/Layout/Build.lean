/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Layout.Builders.Basic
import LeAnTeX.Layout.Builders.Scripts
import LeAnTeX.Parse.Parser

/-!
# Laying out a formula

The dispatch from parse nodes to their builders, and KaTeX's `buildHTML`: the formula as a
sequence of unbreakable parts with struts, inside the `katex` span.

## Main definitions

* `buildGroupF`: KaTeX's `buildGroup`, with a bound on the nesting depth.
* `buildHTML`: the `katex-html` span of a parse tree.
* `buildHTMLTree`: the whole box tree as KaTeX's `__renderToHTMLTree` returns it.
* `LayoutResult`, `layout`: parse and lay out a formula.

## Implementation notes

The builders call back into `buildGroupF` through a `BuildCtx`, so the recursion is in this one
function, structural on its `fuel` argument: a node nested `fuel` deep fails with an error
instead of looping. The fuel is far above any depth the parser produces.

## References

* KaTeX's `src/buildHTML.ts` and `src/buildTree.ts` (MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- Lay out one node with the given context (the builders of every construct). -/
def buildNode (ctx : BuildCtx) (n : Node) (o : Options) : BuildM Box := do
  match n with
  | .sym mode _ group text => buildSymbol mode group text o
  | .ordgroup _ _ body semisimple => buildOrdgroup ctx body semisimple o
  | .styling _ _ style resetFont body => buildStyling ctx style resetFont body o
  | .sizing _ _ size body => buildSizing ctx size body o
  | .font _ _ font body => buildFont ctx font body o
  | .text _ _ body font => buildText ctx body font o
  | .mclass _ _ mclass body _ => buildMclass ctx mclass body o
  | .color _ _ color body => buildColor ctx color body o
  | .kern _ _ dimension => buildKern dimension o
  | .supsub _ _ base sup sub => buildSupsub ctx base sup sub o
  | .op mode _ _ _ suppress _ symbol name body =>
    buildOp ctx mode symbol name body suppress none none false o
  | .operatorname _ _ body _ _ _ => buildOperatorname ctx body none none false o
  | .genfrac mode _ continued numer denom hasBarLine leftDelim rightDelim barSize =>
    buildGenfrac ctx mode continued numer denom hasBarLine leftDelim rightDelim barSize o
  | .raw .. | .size .. | .url .. | .colorToken .. | .internal .. | .environment ..
  | .«infix» .. | .leftrightRight .. | .cdlabel .. | .cdlabelparent .. | .tag .. =>
    throwParse s!"Got group of unknown type: '{n.type}'"
  | n => throwUnsupported n.type

/-- Give a box (and the children of a fragment) the source range of the node it was built
for, unless it has one. -/
def Box.withLoc (b : Box) (loc : OLoc) : Box :=
  let stamp (b : Box) : Box := match b.loc with
    | .absent => { b with loc }
    | _ => b
  let b := if b.isFragment then { b with children := b.children.map stamp } else b
  stamp b

/-- KaTeX's `buildGroup`: lay out `n` in `o`, and when the parent's options `base` have
another size, wrap the result in a span that changes the size, its height and depth scaled to
the parent's size. -/
def buildGroupF : Nat → Node → Options → Option Options → BuildM Box
  | 0, _, _, _ => throwInternal "Formula nested too deeply"
  | fuel + 1, n, o, base => do
    let ctx : BuildCtx := { group := buildGroupF fuel }
    let out := (← buildNode ctx n o).withLoc n.loc
    match base with
    | some b =>
      if o.size != b.size then
        let wrapped := makeSpan (o.sizingClasses b) #[out] (some o)
        let k := o.sizeMultiplier / b.sizeMultiplier
        return { wrapped with height := wrapped.height * k, depth := wrapped.depth * k,
                              loc := n.loc }
      return out
    | none => return out

/-- The nesting depth the layout accepts. -/
def layoutFuel : Nat := 1 <<< 20

/-- The top-level context. -/
def rootCtx : BuildCtx := { group := buildGroupF layoutFuel }

/-- An unbreakable part of the formula with a strut that gives it its height and depth
(`buildHTMLUnbreakable`). -/
def buildHTMLUnbreakable (children : Array Box) (o : Options) : Box :=
  let body := makeSpan #["katex-base"] children (some o)
  let strut := (makeSpan #["katex-strut"]).setStyle "height" (body.height + body.depth)
  let strut := if body.depth != 0 then strut.setStyle "verticalAlign" (-body.depth) else strut
  { body with children := #[strut] ++ body.children }

/-- The `katex-html` span of a parse tree (`buildHTML`): the formula broken after each binary
operator and relation (with the spaces that follow), each part with its strut, and the equation
tag. -/
def buildHTML (tree : Array Node) (o : Options) : BuildM Box := do
  let (tree, tag) := match tree with
    | #[.tag _ _ body tag] => (body, some tag)
    | t => (t, none)
  let mut expression ← rootCtx.expr tree o .root
  let mut eqnNum : Option Box := none
  if expression.size == 2 && expression[1]!.hasClass "katex-tag" then
    eqnNum := expression.back?
    expression := expression.pop
  let mut children := #[]
  let mut parts : Array Box := #[]
  let mut i := 0
  for _ in [0:expression.size] do
    if i ≥ expression.size then break
    let e := expression[i]!
    parts := parts.push e
    if e.hasClass "mbin" || e.hasClass "mrel" || e.hasClass "allowbreak" then
      let mut nobreak := false
      for _ in [0:expression.size] do
        if i < expression.size - 1 && expression[i + 1]!.hasClass "mspace" &&
            !expression[i + 1]!.hasClass "katex-newline" then
          i := i + 1
          parts := parts.push expression[i]!
          if expression[i]!.hasClass "nobreak" then nobreak := true
        else break
      if !nobreak then
        children := children.push (buildHTMLUnbreakable parts o)
        parts := #[]
    else if e.hasClass "katex-newline" then
      parts := parts.pop
      if parts.size > 0 then
        children := children.push (buildHTMLUnbreakable parts o)
        parts := #[]
      children := children.push e
    i := i + 1
  if parts.size > 0 then children := children.push (buildHTMLUnbreakable parts o)
  let mut tagChild : Option Box := none
  if let some t := tag then
    let tc := buildHTMLUnbreakable (← rootCtx.expr t o .yes) o
    tagChild := some { tc with classes := #["katex-tag"] }
    children := children.push tagChild.get!
  else if let some e := eqnNum then
    children := children.push e
  let mut html := makeSpan #["katex-html"] children
  html := { html with attrs := #[("aria-hidden", "true")] }
  if tagChild.isSome then
    let n := html.children.size
    let tc := html.children[n - 1]!
    let strut := tc.children[0]!.setStyle "height" (html.height + html.depth)
    let strut := if html.depth != 0 then strut.setStyle "verticalAlign" (-html.depth)
      else strut
    let tc' := { tc with children := tc.children.set! 0 strut }
    html := { html with children := html.children.set! (n - 1) tc' }
  return html

/-- The layout options of a formula's settings (`optionsFromSettings`). -/
def optionsOfSettings (s : Settings) : Options :=
  { style := if s.displayMode then MathStyle.display else MathStyle.text, strict := s.strict }

/-- The whole box tree of a parse tree: the `katex` span, wrapped in `katex-display` in display
mode (`buildHTMLTree`). -/
def buildHTMLTree (tree : Array Node) (s : Settings) : BuildM Box := do
  let html ← buildHTML tree (optionsOfSettings s)
  let node := makeSpan #["katex"] #[html]
  if s.displayMode then
    let classes := #["katex-display"] ++ (if s.leqno then #["leqno"] else #[]) ++
      (if s.fleqn then #["fleqn"] else #[])
    return makeSpan classes #[node]
  return node

/-- A formula laid out: the box tree or the error, and every strict-mode warning of parsing
and layout, in order. -/
structure LayoutResult where
  /-- The box tree, or why there is none. -/
  result : Except BuildError Box
  /-- The warnings. -/
  warnings : Array Warning

/-- The formula's source in the error colour, with the error as its title, as KaTeX shows a
formula it rejects when `throwOnError` is off (`renderError`). -/
def renderError (input : String) (e : KError) (s : Settings) : Box :=
  let span := makeSpan #["katex-error"] #[newSymbol input "" 0 0 0 0 0 #[]]
  { span with attrs := #[("title", "ParseError: " ++ e.message),
                         ("style", "color:" ++ s.errorColor)] }

/-- Parse and lay out a formula. A `ParseError` gives `renderError`'s box when `throwOnError` is
off, as in KaTeX. -/
def layout (input : String) (settings : Settings := {}) : LayoutResult :=
  let p := parse input settings
  let fail (e : BuildError) (ws : Array Warning) : LayoutResult :=
    match e with
    | .katex e@(.parse ..) =>
      if settings.throwOnError then { result := .error (.katex e), warnings := ws }
      else { result := .ok (renderError input e settings), warnings := ws }
    | e => { result := .error e, warnings := ws }
  match p.result with
  | .error e => fail (.katex e) p.warnings
  | .ok tree =>
    match (buildHTMLTree tree settings).run p.warnings with
    | .ok (b, ws) => { result := .ok b, warnings := ws }
    | .error e => fail e p.warnings

end LeAnTeX
