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
those programs. Each figure below holds for the committed corpora only. The sets differ in how
they relate to the library's development: the parser, layout and text figures are stated for the
committed corpora only; the formula-box corpus and the reference documents were used while the
code was written (the library was developed against them);
the ten fresh documents were written without reading the library but corrected against
afterwards; the first held-out set was written the same way, before the TeX-rule layout was
developed, four of its fixtures were re-recorded before its first recorded score and a defect
it showed was fixed after it, so it is no untouched test; only the second held-out set was
written blind and never tuned to. A document's lines with a formula are compared by their
position only. The README's table states these limits figure by figure; this chapter quotes
it, and adds the table of what this build printed.

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
repository's root, what `lake test` runs) and read what it printed: its sentences, and its
totals as typed fields (`figure KEY VALUE`). The table puts each figure of the README beside
the sentence the driver printed for it and checks the figure's numbers against the fields. A
number that needs files of a TeX installation (the Computer Modern metric files, the Latin
Modern fonts) is checked only when the machine that built the site had them. The status says
how much was checked: *Regenerated* when every number of the README's wording is a field this
build checked, *Partly regenerated* (naming the numbers it did not check) when some are not,
*Not regenerated* when none could be, and then the README's figure is the committed record,
not a result of this build. The build fails if a field it could check is missing or has
another value, if the driver reports a regression against its committed baselines, or if a
figure's wording here no longer occurs in the README's section. Some lines are marked by the
driver as reported, not required: for those the driver does not fail on a change, but this
build still does.

{figureRuns}

The comparisons of the display list with KaTeX in a browser and of the rendered output with
LuaLaTeX's (the last row of the README's table) need KaTeX's built distribution and Chromium, or
LuaLaTeX and macOS. They are not part of `lake test`, are not run by this build, and their
figures are those of their last run, recorded in {file}`STATUS.md`, {file}`docs/display-list.md`
and {file}`docs/back-ends.md` (not quoted here).

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
