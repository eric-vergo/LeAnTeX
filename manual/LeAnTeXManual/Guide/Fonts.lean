/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import VersoManual
import LeAnTeXManual.Meta

open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean
open LeAnTeXManual

#doc (Manual) "Fonts and Metrics" =>
%%%
tag := "fonts"
htmlSplit := .never
%%%

LeAnTeX uses three kinds of font data, from three places:

:::table +header
* * What
  * Where it comes from
  * Used by
* * KaTeX's glyph metrics and font parameters
  * compiled into the library (tables generated from KaTeX 0.19.1's source)
  * the KaTeX-compatible layout
* * OpenType fonts: New Computer Modern, or any fonts the caller reads
  * files read at run time with `LeAnTeX.OpenType`; New Computer Modern is in the repository
  * the text layer (metrics, ligatures, kerning), the back ends (outlines)
* * TeX font metric (TFM) files of Computer Modern, the AMS and Euler fonts
  * a TeX installation the user has, read at run time; not in the repository
  * the TeX-rule layout
:::

# New Computer Modern
%%%
tag := "fonts-ncm"
%%%

{file}`fonts/newcomputermodern` holds 29 font files of New Computer Modern (package version
8.1.1), unmodified, those of the package that are under the GUST Font License; the manifest
{file}`fonts/MANIFEST.tsv` lists each with its size and SHA-256, and `lake test` checks every
file against it. {ref "licences"}[Licences] gives the licence and the files.

{name}`LeAnTeX.Backend.Fonts.load` reads them from a folder: the text fonts for the text layer's
resolver, and the math fonts (`NewCMMath-Book.otf`, `NewCMMath-Bold.otf`) for drawing formulas.
The text layer chooses the file for a font as the package's own `fontspec` files do
({name}`LeAnTeX.Text.newComputerModernFace`):

```lean (name := faceEx)
#eval [({} : LeAnTeX.Text.FontKey), { shape := .italic }, { bold := true },
    { shape := .slanted }, { family := .mono }, { size := 7 * 65536 }]
  |>.map fun k =>
    let f := LeAnTeX.Text.newComputerModernFace k
    (f.file, f.slant)
```

```leanOutput faceEx
[("NewCM10-Book", 0), ("NewCM10-BookItalic", 0), ("NewCM10-Bold", 0), ("NewCM10-Book", 250), ("NewCMMono10-Book", 0),
  ("NewCM08-Book", 0)]
```

Each pair is the file (without `.otf`) and the slant drawn onto it, in thousandths. Which file
serves which of KaTeX's faces when a formula is drawn is in
{ref "back-ends-faces"}[Drawing KaTeX's Faces].

# The OpenType Reader
%%%
tag := "fonts-opentype"
%%%

{name}`LeAnTeX.OpenType.Font.read` reads an OpenType font from its bytes in pure Lean: metrics,
character maps, CFF and TrueType outlines, ligatures and pair kerning, and the `MATH` table's
constants and size variants. The text layer can use any fonts through its resolver; the back
ends draw formulas with New Computer Modern Math unless given a `FontSet` of their own.

{quoteSection "docs/opentype.md" "What it reads"}

# TeX Font Metrics
%%%
tag := "fonts-tfm"
%%%

The TeX-rule layout needs the metric files LaTeX uses for formulas: `cmmi`, `cmsy`, `cmr`, `cmex`
and their bold forms at each design size, and `msam`, `msbm`, `eufm` for `amssymb` and
`\mathfrak`. They are not part of LeAnTeX. {name}`LeAnTeX.TeXMath.readTfmDirs` finds them in the
folders it is given, reads each, checks it as TeX checks a file, and returns the ones that pass
and the reasons for the ones refused; `LeAnTeX.TeXMath.mathTfmNames` lists the names it looks
for. Sizes are scaled as TeX scales them, so widths are TeX's at every size.

A character of a metric font has no outline here: the back ends draw it with the glyph of New
Computer Modern Math that shows the same symbol, at the position and size TeX's metrics give it.

{quoteSection "docs/math-boxes.md" "The metrics"}
