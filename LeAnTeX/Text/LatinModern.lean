/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Text.Typeset

/-!
# Latin Modern's files

Which Latin Modern OpenType file LaTeX uses for a font, by its font definition files for the
`TU` encoding (`tulmr.fd`, `tulmss.fd`, `tulmtt.fd`): the optical size nearest the requested
size, as those files choose it, and the substitutions they make (sans serif italic is its
oblique, small capitals come from the roman). LeAnTeX bundles no font; a caller that has the
fonts (in a TeX installation, for instance) reads the file named here and gives it to
`typeset` through its `FontResolver`.

## Main definitions

* `latinModernFile`: the file name (without `.otf`) for a font key.
-/

namespace LeAnTeX.Text

/-- The first file whose size range (upper bounds in tenths of a point, exclusive) holds
`size`. -/
private def pickSize (size : Int) (ranges : List (Nat × String)) (last : String) : String :=
  let tenths := size * 10 / 65536
  match ranges.find? fun (hi, _) => tenths < hi with
  | some (_, f) => f
  | none => last

/-- The Latin Modern file LaTeX loads for a font key (see the module docstring). -/
def latinModernFile (k : FontKey) : String :=
  match k.family, k.bold, k.shape with
  | .roman, false, .upright => pickSize k.size [(55, "lmroman5-regular"),
      (65, "lmroman6-regular"), (75, "lmroman7-regular"), (85, "lmroman8-regular"),
      (95, "lmroman9-regular"), (110, "lmroman10-regular"), (150, "lmroman12-regular")]
      "lmroman17-regular"
  | .roman, false, .slanted => pickSize k.size [(85, "lmromanslant8-regular"),
      (95, "lmromanslant9-regular"), (110, "lmromanslant10-regular"),
      (150, "lmromanslant12-regular")] "lmromanslant17-regular"
  | .roman, false, .italic => pickSize k.size [(75, "lmroman7-italic"), (85, "lmroman8-italic"),
      (95, "lmroman9-italic"), (110, "lmroman10-italic")] "lmroman12-italic"
  | _, _, .caps => "lmromancaps10-regular"
  | .roman, true, .upright => pickSize k.size [(55, "lmroman5-bold"), (65, "lmroman6-bold"),
      (75, "lmroman7-bold"), (85, "lmroman8-bold"), (95, "lmroman9-bold"),
      (110, "lmroman10-bold")] "lmroman12-bold"
  | .roman, true, .italic => "lmroman10-bolditalic"
  | .roman, true, _ => "lmromanslant10-bold"
  | .sans, false, .upright => pickSize k.size [(85, "lmsans8-regular"), (95, "lmsans9-regular"),
      (110, "lmsans10-regular"), (155, "lmsans12-regular")] "lmsans17-regular"
  | .sans, false, _ => pickSize k.size [(85, "lmsans8-oblique"), (95, "lmsans9-oblique"),
      (110, "lmsans10-oblique"), (155, "lmsans12-oblique")] "lmsans17-oblique"
  | .sans, true, .upright => "lmsans10-bold"
  | .sans, true, _ => "lmsans10-boldoblique"
  | .mono, false, .upright => pickSize k.size [(85, "lmmono8-regular"),
      (95, "lmmono9-regular"), (110, "lmmono10-regular")] "lmmono12-regular"
  | .mono, false, .italic => "lmmono10-italic"
  | .mono, false, _ => "lmmonoslant10-regular"
  | .mono, true, .upright => "lmmonolt10-bold"
  | .mono, true, _ => "lmmonolt10-boldoblique"

end LeAnTeX.Text
