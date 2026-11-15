/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Text.Typeset
import LeAnTeX.Doc.Class
import LeAnTeX.Doc.Counters

/-!
# The document layer's commands: structure

LaTeX's document structure on top of the text front end: `\documentclass{article}` with its
options, the preamble and `\begin{document}`, the title block, sectioning, the table of
contents, counters, labels and references, lengths, page breaks and vertical skips, and page
styles. The behaviour is LaTeX's as its documentation describes it and as LuaLaTeX shows it
(`fixtures/doc/`); the commands are carried out directly or as short token sequences of the
front end's own internal commands (named with `@`, which source text cannot reach).

* **Headings** (LaTeX's `\@startsection`): `\addpenalty{\@secpenalty}` and `\addvspace` of the
  skip before (in the current font's ex), unless the heading follows another; the number
  (stepped, `\the…` followed by a quad) in a box that the heading hangs from; the title in
  the heading's font with `\interlinepenalty` 10000; then a penalty of 10000 and the skip after,
  and the next paragraph without indentation and without a break after its first line. Run-in
  headings (`\paragraph`, `\subparagraph`) start the next paragraph. Levels above 3 are not
  numbered (`secnumdepth` 3).
* **Counters**: `\newcounter{x}[y]`, `\setcounter`, `\addtocounter`, `\stepcounter`,
  `\refstepcounter` (which sets the text a `\label` records), `\value`, `\the<x>` (a macro,
  redefinable), `\arabic` … `\fnsymbol`.
* **References**: `\label` records the current label's text and an anchor in the vertical list
  (its page is the page the anchor falls on); `\ref`, `\pageref` and `\eqref` give the previous
  pass's answer, or `??` with a warning, as LaTeX does on its first run.
* **Vertical**: `\addvspace` and `\addpenalty` as LaTeX defines them (comparing with
  `\lastskip`), `\smallskip`, `\medskip`, `\bigskip`, `\vfill`, `\vskip`, `\newpage`,
  `\clearpage`, `\pagebreak`, `\nopagebreak`.
-/

namespace LeAnTeX.Text.Typeset

open LeAnTeX.Doc

/-- The document state. -/
def docSt : M DocState := return (← get).doc

/-- Changes the document state. -/
def modifyDoc (f : DocState → DocState) : M Unit :=
  modify fun s => { s with doc := f s.doc }

/-- A control sequence token for the front end's own use. -/
def csT (name : String) (at_ : Tok) : Tok := .cs name at_.pos

/-- The source text of tokens. -/
def tokText (ts : Array Tok) : String := String.join (ts.toList.map Tok.text)

/-- Reads an argument as a word (its text, spaces around it removed). -/
def readWord (at_ : Tok) : M String := return (tokText (← readArg at_)).trimAscii.toString

/-- Unreads tokens, counting them against the expansion caps. -/
def inject (at_ : Tok) (ts : Array Tok) : M Unit := do
  countExpansion at_ ts.size
  unread ts

/-- The tokens of a text, at the position of `at_`. -/
def textToks (at_ : Tok) (s : String) : Array Tok :=
  (tokenize s).map fun t => match t with
    | .cs n _ => .cs n at_.pos
    | .char c k _ => .char c k at_.pos
    | t => t

/-- The class's parameters in force. -/
def classP : M ClassParams := return classParams (← docSt).options

/-- The last item of the vertical list if it is glue: TeX's `\lastskip` (zero glue
otherwise). -/
def lastSkip : M Glue := do
  match (← get).vlist.back? with
  | some (.glue g _) => return g
  | _ => return {}

/-- The negation of glue. -/
def negGlue (g : Glue) : Glue :=
  { g with width := -g.width, stretch := -g.stretch, shrink := -g.shrink }

/-- LaTeX's `\addvspace{s}` in vertical mode: `s` when the list does not end in glue;
otherwise `s` in place of the last glue when it is larger (a `\vskip -\lastskip` and the
new skip), and nothing else. Nothing after a heading or at a list's start (`\@nobreak`). -/
def addVSpace (g : Glue) : M Unit := do
  let ls ← lastSkip
  if ls.width == 0 then pushV (.glue g 0)
  else if ls.width < g.width then
    pushV (.glue (negGlue ls) 0)
    pushV (.glue g 0)
  else if g.width < 0 && ls.width ≥ 0 then
    let sum : Glue := { g with width := g.width + ls.width, stretch := g.stretch + ls.stretch,
                                shrink := g.shrink + ls.shrink }
    pushV (.glue (negGlue ls) 0)
    pushV (.glue sum 0)

/-- LaTeX's `\addpenalty{p}` in vertical mode: a penalty, moved before a final skip so that
the skip stays after it. As LaTeX does since 2020, the skip taken back before the penalty
includes the depth of the last box (`\prevdepth`, at most `\maxdepth`, nothing when it is
ignored) and that depth is given back after the penalty, so that a page that ends at the
penalty ends at the box's baseline. Nothing after a heading. -/
def addPenalty (p : Int) : M Unit := do
  if (← docSt).noBreak then return
  let ls ← lastSkip
  if ls.width == 0 then pushV (.penalty p)
  else
    let pv := (← get).vPrev
    let md := (← classP).maxDepth
    let pd := if pv ≤ ignoreDepth then 0 else min pv md
    pushV (.glue (negGlue { ls with width := ls.width + pd }) 0)
    pushV (.penalty p)
    if pd != 0 then pushV (.glue { width := pd } 0)
    pushV (.glue ls 0)

/-! ### Counters and their numbers -/

/-- A new anchor key for a place in the vertical list. -/
def newAnchor : M String := do
  let d ← docSt
  modifyDoc fun d => { d with anchors := d.anchors + 1 }
  return s!"@anchor{d.anchors}"

/-- Defines a counter with `\the<name>` printing it in arabic (or `fmt`). -/
def defineCounter (name : String) (within : Option String := none)
    (fmt : Option String := none) : M Unit := do
  modifyDoc fun d => { d with counters := d.counters.newCounter name within }
  let body := tokenize (fmt.getD s!"\\arabic\{{name}}")
  modifyVars fun v => { v with macros := v.macros.insert ("the" ++ name) { params := 0, body } }

/-- Whether a counter is defined. -/
def hasCounter (name : String) : M Bool := return (← docSt).counters.table.contains name

/-- Fails unless a counter is defined. -/
def needCounter (at_ : Tok) (name : String) : M Unit := do
  if !(← hasCounter name) then failAt at_ s!"No counter '{name}' defined"

/-- The tokens' text with macros, `\arabic`-style numbers and `\the`, `\value` expanded, the
other control sequences kept as their source text (what a `\label` records and a `\ref`
prints). Bounded by the expansion caps. -/
def expandText (at_ : Tok) (ts : Array Tok) : M String := do
  let saved := (← get).input
  modify fun s => { s with input := ts.reverse }
  let mut out := ""
  let (cfg, _) ← read
  for _ in [0:cfg.maxExpansions + ts.size + 1] do
    match ← next? with
    | none => break
    | some t =>
      match t with
      | .cs name _ =>
        let v ← vars
        if let some m := v.macros[name]? then expandMacro t m
        else if let some st := NumberStyle.ofName? name then
          let c ← readWord t
          let n := (← docSt).counters.value c
          out := out ++ (st.format? n).getD "?"
        else if name == "value" then
          let c ← readWord t
          out := out ++ toString ((← docSt).counters.value c)
        else if name == "the" then
          match ← next? with
          | some (.cs "value" _) =>
            let c ← readWord t
            out := out ++ toString ((← docSt).counters.value c)
          | some u => unread #[u]
          | none => pure ()
        else if name == "protect" || name == "relax" then pure ()
        else out := out ++ t.text
      | .char '{' 1 _ | .char '}' 2 _ => pure ()
      | t => out := out ++ t.text
  let _ := at_
  modify fun s => { s with input := saved }
  return out

/-- The printed value of a counter (`\the<name>` expanded). -/
def theCounter (at_ : Tok) (name : String) : M String :=
  expandText at_ #[.cs ("the" ++ name) at_.pos]

/-- Steps a counter (`\stepcounter`), recording the step. -/
def stepCounter (at_ : Tok) (name : String) : M Unit := do
  needCounter at_ name
  modifyDoc fun d => { d with counters := d.counters.step name }
  let txt ← theCounter at_ name
  modifyDoc fun d => { d with steps := d.steps.push (name, txt) }

/-- `\refstepcounter`: steps it and makes its printed value what a `\label` records. -/
def refStepCounter (at_ : Tok) (name : String) : M Unit := do
  stepCounter at_ name
  -- an enumerate level's reference carries the levels above it (LaTeX's `\p@enumii` …)
  let pre := match name with
    | "enumii" => "\\theenumi "
    | "enumiii" => "\\theenumi (\\theenumii )"
    | "enumiv" => "\\theenumi (\\theenumii )\\theenumiii "
    | _ => ""
  let txt ← expandText at_ (tokenize (pre ++ "\\the" ++ name ++ " "))
  modifyDoc fun d => { d with currentLabel := txt }

/-! ### Labels and references -/

/-- `\label{key}`: the current label's text and an anchor where it is. -/
def label (at_ : Tok) : M Unit := do
  let key ← readWord at_
  let d ← docSt
  if d.labels.any (·.1 == key) then
    modifyDoc fun d => { d with warnings := d.warnings.push s!"Label '{key}' multiply defined" }
  modifyDoc fun d => { d with labels := d.labels.push (key, d.currentLabel) }
  adjustV (.label key)
  -- LaTeX writes the label to its auxiliary file; in vertical mode right after a heading
  -- (`@nobreak`) the write is followed by `\nobreak` twice, as LuaLaTeX shows. An item's
  -- label still leaves TeX in vertical mode (LaTeX's `@inlabel`): the paragraph here holds no
  -- more than that label, and the penalties go before its `\parskip`.
  let s ← get
  let nb := #[VNode.penalty 10000, VNode.penalty 10000]
  if !s.hmode && d.noBreak then
    for n in nb do pushV n
  else if s.hmode && s.clubMax && s.run.isEmpty &&
      s.hlist.all (fun n => match n with | .box .. | .penalty _ | .glue .. => true | _ => false) then
    match s.vlist.back? with
    | some (.glue g 3) =>
      set { s with vlist := s.vlist.pop ++ nb |>.push (.glue g 3) }
    | _ => pure ()

/-- The previous pass's answer for a key: its text (`page` false) or page; `??` and a warning
when there is none. -/
def refText (key : String) (page : Bool) : M String := do
  match lookupRef (← docSt).refs key page with
  | some s => return s
  | none =>
    modifyDoc fun d => { d with undefinedRefs := d.undefinedRefs.push key }
    return "??"

/-- `\ref`, `\pageref`, `\eqref`: the text set in the current font (bold `??` when undefined,
as LaTeX sets it). -/
def reference (at_ : Tok) (page paren : Bool) : M Unit := do
  let key ← readWord at_
  let txt ← refText key page
  let body := if txt == "??" then #[Tok.char '{' 1 at_.pos, csT "bfseries" at_] ++
      textToks at_ "??" ++ #[Tok.char '}' 2 at_.pos]
    else textToks at_ txt
  let body := if paren then #[Tok.char '(' 12 at_.pos] ++ body ++ #[Tok.char ')' 12 at_.pos]
    else body
  -- `\eqref` sets the number upright, `\ref` in the current font
  let body := if paren then #[Tok.char '{' 1 at_.pos, csT "upshape" at_] ++ body ++
    #[Tok.char '}' 2 at_.pos] else body
  inject at_ (#[csT "mbox" at_, Tok.char '{' 1 at_.pos] ++ body ++ #[Tok.char '}' 2 at_.pos])

/-! ### The class and the preamble -/

/-- The size command's font size and baseline in the class. -/
def classSize (name : String) : M (Option SizeSpec) := do
  return (← classP).sizes.find? (·.name == name)

/-- Sets the font size by a size command of the class, with its `\baselineskip`. -/
def setSize (name : String) : M Bool := do
  let some sz ← classSize name | return false
  flushRun
  modifyVars fun v => { v with key := { v.key with size := sz.size },
                                baselineSkip := { width := sz.baseline } }
  -- `\normalsize`, `\small` and `\footnotesize` also set the display skips and define
  -- `\@listi`
  let cp ← classP
  if name == "normalsize" then
    modifyVars fun v =>
      { v with
        listOne := none, aboveDisplaySkip := cp.displaySkip, belowDisplaySkip := cp.displaySkip
        aboveDisplayShortSkip := { stretch := 3 * 65536 }
        belowDisplayShortSkip := cp.belowShortSkip }
  else if let some (_, one, (disp, short, bshort)) := cp.sizeSkips.find? (·.1 == name) then
    modifyVars fun v =>
      { v with
        listOne := some one, aboveDisplaySkip := disp, belowDisplaySkip := disp
        aboveDisplayShortSkip := short, belowDisplayShortSkip := bshort }
  return true

/-- The counters, lengths and parameters LaTeX's article class starts a document with. -/
def startClass : M Unit := do
  let cp ← classP
  for c in ["part", "section", "equation", "figure", "table", "footnote", "mpfootnote",
      "page", "enumi", "enumii", "enumiii", "enumiv"] do
    defineCounter c
  defineCounter "subsection" (some "section") (some "\\thesection.\\arabic{subsection}")
  defineCounter "subsubsection" (some "subsection")
    (some "\\thesubsection.\\arabic{subsubsection}")
  defineCounter "paragraph" (some "subsubsection")
    (some "\\thesubsubsection.\\arabic{paragraph}")
  defineCounter "subparagraph" (some "paragraph")
    (some "\\theparagraph.\\arabic{subparagraph}")
  defineCounter "enumii" none (some "\\alph{enumii}")
  defineCounter "enumiii" none (some "\\roman{enumiii}")
  defineCounter "enumiv" none (some "\\Alph{enumiv}")
  defineCounter "mpfootnote" none (some "\\alph{mpfootnote}")
  modifyDoc fun d =>
    let cs := (d.counters.newCounter "enumii" (some "enumi")).newCounter "enumiii" (some "enumii")
    let cs := (cs.newCounter "enumiv" (some "enumiii")).set "page" 1
    { d with counters := cs }
  let normal := (cp.sizes.find? (·.name == "normalsize")).getD ⟨"normalsize", 655360, 786432⟩
  modifyVars fun v => { v with
    p := { v.p with hsize := cp.textWidth }
    key := { v.key with size := normal.size }
    baselineSkip := { width := normal.baseline }
    parIndent := cp.parIndent
    aboveDisplaySkip := cp.displaySkip, belowDisplaySkip := cp.displaySkip
    belowDisplayShortSkip := cp.belowShortSkip }
  modifyDoc fun d => { d with lengths := d.lengths.insert "labelsep" { width := cp.labelSep } }

/-- `\documentclass[options]{article}`. -/
def documentClass (at_ : Tok) : M Unit := do
  let opts := ((← readOptional?).map tokText).getD ""
  let cls ← readWord at_
  if (← docSt).documentMode then failAt at_ "\\documentclass can only be used once"
  if cls != "article" then
    failAt at_ s!"Class '{cls}' is not available (only article is)"
  let mut o : ClassOptions := {}
  for raw in opts.splitOn "," do
    let w := raw.trimAscii.toString
    match w with
    | "10pt" => o := { o with size := 10 }
    | "11pt" => o := { o with size := 11 }
    | "12pt" => o := { o with size := 12 }
    | "a4paper" => o := { o with a4 := true }
    | "letterpaper" => o := { o with a4 := false }
    | "oneside" | "onecolumn" | "final" | "draft" | "notitlepage" | "" => pure ()
    | "twocolumn" => failAt at_ "The option twocolumn is not available (one column only)"
    | w => modifyDoc fun d => { d with warnings := d.warnings.push s!"Unused option '{w}'" }
  modifyDoc fun d => { d with documentMode := true, options := o }
  startClass

/-- The packages whose commands the document layer knows (others are reported and ignored). -/
def knownPackages : Array String :=
  #["amsmath", "amssymb", "amsthm", "graphicx", "graphics", "amsfonts", "latexsym", "fontenc",
    "inputenc", "lmodern"]

/-- `\usepackage[options]{a,b}`: recorded; only in the preamble. -/
def usePackage (at_ : Tok) : M Unit := do
  let _ ← readOptional?
  let names ← readWord at_
  if (← docSt).inDocument then failAt at_ "\\usepackage can be used only in the preamble"
  for raw in names.splitOn "," do
    let n := raw.trimAscii.toString
    if !knownPackages.contains n then
      modifyDoc fun d => { d with warnings := d.warnings.push s!"Package '{n}' is not available" }
    modifyDoc fun d => { d with packages := d.packages.push n }

/-! ### Headings -/

/-- A skip of thousandths of the current ex: natural, stretch, shrink. -/
def exSkip (spec : Int × Int × Int) : M Glue := do
  let (_, ex) ← fontUnits
  let t := fun (m : Int) =>
    let a := m.natAbs
    let f := (roundDecimals (digits3 (a % 1000))).toNat
    let v := texTimes ex (a / 1000) f
    if m < 0 then -v else v
  return { width := t spec.1, stretch := t spec.2.1, shrink := t spec.2.2 }
where
  /-- The three decimal digits of a number below 1000. -/
  digits3 (n : Nat) : List Nat := [n / 100, n / 10 % 10, n % 10]

/-- A heading (`\section` … `\subparagraph`): see the module docstring. -/
def heading (at_ : Tok) (name : String) (spec : SectionSpec) : M Unit := do
  let star ← readStar
  let short ← readOptional?
  let title ← readArg at_
  endParagraph
  let d ← docSt
  let before ← exSkip spec.skipBefore
  if !d.noBreak then
    addPenalty (-300)
    addVSpace before
  let numbered := !star && spec.level ≤ 3
  let num ← if numbered then do refStepCounter at_ name; theCounter at_ name else pure ""
  let p := at_.pos
  let lb := Tok.char '{' 1 p
  let rb := Tok.char '}' 2 p
  let font := #[csT "normalfont" at_, csT spec.size at_, csT "bfseries" at_]
  let numBox := if numbered then textToks at_ num ++ #[csT "quad" at_] else #[]
  let indent := if spec.indentParindent then #[csT "hskip" at_, csT "parindent" at_] else #[]
  let anchor ← newAnchor
  if !star then
    let e : TocEntry := { level := spec.level, number := num, title := short.getD title, anchor }
    modifyDoc fun d => { d with toc := d.toc.push e }
  if spec.skipAfter.1 > 0 then
    -- a displayed heading: a paragraph of its own, hanging from its number
    inject at_ (#[csT "begingroup" at_] ++ font ++
      #[csT "noindent" at_, csT "hbox" at_, lb] ++ indent ++ numBox ++
      #[rb, csT "leantex@hanglast" at_, csT "interlinepenalty" at_] ++ textToks at_ "10000 " ++
      title ++ #[csT "par" at_, csT "endgroup" at_,
        csT "leantex@afterheading" at_, lb] ++ textToks at_ anchor ++ #[rb, lb] ++
      textToks at_ s!"{spec.skipAfter.1}" ++ #[rb])
  else
    -- a run-in heading starts the next paragraph
    if !star then pushV (.label anchor)
    inject at_ (#[csT "leantex@runin" at_, lb] ++ font ++ indent ++ numBox ++ title ++
      #[rb])

/-- After a displayed heading: its anchor, `\nobreak`, the skip after and LaTeX's
`\@afterheading`. -/
def afterHeading (at_ : Tok) : M Unit := do
  let anchor ← readWord at_
  let after := ((← readWord at_).toInt?).getD 0
  pushV (.label anchor)
  pushV (.penalty 10000)
  pushV (.glue (← exSkip (after, 200, 0)) 0)
  modifyDoc fun d => { d with noBreak := true, afterHeading := true }

/-- A run-in heading: the next paragraph starts without indentation with the heading in a
group and a quad of space after it. -/
def runIn (at_ : Tok) : M Unit := do
  let body ← readArg at_
  modifyDoc fun d => { d with noBreak := false }
  modify fun s => { s with noIndent := true }
  let p := at_.pos
  inject at_ (#[csT "leantex@startpar" at_, Tok.char '{' 1 p] ++ body ++
    #[Tok.char '}' 2 p, csT "hskip" at_] ++ textToks at_ "1em" ++
    #[csT "leantex@ignorespaces" at_])

/-! ### The table of contents -/

/-- `\tableofcontents`: an unnumbered section "Contents" and the previous pass's entries
(levels up to 3), each as the article class sets it: sections in bold with their page at the
right, lower levels indented with dotted leaders. -/
def tableOfContents (at_ : Tok) : M Unit := do
  let p := at_.pos
  let lb := Tok.char '{' 1 p
  let rb := Tok.char '}' 2 p
  let mut out := #[csT "section" at_, Tok.char '*' 12 p, lb] ++ textToks at_ "Contents" ++ #[rb]
  for (e, page) in (← docSt).prevToc do
    if e.level > 3 then continue
    out := out ++ #[csT "leantex@tocline" at_, lb] ++ textToks at_ s!"{e.level}" ++ #[rb, lb] ++
      textToks at_ e.number ++ #[rb, lb] ++ e.title ++ #[rb, lb] ++ textToks at_ page ++ #[rb]
  inject at_ out

/-- A line of the table of contents (`\l@section`, `\@dottedtocline`): the indentation and
number width of its level, the title, the leaders and the page in a box of `\@pnumwidth`. -/
def tocLine (at_ : Tok) : M Unit := do
  let level := ((← readWord at_).toNat?).getD 1
  let num ← readArg at_
  let title ← readArg at_
  let page ← readArg at_
  let (indent, numWidth) := match level with
    | 1 => ("0em", "1.5em") | 2 => ("1.5em", "2.3em") | _ => ("3.8em", "3.2em")
  let p := at_.pos
  let lb := Tok.char '{' 1 p
  let rb := Tok.char '}' 2 p
  if level == 1 then
    addPenalty (-300)
    let (em, _) ← fontUnits
    addVSpace { width := em, stretch := 65536 }
  else
    pushV (.glue { stretch := 13107 } 0)
  let leaders := if level == 1 then #[csT "hfil" at_]
    else #[csT "leantex@dotfill" at_]
  let pageBox := #[csT "hbox" at_] ++ textToks at_ "to " ++ textToks at_ "1.55em" ++ #[lb] ++
    (if level == 1 then #[csT "hss" at_] else #[csT "hfil" at_, csT "normalfont" at_]) ++
    page ++ (if level == 1 then #[csT "kern" at_] ++ textToks at_ "-1pt" ++ #[csT "kern" at_] ++
      textToks at_ "1pt " else #[]) ++ #[rb]
  let numBox := if num.isEmpty then #[] else
    #[csT "hbox" at_] ++ textToks at_ "to " ++ textToks at_ numWidth ++ #[lb] ++ num ++
      #[csT "hfil" at_, rb]
  let rsk := if level == 1 then "1.55em" else "2.55em"
  inject at_ (#[csT "begingroup" at_, csT "parindent" at_] ++ textToks at_ (indent ++ " ") ++
    #[csT "leftskip" at_] ++ textToks at_ (indent ++ " ") ++
    #[csT "leantex@addleftskip" at_, lb] ++ textToks at_ numWidth ++ #[rb] ++
    #[csT "rightskip" at_] ++ textToks at_ (rsk ++ " ") ++
    #[csT "parfillskip" at_] ++ textToks at_ ("-" ++ rsk ++ " ") ++
    #[csT "interlinepenalty" at_] ++ textToks at_ "10000 " ++
    #[csT "leantex@startpar" at_] ++
    (if level == 1 then #[csT "bfseries" at_]
      else #[csT "hbox" at_, lb, rb, csT "nobreak" at_]) ++
    #[csT "leantex@hskipleft" at_] ++ numBox ++ title ++
    #[csT "nobreak" at_] ++ leaders ++ #[csT "nobreak" at_] ++ pageBox ++
    #[csT "par" at_, csT "endgroup" at_])

end LeAnTeX.Text.Typeset
