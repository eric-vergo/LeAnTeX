/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/

/-!
# The characters of the Computer Modern math fonts

The Unicode character each slot of a Computer Modern metric file shows (by the font encodings
OT1, OML, OMS, OMX and the AMS fonts' layouts), so it can be drawn with an OpenType math font.

## Main definitions

* `unicodeOf`: the character of a slot of a metric font, by the font's name.
-/

namespace LeAnTeX.TeXMath.Data

/-- The family of a metric file's name (`cmmi7` is `cmmi`). -/
def fontFamily (name : String) : String :=
  String.ofList (name.toList.takeWhile (!·.isDigit))

/-- The character slot `slot` of the metric file `name` shows, if known. -/
def unicodeOf (name : String) (slot : Nat) : Option Char :=
  let fam := fontFamily name
  if slot ≥ 0x21 && slot < 0x7F && (fam == "cmr" || fam == "cmbx") then some (Char.ofNat slot)
  else if (fam == "cmmi" || fam == "cmmib") && slot < 0x7F &&
      ((slot ≥ 0x41 && slot ≤ 0x5A) || (slot ≥ 0x61 && slot ≤ 0x7A)) then
    -- mathematical italic letters (U+1D434 …), `h` at U+210E
    if slot == 0x68 then some 'ℎ'
    else if slot ≤ 0x5A then some (Char.ofNat (0x1D434 + slot - 0x41))
    else some (Char.ofNat (0x1D44E + slot - 0x61))
  else if slot ≥ 0x30 && slot ≤ 0x39 then some (Char.ofNat slot)
  else none

end LeAnTeX.TeXMath.Data
