/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Backend.Proofs

/-!
# The axioms of the back ends' theorems

Printed when this module is built: each may use only `propext`, `Classical.choice` and
`Quot.sound`.
-/

open LeAnTeX.Backend

#print axioms escape_no_lt
#print axioms escape_no_gt
#print axioms escape_no_quot
#print axioms escape_no_apos
#print axioms unescape_escape
#print axioms exists_def_of_mem_picture_body
