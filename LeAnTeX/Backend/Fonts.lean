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
* KaTeX's private-use characters (`privateUse`), which name glyphs of KaTeX's own fonts, are
  drawn with the math font's glyph of the same symbol: `\not`'s slash as the combining long
  solidus moved right onto the relation after it, the negated and variant AMS relations as
  their Unicode characters (the variants through the font's `cv01` feature) or the math font's
  own glyphs of them, the dotless `ı` and `ȷ` of math italic as the mathematical italic ones.
  The math font's own private-use characters are other glyphs, so KaTeX's are never looked up
  as they are.
* A few glyphs sit elsewhere in New Computer Modern than in KaTeX's fonts and are placed
  where KaTeX's are (`placement`): `\surd`'s radical, which hangs below the baseline, and the
  short bars of `\shortmid` and its relatives, which the math font has only at full height.
* A character KaTeX's fonts lack takes the advance of the glyph that draws it
  (`fallbackAdvance`, for `DisplayOptions.fallbackAdvance`), as a browser's fallback font
  would give it.
* A character the chosen font lacks is looked up in the math font, then in the main text font;
  a glyph no font has is not drawn.

The outlines are not KaTeX's own fonts' (which LeAnTeX does not include): New Computer Modern's
glyphs differ from KaTeX's in places (`docs/back-ends.md`), while their positions are KaTeX's.

## Main definitions

* `FontSet`, `GlyphRef`, `FontSet.resolve`, `FontSet.placement`, `FontSet.fallbackAdvance`.
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

/-- KaTeX's private-use character `c` of face `face` as drawn with New Computer Modern Math:
the code point (one of the font's own private-use characters for the negated AMS relations
Unicode does not encode), the `GSUB` features applied to its glyph, and the shift right in
thousandths of an em that centres the glyph where KaTeX's is (see the module docstring);
`none` for every other character. -/
def privateUse (face : String) (c : Char) : Option (Nat × List String × Int) :=
  match face, c.toNat with
  -- `\not`: KaTeX's slash is centred 0.389 em right of the origin (0.4465 em in bold), New
  -- Computer Modern's combining solidus 0.2635 em left of it (0.2885 em in bold)
  | "Main-Regular", 0xE020 => some (0x0338, [], 653)
  | "Main-Bold", 0xE020 => some (0x0338, [], 735)
  | "Math-Italic", 0xE131 | "Math-BoldItalic", 0xE131 => some (0x1D6A4, [], 0)
  | "Math-Italic", 0xE237 | "Math-BoldItalic", 0xE237 => some (0x1D6A5, [], 0)
  | "AMS-Regular", n => match n with
    | 0xE006 => some (0x2224, [], 0)
    | 0xE007 => some (0x2226, [], 0)
    | 0xE00C => some (0x2268, ["cv01"], 0)
    | 0xE00D => some (0x2269, ["cv01"], 0)
    | 0xE00E => some (0xE0EA, [], 0)
    | 0xE00F => some (0xE1CC, [], 0)
    | 0xE010 => some (0xE1CB, [], 0)
    | 0xE011 => some (0xE0E9, [], 0)
    | 0xE016 => some (0xE20D, [], 0)
    | 0xE017 => some (0x2ACB, ["cv01"], 0)
    | 0xE018 => some (0xE20E, [], 0)
    | 0xE019 => some (0x2ACC, ["cv01"], 0)
    | 0xE01A => some (0x228A, ["cv01"], 0)
    | 0xE01B => some (0x228B, ["cv01"], 0)
    | _ => none
  | _, _ => none

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
      match privateUse name c with
      | some (m, feats, _) =>
        let bold := (name == "Main-Bold" || name == "Math-BoldItalic") &&
          fs.fonts.contains fs.mathBold
        let pu := if bold then fs.mathBold else fs.math
        (fs.glyphIn pu (Char.ofNat m)).map fun r =>
          match (fs.fonts[pu]?).bind (·.gsub), feats with
          | some t, _ :: _ => { r with glyph := (t.apply feats #[r.glyph])[0]?.getD r.glyph }
          | _, _ => r
      | none =>
        match mathAlphanumeric name c with
        | some m => (fs.glyphIn font m).orElse fun _ => fs.glyphWithFallback font c
        | none => fs.glyphWithFallback font c

/-- How the glyph `resolve` gives for `face` and `c` is placed against the display list's
glyph item: moved right by `dx` and up by `dy` (in the units of its font) and scaled
vertically by `yScale` thousandths about the baseline before it is moved
(`FontSet.placement`). -/
structure Placement where
  /-- The shift right, in font units. -/
  dx : Int := 0
  /-- The shift up, in font units. -/
  dy : Int := 0
  /-- The vertical scale, in thousandths. -/
  yScale : Nat := 1000
  deriving BEq, Inhabited, Repr

/-- The placement of the glyph `resolve` gives for `face` and `c`: the identity but for the
glyphs New Computer Modern draws elsewhere than KaTeX's fonts do (in thousandths of an em):
`\not`'s slash (`privateUse`), `\surd`, whose radical hangs below the baseline in the math
font (raised 0.76 em to KaTeX's place), and the short bars of `\shortmid`, `\shortparallel`
and their negations, which the math font has only at full height (scaled to KaTeX's height,
0.452 of it, and raised 0.092 em). -/
def placement (face : Face) (c : Char) : Placement :=
  let units := fun (v : Int) =>
    v * ((((fs.resolve face c).bind (fs.fonts[·.font]?)).map (·.unitsPerEm)).getD 1000 : Nat) /
      1000
  if face.font.isSome then {}
  else
    let name := face.katexName
    match name, c.toNat with
    | "Main-Regular", 0xE020 | "Main-Bold", 0xE020 =>
      match privateUse name c with
      | some (_, _, dx) => { dx := units dx }
      | none => {}
    | "Main-Regular", 0x221A => { dy := units 760 }
    | "AMS-Regular", 0x2223 | "AMS-Regular", 0x2225 | "AMS-Regular", 0xE006
    | "AMS-Regular", 0xE007 => { dy := units 92, yScale := 452 }
    | _, _ => {}

/-- The advance, in em of the glyph's size, of a character KaTeX's face `name` does not have,
as the font `resolve` draws it with gives it (`LeAnTeX.DisplayOptions.fallbackAdvance`): a
browser lays such a character out with its fallback font, and this back end draws it with that
glyph, so the layout leaves the glyph's own room for it. -/
def fallbackAdvance (name : String) (c : Char) : Option Em := do
  let family := (name.splitOn "-").headD name
  let style := ((name.splitOn "-").drop 1).headD "Regular"
  let face : Face := { family, bold := (style.splitOn "Bold").length > 1,
                       italic := (style.splitOn "Italic").length > 1 }
  let r ← fs.resolve face c
  let f ← fs.fonts[r.font]?
  return Em.ofRatio (f.advance r.glyph) f.unitsPerEm

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
