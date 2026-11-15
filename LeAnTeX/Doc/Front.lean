/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Doc.Environments
import LeAnTeX.Doc.Output

/-!
# The front end and documents

The front end's dispatcher (every token: macros first, then the document layer's commands,
then the text layer's) and its two entry points:

* `typeset`: a fragment of LaTeX (no `\documentclass`) to a `Document` of lines, as the text
  layer always did.
* `typesetDocument`: a whole LaTeX document (`\documentclass{article}` … `\end{document}`) to
  pages. The front end runs until the labels and the table of contents stop changing (LaTeX's
  repeated runs, without files: each pass gets the previous pass's answers), at most
  `maxPasses` times; each pass builds the pages with TeX's page builder and LaTeX's output
  routine (`LeAnTeX.Doc.PageBuilder`, `LeAnTeX.Doc.Output`).

## Main definitions

* `typeset`, `typesetDocument`, `DocResult`.
-/

namespace LeAnTeX.Text

namespace Typeset

open LeAnTeX.Doc

/-- Carries out a control sequence: a macro, then the document layer's commands, then the
text layer's. -/
def command (t : Tok) (name : String) : M Unit := do
  let v ← vars
  if let some m := v.macros[name]? then expandMacro t m; return
  if ← docCommand t name then return
  let basic := (fontDecl name v.key).isSome || (textFontCommand name).isSome ||
    isIntParam name || isGlueParam name || isDimenParam name || basicNames.contains name
  if basic then textCommand t name
  else failAt t s!"Undefined control sequence \\{name}"

/-- Carries out one token. -/
def step (t : Tok) : M Unit :=
  match t with
  | .cs name _ => command t name
  | .char c cat _ =>
    match cat with
    | 1 => beginGroup t
    | 2 => closeGroup t
    | 3 => do
      match ← next? with
      | some u@(.char '$' 3 _) =>
        let _ := u
        displayFormula t (← readFormula t (·.isChar '$' 3) true)
      | some u =>
        unread #[u]
        startParagraph
        inlineFormula t (← readFormula t (·.isChar '$' 3) false)
      | none => failAt t "Missing $ inserted (formula not closed)"
    | 10 => addSpace
    | 13 => do
      startParagraph
      push (.penalty 10000)
      addSpace (some 1000)
    | 4 => alignTab t
    | 6 => failAt t "You can't use the macro parameter character # here"
    | 7 | 8 => failAt t s!"Missing $ inserted ({c} is for formulas)"
    | _ => do
      if (← docSt).documentMode && !(← docSt).inDocument then
        if !c.isWhitespace then failAt t "Missing \\begin{document}"
      else addChar c
  | .param _ => fail "internal: a parameter outside a macro body"

/-- Reads and carries out every token, then ends the last paragraph. -/
def process : M Unit := do
  let (cfg, _) ← read
  let fuel := (← get).input.size + cfg.maxTokens + 2
  for _ in [0:fuel] do
    match ← next? with
    | none => break
    | some t => step t
  if !(← get).input.isEmpty then fail "internal: the token budget ran out"
  if !(← get).boxes.isEmpty then fail "Missing } inserted (a box is not closed)"
  if !(← get).nest.isEmpty then fail "Missing } inserted (a footnote or float is not closed)"
  endParagraph
  if (← get).groups.size > 1 then fail "Missing } inserted (a group is not closed)"
  let d ← docSt
  if d.documentMode then
    if !d.inDocument then fail "Missing \\begin{document}"
    if !d.ended then fail "Missing \\end{document}"

end Typeset

open Typeset in
/-- Typesets LaTeX source (see the module docstring of `LeAnTeX.Text.Typeset`): the lines of
its paragraphs and formulas with their positions, the fonts named by `resolve`. `init` holds
the starting parameters (LaTeX's ten-point article class by default). An error for source the
front end does not understand or that exceeds a cap of `cfg`. -/
def typeset (src : String) (resolve : FontResolver) (cfg : Settings := {})
    (init : Vars := {}) : Except TypesetError Document := do
  if src.length > cfg.maxSource then
    throw { message := s!"source too long: more than {cfg.maxSource} characters" }
  let st : St := { input := (tokenize src).reverse, groups := #[init] }
  let ((), s) ← (process.run (cfg, resolve)).run st
  return { fonts := s.fonts, lines := s.lines, width := s.width, warnings := s.warnings
           paragraphs := s.paragraphs }

end LeAnTeX.Text

namespace LeAnTeX.Doc

open LeAnTeX.Text LeAnTeX.Text.Typeset

/-- A typeset document: its pages, the fonts the glyphs index, the labels (key, text, page),
the table of contents (level, number, title as source text, page), the counter steps (counter
and printed value), the passes it took, and the warnings (undefined references among them). -/
structure DocResult where
  /-- The pages. -/
  pages : Array Page
  /-- The fonts, as glyph nodes index them. -/
  fonts : Array (FontInfo × Int)
  /-- The labels: key, text, page. -/
  labels : Array (String × String × String)
  /-- The table of contents: level, number, title, page. -/
  toc : Array (Nat × String × String × String)
  /-- The counter steps. -/
  steps : Array (String × String)
  /-- The passes the front end ran. -/
  passes : Nat
  /-- Warnings. -/
  warnings : Array String
  /-- The records of `\leantexprobe` (`LeAnTeX.Text.Settings.probes`), in order. -/
  probes : Array String := #[]
  deriving Inhabited

/-- The pages of a pass: the main vertical list through the page builder and the output
routine, with the page numbers, the foot lines and the anchors each page holds. -/
def makePages (vlist : Array VNode) : Typeset.M (Array Page) := do
  let d ← docSt
  let cp := classParams d.options
  let fn : InsertClass := { skip := cp.footinsSkip, dimen := 37890286 }
  let boxes := d.floats.map fun f => f.box.toNode
  let specs := (d.floats.zip boxes).map fun (f, b) =>
    let has := fun (c : Char) => f.placement.contains c
    ({ box := b, here := has 'h', top := has 't', bottom := has 'b', page := has 'p',
       kind := f.kind, penalty := f.penalty, unskip := f.unskip } : FloatSpec)
  let fparams : FloatParams :=
    { floatSep := cp.floatSep, textFloatSep := cp.textFloatSep, inTextSep := cp.inTextSep,
      fpSep := cp.fpSep }
  let (cfg, _) ← read
  let specs := if cfg.continuous then specs.map fun f => { f with here := true } else specs
  let vsize := if cfg.continuous then 536870911 else cp.textHeight
  let pp : PageParams :=
    { vsize, maxDepth := cp.maxDepth, topSkip := { width := cp.topSkip },
      inserts := fun n => if n == 254 then some fn else none, floats := specs, fp := fparams }
  let outs ← match buildPages vlist pp with
    | .ok o => pure o
    | .error e => fail e
  let mut pages := #[]
  let mut number : Int := 1
  for o in outs do
    let body := if cfg.continuous then
        let b := makeColumn cp o cp.textWidth boxes
        vpack b.content
      else makeColumn cp o cp.textWidth boxes
    let fl := (o.top ++ o.bottom ++ o.floatPage).filterMap fun i => boxes[i]?
    let anchors := anchorsOf o.items 64 ++ anchorsOf fl 64 ++
      (o.inserts.foldl (init := #[]) fun acc (_, m) => acc ++ anchorsOf m 64)
    let style := match d.thisPageStyles.find? (fun (k, _) => anchors.contains k) with
      | some (_, st) => st
      | none => d.pageStyle
    let bodyX := inch + cp.oddSideMargin
    let bodyY := inch + cp.topMargin + cp.headHeight + cp.headSep
    let text := toString number
    let foot ← if style == "empty" then pure none else some <$> footLine text cp.textWidth
    let textHeight := if cfg.continuous then body.height + body.depth else cp.textHeight
    let footY := bodyY + textHeight + cp.footSkip
    let pg : Page :=
      { number, text, width := cp.paperWidth,
          height := if cfg.continuous then footY + inch else cp.paperHeight, body,
        bodyX, bodyY, foot, footX := bodyX, footY, anchors }
    pages := pages.push pg
    number := number + 1
  return pages
where
  /-- The `plain` style's foot: the page number centred in the normal font. -/
  footLine (text : String) (width : Int) : Typeset.M VNode := do
    let cp ← classP
    let size := ((cp.sizes.find? (·.name == "normalsize")).map (·.size)).getD 655360
    let tf ← fontFor { size := size }
    let glyphs := tf.shape text.toList.toArray
    let fil : HNode := .glue { stretch := 65536, stretchOrder := 1 } 0
    let nodes := #[fil] ++ glyphs ++ #[fil]
    let (nat, st, sh, h, dp) := measure nodes
    return .hbox width h dp 0 nodes (hpackGlue nat width st sh)

/-- One pass over a document: the front end with the previous pass's references and contents,
then the pages. -/
def pass (refs : Std.HashMap String (String × String)) (prevToc : Array (TocEntry × String)) :
    Typeset.M (Array Page) := do
  modifyDoc fun d => { d with refs, prevToc }
  process
  makePages (← get).vlist

/-- Typesets a whole document (see the module docstring): its pages, or an error for source
the front end does not understand, that exceeds a cap of `cfg`, or that is not a document (no
`\documentclass`). -/
def typesetDocument (src : String) (resolve : FontResolver) (cfg : LeAnTeX.Text.Settings := {})
    (maxPasses : Nat := 4) : Except TypesetError DocResult := do
  if src.length > cfg.maxSource then
    throw { message := s!"source too long: more than {cfg.maxSource} characters" }
  let prepared ← match prepareVerbatim src with
    | .ok s => pure s
    | .error (pos, e) => throw { message := e, pos }
  let mut refs : Std.HashMap String (String × String) := {}
  let mut prevToc : Array (TocEntry × String) := #[]
  let mut last : Option (Array Page × St) := none
  let mut passes := 0
  for _ in [0:max 1 maxPasses] do
    let st : St := { input := (tokenize prepared).reverse, groups := #[{}] }
    let (pages, s) ← ((pass refs prevToc).run (cfg, resolve)).run st
    passes := passes + 1
    if !s.doc.documentMode then
      throw { message := "Not a document: \\documentclass is missing" }
    let pageOf := fun (key : String) =>
      ((pages.find? (·.anchors.contains key)).map (·.text)).getD "??"
    let newRefs : Std.HashMap String (String × String) :=
      s.doc.labels.foldl (init := {}) fun m (k, t) => m.insert k (t, pageOf k)
    let newToc := s.doc.toc.map fun e => (e, pageOf e.anchor)
    let same := sameRefs newRefs refs && sameToc newToc prevToc
    last := some (pages, s)
    refs := newRefs
    prevToc := newToc
    if same then break
  let some (pages, s) := last | throw { message := "internal: no pass ran" }
  let pageOf := fun (key : String) =>
    ((pages.find? (·.anchors.contains key)).map (·.text)).getD "??"
  return {
    pages, fonts := s.fonts, passes,
    labels := s.doc.labels.map fun (k, t) => (k, t, pageOf k)
    toc := s.doc.toc.map fun e => (e.level, e.number, tokText e.title, pageOf e.anchor)
    steps := s.doc.steps, probes := s.doc.probes
    warnings := s.warnings ++ s.doc.warnings ++
      (s.doc.undefinedRefs.map fun k => s!"Reference '{k}' undefined") }
where
  /-- Whether two passes gave the same references. -/
  sameRefs (a b : Std.HashMap String (String × String)) : Bool :=
    a.size == b.size && a.toList.all fun (k, v) => b[k]? == some v
  /-- Whether two passes gave the same contents (numbers, titles and pages). -/
  sameToc (a b : Array (TocEntry × String)) : Bool :=
    a.size == b.size && (a.zip b).all fun ((e, p), (f, q)) =>
      e.level == f.level && e.number == f.number && tokText e.title == tokText f.title &&
        p == q

end LeAnTeX.Doc
