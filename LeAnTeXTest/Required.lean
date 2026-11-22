/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import Std.Data.HashSet

/-!
# The files the comparisons need

`parity/required.txt` lists every corpus and fixture file the comparisons read: the formula
corpora and their parser and layout fixtures, the documents of every set with their fixtures,
the formula-box fixtures and the baselines. It is written by hand, when a corpus or a document
is added or removed, and no `--update` option writes it, so a file that goes missing, or one
that comes or goes unrecorded, fails `lake test` instead of making a comparison smaller.

The check: every listed file exists and is not empty, no file is listed twice, and every file
of the compared directories (`corpus/*.jsonl`, `fixtures/*.jsonl`, `fixtures/layout/*.jsonl`,
`corpus/doc*/*.tex`, `fixtures/doc*/*.json`, `fixtures/math-box/*.jsonl`) is listed, but for the
local corpora that `.gitignore` lists (`corpus/NAME.jsonl` and their fixtures).
-/

namespace LeAnTeXTest.Required

/-- The list's path. -/
def listPath : System.FilePath := "parity/required.txt"

/-- The directories whose files must all be listed, with the extension of the compared files. -/
def compared : List (String × String) :=
  [("corpus", ".jsonl"), ("fixtures", ".jsonl"), ("fixtures/layout", ".jsonl"),
   ("corpus/doc", ".tex"), ("corpus/doc-heldout", ".tex"), ("corpus/doc-heldout-2", ".tex"),
   ("fixtures/doc", ".json"), ("fixtures/doc-heldout", ".json"),
   ("fixtures/doc-heldout-2", ".json"), ("fixtures/math-box", ".jsonl")]

/-- The local corpora `.gitignore` names (`corpus/NAME.jsonl`): their files need no line. -/
def localCorpora : IO (Array String) := do
  let some lines := (← IO.FS.lines ".gitignore" |>.toBaseIO).toOption | return #[]
  return lines.filterMap fun l =>
    let l := l.trimAscii.toString
    if l.startsWith "corpus/" && l.endsWith ".jsonl" then
      some ((l.drop 7).dropEnd 6).toString
    else none

/-- The listed paths, or why the list does not read. -/
def listed : IO (Except String (Array String)) := do
  if !(← listPath.pathExists) then return .error s!"{listPath} is missing"
  let lines := ((← IO.FS.readFile listPath).splitOn "\n").map (·.trimAscii.toString)
  return .ok (lines.filter fun l => !l.isEmpty && !l.startsWith "#").toArray

/-- The failures of the check (see the module docstring). -/
def check : IO (Array String) := do
  let paths ← match ← listed with
    | .ok p => pure p
    | .error e => return #[e]
  let mut fails := #[]
  let mut seen : Std.HashSet String := {}
  for p in paths do
    if seen.contains p then fails := fails.push s!"{listPath}: {p} listed twice"
    seen := seen.insert p
    let fp : System.FilePath := p
    if !(← fp.pathExists) then fails := fails.push s!"{p} is missing"
    else if (← fp.metadata).byteSize == 0 then fails := fails.push s!"{p} is empty"
  let skip ← localCorpora
  for (dir, ext) in compared do
    let d : System.FilePath := dir
    if !(← d.pathExists) then continue
    for e in ← d.readDir do
      if !e.fileName.endsWith ext then continue
      let base := (e.fileName.dropEnd ext.length).toString
      let formulaDir := dir == "corpus" || dir == "fixtures" || dir == "fixtures/layout"
      if formulaDir && skip.contains base then continue
      let p := s!"{dir}/{e.fileName}"
      if !seen.contains p then fails := fails.push s!"{p} is not in {listPath}"
  return fails

end LeAnTeXTest.Required
