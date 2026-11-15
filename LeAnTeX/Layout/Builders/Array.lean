/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Layout.Html

/-!
# Arrays and environments

The layout of KaTeX's `array` node, which every tabular environment produces (`array`,
`matrix` and its delimited forms, `cases`, `aligned`, `gathered`, `alignat`, `smallmatrix`,
`subarray`, `equation`, `split`, `{CD}`): rows of cells on struts, columns as vertical lists
aligned left, centred or right, the gaps between columns, vertical and horizontal rules, and the
equation numbers and tags of the AMS environments in a column of their own. Also the labels of
the vertical arrows of `{CD}`.

## Main definitions

* `buildArray`: an array node.
* `buildCdLabel`, `buildCdLabelParent`: a label beside a vertical arrow of `{CD}`, and the group
  of the arrow and its labels.

## Implementation notes

KaTeX sets each cell's height and depth to its row's before stacking the column (the cells are
then positioned by `individualShift` from the row's baseline); the port does the same on its
copies. Lengths are KaTeX's: `\arraycolsep` 5 pt, `\baselineskip` 12 pt (3 ex in `{CD}`),
`\jot` 3 pt, struts of 0.7 and 0.3 times `\arraystretch × \baselineskip`.

## References

* KaTeX's `src/environments/array.ts` (the HTML builder) and `src/environments/cd.ts` (the
  label builders) (MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- A row of an array as laid out: its cells, its height and depth, and the position of its
baseline from the top of the array. -/
structure OutRow where
  /-- The cells. -/
  cells : Array Box
  /-- Height of the row. -/
  height : Em
  /-- Depth of the row. -/
  depth : Em
  /-- Distance from the top of the array to the row's baseline. -/
  pos : Em
  deriving Inhabited

/-- An array or matrix (KaTeX's `array` HTML builder). -/
def buildArray (ctx : BuildCtx) (colSeparationType : Option String)
    (hskipBeforeAndAfter : Option Bool) (addJot : Option Bool)
    (colDescriptions : Array AlignSpec) (arraystretch : Float) (body : Array (Array Node))
    (rowGaps : Array (Option Measurement)) (hLinesBeforeRow : Array (Array Bool))
    (tags : Option (Array (Sum Bool (Array Node)))) (o : Options) : BuildM Box := do
  let fm := o.fontMetrics
  let nr := body.size
  let ruleThickness := max fm.arrayRuleWidth o.minRuleThickness
  let pt : Em := 1 / fm.ptPerEm
  let isCD := colSeparationType == some "CD"
  -- in {smallmatrix} the column space is \thickspace in script style
  let arraycolsep : Em := if colSeparationType == some "small" then
      0.2778 * ((o.havingStyle MathStyle.script).sizeMultiplier / o.sizeMultiplier)
    else 5 * pt
  let baselineskip ← if isCD then calculateSize ⟨3, "ex"⟩ o else pure (12 * pt)
  let jot : Em := 3 * pt
  let arrayskip := Em.ofFloat arraystretch * baselineskip
  let arstrutHeight := 0.7 * arrayskip
  let arstrutDepth := 0.3 * arrayskip
  let mut totalHeight : Em := 0
  let mut hlines : Array (Em × Bool) := #[]
  -- the rules above the first row, 0.25 em apart
  for h : i in [0:(hLinesBeforeRow[0]?.getD #[]).size] do
    if i > 0 then totalHeight := totalHeight + 0.25
    hlines := hlines.push (totalHeight, (hLinesBeforeRow[0]?.getD #[]).getD i false)
  let mut rows : Array OutRow := #[]
  let mut nc := 0
  for r in [0:nr] do
    let inrow := body.getD r default
    let mut height := arstrutHeight
    let mut depth := arstrutDepth
    if nc < inrow.size then nc := inrow.size
    let mut cells := #[]
    for cell in inrow do
      let elt ← ctx.group cell o none
      if depth < elt.depth then depth := elt.depth
      if height < elt.height then height := elt.height
      cells := cells.push elt
    let mut gap : Em := 0
    if let some (some rowGap) := rowGaps[r]? then
      gap ← calculateSize rowGap o
      if gap > 0 then
        gap := gap + arstrutDepth
        if depth < gap then depth := gap
        gap := 0
    -- the AMS multi-line environments add \jot between rows
    if addJot == some true && r + 1 < nr then depth := depth + jot
    totalHeight := totalHeight + height
    rows := rows.push { cells, height, depth, pos := totalHeight }
    totalHeight := totalHeight + depth + gap
    let lines := hLinesBeforeRow[r + 1]?.getD #[]
    for h : i in [0:lines.size] do
      if i > 0 then totalHeight := totalHeight + 0.25
      hlines := hlines.push (totalHeight, lines[i])
  let offset := Em.mk (Em.roundDiv totalHeight.raw 2) + fm.axisHeight
  -- the equation numbers and tags, one per row
  let mut tagSpans : Array VElem := #[]
  if let some ts := tags then
    let anyTag := ts.any fun t => match t with
      | .inl b => b
      | .inr _ => true
    if anyTag then
      for r in [0:nr] do
        let rw := rows.getD r default
        let tagSpan ← match ts[r]? with
          | some (.inl true) => pure (makeSpan #["eqn-num"] #[] (some o))
          | some (.inr tag) => pure (makeSpan #[] (← ctx.expr tag o .yes) (some o))
          | _ => pure (makeSpan #[] #[] (some o))
        tagSpans := tagSpans.push
          { elem := { tagSpan with height := rw.height, depth := rw.depth },
            shift := rw.pos - offset }
  -- the columns, with the gaps and rules between them
  let mut cols : Array Box := #[]
  let mut c := 0
  let mut colDescrNum := 0
  -- each step consumes a column or at least one column description
  for _ in [0:nc + colDescriptions.size + 1] do
    if !(c < nc || colDescrNum < colDescriptions.size) then break
    let mut colDescr := colDescriptions[colDescrNum]?
    let mut firstSeparator := true
    for _ in [0:colDescriptions.size + 1] do
      let some (.separator sep) := colDescr | break
      if !firstSeparator then
        cols := cols.push ((makeSpan #["arraycolsep"]).setStyle "width" fm.doubleRuleSep)
      if sep == "|" || sep == ":" then
        let lineType := if sep == "|" then "solid" else "dashed"
        let mut separator := (makeSpan #["vertical-separator"] #[] (some o)).setStyle "height"
          totalHeight
        separator := separator.setStyle "borderRightWidth" ruleThickness
        separator := separator.setStyleStr "borderRightStyle" lineType
        separator := separator.setStyleStr "margin"
          ("0 " ++ (-(Em.mk (Em.roundDiv ruleThickness.raw 2))).css)
        let shift := totalHeight - offset
        if shift != 0 then separator := separator.setStyle "verticalAlign" (-shift)
        cols := cols.push separator
      else throwParse s!"Invalid separator type: {sep}"
      colDescrNum := colDescrNum + 1
      colDescr := colDescriptions[colDescrNum]?
      firstSeparator := false
    if c < nc then
      let (pregap, postgap, align) := match colDescr with
        | some (.align a pre post) => (pre, post, a)
        | _ => (none, none, "")
      if c > 0 || hskipBeforeAndAfter == some true then
        let sepwidth := (pregap.map Em.ofFloat).getD arraycolsep
        if sepwidth != 0 then
          cols := cols.push ((makeSpan #["arraycolsep"]).setStyle "width" sepwidth)
      let mut colElems : Array VElem := #[]
      for row in rows do
        let some elem := row.cells[c]? | continue
        colElems := colElems.push
          { elem := { elem with height := row.height, depth := row.depth },
            shift := row.pos - offset }
      let colVList ← makeVList (.individualShift colElems)
      let align := if align == "" then "c" else align
      cols := cols.push (makeSpan #["col-align-" ++ align] #[colVList])
      if c + 1 < nc || hskipBeforeAndAfter == some true then
        let sepwidth := (postgap.map Em.ofFloat).getD arraycolsep
        if sepwidth != 0 then
          cols := cols.push ((makeSpan #["arraycolsep"]).setStyle "width" sepwidth)
    c := c + 1
    colDescrNum := colDescrNum + 1
  let mut tableBody := makeSpan #["mtable"] cols
  -- the horizontal rules, last first
  if !hlines.isEmpty then
    let line := makeLineSpan "katex-hline" o (some ruleThickness)
    let dashes := makeLineSpan "katex-hdashline" o (some ruleThickness)
    let mut elems : Array VElem := #[{ elem := tableBody }]
    for (pos, dashed) in hlines.reverse do
      elems := elems.push { elem := if dashed then dashes else line, shift := pos - offset }
    tableBody ← makeVList (.individualShift elems)
  if tagSpans.isEmpty then return makeSpan #["mord"] #[tableBody] (some o)
  let eqnNumCol ← makeVList (.individualShift tagSpans)
  return makeFragment #[tableBody, makeSpan #["katex-tag"] #[eqnNumCol] (some o)]

/-- A label beside a vertical arrow of `{CD}`, in script style, raised to the arrow's middle
and taking no height or depth (`cdlabel`). -/
def buildCdLabel (ctx : BuildCtx) (side : String) (label : Node) (o : Options) :
    BuildM Box := do
  let o' := o.havingStyle o.style.sup
  let l := wrapFragment (← ctx.group label o' (some o)) o
  let l := (l.addClass ("cd-label-" ++ side)).setStyle "bottom" (0.8 - l.depth)
  return { l with height := 0, depth := 0 }

/-- A vertical arrow of `{CD}` with its labels (`cdlabelparent`). -/
def buildCdLabelParent (ctx : BuildCtx) (fragment : Node) (o : Options) : BuildM Box := do
  return (wrapFragment (← ctx.group fragment o none) o).addClass "cd-vert-arrow"

end LeAnTeX
