/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX

/-!
# The axioms of the TeX-rule layout's theorems

Built with the test library: each line prints the axioms a theorem of `LeAnTeX.TeXMath.Proofs`
depends on (`propext`, `Classical.choice` and `Quot.sound` at most).
-/

open LeAnTeX.TeXMath

#print axioms Style.sub_isCramped
#print axioms Style.denom_isCramped
#print axioms Style.sup_isCramped_of
#print axioms Style.cramped_cramped
#print axioms Style.size_le_sub
#print axioms Style.sub_size_eq_sup_size
#print axioms Style.sub_of_script
#print axioms Style.size_le_num
#print axioms spacingTable_total
#print axioms spacingTable_after_open
#print axioms interAtomGlue_script
#print axioms hpack_width
#print axioms le_hpack_height
#print axioms le_hpack_depth
