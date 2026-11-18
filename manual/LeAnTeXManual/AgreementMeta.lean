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
  repository's root with no arguments (what `lake test` runs), once, and reads its output. For
  each figure it finds the line the driver prints (`Figure.line`, the start of the line) and
  shows it. If the figure needs files the build machine does not have (`Figure.needs`: the
  Computer Modern metric files or the Latin Modern fonts of a TeX installation, which the
  driver reports as skipped or missing), the row says that it was not regenerated and why, and
  the README's figure is the committed record. Otherwise every expected number
  (`Figure.expect`) must occur in the line: a figure the driver no longer prints fails the
  site's build. A driver that fails (a regression against the committed baselines) fails it
  too.

The driver reads only the committed corpora and fixtures (KaTeX's, LuaLaTeX's and fontTools'
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

/-- One figure of the README and the driver's line that prints it. -/
structure Figure where
  /-- The figure as the README words it (must occur in `README.md`). -/
  readme : String
  /-- The start of the driver's line that prints it (after leading spaces). -/
  line : String
  /-- The numbers the line must contain, as the driver writes them (no thousands separators). -/
  expect : Array String
  /-- What it needs beyond the repository. -/
  needs : Needs
  /-- A note shown with the row (how the line relates to the README's wording). -/
  note : String := ""
  deriving Repr, ToJson, FromJson

/-- The figures of the README's table *The figures, and how to reproduce them* that the test
driver prints, in the table's order. -/
def figures : Array Figure := #[
  { readme := "Parser: 11,885 of 11,885 cases", line := "parity:",
    expect := #["11885 of 11885"], needs := .nothing },
  { readme := "Layout: 10,855 laid out as KaTeX does, the other 1,030 rejected by both",
    line := "layout:", expect := #["10855 of 11885"], needs := .nothing,
    note := "1,030 is 11,885 minus 10,855; that these are cases both KaTeX and LeAnTeX reject \
      is shown by the parser's line (all 11,885 cases match, errors included) and by \
      parity/LAYOUT.md, not by a number of this line." },
  { readme := "Text: 174 of 174 paragraphs", line := "line breaker:",
    expect := #["174 of 174"], needs := .nothing,
    note := "This line is the line breaker on TeX's own item lists (breaks, demerits, widths, \
      glue). The front end's 174 paragraphs from the source (horizontal lists, lines, boxes) are \
      the driver's lines starting \"front end\", not shown here; with Latin Modern absent the \
      Latin Modern one is skipped." },
  { readme := "1,691 of 1,691 words (2,686 hyphenation points)", line := "hyphenation:",
    expect := #["1691 of 1691", "2686 points"], needs := .nothing },
  { readme := "72 boxes", line := "boxes:", expect := #["72 of 72"], needs := .latinModern,
    note := "Of the 80 recorded boxes; 8 are not compared (the README's last column says why)." },
  { readme := "Formula boxes: 12,166 of 12,750 the same to the sp: 12,162 of the 12,174 the \
      TeX-rule layout builds and 4 of the 576 it refuses",
    line := "formula boxes against TeX", expect := #["12166 of 12750", "12162 of the 12174",
      "4 of the 576"], needs := .metricFiles },
  { readme := "87 of 87 reference and regression documents (1,810 of 1,810 lines), 7 of 10 \
      fresh documents (367 of 398 lines)",
    line := "documents:", expect := #["94 of 97", "2177 of 2208"], needs := .metricFiles,
    note := "Both sets were tuned on: this row says nothing about documents the layer was not \
      developed with. `lake test` prints the two sets only as a total (87 + 7 = 94 of 97 \
      documents, 1,810 + 367 = 2,177 of 2,208 lines); this build checks the total, not the \
      split between the sets, which is the README's and parity/DOC.md's. \
      `lake exe leantex-test --doc-table` prints a line per document." },
  { readme := "First held-out set: 9 of 20 documents, 398 of 469 lines",
    line := "held-out documents", expect := #["9 of 20", "398 of 469"], needs := .metricFiles,
    note := "Not a blind result: a defect the set showed was fixed and four fixtures were \
      re-recorded afterwards; the blind run gave 8 of 20 and 397 lines (README)." },
  { readme := "Second held-out set: 5 of 10 documents, 374 of 400 lines, page breaks 10 of 10",
    line := "second held-out set", expect := #["5 of 10", "374 of 400", "page breaks 10 of 10"],
    needs := .metricFiles,
    note := "Written blind after the first set was run, run once, never tuned to; ten short \
      articles." }]

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
  let out ← IO.Process.output { cmd := bin.toString, cwd := root }
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

/-- The table's HTML, from the driver's output; an error when a figure the build could
regenerate is not in its line. -/
def figureTableHtml (figs : Array Figure) (code : UInt32) (out : String) : Except String String := do
  if code != 0 then
    throw s!"the test driver failed (exit {code}); its output:\n{out}"
  let lines := (out.splitOn "\n").map (·.trimAscii.toString)
  let mut rows := ""
  for f in figs do
    let line? := lines.find? (·.startsWith f.line)
    let some line := line?
      | throw s!"the test driver printed no line starting \"{f.line}\" (figure \"{f.readme}\")"
    let status ← match missingIn out f.needs with
      | some why => pure s!"<strong>Not regenerated</strong>: {esc why}. The README's figure is \
          the committed record and the figure to rely on; the line is what this build printed \
          without those files."
      | none =>
        for e in f.expect do
          unless containsNumber line e do
            throw s!"the figure \"{f.readme}\" expects \"{e}\" in the driver's line, which \
              reads: {line}"
        pure s!"<strong>Regenerated</strong> in this build: the line contains \
          {", ".intercalate (f.expect.toList.map fun e => s!"<code>{esc e}</code>")}."
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
    | .ok h => return .text false h
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
        throwError "README.md's section on the figures no longer says \"{f.readme}\": change the figure in \
          LeAnTeXManual.AgreementMeta.figures together with the README"
    ``(Block.other (Block.figureTable $(quote (toJson figures).compress)) #[])

end LeAnTeXManual
