/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import VersoManual
import LeAnTeXManual.Meta

/-!
# The agreement figures, regenerated

`{figureRuns}` is the table of the agreement chapter that puts each figure of the README beside
what LeAnTeX's test driver prints for it in the build that wrote the site.

* **When the page is elaborated**, every figure's wording (`Figure.readme`) must occur in the
  repository's `README.md` as it is then: a changed figure in the README fails the build until
  the row here is changed with it.
* **When the site is written**, the generator runs the test driver, `leantex-test` in the
  repository's root with no arguments (what `lake test` runs), once, and reads its output.
  Besides its sentences the driver prints its totals as typed fields, one per line:
  `figure KEY VALUE` (`parser.match`, `mathbox.builtSame`, `heldout2.lines`, …). Each figure
  names the fields that hold its numbers (`Figure.fields`). A field that needs files the build
  machine does not have (`Field.needs`: the Computer Modern metric files or the Latin Modern
  fonts of a TeX installation, which the driver reports as skipped or missing) is not checked,
  and the row says why. Every other field must be printed exactly once and its value must be
  the expected one, and a field marked `inLine` must also occur as a whole number in the
  driver's sentence the row shows (`Figure.line`, the start of that line), so that `9 of 20` is
  not found in `19 of 20`: a figure the driver no longer prints fails the site's build. A driver
  that fails (a regression against the committed baselines) fails it too.
* **The status label** says how much of the figure this build checked: *Regenerated* when every
  number of the README's wording is the value of a checked field, *Partly regenerated* (naming
  the numbers left unchecked) when some are not, *Not regenerated* when no field could be
  checked.

The driver is run with `LEANTEX_COMMITTED_CORPORA` set, which leaves out a corpus that
`.gitignore` lists (a local file that a clean clone does not have), so the page shows the figures
of a clean clone whether or not the checkout holds one. The driver reads only the committed
corpora and fixtures (KaTeX's, LuaLaTeX's and fontTools'
recorded answers) and, when present, the metric files and fonts of a TeX installation; it runs
neither KaTeX nor TeX.
-/

open Verso Genre Manual Doc Elab ArgParse
open Lean Elab

namespace LeAnTeXManual

/-- What a figure needs beyond the repository. -/
inductive Needs where
  /-- Nothing: the committed fixtures and the library. -/
  | nothing
  /-- The Computer Modern metric files of a TeX installation. -/
  | metricFiles
  /-- The Latin Modern fonts of a TeX installation. -/
  | latinModern
  deriving Repr, BEq, ToJson, FromJson

/-- One number of a figure: the driver's field that prints it and the value it must have. -/
structure Field where
  /-- The field's key (`figure KEY VALUE` in the driver's output). -/
  key : String
  /-- The value, as the driver writes it (no thousands separators). -/
  value : String
  /-- What it needs beyond the repository. -/
  needs : Needs := .nothing
  /-- Whether the value must also occur in the sentence the row shows. -/
  inLine : Bool := true
  deriving Repr, ToJson, FromJson

/-- One figure of the README, the driver's sentence shown beside it and the fields that hold its
numbers. -/
structure Figure where
  /-- The figure as the README words it (must occur in `README.md`). -/
  readme : String
  /-- The start of the driver's sentence shown in the row (after leading spaces). -/
  line : String
  /-- The fields that hold the figure's numbers. -/
  fields : Array Field
  /-- A note shown with the row (how the line relates to the README's wording). -/
  note : String := ""
  deriving Repr, ToJson, FromJson

/-- The figures of the README's table *The figures, and how to reproduce them* that the test
driver prints, in the table's order. -/
def figures : Array Figure := #[
  { readme := "Parser: 11,885 of the 11,885 representable cases (11,886 recorded)",
    line := "parity:",
    fields := #[⟨"parser.match", "11885", .nothing, true⟩,
      ⟨"parser.cases", "11885", .nothing, true⟩, ⟨"parser.recorded", "11886", .nothing, true⟩] },
  { readme := "Layout: 10,855 laid out as KaTeX does, the other 1,030 rejected by both",
    line := "layout:",
    fields := #[⟨"layout.same", "10855", .nothing, true⟩,
      ⟨"layout.bothReject", "1030", .nothing, false⟩],
    note := "Rejected by both: KaTeX's recorded error and LeAnTeX's are the same (class and \
      message), with the same warnings." },
  { readme := "Text: 174 of 174 paragraphs", line := "line breaker:",
    fields := #[⟨"linebreak.same", "174", .nothing, true⟩,
      ⟨"linebreak.cases", "174", .nothing, true⟩,
      ⟨"frontend.ncm.same", "174", .nothing, false⟩,
      ⟨"frontend.lm.same", "174", .latinModern, false⟩],
    note := "The line shown is the line breaker on TeX's own item lists (breaks, demerits, \
      widths, glue). The front end's 174 paragraphs from the source are the fields \
      frontend.ncm.same (New Computer Modern) and frontend.lm.same (Latin Modern, which needs \
      TeX Live's fonts)." },
  { readme := "1,691 of 1,691 words (2,686 hyphenation points)", line := "hyphenation:",
    fields := #[⟨"hyphenation.same", "1691", .nothing, true⟩,
      ⟨"hyphenation.words", "1691", .nothing, true⟩,
      ⟨"hyphenation.points", "2686", .nothing, true⟩] },
  { readme := "72 boxes", line := "boxes:",
    fields := #[⟨"boxes.same", "72", .latinModern, true⟩,
      ⟨"boxes.compared", "72", .latinModern, true⟩],
    note := "Of the 80 recorded boxes; 8 are not compared (the README's last column says why)." },
  { readme := "Formula boxes: 12,166 of 12,750 the same to the sp: 12,162 of the 12,174 the \
      TeX-rule layout builds and 4 of the 576 it refuses",
    line := "formula boxes against TeX",
    fields := #[⟨"mathbox.same", "12166", .metricFiles, true⟩,
      ⟨"mathbox.boxes", "12750", .metricFiles, true⟩,
      ⟨"mathbox.builtSame", "12162", .metricFiles, true⟩,
      ⟨"mathbox.built", "12174", .metricFiles, true⟩,
      ⟨"mathbox.refusedSame", "4", .metricFiles, true⟩,
      ⟨"mathbox.refused", "576", .metricFiles, true⟩] },
  { readme := "87 of 87 reference and regression documents (1,810 of 1,810 lines, 88 of them \
      with a formula and compared by position only), 7 of 10 fresh documents (367 of 398 lines, \
      56 by position only)",
    line := "documents:",
    fields := #[⟨"reference.agree", "87", .metricFiles, false⟩,
      ⟨"reference.docs", "87", .metricFiles, false⟩,
      ⟨"reference.same", "1810", .metricFiles, false⟩,
      ⟨"reference.lines", "1810", .metricFiles, false⟩,
      ⟨"reference.positionOnly", "88", .metricFiles, false⟩,
      ⟨"fresh.agree", "7", .metricFiles, false⟩, ⟨"fresh.docs", "10", .metricFiles, false⟩,
      ⟨"fresh.same", "367", .metricFiles, false⟩, ⟨"fresh.lines", "398", .metricFiles, false⟩,
      ⟨"fresh.positionOnly", "56", .metricFiles, false⟩],
    note := "Both sets were tuned on: this row says nothing about documents the layer was not \
      developed with. The line shown is the driver's total of both sets; the fields hold each \
      set's numbers. `lake exe leantex-test --doc-table` prints a line per document." },
  { readme := "First held-out set: 9 of 20 documents, 398 of 469 lines (163 by position only)",
    line := "held-out documents",
    fields := #[⟨"heldout.agree", "9", .metricFiles, true⟩,
      ⟨"heldout.docs", "20", .metricFiles, true⟩, ⟨"heldout.same", "398", .metricFiles, true⟩,
      ⟨"heldout.lines", "469", .metricFiles, true⟩,
      ⟨"heldout.positionOnly", "163", .metricFiles, true⟩],
    note := "Not an untouched test: the set existed before the TeX-rule layout was developed, \
      four of its fixtures were re-recorded before its first recorded score (8 of 20) and a \
      defect it showed was fixed after it (README)." },
  { readme := "Second held-out set: 5 of 10 documents, 374 of 400 lines (157 by position \
      only), page breaks 10 of 10 (5 by position only)",
    line := "second held-out set",
    fields := #[⟨"heldout2.agree", "5", .metricFiles, true⟩,
      ⟨"heldout2.docs", "10", .metricFiles, true⟩, ⟨"heldout2.same", "374", .metricFiles, true⟩,
      ⟨"heldout2.lines", "400", .metricFiles, true⟩,
      ⟨"heldout2.positionOnly", "157", .metricFiles, true⟩,
      ⟨"heldout2.sameBreaks", "10", .metricFiles, true⟩,
      ⟨"heldout2.breaks", "10", .metricFiles, true⟩,
      ⟨"heldout2.breaksByPosition", "5", .metricFiles, true⟩],
    note := "Written blind after the first set was run and first recorded at 648d738 with these \
      scores; its sources and fixtures have not changed since. Ten short articles." }]

/-- The test driver's output, run once per site generation. -/
initialize driverOutput : IO.Ref (Option (UInt32 × String)) ← IO.mkRef none

/-- Runs the test driver in the repository's root (once) and returns its exit code and output. -/
def runDriver : IO (UInt32 × String) := do
  if let some r ← driverOutput.get then return r
  let root ← IO.FS.realPath (← repoRoot)
  let bin := root / ".lake" / "build" / "bin" / "leantex-test"
  unless ← bin.pathExists do
    throw <| IO.userError s!"{bin} is missing: build the manual with `lake exe leantex-manual`, \
      which builds it first"
  IO.eprintln "leantex-manual: running the test driver for the agreement chapter"
  let env : Array (String × Option String) := #[("LEANTEX_COMMITTED_CORPORA", some "1")]
  let out ← IO.Process.output { cmd := bin.toString, cwd := root, env := env }
  let r := (out.exitCode, out.stdout ++ out.stderr)
  driverOutput.set (some r)
  return r

/-- Whether the driver's output says that a figure's files were missing. -/
def missingIn (out : String) : Needs → Option String
  | .nothing => none
  | .metricFiles =>
    if (out.splitOn "no Computer Modern metric files").length > 1 then
      some "this build had no Computer Modern metric files (the driver skipped or could not \
        complete the comparisons that need them)"
    else none
  | .latinModern =>
    if (out.splitOn "no Latin Modern fonts found").length > 1 ||
        (out.splitOn "0 of 0 TeX boxes").length > 1 then
      some "this build had no Latin Modern fonts (the driver skipped the boxes)"
    else none

/-- Whether `e` occurs in `line` with no digit right before or after it (so that `9 of 20` is
not found in `19 of 20`). -/
def containsNumber (line e : String) : Bool :=
  let parts := line.splitOn e
  (List.range (parts.length - 1)).any fun i =>
    let before := (parts[i]!.toList.getLast?).getD ' '
    let after := (parts[i + 1]!.toList.head?).getD ' '
    !before.isDigit && !after.isDigit

/-- The driver's typed fields (`figure KEY VALUE` lines): each key with its value; an error
when a key is printed twice or a line does not have that shape. -/
def driverFields (out : String) : Except String (Std.HashMap String String) := do
  let mut m : Std.HashMap String String := {}
  for l in out.splitOn "\n" do
    let l := l.trimAscii.toString
    unless l.startsWith "figure " do continue
    let parts := (l.splitOn " ").filter (· ≠ "")
    let (k, v) ← match parts with
      | ["figure", k, v] => pure (k, v)
      | _ => throw s!"the driver's line \"{l}\" is not \"figure KEY VALUE\""
    if m.contains k then throw s!"the driver printed the field {k} twice"
    m := m.insert k v
  return m

/-- The numbers of a figure's wording, without thousands separators (`11,885` is `11885`). -/
def numbersIn (s : String) : List String := Id.run do
  let mut out := #[]
  let mut cur := ""
  for c in (s ++ " ").toList do
    if c.isDigit then cur := cur.push c
    else if c == ',' && !cur.isEmpty then pure ()
    else
      if !cur.isEmpty then out := out.push cur
      cur := ""
  return out.toList.eraseDups

/-- The table's HTML, from the driver's output; an error when a field the build could check is
missing or has another value, or a figure's sentence is missing. -/
def figureTableHtml (figs : Array Figure) (code : UInt32) (out : String) :
    Except String String := do
  if code != 0 then
    throw s!"the test driver failed (exit {code}); its output:\n{out}"
  let fields ← driverFields out
  let lines := (out.splitOn "\n").map (·.trimAscii.toString)
  let mut rows := ""
  for f in figs do
    let some line := lines.find? (·.startsWith f.line)
      | throw s!"the test driver printed no line starting \"{f.line}\" (figure \"{f.readme}\")"
    let mut checked : Array Field := #[]
    let mut skipped : Array String := #[]
    for x in f.fields do
      match missingIn out x.needs with
      | some why => skipped := skipped.push s!"{x.key}: {why}"
      | none =>
        let some v := fields[x.key]?
          | throw s!"the driver printed no field {x.key} (figure \"{f.readme}\")"
        unless v == x.value do
          throw s!"the figure \"{f.readme}\" expects {x.key} = {x.value}; the driver printed {v}"
        if x.inLine && !containsNumber line x.value then
          throw s!"the figure \"{f.readme}\" expects {x.value} in the driver's line, which \
            reads: {line}"
        checked := checked.push x
    let vals := checked.map (·.value)
    let unchecked := (numbersIn f.readme).filter (!vals.contains ·)
    let shown := ", ".intercalate (checked.toList.map fun x =>
      s!"<code>{esc x.key}</code> = <code>{esc x.value}</code>")
    let why := if skipped.isEmpty then "" else
      s!" Not checked: {esc ("; ".intercalate skipped.toList)}."
    let status :=
      if checked.isEmpty then
        s!"<strong>Not regenerated</strong>.{why} The README's figure is the committed record and \
          the figure to rely on; the line is what this build printed without those files."
      else if unchecked.isEmpty then
        s!"<strong>Regenerated</strong> in this build: every number of the figure is a field \
          the driver printed: {shown}.{why}"
      else
        s!"<strong>Partly regenerated</strong> in this build: {shown}; the README's \
          {esc (", ".intercalate unchecked)} not checked by this build.{why}"
    let note := if f.note.isEmpty then "" else s!"<br/>{esc f.note}"
    rows := rows ++ s!"<tr><td>{esc f.readme}</td><td><code class=\"ltx-run\">{esc line}</code>\
      </td><td>{status}{note}</td></tr>"
  return "<div class=\"ltx-table-wrap\"><table class=\"ltx-quote-table\"><thead><tr>\
    <th>The README's figure</th><th>What <code>lake test</code> printed in this build</th>\
    <th>Status</th></tr></thead><tbody>" ++ rows ++ "</tbody></table></div>"

block_extension Block.figureTable (figs : String) where
  data := Json.str figs
  traverse _ _ _ := pure none
  toTeX := some fun _ _ _ _ _ => pure .empty
  toHtml := some fun _ _ _ data _ => do
    let .str s := data | return .empty
    let figs ← match (Json.parse s).bind (fromJson? (α := Array Figure)) with
      | .ok f => pure f
      | .error e => throw <| IO.userError s!"the agreement table's data: {e}"
    let (code, out) ← runDriver
    match figureTableHtml figs code out with
    | .ok h => return .raw h
    | .error e => throw <| IO.userError s!"agreement chapter: {e}"

/-- `{figureRuns}`: the table (see the module docstring). Fails when a figure's wording is not
in the README. -/
@[block_command]
def figureRuns : BlockCommandOf Unit
  | () => do
    let some figSection := sectionLines (← readRepoFile "README.md")
        "The figures, and how to reproduce them"
      | throwError "README.md has no section \"The figures, and how to reproduce them\""
    let readme := "\n".intercalate figSection
    -- the README's table cells may wrap; compare with white space collapsed
    let flat (s : String) : String := Id.run do
      let mut out := ""
      let mut space := false
      for c in s.toList do
        if c.isWhitespace then space := true
        else
          if space && !out.isEmpty then out := out.push ' '
          space := false
          out := out.push c
      return out
    for f in figures do
      unless (flat readme).contains (flat f.readme) do
        throwError "README.md's section on the figures no longer says \"{f.readme}\": change \
          the figure in \
          LeAnTeXManual.AgreementMeta.figures together with the README"
    ``(Block.other (Block.figureTable $(quote (toJson figures).compress)) #[])

end LeAnTeXManual
