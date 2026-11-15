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

/-- The condition `checkBreaks` tests holds of every result of `breakParagraph`. -/
theorem breakParagraph_checked {items : Array HNode} {p : Params} {r : Breaks}
    (h : breakParagraph items p = .ok r) :
    (r.breaks.all (fun b => b.pos == items.size || legalBreak items b.pos) &&
      increasing (r.breaks.toList.map (·.pos)) &&
      (r.breaks.back?.map (·.pos)) == some items.size) = true := by
  unfold breakParagraph at h
  cases hc : breakParagraphCore items p with
  | error e => rw [hc] at h; cases h
  | ok r0 =>
    rw [hc] at h
    simp only [Except.bind] at h
    unfold checkBreaks at h
    split at h
    · next hcond => cases h; exact hcond
    · cases h

/-- Every break the line breaker returns is a legal breakpoint of its input or its end. -/
theorem breakParagraph_legal {items : Array HNode} {p : Params} {r : Breaks}
    (h : breakParagraph items p = .ok r) :
    ∀ b ∈ r.breaks, b.pos = items.size ∨ legalBreak items b.pos = true := by
  have := breakParagraph_checked h
  simp only [Bool.and_eq_true] at this
  intro b hb
  have := Array.all_eq_true_iff_forall_mem.mp this.1.1 b hb
  simpa using this

/-- The breaks the line breaker returns increase. -/
theorem breakParagraph_increasing {items : Array HNode} {p : Params} {r : Breaks}
    (h : breakParagraph items p = .ok r) :
    increasing (r.breaks.toList.map (·.pos)) = true := by
  have := breakParagraph_checked h
  simp only [Bool.and_eq_true] at this
  exact this.1.2

/-- The last break the line breaker returns is the end of the paragraph. -/
theorem breakParagraph_ends {items : Array HNode} {p : Params} {r : Breaks}
    (h : breakParagraph items p = .ok r) :
    r.breaks.back?.map (·.pos) = some items.size := by
  have := breakParagraph_checked h
  simp only [Bool.and_eq_true] at this
  simpa using this.2

/-- No hyphenation point is within `left` letters of a word's start or `right` of its end. -/
theorem points_minima (ps : Patterns) (w : String) (left right k : Nat)
    (h : k ∈ ps.points w left right) : left ≤ k ∧ k + right ≤ w.length := by
  unfold Patterns.points at h
  have := (Array.mem_filter.mp h).2
  simpa [Bool.and_eq_true, decide_eq_true_eq] using this

example : 2 ∈ ({ exceptions := (({} : Std.HashMap String (Array Nat)).insert "aab" #[2]) } :
    Patterns).points "aab" 1 1 := by
  unfold Patterns.points
  have : "aab".toLower = "aab" := by decide +kernel
  simp only [this, Std.HashMap.getElem?_insert_self]
  decide +kernel

example : badness 100 1 = infBad := by decide

/-- A cube is at most `1290³` when its root is at most 1290. -/
theorem cube_le (r : Int) (h : r ≤ 1290) : r * r * r ≤ 1290 * 1290 * 1290 := by
  by_cases h0 : 0 ≤ r
  · have h1 : r * r ≤ 1290 * 1290 := Int.mul_le_mul h h h0 (by decide)
    exact Int.mul_le_mul h1 h h0 (by decide)
  · have hr : r < 0 := Int.lt_of_not_ge h0
    have h2 : 0 ≤ r * r :=
      Int.mul_nonneg_of_nonpos_of_nonpos (Int.le_of_lt hr) (Int.le_of_lt hr)
    have h3 : r * r * r ≤ 0 := Int.mul_nonpos_of_nonneg_of_nonpos h2 (Int.le_of_lt hr)
    exact Int.le_trans h3 (by decide)

/-- A badness is at most `infBad` (10000). -/
theorem badness_le (t s : Int) : badness t s ≤ infBad := by
  unfold badness
  split
  · decide
  split
  · exact Int.le_refl _
  generalize (if t ≤ 7230584 then t * 297 / s else if s ≥ 1663497 then t / (s / 297) else t) = r
  dsimp only
  split
  · exact Int.le_refl _
  · rename_i hr
    have hr : r ≤ 1290 := Int.not_lt.mp hr
    have := Int.ediv_le_ediv (c := 0x40000) (by decide)
      (Int.add_le_add_right (cube_le r hr) 0x20000)
    exact Int.le_trans this (by decide)

example : (match breakParagraph
      #[.penalty 10000, .glue { stretch := 65536, stretchOrder := 1 } 15] with
    | .ok _ => true | .error _ => false) = true := by decide +kernel

/-- Pruning never moves back. -/
theorem pruneGo_ge (items : Array HNode) (stop : Nat) :
    ∀ fuel k, k ≤ pruneGo items stop fuel k := by
  intro fuel
  induction fuel with
  | zero => intro k; simp [pruneGo]
  | succ n ih =>
    intro k
    unfold pruneGo
    split
    · exact Nat.le_refl _
    · split
      · split
        · exact Nat.le_trans (Nat.le_succ k) (ih (k + 1))
        · exact Nat.le_refl _
      · exact Nat.le_refl _

/-- Every node pruning passes over is discardable. -/
theorem pruneGo_dropped (items : Array HNode) (stop : Nat) :
    ∀ fuel k j, k ≤ j → j < pruneGo items stop fuel k →
      ∃ n, items[j]? = some n ∧ n.discardable = true := by
  intro fuel
  induction fuel with
  | zero => intro k j h1 h2; simp [pruneGo] at h2; omega
  | succ m ih =>
    intro k j h1 h2
    unfold pruneGo at h2
    split at h2
    · omega
    · split at h2
      · rename_i n hn
        split at h2
        · rename_i hd
          by_cases hjk : j = k
          · subst hjk; exact ⟨n, hn, hd⟩
          · exact ih (k + 1) j (by omega) h2
        · omega
      · omega

/-- The line after a break starts after it. -/
theorem nextStart_gt (items : Array HNode) (b next : Nat) : b < nextStart items b next := by
  unfold nextStart pruneFrom
  split
  · split
    · exact Nat.lt_of_lt_of_le (Nat.lt_succ_self b) (pruneGo_ge _ _ _ _)
    · exact Nat.lt_succ_self b
  all_goals first
    | exact Nat.lt_of_lt_of_le (Nat.lt_succ_self b) (pruneGo_ge _ _ _ _)
    | exact Nat.lt_succ_self b

/-- The nodes between a break and the next line's start are discardable. -/
theorem nextStart_dropped (items : Array HNode) (b next j : Nat) (h1 : b < j)
    (h2 : j < nextStart items b next) : ∃ n, items[j]? = some n ∧ n.discardable = true := by
  unfold nextStart pruneFrom at h2
  split at h2
  · split at h2
    · exact pruneGo_dropped _ _ _ _ _ h1 h2
    · omega
  all_goals first
    | exact pruneGo_dropped _ _ _ _ _ h1 h2
    | omega

/-- The first line starts at the first node. -/
theorem lineRanges_first {items : Array HNode} {bs : Array Nat} {a b : Nat}
    (h : (lineRanges items bs)[0]? = some (a, b)) : a = 0 := by
  unfold lineRanges at h
  rw [Array.getElem?_ofFn] at h
  split at h
  · simp at h; omega
  · cases h

/-- Each line ends at its break. -/
theorem lineRanges_stop {items : Array HNode} {bs : Array Nat} {k a b : Nat}
    (h : (lineRanges items bs)[k]? = some (a, b)) : bs[k]? = some b := by
  unfold lineRanges at h
  rw [Array.getElem?_ofFn] at h
  split at h
  · rename_i hk
    simp only [Option.some.injEq, Prod.mk.injEq, Fin.getElem_fin] at h
    rw [Array.getElem?_eq_getElem hk, h.2]
  · cases h

/-- The next line starts after a line's break, and every node between them is discardable:
the lines' nodes together are the input without the nodes dropped at breaks. -/
theorem lineRanges_next {items : Array HNode} {bs : Array Nat} {k a b a' b' : Nat}
    (h : (lineRanges items bs)[k]? = some (a, b))
    (h' : (lineRanges items bs)[k + 1]? = some (a', b')) :
    b < a' ∧ ∀ j, b < j → j < a' → ∃ n, items[j]? = some n ∧ n.discardable = true := by
  have hb := lineRanges_stop h
  unfold lineRanges at h'
  rw [Array.getElem?_ofFn] at h'
  split at h'
  · simp only [Option.some.injEq, Prod.mk.injEq, Fin.getElem_fin] at h'
    have ha : a' = nextStart items b bs[k + 1] := by rw [← h'.1, hb]; rfl
    subst ha
    exact ⟨nextStart_gt _ _ _, fun j h1 h2 => nextStart_dropped _ _ _ j h1 h2⟩
  · cases h'

example : (lineRanges #[.penalty 0, .glue {} 0, .penalty 0, .rule 1 1 1, .penalty 0]
    #[0, 4])[1]? = some (3, 4) := by decide

end LeAnTeX.Text
