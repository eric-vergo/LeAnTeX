/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import VersoManual
import LeAnTeXManual.Meta
import LeAnTeXManual.Guide.Math
import LeAnTeXManual.Guide.Text
import LeAnTeXManual.Guide.Documents
import LeAnTeXManual.Guide.Fonts
import LeAnTeXManual.Guide.BackEnds
import LeAnTeXManual.Guide.Macros
import LeAnTeXManual.Guide.Untrusted

open Verso.Genre Manual
open LeAnTeXManual

#doc (Manual) "Guide" =>
%%%
tag := "guide"
%%%

One chapter per part of the library. Each says what the part is for and how to call it, shows
samples typeset by the library when the manual was built, and quotes the repository's own
documents for the exact lists of what is supported and what is not.

{include 1 LeAnTeXManual.Guide.Math}

{include 1 LeAnTeXManual.Guide.Text}

{include 1 LeAnTeXManual.Guide.Documents}

{include 1 LeAnTeXManual.Guide.Fonts}

{include 1 LeAnTeXManual.Guide.BackEnds}

{include 1 LeAnTeXManual.Guide.Macros}

{include 1 LeAnTeXManual.Guide.Untrusted}
