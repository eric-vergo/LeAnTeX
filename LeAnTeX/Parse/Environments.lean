/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Parse.Functions

/-!
# Environment handlers

The handlers of KaTeX's environments: `array` and `darray`, the matrices, `smallmatrix`,
`subarray`, `cases` and its variants, the AMS alignments (`align`, `aligned`, `split`,
`alignat`, `gather`, `gathered`, `equation`) and the commutative diagram `CD`. All but `CD`
read their body with `parseArray`, which splits it into rows at `\\` and cells at `&`.

## Main definitions

* `parseArray`: the body of an array-like environment (KaTeX's `parseArray`).
* `parseCD`: the body of `{CD}`.
* `environmentHandler`: the handler for an environment key.

## References

* KaTeX's `src/environments/array.ts` and `src/environments/cd.ts` (MIT licence, see
  `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- The options of `parseArray`. -/
structure ArrayOpts where
  /-- `\hskip` before and after the array. -/
  hskipBeforeAndAfter : Option Bool := none
  /-- Extra `\jot` between rows. -/
  addJot : Option Bool := none
  /-- Column specifications. -/
  cols : Option (Array AlignSpec) := none
  /-- Row stretch; `none` reads `\arraystretch`. -/
  arraystretch : Option Float := none
  /-- Column separation type. -/
  colSeparationType : Option String := none
  /-- Equation numbering: `none` (no tags), `some true` (automatic), `some false` (only
  explicit `\tag`s). -/
  autoTag : Option Bool := none
  /-- One row only, ended by `\end`. -/
  singleRow : Bool := false
  /-- Keep an empty only row. -/
  emptySingleRow : Bool := false
  /-- The maximum number of columns. -/
  maxNumCols : Option Nat := none
  /-- Tags on the left. -/
  leqno : Option Bool := none

/-- `\hline` and `\hdashline` after a row: one entry per line, `true` when dashed. -/
private def getHLines : M (Array Bool) := do
  let mut info := #[]
  consumeSpacesP
  let mut nxt := (← fetch).text
  if nxt == "\\relax" then
    consume
    consumeSpacesP
    nxt := (← fetch).text
  while nxt == "\\hline" || nxt == "\\hdashline" do
    consume
    info := info.push (nxt == "\\hdashline")
    consumeSpacesP
    nxt := (← fetch).text
  return info

/-- Rows and cells of an array-like environment, each cell in its own group and wrapped in
`style` (KaTeX's `parseArray`). -/
def parseArray (ops : Ops) (o : ArrayOpts) (style : String) : M Node := do
  beginGroup
  if !o.singleRow then setMacro "\\cr" (some (.str "\\\\\\relax"))
  let arraystretch ← match o.arraystretch with
    | some a => pure a
    | none =>
      match ← expandMacroAsText "\\arraystretch" with
      | none => pure 1.0
      | some s =>
        let v := jsParseFloat s
        if v.isNaN || v == 0 || v < 0 then perr s!"Invalid \\arraystretch: {s}"
        pure v
  beginGroup
  let mut row : Array Node := #[]
  let mut body : Array (Array Node) := #[]
  let mut rowGaps : Array (Option Measurement) := #[]
  let mut hLines : Array (Array Bool) := #[]
  let mut tags : Option (Array (Sum Bool (Array Node))) := o.autoTag.map fun _ => #[]
  if o.autoTag == some true then setMacro "\\@eqnsw" (some (.str "1")) true
  hLines := hLines.push (← getHLines)
  repeat
    let cellBody ← ops.parseExpression false (some (if o.singleRow then "\\end" else "\\\\"))
    endGroup
    beginGroup
    let m ← curMode
    let cell := Node.styling m .absent style (some true) #[.ordgroup m .absent cellBody none]
    row := row.push cell
    let next ← fetch
    if next.text == "&" then
      if let some mx := o.maxNumCols then
        if row.size == mx then
          if o.singleRow || o.colSeparationType.isSome then
            perrLoc "Too many tab characters: &" ((← get).nextToken.map (·.loc) |>.getD .absent)
          else
            reportStrict "textEnv" "Too few columns specified in the {array} column argument."
      consume
    else if next.text == "\\end" then
      tags ← endRow tags
      -- a last empty row is dropped, except as the only row of an AMS environment, after a
      -- manual tag, or when automatically numbered
      let lastTag := tags.bind (·.back?)
      let isEmptyCell := row.size == 1 && cellBody.isEmpty
      let manual := match lastTag with | some (.inr _) => true | _ => false
      let autoNumbered := o.autoTag == some true && match lastTag with
        | some (.inl true) => true | _ => false
      let body' := body.push row
      if isEmptyCell && (body'.size > 1 || !o.emptySingleRow) && !manual && !autoNumbered then
        body := body
      else body := body'
      if hLines.size < body.size + 1 then hLines := hLines.push #[]
      break
    else if next.text == "\\\\" then
      consume
      let size ← if (← future).text != " " then parseSizeGroup true else pure none
      rowGaps := rowGaps.push (match size with | some (.size _ _ v _) => some v | _ => none)
      tags ← endRow tags
      hLines := hLines.push (← getHLines)
      body := body.push row
      row := #[]
      if o.autoTag == some true then setMacro "\\@eqnsw" (some (.str "1")) true
    else
      perrLoc "Expected & or \\\\ or \\cr or \\end"
        ((← get).nextToken.map (·.loc) |>.getD .absent)
  endGroup
  endGroup
  return .array (← curMode) .absent o.colSeparationType o.hskipBeforeAndAfter o.addJot o.cols
    arraystretch body rowGaps hLines tags o.leqno
where
  /-- Record the tag of the row that just ended. -/
  endRow (tags : Option (Array (Sum Bool (Array Node)))) :
      M (Option (Array (Sum Bool (Array Node)))) := do
    let some ts := tags | return none
    if ((← getMacro "\\df@tag").map MacroDef.truthy).getD false then
      let t ← ops.subparse #[{ text := "\\df@tag" }]
      setMacro "\\df@tag" none true
      return some (ts.push (.inr t))
    let sw ← getMacro "\\@eqnsw"
    let on := match sw with | some (.str "1") => true | _ => false
    return some (ts.push (.inl (o.autoTag == some true && on)))
  /-- JavaScript's `parseFloat`: the longest decimal prefix after leading spaces. -/
  jsParseFloat (s : String) : Float :=
    let cs := s.toList.dropWhile isJsSpace
    let (sign, cs) := match cs with
      | '-' :: r => ("-", r) | '+' :: r => ("", r) | r => ("", r)
    let ip := cs.takeWhile Char.isDigit
    let rest := cs.dropWhile Char.isDigit
    let fp := match rest with
      | '.' :: r => r.takeWhile Char.isDigit
      | _ => []
    if ip.isEmpty && fp.isEmpty then 0.0 / 0.0
    else decimalToFloat (sign ++ String.ofList ip ++ "." ++ String.ofList fp)

/-- Cells set in display style for environment names starting with `d`, else text style. -/
private def dCellStyle (envName : String) : String :=
  if envName.startsWith "d" then "display" else "text"

/-- The AMS environments that need display mode. -/
private def validateAms (ctx : EnvCtx) : M Unit := do
  if !(← settings).displayMode then perr s!"\{{ctx.envName}} can be used only in display mode."

/-- Automatic numbering for an environment name: none for names with `ed`, else on unless
starred. -/
private def getAutoTag (name : String) : Option Bool :=
  if (name.splitOn "ed").length > 1 then none else some !(name.contains '*')

/-- Column specifications from an `{array}` / `{subarray}` argument. -/
private def colSpecs (arg : Node) (allowed : String) (seps : Bool) : M (Array AlignSpec) := do
  let nodes ← match arg.symText? with
    | some _ => pure #[arg]
    | none => match arg with
      | .ordgroup _ _ body _ => pure body
      | n => wrongNode "ordgroup" (some n)
  nodes.mapM fun nde => do
    let some ca := nde.symText?
      | ierr s!"Expected node of symbol group type, but got node of type {nde.type}"
    if (allowed.splitOn ca).length > 1 then return .align ca none none
    if seps && (ca == "|" || ca == ":") then return .separator ca
    perrLoc s!"Unknown column alignment: {ca}" nde.loc

/-- The handler shared by `align`, `aligned`, `split`, `alignat`, `alignedat`. -/
private def alignedHandler (ops : Ops) (ctx : EnvCtx) (args : Array Node) : M Node := do
  if (ctx.envName.splitOn "ed").length == 1 then validateAms ctx
  let isSplit := ctx.envName == "split"
  let leqno := (← settings).leqno
  let colSep := if (ctx.envName.splitOn "at").length > 1 then "alignat" else "align"
  let opts : ArrayOpts := {
    cols := some #[], addJot := some true, emptySingleRow := true, leqno := some leqno
    autoTag := if isSplit then none else getAutoTag ctx.envName
    colSeparationType := some colSep
    maxNumCols := if isSplit then some 2 else none }
  let res ← parseArray ops opts "display"
  let .array m l _ hs aj _ st body gaps hl tags lq := res | return res
  let mut numMaths := 0
  let mut numCols := 0
  if let some a@(Node.ordgroup ..) := args[0]? then
    let message := "Number of columns should be a positive integer"
    let s ← assertCharacterGroup a message
    if s.isEmpty || !s.all Char.isDigit then perrLoc message a.loc
    let some n := s.toNat? | perrLoc message a.loc
    if n < 1 then perrLoc message a.loc
    numMaths := n
    numCols := numMaths * 2
  let isAligned := numCols == 0
  let mut body' := #[]
  for row in body do
    let mut row := row
    let mut i := 1
    while i < row.size do
      match row[i]? with
      | some (.styling sm sl ss sr sb) =>
        match sb[0]? with
        | some (Node.ordgroup om ol ob os) =>
          row := row.setIfInBounds i (.styling sm sl ss sr
            (sb.setIfInBounds 0 (.ordgroup om ol (#[Node.emptyGroup ctx.mode] ++ ob) os)))
        | n => wrongNode "ordgroup" n
      | some n => wrongNode "styling" (some n)
      | none => pure ()
      i := i + 2
    if !isAligned then
      let curMaths := row.size.toFloat / 2
      if numMaths.toFloat < curMaths then
        perrLoc s!"Too many math in a row: expected {numMaths}, but got {jsNum curMaths}"
          (row[0]?.map (·.loc) |>.getD .absent)
    else if numCols < row.size then numCols := row.size
    body' := body'.push row
  let cols := (List.range numCols).toArray.map fun i =>
    let align := if i % 2 == 1 then "l" else "r"
    let pregap := if i % 2 == 0 && i > 0 && isAligned then 1.0 else 0.0
    AlignSpec.align align (some pregap) (some 0)
  return .array m l (some (if isAligned then "align" else "alignat")) hs aj (some cols) st body'
    gaps hl tags lq
where
  /-- A half-integer as JavaScript prints it in a message (`2`, `1.5`). -/
  jsNum (x : Float) : String :=
    if x == x.floor then toString x.toUInt64.toNat else s!"{x.floor.toUInt64.toNat}.5"

/-- `{CD}`: rows of cells and arrows (`@>>>`, `@<<<`, `@AAA`, `@VVV`, `@=`, `@|`, `@.`), laid out
as an array (KaTeX's `parseCD`). -/
def parseCD (ops : Ops) : M Node := do
  let mut parsedRows : Array (Array Node) := #[]
  beginGroup
  setMacro "\\cr" (some (.str "\\\\\\relax"))
  beginGroup
  repeat
    parsedRows := parsedRows.push (← ops.parseExpression false (some "\\\\"))
    endGroup
    beginGroup
    let next := (← fetch).text
    if next == "&" || next == "\\\\" then consume
    else if next == "\\end" then
      if parsedRows.back?.map (·.isEmpty) == some true then parsedRows := parsedRows.pop
      break
    else perrLoc "Expected \\\\ or \\cr or \\end" ((← get).nextToken.map (·.loc) |>.getD .absent)
  let newCell : Node := .styling .math .absent "display" (some true) #[]
  let pushCell (cell : Node) (n : Node) : Node := match cell with
    | .styling m l s r b => .styling m l s r (b.push n)
    | c => c
  let mut row : Array Node := #[]
  let mut body : Array (Array Node) := #[]
  for i in [0:parsedRows.size] do
    let rowNodes := parsedRows.getD i #[]
    let mut cell := newCell
    let mut j := 0
    while j < rowNodes.size do
      let some nj := rowNodes[j]? | break
      if !(isStartOfArrow nj) then
        cell := pushCell cell nj
      else
        row := row.push cell
        j := j + 1
        let some arrowChar := rowNodes[j]?.bind (·.symText?)
          | match rowNodes[j]? with
            | some n => ierr s!"Expected node of symbol group type, but got node of type {n.type}"
            | none => throw (.internal "TypeError" "Cannot read properties of undefined")
        let mut labels : Array (Array Node) := #[#[], #[]]
        if ("=|.".splitOn arrowChar).length > 1 then pure ()
        else if ("<>AV".splitOn arrowChar).length > 1 then
          for labelNum in [0:2] do
            let mut inLabel := true
            let mut k := j + 1
            while k < rowNodes.size do
              let some nk := rowNodes[k]? | break
              if isLabelEnd nk arrowChar then
                inLabel := false
                j := k
                break
              if isStartOfArrow nk then
                perrLoc s!"Missing a {arrowChar} character to complete a CD arrow." nk.loc
              labels := labels.modify labelNum (·.push nk)
              k := k + 1
            if inLabel then
              perrLoc s!"Missing a {arrowChar} character to complete a CD arrow."
                (rowNodes[j]?.map (·.loc) |>.getD .absent)
        else
          perrLoc "Expected one of \"<>AV=|.\" after @" (rowNodes[j]?.map (·.loc) |>.getD .absent)
        let lab (k : Nat) : Node := .ordgroup .math .absent (labels.getD k #[]) none
        let arrow ← cdArrow arrowChar (lab 0) (lab 1)
        row := row.push (.styling .math .absent "display" (some true) #[arrow])
        cell := newCell
      j := j + 1
    if i % 2 == 0 then row := row.push cell
    else row := row.extract 1 row.size
    body := body.push row
    row := #[]
  body := body.push row
  endGroup
  endGroup
  let ncols := (body[0]?.map (·.size)).getD 0
  let cols := (List.replicate ncols (AlignSpec.align "c" (some 0.25) (some 0.25))).toArray
  return .array .math .absent (some "CD") none (some true) (some cols) 1.0 body #[none]
    ((List.replicate (body.size + 1) #[]).toArray) none none
where
  /-- An `@`, which starts an arrow. -/
  isStartOfArrow : Node → Bool
    | .sym _ _ .textord "@" => true
    | _ => false
  /-- The character that ends an arrow label. -/
  isLabelEnd (n : Node) (endChar : String) : Bool :=
    match n with
    | .sym _ _ g t => (g == .mathord || g.isAtom) && t == endChar
    | _ => false
  /-- The parse tree of an arrow with its labels. -/
  cdArrow (arrowChar : String) (l0 l1 : Node) : M Node := do
    match arrowChar with
    | ">" => ops.callFunction "\\\\cdrightarrow" #[l0] #[some l1] none none
    | "<" => ops.callFunction "\\\\cdleftarrow" #[l0] #[some l1] none none
    | "A" | "V" =>
      let fn := if arrowChar == "A" then "\\uparrow" else "\\downarrow"
      let left ← ops.callFunction "\\\\cdleft" #[l0] #[] none none
      let bare := Node.sym .math .absent .rel fn
      let sized ← ops.callFunction "\\Big" #[bare] #[] none none
      let right ← ops.callFunction "\\\\cdright" #[l1] #[] none none
      ops.callFunction "\\\\cdparent" #[.ordgroup .math .absent #[left, sized, right] none] #[]
        none none
    | "=" => ops.callFunction "\\\\cdlongequal" #[] #[] none none
    | "|" => ops.callFunction "\\Big" #[.sym .math .absent .textord "\\Vert"] #[] none none
    | _ => return .sym .math .absent .textord " "

/-- The handler for an environment key. -/
def environmentHandler (key : String) : Option EnvHandler :=
  match key with
  | "array" => some fun ops ctx args _ => do
    let cols ← colSpecs (← argAt args 0) "lcr" true
    parseArray ops { cols := some cols, hskipBeforeAndAfter := some true,
                     maxNumCols := some cols.size } (dCellStyle ctx.envName)
  | "matrix" => some fun ops ctx _ _ => do
    let base := ctx.envName.replace "*" ""
    let delims : Option (String × String) := match base with
      | "pmatrix" => some ("(", ")") | "bmatrix" => some ("[", "]")
      | "Bmatrix" => some ("\\{", "\\}") | "vmatrix" => some ("|", "|")
      | "Vmatrix" => some ("\\Vert", "\\Vert") | _ => none
    let mut colAlign := "c"
    if ctx.envName.endsWith "*" then
      consumeSpacesP
      if (← fetch).text == "[" then
        consume
        consumeSpacesP
        colAlign := (← fetch).text
        if ("lcr".splitOn colAlign).length == 1 then
          perrLoc "Expected l or c or r" ((← get).nextToken.map (·.loc) |>.getD .absent)
        consume
        consumeSpacesP
        expect "]"
        consume
    let res ← parseArray ops { hskipBeforeAndAfter := some false,
                               cols := some #[.align colAlign none none] } (dCellStyle ctx.envName)
    let res := match res with
      | .array m l cst hs aj _ st body gaps hl tags lq =>
        let n := body.foldl (fun acc r => max acc r.size) 0
        Node.array m l cst hs aj (some (List.replicate n (.align colAlign none none)).toArray) st
          body gaps hl tags lq
      | r => r
    match delims with
    | some (l, r) => return .leftright ctx.mode .absent #[res] l r none
    | none => return res
  | "smallmatrix" => some fun ops _ _ _ => do
    let res ← parseArray ops { arraystretch := some 0.5 } "script"
    match res with
    | .array m l _ hs aj cols st body gaps hl tags lq =>
      return .array m l (some "small") hs aj cols st body gaps hl tags lq
    | r => return r
  | "subarray" => some fun ops _ args _ => do
    let cols ← colSpecs (← argAt args 0) "lc" false
    if cols.size > 1 then perr "{subarray} can contain only one column"
    let res ← parseArray ops { cols := some cols, hskipBeforeAndAfter := some false,
                               arraystretch := some 0.5 } "script"
    if let .array _ _ _ _ _ _ _ body .. := res then
      if (body[0]?.map (·.size)).getD 0 > 1 then perr "{subarray} can contain only one column"
    return res
  | "cases" => some fun ops ctx _ _ => do
    let cols := #[.align "l" (some 0) (some 1.0), .align "l" (some 0) (some 0)]
    let res ← parseArray ops { arraystretch := some 1.2, cols := some cols }
      (dCellStyle ctx.envName)
    let r := ctx.envName.contains 'r'
    return .leftright ctx.mode .absent #[res] (if r then "." else "\\{")
      (if r then "\\}" else ".") none
  | "align" | "alignat" => some fun ops ctx args _ => alignedHandler ops ctx args
  | "gathered" => some fun ops ctx _ _ => do
    if ctx.envName == "gather" || ctx.envName == "gather*" then validateAms ctx
    let leqno := (← settings).leqno
    let opts : ArrayOpts := {
      cols := some #[.align "c" none none], addJot := some true
      colSeparationType := some "gather", autoTag := getAutoTag ctx.envName
      emptySingleRow := true, leqno := some leqno }
    parseArray ops opts "display"
  | "equation" => some fun ops ctx _ _ => do
    validateAms ctx
    let leqno := (← settings).leqno
    let opts : ArrayOpts := {
      autoTag := getAutoTag ctx.envName, emptySingleRow := true, singleRow := true
      maxNumCols := some 1, leqno := some leqno }
    parseArray ops opts "display"
  | "CD" => some fun ops ctx _ _ => do
    validateAms ctx
    parseCD ops
  | _ => none

end LeAnTeX
