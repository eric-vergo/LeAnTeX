/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX
import LeAnTeXTest.Layout
import LeAnTeXTest.Cases
import LeAnTeXTest.DisplayChecks

/-!
# The differential test and the parity report

`lake test` runs this from the repository root. For every case of every corpus
(`corpus/*.jsonl`) it parses the formula with LeAnTeX and compares the result with KaTeX's
recorded answer (`fixtures/*.jsonl`, written by `tools/record.mjs`): the parse tree as JSON, or
the error (class, raw message, position, length), and the strict-mode warnings. It then builds
the parity report over KaTeX's name list (`parity/names.tsv`).

It then lays out every formula and compares the box tree with KaTeX's
(`LeAnTeXTest.Layout`, fixtures in `fixtures/layout/`, report `parity/LAYOUT.md`).

* `lake test` (no arguments): fail if a case that matched in the committed baselines
  (`parity/baseline.tsv`, `parity/layout-baseline.tsv`) no longer matches, or if a corpus or
  fixture is missing.
* `lake exe leantex-test --bench`, `--bench-matrix`: the speed over the corpora, and of a
  10 × 10 matrix.
* `lake exe leantex-test --update`: rewrite the baselines, `parity/REPORT.md`,
  `parity/LAYOUT.md` and `parity/names-status.tsv` from the current results.
* `lake exe leantex-test --show ID-PREFIX`: print the cases whose id starts with the prefix that
  do not match, with both answers.
* `lake exe leantex-test --show-layout ID-PREFIX`: the same for the layout, with the first
  difference of the trees.
-/

open LeAnTeX

/-- How a case compares with KaTeX. -/
inductive Outcome where
  /-- Both accept with the same tree and warnings. -/
  | same
  /-- Both reject with the same error. -/
  | sameError
  /-- Both accept, with different trees. -/
  | treeDiffers
  /-- Both accept with the same tree, but the warnings differ. -/
  | warningsDiffer
  /-- Both reject, with different errors. -/
  | errorDiffers
  /-- KaTeX accepts, LeAnTeX rejects. -/
  | leanRejects
  /-- KaTeX rejects, LeAnTeX accepts. -/
  | leanAccepts
  deriving BEq

/-- The outcome's name in reports. -/
def Outcome.name : Outcome → String
  | .same => "same" | .sameError => "same-error" | .treeDiffers => "tree-differs"
  | .warningsDiffer => "warnings-differ" | .errorDiffers => "error-differs"
  | .leanRejects => "lean-rejects" | .leanAccepts => "lean-accepts"

/-- Whether the outcome is parity. -/
def Outcome.ok (o : Outcome) : Bool := o == .same || o == .sameError

/-- Whether two errors are the same: for a `ParseError` the raw and full message, position and
length; for an error KaTeX raises as a JavaScript `Error` the message; for other classes the
class. -/
def sameError (k l : Json) : Bool :=
  let kind := (k.get? "kind").bind Json.getStr?
  kind == (l.get? "kind").bind Json.getStr? &&
    match kind with
    | some "ParseError" =>
      ["rawMessage", "position", "length", "message"].all fun f =>
        match k.get? f, l.get? f with
        | some a, some b => a.sameAs b
        | none, none => true
        | _, _ => false
    | some "Error" => ((k.get? "message").map fun a =>
        ((l.get? "message").map a.sameAs).getD false).getD false
    | _ => true

/-- LeAnTeX's answer for a case, in the fixture's shape. -/
def leanAnswer (c : Case) : Json :=
  let r := parse c.tex c.settings
  let warnings := Json.arr (r.warnings.map Json.str)
  match r.result with
  | .ok t => .obj #[("tree", nodesToJson t), ("warnings", warnings)]
  | .error e => .obj #[("error", e.toJson), ("warnings", warnings)]

/-- Compare LeAnTeX's answer with KaTeX's. -/
def compare (katex lean : Json) : Outcome :=
  let warnSame := match katex.get? "warnings", lean.get? "warnings" with
    | some a, some b => a.sameAs b
    | _, _ => false
  match katex.get? "tree", katex.get? "error", lean.get? "tree", lean.get? "error" with
  | some kt, _, some lt, _ => if kt.sameAs lt then (if warnSame then .same else .warningsDiffer)
      else .treeDiffers
  | some _, _, none, _ => .leanRejects
  | none, some ke, _, some le => if sameError ke le then .sameError else .errorDiffers
  | _, _, _, _ => .leanAccepts

/-- The result of one case. -/
structure Result where
  /-- The corpus. -/
  corpus : String
  /-- The case. -/
  case : Case
  /-- How it compares. -/
  outcome : Outcome
  /-- KaTeX's answer. -/
  katex : Json
  /-- LeAnTeX's answer. -/
  lean : Json

/-- The corpora: every `corpus/*.jsonl`, sorted. -/
def corpora : IO (Array String) := do
  let entries ← System.FilePath.readDir "corpus"
  let names := entries.filterMap fun e =>
    if e.fileName.endsWith ".jsonl" then some (e.fileName.dropEnd 6).toString else none
  return names.qsort (· < ·)

/-- Run every case of a corpus against its fixture. -/
def runCorpus (name : String) : IO (Array Result) := do
  let cases ← readJsonLines s!"corpus/{name}.jsonl"
  let fixtures ← readJsonLines s!"fixtures/{name}.jsonl"
  let byId : Std.HashMap String Json := Std.HashMap.ofList (fixtures.toList.filterMap fun f =>
    ((f.get? "id").bind Json.getStr?).map (·, f))
  let mut out := #[]
  for j in cases do
    let some id := (j.get? "id").bind Json.getStr? | continue
    let tex := ((j.get? "tex").bind Json.getStr?).getD ""
    let c : Case := { id, tex, settings := caseSettings j }
    let some k := byId[id]? | throw (IO.userError s!"no fixture for {id}; run tools/record.mjs")
    -- a formula with a lone surrogate has no Lean string; the recorder marks it
    if k.get? "unrepresentable" |>.isSome then continue
    let l := leanAnswer c
    out := out.push { corpus := name, case := c, outcome := compare k l, katex := k, lean := l }
  return out

/-- Unescape a field of `parity/names.tsv`. -/
def unescapeTsv (s : String) : String := Id.run do
  let mut out := ""
  let mut esc := false
  for c in s.toList do
    if esc then
      out := out.push (match c with | 't' => '\t' | 'n' => '\n' | c => c)
      esc := false
    else if c == '\\' then esc := true
    else out := out.push c
  return out

/-- The names a formula uses: the texts of its tokens and its environment names. -/
def namesUsed (tex : String) : List String := Id.run do
  let lx := Lexer.ofSource ⟨0, tex⟩
  let mut toks : Array String := #[]
  let mut lx := lx
  for _ in [0:tex.length + 1] do
    match lx.lex .ignore with
    | .ok (t, lx', _) =>
      if t.text == "EOF" then break
      toks := toks.push t.text
      lx := lx'
    | .error _ => break
  let mut envs := #[]
  for i in [0:toks.size] do
    if toks[i]! == "\\begin" && toks[i + 1]? == some "{" then
      let name := (toks.extract (i + 2) toks.size).toList.takeWhile (· != "}")
      envs := envs.push ("env:" ++ String.join name)
  return toks.toList ++ envs.toList

/-- Whether LeAnTeX implements a name of the given kind. -/
def implemented (kind name : String) : Bool :=
  match kind with
  | "function" => match Tables.functions[name]? with
    | some spec => spec.handler == "\\begin" || (functionHandler spec.handler).isSome
    | none => false
  | "environment" => match Tables.environments[name]? with
    | some spec => (environmentHandler spec.handler).isSome
    | none => false
  | "macro" => Tables.builtinStringMacros.contains name || implementedNatives.contains name
  | _ => true

/-- The per-name parity rows (kind, name, status, cases using it, cases differing) and the
counts per kind and status. -/
def nameParity (results : Array Result) :
    IO (Array (String × String × String × Nat × Nat)) := do
  let lines ← IO.FS.lines "parity/names.tsv"
  let mut used : Std.HashMap String (Nat × Nat) := {}
  for r in results do
    for n in (namesUsed r.case.tex).eraseDups do
      let (a, b) := used.getD n (0, 0)
      used := used.insert n (a + 1, if r.outcome.ok then b else b + 1)
  let mut rows := #[]
  for l in lines.toList.drop 2 do
    match l.splitOn "\t" with
    | kind :: name :: _ =>
      let name := unescapeTsv name
      let key := if kind == "environment" then "env:" ++ name else name
      let (n, bad) := used.getD key (0, 0)
      let status :=
        if !implemented kind name then "not yet"
        else if n == 0 && (name.startsWith "\\\\" ||
            (kind == "symbol-text" && name.length > 1 && !name.startsWith "\\")) then
          -- `\\…` names cannot be typed and the text ligatures are not tokens: the parser
          -- reaches them from other commands (`\atop`, `\global`, `{CD}`) or by merging tokens
          "internal"
        else if n == 0 then "untested"
        else if bad == 0 then "parsed identically"
        else "differs"
      rows := rows.push (kind, name, status, n, bad)
    | _ => pure ()
  return rows

/-- The Markdown parity report. -/
def report (results : Array Result) (rows : Array (String × String × String × Nat × Nat)) :
    String := Id.run do
  let mut s := "# Parity report\n\n" ++
    "Generated by `lake exe leantex-test --update`; do not edit by hand. LeAnTeX's parser " ++
    "against KaTeX 0.19.1's `__parse`: the parse tree (as JSON), or for a formula KaTeX " ++
    "rejects the error (class, message, position), and the strict-mode warnings.\n\n" ++
    "## Corpora\n\n| Corpus | Cases | Accepted, same tree | Rejected, same error | " ++
    "Mismatched |\n|---|---:|---:|---:|---:|\n"
  let names := (results.map (·.corpus)).toList.eraseDups
  for c in names do
    let rs := results.filter (·.corpus == c)
    let same := (rs.filter (·.outcome == .same)).size
    let se := (rs.filter (·.outcome == .sameError)).size
    s := s ++ s!"| {c} | {rs.size} | {same} | {se} | {rs.size - same - se} |\n"
  let total := results.size
  let ok := (results.filter (·.outcome.ok)).size
  s := s ++ s!"| all | {total} | {(results.filter (·.outcome == .same)).size} | " ++
    s!"{(results.filter (·.outcome == .sameError)).size} | {total - ok} |\n\n"
  s := s ++ "## Mismatches by kind\n\n| Kind | Cases |\n|---|---:|\n"
  for o in [Outcome.treeDiffers, .warningsDiffer, .errorDiffers, .leanRejects, .leanAccepts] do
    s := s ++ s!"| {o.name} | {(results.filter (·.outcome == o)).size} |\n"
  s := s ++ "\n## KaTeX's names\n\nStatus of every name KaTeX defines (`parity/names.tsv`): " ++
    "*parsed identically* when every corpus case that uses it matches, *differs* when one " ++
    "does not, *internal* for names that cannot be typed (`\\\\atopfrac`, the `{CD}` arrows, " ++
    "the text ligatures `--`, `---`, ` `` `, `''`), which the parser reaches from other " ++
    "commands, " ++
    "*untested* when no case uses it, *not yet* when LeAnTeX has no implementation. " ++
    "Per-name rows: `parity/names-status.tsv`.\n\n| Kind | Names | Parsed identically | " ++
    "Differs | Internal | Untested | Not yet |\n|---|---:|---:|---:|---:|---:|---:|\n"
  for k in ["function", "environment", "macro", "symbol-math", "symbol-text"] do
    let rs := rows.filter (·.1 == k)
    let cnt (st : String) := (rs.filter (·.2.2.1 == st)).size
    s := s ++ s!"| {k} | {rs.size} | {cnt "parsed identically"} | {cnt "differs"} | " ++
      s!"{cnt "internal"} | {cnt "untested"} | {cnt "not yet"} |\n"
  let differ := rows.filter (·.2.2.1 == "differs")
  if !differ.isEmpty then
    s := s ++ "\n### Names that differ\n\n"
    for (k, n, _, u, b) in differ do
      s := s ++ s!"* `{n}` ({k}): {b} of {u} cases\n"
  let notYet := rows.filter (·.2.2.1 == "not yet")
  if !notYet.isEmpty then
    s := s ++ "\n### Not yet implemented\n\n"
    for (k, n, _, _, _) in notYet do
      s := s ++ s!"* `{n}` ({k})\n"
  let bad := results.filter (!·.outcome.ok)
  if !bad.isEmpty then
    s := s ++ "\n## Mismatched cases\n\n| Case | Kind |\n|---|---|\n"
    for r in bad do
      s := s ++ s!"| `{r.case.id.replace "|" "\\|"}` | {r.outcome.name} |\n"
  return s

/-- The baseline: per case, `ok` or `mismatch`. -/
def baselineText (results : Array Result) : String :=
  "# corpus\tcase id\tstatus (written by lake exe leantex-test --update)\n" ++
  String.join (results.toList.map fun r =>
    s!"{r.corpus}\t{r.case.id}\t{if r.outcome.ok then "ok" else "mismatch"}\n")

/-- Lay out every case of every corpus against the layout fixtures, and print the throughput. -/
def runLayout (results : Array Result) : IO (Array LayoutTest.LayoutResult) := do
  let mut out := #[]
  let t0 ← IO.monoNanosNow
  for c in (results.map (·.corpus)).toList.eraseDups do
    let cases := (results.filter (·.corpus == c)).map fun r =>
      (r.case.id, r.case.tex, r.case.settings)
    out := out ++ (← LayoutTest.runLayoutCorpus c cases)
  let t1 ← IO.monoNanosNow
  IO.println s!"layout test: {out.size} cases in {(t1 - t0).toFloat / 1e9} s"
  return out

/-- Lines of a baseline file as (corpus, id, status). -/
def readBaseline (path : System.FilePath) : IO (Array (String × String × String)) := do
  let lines ← IO.FS.lines path
  return lines.toList.drop 1 |>.toArray.filterMap fun l => match l.splitOn "\t" with
    | [c, id, st] => some (c, id, st)
    | _ => none

/-- Parse, lay out and draw an `n × n` matrix of subscripted entries `reps` times, each stage
timed on its own; the times per formula in µs. -/
def benchMatrixOf (n reps : Nat) : IO (Float × Float × Float × Int) := do
  let row (i : Nat) : String :=
    " & ".intercalate ((List.range n).map fun j => s!"a_\{{i + 1}{j + 1}}")
  let matrix := "\\begin{pmatrix}" ++ " \\\\ ".intercalate ((List.range n).map row) ++
    "\\end{pmatrix}"
  -- results feed a checksum, so that no stage is optimised away
  let mut check : Int := 0
  let a ← IO.monoNanosNow
  for _ in [0:reps] do
    match (parse matrix).result with
    | .ok t => check := check + t.size
    | .error _ => check := check - 1
  let b ← IO.monoNanosNow
  let mut box : Box := {}
  for _ in [0:reps] do
    match (layout matrix).result with
    | .ok bx =>
      check := check + bx.height.raw
      box := bx
    | .error _ => check := check - 1
  let c ← IO.monoNanosNow
  for _ in [0:reps] do
    check := check + (DisplayList.ofBox box).items.size
  let d ← IO.monoNanosNow
  let us (ns : Nat) : Float := ns.toFloat / reps.toFloat / 1e3
  return (us (b - a), us (c - b), us (d - c), check)

/-- The worst case of the performance budget, a 10 × 10 matrix, with 5 × 5 and 20 × 20 to show
how the time grows. -/
def benchMatrix : IO Unit := do
  for (n, reps) in [(5, 2000), (10, 500), (20, 100)] do
    let (p, l, d, check) ← benchMatrixOf n reps
    IO.println s!"{n} × {n} matrix: parse {p} µs, parse + layout {l} µs, display list {d} µs \
      (checksum {check})"

/-- Run everything; see the module docstring for the modes. -/
def main (args : List String) : IO UInt32 := do
  if args == ["--bench-matrix"] then
    benchMatrix
    return 0
  let mut results := #[]
  for c in ← corpora do
    results := results ++ (← runCorpus c)
  match args with
  | ["--bench"] =>
    -- parse and layout, and the display list, of every formula KaTeX lays out, several times
    let cases := results.filter (·.case.tex.length > 0)
    let rounds := 5
    let mut n := 0
    -- results feed a checksum, so that no layout is optimised away
    let mut check : Int := 0
    let mut longest : Nat × String := (0, "")
    let t0 ← IO.monoNanosNow
    for _ in [0:rounds] do
      for r in cases do
        n := n + 1
        match (layout r.case.tex r.case.settings).result with
        | .ok b => check := check + b.height.raw
        | .error _ => check := check + 1
    let t1 ← IO.monoNanosNow
    let mut m := 0
    for _ in [0:rounds] do
      for r in cases do
        match (layout r.case.tex r.case.settings).result with
        | .ok b => m := m + (DisplayList.ofBox b).items.size
        | .error _ => pure ()
    let t2 ← IO.monoNanosNow
    -- the slowest single formula laid out
    for r in cases do
      let a ← IO.monoNanosNow
      for _ in [0:20] do
        match (layout r.case.tex r.case.settings).result with
        | .ok b => check := check + b.depth.raw
        | .error _ => check := check - 1
      let b ← IO.monoNanosNow
      if (b - a) / 20 > longest.1 then longest := ((b - a) / 20, r.case.id)
    let perSec (k : Nat) (ns : Nat) : Float := k.toFloat / (ns.toFloat / 1e9)
    for c in (cases.map (·.corpus)).toList.eraseDups do
      let cs := cases.filter (·.corpus == c)
      let a ← IO.monoNanosNow
      for _ in [0:rounds] do
        for r in cs do
          match (layout r.case.tex r.case.settings).result with
          | .ok b => check := check + (DisplayList.ofBox b).width.raw
          | .error _ => check := check + 1
      let b ← IO.monoNanosNow
      for _ in [0:rounds] do
        for r in cs do
          match (parse r.case.tex r.case.settings).result with
          | .ok t => check := check + t.size
          | .error _ => check := check + 1
      let e ← IO.monoNanosNow
      IO.println s!"  {c}: {cs.size} formulas, {perSec (rounds * cs.size) (b - a)} formulas/s \
        (parse, layout, display list); parse alone {perSec (rounds * cs.size) (e - b)}/s"
    IO.println s!"parse + layout: {n} formulas in {(t1 - t0).toFloat / 1e9} s, \
      {perSec n (t1 - t0)} formulas/s"
    IO.println s!"parse + layout + display list: {perSec n (t2 - t1)} formulas/s ({m} items)"
    IO.println s!"slowest formula: {longest.1.toFloat / 1e3} µs ({longest.2}); checksum {check}"
    benchMatrix
    return 0
  | ["--worst-layout"] =>
    let lres ← runLayout results
    let sorted := (lres.filter (·.outcome == .same)).qsort (·.deviation.raw > ·.deviation.raw)
    for r in sorted.extract 0 10 do
      IO.println s!"{r.deviation.raw} {r.deviation.css} {r.id}: {r.tex.take 80}"
    return 0
  | ["--show-layout", pre] =>
    let lres ← runLayout (results.filter (·.case.id.startsWith pre))
    for r in lres do
      if !r.outcome.ok && r.outcome != .notYet then
        IO.println s!"== {r.id} [{r.outcome.name}]\ntex: {r.tex}\n{r.detail}"
        IO.println s!"katex: {r.katex.compress}"
        IO.println s!"lean:  {r.lean.compress}"
    return 0
  | ["--show", pre] =>
    for r in results do
      if r.case.id.startsWith pre && !r.outcome.ok then
        IO.println s!"== {r.case.id} [{r.outcome.name}]\ntex: {r.case.tex}"
        IO.println s!"katex: {r.katex.compress}"
        IO.println s!"lean:  {r.lean.compress}"
    return 0
  | ["--update"] =>
    let rows ← nameParity results
    IO.FS.writeFile "parity/REPORT.md" (report results rows)
    IO.FS.writeFile "parity/baseline.tsv" (baselineText results)
    IO.FS.writeFile "parity/names-status.tsv" ("# kind\tname\tstatus\tcases\tcases differing\n" ++
      String.join (rows.toList.map fun (k, n, st, u, b) => s!"{k}\t{n}\t{st}\t{u}\t{b}\n"))
    let ok := (results.filter (·.outcome.ok)).size
    IO.println s!"parity: {ok} of {results.size} cases match; report written"
    let lres ← runLayout results
    IO.FS.writeFile "parity/LAYOUT.md" (LayoutTest.layoutReport lres 0)
    IO.FS.writeFile "parity/layout-baseline.tsv" (LayoutTest.layoutBaselineText lres)
    let same := (lres.filter (·.outcome == .same)).size
    IO.println s!"layout: {same} of {lres.size} cases laid out as KaTeX does; report written"
    return 0
  | [] =>
    let baseline ← IO.FS.lines "parity/baseline.tsv"
    let now : Std.HashMap String Bool := Std.HashMap.ofList (results.toList.map fun r =>
      (r.corpus ++ "\t" ++ r.case.id, r.outcome.ok))
    let mut regressions := #[]
    let mut improved := 0
    for l in baseline.toList.drop 1 do
      match l.splitOn "\t" with
      | [c, id, st] =>
        -- a corpus that is not in this checkout (one kept out of the repository) is skipped
        if !(← System.FilePath.pathExists s!"corpus/{c}.jsonl") then continue
        match now[c ++ "\t" ++ id]? with
        | some true => if st == "mismatch" then improved := improved + 1
        | some false => if st == "ok" then regressions := regressions.push s!"{c}: {id}"
        | none => if st == "ok" then regressions := regressions.push s!"{c}: {id} (missing)"
      | _ => pure ()
    let ok := (results.filter (·.outcome.ok)).size
    IO.println s!"parity: {ok} of {results.size} cases match KaTeX"
    -- the layout baseline: a case laid out identically must stay so
    let lres ← runLayout results
    let lnow : Std.HashMap String String := Std.HashMap.ofList (lres.toList.map fun r =>
      (r.corpus ++ "\t" ++ r.id, if r.outcome.ok then "ok" else if r.outcome == .notYet then
        "not-yet" else "mismatch"))
    let lpath : System.FilePath := "parity/layout-baseline.tsv"
    if ← lpath.pathExists then
      for (c, id, st) in ← readBaseline lpath do
        if !(← System.FilePath.pathExists s!"corpus/{c}.jsonl") then continue
        let now := lnow[c ++ "\t" ++ id]?
        if st == "ok" && now != some "ok" then
          regressions := regressions.push s!"layout {c}: {id} ({now.getD "missing"})"
        else if st != "ok" && now == some "ok" then improved := improved + 1
    else regressions := regressions.push "parity/layout-baseline.tsv is missing"
    let lsame := (lres.filter (·.outcome == .same)).size
    IO.println s!"layout: {lsame} of {lres.size} cases laid out as KaTeX does"
    -- the display-list checks
    let failed := DisplayChecks.displayChecks.filter (!·.2)
    for (name, _) in failed do regressions := regressions.push s!"display list: {name}"
    IO.println s!"display list: {DisplayChecks.displayChecks.size - failed.size} of \
      {DisplayChecks.displayChecks.size} checks hold"
    if improved > 0 then
      IO.println s!"{improved} cases match that the baseline lists as mismatched; record them \
        with `lake exe leantex-test --update`"
    if regressions.isEmpty then
      IO.println "no regression against parity/baseline.tsv and parity/layout-baseline.tsv"
      return 0
    IO.eprintln s!"{regressions.size} regressions against parity/baseline.tsv and \
      parity/layout-baseline.tsv:"
    for r in regressions do IO.eprintln s!"  {r}"
    return 1
  | _ =>
    IO.eprintln "usage: leantex-test [--update | --show ID-PREFIX | --show-layout ID-PREFIX]"
    return 2
