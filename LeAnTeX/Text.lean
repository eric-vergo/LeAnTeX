/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Text.Node
import LeAnTeX.Text.Hyphen
import LeAnTeX.Text.LineBreak
import LeAnTeX.Text.Pack
import LeAnTeX.Text.Font
import LeAnTeX.Text.Source
import LeAnTeX.Text.Typeset
import LeAnTeX.Text.LatinModern
import LeAnTeX.Text.NewComputerModern
import LeAnTeX.Text.Output
import LeAnTeX.Text.Proofs

/-!
# Text mode

LeAnTeX's text layer: LaTeX source set into lines as TeX sets it (`docs/text.md`).

* `LeAnTeX.Text.typeset`: source to a `Document` (`LeAnTeX.Text.Typeset`).
* `LeAnTeX.Text.breakParagraph`, `setLines`: TeX's line breaker and the lines it gives.
* `LeAnTeX.Text.Patterns`: Liang's hyphenation with TeX's patterns.
* `LeAnTeX.Text.Document.toDisplayList`: the result as a display list.
-/
