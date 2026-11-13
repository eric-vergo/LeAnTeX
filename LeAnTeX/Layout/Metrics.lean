/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import Std.Data.HashMap
import LeAnTeX.Layout.Em
import LeAnTeX.Spec
import LeAnTeX.Data.FontMetrics
import LeAnTeX.Data.FontParams
import LeAnTeX.Parse.Tables

/-!
# Font metrics

The metrics of KaTeX's glyphs and TeX's font parameters, looked up as KaTeX does.

## Main definitions

* `CharMetrics`: a glyph's depth, height, italic correction, skew and width.
* `CharMetrics.exactFloat`: a table value as the double KaTeX computes with.
* `charMetrics`: KaTeX's `getCharacterMetrics`.
* `FontParams`, `fontParams`: TeX's σ and ξ parameters for a size (KaTeX's `getGlobalMetrics`).

## Implementation notes

KaTeX keys its metrics by the first UTF-16 code unit of a character, so a character outside the
Basic Multilingual Plane is looked up by its high surrogate (and has no metrics); `utf16First`
gives that unit.

## References

* KaTeX's `src/fontMetrics.ts` (MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

open Std

/-- The metrics of one glyph, in em of its font size. `exact` keeps the table's values
(depth, height, italic, skew, width in 1e-5 em), for the few places where the layout must
reproduce a decision KaTeX takes on its floating-point value. -/
structure CharMetrics where
  /-- Depth below the baseline. -/
  depth : Em
  /-- Height above the baseline. -/
  height : Em
  /-- Italic correction. -/
  italic : Em
  /-- Skew (for accent placement). -/
  skew : Em
  /-- Advance width. -/
  width : Em
  /-- The table's values in 1e-5 em: depth, height, italic, skew, width. -/
  exact : Array Int := #[]
  deriving Inhabited, BEq, Repr

/-- A table value (`0` depth, `1` height, `2` italic, `3` skew, `4` width) as the double
JavaScript reads from KaTeX's table. -/
def CharMetrics.exactFloat (m : CharMetrics) (i : Nat) : Float :=
  Float.ofInt (m.exact[i]?.getD 0) / 100000

namespace Metrics

/-- Every font's glyph table, by font name and UTF-16 code unit. -/
def table : HashMap String (HashMap Nat CharMetrics) := Id.run do
  let mut out := {}
  for (font, flat) in Data.fontMetricTables do
    let mut m : HashMap Nat CharMetrics := {}
    for i in [0:flat.size / 6] do
      let g := fun k => Em.ofRatio flat[6 * i + k]! 100000
      m := m.insert flat[6 * i]!.toNat
        ⟨g 1, g 2, g 3, g 4, g 5, (flat.extract (6 * i + 1) (6 * i + 6))⟩
    out := out.insert font m
  return out

/-- Characters measured with the metrics of a look-alike, by code point. -/
def extraCharacters : HashMap Nat Nat := HashMap.ofList Data.extraCharacterList.toList

end Metrics

/-- The first UTF-16 code unit of a character (JavaScript's `charCodeAt(0)`). -/
def utf16First (c : Char) : Nat :=
  if c.val < 0x10000 then c.val.toNat else 0xD800 + ((c.val.toNat - 0x10000) >>> 10)

/-- The first UTF-16 code unit of a string, or `none` for the empty string. -/
def utf16FirstOf (s : String) : Option Nat := s.toList.head?.map utf16First

/-- Whether metrics exist for the font name (KaTeX throws for an unknown font). -/
def hasFontMetrics (font : String) : Bool := Metrics.table.contains font

/-- KaTeX's `getCharacterMetrics`: the metrics of the first character of `character` in `font`,
or of its look-alike, or, in text mode, of `M` for a character of a supported script. Assumes
`hasFontMetrics font`. -/
def charMetrics (character : String) (font : String) (mode : Mode) : Option CharMetrics := do
  let tbl ← Metrics.table[font]?
  let some c := character.toList.head? | none
  let ch := utf16First c
  match tbl[ch]? with
  | some m => some m
  | none =>
    let viaExtra := (Metrics.extraCharacters[c.val.toNat]?).bind (tbl[·]?)
    match viaExtra with
    | some m => some m
    | none =>
      if mode == .text && Tables.supportedCodepoint ch then tbl[77]? else none

/-- TeX's font parameters σ and ξ at one size class, in em of that size (KaTeX's
`getGlobalMetrics`); field names are KaTeX's. -/
structure FontParams where
  /-- σ1. -/
  slant : Em
  /-- σ5. -/
  xHeight : Em
  /-- σ6. -/
  quad : Em
  /-- σ8. -/
  num1 : Em
  /-- σ9. -/
  num2 : Em
  /-- σ10. -/
  num3 : Em
  /-- σ11. -/
  denom1 : Em
  /-- σ12. -/
  denom2 : Em
  /-- σ13. -/
  sup1 : Em
  /-- σ14. -/
  sup2 : Em
  /-- σ15. -/
  sup3 : Em
  /-- σ16. -/
  sub1 : Em
  /-- σ17. -/
  sub2 : Em
  /-- σ18. -/
  supDrop : Em
  /-- σ19. -/
  subDrop : Em
  /-- σ20. -/
  delim1 : Em
  /-- σ21. -/
  delim2 : Em
  /-- σ22. -/
  axisHeight : Em
  /-- ξ8. -/
  defaultRuleThickness : Em
  /-- ξ9. -/
  bigOpSpacing1 : Em
  /-- ξ10. -/
  bigOpSpacing2 : Em
  /-- ξ11. -/
  bigOpSpacing3 : Em
  /-- ξ12. -/
  bigOpSpacing4 : Em
  /-- ξ13. -/
  bigOpSpacing5 : Em
  /-- The rule thickness of `\sqrt`. -/
  sqrtRuleThickness : Em
  /-- Points per em (10). -/
  ptPerEm : Em
  /-- The gap between double rules. -/
  doubleRuleSep : Em
  /-- The thickness of array rules. -/
  arrayRuleWidth : Em
  /-- `\fboxsep`. -/
  fboxsep : Em
  /-- `\fboxrule`. -/
  fboxrule : Em
  /-- One mu: a quad / 18. -/
  cssEmPerMu : Em
  deriving Inhabited, Repr

namespace Metrics

/-- The parameters of size class `i` (0 text, 1 script, 2 scriptscript). -/
def paramsAt (i : Nat) : FontParams :=
  let get (key : String) : Em :=
    match Data.fontParamList.find? (·.1 == key) with
    | some (_, a, b, c) => Em.ofRatio (if i == 0 then a else if i == 1 then b else c) 100000
    | none => 0
  { slant := get "slant", xHeight := get "xHeight", quad := get "quad", num1 := get "num1",
    num2 := get "num2", num3 := get "num3", denom1 := get "denom1", denom2 := get "denom2",
    sup1 := get "sup1", sup2 := get "sup2", sup3 := get "sup3", sub1 := get "sub1",
    sub2 := get "sub2", supDrop := get "supDrop", subDrop := get "subDrop",
    delim1 := get "delim1", delim2 := get "delim2", axisHeight := get "axisHeight",
    defaultRuleThickness := get "defaultRuleThickness", bigOpSpacing1 := get "bigOpSpacing1",
    bigOpSpacing2 := get "bigOpSpacing2", bigOpSpacing3 := get "bigOpSpacing3",
    bigOpSpacing4 := get "bigOpSpacing4", bigOpSpacing5 := get "bigOpSpacing5",
    sqrtRuleThickness := get "sqrtRuleThickness", ptPerEm := get "ptPerEm",
    doubleRuleSep := get "doubleRuleSep", arrayRuleWidth := get "arrayRuleWidth",
    fboxsep := get "fboxsep", fboxrule := get "fboxrule",
    cssEmPerMu := ⟨Em.roundDiv (get "quad").raw 18⟩ }

/-- The parameters of the three size classes. -/
def params : Array FontParams := #[paramsAt 0, paramsAt 1, paramsAt 2]

end Metrics

/-- The font parameters for KaTeX size `size` (1–11): sizes 5 and up use the text class, 3 and
4 the script class, 1 and 2 the scriptscript class. -/
def fontParams (size : Nat) : FontParams :=
  Metrics.params[if size ≥ 5 then 0 else if size ≥ 3 then 1 else 2]!

end LeAnTeX
