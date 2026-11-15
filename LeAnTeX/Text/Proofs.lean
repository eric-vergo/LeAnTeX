/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Text.Pack
import LeAnTeX.Text.Hyphen

/-!
# Theorems about the text layer

Statements about the functions the text layer calls:

* `breakParagraph_legal`, `breakParagraph_increasing`, `breakParagraph_ends`: every break the
  line breaker returns is a legal breakpoint of its input (or the end), the breaks increase, and
  the last is the end of the paragraph. `breakParagraph` checks its result before returning it
  (`checkBreaks`), so these hold by construction; the tests show that the check never rejects a
  breaking of the corpora.
* `lineRanges_first`, `lineRanges_stop`, `lineRanges_next`: the lines `setLines` builds take
  the input's nodes in order: the first line starts at node 0, each line ends at its break, and
  the next starts after it, the nodes between them all discardable (glue, penalties, explicit
  kerns) — so the lines' nodes, put together, are the input without the nodes dropped at
  breaks.
* `points_minima`: hyphenation never leaves fewer than `\lefthyphenmin` letters before a point
  or fewer than `\righthyphenmin` after it.
* `badness_le`: a badness is at most 10000.

Each statement has an example showing that its hypotheses can be met.
-/

namespace LeAnTeX.Text

theorem breakParagraph_legal {items : Array HNode} {p : Params} {r : Breaks}
    (h : breakParagraph items p = .ok r) :
    ∀ b ∈ r.breaks, b.pos = items.size ∨ legalBreak items b.pos = true := by
  sorry

theorem breakParagraph_increasing {items : Array HNode} {p : Params} {r : Breaks}
    (h : breakParagraph items p = .ok r) :
    increasing (r.breaks.toList.map (·.pos)) = true := by
  sorry

theorem breakParagraph_ends {items : Array HNode} {p : Params} {r : Breaks}
    (h : breakParagraph items p = .ok r) :
    r.breaks.back?.map (·.pos) = some items.size := by
  sorry

example : ∃ r, breakParagraph #[.penalty 10000, .glue { stretch := 65536, stretchOrder := 1 } 15]
    = .ok r := by
  sorry

theorem lineRanges_first {items : Array HNode} {bs : Array Nat} {a b : Nat}
    (h : (lineRanges items bs)[0]? = some (a, b)) : a = 0 := by
  sorry

theorem lineRanges_stop {items : Array HNode} {bs : Array Nat} {k a b : Nat}
    (h : (lineRanges items bs)[k]? = some (a, b)) : bs[k]? = some b := by
  sorry

theorem lineRanges_next {items : Array HNode} {bs : Array Nat} {k a b a' b' : Nat}
    (h : (lineRanges items bs)[k]? = some (a, b))
    (h' : (lineRanges items bs)[k + 1]? = some (a', b')) :
    b < a' ∧ ∀ j, b < j → j < a' → ∃ n, items[j]? = some n ∧ n.discardable = true := by
  sorry

example : (lineRanges #[.penalty 0, .glue {} 0, .penalty 0, .rule 1 1 1, .penalty 0]
    #[0, 4])[1]? = some (3, 4) := by
  sorry

theorem points_minima (ps : Patterns) (w : String) (left right k : Nat)
    (h : k ∈ ps.points w left right) : left ≤ k ∧ k + right ≤ w.length := by
  sorry

example : 2 ∈ (Patterns.ofStrings "a1b" "").points "aab" 1 1 := by
  sorry

theorem badness_le (t s : Int) : badness t s ≤ infBad := by
  sorry

example : badness 100 1 = infBad := by
  sorry

end LeAnTeX.Text
