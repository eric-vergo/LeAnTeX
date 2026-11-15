/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.OpenType.Binary
import LeAnTeX.OpenType.Layout

/-!
# The `MATH` table's constants and size variants

The 56 constants of an OpenType math font's `MathConstants` table (the spacing and positioning
parameters TeX takes from its math fonts' σ and ξ): two percentages, two heights, 51 values
(device corrections ignored) and a final percentage, in font units. And the `MathVariants`
table's size variants: for a glyph, the larger glyphs of the same symbol (a bigger parenthesis,
the display-style sum), each with its size along the axis it grows in. Glyph assemblies (the
pieces an extensible delimiter is built from) are not read.

## Main definitions

* `mathConstantNames`: the constants' names, in table order, as the specification spells them.
* `readMathConstants`: the values of a `MATH` table, in the same order.
* `MathVariants`, `readMathVariants`: the size variants.

## References

* The OpenType specification 1.9.1, "MATH — The Mathematical Typesetting Table".
-/

namespace LeAnTeX.OpenType

/-- The names of the `MathConstants` fields, in table order. -/
def mathConstantNames : Array String := #[
  "scriptPercentScaleDown", "scriptScriptPercentScaleDown", "delimitedSubFormulaMinHeight",
  "displayOperatorMinHeight", "mathLeading", "axisHeight", "accentBaseHeight",
  "flattenedAccentBaseHeight", "subscriptShiftDown", "subscriptTopMax",
  "subscriptBaselineDropMin", "superscriptShiftUp", "superscriptShiftUpCramped",
  "superscriptBottomMin", "superscriptBaselineDropMax", "subSuperscriptGapMin",
  "superscriptBottomMaxWithSubscript", "spaceAfterScript", "upperLimitGapMin",
  "upperLimitBaselineRiseMin", "lowerLimitGapMin", "lowerLimitBaselineDropMin",
  "stackTopShiftUp", "stackTopDisplayStyleShiftUp", "stackBottomShiftDown",
  "stackBottomDisplayStyleShiftDown", "stackGapMin", "stackDisplayStyleGapMin",
  "stretchStackTopShiftUp", "stretchStackBottomShiftDown", "stretchStackGapAboveMin",
  "stretchStackGapBelowMin", "fractionNumeratorShiftUp", "fractionNumeratorDisplayStyleShiftUp",
  "fractionDenominatorShiftDown", "fractionDenominatorDisplayStyleShiftDown",
  "fractionNumeratorGapMin", "fractionNumDisplayStyleGapMin", "fractionRuleThickness",
  "fractionDenominatorGapMin", "fractionDenomDisplayStyleGapMin", "skewedFractionHorizontalGap",
  "skewedFractionVerticalGap", "overbarVerticalGap", "overbarRuleThickness",
  "overbarExtraAscender", "underbarVerticalGap", "underbarRuleThickness",
  "underbarExtraDescender", "radicalVerticalGap", "radicalDisplayStyleVerticalGap",
  "radicalRuleThickness", "radicalExtraAscender", "radicalKernBeforeDegree",
  "radicalKernAfterDegree", "radicalDegreeBottomRaisePercent"]

/-- The values of the `MathConstants` table of a `MATH` table, in the order of
`mathConstantNames`. -/
def readMathConstants (s : Slice) : Result (Array Int) := do
  let major ← s.u16 0
  unless major == 1 do s.fail s!"MATH major version {major}"
  let c ← s.drop (← s.u16 4)
  c.need 0 214
  let mut out := #[← c.i16 0, ← c.i16 2, (← c.u16 4 : Int), (← c.u16 6 : Int)]
  for k in [0:51] do out := out.push (← c.i16 (8 + 4 * k))
  return out.push (← c.i16 212)

/-- The glyphs a coverage table covers, in coverage-index order; at most `limit` of them. -/
def Coverage.glyphs (c : Coverage) (limit : Nat) : Array Nat :=
  match c with
  | .list gs => gs.extract 0 limit
  | .ranges rs => Id.run do
    let mut out := #[]
    for (st, e, _) in rs do
      for g in [st:e + 1] do
        if out.size ≥ limit then return out
        out := out.push g
    return out

/-- The size variants of a math font: for a glyph, its variants as `(glyph, size)` in font
units (height plus depth for vertical variants, width for horizontal ones), smallest first, as
the table lists them; the first is usually the glyph itself. -/
structure MathVariants where
  /-- Vertical variants by glyph. -/
  vertical : Std.HashMap Nat (Array (Nat × Nat)) := {}
  /-- Horizontal variants by glyph. -/
  horizontal : Std.HashMap Nat (Array (Nat × Nat)) := {}
  deriving Inhabited

/-- The variants of one `MathGlyphConstruction` table: its `MathGlyphVariantRecord`s. -/
private def readConstruction (s : Slice) : Result (Array (Nat × Nat)) := do
  let n ← s.u16 2
  s.need 4 (4 * n)
  let mut out := Array.mkEmpty n
  for i in [0:n] do out := out.push (← s.u16 (4 + 4 * i), ← s.u16 (6 + 4 * i))
  return out

/-- The size variants of a `MATH` table (none if it has no `MathVariants`). The glyph counts are
bounded by the coverage tables and the variant counts by the table's size. -/
def readMathVariants (s : Slice) : Result MathVariants := do
  let off ← s.u16 8
  if off == 0 then return {}
  let v ← s.drop off
  let vertCount ← v.u16 6
  let horizCount ← v.u16 8
  v.need 10 (2 * (vertCount + horizCount))
  let side := fun (covOff count first : Nat) => do
    if covOff == 0 || count == 0 then return ({} : Std.HashMap Nat (Array (Nat × Nat)))
    let cov ← Coverage.read (← v.drop covOff)
    let glyphs := cov.glyphs count
    let mut m : Std.HashMap Nat (Array (Nat × Nat)) := {}
    for h : i in [0:glyphs.size] do
      let co ← v.u16 (first + 2 * i)
      if co == 0 then continue
      m := m.insert glyphs[i] (← readConstruction (← v.drop co))
    return m
  let vertical ← side (← v.u16 2) vertCount 10
  let horizontal ← side (← v.u16 4) horizCount (10 + 2 * vertCount)
  return { vertical, horizontal }

end LeAnTeX.OpenType
