/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX

/-!
# The axioms of the document layer's theorems

Built with the test library: each line prints the axioms a theorem of `LeAnTeX.Doc.Proofs`
depends on (`propext`, `Classical.choice` and `Quot.sound` at most).
-/

open LeAnTeX.Doc

#print axioms buildPages_boxes
#print axioms Counters.add_value
#print axioms Counters.set_value
#print axioms Counters.newCounter_value
#print axioms lookupRef_some
#print axioms lookupRef_none
#print axioms safeImagePath_relative
#print axioms safeImagePath_noParent
#print axioms romanLower_nonpos
