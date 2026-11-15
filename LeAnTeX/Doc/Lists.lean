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
  `\addvspace` of `\@topsepadd` plus the outer `\parskip`, and `\addvspace{-\parskip}`; before the
  others `\addpenalty{-51}` and `\addvspace{\itemsep}`. Its paragraph starts without the
  indentation, with the label box: `\hskip\itemindent \hskip-\labelwidth \hskip-\labelsep`, the
  label in a box `\labelwidth` wide (flush right; at its natural width when wider, and always
  for `description`), `\hskip\labelsep`, then `\penalty 0`. A numbered list steps its counter
  (`\refstepcounter`) for an item without its own label.
* **The end** (`\endtrivlist`): the paragraph ends; a final skip is replaced by itself plus the
  inner `\parskip` less the outer one; `\addpenalty{-51}` and `\addvspace{\@topsepadd}`; the
  next paragraph, if it follows without a blank line, is not indented (`\@endpe`).
* **Levels**: the class's parameters for levels 1 to 4 (`\@listi` …), `\leftmarginv` and
  `\leftmarginvi` deeper; at most six levels (an error beyond, as in LaTeX).

Environments: `itemize` (labels •, bold –, ∗, ·), `enumerate` (`1.`, `(a)`, `i.`, `A.`; its
`\ref` texts `1`, `1a`, `1(a)i`, `1(a)iA`), `description` (bold labels at their natural
width, the item indented by `-\leftmargin`), `quote`, `quotation`, `center`, `flushleft`,
`flushright`, `trivlist`.
-/

namespace LeAnTeX.Text.Typeset

open LeAnTeX.Doc

/-- LaTeX's flush glue: `0pt plus 1fil`. -/
def flushGlue : Glue := { stretch := 65536, stretchOrder := 1 }

/-- Starts a list (`\list` and `\@trivlist`): the level's parameters, then `setup` (the
environment's own settings), then the vertical skips' bookkeeping and the new margins. -/
def beginList (at_ : Tok) (setup : ListLevel → ListLevel) (trivial : Bool := false) : M Unit := do
  let d ← docSt
  let depth := d.lists.size + 1
  if depth > 6 && !trivial then failAt at_ "Too deeply nested"
  let cp ← classP
  let lvl := if trivial && d.lists.isEmpty then (cp.lists[0]?.getD {})
    else if trivial then (d.lists.back?.getD {})
    else cp.lists[(min depth 4) - 1]?.getD {}
  let left := if trivial then lvl.leftMargin else if depth ≤ 4 then lvl.leftMargin
    else cp.leftMarginDeep
  let base : ListLevel :=
    { lvl with leftMargin := left, labelWidth := left - cp.labelSep, labelSep := cp.labelSep,
               rightMargin := 0, itemIndent := 0, listParIndent := 0, label := #[],
               counter := none, labelStyle := 0, trivial, naturalLabel := false }
  let outerSkip := (← vars).parSkip
  let base := if trivial then
      { base with leftMargin := 0, labelWidth := 0, itemIndent := 0, parSep := outerSkip }
    else base
  let l := setup base
  let wasV := !(← get).hmode
  if !wasV then endParagraph
  let v ← vars
  let topSepAdd := if wasV then
      { l.topSep with width := l.topSep.width + l.parTopSep.width,
                      stretch := l.topSep.stretch + l.parTopSep.stretch,
                      shrink := l.topSep.shrink + l.parTopSep.shrink } else l.topSep
  let topSepItem := { topSepAdd with width := topSepAdd.width + v.parSkip.width,
                                     stretch := topSepAdd.stretch + v.parSkip.stretch,
                                     shrink := topSepAdd.shrink + v.parSkip.shrink }
  let noParList := d.inLabel
  let l := { l with topSepAdd, topSepItem, outerParSkip := v.parSkip, newList := true,
                    noParList }
  modifyDoc fun d => { d with lists := d.lists.push l }
  let width := (v.lineWidth.getD v.p.hsize) - l.rightMargin - l.leftMargin
  modifyVars fun v =>
    { v with
      parSkip := l.parSep, parIndent := l.listParIndent, lineWidth := some width,
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
  let depth := (← docSt).lists.size + 1
  match name with
  | "itemize" =>
    beginList at_ fun l => { l with label := itemizeLabel at_ depth }
  | "enumerate" =>
    let c := enumCounter depth
    if depth > 4 then failAt at_ "Too deeply nested"
    modifyDoc fun d => { d with counters := d.counters.set c 0 }
    beginList at_ fun l => { l with label := enumLabel at_ depth, counter := some c }
  | "description" =>
    beginList at_ fun l => { l with labelWidth := 0, itemIndent := -l.leftMargin,
                                    naturalLabel := true, labelStyle := 1,
                                    label := #[] }
  | "quote" =>
    beginList at_ fun l => { l with rightMargin := l.leftMargin }
    inject at_ #[csT "item" at_, csT "relax" at_]
  | "quotation" =>
    let (em, _) ← fontUnits
    let pi := em + em / 2
    beginList at_ fun l => { l with listParIndent := pi, itemIndent := pi,
                                    rightMargin := l.leftMargin, parSep := { stretch := 65536 } }
    inject at_ #[csT "item" at_, csT "relax" at_]
  | "trivlist" => beginList at_ id (trivial := true)
  | "center" | "flushleft" | "flushright" =>
    beginList at_ id (trivial := true)
    let (ls, rs, pf) := match name with
      | "center" => (flushGlue, flushGlue, ({} : Glue))
      | "flushleft" => ({}, flushGlue, flushGlue)
      | _ => (flushGlue, {}, {})
    modifyVars fun v => { v with p := { v.p with leftSkip := ls, rightSkip := rs },
                                 parIndent := 0, parFillSkip := pf, crPar := true }
    inject at_ #[csT "item" at_, csT "relax" at_]
  | _ => return false
  return true

/-- Whether an environment is a list ended by `endList`. -/
def isListEnv (name : String) : Bool :=
  ["itemize", "enumerate", "description", "quote", "quotation", "trivlist", "center",
    "flushleft", "flushright"].contains name

end LeAnTeX.Text.Typeset
