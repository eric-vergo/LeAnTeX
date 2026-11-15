/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Doc.Lists

/-!
# The document layer's commands: environments and the dispatcher

`\begin{…}` and `\end{…}` (a group around the environment; `\end` checks the name), the
`document` environment, and `docCommand`, which carries out every command of the document
layer (`LeAnTeX.Doc.Commands` and this module) and answers `false` for the others, which the
text layer then carries out. A group's end closes the nested vertical list or box that began
with it (`closeGroup`).

Vertical commands: `\newpage` and `\clearpage` (the paragraph ended, `\vskip -\prevdepth`,
`\vfil` and a forced break, as LuaLaTeX shows them), `\pagebreak[n]` and `\nopagebreak[n]`
(penalties -10000, -4n×… as LaTeX's table: 0, -51, -151, -301, -10000 and their negatives),
`\vfill`, `\vskip`, `\smallskip`, `\medskip`, `\bigskip`, `\addvspace`, `\pagestyle`,
`\thispagestyle`.
-/

namespace LeAnTeX.Text.Typeset

open LeAnTeX.Doc

/-- The penalties of `\pagebreak[n]` for n = 0 … 4 (LaTeX's `\@lowpenalty`, `\@medpenalty`,
`\@highpenalty`, and a forced break). -/
def breakPenalty (n : Nat) : Int :=
  match n with | 0 => 0 | 1 => 51 | 2 => 151 | 3 => 301 | _ => 10000

/-- Reads `[n]` after `\pagebreak` (4 when absent). -/
def readPriority (at_ : Tok) : M Nat := do
  match ← readOptional? with
  | some ts => match (tokText ts).trimAscii.toString.toNat? with
    | some n => if n ≤ 4 then return n else failAt at_ "Bad \\pagebreak priority"
    | none => failAt at_ "Bad \\pagebreak priority"
  | none => return 4

/-- `\newpage`: the paragraph ended, `\vskip -\prevdepth`, `\vfil`, a forced break. -/
def newPage : M Unit := do
  endParagraph
  let s ← get
  if s.vPrev > ignoreDepth then pushV (.glue { width := -s.vPrev } 0)
  pushV (.glue { stretch := 65536, stretchOrder := 1 } 0)
  pushV (.penalty (-10000))
  modify fun s => { s with vPrev := ignoreDepth }

/-- `\begin{name}`. -/
def beginEnv (at_ : Tok) : M Unit := do
  let name ← readWord at_
  let d ← docSt
  match name with
  | "document" =>
    if !d.documentMode then failAt at_ "\\begin{document} without \\documentclass"
    if d.inDocument then failAt at_ "\\begin{document} ended by \\begin{document}"
    modifyDoc fun d => { d with inDocument := true }
  | _ =>
    if !d.inDocument && d.documentMode then failAt at_ "Missing \\begin{document}"
    beginGroup at_
    let depth := (← get).groups.size
    modifyDoc fun d => { d with envs := d.envs.push { name, depth } }
    if !(← beginNamed at_ name) then
      failAt at_ s!"Environment {name} undefined"
where
  /-- The environment's own beginning; whether it is known. -/
  beginNamed (at_ : Tok) (name : String) : M Bool := do
    if ← beginListEnv at_ name then
      setEnd #[csT "leantex@endlist" at_]
      return true
    return false
  /-- Sets the innermost environment's end code. -/
  setEnd (ts : Array Tok) : M Unit :=
    modifyDoc fun d => { d with envs := d.envs.modify (d.envs.size - 1) fun e =>
                                { e with end_ := ts } }

/-- `\end{name}`. -/
def endEnv (at_ : Tok) : M Unit := do
  let name ← readWord at_
  let d ← docSt
  if name == "document" then
    if !d.inDocument then failAt at_ "\\end{document} without \\begin{document}"
    if let some e := d.envs.back? then
      failAt at_ s!"\\begin\{{e.name}} ended by \\end\{document}"
    newPage
    modifyDoc fun d => { d with ended := true }
    -- everything after \end{document} is ignored
    modify fun s => { s with input := #[] }
    return
  match d.envs.back? with
  | none => failAt at_ s!"\\end\{{name}} without \\begin"
  | some e =>
    if e.name != name then failAt at_ s!"\\begin\{{e.name}} ended by \\end\{{name}}"
    inject at_ (e.end_ ++ #[csT "leantex@endenv" at_])

/-- The end of an environment after its own end code: the group closed. -/
def endEnvGroup (at_ : Tok) : M Unit := do
  let e := (← docSt).envs.back?
  modifyDoc fun d => { d with envs := d.envs.pop }
  endGroup at_
  if let some e := e then
    if isListEnv e.name then modifyDoc fun d => { d with endPe := true }

/-- Closes a group: a nested vertical list or a box that began with it is finished. -/
def closeGroup (at_ : Tok) : M Unit := endGroup at_

/-- An alignment tab `&` (only inside a table). -/
def alignTab (at_ : Tok) : M Unit := failAt at_ "Misplaced alignment tab character &"

/-- The document layer's commands (see the module docstrings); `false` for a command it does
not carry out. -/
def docCommand (t : Tok) (name : String) : M Bool := do
  let d ← docSt
  if d.documentMode then
    if (← setSize name) then return true
  match name with
  | "documentclass" => documentClass t
  | "usepackage" | "RequirePackage" => usePackage t
  | "begin" => beginEnv t
  | "end" => endEnv t
  | "leantex@endenv" => endEnvGroup t
  | "section" | "subsection" | "subsubsection" | "paragraph" | "subparagraph" =>
    match sectionSpec? name with
    | some spec => heading t name spec
    | none => return false
  | "leantex@afterheading" => afterHeading t
  | "leantex@runin" => runIn t
  | "leantex@startpar" | "leavevmode" => startParagraph
  | "leantex@ignorespaces" | "ignorespaces" =>
    if let some u ← nextNonSpace? then unread #[u]
  | "leantex@hanglast" =>
    flushRun
    match (← get).hlist.back? with
    | some (.box w ..) => modifyVars fun v => { v with p := { v.p with hangIndent := w } }
    | _ => pure ()
  | "leantex@addleftskip" =>
    let arg ← readArg t
    let saved := (← get).input
    modify fun s => { s with input := arg.reverse }
    let (w, _) ← readDimen t
    modify fun s => { s with input := saved }
    modifyVars fun v => { v with p := { v.p with leftSkip :=
                                 { v.p.leftSkip with width := v.p.leftSkip.width + w } } }
  | "leantex@hskipleft" =>
    startParagraph
    push (.glue { width := -(← vars).p.leftSkip.width } 0)
  | "leantex@dotfill" =>
    startParagraph
    push (.glue { stretch := 65536, stretchOrder := 2 } 100)
  | "leantex@tocline" => tocLine t
  | "item" => item t
  | "leantex@labelbox" => labelBox t
  | "leantex@fitlast" => fitLast t
  | "leantex@endlist" => endList t
  | "\\" =>
    if !(← vars).crPar then return false
    let _ ← readStar
    let skip ← readOptional?
    endParagraph
    if let some sk := skip then
      let saved := (← get).input
      modify fun s => { s with input := sk.reverse }
      let g ← readGlue t
      modify fun s => { s with input := saved }
      pushV (.glue g 0)
  | "centering" | "raggedright" | "raggedleft" =>
    let (ls, rs, pf) := match name with
      | "centering" => (flushGlue, flushGlue, ({} : Glue))
      | "raggedright" => ({}, flushGlue, flushGlue)
      | _ => (flushGlue, {}, {})
    modifyVars fun v => { v with p := { v.p with leftSkip := ls, rightSkip := rs },
                                 parIndent := 0, parFillSkip := pf, crPar := true }
  | "par" =>
    if !(← get).hmode then modifyDoc fun d => { d with endPe := false }
    return false
  | "tableofcontents" => tableOfContents t
  | "begingroup" => beginGroup t
  | "endgroup" => closeGroup t
  | "null" => inject t #[csT "hbox" t, .char '{' 1 t.pos, .char '}' 2 t.pos]
  | "label" => label t
  | "ref" => reference t false false
  | "pageref" => reference t true false
  | "eqref" => reference t false true
  | "newcounter" =>
    let n ← readWord t
    let within ← readOptional?
    if ← hasCounter n then failAt t s!"Counter '{n}' already defined"
    defineCounter n ((within.map fun w => (tokText w).trimAscii.toString))
  | "setcounter" =>
    let n ← readWord t
    let v ← readNumberArg t
    needCounter t n
    modifyDoc fun d => { d with counters := d.counters.set n v }
  | "addtocounter" =>
    let n ← readWord t
    let v ← readNumberArg t
    needCounter t n
    modifyDoc fun d => { d with counters := d.counters.add n v }
  | "stepcounter" => stepCounter t (← readWord t)
  | "refstepcounter" => refStepCounter t (← readWord t)
  | "value" =>
    let n ← readWord t
    needCounter t n
    inject t (textToks t (toString ((← docSt).counters.value n)))
  | "the" =>
    match ← next? with
    | some (.cs "value" _) =>
      let n ← readWord t
      needCounter t n
      inject t (textToks t (toString ((← docSt).counters.value n)))
    | some u => failAt u "\\the is supported before \\value only"
    | none => failAt t "Missing argument of \\the"
  | "arabic" | "roman" | "Roman" | "alph" | "Alph" | "fnsymbol" =>
    let n ← readWord t
    needCounter t n
    let st := (NumberStyle.ofName? name).getD .arabic
    match st.format? ((← docSt).counters.value n) with
    | some s => inject t (textToks t s)
    | none => failAt t "Counter too large"
  | "newpage" | "clearpage" | "cleardoublepage" => newPage
  | "pagebreak" =>
    let n ← readPriority t
    if (← get).hmode then
      adjustV (.penalty (-(breakPenalty n)))
    else
      endParagraph
      addPenaltyAlways (-(breakPenalty n))
  | "nopagebreak" =>
    let n ← readPriority t
    if (← get).hmode then adjustV (.penalty (breakPenalty n))
    else
      endParagraph
      addPenaltyAlways (breakPenalty n)
  | "vfill" =>
    endParagraph
    pushV (.glue { stretch := 65536, stretchOrder := 2 } 0)
  | "vfil" =>
    endParagraph
    pushV (.glue { stretch := 65536, stretchOrder := 1 } 0)
  | "vskip" =>
    let g ← readGlue t
    endParagraph
    pushV (.glue g 0)
  | "smallskip" | "medskip" | "bigskip" =>
    let k : Int := if name == "smallskip" then 1 else if name == "medskip" then 2 else 4
    endParagraph
    pushV (.glue { width := 3 * k * 65536, stretch := k * 65536, shrink := k * 65536 } 0)
  | "addvspace" =>
    let g ← readGlueArg t
    if (← get).hmode then failAt t "Something's wrong--perhaps a missing \\item"
    addVSpace g
  | "pagestyle" =>
    let st ← readWord t
    if st != "plain" && st != "empty" then
      failAt t s!"Page style '{st}' is not available (plain and empty are)"
    modifyDoc fun d => { d with pageStyle := st }
  | "thispagestyle" =>
    let st ← readWord t
    if st != "plain" && st != "empty" then
      failAt t s!"Page style '{st}' is not available (plain and empty are)"
    let a ← newAnchor
    adjustV (.label a)
    modifyDoc fun d => { d with thisPageStyles := d.thisPageStyles.push (a, st) }
  | _ => return false
  return true
where
  /-- A number argument (`\setcounter{x}{3}`, `{\value{y}}`). -/
  readNumberArg (at_ : Tok) : M Int := do
    let arg ← readArg at_
    let txt ← expandText at_ arg
    match txt.trimAscii.toString.toInt? with
    | some v => return v
    | none => failAt at_ s!"Missing number (got '{txt}')"
  /-- LaTeX's `\pagebreak` and `\nopagebreak` in vertical mode: the penalty, moved before a
  final skip. -/
  addPenaltyAlways (p : Int) : M Unit := do
    let ls ← lastSkip
    if ls.width == 0 then pushV (.penalty p)
    else
      pushV (.glue (negGlue ls) 0)
      pushV (.penalty p)
      pushV (.glue ls 0)

end LeAnTeX.Text.Typeset
