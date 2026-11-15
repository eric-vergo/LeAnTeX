# Fonts

`newcomputermodern/` holds font files of **New Computer Modern** by Antonis Tsolomitis, package
version 8.1.1, as published on CTAN (<https://ctan.org/pkg/newcomputermodern>), with the
package's `README` and `License.txt`. Every file is byte for byte the file of the package:
nothing is renamed, subset or otherwise modified. `MANIFEST.tsv` lists each file with its size,
its SHA-256 and its licence; `lake test` checks every file against it.

## Which files, and why

The package's `License.txt` states: "All fonts are distributed under the GUST license except
NewCM10-Regular, all NewCMUncial, and all NewCM*Devanagari which are distributed with GPL3 or
later plus Font Exception (FE) plus Distribution Exception (DE)". Its documentation
(`doc/newcm-doc.tex`, section "License") says the same. This directory holds only the fonts
under the GUST Font License: the 29 files of the package's `otf/` directory that are not among
those exceptions.

Left out on purpose, and never part of this repository: `NewCM10-Regular.otf`, the six
`NewCMUncial*.otf` files and the five `NewCM*Devanagari*.otf` files (GPL 3 or later with the
Font and Distribution Exceptions); the package's sources (`sfd.txz`, which holds the sources of
those fonts too), its LaTeX support files and its documentation.

One font's own `name` table carries a copyright line without a licence statement
(`NewCM08-BookItalic.otf`); it is covered by `License.txt`'s statement above and is included.

## The GUST Font License

The GUST Font License's own text is not part of the local TeX installation this repository was
prepared with, so it is not copied here; the addresses below give it. The GUST Font License is
the LaTeX Project Public License, version 1.3c or later
(`LPPL-1.3c.txt`, copied verbatim from TeX Live), with an added request, not a legal
requirement, that derived works be distributed only after renaming the fonts and their files. The
licence is published at <https://www.gust.org.pl/projects/e-foundry/licenses> and
<http://tug.org/fonts/licenses/GUST-FONT-LICENSE.txt>, the address each font's copyright notice
gives.

Under the LPPL a distribution of part of a work counts as a modified one; this directory is
therefore a selection of the package's files, marked as such here, with every file unmodified, no
font renamed or presented as anything other than the original, and the complete package
available at the CTAN address above.

## Where they are used

`LeAnTeX.Text.newComputerModernFile` names the file the text layer uses for a font (the Book
weight is the default, as in the package's `newcomputermodern.sty`); the SVG and HTML back ends
draw glyphs from these files as outlines, so no output refers to a font file.
