/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.TeXMath.MList

/-!
# Properties of the TeX-rule layout

Theorems about the functions the layout runs.

* The style transitions form the lattice *The TeXbook* (Chapter 17) gives: a subscript's and a
  denominator's style is cramped, a cramped style's superscript is cramped, `cramped` is
  idempotent, scripts are never larger than their nucleus, the subscript and superscript of a
  style are set at the same size, and the scripts of a script style are scriptscript.
* The inter-atom spacing is total over the classes and gives no space but the unconditional
  thin one in script styles; there is never a space after an opening or before a closing atom
  in the table, and every entry is one of the five codes.
* `hpack` contains its children: its width is the sum of theirs, its height and depth are at
  least each child's.
-/

namespace LeAnTeX.TeXMath

namespace Style

/-- A subscript's style is cramped. -/
theorem sub_isCramped (s : Style) : s.sub.isCramped = true := by
  rcases s with ⟨c⟩; revert c; decide

/-- A denominator's style is cramped. -/
theorem denom_isCramped (s : Style) : s.denom.isCramped = true := by
  rcases s with ⟨c⟩; revert c; decide

/-- The superscript of a cramped style is cramped. -/
theorem sup_isCramped_of (s : Style) (h : s.isCramped = true) : s.sup.isCramped = true := by
  rcases s with ⟨c⟩; revert c h; decide

/-- `cramped` is idempotent. -/
theorem cramped_cramped (s : Style) : s.cramped.cramped = s.cramped := by
  rcases s with ⟨c⟩; revert c; decide

/-- A script is never set at a larger size than its nucleus. -/
theorem size_le_sub (s : Style) : s.size ≤ s.sub.size := by
  rcases s with ⟨c⟩; revert c; decide

/-- Subscript and superscript of a style are set at the same size. -/
theorem sub_size_eq_sup_size (s : Style) : s.sub.size = s.sup.size := by
  rcases s with ⟨c⟩; revert c; decide

/-- The scripts of a script or scriptscript style are scriptscript. -/
theorem sub_of_script (s : Style) (h : 4 ≤ s.code.val) : s.sub.size = 2 := by
  rcases s with ⟨c⟩; revert c h; decide

/-- A numerator is never set at a larger size than its fraction. -/
theorem size_le_num (s : Style) : s.size ≤ s.num.size := by
  rcases s with ⟨c⟩; revert c; decide

end Style

/-- Every entry of the spacing table is one of its five codes, for every pair of classes. -/
theorem spacingTable_total (l r : Fin 8) : (spacingTable l r).val ≤ 4 := by
  revert l r; decide

/-- No space follows an opening atom. -/
theorem spacingTable_after_open (r : Fin 8) : spacingTable 4 r = 0 := by
  revert r; decide

/-- In script and scriptscript style the only inter-atom space is the unconditional thin one
(`2` in the table, between an operator and an ordinary atom or another operator, and before an
operator). -/
theorem interAtomGlue_script (p : Params) (l r : Fin 8) (s : Style) (mu : Int)
    (h : s.isLarge = false) :
    interAtomGlue p l r s mu = none ∨ spacingTable l r = 2 := by
  unfold interAtomGlue
  generalize spacingTable l r = k
  rcases k with ⟨k, hk⟩
  match k, hk with
  | 0, _ => exact .inl rfl
  | 1, _ => exact .inl (by simp [h])
  | 2, _ => exact .inr rfl
  | 3, _ => exact .inl (by simp [h])
  | 4, _ => exact .inl (by simp [h])

/-- `hpack`'s width at natural size is the sum of its children's. -/
theorem hpack_width (l : Array Node) :
    (hpack l).width = l.foldl (init := 0) fun a n => a + n.width := by
  simp [hpack, Node.width]

/-- A natural `hpack` is at least as high as each child. -/
theorem le_hpack_height (l : Array Node) (n : Node) (h : n ∈ l) :
    n.height ≤ (hpack l).boxHeight := by
  simp only [hpack, Node.boxHeight]
  have key : ∀ (xs : List Node) (a : Int), n ∈ xs →
      n.height ≤ xs.foldl (fun a m => max a m.height) a := by
    intro xs
    induction xs with
    | nil => intro _ h; simp at h
    | cons x xs ih =>
      intro a hm
      simp only [List.foldl_cons]
      rcases List.mem_cons.mp hm with rfl | hm
      · have : ∀ (ys : List Node) (b : Int), b ≤ ys.foldl (fun a m => max a m.height) b := by
          intro ys
          induction ys with
          | nil => intro b; simp
          | cons y ys ih2 =>
            intro b; simp only [List.foldl_cons]; exact Int.le_trans (by omega) (ih2 _)
        exact Int.le_trans (by omega) (this xs _)
      · exact ih _ hm
  rw [← Array.foldl_toList]
  exact key l.toList 0 (Array.mem_toList_iff.mpr h)

/-- A natural `hpack` is at least as deep as each child. -/
theorem le_hpack_depth (l : Array Node) (n : Node) (h : n ∈ l) :
    n.depth ≤ (hpack l).boxDepth := by
  simp only [hpack, Node.boxDepth]
  have key : ∀ (xs : List Node) (a : Int), n ∈ xs →
      n.depth ≤ xs.foldl (fun a m => max a m.depth) a := by
    intro xs
    induction xs with
    | nil => intro _ h; simp at h
    | cons x xs ih =>
      intro a hm
      simp only [List.foldl_cons]
      rcases List.mem_cons.mp hm with rfl | hm
      · have : ∀ (ys : List Node) (b : Int), b ≤ ys.foldl (fun a m => max a m.depth) b := by
          intro ys
          induction ys with
          | nil => intro b; simp
          | cons y ys ih2 =>
            intro b; simp only [List.foldl_cons]; exact Int.le_trans (by omega) (ih2 _)
        exact Int.le_trans (by omega) (this xs _)
      · exact ih _ hm
  rw [← Array.foldl_toList]
  exact key l.toList 0 (Array.mem_toList_iff.mpr h)

/-- The hypotheses of `le_hpack_height` can be met: a character in a list. -/
example : (Node.char 0 0 1 2 3) ∈ #[Node.char 0 0 1 2 3] := by simp

end LeAnTeX.TeXMath
