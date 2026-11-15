/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import Lake

/-!
# LeAnTeX's package

The library `LeAnTeX` (imports `Init` and `Std` only) and the test executable that `lake test`
runs: it checks the parser and the layout against the recorded KaTeX fixtures and the committed
baselines. `leantex-display` prints display lists for the browser comparison; `leantex-typeset`
typesets a LaTeX file with the text layer; `leantex-render` writes a LaTeX fragment as SVG or
HTML.
-/

open Lake DSL

package leantex where
  leanOptions := #[⟨`linter.missingDocs, true⟩, ⟨`autoImplicit, false⟩]

@[default_target]
lean_lib LeAnTeX

lean_lib LeAnTeXTest

/-- Display lists as JSON, for the browser comparison of `tools/check-display.mjs`. -/
lean_exe «leantex-display» where
  root := `LeAnTeXTest.DisplayDump

/-- Typesets a LaTeX file with the text layer and prints its display list as text. -/
lean_exe «leantex-typeset» where
  root := `LeAnTeXTest.TypesetMain

/-- Typesets a LaTeX fragment and writes it as SVG or HTML. -/
lean_exe «leantex-render» where
  root := `LeAnTeXTest.RenderMain

/-- The test driver: `lake test` runs it from the repository root. -/
@[test_driver]
lean_exe «leantex-test» where
  root := `LeAnTeXTest.Main
