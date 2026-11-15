/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Text.Proofs

/-!
# The axioms of the text layer's theorems

Printed when this module is built: each may use only `propext`, `Classical.choice` and
`Quot.sound`.
-/

open LeAnTeX.Text

#print axioms breakParagraph_legal
#print axioms breakParagraph_increasing
#print axioms breakParagraph_ends
#print axioms points_minima
#print axioms badness_le
#print axioms lineRanges_first
#print axioms lineRanges_stop
#print axioms lineRanges_next
