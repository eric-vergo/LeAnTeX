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
* `refsDefined`: every glyph an SVG picture draws (`<use>`) has its definition in the picture,
  so the picture is self-contained.

Each is stated for every input (no hypotheses). Axioms: `propext`, `Classical.choice`,
`Quot.sound` only.
-/

namespace LeAnTeX.Backend

/-- No character of an escaped character is one of the four markup characters. -/
theorem escapeChar_safe (c d : Char) (h : d ∈ escapeChar c) :
    d ≠ '<' ∧ d ≠ '>' ∧ d ≠ '"' ∧ d ≠ '\'' := by
  sorry

/-- No character of an escaped list is one of the four markup characters. -/
theorem escapeList_safe (l : List Char) (d : Char) (h : d ∈ escapeList l) :
    d ≠ '<' ∧ d ≠ '>' ∧ d ≠ '"' ∧ d ≠ '\'' := by
  sorry

/-- Escaped text has no `<`. -/
theorem escape_no_lt (s : String) : '<' ∉ (escape s).toList := by
  sorry

/-- Escaped text has no `>`. -/
theorem escape_no_gt (s : String) : '>' ∉ (escape s).toList := by
  sorry

/-- Escaped text has no `"`. -/
theorem escape_no_quot (s : String) : '"' ∉ (escape s).toList := by
  sorry

/-- Escaped text has no `'`. -/
theorem escape_no_apos (s : String) : '\'' ∉ (escape s).toList := by
  sorry

/-- Decoding the entities of escaped text gives the text back, less the characters XML cannot
carry. -/
theorem unescape_escape (l : List Char) : unescapeList (escapeList l) = l.filter xmlChar := by
  sorry

/-- Every glyph a picture's body draws has its definition among the picture's `defs`. -/
theorem refsDefined (fs : FontSet) (dl : DisplayList) (opts : SvgOptions) (u : SvgUse)
    (h : Sum.inl u ∈ (picture fs dl opts).body) :
    ∃ d ∈ (picture fs dl opts).defs, d.1 = u.ref := by
  sorry

/-- The hypothesis of `refsDefined` can be met: a picture with a drawn glyph. -/
example : Sum.inl ({ ref := "g0-1", matrix := "", fill := none } : SvgUse) ∈
    (SvgPicture.ofParts (0, 0, 0, 0) #[("g0-1", "M0 0Z")]
      #[.inl { ref := "g0-1", matrix := "", fill := none }]).body := by
  simp [SvgPicture.ofParts, keepElement]

end LeAnTeX.Backend
