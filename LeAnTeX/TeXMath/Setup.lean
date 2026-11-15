/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.TeXMath.Font
import LeAnTeX.TeXMath.Arith

/-!
# LaTeX's math fonts

The families LaTeX sets up for a formula at a size, in the setup the document fixtures are
recorded with (LuaLaTeX, the `article` class, `fontspec` with New Computer Modern for text,
TeX's default math fonts, optionally `amssymb`):

| Family | Font | Bold math version |
|---|---|---|
| 0 | the text font, upright (`\mathrm`, `\operatorname`) | its bold |
| 1 | `cmmi` (letters) | `cmmib` |
| 2 | `cmsy` (symbols, `\mathcal`) | `cmbsy` |
| 3 | `cmex` (large symbols) | `cmex` |
| 4, 5 | `msam`, `msbm` (`amssymb`; `\mathbb` is family 5) | the same |
| 6 | `cmr` (digits, `+`, `=`, delimiters, Greek capitals) | `cmbx` |
| 7–10 | the text font bold, italic, sans serif, typewriter (`\mathbf` … `\mathtt`) | |
| 11 | `eufm` (`\mathfrak`) | `eufb` |

The sizes are LaTeX's `\DeclareMathSizes` (text, script and scriptscript size for each text
size; 0.7 and 0.5 of it for an undeclared size), and each family's metric file at a size is
chosen as LaTeX's font definition files choose it (`ot1cmr.fd`, `omlcmm.fd`, `omscmsy.fd`,
`omxcmex.fd` or, with `amsfonts`, its own `cmex` sizes, `umsa.fd`, `umsb.fd`, `ueuf.fd`): a
design size, or the nearest design loaded at the size. A size the definition does not list is
replaced by the nearest it lists, as LaTeX substitutes it.

The metric files are not part of this library: `MathFontSet.ofFiles` reads them from bytes the
caller supplies (from a TeX installation).

## Main definitions

* `mathSizes`: LaTeX's math sizes for a text size.
* `tfmFor`: the metric file and size of a family at a size.
* `MathFontSet`, `MathFontSet.families`.

## References

* LaTeX's `fontmath.ltx` (`\DeclareMathSizes`) and the font definition files named above, and
  `amsfonts.sty`, read from TeX Live; recordings of LuaLaTeX (`tools/math-box-reference.sh`).
-/

namespace LeAnTeX.TeXMath

open LeAnTeX.Text (FontKey TextFont)

/-- A length in points with two decimals, `p` hundredths of a point, as TeX reads `p/100 pt`
(TeX's decimal rounding). -/
def ptHundredths (p : Nat) : Int :=
  let whole := p / 100
  let frac := p % 100
  -- TeX's round_decimals on two digits d1 d2: ((d1·2¹⁷/10 + d2·2¹⁷/100) rounded) / 2
  let a := (frac % 10) * 131072
  let a := (a / 10 + (frac / 10) * 131072) / 10
  (whole * 65536 : Nat) + (a + 1) / 2

/-- LaTeX's declared math sizes, in hundredths of a point: text size, script, scriptscript. -/
def declaredMathSizes : List (Nat × Nat × Nat) :=
  [(500, 500, 500), (600, 500, 500), (700, 500, 500), (800, 600, 500), (900, 600, 500),
   (1000, 700, 500), (1095, 800, 600), (1200, 800, 600), (1440, 1000, 700),
   (1728, 1200, 1000), (2074, 1440, 1200), (2488, 2074, 1728)]

/-- The script and scriptscript sizes (sp) LaTeX gives a formula at text size `size` (sp):
the declared ones, or 0.7 and 0.5 of the size. -/
def mathSizes (size : Int) : Int × Int × Int :=
  match declaredMathSizes.find? (fun (t, _, _) => ptHundredths t == size) with
  | some (_, s, ss) => (size, ptHundredths s, ptHundredths ss)
  | none => (size, xnOverD size 45875 65536, xnOverD size 32768 65536)

/-- The sizes a font definition lists, in hundredths of a point. -/
def fdSizes : List Nat := [500, 600, 700, 800, 900, 1000, 1095, 1200, 1440, 1728, 2074, 2488]

/-- The listed size nearest to `size` (sp), in hundredths of a point (the smaller of two equally
near). -/
def nearestFdSize (size : Int) : Nat :=
  fdSizes.foldl (init := 1000) fun best s =>
    if (ptHundredths s - size).natAbs < (ptHundredths best - size).natAbs then s else best

/-- A family's font kind, by the table in the module docstring. -/
inductive MathFace where
  /-- `cmr` (or `cmbx` in bold). -/
  | cmr
  /-- `cmmi` (`cmmib`). -/
  | cmmi
  /-- `cmsy` (`cmbsy`). -/
  | cmsy
  /-- `cmex`. -/
  | cmex
  /-- `msam`. -/
  | msam
  /-- `msbm`. -/
  | msbm
  /-- `eufm` (`eufb`). -/
  | eufm
  deriving BEq, Inhabited

/-- The metric file and the size (sp) LaTeX loads for a face at size `size` (sp), in the bold
math version when `bold`; `amsfonts` when `amsfonts.sty` is loaded (its own sizes of `cmex`). -/
def tfmFor (face : MathFace) (size : Int) (bold amsfonts : Bool) : String × Int :=
  -- a range font definition (cmex with amsfonts, the AMS fonts) takes any size
  let range := fun (cuts : List (Nat × String)) (last : String) =>
    let n := (cuts.find? (fun (c, _) => size < ptHundredths c)).map (·.2) |>.getD last
    (n, size)
  match face with
  | .cmex =>
    if amsfonts then range [(750, "cmex7"), (850, "cmex8"), (950, "cmex9")] "cmex10"
    else ("cmex10", 10 * 65536)
  | .msam => range [(600, "msam5"), (800, "msam7")] "msam10"
  | .msbm => range [(600, "msbm5"), (800, "msbm7")] "msbm10"
  | .eufm =>
    let b := if bold then "eufb" else "eufm"
    range [(600, b ++ "5"), (800, b ++ "7")] (b ++ "10")
  | _ =>
    let s := nearestFdSize size
    let at_ := ptHundredths s
    let gen := fun (p : String) => p ++ toString (s / 100)
    let n := match face, bold with
      | .cmr, false =>
        if s ≤ 1000 || s == 1200 then gen "cmr" else if s == 1095 then "cmr10"
        else if s == 1440 then "cmr12" else "cmr17"
      | .cmr, true => if s ≤ 900 then gen "cmbx" else if s ≤ 1095 then "cmbx10" else "cmbx12"
      | .cmmi, false => if s ≤ 900 then gen "cmmi" else if s ≤ 1095 then "cmmi10" else "cmmi12"
      | .cmmi, true => if s ≤ 900 then gen "cmmib" else "cmmib10"
      | .cmsy, false => if s ≤ 1000 then gen "cmsy" else "cmsy10"
      | .cmsy, true => if s ≤ 900 then gen "cmbsy" else "cmbsy10"
      | _, _ => "cmr10"
    (n, at_)

/-- The metric files a setup may load. -/
def mathTfmNames : List String :=
  (["cmr", "cmbx", "cmmi", "cmmib", "cmsy", "cmbsy"].flatMap fun p =>
    ["5", "6", "7", "8", "9", "10"].map (p ++ ·)) ++
  ["cmr12", "cmr17", "cmbx12", "cmmi12", "cmex7", "cmex8", "cmex9", "cmex10"] ++
  (["msam", "msbm", "eufm", "eufb"].flatMap fun p => ["5", "7", "10"].map (p ++ ·))

/-- The fonts LaTeX's math setup uses: the metric files read, the text fonts (the text layer's,
at a size, with their index in its table of fonts), and the options. -/
structure MathFontSet where
  /-- The metric files read, by name. -/
  tfms : Std.HashMap String Tfm := {}
  /-- The text layer's font for a key (`none` if it has none). -/
  text : FontKey → Option TextFont := fun _ => none
  /-- Whether `amsfonts.sty` (`amssymb`) is loaded. -/
  amsfonts : Bool := true
  /-- The bold math version (`\boldmath`). -/
  bold : Bool := false

/-- Reads the metric files of `mathTfmNames` with `read` (by name, without extension): the set,
or the first file that fails its checks. A file `read` does not supply is left out (a formula
needing it fails). -/
def MathFontSet.ofFiles (read : String → Option ByteArray) :
    Except String MathFontSet := do
  let mut tfms : Std.HashMap String Tfm := {}
  for n in mathTfmNames do
    if let some b := read n then
      match Tfm.read b with
      | .ok t => tfms := tfms.insert n t
      | .error e => throw s!"{n}.tfm: {e}"
  return { tfms := tfms }

/-- The skew character LaTeX's font families give their fonts (`\skewchar`): 127 for `cmmi`,
48 for `cmsy`. -/
def skewOf : MathFace → Option Nat
  | .cmmi => some 127
  | .cmsy => some 48
  | _ => none

/-- The families of a formula at text size `size` (sp): every family of the table in the
module docstring at the three math sizes. A metric file the set lacks is an error. -/
def MathFontSet.families (m : MathFontSet) (size : Int) : Except String Families := do
  let (t, s, ss) := mathSizes size
  let sizes : Array Int := #[t, s, ss]
  let mut fs : Families := {}
  let tfmFaces : List (Nat × MathFace) :=
    [(1, .cmmi), (2, .cmsy), (3, .cmex), (4, .msam), (5, .msbm), (6, .cmr), (11, .eufm)]
  for (fam, face) in tfmFaces do
    for k in [0:3] do
      let sz := sizes.getD k t
      let (name, at_) := tfmFor face sz m.bold m.amsfonts
      match m.tfms.get? name with
      | none => if fam ≤ 3 || fam == 6 then throw s!"metric file {name}.tfm not available"
      | some tfm =>
        let f ← match tfm.at name (some at_) (skewOf face) with
          | .ok f => pure f
          | .error e => throw s!"{name}: {e}"
        let (fs', i) := fs.addFont (.tfm f)
        fs := fs'.set fam ⟨k % 3, Nat.mod_lt _ (by omega)⟩ i
  let textFaces : List (Nat × FontKey) :=
    [(0, { bold := m.bold }), (7, { bold := true }), (8, { shape := .italic, bold := m.bold }),
     (9, { family := .sans, bold := m.bold }), (10, { family := .mono, bold := m.bold })]
  for (fam, key) in textFaces do
    for k in [0:3] do
      let sz := sizes.getD k t
      if let some tf := m.text { key with size := sz } then
        let (fs', i) := fs.addFont (.otf tf)
        fs := fs'.set fam ⟨k % 3, Nat.mod_lt _ (by omega)⟩ i
  return fs

end LeAnTeX.TeXMath
