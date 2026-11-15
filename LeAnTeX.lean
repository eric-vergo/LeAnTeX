/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Parse.Parser
import LeAnTeX.Parse.NodeJson
import LeAnTeX.Layout.Build
import LeAnTeX.Layout.BoxJson
import LeAnTeX.Layout.Display
import LeAnTeX.Path
import LeAnTeX.OpenType
import LeAnTeX.OpenType.Display
import LeAnTeX.Text
import LeAnTeX.Doc
import LeAnTeX.Backend

/-!
# LeAnTeX

A TeX math renderer in pure Lean, ported from KaTeX, an OpenType font reader
(`LeAnTeX.OpenType`), and a text mode that sets paragraphs as TeX does (`LeAnTeX.Text`).
-/
