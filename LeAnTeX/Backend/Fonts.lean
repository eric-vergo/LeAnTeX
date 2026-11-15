/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.OpenType
import LeAnTeX.Layout.Display
import LeAnTeX.Layout.Metrics

/-!
# Fonts for drawing a display list

A display list names its glyphs by face and character; a back end that draws them as outlines
needs, for each, a font and a glyph index. `FontSet.resolve` gives them:

* **Text-layer glyphs** (`Face.font` set) come from the font of that name, through its
  character map, with its small capitals (`smcp`) when the face asks for them.
* **KaTeX's faces** are drawn with an OpenType math font (by default New Computer Modern Math,
  Book weight, `NewCMMath-Book.otf`) at the positions KaTeX's metrics give. Each face maps a
  character to the code point of the same symbol in Unicode's mathematical alphanumeric
  symbols: `Math-Italic` to the italic letters and Greek (`U+1D434`…, with `ℎ` for `h`),
  `AMS-Regular` capitals to the double-struck ones, `Caligraphic` and `Script` to the script
  letters, `Fraktur` to the Fraktur letters, `SansSerif` and `Typewriter` to the sans-serif and
  monospace ones (with the letters Unicode places in its Letterlike Symbols block). `Main-Bold`
  is the bold math font (`NewCMMath-Bold.otf`), `Main-Italic` and `Main-BoldItalic` the text
  italics (`NewCM10-BookItalic.otf`, `NewCM10-BoldItalic.otf`). `Size1`–`Size4` take the math
  font's size variants (`MATH` table): the smallest variant at least as tall (or, for a glyph
  that grows sideways, as wide) as KaTeX's glyph in that face, else the largest.
* A character the chosen font lacks is looked up in the math font, then in the main text font;
  a glyph no font has is not drawn.

The outlines are not KaTeX's own fonts' (which LeAnTeX does not include): New Computer Modern's
glyphs differ from KaTeX's in places (`docs/back-ends.md`), while their positions are KaTeX's.

## Main definitions

* `FontSet`, `GlyphRef`, `FontSet.resolve`.
* `mathAlphanumeric`: KaTeX's face and character to the Unicode mathematical character.
* `FontSet.load`: fonts read from files.
-/

namespace LeAnTeX.Backend

open LeAnTeX.OpenType

/-- The fonts a back end draws with: fonts by the name display lists use (a text font's file
name, `NewCM10-Book.otf`), and which of them serve KaTeX's faces. -/
structure FontSet where
  /-- The fonts, by name. -/
  fonts : Std.HashMap String OpenType.Font := {}
  /-- The math font. -/
  math : String := "NewCMMath-Book.otf"
  /-- The bold math font (`Main-Bold`), falling back to `math`. -/
  mathBold : String := "NewCMMath-Bold.otf"
  /-- The text italic (`Main-Italic`). -/
  italic : String := "NewCM10-BookItalic.otf"
  /-- The text bold italic (`Main-BoldItalic`). -/
  boldItalic : String := "NewCM10-BoldItalic.otf"
  /-- The main text font, the last fallback. -/
  text : String := "NewCM10-Book.otf"
  deriving Inhabited

/-- A glyph to draw: the font's name and the glyph index in it. -/
structure GlyphRef where
  /-- The font's name in the `FontSet`. -/
  font : String
  /-- The glyph index. -/
  glyph : Nat
  deriving BEq, Hashable, Inhabited, Repr

/-- `c` moved from the block starting at `base` (of `n` characters) to the block starting at
`target`, if it is in it. -/
private def shift (c : Char) (base n target : Nat) : Option Char :=
  if base ≤ c.toNat && c.toNat < base + n then some (Char.ofNat (target + c.toNat - base))
  else none

/-- Letters Unicode places outside a mathematical alphabet, by capital, for an alphabet. -/
private def holes (alphabet : String) (c : Char) : Option Char :=
  let table : List (Char × Nat) := match alphabet with
    | "double" => [('C', 0x2102), ('H', 0x210D), ('N', 0x2115), ('P', 0x2119), ('Q', 0x211A),
        ('R', 0x211D), ('Z', 0x2124)]
    | "script" => [('B', 0x212C), ('E', 0x2130), ('F', 0x2131), ('H', 0x210B), ('I', 0x2110),
        ('L', 0x2112), ('M', 0x2133), ('R', 0x211B)]
    | "fraktur" => [('C', 0x212D), ('H', 0x210C), ('I', 0x2111), ('R', 0x211C), ('Z', 0x2128)]
    | "italic" => [('h', 0x210E)]
    | _ => []
  (table.find? (·.1 == c)).map fun (_, n) => Char.ofNat n

/-- A Latin letter (and digit, when the alphabet has digits) in a mathematical alphabet:
capitals from `cap`, small letters from `small`, digits from `digit`. -/
private def latin (alphabet : String) (cap small : Nat) (digit : Option Nat) (c : Char) :
    Option Char :=
  (holes alphabet c).orElse fun _ => (shift c 0x41 26 cap).orElse fun _ =>
    (shift c 0x61 26 small).orElse fun _ => digit.bind (shift c 0x30 10 ·)

/-- Greek in a mathematical alphabet: capitals from `cap`, small letters from `small`, and the
six variant forms (`ϵ ϑ ϰ ϕ ϱ ϖ`) from `vars`. -/
private def greek (cap small vars : Nat) (c : Char) : Option Char :=
  let variants : List Nat := [0x3F5, 0x3D1, 0x3F0, 0x3D5, 0x3F1, 0x3D6]
  (shift c 0x391 25 cap).orElse fun _ => (shift c 0x3B1 25 small).orElse fun _ =>
    (variants.idxOf? c.toNat).map fun i => Char.ofNat (vars + i)

/-- The Unicode mathematical character KaTeX's face draws `c` as (see the module docstring),
`none` when the face draws it as itself. -/
def mathAlphanumeric (face : String) (c : Char) : Option Char :=
  match face with
  | "Math-Italic" => (latin "italic" 0x1D434 0x1D44E none c).orElse fun _ =>
      greek 0x1D6E2 0x1D6FC 0x1D716 c
  | "Math-BoldItalic" => (latin "" 0x1D468 0x1D482 none c).orElse fun _ =>
      greek 0x1D71C 0x1D736 0x1D750 c
  | "AMS-Regular" => if c == 'k' then some (Char.ofNat 0x1D55C)
      else if 'A' ≤ c && c ≤ 'Z' then latin "double" 0x1D538 0x1D552 none c else none
  | "Caligraphic-Regular" | "Script-Regular" =>
      if 'A' ≤ c && c ≤ 'Z' then latin "script" 0x1D49C 0x1D4B6 none c else none
  | "Caligraphic-Bold" => if 'A' ≤ c && c ≤ 'Z' then latin "" 0x1D4D0 0x1D4EA none c else none
  | "Fraktur-Regular" => latin "fraktur" 0x1D504 0x1D51E none c
  | "Fraktur-Bold" => latin "" 0x1D56C 0x1D586 none c
  | "SansSerif-Regular" => latin "" 0x1D5A0 0x1D5BA (some 0x1D7E2) c
  | "SansSerif-Bold" => latin "" 0x1D5D4 0x1D5EE (some 0x1D7EC) c
  | "SansSerif-Italic" => latin "" 0x1D608 0x1D622 none c
  | "Typewriter-Regular" => latin "" 0x1D670 0x1D68A (some 0x1D7F6) c
  | _ => none

namespace FontSet

variable (fs : FontSet)

/-- The glyph of `c` in the font named `name`, if the font is there and has it. -/
def glyphIn (name : String) (c : Char) : Option GlyphRef := do
  let f ← fs.fonts[name]?
  let g := f.glyph c
  if g == 0 then none else some ⟨name, g⟩

/-- The glyph of `c` in `name`, else in the math font, else in the text font. -/
def glyphWithFallback (name : String) (c : Char) : Option GlyphRef :=
  (fs.glyphIn name c).orElse fun _ => (fs.glyphIn fs.math c).orElse fun _ => fs.glyphIn fs.text c

/-- For a glyph, its smallest vertical size variant of at least `tall` font units, else its
largest; for a glyph with horizontal variants only, the same by `wide`; the glyph itself
without variants. -/
def sizeVariant (r : GlyphRef) (tall wide : Nat) : GlyphRef := Id.run do
  let some f := fs.fonts[r.font]? | return r
  let (vs, target) := match f.mathVariants.vertical[r.glyph]? with
    | some vs => (vs, tall)
    | none => ((f.mathVariants.horizontal[r.glyph]?).getD #[], wide)
  match vs.find? (·.2 ≥ target) with
  | some (g, _) => return ⟨r.font, g⟩
  | none => return match vs.back? with | some (g, _) => ⟨r.font, g⟩ | none => r

/-- The glyph to draw for a display list's glyph item of `face` and `c` (see the module
docstring); `none` if no font has it. -/
def resolve (face : Face) (c : Char) : Option GlyphRef :=
  match face.font with
  | some name => do
    let r ← fs.glyphWithFallback name c
    if !face.smallCaps then return r
    let f ← fs.fonts[r.font]?
    let g := match f.gsub with
      | some t => (t.apply ["smcp"] #[r.glyph])[0]?.getD r.glyph
      | none => r.glyph
    return ⟨r.font, g⟩
  | none =>
    let name := face.katexName
    if name.startsWith "Size" then do
      let r ← fs.glyphWithFallback fs.math c
      let m := charMetrics (String.singleton c) name .math
      let upem := ((fs.fonts[r.font]?).map (·.unitsPerEm)).getD 1000
      -- KaTeX's glyph's extent in font units, less 5 % so that a variant a little smaller
      -- than KaTeX's glyph is still taken
      let units := fun (e : Em) => (Em.roundDiv (e.raw * upem) Em.unit).toNat * 95 / 100
      match m with
      | some m => return fs.sizeVariant r (units (m.height + m.depth)) (units m.width)
      | none => return r
    else
      let font := match name with
        | "Main-Bold" => if fs.fonts.contains fs.mathBold then fs.mathBold else fs.math
        | "Main-Italic" => fs.italic
        | "Main-BoldItalic" => fs.boldItalic
        | _ => fs.math
      match mathAlphanumeric name c with
      | some m => (fs.glyphIn font m).orElse fun _ => fs.glyphWithFallback font c
      | none => fs.glyphWithFallback font c

/-- The font set over the fonts read from the files `names` in `dir`, each under its file name;
a file missing or unreadable is left out, with the reason in the second component. -/
def load (dir : System.FilePath) (names : List String) (base : FontSet := {}) :
    IO (FontSet × Array String) := do
  let mut fonts := base.fonts
  let mut missing := #[]
  for n in names do
    let p := dir / n
    if !(← p.pathExists) then missing := missing.push s!"{n}: not found"; continue
    match OpenType.Font.read (← IO.FS.readBinFile p) with
    | .ok f => fonts := fonts.insert n f
    | .error e => missing := missing.push s!"{n}: {e.table}: {e.message}"
  return ({ base with fonts }, missing)

end FontSet

end LeAnTeX.Backend
