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
* `readSource`: a source file's text, refused unread when it is too large to be typeset.
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

/-- The source as SVG or HTML (see the module docstring), or the error's position and message.
With `math` the position is KaTeX's, a UTF-16 offset in the source (`KError.position`: a
character outside the Basic Multilingual Plane counts two); otherwise it is a character offset
(for an error inside a formula, the offset of the formula's start). -/
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

/-- The text of a source file, or why it is not read: a file with more bytes than
`Settings.maxSource` characters can have (four each) is refused before it is read, so that a
program given a file by a stranger holds no more of it than the typesetter would take. -/
def readSource (path : System.FilePath) (cfg : Text.Settings := {}) :
    IO (Except String String) := do
  let size := (← path.metadata).byteSize.toNat
  if size > 4 * cfg.maxSource then
    return .error s!"source too long: {size} bytes, more than {4 * cfg.maxSource}"
  return .ok (← IO.FS.readFile path)

end LeAnTeX.Backend
