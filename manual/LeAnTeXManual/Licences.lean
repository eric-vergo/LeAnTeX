/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import VersoManual
import LeAnTeXManual.Meta

open Verso.Genre Manual
open LeAnTeXManual

#doc (Manual) "Licences" =>
%%%
tag := "licences"
htmlSplit := .never
%%%

LeAnTeX's own code is released under the Apache License 2.0. Parts of it are derived from KaTeX,
and the repository carries fonts, hyphenation patterns and recorded data under their own terms.
This page quotes the repository's notices as they are committed ({file}`THIRD-PARTY.md`, the
licence files and the font manifest), so that it says no more and no less than they do. The full
texts are at the end of the page.

# Derived from KaTeX
%%%
tag := "licences-katex"
%%%

{quoteSection "THIRD-PARTY.md" "Derived from KaTeX"}

The MIT licence of KaTeX is reproduced in full in {file}`LICENSE-KaTeX` (below).

# Data from KaTeX's Fonts
%%%
tag := "licences-katex-fonts"
%%%

{quoteSection "THIRD-PARTY.md" "Data from KaTeX's fonts"}

# New Computer Modern
%%%
tag := "licences-ncm"
%%%

{quoteSection "THIRD-PARTY.md" "Fonts: New Computer Modern"}

The files, with their sizes, checksums and licence, as the manifest lists them (`lake test`
checks every file against it):

{tsvTable "fonts/MANIFEST.tsv"}

{quoteSection "fonts/README.md" "Which files, and why"}

# Hyphenation Patterns
%%%
tag := "licences-patterns"
%%%

{quoteSection "THIRD-PARTY.md" "Hyphenation patterns"}

Each pattern module carries its source file's notice in its module documentation: {api}`LeAnTeX.Data.HyphenEnglish`
and {api}`LeAnTeX.Data.HyphenEnUs`.

# TeX's Metric Files and Other Sources
%%%
tag := "licences-other"
%%%

{quoteSection "THIRD-PARTY.md" "The TeX-rule math layout"}

{quoteSection "THIRD-PARTY.md" "The text and document layers"}

{quoteSection "THIRD-PARTY.md" "Recorded from TeX and from fonts"}

{quoteSection "THIRD-PARTY.md" "Other corpora"}

# Licence Texts
%%%
tag := "licences-texts"
%%%

{fileText "LICENSE"}

{fileText "LICENSE-KaTeX"}

{fileText "LICENSE-KaTeX-fonts"}

{fileText "fonts/GUST-FONT-LICENSE.txt"}

{fileText "fonts/LPPL-1.3c.txt"}

{fileText "fonts/newcomputermodern/License.txt"}
