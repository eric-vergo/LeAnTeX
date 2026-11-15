/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Text.Typeset

/-!
# New Computer Modern's files

Which New Computer Modern OpenType file the text layer uses for a font, as the package's own
`fontspec` files (`NewCM10-Book.fontspec`, `NewCMSans10-Book.fontspec`,
`NewCMMono10-Book.fontspec`) choose them for its default, the Book weight:

* **Optical sizes.** The roman and sans upright and italic shapes come in 8-point and 10-point
  designs; sizes up to 8 points take the 8-point design, larger ones the 10-point one. Bold
  and typewriter have the 10-point design only.
* **Shapes.** Roman italic is `BookItalic`; sans italic is its oblique; typewriter italic is
  `BookItalic` (bold: `BoldOblique`). **Slanted** is the upright font with a slant of 0.25
  drawn onto it (`FakeSlant=0.25`); **small capitals** are the upright font's `smcp` feature.
* **Bold** is `Bold` (the package has one bold weight), with `BoldItalic` (roman) or
  `BoldOblique` (sans, typewriter).

The repository's `fonts/newcomputermodern/` holds these files (the fonts under the GUST Font
License); `NewCM10-Regular`, the one roman file under another licence, is never used: the
Regular weight's other files are the package's alternative to the Book weight, which is the
default.

## Main definitions

* `NcmFace`, `newComputerModernFace`: the file, slant and small capitals for a font key.
* `newComputerModernFiles`: every file a key can name.
* `newComputerModernResolver`: a `FontResolver` over fonts read from those files.
-/

namespace LeAnTeX.Text

/-- A font of New Computer Modern for a key: the file (without `.otf`), the slant to draw onto
it, in thousandths, and whether small capitals are wanted. -/
structure NcmFace where
  /-- The file name without `.otf`. -/
  file : String
  /-- The slant, in thousandths (250 for the slanted shape). -/
  slant : Int := 0
  /-- Whether the text is set in small capitals. -/
  smallCaps : Bool := false
  deriving BEq, Repr, Inhabited

/-- Whether a size (sp) takes the 8-point design: up to and including 8 points. -/
def ncmSmall (size : Int) : Bool := size ≤ 8 * 65536

/-- The New Computer Modern font for a key (see the module docstring). -/
def newComputerModernFace (k : FontKey) : NcmFace :=
  let opt := fun (base : String) => if ncmSmall k.size then s!"{base}08" else s!"{base}10"
  match k.family, k.bold, k.shape with
  | .roman, false, .upright => ⟨opt "NewCM" ++ "-Book", 0, false⟩
  | .roman, false, .italic => ⟨opt "NewCM" ++ "-BookItalic", 0, false⟩
  | .roman, false, .slanted => ⟨opt "NewCM" ++ "-Book", 250, false⟩
  | .roman, false, .caps => ⟨opt "NewCM" ++ "-Book", 0, true⟩
  | .roman, true, .upright => ⟨"NewCM10-Bold", 0, false⟩
  | .roman, true, .italic => ⟨"NewCM10-BoldItalic", 0, false⟩
  | .roman, true, .slanted => ⟨"NewCM10-Bold", 250, false⟩
  | .roman, true, .caps => ⟨"NewCM10-Bold", 0, true⟩
  | .sans, false, .upright => ⟨opt "NewCMSans" ++ "-Book", 0, false⟩
  | .sans, false, .italic => ⟨opt "NewCMSans" ++ "-BookOblique", 0, false⟩
  | .sans, false, .slanted => ⟨opt "NewCMSans" ++ "-Book", 250, false⟩
  | .sans, false, .caps => ⟨opt "NewCMSans" ++ "-Book", 0, true⟩
  | .sans, true, .upright => ⟨"NewCMSans10-Bold", 0, false⟩
  | .sans, true, .italic => ⟨"NewCMSans10-BoldOblique", 0, false⟩
  | .sans, true, .slanted => ⟨"NewCMSans10-Bold", 250, false⟩
  | .sans, true, .caps => ⟨"NewCMSans10-Bold", 0, true⟩
  | .mono, false, .upright => ⟨"NewCMMono10-Book", 0, false⟩
  | .mono, false, .italic => ⟨"NewCMMono10-BookItalic", 0, false⟩
  | .mono, false, .slanted => ⟨"NewCMMono10-Book", 250, false⟩
  | .mono, false, .caps => ⟨"NewCMMono10-Book", 0, true⟩
  | .mono, true, .upright => ⟨"NewCMMono10-Bold", 0, false⟩
  | .mono, true, .italic => ⟨"NewCMMono10-BoldOblique", 0, false⟩
  | .mono, true, .slanted => ⟨"NewCMMono10-Bold", 250, false⟩
  | .mono, true, .caps => ⟨"NewCMMono10-Bold", 0, true⟩

/-- Every file `newComputerModernFace` can name, without `.otf`. -/
def newComputerModernFiles : List String :=
  ["NewCM08-Book", "NewCM08-BookItalic", "NewCM10-Book", "NewCM10-BookItalic", "NewCM10-Bold",
    "NewCM10-BoldItalic", "NewCMSans08-Book", "NewCMSans08-BookOblique", "NewCMSans10-Book",
    "NewCMSans10-BookOblique", "NewCMSans10-Bold", "NewCMSans10-BoldOblique",
    "NewCMMono10-Book", "NewCMMono10-BookItalic", "NewCMMono10-Bold",
    "NewCMMono10-BoldOblique"]

/-- A resolver over fonts read from New Computer Modern's files, by file name without `.otf`:
the key's font with its slant and small capitals, `none` if its file is missing. The font's
name (`FontInfo.name`) is its file name with `.otf`. -/
def newComputerModernResolver (fonts : Std.HashMap String FontInfo) : FontResolver := fun k =>
  let face := newComputerModernFace k
  fonts[face.file]?.map fun i => { i with slant := face.slant, smallCaps := face.smallCaps }

end LeAnTeX.Text
