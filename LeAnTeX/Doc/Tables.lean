/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Doc.Lists

/-!
# Tables

LaTeX's `tabular` as its documentation describes it (the `array` machinery of the kernel)
and as LuaLaTeX shows it:

* **Preamble**: `l`, `c`, `r` (the cell's material flush left, centred or flush right in the
  column, as `\hfil` on the other side or both sides sets it), `p{w}` (a paragraph `w` wide
  in a `\vtop`, its first line with a strut, its last with the strut's depth), `|` (a rule
  `\arrayrulewidth` wide, as tall as the row, centred on the boundary and taking no width), `@{}` (no `\tabcolsep` on that side).
* **Cells**: each has `\tabcolsep` on both sides and the array strut (0.7 and 0.3 of the
  `\baselineskip`, times `\arraystretch` 1); spaces at its ends are dropped. A column is as
  wide as its widest cell; `\multicolumn{n}{spec}{text}` spans `n` columns with its own
  preamble, widening the last of them when it is wider than they are together.
* **Rows** end with `\\` (`\\[d]` adds `d` to the row's depth); `\hline` is a rule
  `\arrayrulewidth` high across the table, `\hline\hline` two with `\doublerulesep` between.
  The rows touch (`\baselineskip` and `\lineskip` 0); no glue after a rule.
* **The box**: `[c]` (the default) centred on the math axis (0.25 em, TeX's `\vcenter`),
  `[t]` with its first row's (or rule's) top on the baseline (`\vtop`), `[b]` with its last
  row's baseline on the baseline.

Not implemented: `\cline`, `>{…}`, `<{…}`, `m{}`, `b{}`, `!{…}`, `@{text}` with text, `*{n}{…}`,
`\arraystretch` other than 1, `tabular*`, `array` (in formulas the math layout's own arrays
are used).
-/

namespace LeAnTeX.Text.Typeset

open LeAnTeX.Doc

/-- The innermost table. -/
def curTable : M (Option Table) := return (← docSt).tables.back?

/-- Changes the innermost table. -/
def modifyTable (f : Table → Table) : M Unit :=
  modifyDoc fun d => { d with tables := d.tables.modify (d.tables.size - 1) f }

/-- Reads a dimension from tokens. -/
def dimFrom (at_ : Tok) (ts : Array Tok) : M Int := do
  let saved := (← get).input
  modify fun s => { s with input := ts.reverse }
  let (d, _) ← readDimen at_
  modify fun s => { s with input := saved }
  return d

/-- Parses a table preamble (see the module docstring). -/
def parsePreamble (at_ : Tok) (ts : Array Tok) : M (Array Column) := do
  let mut cols : Array Column := #[]
  let mut pendingRules := 0
  let mut noSep := false
  let mut i := 0
  for _ in [0:ts.size + 1] do
    if i ≥ ts.size then break
    let t := ts[i]!
    i := i + 1
    match t with
    | .char ' ' _ _ => pure ()
    | .char '|' _ _ =>
      if cols.isEmpty then pendingRules := pendingRules + 1
      else cols := cols.modify (cols.size - 1) fun c => { c with rulesAfter := c.rulesAfter + 1 }
    | .char '@' _ _ =>
      -- `@{}`: only the empty form
      let open_ := ts[i]?
      let close := ts[i + 1]?
      match open_, close with
      | some o, some c =>
        if o.isBegin && c.isEnd then
          i := i + 2
          if cols.isEmpty then noSep := true
          else cols := cols.modify (cols.size - 1) fun c => { c with noSepRight := true }
        else failAt at_ "Only @{} (empty) is supported in a table preamble"
      | _, _ => failAt at_ "Only @{} (empty) is supported in a table preamble"
    | .char c _ _ =>
      if c == 'l' || c == 'c' || c == 'r' then
        cols := cols.push { align := c, rulesBefore := pendingRules, noSepLeft := noSep }
        pendingRules := 0
        noSep := false
      else if c == 'p' then
        -- p{width}
        let some o := ts[i]? | failAt at_ "Missing width of a p column"
        if !o.isBegin then failAt at_ "Missing { after p in a table preamble"
        let mut j := i + 1
        let mut depth := 1
        let mut arg := #[]
        for _ in [0:ts.size] do
          match ts[j]? with
          | none => break
          | some u =>
            if u.isBegin then depth := depth + 1
            if u.isEnd then depth := depth - 1
            j := j + 1
            if depth == 0 then break
            arg := arg.push u
        i := j
        let w ← dimFrom at_ arg
        cols := cols.push { align := 'p', width := w, rulesBefore := pendingRules,
                            noSepLeft := noSep }
        pendingRules := 0
        noSep := false
      else failAt at_ s!"Illegal character '{c}' in a table preamble"
    | _ => failAt at_ "Illegal token in a table preamble"
  if cols.isEmpty then failAt at_ "Empty table preamble"
  if pendingRules > 0 then
    cols := cols.modify (cols.size - 1) fun c =>
      { c with rulesAfter := c.rulesAfter + pendingRules }
  return cols

/-- The array strut's height and depth at the current `\baselineskip`. -/
def arrayStrut : M (Int × Int) := do
  let b := (← vars).baselineSkip.width
  return (texTimes b 0 45875, texTimes b 0 19661)

/-- The column the current cell is in (its own preamble for a `\multicolumn`). -/
def cellColumn (t : Table) : Column := t.own.getD (t.cols[t.col]?.getD {})

/-- Starts a cell: a group; a horizontal list for `l`, `c`, `r`, a nested vertical list `w`
wide for `p`. -/
def startCell (at_ : Tok) : M Unit := do
  beginGroup at_
  let some t ← curTable | failAt at_ "internal: no table"
  let col := cellColumn t
  let depth := (← get).groups.size
  modifyTable fun t => { t with depth, pcell := col.align == 'p', touched := false }
  if col.align == 'p' then
    let (sh, _) ← arrayStrut
    openFrame (.parbox col.width 't')
    modifyVars fun v =>
      { v with
        p := { v.p with hsize := col.width, leftSkip := {}, rightSkip := {}, parShape := #[] },
        lineWidth := none, totalLeftMargin := 0, parFillSkip := flushGlue,
        crPar := false }
    inject at_ (#[csT "leantex@strut" at_, Tok.char '{' 1 at_.pos] ++ textToks at_ s!"{sh}" ++
      #[Tok.char '}' 2 at_.pos, csT "leantex@ignorespaces" at_])
  else
    flushRun
    modify fun s => { s with
      boxes := s.boxes.push { depth := s.groups.size, outer := s.hlist, sf := s.sf,
                              wasVertical := false }
      hlist := #[] }
    modifyVars fun v => { v with crPar := false }
    inject at_ #[csT "leantex@ignorespaces" at_]

/-- Ends the current cell: its material recorded in the row. -/
def endCell (at_ : Tok) : M Unit := do
  let some t ← curTable | failAt at_ "internal: no table"
  if (← get).groups.size != t.depth then
    failAt at_ "Missing } inserted (a group in a table cell is not closed)"
  let cell ← if t.pcell then do
      let (_, sd) ← arrayStrut
      if (← get).hmode then
        flushRun
        modify fun s => { s with hlist := match s.hlist.back? with
                                 | some (.glue ..) => s.hlist.pop
                                 | _ => s.hlist }
        push (.penalty 10000)
        push (.rule 0 0 sd)
      let some (_, items) ← closeFrame | failAt at_ "internal: no cell list"
      let col := cellColumn t
      let b := vpack items
      -- a \vtop: the first line's top on the baseline
      let h := match items[0]? with
        | some n => if n.isBox then n.height else 0
        | none => 0
      let node := vboxNode items b.glue col.width h (b.height + b.depth - h)
      pure ({ content := #[node], width := col.width, height := h,
              depth := b.height + b.depth - h, span := t.span, own := t.own } : Cell)
    else do
      flushRun
      let s ← get
      let content := match s.hlist.back? with
        | some (.glue ..) => s.hlist.pop
        | _ => s.hlist
      let some fr := s.boxes.back? | failAt at_ "internal: no cell box"
      set { s with boxes := s.boxes.pop, hlist := fr.outer, sf := fr.sf }
      let (w, _, _, h, d) := measure content
      pure ({ content, width := w, height := h, depth := d, span := t.span, own := t.own } : Cell)
  endGroup at_
  let touched := t.touched || !cell.content.isEmpty
  modifyTable fun t => { t with cells := t.cells.push cell, col := t.col + t.span, span := 1,
                                own := none, touched }
where
  /-- A vertical list as a box of the horizontal list (each item shifted to its place, a kern
  back after it): `w` wide, `h` high and `d` deep. -/
  vboxNode (items : Array VNode) (g : GlueSet) (w h d : Int) : HNode :=
    let tops := positions items g
    let parts := (items.zip tops).foldl (init := #[]) fun acc (n, top) =>
      match n with
      | .hbox bw bh bd sh c gl =>
        let shift := top + bh - h
        acc.push (HNode.box (bw + sh) bh bd shift (#[HNode.kern sh .explicit] ++
          freezeGlue c gl)) |>.push (.kern (-(bw + sh)) .explicit)
      | .rule rw rh rd =>
        let rw := rw.getD w
        acc.push (HNode.box rw rh rd (top + rh - h) #[.rule rw rh rd]) |>.push
          (.kern (-rw) .explicit)
      | _ => acc
    .box w h d 0 (parts.push (.kern w .explicit))

/-- `\begin{tabular}[pos]{preamble}`: a table starts in the paragraph (see the module
docstring). -/
def beginTabular (at_ : Tok) : M Unit := do
  let pos := match ← readOptional? with
    | some ts => ((tokText ts).trimAscii.toString.toList.headD 'c')
    | none => 'c'
  let cols ← parsePreamble at_ (← readArg at_)
  startParagraph
  modifyDoc fun d => { d with tables := d.tables.push { pos, cols } }
  startCell at_

/-- `&`: the next cell. -/
def nextCell (at_ : Tok) : M Unit := do
  let some t ← curTable | failAt at_ "Misplaced alignment tab character &"
  if t.col + t.span ≥ t.cols.size then failAt at_ "Extra alignment tab has been changed to \\cr"
  endCell at_
  startCell at_

/-- `\\[d]`: the row ends. -/
def endRow (at_ : Tok) : M Unit := do
  let _ ← readStar
  let extra ← match ← readOptional? with
    | some ts => dimFrom at_ ts
    | none => pure 0
  endCell at_
  modifyTable fun t => { t with rows := t.rows.push (.cells t.cells extra), cells := #[],
                                col := 0, touched := false }
  startCell at_

/-- `\hline`, at the start of a row. -/
def hline (at_ : Tok) : M Unit := do
  let some t ← curTable | failAt at_ "Misplaced \\hline"
  if t.touched || !t.cells.isEmpty || t.col != 0 then failAt at_ "Misplaced \\noalign (\\hline)"
  modifyTable fun t => { t with rows := match t.rows.back? with
                                | some (.hline n) => t.rows.pop.push (.hline (n + 1))
                                | _ => t.rows.push (.hline 1) }

/-- `\multicolumn{n}{spec}{text}`, first in a cell. -/
def multicolumn (at_ : Tok) : M Unit := do
  let n := ((← readWord at_).toNat?).getD 0
  let spec ← parsePreamble at_ (← readArg at_)
  let text ← readArg at_
  let some t ← curTable | failAt at_ "\\multicolumn outside a table"
  if (← get).hlist.any (fun _ => true) || t.touched then
    failAt at_ "Misplaced \\omit (\\multicolumn must come first in a cell)"
  if n == 0 || t.col + n > t.cols.size then failAt at_ "Illegal \\multicolumn span"
  let some c := spec[0]? | failAt at_ "Empty \\multicolumn preamble"
  -- the cell is restarted with its own column
  endCellQuiet
  modifyTable fun t => { t with span := n, own := some c }
  startCell at_
  inject at_ text
where
  /-- Drops the cell just started (it had no material). -/
  endCellQuiet : M Unit := do
    let some t ← curTable | return
    if t.pcell then
      let _ ← closeFrame
    else
      let s ← get
      if let some fr := s.boxes.back? then
        set { s with boxes := s.boxes.pop, hlist := fr.outer, sf := fr.sf }
    endGroup at_

/-- A cell's box: rules, `\tabcolsep`, the strut, its material aligned in the column's width
(`w`), `\tabcolsep`, rules; set to the row's height and depth. -/
def cellBox (c : Column) (cell : Cell) (colW : Int) (isFirst : Bool) (rowH rowD sh sd : Int)
    (sep rule : Int) : HNode :=
  -- a rule is centred on the column boundary and takes no width (`\hskip -.5\arrayrulewidth
  -- \vline \hskip -.5\arrayrulewidth`)
  let half := rule / 2
  let rules := fun (n : Nat) => (List.replicate n #[HNode.glue { width := -half } 0,
    .rule rule rowH rowD, .glue { width := -(rule - half) } 0]).toArray.flatten
  let fil : HNode := .glue { stretch := 65536, stretchOrder := 1 } 0
  let body := match c.align with
    | 'c' => #[fil] ++ cell.content ++ #[fil]
    | 'r' => #[fil] ++ cell.content
    -- LaTeX's `l` column: `\hskip 1sp` before the material and `\hfill` after it
    | _ => #[HNode.glue { width := 1 } 0] ++ cell.content ++
      #[.glue { stretch := 65536, stretchOrder := 2 } 0]
  let (nat, st, shr, _, _) := measure body
  let body := freezeGlue body (hpackGlue nat colW st shr)
  let left := (if isFirst then rules c.rulesBefore else #[]) ++
    (if c.noSepLeft then #[] else #[HNode.glue { width := sep } 0])
  let right := (if c.noSepRight then #[] else #[HNode.glue { width := sep } 0]) ++
    rules c.rulesAfter
  let nodes := left ++ #[HNode.rule 0 sh sd] ++ body ++ right
  let (wd, _, _, _, _) := measure nodes
  .box wd rowH rowD 0 nodes

/-- The full width a column's cells take besides their material: rules and separations. -/
def colExtra (c : Column) (first : Bool) (sep rule : Int) : Int :=
  let _ := (first, rule)
  (if c.noSepLeft then 0 else sep) + (if c.noSepRight then 0 else sep)

/-- `\end{tabular}`: the last row ended (an empty last row after `\\` dropped), the columns
measured and the rows set, the table's box put in the paragraph. -/
def endTabular (at_ : Tok) : M Unit := do
  endCell at_
  let some t ← curTable | failAt at_ "internal: no table"
  let rows := if t.cells.size == 1 && !t.touched then t.rows
    else t.rows.push (.cells t.cells 0)
  modifyDoc fun d => { d with tables := d.tables.pop }
  let sep : Int := 6 * 65536
  let rule : Int := 26214
  let (sh, sd) ← arrayStrut
  let n := t.cols.size
  -- the columns' widths: the widest single cell, then spans widen their last column
  let mut widths : Array Int := t.cols.map fun c => if c.align == 'p' then c.width else 0
  for r in rows do
    if let .cells cs _ := r then
      let mut j := 0
      for c in cs do
        if c.span == 1 && c.own.isNone then
          if let some col := t.cols[j]? then
            if col.align != 'p' then widths := widths.modify j (max · c.width)
        j := j + c.span
  for r in rows do
    if let .cells cs _ := r then
      let mut j := 0
      for c in cs do
        if c.span > 1 || c.own.isSome then
          let own := c.own.getD (t.cols[j]?.getD {})
          let avail := (List.range c.span).foldl (init := (0 : Int)) fun acc k =>
            acc + widths.getD (j + k) 0 + colExtra (t.cols[j + k]?.getD {}) (j + k == 0) sep rule
          let need := c.width + colExtra own (j == 0) sep rule
          if need > avail then
            widths := widths.modify (j + c.span - 1) (· + (need - avail))
        j := j + c.span
  -- the rows
  let mut items : Array VNode := #[]
  let mut prev := ignoreDepth
  let lineP : Interline := { baselineSkip := {}, lineSkip := {}, lineSkipLimit := 0 }
  for r in rows do
    match r with
    | .hline k =>
      for i in [0:k] do
        if i > 0 then items := items.push (.glue { width := 2 * 65536 } 0)
        items := items.push (.rule none rule 0)
      prev := ignoreDepth
    | .cells cs extra =>
      let rowH := cs.foldl (init := sh) fun m c => max m c.height
      let rowD := cs.foldl (init := sd + extra) fun m c => max m c.depth
      let mut nodes := #[]
      let mut j := 0
      for c in cs do
        let own := c.own.getD (t.cols[j]?.getD {})
        let base := (List.range c.span).foldl (init := (0 : Int)) fun acc k =>
          acc + widths.getD (j + k) 0 + colExtra (t.cols[j + k]?.getD {}) (j + k == 0) sep rule
        let w := base - colExtra own (j == 0) sep rule
        nodes := nodes.push (cellBox own c w (j == 0) rowH rowD sh sd sep rule)
        j := j + c.span
      -- columns with no cell in this row: empty cells
      for k in [j:n] do
        let col := t.cols[k]?.getD {}
        nodes := nodes.push (cellBox col {} (widths.getD k 0) (k == 0) rowH rowD sh sd sep rule)
      let (wd, _, _, _, _) := measure nodes
      let (l, pd) := appendBox items lineP prev (.hbox wd rowH rowD 0 nodes {})
      items := l
      prev := pd
  let width := (List.range n).foldl (init := (0 : Int)) fun acc k =>
    acc + widths.getD k 0 + colExtra (t.cols[k]?.getD {}) (k == 0) sep rule
  let b := vpack items
  let total := b.height + b.depth
  let size := (← vars).key.size
  let (h, d) := match t.pos with
    | 't' => let h0 := (items[0]?.map VNode.height).getD 0; (h0, total - h0)
    | 'b' => (b.height, b.depth)
    | _ => let h0 := half total + size / 4; (h0, total - h0)
  let box := endCell.vboxNode items b.glue width h d
  push box

end LeAnTeX.Text.Typeset
