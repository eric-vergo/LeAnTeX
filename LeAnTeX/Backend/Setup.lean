/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Backend.Fonts
import LeAnTeX.Text.NewComputerModern

/-!
# New Computer Modern for typesetting and drawing

The text layer's resolver and the back ends' font set from one directory of New Computer
Modern's files (`fonts/newcomputermodern` in this repository): the text fonts of
`newComputerModernFiles` and the math fonts `NewCMMath-Book.otf` and `NewCMMath-Bold.otf`.

## Main definitions

* `Fonts`, `Fonts.load`.
-/

namespace LeAnTeX.Backend

open LeAnTeX.Text

/-- The fonts for typesetting and drawing: the text layer's resolver and the back ends' font
set. -/
structure Fonts where
  /-- The text layer's resolver (`LeAnTeX.Text.typeset`). -/
  resolver : FontResolver
  /-- The back ends' fonts. -/
  set : FontSet

/-- The math fonts read for the back ends. -/
def mathFiles : List String := ["NewCMMath-Book.otf", "NewCMMath-Bold.otf"]

/-- The New Computer Modern fonts in `dir`, with the files that are missing or do not read. -/
def Fonts.load (dir : System.FilePath) : IO (Fonts × Array String) := do
  let (infos, missingText) ← loadNewComputerModern dir
  let base : FontSet := { fonts := infos.fold (fun m _ i => m.insert i.name i.font) {} }
  let (set, missingMath) ← FontSet.load dir mathFiles base
  return ({ resolver := newComputerModernResolver infos, set }, missingText ++ missingMath)

end LeAnTeX.Backend
