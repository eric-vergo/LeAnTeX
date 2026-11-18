/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Doc.Front
import LeAnTeX.Doc.Graphics

/-!
# Theorems about the document layer

About the functions the document layer calls:

* `buildPages_boxes`: the sizes (width, height, depth) of the boxes on the pages the page
  builder returns are, in order, the sizes of the boxes of the vertical list it was given, so
  the number of boxes and their sizes in order are kept (boxes of equal size are not told
  apart, so the theorem does not say which box is which; glue, kerns and penalties may be
  discarded at breaks, `\topskip` glue added; the boxes of floats set here and the material of
  insertions are not in the count). The builder makes this comparison before returning
  (`pagesPartition`), so the theorem holds by construction; where the pages are cut (TeX's algorithm) is tested against
  LuaLaTeX, not proved.
* `Counters.add_value`, `Counters.set_value`, `Counters.newCounter_value`: setting and adding
  to a counter change its value as specified; a new counter starts at zero.
* `lookupRef_some`, `lookupRef_none`: a reference that resolves gives the text (or the page)
  the table of labels holds for its key, and one that does not has no entry there (the front
  end, which passes the labels of the previous pass, then reports the key and prints `??`).
* `safeImagePath_relative`, `safeImagePath_noParent`: a path that passes `safeImagePath` (the
  check the document layer makes before it asks for an image) does not start with `/` and has
  no `..` segment.
* `romanLower_nonpos`: `\roman` prints nothing for zero or less, as TeX's `\romannumeral`.
-/

namespace LeAnTeX.Doc

open LeAnTeX.Text

/-- When `buildPages` returns pages, they pass `pagesPartition`: their boxes' sizes, in order,
are those of the list's boxes (see the module docstring). -/
theorem buildPages_boxes (items : Array VNode) (p : PageParams) (pages : Array PageOut)
    (h : buildPages items p = .ok pages) : pagesPartition items pages = true := by
  unfold buildPages at h
  split at h
  · split at h
    · rename_i hc
      cases h
      exact hc
    · cases h
  · cases h

/-- The hypothesis of `buildPages_boxes` can be met: two boxes with a penalty between them, on
pages with room for one, come back as two pages. -/
example : (match buildPages #[.hbox 10 20 5 0 #[] {}, .penalty 0, .hbox 10 20 5 0 #[] {}]
      { vsize := 30, maxDepth := 5, topSkip := {}, maxSteps := 100 } with
    | .ok pages => pages.size == 2 | .error _ => false) = true := by
  decide +kernel

/-- Adding to a defined counter adds to its value. -/
theorem Counters.add_value (cs : Counters) (n : String) (v : Int) (c : Counter)
    (h : cs.table.get? n = some c) : (cs.add n v).value n = c.value + v := by
  simp [Counters.add, Counters.value, Std.HashMap.get?_eq_getElem?] at h ⊢
  simp [h]

/-- Setting a defined counter sets its value. -/
theorem Counters.set_value (cs : Counters) (n : String) (v : Int) (c : Counter)
    (h : cs.table.get? n = some c) : (cs.set n v).value n = v := by
  simp [Counters.set, Counters.value, Std.HashMap.get?_eq_getElem?] at h ⊢
  simp [h]

/-- A new counter (not within another) starts at zero. -/
theorem Counters.newCounter_value (cs : Counters) (n : String) :
    (cs.newCounter n none).value n = 0 := by
  simp [Counters.newCounter, Counters.value, Std.HashMap.get?_eq_getElem?]

/-- A reference that resolves gives the label's text (or page). -/
theorem lookupRef_some (refs : Std.HashMap String (String × String)) (key : String)
    (page : Bool) (s : String) (h : lookupRef refs key page = some s) :
    ∃ t p, refs[key]? = some (t, p) ∧ s = if page then p else t := by
  unfold lookupRef at h
  cases hk : refs[key]? with
  | none => simp [hk] at h
  | some v =>
    obtain ⟨t, p⟩ := v
    simp [hk] at h
    exact ⟨t, p, rfl, h.symm⟩

/-- A reference that does not resolve has no label of its key. -/
theorem lookupRef_none (refs : Std.HashMap String (String × String)) (key : String)
    (page : Bool) (h : lookupRef refs key page = none) : refs[key]? = none := by
  unfold lookupRef at h
  cases hk : refs[key]? with
  | none => rfl
  | some v => simp [hk] at h

/-- A path that passes `safeImagePath` does not start with `/`. -/
theorem safeImagePath_relative (p : String) (h : Typeset.safeImagePath p = true) :
    p.startsWith "/" = false := by
  unfold Typeset.safeImagePath at h
  simp only [Bool.and_eq_true, Bool.not_eq_true'] at h
  exact h.1.1.2

/-- A path that passes `safeImagePath` has no `..` segment. -/
theorem safeImagePath_noParent (p : String) (h : Typeset.safeImagePath p = true) :
    ∀ seg ∈ p.splitOn "/", seg ≠ ".." := by
  unfold Typeset.safeImagePath at h
  simp only [Bool.and_eq_true, Bool.not_eq_true', List.any_eq_false] at h
  intro seg hs heq
  have := h.2 seg hs
  simp [heq] at this

/-- `\roman` of zero or less prints nothing. -/
theorem romanLower_nonpos (n : Int) (h : n ≤ 0) : romanLower n = "" := by
  unfold romanLower
  simp [h]

/-- The hypotheses of `Counters.add_value` and `Counters.set_value` can be met: a new counter
is defined. -/
example : ∃ c, (Counters.newCounter {} "section" none).table.get? "section" = some c :=
  ⟨{}, by simp [Counters.newCounter, Std.HashMap.get?_eq_getElem?]⟩

end LeAnTeX.Doc
