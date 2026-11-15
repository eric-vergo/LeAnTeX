/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Doc.Commands

/-!
# Lists

LaTeX's list environments as its documentation describes `\list` and `\trivlist` and as
LuaLaTeX shows them:

* **The start** (`\@trivlist`): the paragraph before ends; `\@topsepadd` is `\topsep`, with
  `\partopsep` when the list starts after a blank line (in vertical mode); `\parskip` becomes
  `\parsep`, `\parindent` `\listparindent`; the lines are `\leftmargin` further in and
  `\leftmargin + \rightmargin` shorter (LaTeX's `\@totalleftmargin` and `\linewidth`).
* **An item** (`\item[label]`): before the first, `\addpenalty{-51}` (`\@beginparpenalty`),
  `\addvspace` of `\@topsepadd` plus the outer `\parskip`, and `\addvspace{-\parskip}` (right
  after a heading only `\addvspace` of the outer `\parskip` less the list's, `\@nbitem`); before
  the others `\addpenalty{-51}` and `\addvspace{\itemsep}`. Its paragraph starts without the
  indentation, with the label box: `\hskip\itemindent \hskip-\labelwidth \hskip-\labelsep`, the
  label in a box `\labelwidth` wide (flush right; at its natural width when wider, and always
  for `description`), `\hskip\labelsep`, then `\penalty 0`. A numbered list steps its counter
  (`\refstepcounter`) for an item without its own label.
* **The end** (`\endtrivlist`): the paragraph ends; a final skip is replaced by itself plus the
  inner `\parskip` less the outer one; `\addpenalty{-51}` and `\addvspace{\@topsepadd}`; the
  next paragraph, if it follows without a blank line, is not indented (`\@endpe`).
* **Levels**: the class's parameters for levels 1 to 4 (`\@listi` …), `\leftmarginv` and
  `\leftmarginvi` deeper; at most six levels (an error beyond, as in LaTeX). The labels of
  `itemize` and of `enumerate` follow each environment's own level, counted apart as LaTeX
  counts them (`\@itemdepth`, `\@enumdepth`, at most four each): an `itemize` inside an
  `enumerate` inside an `itemize` has the second `itemize` label.

Environments: `itemize` (labels •, bold –, ∗, ·), `enumerate` (`1.`, `(a)`, `i.`, `A.`; its
`\ref` texts `1`, `1a`, `1(a)i`, `1(a)iA`), `description` (bold labels at their natural
width, the item indented by `-\leftmargin`), `quote`, `quotation`, `center`, `flushleft`,
`flushright`, `trivlist`, `thebibliography` (with `\bibitem` and `\cite`, see `bibList`).
-/

namespace LeAnTeX.Text.Typeset

open LeAnTeX.Doc

/-- LaTeX's flush glue: `0pt plus 1fil`. -/
def flushGlue : Glue := { stretch := 65536, stretchOrder := 1 }

/-- Starts a list (`\list` and `\@trivlist`): the level's parameters, then `setup` (the
environment's own settings), then the vertical skips' bookkeeping and the new margins.

The level is the number of enclosing lists that are not trivial (LaTeX's `\@listdepth`, which
`\trivlist` leaves alone). Level 1 takes the size's own `\@listi` (`\small` and
`\footnotesize` have theirs, `Vars.listOne`) and keeps the `\labelwidth` in force (`\@listi`
does not set it: 0 inside a trivial list); levels 2 to 4 set it from their left margin. A
trivial list keeps the enclosing list's skips (outside every list the class's level 1), `\rightmargin`, `\listparindent` and
`\parindent`, its own `\parsep` the `\parskip` outside. With `ams` (amsthm's theorems) the skip
above is `\topsep` alone and the skip below too (`\@topsep\thm@preskip`,
`\@topsepadd\thm@postskip`), without `\partopsep` and the outer `\parskip`. -/
def beginList (at_ : Tok) (setup : ListLevel → ListLevel) (trivial : Bool := false)
    (ams : Bool := false) : M Unit := do
  let d ← docSt
  let enclosing := d.lists.back?
  let depth := (d.lists.filter (!·.trivial)).size + 1
  if depth > 6 && !trivial then failAt at_ "Too deeply nested"
  let cp ← classP
  let v0 ← vars
  let one := match v0.listOne with
    | some (t, i, p) => { (cp.lists[0]?.getD default) with topSep := t, itemSep := i, parSep := p }
    | none => cp.lists[0]?.getD default
  let defaultLabel := (cp.lists[0]?.map (·.leftMargin)).getD 0 - cp.labelSep
  -- a trivial list outside every list has the `\topsep` the class's `\@listi` set at the
  -- start (a size command defines its own `\@listi` without carrying it out)
  let lvl := if trivial then enclosing.getD (cp.lists[0]?.getD default)
    else if depth == 1 then one
    else cp.lists[(min depth 4) - 1]?.getD default
  let left := if trivial then 0 else if depth ≤ 4 then lvl.leftMargin else cp.leftMarginDeep
  let labelWidth := if trivial then 0
    else if depth == 1 then (enclosing.map (·.labelWidth)).getD defaultLabel
    else left - cp.labelSep
  let inherited := fun (f : ListLevel → Int) => (enclosing.map f).getD 0
  let base : ListLevel :=
    { lvl with leftMargin := left, labelWidth, labelSep := cp.labelSep,
               rightMargin := if trivial then inherited (·.rightMargin) else 0, itemIndent := 0,
               listParIndent := if trivial then inherited (·.listParIndent) else 0, label := #[],
               counter := none, labelStyle := 0, trivial, naturalLabel := false, env := "" }
  let base := if trivial then { base with parSep := v0.parSkip } else base
  let l := setup base
  let wasV := !(← get).hmode
  if !wasV then endParagraph
  let v ← vars
  let topSepAdd := if wasV && !ams then
      { l.topSep with width := l.topSep.width + l.parTopSep.width,
                      stretch := l.topSep.stretch + l.parTopSep.stretch,
                      shrink := l.topSep.shrink + l.parTopSep.shrink } else l.topSep
  let topSepItem := if ams then l.topSep
    else { topSepAdd with width := topSepAdd.width + v.parSkip.width,
                          stretch := topSepAdd.stretch + v.parSkip.stretch,
                          shrink := topSepAdd.shrink + v.parSkip.shrink }
  let noParList := d.inLabel
  let l := { l with topSepAdd, topSepItem, outerParSkip := v.parSkip, newList := true,
                    noParList }
  modifyDoc fun d => { d with lists := d.lists.push l }
  -- `\@trivlist` leaves `\linewidth` and `\parindent` as they are
  let width := (v.lineWidth.getD v.p.hsize) -
    (if trivial then 0 else l.rightMargin + l.leftMargin)
  modifyVars fun v =>
    { v with
      parSkip := l.parSep, parIndent := if trivial then v.parIndent else l.listParIndent,
      lineWidth := some width,
      totalLeftMargin := v.totalLeftMargin + l.leftMargin,
      p := { v.p with leftSkip := {}, rightSkip := {} }, parFillSkip := flushGlue,
      crPar := false }

/-- The innermost list's record changed. -/
def modifyList (f : ListLevel → ListLevel) : M Unit :=
  modifyDoc fun d => { d with lists := d.lists.modify (d.lists.size - 1) f }

/-- `\item[label]` (see the module docstring). -/
def item (at_ : Tok) : M Unit := do
  let opt ← readOptional?
  let some l := (← docSt).lists.back?
    | failAt at_ "Lonely \\item--perhaps a missing list environment"
  if (← get).hmode then endParagraph
  if l.newList then
    if !l.noParList then
      if !(← docSt).noBreak then
        addPenalty (-51)
        addVSpace l.topSepItem
        addVSpace (negGlue (← vars).parSkip)
      else
        -- right after a heading (LaTeX's `\@nbitem`): `\addvspace` of the outer `\parskip`
        -- less the list's, so that the skip after the heading stays what it was once the
        -- item's paragraph adds the list's `\parskip`
        let ps := (← vars).parSkip
        let o := l.outerParSkip
        addVSpace { o with width := o.width - ps.width, stretch := o.stretch - ps.stretch,
                           shrink := o.shrink - ps.shrink }
  else
    addPenalty (-51)
    addVSpace l.itemSep
  modifyList fun l => { l with newList := false }
  let label ← match opt with
    | some ts => pure ts
    | none => do
      if let some c := l.counter then refStepCounter at_ c
      pure l.label
  let p := at_.pos
  let lb := Tok.char '{' 1 p
  let rb := Tok.char '}' 2 p
  let dim := fun (v : Int) => textToks at_ s!"{v}sp "
  let made := if l.naturalLabel then #[lb] ++ label ++ #[rb]
    else #[csT "leantex@labelbox" at_, lb] ++ dim l.labelWidth ++ #[rb, lb] ++ label ++ #[rb]
  -- the item's paragraph starts with the label box (no indentation)
  modify fun s => { s with noIndent := true }
  startParagraph
  inject at_ (#[csT "hbox" at_, lb, csT "hskip" at_] ++ dim l.itemIndent ++
    #[csT "hskip" at_] ++ dim (-l.labelWidth) ++ #[csT "hskip" at_] ++ dim (-l.labelSep) ++
    made ++ #[csT "hskip" at_] ++ dim l.labelSep ++ #[rb, csT "penalty" at_] ++
    textToks at_ "0 " ++ #[csT "leantex@ignorespaces" at_])

/-- A label in a box `w` wide, flush right; at its natural width when wider (LaTeX's `\@item`
compares the widths). -/
def labelBox (at_ : Tok) : M Unit := do
  let wTok ← readArg at_
  let label ← readArg at_
  let p := at_.pos
  inject at_ (#[csT "hbox" at_, Tok.char '{' 1 p] ++ label ++ #[Tok.char '}' 2 p,
    csT "leantex@fitlast" at_, Tok.char '{' 1 p] ++ wTok ++ #[Tok.char '}' 2 p])

/-- After a label's box: the box set `w` wide, flush right, unless it is wider. -/
def fitLast (at_ : Tok) : M Unit := do
  let arg ← readArg at_
  let saved := (← get).input
  modify fun s => { s with input := arg.reverse }
  let (w, _) ← readDimen at_
  modify fun s => { s with input := saved }
  flushRun
  match (← get).hlist.back? with
  | some (.box bw h d sh c) =>
    if bw ≤ w then
      let b := HNode.box w h d sh (#[HNode.glue { width := w - bw } 0] ++ c)
      modify fun s => { s with hlist := s.hlist.pop.push b }
  | _ => pure ()

/-- Ends a list (see the module docstring). -/
def endList (at_ : Tok) : M Unit := do
  let some l := (← docSt).lists.back? | failAt at_ "internal: no list to end"
  if (← get).hmode then endParagraph
  if !l.noParList then
    let ls ← lastSkip
    if ls.width > 0 then
      let ps := (← vars).parSkip
      let t : Glue := { ls with width := ls.width + ps.width - l.outerParSkip.width,
                                stretch := ls.stretch + ps.stretch - l.outerParSkip.stretch,
                                shrink := ls.shrink + ps.shrink - l.outerParSkip.shrink }
      pushV (.glue (negGlue ls) 0)
      pushV (.glue t 0)
    modifyDoc fun d => { d with noBreak := false }
    addPenalty (-51)
    addVSpace l.topSepAdd
  modifyDoc fun d => { d with lists := d.lists.pop }

/-- The label of an `itemize` level. -/
def itemizeLabel (at_ : Tok) (depth : Nat) : Array Tok :=
  match depth with
  | 1 => textToks at_ "•"
  | 2 => #[csT "normalfont" at_, csT "bfseries" at_] ++ textToks at_ "–"
  | 3 => textToks at_ "∗"
  | _ => textToks at_ "·"

/-- The counter of an `enumerate` level. -/
def enumCounter (depth : Nat) : String :=
  match depth with | 1 => "enumi" | 2 => "enumii" | 3 => "enumiii" | _ => "enumiv"

/-- The label of an `enumerate` level. -/
def enumLabel (at_ : Tok) (depth : Nat) : Array Tok :=
  let c := enumCounter depth
  let the := #[csT ("the" ++ c) at_]
  match depth with
  | 2 => textToks at_ "(" ++ the ++ textToks at_ ")"
  | _ => the ++ textToks at_ "."

/-- The list environments' beginnings (see the module docstring); whether `name` is one. -/
def beginListEnv (at_ : Tok) (name : String) : M Bool := do
  -- LaTeX counts the levels of `itemize` and of `enumerate` apart (`\@itemdepth`,
  -- `\@enumdepth`), each to four, inside the six levels of all lists (`\@listdepth`)
  let levels := (← docSt).lists
  let depthOf := fun (env : String) => (levels.filter (·.env == env)).size + 1
  match name with
  | "itemize" =>
    let depth := depthOf "itemize"
    if depth > 4 then failAt at_ "Too deeply nested"
    beginList at_ fun l => { l with label := itemizeLabel at_ depth, env := "itemize" }
  | "enumerate" =>
    let depth := depthOf "enumerate"
    let c := enumCounter depth
    if depth > 4 then failAt at_ "Too deeply nested"
    modifyDoc fun d => { d with counters := d.counters.set c 0 }
    beginList at_ fun l =>
      { l with label := enumLabel at_ depth, counter := some c, env := "enumerate" }
  | "description" =>
    beginList at_ fun l => { l with labelWidth := 0, itemIndent := -l.leftMargin,
                                    naturalLabel := true, labelStyle := 1,
                                    label := #[] }
  | "quote" =>
    beginList at_ fun l => { l with rightMargin := l.leftMargin }
    inject at_ #[csT "item" at_, csT "relax" at_, csT "leantex@ignorespaces" at_]
  | "quotation" =>
    let (em, _) ← fontUnits
    let pi := em + em / 2
    beginList at_ fun l => { l with listParIndent := pi, itemIndent := pi,
                                    rightMargin := l.leftMargin, parSep := { stretch := 65536 } }
    inject at_ #[csT "item" at_, csT "relax" at_, csT "leantex@ignorespaces" at_]
  | "verse" =>
    -- `\list{}{\itemsep\z@ \itemindent -1.5em \listparindent\itemindent
    -- \rightmargin\leftmargin \advance\leftmargin 1.5em}`, `\\` ending the line
    let (em, _) ← fontUnits
    let pi := em + em / 2
    beginList at_ fun l => { l with itemSep := {}, itemIndent := -pi, listParIndent := -pi,
                                    rightMargin := l.leftMargin, leftMargin := l.leftMargin + pi }
    modifyVars fun v => { v with crPar := true }
    inject at_ #[csT "item" at_, csT "relax" at_, csT "leantex@ignorespaces" at_]
  | "thebibliography" =>
    -- `\section*{\refname}`, then the list
    let w ← readArg at_
    let p := at_.pos
    inject at_ (#[csT "section" at_, Tok.char '*' 12 p, Tok.char '{' 1 p] ++
      textToks at_ "References" ++ #[Tok.char '}' 2 p, csT "leantex@biblist" at_,
      Tok.char '{' 1 p] ++ w ++ #[Tok.char '}' 2 p])
  | "trivlist" => beginList at_ id (trivial := true)
  | "center" | "flushleft" | "flushright" =>
    beginList at_ id (trivial := true)
    let (ls, rs, pf) := match name with
      | "center" => (flushGlue, flushGlue, ({} : Glue))
      | "flushleft" => ({}, flushGlue, flushGlue)
      | _ => (flushGlue, {}, {})
    modifyVars fun v => { v with p := { v.p with leftSkip := ls, rightSkip := rs },
                                 parIndent := 0, parFillSkip := pf, crPar := true }
    inject at_ #[csT "item" at_, csT "relax" at_, csT "leantex@ignorespaces" at_]
  | _ => return false
  return true

/-! ### Bibliographies -/

/-- The list of `thebibliography` (`\list{\@biblabel{\@arabic\c@enumiv}}{…}` of the article
class): the width of `[w]` for the widest label `w` (the environment's argument) is
`\labelwidth`, plus `\labelsep` is `\leftmargin`; the items are numbered with `enumiv`,
printed in arabic; then `\sloppy` (`\tolerance 9999`, `\emergencystretch 3em`),
`\clubpenalty 4000`, `\widowpenalty 4000` and a space factor of `1000` after a full stop. -/
def bibList (at_ : Tok) : M Unit := do
  let w ← readArg at_
  let txt ← expandText at_ w
  let tf ← fontFor (← vars).key
  let width := (tf.shape ("[" ++ txt ++ "]").toList.toArray).foldl (· + ·.width) 0
  let (em, _) ← fontUnits
  modifyDoc fun d => { d with counters := d.counters.set "enumiv" 0 }
  let theNum : Macro := { params := 0, body := tokenize "\\arabic{enumiv}" }
  modifyVars fun v => { v with macros := v.macros.insert "theenumiv" theNum }
  let lab := textToks at_ "[" ++ #[csT "theenumiv" at_] ++ textToks at_ "]"
  beginList at_ fun l =>
    { l with labelWidth := width, leftMargin := width + l.labelSep, counter := some "enumiv",
             env := "thebibliography", label := lab }
  modifyVars fun v =>
    { v with p := { v.p with tolerance := 9999, emergencyStretch := 3 * em },
             clubPenalty := 4000, widowPenalty := 4000, periodSf := 1000 }

/-- The key of a citation in the labels: `bib@` and the citation key. -/
def bibKey (key : String) : String := "bib@" ++ key

/-- `\bibitem[label]{key}`: an item whose label is `[label]` flush left in `\labelwidth`, or the
next number; the label's text is recorded for `\cite` (LaTeX's `\bibcite`). -/
def bibItem (at_ : Tok) : M Unit := do
  let opt ← readOptional?
  let key ← readWord at_
  let some l := (← docSt).lists.back?
    | failAt at_ "Lonely \\item--perhaps a missing list environment"
  let p := at_.pos
  let lb := Tok.char '{' 1 p
  let rb := Tok.char '}' 2 p
  match opt with
  | some ts =>
    let txt ← expandText at_ ts
    modifyDoc fun d => { d with labels := d.labels.push (bibKey key, txt) }
    -- `\item[\@biblabel{label}\hfill]`: the label left in its box
    inject at_ (#[csT "item" at_, Tok.char '[' 12 p, lb, csT "hbox" at_] ++
      textToks at_ s!"to {l.labelWidth}sp" ++ #[lb] ++ textToks at_ "[" ++ ts ++
      textToks at_ "]" ++ #[csT "hss" at_, rb, rb, Tok.char ']' 12 p])
  | none =>
    inject at_ (#[csT "item" at_, csT "leantex@bibcite" at_, lb] ++ textToks at_ key ++
      #[rb, csT "leantex@ignorespaces" at_])

/-- After a numbered `\bibitem`: its number recorded for `\cite`. -/
def bibCite (at_ : Tok) : M Unit := do
  let key ← readWord at_
  let txt ← theCounter at_ "enumiv"
  modifyDoc fun d => { d with labels := d.labels.push (bibKey key, txt) }

/-- `\cite[note]{a,b}`: `[1, 2]` or `[1, note]` from the previous pass's labels, the keys
apart by `,\penalty\@m\ ` (LaTeX's `\@citex`); an unknown key prints a bold `?` and is
reported. -/
def cite (at_ : Tok) : M Unit := do
  let note ← readOptional?
  let keys := ((tokText (← readArg at_)).splitOn ",").map (·.trimAscii.toString)
  let p := at_.pos
  let lb := Tok.char '{' 1 p
  let rb := Tok.char '}' 2 p
  let mut body : Array Tok := #[]
  for (k, i) in keys.zipIdx do
    if i > 0 then
      body := body ++ textToks at_ "," ++ #[csT "penalty" at_] ++ textToks at_ "1000" ++
        #[csT " " at_]
    let t ← refText (bibKey k) false
    body := body ++ (if t == "??" then #[lb, csT "bfseries" at_] ++ textToks at_ "?" ++ #[rb]
      else textToks at_ t)
  if let some n := note then body := body ++ textToks at_ ", " ++ n
  inject at_ (textToks at_ "[" ++ #[lb] ++ body ++ #[rb] ++ textToks at_ "]")

/-- Whether an environment is a list ended by `endList`. -/
def isListEnv (name : String) : Bool :=
  ["itemize", "enumerate", "description", "quote", "quotation", "verse", "trivlist", "center",
    "flushleft", "flushright", "thebibliography"].contains name

end LeAnTeX.Text.Typeset
