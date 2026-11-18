/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import VersoManual
import LeAnTeXManual.Meta
import LeAnTeXManual.AgreementMeta

open Verso.Genre Manual
open LeAnTeXManual

#doc (Manual) "Agreement with TeX and KaTeX" =>
%%%
tag := "agreement"
htmlSplit := .never
%%%

LeAnTeX is compared with three reference programs: KaTeX 0.19.1 for the parser and the
KaTeX-compatible layout, LuaLaTeX of TeX Live 2025 for the text layer, the TeX-rule layout and
the document layer, and fontTools for the font reader. The comparisons use the reference
programs' answers as they were recorded and committed in the repository; the tests run none of
those programs. Each figure below holds for the committed corpora only, and says how its inputs
relate to the development of the library: some sets were used while the code was written (the
library was tuned to them), others were written without reading the library and not tuned to.
The README states this for every figure, and this chapter quotes it rather than restating it.

# The Figures as the README States Them
%%%
tag := "agreement-readme"
%%%

The section below is the repository's `README.md`, quoted when the manual was built:

{quoteSection "README.md" "The figures, and how to reproduce them"}

# The Figures in This Build
%%%
tag := "agreement-this-build"
%%%

When this site was written, its build ran LeAnTeX's test driver (`leantex-test` in the
repository's root, what `lake test` runs) and read what it printed. The table puts each figure
of the README beside the line the driver printed for it. A figure that needs files of a TeX
installation (the Computer Modern metric files, the Latin Modern fonts) is regenerated only when
the machine that built the site had them; otherwise its row says so, and the README's figure is
the committed record, not a result of this build. The build fails if a figure it could
regenerate is not what the driver printed, if the driver reports a regression, or if a figure's
wording here is no longer the README's.

{figureRuns}

The comparisons of the display list with KaTeX in a browser and of the rendered output with
LuaLaTeX's (the last row of the README's table) need KaTeX's built distribution and Chromium, or
LuaLaTeX and macOS. They are not part of `lake test`, are not run by this build, and their
figures are those of their last run as the documents below record them.

# Text
%%%
tag := "agreement-text"
%%%

{quoteSection "docs/text.md" "Agreement with TeX"}

# Formula Boxes
%%%
tag := "agreement-math-boxes"
%%%

{quoteSection "docs/math-boxes.md" "How far apart they are"}

# Documents
%%%
tag := "agreement-documents"
%%%

{quoteSection "docs/documents.md" "Agreement with LuaLaTeX"}
