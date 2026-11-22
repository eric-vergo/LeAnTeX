/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX
import LeAnTeXTest.JsonParse

/-!
# The layout differential test

For every case of every corpus, LeAnTeX's box tree against KaTeX's (`fixtures/layout/`, written
by `tools/record.mjs --layout` from KaTeX's `__renderToHTMLTree`): the same nodes with the same
kinds, texts, classes, style properties and attributes, and every number (height, depth,
maxFontSize, italic correction, skew, width, style lengths, numbers in SVG data) within the
tolerance; and the same strict-mode warnings. The display list of every tree LeAnTeX lays out
must keep its invariants (`DisplayList.wellFormed`).

## Main definitions

* `LayoutOutcome`: how a case compares.
* `treeDiff`: the first difference between two trees in their JSON form, and the largest
  numeric deviation where they agree.
* `runLayoutCorpus`, `layoutReport`, `layoutBaselineText`.
-/

open LeAnTeX

namespace LayoutTest

/-- The tolerance on lengths in em. KaTeX writes CSS lengths rounded to 1e-4 em, so two
correct layouts can differ by 5e-5 em in a style value; LeAnTeX's fixed point adds at most a
few 2⁻¹⁶ em. -/
def tolerance : Float := 1e-4

/-- How a case compares with KaTeX. -/
inductive LayoutOutcome where
  /-- Both lay it out, with the same tree within the tolerance and the same warnings. -/
  | same
  /-- Both reject it, with the same error (class and message) and the same warnings. -/
  | bothReject
  /-- KaTeX lays it out; LeAnTeX does not lay out one of its constructs yet. -/
  | notYet
  /-- Both lay it out; the trees differ. -/
  | differs
  /-- Same trees, different warnings. -/
  | warningsDiffer
  /-- KaTeX lays it out, LeAnTeX fails. -/
  | leanRejects
  /-- KaTeX fails, LeAnTeX lays it out. -/
  | leanAccepts
  /-- Both reject it, with different errors or different warnings. -/
  | errorDiffers
  deriving BEq, Inhabited

/-- The outcome's name in reports. -/
def LayoutOutcome.name : LayoutOutcome → String
  | .same => "same" | .bothReject => "both-reject" | .notYet => "not-yet"
  | .differs => "differs" | .warningsDiffer => "warnings-differ"
  | .leanRejects => "lean-rejects" | .leanAccepts => "lean-accepts"
  | .errorDiffers => "error-differs"

/-- Whether the outcome counts as parity (for the baseline). -/
def LayoutOutcome.ok (o : LayoutOutcome) : Bool := o == .same || o == .bothReject

/-- A number with an optional sign, digits and a fraction at the start of a list of
characters, and the rest. -/
def numberPrefix (cs : List Char) : Option (Float × List Char) :=
  let (sign, rest) := match cs with
    | '-' :: r => (-1.0, r)
    | r => (1.0, r)
  let (ip, rest) := rest.span Char.isDigit
  let (fp, rest) := match rest with
    | '.' :: r => r.span Char.isDigit
    | r => ([], r)
  if ip.isEmpty && fp.isEmpty then none
  else
    let digits := ip ++ fp
    let n := digits.foldl (fun acc c => acc * 10 + (c.toNat - '0'.toNat)) 0
    some (sign * n.toFloat / (10 : Float) ^ fp.length.toFloat, rest)

/-- A string split into numbers and the text between them. -/
def tokens (s : String) : Array (Sum String Float) := Id.run do
  let mut out := #[]
  let mut cs := s.toList
  let mut text := ""
  for _ in [0:s.length + 1] do
    match cs with
    | [] => break
    | c :: rest =>
      let prevDigit := text.back.isDigit || text.back == '.'
      match (if prevDigit then none else numberPrefix cs) with
      | some (x, rest') =>
        if !text.isEmpty then out := out.push (.inl text)
        text := ""
        out := out.push (.inr x)
        cs := rest'
      | none =>
        text := text.push c
        cs := rest
  if !text.isEmpty then out := out.push (.inl text)
  return out

/-- The largest deviations found in a comparison: of the unrounded numbers (heights, depths,
widths, …), of CSS lengths (which KaTeX rounds to 1e-4 em), and of the numbers in SVG data (in
SVG units, 1/1000 em, which KaTeX rounds to integers). -/
structure Deviation where
  /-- Unrounded numbers, in em. -/
  raw : Float := 0
  /-- CSS lengths, in em. -/
  css : Float := 0
  /-- SVG data, in SVG units. -/
  svg : Float := 0
  deriving Inhabited

/-- The larger of two deviations, field by field. -/
def Deviation.max (a b : Deviation) : Deviation :=
  ⟨Max.max a.raw b.raw, Max.max a.css b.css, Max.max a.svg b.svg⟩

/-- Whether a deviation is within the tolerances: `tolerance` for unrounded numbers, one unit of
KaTeX's rounding for CSS lengths (two correct values a hair apart can round to neighbouring
four-decimal strings) and for SVG data. -/
def Deviation.ok (d : Deviation) : Bool :=
  d.raw ≤ tolerance && d.css ≤ 1e-4 + 1e-9 && d.svg ≤ 1 + 1e-9

/-- Compare two strings with the numbers in them: `none` when the texts between the numbers
differ, else the largest difference of the numbers. -/
def stringDiff (a b : String) : Option Float :=
  if a == b then some 0
  else
    let ta := tokens a
    let tb := tokens b
    if ta.size != tb.size then none
    else
      (ta.zip tb).foldl (init := some 0) fun acc (x, y) =>
        acc.bind fun m => match x, y with
          | .inl p, .inl q => if p == q then some m else none
          | .inr p, .inr q => some (max m (p - q).abs)
          | _, _ => none

/-- The keys of the compact form whose number the recorder leaves out when it is zero
(`put` in `tools/record.mjs`), in a node of kind `kind`: height, depth, maximum font size and
skew everywhere, a symbol's italic correction and width. Elsewhere an absent number is not a
zero (a span's `w` and `i` are written whenever they are set, zero included). -/
def zeroOmitted (kind : Option String) (key : String) : Bool :=
  ["h", "d", "m", "sk"].contains key || (kind == some "sym" && (key == "i" || key == "w"))

/-- Compare two lists of `[name, value]` pairs (a node's style `st` or attributes `at`): the
names exactly, the values as lengths. A value is SVG data (in SVG units) when `svg` is set and
it does not end in `em`, else a CSS value. -/
def pairsDiff (k l : Json) (path : String) (svg : Bool) : Except String Deviation := do
  let some a := k.getArr? | throw s!"{path}: not a list of pairs"
  let some b := l.getArr? | throw s!"{path}: not a list of pairs"
  if a.size != b.size then throw s!"{path}: {a.size} vs {b.size} pairs"
  let mut m : Deviation := {}
  for h : i in [0:a.size] do
    match a[i].getArr?, (b[i]?.getD .null).getArr? with
    | some #[.str n, .str x], some #[.str n', .str y] =>
      if n != n' then throw s!"{path}[{i}]: {Json.quote n} vs {Json.quote n'}"
      match stringDiff x y with
      | some d => m := m.max (if svg && !x.endsWith "em" then { svg := d } else { css := d })
      | none => throw s!"{path}[{i}] {n}: {Json.quote x} vs {Json.quote y}"
    | _, _ => throw s!"{path}[{i}]: not a pair of strings"
  return m

/-- The first structural difference of two trees in JSON form (`.error path`), or the largest
deviations (`.ok d`). Every string is compared exactly (kinds, texts, classes, path names, image
sources) except the values of style properties and attributes (`pairsDiff`) and an SVG path's
data (`alt`, in SVG units), whose numbers are compared within the tolerances. An absent number
is zero only where the recorder leaves zeros out (`zeroOmitted`). -/
partial def treeDiff (k l : Json) (path : String := "") (svg : Bool := false) :
    Except String Deviation :=
  match k, l with
  | .num a, .num b => .ok { raw := (a - b).abs }
  | .str a, .str b =>
    if a == b then .ok {} else .error s!"{path}: {Json.quote a} vs {Json.quote b}"
  | .arr a, .arr b =>
    if a.size != b.size then .error s!"{path}: {a.size} vs {b.size} elements"
    else Id.run do
      let mut m : Deviation := {}
      for h : i in [0:a.size] do
        match treeDiff a[i] (b[i]?.getD .null) s!"{path}[{i}]" svg with
        | .ok d => m := m.max d
        | .error e => return .error e
      return .ok m
  | .obj a, .obj b => do
    let keys := (a.map (·.1) ++ b.map (·.1)).toList.eraseDups
    let kind := (k.get? "k").bind Json.getStr?
    let svg := svg || kind == some "svg"
    let mut m : Deviation := {}
    for key in keys do
      match k.get? key, l.get? key with
      | some x, some y =>
        if key == "st" || key == "at" then m := m.max (← pairsDiff x y s!"{path}.{key}" svg)
        else if key == "alt" && kind == some "path" then
          match x, y with
          | .str p, .str q => match stringDiff p q with
            | some d => m := m.max { svg := d }
            | none => throw s!"{path}.alt: {Json.quote p} vs {Json.quote q}"
          | _, _ => throw s!"{path}.alt: not a string"
        else m := m.max (← treeDiff x y s!"{path}.{key}" svg)
      | some (.num x), none =>
        if zeroOmitted kind key then m := m.max { raw := x.abs }
        else throw s!"{path}.{key}: KaTeX has {x}, LeAnTeX none"
      | none, some (.num y) =>
        if zeroOmitted kind key then m := m.max { raw := y.abs }
        else throw s!"{path}.{key}: LeAnTeX has {y}, KaTeX none"
      | some x, none => throw s!"{path}.{key}: KaTeX has {x.compress.take 80}, LeAnTeX none"
      | none, some y => throw s!"{path}.{key}: LeAnTeX has {y.compress.take 80}, KaTeX none"
      | none, none => pure ()
    return m
  | .bool a, .bool b => if a == b then .ok {} else .error s!"{path}: booleans"
  | .null, .null => .ok {}
  | _, _ => .error s!"{path}: {k.compress.take 60} vs {l.compress.take 60}"

/-- The checks of the tree comparison on made-up trees (`treeDiff`): each pair is
`(name, holds)`. Each would catch a string compared with the tolerance of a length, or an absent
number taken for a zero where the recorder writes zeros. -/
def comparatorChecks : List (String × Bool) :=
  let j := fun (s : String) => (Json.parse s).toOption.getD .null
  let passes := fun (a b : String) => match treeDiff (j a) (j b) with
    | .ok d => d.ok
    | .error _ => false
  [("a text is compared exactly",
     !passes "{\"k\":\"sym\",\"t\":\"01\"}" "{\"k\":\"sym\",\"t\":\"1\"}"),
   ("a class is compared exactly",
     !passes "{\"k\":\"span\",\"c\":[\"x1\"]}" "{\"k\":\"span\",\"c\":[\"x1.00009\"]}"),
   ("a style length within the tolerance passes",
     passes "{\"k\":\"span\",\"st\":[[\"height\",\"0.35em\"]]}"
       "{\"k\":\"span\",\"st\":[[\"height\",\"0.35009em\"]]}"),
   ("a style property's name is compared exactly",
     !passes "{\"k\":\"span\",\"st\":[[\"height\",\"1em\"]]}"
       "{\"k\":\"span\",\"st\":[[\"width\",\"1em\"]]}"),
   ("a style length past the tolerance fails",
     !passes "{\"k\":\"span\",\"st\":[[\"height\",\"0.35em\"]]}"
       "{\"k\":\"span\",\"st\":[[\"height\",\"0.3502em\"]]}"),
   ("SVG path data within one SVG unit passes",
     passes "{\"k\":\"path\",\"name\":\"v\",\"alt\":\"M1 2\"}"
       "{\"k\":\"path\",\"name\":\"v\",\"alt\":\"M1.9 2\"}"),
   ("SVG path data past one SVG unit fails",
     !passes "{\"k\":\"path\",\"name\":\"v\",\"alt\":\"M1 2\"}"
       "{\"k\":\"path\",\"name\":\"v\",\"alt\":\"M2.1 2\"}"),
   ("a path's name is compared exactly",
     !passes "{\"k\":\"path\",\"name\":\"v1\"}" "{\"k\":\"path\",\"name\":\"v2\"}"),
   ("an absent height is a zero height",
     passes "{\"k\":\"span\"}" "{\"k\":\"span\",\"h\":0}"),
   ("an absent span width is not a zero width",
     !passes "{\"k\":\"span\"}" "{\"k\":\"span\",\"w\":0}"),
   ("an unknown absent number is not a zero", !passes "{\"a\":0}" "{}")]

/-- The result of one case. -/
structure LayoutResult where
  /-- The corpus. -/
  corpus : String
  /-- The case id. -/
  id : String
  /-- The formula. -/
  tex : String
  /-- How it compares. -/
  outcome : LayoutOutcome
  /-- The largest deviations of a matching tree. -/
  deviation : Deviation := {}
  /-- What differs, or what is not laid out yet. -/
  detail : String := ""
  /-- The parse node types of the formula. -/
  constructs : List String := []
  /-- KaTeX's tree. -/
  katex : Json := .null
  /-- LeAnTeX's tree. -/
  lean : Json := .null

/-- The parse node types in a parse tree's JSON form, with symbol kinds as `atom:rel` and the
like. -/
partial def constructsOf (j : Json) : List String :=
  match j with
  | .arr xs => (xs.toList.map constructsOf).flatten
  | .obj kvs =>
    let here := match j.get? "type" with
      | some (.str "atom") => match j.get? "family" with
        | some (.str f) => ["atom:" ++ f]
        | _ => ["atom"]
      -- the column specifications of an array are not parse nodes
      | some (.str "align") | some (.str "separator") => []
      | some (.str t) => [t]
      | _ => []
    here ++ (kvs.toList.map fun (_, v) => constructsOf v).flatten
  | _ => []

/-- Run every case of a corpus against its layout fixture. `cases` are the corpus's cases (id,
formula, settings) as the parser test reads them. -/
def runLayoutCorpus (name : String) (cases : Array (String × String × Settings)) :
    IO (Array LayoutResult) := do
  let path : System.FilePath := s!"fixtures/layout/{name}.jsonl"
  if !(← path.pathExists) then
    throw (IO.userError s!"no layout fixture {path}; run tools/record.mjs --layout")
  let lines ← IO.FS.lines path
  let mut byId : Std.HashMap String Json := {}
  for l in lines.toList.drop 1 do
    if l.trimAscii.isEmpty then continue
    match Json.parse l with
    | .ok j => if let some id := (j.get? "id").bind Json.getStr? then
        if byId.contains id then throw (IO.userError s!"{path}: {id} twice")
        byId := byId.insert id j
    | .error e => throw (IO.userError s!"{path}: bad JSON line ({e})")
  let mut out := #[]
  for (id, tex, settings) in cases do
    let some k := byId[id]? | throw (IO.userError s!"no layout fixture for {id}")
    if k.get? "unrepresentable" |>.isSome then continue
    if (k.get? "box").isSome == (k.get? "error").isSome ||
        ((k.get? "warnings").bind Json.getArr?).isNone then
      throw (IO.userError s!"{path}: {id}: neither a box nor an error, or no warnings")
    let constructs := match (parse tex settings).result with
      | .ok t => (constructsOf (nodesToJson t)).eraseDups
      | .error _ => []
    let r := layout tex settings
    -- the display list of every tree LeAnTeX lays out keeps its invariants
    let displayOk := match r.result with
      | .ok b => (DisplayList.ofBox b).wellFormed
      | .error _ => true
    let kw := k.get? "warnings"
    let lw := Json.arr (r.warnings.map Json.str)
    let base : LayoutResult := { corpus := name, id, tex, outcome := .same, constructs }
    let res : LayoutResult := match k.get? "box", r.result with
      | some kb, .ok b =>
        let lb := b.toJson
        match treeDiff kb lb with
        | .ok d =>
          if !d.ok then
            { base with outcome := .differs, deviation := d,
                        detail := s!"deviation {d.raw} em, CSS {d.css} em, SVG {d.svg}",
                        katex := kb, lean := lb }
          else if !(kw.map (·.sameAs lw)).getD false then
            { base with outcome := .warningsDiffer, deviation := d, katex := kb, lean := lb }
          else { base with deviation := d }
        | .error e => { base with outcome := .differs, detail := e, katex := kb, lean := lb }
      | some _, .error (.unsupported what) => { base with outcome := .notYet, detail := what }
      | some kb, .error (.katex e) =>
        { base with outcome := .leanRejects, detail := e.message, katex := kb }
      | none, .ok b => { base with outcome := .leanAccepts, lean := b.toJson }
      | none, .error (.unsupported what) => { base with outcome := .notYet, detail := what }
      | none, .error (.katex e) =>
        let ke := k.get? "error"
        let sameErr := (ke.bind (·.get? "kind")).bind Json.getStr? == some "ParseError" &&
          (ke.bind (·.get? "message")).bind Json.getStr? == some e.message
        if !sameErr then
          { base with outcome := .errorDiffers,
                      detail := s!"KaTeX {(ke.getD .null).compress.take 80}, LeAnTeX {e.message}" }
        else if !(kw.map (·.sameAs lw)).getD false then
          { base with outcome := .errorDiffers, detail := "the warnings differ" }
        else { base with outcome := .bothReject }
    let res := if displayOk then res
      else { res with outcome := .differs, detail := "display list breaks its invariants" }
    out := out.push res
  return out

/-- A small float in scientific notation with two significant digits (`1.5e-05`). -/
def fmtSci (x : Float) : String := Id.run do
  if x == 0 then return "0"
  let mut e : Int := 0
  let mut m := x
  for _ in [0:40] do
    if m < 1 then
      m := m * 10
      e := e - 1
    else if m ≥ 10 then
      m := m / 10
      e := e + 1
    else break
  let r := (m * 10).round / 10
  return s!"{(toString r).take 3}e{e}"

/-- The baseline: per case, `ok`, `not-yet` or `mismatch`. -/
def layoutBaselineText (results : Array LayoutResult) : String :=
  "# corpus\tcase id\tlayout status (written by lake exe leantex-test --update)\n" ++
  String.join (results.toList.map fun r =>
    let st := if r.outcome.ok then "ok" else if r.outcome == .notYet then "not-yet"
      else "mismatch"
    s!"{r.corpus}\t{r.id}\t{st}\n")

/-- The Markdown layout parity report. -/
def layoutReport (results : Array LayoutResult) (seconds : Float) : String := Id.run do
  let laidOut := results.filter fun r => r.outcome == .same || r.outcome == .differs ||
    r.outcome == .warningsDiffer || r.outcome == .leanRejects
  let worst : Deviation :=
    (results.filter (·.outcome == .same)).foldl (fun m r => m.max r.deviation) {}
  let mut s := "# Layout parity report\n\n" ++
    "Generated by `lake exe leantex-test --update`; do not edit by hand. LeAnTeX's box tree " ++
    "against KaTeX 0.19.1's (`__renderToHTMLTree`, recorded in `fixtures/layout/`): every " ++
    "node with its kind, text, classes, style properties and attributes, and every number " ++
    "(heights, depths, widths, shifts, kerns, struts, SVG data) within the tolerance, and " ++
    "the strict-mode warnings. The tolerance: 1e-4 em for the unrounded numbers; for CSS " ++
    "lengths, which KaTeX rounds to four decimals, one unit of that rounding (1e-4 em); for " ++
    "the numbers in SVG data, which KaTeX rounds to whole SVG units, one unit (1/1000 em)." ++
    "\n\nLargest deviation on an identical tree: " ++
    s!"{fmtSci worst.raw} em in an unrounded number, {fmtSci worst.css} em in a CSS length, " ++
    s!"{worst.svg} SVG units in SVG data.\n\n" ++
    "## Corpora\n\n| Corpus | Cases | KaTeX lays out | Identical | Differs | Not yet in " ++
    "scope | Both reject |\n|---|---:|---:|---:|---:|---:|---:|\n"
  let names := (results.map (·.corpus)).toList.eraseDups
  let row (label : String) (rs : Array LayoutResult) : String :=
    let cnt (p : LayoutResult → Bool) := (rs.filter p).size
    let katexOk := cnt fun r => r.outcome != .bothReject && r.outcome != .leanAccepts &&
      r.outcome != .errorDiffers
    s!"| {label} | {rs.size} | {katexOk} | {cnt (·.outcome == .same)} | " ++
      s!"{cnt fun r => !r.outcome.ok && r.outcome != .notYet} | " ++
      s!"{cnt (·.outcome == .notYet)} | {cnt (·.outcome == .bothReject)} |\n"
  for c in names do
    s := s ++ row c (results.filter (·.corpus == c))
  s := s ++ row "all" results
  s := s ++ "\n## Mismatches by kind\n\n| Kind | Cases |\n|---|---:|\n"
  for o in [LayoutOutcome.differs, .warningsDiffer, .leanRejects, .leanAccepts, .errorDiffers] do
    s := s ++ s!"| {o.name} | {(results.filter (·.outcome == o)).size} |\n"
  -- per construct: the formulas KaTeX lays out that contain it
  let mut stats : Std.HashMap String (Nat × Nat × Nat) := {}
  for r in results do
    if r.outcome == .bothReject || r.outcome == .leanAccepts || r.outcome == .errorDiffers then
      continue
    for c in r.constructs do
      let (a, b, n) := stats.getD c (0, 0, 0)
      stats := stats.insert c <| match r.outcome with
        | .same => (a + 1, b, n)
        | .notYet => (a, b, n + 1)
        | _ => (a, b + 1, n)
  let keys := stats.toList.map (·.1) |>.toArray.qsort (· < ·)
  s := s ++ "\n## Constructs\n\nFor each parse node type (atoms by class), the formulas " ++
    "KaTeX lays out that contain it: laid out identically, differing, or not yet in scope " ++
    "(the formula contains a construct LeAnTeX does not lay out yet, not necessarily this " ++
    "one).\n\n| Construct | Formulas | Identical | Differs | Not yet in scope |\n" ++
    "|---|---:|---:|---:|---:|\n"
  for k in keys do
    let (a, b, n) := stats.getD k (0, 0, 0)
    s := s ++ s!"| `{k}` | {a + b + n} | {a} | {b} | {n} |\n"
  -- what blocks the formulas not yet in scope
  let mut blocks : Std.HashMap String Nat := {}
  for r in results do
    if r.outcome == .notYet then blocks := blocks.insert r.detail (blocks.getD r.detail 0 + 1)
  let bl := blocks.toList.toArray.qsort (fun a b => a.2 > b.2 || (a.2 == b.2 && a.1 < b.1))
  s := s ++ "\n## Not yet in scope\n\n"
  if bl.isEmpty then
    s := s ++ "None: LeAnTeX lays out every construct of every formula KaTeX lays out.\n"
  else
    s := s ++ "The first construct LeAnTeX does not lay out, by number of formulas it stops." ++
      "\n\n| Construct | Formulas |\n|---|---:|\n"
    for (k, n) in bl do
      s := s ++ s!"| `{k}` | {n} |\n"
  let bad := results.filter fun r => !r.outcome.ok && r.outcome != .notYet
  if !bad.isEmpty then
    s := s ++ "\n## Mismatched cases\n\n| Case | Kind | Detail |\n|---|---|---|\n"
    for r in bad do
      let d := ((r.detail.replace "|" "\\|").replace "\n" " ").take 100
      s := s ++ s!"| `{r.id.replace "|" "\\|"}` | {r.outcome.name} | {d} |\n"
  let _ := laidOut
  let _ := seconds
  return s

end LayoutTest
