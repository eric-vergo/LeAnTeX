/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Doc.Blocks

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

/-- `\newpage`: the paragraph ended, `\vskip -\pagedepth` (the page's last depth, as LuaLaTeX
shows it), `\vfil`, a forced break. -/
def newPage : M Unit := do
  endParagraph
  pushV (.mark "@pagedepth")
  pushV (.glue { stretch := 65536, stretchOrder := 1 } 0)
  pushV (.penalty (-10000))
  modify fun s => { s with vPrev := ignoreDepth }

/-- `\begin{figure}[placement]` (and `table`): a nested vertical list for the float's body,
in the normal size and font, the full column width. -/
def beginFloat (at_ : Tok) (kind : String) : M Unit := do
  let opt ← readOptional?
  let placement := match opt with
    | some ts => (tokText ts).trimAscii.toString
    | none => "tbp"
  let placement := if placement.isEmpty then "tbp" else placement
  for c in placement.toList do
    if !"htbpH!".contains c then failAt at_ s!"Unknown float option '{c}'"
  let idx := (← docSt).floats.size
  modifyDoc fun d => { d with floats := d.floats.push { kind, placement } }
  openFrame (.float idx)
  let cp ← classP
  let normal := (cp.sizes.find? (·.name == "normalsize")).getD ⟨"normalsize", 655360, 786432⟩
  modifyVars fun v =>
    { v with
      key := { family := .roman, bold := false, shape := .upright, size := normal.size },
      baselineSkip := { width := normal.baseline },
      p := { v.p with hsize := cp.textWidth, leftSkip := {}, rightSkip := {} },
      lineWidth := none, totalLeftMargin := 0, parFillSkip := flushGlue, crPar := false,
      parIndent := cp.parIndent }
  modifyDoc fun d => { d with noBreak := true }

/-- `\caption[short]{text}`: the float's counter stepped, `\abovecaptionskip`, then "Figure
n: text" centred on a line of its own when it fits, else as a paragraph, then
`\belowcaptionskip`. -/
def caption (at_ : Tok) : M Unit := do
  let _ ← readOptional?
  let text ← readArg at_
  let some fr := (← get).nest.back? | failAt at_ "\\caption outside float"
  let .float idx := fr.kind | failAt at_ "\\caption outside float"
  let kind := (((← docSt).floats[idx]?).map (·.kind)).getD "figure"
  refStepCounter at_ kind
  let num ← theCounter at_ kind
  modifyDoc fun d => { d with floats := d.floats.modify idx fun f => { f with number := num } }
  endParagraph
  pushV (.glue { width := 10 * 65536 } 0)
  let name := if kind == "figure" then "Figure" else "Table"
  let p := at_.pos
  inject at_ (#[csT "hbox" at_, Tok.char '{' 1 p] ++ textToks at_ (name ++ "~" ++ num ++ ": ") ++
    text ++ #[Tok.char '}' 2 p, csT "leantex@captionfit" at_])

/-- After a caption's box: centred on a line of the column's width when it fits, else its
content made a paragraph of its own. -/
def captionFit (at_ : Tok) : M Unit := do
  flushRun
  let s ← get
  let v ← vars
  match s.hlist.back? with
  | some (.box w h d _ c) =>
    if w ≤ v.p.hsize then
      let fil : HNode := .glue { stretch := 65536, stretchOrder := 1 } 0
      let nodes := #[fil, HNode.box w h d 0 c, fil]
      let (nat, st, sh, _, _) := measure nodes
      let g := hpackGlue nat v.p.hsize st sh
      set { s with hmode := false, hlist := #[] }
      appendV (.hbox v.p.hsize h d 0 (freezeGlue nodes g) {})
    else
      set { s with hlist := s.hlist.pop ++ c }
      endParagraph
  | _ => endParagraph
  pushV (.glue {} 0)
  let _ := at_

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
    let d ← docSt
    if let some e := d.environments[name]? then
      beginUserEnv at_ e
      setEnd e.end_
      return true
    if let some th := d.theorems[name]? then
      beginTheorem at_ th
      setEnd #[csT "leantex@endlist" at_]
      return true
    if name == "proof" then
      beginProof at_
      setEnd #[csT "leantex@qed" at_, csT "leantex@endlist" at_]
      return true
    if ["equation", "equation*", "displaymath", "align", "align*", "gather", "gather*",
        "multline", "multline*", "flalign", "flalign*"].contains name then
      equationEnv at_ name
      return true
    if name == "abstract" then
      let p := at_.pos
      let lb := Tok.char '{' 1 p
      let rb := Tok.char '}' 2 p
      inject at_ (#[csT "small" at_, csT "begin" at_, lb] ++ textToks at_ "center" ++
        #[rb, lb, csT "bfseries" at_] ++ textToks at_ "Abstract" ++ #[csT "vspace" at_, lb] ++
        textToks at_ "-.5em" ++ #[rb, csT "vspace" at_, lb] ++ textToks at_ "0pt" ++
        #[rb, rb, csT "end" at_, lb] ++ textToks at_ "center" ++ #[rb, csT "begin" at_, lb] ++
        textToks at_ "quotation" ++ #[rb])
      setEnd (#[csT "end" at_, lb] ++ textToks at_ "quotation" ++ #[rb])
      return true
    if name == "tabular" then
      beginTabular at_
      setEnd #[csT "leantex@endtabular" at_]
      return true
    if name == "figure" || name == "table" || name == "figure*" || name == "table*" then
      beginFloat at_ (if name.startsWith "figure" then "figure" else "table")
      setEnd #[csT "leantex@endfloat" at_]
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
    pushV (.mark "@clearpage")
    modifyDoc fun d => { d with ended := true }
    -- everything after \end{document} is ignored
    modify fun s => { s with input := #[] }
    return
  match d.envs.back? with
  | none => failAt at_ s!"\\end\{{name}} without \\begin"
  | some e =>
    if e.name != name then
      -- an environment whose own beginning opened others: its end code closes them first
      -- (LaTeX runs the end code before it checks the name)
      match (List.range d.envs.size).reverse.find?
          (fun i => (d.envs[i]?.map EnvFrame.name) == some name) with
      | some i =>
        let code := (d.envs[i]?.map EnvFrame.end_).getD #[]
        if code.isEmpty then failAt at_ s!"\\begin\{{e.name}} ended by \\end\{{name}}"
        modifyDoc fun d => { d with envs := d.envs.modify i fun f => { f with end_ := #[] } }
        let p := at_.pos
        inject at_ (code ++ #[csT "end" at_, Tok.char '{' 1 p] ++ textToks at_ name ++
          #[Tok.char '}' 2 p])
      | none => failAt at_ s!"\\begin\{{e.name}} ended by \\end\{{name}}"
    else inject at_ (e.end_ ++ #[csT "leantex@endenv" at_])

/-- LaTeX's script size (`\sf@size`) for a text size: the defaults of its math sizes. -/
def scriptSize (size : Int) : Int :=
  let pt := fun (x : Nat) => (x * 65536 / 100 : Nat)
  let table : List (Nat × Nat) := [(500, 500), (600, 500), (700, 500), (800, 600), (900, 600),
    (1000, 700), (1095, 800), (1200, 800), (1440, 1000), (1728, 1200), (2074, 1440),
    (2488, 2074)]
  match table.find? (fun (t, _) => (pt t : Int) ≥ size - 655) with
  | some (_, s) => (pt s : Int)
  | none => size * 7 / 10

/-- A superscript mark (LaTeX's `\@textsuperscript`, a formula's superscript of a box): `text`
in the normal font at the script size of `size`, raised by the superscript shift of the math
fonts at `size` (`\fontdimen13` of the symbol font, 0.412892 em). -/
def superscriptBox (text : String) (size : Int) : M HNode := do
  let tf ← fontFor { size := scriptSize size }
  let g := tf.shape text.toList.toArray
  let (w, _, _, h, d) := measure g
  -- TeX's superscript shift in text style: `\fontdimen14` (sup2) of the symbol font of the
  -- size: Computer Modern's cmsy10 (scaled for 10 pt and above) and cmsy8
  let sup2 : Int := if size ≤ 8 * 65536 then 352917 else if size < 10 * 65536 then 357900
    else 362892
  let shift := (size * sup2 + 500000) / 1000000
  return .box w (h + shift) (max 0 (d - shift)) 0 #[.box w h d (-shift) g]

/-- The depth of LaTeX's `\strutbox` at a `\baselineskip`: 0.3 of it. -/
def strutDepth (baseline : Int) : Int := texTimes baseline 0 19661

/-- `\footnote[n]{text}`: the counter stepped (or set), the mark in the text after a
`\nobreak` (the space factor kept), and the text as an insertion (LaTeX's `\@footnotetext`
and the article class's `\@makefntext`): in the footnote size, `\interlinepenalty` 100, the
full column width, the mark flush right in a box 1.8 em wide, a strut of `\footnotesep` at the
start and of the strut's depth at the end. -/
def footnote (at_ : Tok) (thanks : Bool := false) : M Unit := do
  let opt ← if thanks then pure none else readOptional?
  let body ← readArg at_
  match opt with
  | some n =>
    let v := ((tokText n).trimAscii.toString.toInt?).getD 0
    modifyDoc fun d => { d with counters := d.counters.set "footnote" v }
  | none => stepCounter at_ "footnote"
  let mark ← if thanks then do
      let v := (← docSt).counters.value "footnote"
      pure (if v == 1 then "∗" else (NumberStyle.fnsymbol.format? v).getD "?")
    else theCounter at_ "footnote"
  if thanks then
    modifyDoc fun d => { d with steps := d.steps.modify (d.steps.size - 1) fun (n, _) =>
      (n, mark) }
  let size := (← vars).key.size
  startParagraph
  push (.penalty 10000)
  let sf := (← get).sf
  let mb ← superscriptBox mark size
  -- a title's mark takes no width (LaTeX's `\rlap`)
  push (if thanks then match mb with
      | .box _ h d s c => .box 0 h d s c
      | b => b
    else mb)
  modify fun s => { s with sf }
  let cp ← classP
  let some fs ← classSize "footnotesize" | failAt at_ "internal: no footnote size"
  beginGroup at_
  openFrame .footnote
  modifyDoc fun d => { d with currentLabel := mark }
  modifyVars fun v =>
    { v with
      key := { family := .roman, bold := false, shape := .upright, size := fs.size },
      baselineSkip := { width := fs.baseline }, interlinePenalty := 100,
      p := { v.p with hsize := cp.textWidth, leftSkip := {}, rightSkip := {} },
      lineWidth := none, totalLeftMargin := 0, parFillSkip := flushGlue, crPar := false }
  let p := at_.pos
  let lb := Tok.char '{' 1 p
  let rb := Tok.char '}' 2 p
  inject at_ (#[csT "parindent" at_] ++ textToks at_ "1em " ++ #[csT "noindent" at_,
    csT "hbox" at_] ++ textToks at_ "to 1.8em" ++ #[lb, csT "hss" at_,
    csT "leantex@supmark" at_, lb] ++ textToks at_ mark ++ #[rb, rb,
    csT "leantex@strut" at_, lb] ++ textToks at_ s!"{cp.footnoteSep}" ++ #[rb] ++
    #[csT "leantex@ignorespaces" at_] ++ body ++
    #[csT "leantex@finalstrut" at_, rb])

/-- Closes a group: a nested vertical list or a box that began with it is finished; a
footnote's list becomes its insertion. -/
def closeGroup (at_ : Tok) : M Unit := do
  let s ← get
  if let some fr := s.nest.back? then
    if fr.depth == s.groups.size then
      let v ← vars
      let cp ← classP
      if let some (kind, content) ← closeFrame then
        match kind with
        | .footnote =>
          adjustV (.ins 254 content { width := cp.footnoteSep }
            (strutDepth v.baselineSkip.width) 20000)
        | .float idx =>
          let box := vpack content
          modifyDoc fun d => { d with floats := d.floats.modify idx fun f => { f with box } }
          adjustV (.float idx)
        | _ => pure ()
  endGroup at_

/-- The end of an environment after its own end code: the group closed. -/
def endEnvGroup (at_ : Tok) : M Unit := do
  let e := (← docSt).envs.back?
  modifyDoc fun d => { d with envs := d.envs.pop }
  closeGroup at_
  if let some e := e then
    if isListEnv e.name then modifyDoc fun d => { d with endPe := true }

/-- An alignment tab `&` (only inside a table). -/
def alignTab (at_ : Tok) : M Unit := nextCell at_

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
  | "footnote" => footnote t
  | "includegraphics" => includeGraphics t
  | "thanks" => footnote t (thanks := true)
  | "newenvironment" => newEnvironment t false
  | "renewenvironment" => newEnvironment t true
  | "newtheorem" => newTheorem t
  | "theoremstyle" =>
    let st ← readWord t
    modifyDoc fun d => { d with theoremStyle := st }
  | "leantex@qed" | "qed" => qed t
  | "leantex@null" =>
    if (← get).hmode then push (.box 0 0 0 0 #[]) else appendV (.hbox 0 0 0 0 #[] {})
  | "\uE001" =>
    startParagraph
    let txt := unhex (← readWord t)
    beginGroup t
    verbText txt
    endGroup t
  | "\uE000" =>
    let txt := unhex (← readWord t)
    beginGroup t
    beginList t id (trivial := true)
    modifyVars fun v => { v with parIndent := 0, parFillSkip := flushGlue, parSkip := {},
                                 p := { v.p with leftSkip := {}, rightSkip := {} } }
    let ls := (txt.splitOn "\n").toArray
    for h : k in [0:ls.size] do
      if k == 0 then
        item t
        flushRun
      else
        modify fun s => { s with noIndent := true }
        startParagraph
      verbText ls[k]
      if ls[k].isEmpty then push (.box 0 0 0 0 #[])
      endParagraph
    endList t
    endGroup t
    modifyDoc fun d => { d with endPe := true }
  | "'" | "`" | "^" | "\"" | "~" | "=" | "." | "u" | "v" | "H" | "c" | "r" | "k" =>
    accent t name
  | "i" | "j" | "aa" | "AA" | "ae" | "AE" | "oe" | "OE" | "o" | "O" | "ss" | "l" | "L" =>
    addChar ((specialLetter? name).getD '?')
  | "hrule" =>
    let (w, h, dp) ← ruleSpec t none none none
    endParagraph
    pushV (.rule w (h.getD 26214) (dp.getD 0))
    modify fun s => { s with vPrev := ignoreDepth }
  | "vrule" =>
    let size := (← vars).key.size
    let (w, h, dp) ← ruleSpec t none none none
    startParagraph
    push (.rule (w.getD 26214) (h.getD (size * 3 / 4)) (dp.getD (size / 4)))
  | "newlength" =>
    let some (.cs reg _) := (← readArg t).toList.find? (!·.isSpace)
      | failAt t "Missing length register"
    if (← docSt).lengths.contains reg || (← dimenOf reg).isSome then
      failAt t s!"\\{reg} already defined"
    modifyDoc fun d => { d with lengths := d.lengths.insert reg {} }
  | "addtolength" => addToLength t false
  | "setlength" =>
    let saved := (← get).input
    let arg ← readArg t
    let some (.cs reg _) := arg.toList.find? (!·.isSpace) | unread #[t]; return false
    modify fun s => { s with input := saved }
    if !(← docSt).lengths.contains reg then return false
    addToLength t true
  | "title" => let a ← readArg t; modifyDoc fun d => { d with title := a }
  | "author" => let a ← readArg t; modifyDoc fun d => { d with author := a }
  | "date" => let a ← readArg t; modifyDoc fun d => { d with date := some a }
  | "today" =>
    let (cfg, _) ← read
    inject t (textToks t cfg.today)
  | "and" =>
    let p := t.pos
    inject t (#[csT "end" t, .char '{' 1 p] ++ textToks t "tabular" ++ #[.char '}' 2 p,
      csT "hskip" t] ++ textToks t "1em plus .17fil" ++ #[csT "begin" t, .char '{' 1 p] ++
      textToks t "tabular" ++ #[.char '}' 2 p] ++ textToks t "[t]" ++ #[.char '{' 1 p] ++
      textToks t "c" ++ #[.char '}' 2 p])
  | "maketitle" => makeTitle t
  | "leantex@endtitle" =>
    modifyDoc fun d => { d with inTitle := false, counters := d.counters.set "footnote" 0 }
  | "leantex@supmark" =>
    let txt ← readWord t
    push (← superscriptBox txt (← vars).key.size)
  | "leantex@strut" =>
    let h := ((← readWord t).toInt?).getD 0
    startParagraph
    push (.rule 0 h 0)
  | "leantex@finalstrut" =>
    if (← get).hmode then
      flushRun
      modify fun s => { s with hlist := match s.hlist.back? with
                               | some (.glue ..) => s.hlist.pop
                               | _ => s.hlist }
      push (.penalty 10000)
      push (.rule 0 0 (strutDepth (← vars).baselineSkip.width))
  | "item" => item t
  | "leantex@endtabular" => endTabular t
  | "hline" => hline t
  | "multicolumn" => multicolumn t
  | "leantex@labelbox" => labelBox t
  | "leantex@fitlast" => fitLast t
  | "leantex@endlist" => endList t
  | "\\" =>
    if (← curTable).isSome then
      endRow t
      return true
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
  | "newpage" => newPage
  | "clearpage" | "cleardoublepage" =>
    newPage
    pushV (.mark "@clearpage")
  | "caption" => caption t
  | "leantex@captionfit" => captionFit t
  | "leantex@endfloat" =>
    endParagraph
    pushV (.glue {} 0)
  | "rule" =>
    let r ← readOptional?
    let raise ← match r with
      | some ts => dimOf t ts
      | none => pure 0
    let w ← dimOf t (← readArg t)
    let h ← dimOf t (← readArg t)
    startParagraph
    push (.box w (h + raise) (max 0 (-raise)) 0 #[.rule w (h + raise) (-raise)])
  | "pagebreak" =>
    let n ← readPriority t
    if (← get).hmode then
      adjustV (.penalty (-(breakPenalty n)))
    else
      endParagraph
      addPenaltyAlways (-(breakPenalty n))
  | "linebreak" | "nolinebreak" =>
    -- LaTeX's `\@no@lnbk`: the last glue taken off, the penalty, the glue put back after it
    -- and the spaces that follow ignored; an error between paragraphs
    let n ← readPriority t
    if !(← get).hmode then failAt t s!"\\{name}: there's no line here to end"
    flushRun
    let saved := match (← get).hlist.back? with
      | some (.glue g st) => some (g, st)
      | _ => none
    if saved.isSome then modify fun s => { s with hlist := s.hlist.pop }
    let pen := breakPenalty n
    push (.penalty (if name == "linebreak" then -pen else pen))
    if let some (g, st) := saved then
      push (.glue g st)
      inject t #[csT "leantex@ignorespaces" t]
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
    -- `\vspace{\smallskipamount}` …: after the current line in a paragraph
    let k : Int := if name == "smallskip" then 1 else if name == "medskip" then 2 else 4
    vspace { width := 3 * k * 65536, stretch := k * 65536, shrink := k * 65536 }
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
  /-- A dimension from tokens. -/
  dimOf (at_ : Tok) (ts : Array Tok) : M Int := do
    let saved := (← get).input
    modify fun s => { s with input := ts.reverse }
    let (d, _) ← readDimen at_
    modify fun s => { s with input := saved }
    return d
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
