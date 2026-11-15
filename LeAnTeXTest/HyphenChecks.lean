/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Text.Hyphen
import LeAnTeXTest.Font

/-!
# Hyphenation against TeX

Every word of `fixtures/text/words.jsonl` hyphenated by `Patterns.english` (TeX's language 0)
under the fixture's
hyphen minima must be TeX's hyphenation of it, point for point.
-/

namespace HyphenChecks

open LeAnTeX LeAnTeX.Text FontTest

/-- Runs the comparison; prints a summary, returns the words that differ. -/
def run : IO (Array String) := do
  let fixture ← readJsonLines "fixtures/text/words.jsonl"
  let hdr := ((fixture[0]?).bind (·.get? "meta")).getD .null
  let left := (((hdr.get? "lefthyphenmin").bind jint?).getD 2).toNat
  let right := (((hdr.get? "righthyphenmin").bind jint?).getD 3).toNat
  let ps := Patterns.english
  let mut fails := #[]
  let mut n := 0
  let mut points := 0
  for r in fixture do
    let some w := (r.get? "word").bind Json.getStr? | continue
    let tex := ((r.get? "hyphenated").bind Json.getStr?).getD ""
    n := n + 1
    points := points + (tex.toList.filter (· == '-')).length
    let ours := ps.hyphenate w left right
    if ours != tex then fails := fails.push s!"hyphenation of {w}: {ours}; TeX's {tex}"
  IO.println s!"  hyphenation: {n - fails.size} of {n} words hyphenated as TeX does \
    ({points} points)"
  return fails

end HyphenChecks
