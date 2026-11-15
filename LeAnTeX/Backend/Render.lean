/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Backend.Html
import LeAnTeX.Backend.Setup
import LeAnTeX.Text.Output
import LeAnTeX.Doc.Front

/-!
# From source to SVG or HTML

`render` typesets LaTeX source with the text layer (or lays it out as one formula) and writes
it with the SVG or the HTML back end, with the source as the picture's title.

## Main definitions

* `RenderOptions`, `render`.
-/

namespace LeAnTeX.Backend

/-- What to render and how. -/
structure RenderOptions where
  /-- Write an HTML page instead of an SVG picture. -/
  html : Bool := false
  /-- Take the source as one formula in display mode instead of text. -/
  math : Bool := false
  /-- Where an HTML page finds the fonts. -/
  fontUrl : String := "fonts/newcomputermodern"
  /-- The size of a formula's em, in sp, when `math` (ten points). -/
  mathEm : Int := 10 * 65536
  deriving Inhabited

/-- The source as SVG or HTML (see the module docstring), or the error's position (a character
offset in the source) and message. -/
def render (fonts : Fonts) (src : String) (opts : RenderOptions := {}) :
    Except (Nat × String) String := do
  let dl ← if opts.math then
      match (LeAnTeX.layout src { displayMode := true }).result with
      | .ok b =>
        let dl := DisplayList.ofBox b { fallbackAdvance := fonts.set.fallbackAdvance }
        pure { dl with formulas := #[⟨0, dl.items.size, 0, 0, dl.width, dl.height, dl.depth,
          src, true⟩] }
      | .error (.katex e) => throw (((e.position.map (·.1)).getD 0), e.message)
      | .error (.unsupported w) => throw (0, s!"unsupported: {w}")
    else
      match Text.typeset src fonts.resolver with
      | .ok d => pure d.toDisplayList
      | .error e => throw (e.pos, e.message)
  let title := src.trimAscii.toString
  if opts.html then
    let em := if opts.math then opts.mathEm else 10 * 65536
    return htmlDocument fonts.set dl { em, fontUrl := opts.fontUrl, title }
  else
    let em := if opts.math then opts.mathEm else 10 * 65536
    return svgDocument fonts.set dl { em, title }

end LeAnTeX.Backend
