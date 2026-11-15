/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Json
import LeAnTeXTest.Cases
import LeAnTeXTest.Font

/-!
# Checks of the text-mode reference fixtures

`fixtures/text/*.jsonl` hold real TeX's answers for the corpora in `corpus/text/` (recorded by
`tools/tex-reference.sh`): the reference the line breaker and the hyphenator are tested against.
These checks keep the fixtures coherent with their corpora and with themselves:

* every corpus case has its answer, in the same order;
* a paragraph's line breaks ascend, each at an item TeX can break at (glue, a discretionary, a
  penalty or a kern), the last at the end of the list, every line `\hsize` wide;
* a word's hyphenated form is the word with hyphens inserted;
* a box's width is the sum of its items' widths (glue at its natural width, a discretionary by
  its unbroken text).
-/

namespace TextFixtures

open LeAnTeX FontTest

/-- The width of TeX items: glyphs, kerns, glue (natural), boxes, discretionaries unbroken. -/
partial def itemsWidth (items : Array Json) : Int :=
  items.foldl (init := 0) fun acc it =>
    acc + match (jat it 0).getStr? with
      | some "g" => (jint? (jat it 3)).getD 0
      | some "k" | some "glue" | some "box" | some "rule" => (jint? (jat it 1)).getD 0
      | some "d" => itemsWidth ((jat it 4).getArr?.getD #[])
      | _ => 0

/-- The failures of one corpus's fixture. -/
def checkCorpus (name : String) : IO (Nat × Array String) := do
  let corpus ← readJsonLines s!"corpus/text/{name}.jsonl"
  let fixture ← readJsonLines s!"fixtures/text/{name}.jsonl"
  let mut fails := #[]
  if corpus.size != fixture.size then
    fails := fails.push s!"{name}: {corpus.size} cases, {fixture.size} answers"
  for (c, r) in corpus.zip fixture do
    let id := ((c.get? "id").bind Json.getStr?).getD "?"
    if (r.get? "id").bind Json.getStr? != some id then
      fails := fails.push s!"{name}: answer for {id} out of order"; continue
    match (c.get? "kind").bind Json.getStr? with
    | some "paragraph" =>
      let items := ((r.get? "items").bind Json.getArr?).getD #[]
      let lines := ((r.get? "lines").bind Json.getArr?).getD #[]
      let hsize := ((r.get? "params").bind (·.get? "hsize")).bind jint?
      let breaks := lines.map fun l => ((l.get? "break").bind jint?).getD (-1)
      let ascending := (List.range breaks.size).all fun i =>
        i == 0 || (breaks[i - 1]?.getD 0) < (breaks[i]?.getD 0)
      let kinds := breaks.all fun b => b ≥ 0 && match (jat (items[b.toNat]?.getD .null) 0).getStr?
        with | some "glue" | some "d" | some "p" | some "k" => true | _ => false
      let last := breaks.back? == some ((items.size : Int) - 1)
      let shaped := (c.get? "hangindent").isSome || (c.get? "parshape").isSome
      let widths := lines.all fun l => shaped || (l.get? "width").bind jint? == hsize
      if lines.isEmpty || !ascending || !kinds || !last || !widths then
        fails := fails.push s!"{id}: line breaks incoherent"
    | some "word" =>
      let w := ((c.get? "word").bind Json.getStr?).getD ""
      let h := ((r.get? "hyphenated").bind Json.getStr?).getD ""
      if !w.contains '-' && String.ofList (h.toList.filter (· != '-')) != w then
        fails := fails.push s!"{id}: {h} is not {w} hyphenated"
    | some "hbox" =>
      let items := ((r.get? "items").bind Json.getArr?).getD #[]
      if (r.get? "width").bind jint? != some (itemsWidth items) then
        fails := fails.push s!"{id}: width is not the sum of the items"
    | k => fails := fails.push s!"{id}: unknown kind {k}"
  return (corpus.size, fails)

/-- Runs the checks over the three text corpora; prints a summary, returns the failures. -/
def run : IO (Array String) := do
  let mut fails := #[]
  for name in ["paragraphs", "words", "boxes"] do
    let (n, fs) ← checkCorpus name
    IO.println s!"  text fixture {name}: {n - fs.size} of {n} cases coherent"
    fails := fails ++ fs
  return fails

end TextFixtures
