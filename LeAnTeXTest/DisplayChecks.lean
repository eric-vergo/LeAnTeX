/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX

/-!
# Display-list checks

Properties of the display list that the browser comparison (`tools/check-display.mjs`) cannot
run on every `lake test`: mirrored material, display-mode placement of the formula and its tag,
equation numbers, dashed rules, the boxes and strikes of enclosures. Each check lays out one
formula and states what its display list must contain. Also the round trip of box trees through
their JSON form.

## Main definitions

* `displayChecks`: the checks, by name, with whether each holds.
-/

open LeAnTeX

namespace DisplayChecks

/-- The display list of a formula, or an empty one when it is not laid out. -/
def dl (tex : String) (display : Bool := false) (opts : DisplayOptions := {}) : DisplayList :=
  match (layout tex { displayMode := display }).result with
  | .ok b => DisplayList.ofBox b opts
  | .error _ => {}

/-- The display list of a formula laid out with `maxSize` em, or an empty one when it is not
laid out. -/
def dlMax (tex : String) (maxSize : Option Float) : DisplayList :=
  match (layout tex { maxSize }).result with
  | .ok b => DisplayList.ofBox b
  | .error _ => {}

/-- The glyphs of a display list: character and origin. -/
def glyphs (d : DisplayList) : Array (Char × Em × Em) :=
  d.items.filterMap fun
    | .glyph _ c x y .. => some (c, x, y)
    | _ => none

/-- The rules of a display list: rectangle and colour. -/
def rules (d : DisplayList) : Array (Em × Em × Em × Em × Option String) :=
  d.items.filterMap fun
    | .rule x y w h c _ => some (x, y, w, h, c)
    | _ => none

/-- The rectangles of the paths of a display list, with their `preserveAspectRatio`. -/
def paths (d : DisplayList) : Array (Em × Em × Em × Em × String) :=
  d.items.filterMap fun
    | .path _ _ par x y w h .. => some (x, y, w, h, par)
    | _ => none

/-- The x of a glyph. -/
def xOf (d : DisplayList) (c : Char) : Option Em :=
  ((glyphs d).find? (·.1 == c)).map (·.2.1)

/-- The checks: name and result. -/
def displayChecks : Array (String × Bool) :=
  let mirror := dl "\\reflectbox{ab}"
  let notMirrored := dl "ab"
  let tagged := dl "x \\tag{1}" true { lineWidth := some 40 }
  let taggedLeft := match (layout "x \\tag{1}" { displayMode := true, leqno := true }).result with
    | .ok b => DisplayList.ofBox b { lineWidth := some 40 }
    | .error _ => {}
  let untagged := dl "x \\tag{1}" true
  let numbered := dl "\\begin{equation}x\\end{equation}" true
    { lineWidth := some 40, firstEquationNumber := 7 }
  let dashed := dl "\\begin{array}{c:c}a&b\\\\c&d\\end{array}"
  let solid := dl "\\begin{array}{c|c}a&b\\\\c&d\\end{array}"
  let hdash := dl "\\begin{matrix}a\\\\\\hdashline b\\end{matrix}"
  let fbox := dl "\\fbox{x}"
  let colorbox := dl "\\colorbox{red}{x}"
  let cancel := dl "\\cancel{ab}"
  let xcancel := dl "\\xcancel{ab}"
  let sout := dl "\\text{\\sout{ab}}"
  #[("reflectbox: its glyphs are one mirrored range", mirror.mirrored == #[(0, 2)]),
    ("reflectbox: the first character ends up on the right",
      match xOf mirror 'a', xOf mirror 'b' with
      | some a, some b => a > b
      | _, _ => false),
    ("reflectbox: unmirrored material has no range", notMirrored.mirrored.isEmpty),
    ("reflectbox: the mirrored glyphs keep the material's extent",
      match xOf mirror 'a', xOf notMirrored 'b' with
      | some a, some b => (a - mirror.width).abs ≤ Em.mk 1 && b < mirror.width
      | _, _ => false),
    ("display mode: the tag ends at the right end of the line",
      match tagged.parts.find? (·.tag) with
      | some p => p.x + p.width == 40
      | none => false),
    ("display mode: the formula is centred in the line",
      match tagged.parts.find? (!·.tag) with
      | some p => p.x > 0 && (2 * p.x + p.width - 40).abs ≤ Em.mk 1
      | none => false),
    ("display mode, leqno: the tag starts at the left end",
      match taggedLeft.parts.find? (·.tag) with
      | some p => p.x == 0
      | none => false),
    ("display mode without a line width: the tag follows the formula",
      match untagged.parts.find? (·.tag), untagged.parts.find? (!·.tag) with
      | some t, some p => t.x ≥ p.x + p.width
      | _, _ => false),
    ("equation numbers: written out from the first number",
      ((glyphs numbered).map (·.1)).toList.filter (· != 'x') == ['(', '7', ')']),
    ("dashed column rule: drawn as dashes", (rules dashed).size > 2),
    ("solid column rule: one rule", (rules solid).size == 1),
    ("dashed row rule: drawn as dashes, all on one line",
      (rules hdash).size > 2 && ((rules hdash).map (·.2.1)).toList.eraseDups.length == 1),
    ("fbox: four borders", (rules fbox).size == 4),
    ("colorbox: the background, before the glyph",
      match colorbox.items[0]? with
      | some (Item.rule _ _ _ _ (some "red") _) => (rules colorbox).size == 1
      | _ => false),
    ("cancel: one stroke clipped to the box",
      (paths cancel).size == 1 && (paths cancel).all (·.2.2.2.2 == "none")),
    ("xcancel: two strokes", (paths xcancel).size == 2),
    ("sout: one rule through the text", (rules sout).size == 1),
    ("box trees read back from their JSON form unchanged",
      ["\\frac{a}{b}^2", "\\begin{pmatrix}a&b\\\\c&d\\end{pmatrix}", "\\cancel{x+y}",
        "\\xrightarrow[b]{a}", "\\sqrt[3]{x}"].all fun tex =>
        match (layout tex).result with
        | .ok b => (Box.ofJson b.toJson).toJson.compress == b.toJson.compress
        | .error _ => false),
    ("a character a face does not have: the fallback font's advance moves what follows",
      let fb : DisplayOptions := { fallbackAdvance := fun _ c => if c == '日' then some 1 else none }
      let (a, b) := (dl "\\text{日}x", dl "\\text{日}x" (opts := fb))
      match xOf a 'x', xOf b 'x', a.items[0]?, b.items[0]? with
      | some xa, some xb, some (Item.glyph f '日' _ _ _ false ..), some (Item.glyph _ _ _ _ _ false ..) =>
        xb - xa == 1 - (Display.charWidth f '日').1
      | _, _, _, _ => false),
    ("a character a face does not have: the fallback advance widens what holds it",
      let fb : DisplayOptions := { fallbackAdvance := fun _ c => if c == '日' then some 1 else none }
      (dl "\\sqrt{\\text{日}}" (opts := fb)).width > (dl "\\sqrt{\\text{日}}").width),
    ("a face's own characters ignore the fallback advance",
      let fb : DisplayOptions := { fallbackAdvance := fun _ _ => some 3 }
      (dl "x+y" (opts := fb)).width == (dl "x+y").width),
    ("maxSize: a rule's height is cut to it",
      match rules (dlMax "\\rule{1pt}{100000em}" (some 10)) with
      | #[(_, _, _, h, _)] => h == Em.ofInt 10
      | _ => false),
    ("maxSize: a space is cut to it, the formula's width with it",
      let (cut, whole) := (dlMax "a\\hspace{1000em}b" (some 5), dlMax "a\\hspace{1000em}b" none)
      match xOf cut 'a', xOf cut 'b' with
      | some xa, some xb => xb - xa ≤ Em.ofInt 6 && whole.width > Em.ofInt 1000 && cut.wellFormed
      | _, _ => false),
    ("maxSize: none, an infinite and a negative one",
      let h (d : DisplayList) : Em := match rules d with | #[(_, _, _, h, _)] => h | _ => 0
      h (dlMax "\\rule{1pt}{50em}" none) == Em.ofInt 50 &&
        h (dlMax "\\rule{1pt}{50em}" (some (1 / 0))) == Em.ofInt 50 &&
        h (dlMax "\\rule{1pt}{50em}" (some (-3))) == 0),
    ("maxTokens: a macro bomb past it is an error, within it laid out; none: no limit",
      let bomb := "\\def\\a{xxxxxxxxxx}\\def\\b{\\a\\a\\a\\a\\a\\a\\a\\a\\a\\a}\\b\\b\\b"
      let res (mt : Option Nat) := (layout bomb { maxTokens := mt }).result
      (match res (some 100) with
        | .error (.katex e) => e.message.startsWith "KaTeX parse error: Too many tokens"
        | _ => false) &&
      (match res (some 1000), res none with
        | .ok _, .ok b => (DisplayList.ofBox b).items.size == 300
        | _, _ => false)),
    ("every check list keeps the invariants",
      [mirror, tagged, taggedLeft, numbered, dashed, hdash, fbox, colorbox, cancel, xcancel,
        sout].all (·.wellFormed))]

end DisplayChecks
