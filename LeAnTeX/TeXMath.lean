/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.TeXMath.Arith
import LeAnTeX.TeXMath.Tfm
import LeAnTeX.TeXMath.Node
import LeAnTeX.TeXMath.Font
import LeAnTeX.TeXMath.Noad
import LeAnTeX.TeXMath.MList
import LeAnTeX.TeXMath.Setup
import LeAnTeX.TeXMath.Data.MathCodes
import LeAnTeX.TeXMath.Front

/-!
# The TeX-rule math layout

A second math layout beside the KaTeX-compatible one: TeX's own rules (*The TeXbook*,
Appendix G) with the metrics of the fonts LaTeX uses, for the text and document layers, whose
boxes must be TeX's (`docs/math-boxes.md`).

* `LeAnTeX.TeXMath.Tfm`: TeX font metric files.
* `LeAnTeX.TeXMath.mlistToHlist`: a math list to boxes.
* `LeAnTeX.TeXMath.MathFontSet`: LaTeX's math fonts at a size.
* `LeAnTeX.TeXMath.toMathList`: the parse tree to TeX's math list.
-/
