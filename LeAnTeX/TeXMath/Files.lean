/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.TeXMath.Setup

/-!
# Metric files from a TeX installation

The Computer Modern and AMS metric files are not part of this library; a program that wants
TeX's formula boxes reads them from a TeX installation. `readTfmDirs` looks for each file of
`mathTfmNames` in the directories given (the first that has it) and reads it, at most
`maxTfmBytes` bytes; a file that fails the reader's checks is left out with its error.

## Main definitions

* `texLiveTfmDirs`: the directories of the metric files in `/usr/local/texlive/*`.
* `readTfmDirs`: the metric files found, read and checked.
-/

namespace LeAnTeX.TeXMath

/-- The largest metric file read (TeX's own limit on a font's words is far below). -/
def maxTfmBytes : Nat := 1048576

/-- The directories of the Computer Modern and AMS metric files of every TeX Live under
`root` (`/usr/local/texlive` by default): `texmf-dist/fonts/tfm/public/{cm, amsfonts/cmextra,
amsfonts/symbols, amsfonts/euler}`. -/
def texLiveTfmDirs (root : System.FilePath := "/usr/local/texlive") :
    IO (Array System.FilePath) := do
  if !(← root.isDir) then return #[]
  let mut out := #[]
  for e in ← root.readDir do
    let t := e.path / "texmf-dist" / "fonts" / "tfm" / "public"
    for sub in ["cm", "amsfonts/cmextra", "amsfonts/symbols", "amsfonts/euler"] do
      if ← (t / sub).isDir then out := out.push (t / sub)
  return out

/-- The metric files of `mathTfmNames` found in `dirs` (the first directory that has a file
wins), read and checked, and the files that were refused, with the reason. -/
def readTfmDirs (dirs : Array System.FilePath) :
    IO (Std.HashMap String Tfm × Array String) := do
  let mut out : Std.HashMap String Tfm := {}
  let mut refused := #[]
  for n in mathTfmNames do
    for d in dirs do
      let p := d / (n ++ ".tfm")
      if !(← p.pathExists) then continue
      if (← p.metadata).byteSize.toNat > maxTfmBytes then
        refused := refused.push s!"{p}: larger than {maxTfmBytes} bytes"; break
      match Tfm.read (← IO.FS.readBinFile p) with
      | .ok t => out := out.insert n t
      | .error e => refused := refused.push s!"{p}: {e}"
      break
  return (out, refused)

end LeAnTeX.TeXMath
