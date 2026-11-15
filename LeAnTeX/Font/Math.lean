/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Font.Binary

/-!
# The `MATH` table's constants

The 56 constants of an OpenType math font's `MathConstants` table (the spacing and positioning
parameters TeX takes from its math fonts' σ and ξ): two percentages, two heights, 51 values
(device corrections ignored) and a final percentage, in font units.

## Main definitions

* `mathConstantNames`: the constants' names, in table order, as the specification spells them.
* `readMathConstants`: the values of a `MATH` table, in the same order.

## References

* The OpenType specification 1.9.1, "MATH — The Mathematical Typesetting Table".
-/

namespace LeAnTeX.Font

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

end LeAnTeX.Font
