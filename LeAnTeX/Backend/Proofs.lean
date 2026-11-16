/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Backend.Svg

/-!
# Theorems about the back ends

About the functions the back ends call:

* `escape_no_lt`, `escape_no_gt`, `escape_no_quot`, `escape_no_apos`: escaped text (all text
  and attribute values from TeX source in the SVG and HTML output) contains no `<`, `>`, `"` or
  `'`, so it can neither open markup nor close an attribute value.
* `unescape_escape`: decoding the five entities gives the input back, less the characters XML
  cannot carry; so every `&` the escaping writes starts one of its entities, and the text a
  reader sees is the source text.
* `exists_def_of_mem_picture_body`: every glyph an SVG picture draws (`<use>`) has its definition
  in the picture, so the picture is self-contained. It holds by construction: `picture` ends with
  `SvgPicture.ofParts`, which keeps a use only if its definition is there. What that filter
  removes is not hidden from the reader: a character no font has, and a glyph whose outline cannot
  be read, are given the missing-glyph box (`notdefPath`) with its definition before the filter,
  so the only uses it drops are of glyphs with an empty outline (spaces), which draw nothing
  anyway.

Each is stated for every input (no hypotheses). Axioms: `propext`, `Classical.choice`,
`Quot.sound` only.
-/

namespace LeAnTeX.Backend

/-- No character of an escaped character is one of the four markup characters. -/
theorem escapeChar_safe (c d : Char) (h : d ∈ escapeChar c) :
    d ≠ '<' ∧ d ≠ '>' ∧ d ≠ '"' ∧ d ≠ '\'' := by
  unfold escapeChar at h
  split at h <;> (refine ⟨?_, ?_, ?_, ?_⟩ <;> rintro rfl <;> (try split at h) <;> simp at h)
  all_goals (subst h; simp_all)

/-- Decoding a character other than `&` keeps it and goes on. -/
theorem unescapeList_cons (c : Char) (r : List Char) (h : c ≠ '&') :
    unescapeList (c :: r) = c :: unescapeList r := by
  rw [unescapeList.eq_def]
  split <;> simp_all

/-- No character of an escaped list is one of the four markup characters. -/
theorem escapeList_safe (l : List Char) (d : Char) (h : d ∈ escapeList l) :
    d ≠ '<' ∧ d ≠ '>' ∧ d ≠ '"' ∧ d ≠ '\'' := by
  induction l with
  | nil => simp [escapeList] at h
  | cons c cs ih =>
    simp only [escapeList, List.mem_append] at h
    rcases h with h | h
    · exact escapeChar_safe c d h
    · exact ih h

/-- Escaped text has no `<`. -/
theorem escape_no_lt (s : String) : '<' ∉ (escape s).toList := by
  intro h
  simp only [escape, String.toList_ofList] at h
  exact (escapeList_safe _ _ h).1 rfl

/-- Escaped text has no `>`. -/
theorem escape_no_gt (s : String) : '>' ∉ (escape s).toList := by
  intro h
  simp only [escape, String.toList_ofList] at h
  exact (escapeList_safe _ _ h).2.1 rfl

/-- Escaped text has no `"`. -/
theorem escape_no_quot (s : String) : '"' ∉ (escape s).toList := by
  intro h
  simp only [escape, String.toList_ofList] at h
  exact (escapeList_safe _ _ h).2.2.1 rfl

/-- Escaped text has no `'`. -/
theorem escape_no_apos (s : String) : '\'' ∉ (escape s).toList := by
  intro h
  simp only [escape, String.toList_ofList] at h
  exact (escapeList_safe _ _ h).2.2.2 rfl

/-- Decoding the entities of escaped text gives the text back, less the characters XML cannot
carry. -/
theorem unescape_escape (l : List Char) : unescapeList (escapeList l) = l.filter xmlChar := by
  induction l with
  | nil => simp [escapeList, unescapeList]
  | cons c cs ih =>
    by_cases hlt : c = '<'
    · subst hlt; simp [escapeList, escapeChar, unescapeList, ih, xmlChar]
    by_cases hgt : c = '>'
    · subst hgt; simp [escapeList, escapeChar, unescapeList, ih, xmlChar]
    by_cases hamp : c = '&'
    · subst hamp; simp [escapeList, escapeChar, unescapeList, ih, xmlChar]
    by_cases hq : c = '"'
    · subst hq; simp [escapeList, escapeChar, unescapeList, ih, xmlChar]
    by_cases ha : c = '\''
    · subst ha; simp [escapeList, escapeChar, unescapeList, ih, xmlChar]
    have hc : escapeChar c = if xmlChar c then [c] else [] := by
      unfold escapeChar; split <;> simp_all
    by_cases hx : xmlChar c
    · simp only [escapeList, hc, hx, ite_true, List.filter_cons_of_pos hx,
        List.singleton_append, unescapeList_cons c _ hamp, ih]
    · simp only [escapeList, hc, hx, List.filter_cons_of_neg hx]
      exact ih

/-- Every glyph a picture's body draws has its definition among the picture's `defs`. -/
theorem exists_def_of_mem_picture_body (fs : FontSet) (dl : DisplayList) (opts : SvgOptions)
    (u : SvgUse) (h : Sum.inl u ∈ (picture fs dl opts).body) :
    ∃ d ∈ (picture fs dl opts).defs, d.1 = u.ref := by
  unfold picture at h ⊢
  generalize pictureParts fs dl opts = parts at h ⊢
  obtain ⟨box, defs, body⟩ := parts
  simp only [SvgPicture.ofParts, Array.mem_filter, keepElement] at h ⊢
  obtain ⟨-, hk⟩ := h
  obtain ⟨d, hd, hdu⟩ := Array.mem_map.mp (Array.contains_iff_mem.mp hk)
  exact ⟨d, hd, hdu⟩

/-- The hypothesis of `exists_def_of_mem_picture_body` can be met: a picture with a drawn glyph
(stated for `SvgPicture.ofParts`, the last step of `picture`; `picture` itself reads fonts and
cannot be evaluated by the kernel). -/
example : Sum.inl ({ ref := "g0-1", matrix := "", fill := none } : SvgUse) ∈
    (SvgPicture.ofParts (0, 0, 0, 0) #[("g0-1", "M0 0Z")]
      #[.inl { ref := "g0-1", matrix := "", fill := none }]).body := by
  simp [SvgPicture.ofParts, keepElement]

/-- The former name of `exists_def_of_mem_picture_body`. -/
@[deprecated exists_def_of_mem_picture_body (since := "2026-11-16")]
theorem refsDefined (fs : FontSet) (dl : DisplayList) (opts : SvgOptions) (u : SvgUse)
    (h : Sum.inl u ∈ (picture fs dl opts).body) :
    ∃ d ∈ (picture fs dl opts).defs, d.1 = u.ref :=
  exists_def_of_mem_picture_body fs dl opts u h

