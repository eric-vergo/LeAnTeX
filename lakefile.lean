/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import Lake

/-!
# LeAnTeX's package

The library `LeAnTeX` (imports `Init` and `Std` only) and the test executable that `lake test`
runs: it checks the parser against the recorded KaTeX fixtures and the committed parity report.
-/

open Lake DSL

package leantex where
  leanOptions := #[⟨`linter.missingDocs, true⟩, ⟨`autoImplicit, false⟩]

@[default_target]
lean_lib LeAnTeX

lean_lib LeAnTeXTest

/-- The test driver: `lake test` runs it from the repository root. -/
@[test_driver]
lean_exe «leantex-test» where
  root := `LeAnTeXTest.Main
