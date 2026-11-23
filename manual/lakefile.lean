/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import Lake

/-!
# LeAnTeX's manual

The Verso manual of LeAnTeX: the library `LeAnTeXManual` holds the pages, and the executable
`leantex-manual` writes them as a web site (`lake exe leantex-manual`, run in this folder, writes
`_out/html-multi`).

The pages typeset their samples with LeAnTeX while they are elaborated, so every picture in the
manual is the library's own output for the source beside it. To make that fast, the library is
loaded into the elaborator as the shared library Lake builds for it (`leantexShared`): the
interpreter then calls LeAnTeX's compiled code instead of interpreting it.
-/

open Lake DSL

package «leantex-manual» where
  leanOptions := #[⟨`autoImplicit, false⟩, ⟨`weak.verso.code.warnLineLength, .ofNat 90⟩]

require leantex from ".."
require subverso from git "https://github.com/eric-vergo/subverso" @ "release/verso-v4.35.0"
require verso from git "https://github.com/eric-vergo/verso" @ "sbs"

/-- The LeAnTeX library as a shared library, loaded while the pages are elaborated. -/
target leantexShared : Dynlib := do
  let some lib ← findLeanLib? `LeAnTeX
    | error "the library `LeAnTeX` of the package `leantex` is not in the workspace"
  lib.shared.fetch

/-- The repository's files the pages read while they are elaborated (quoted documents, notices,
licence texts, the allow-list of the API reference, and the fonts the samples are typeset
with). -/
def manualInputFiles (root : System.FilePath) : IO (Array System.FilePath) := do
  let mut out : Array System.FilePath := #[]
  for f in ["README.md", "THIRD-PARTY.md", "LICENSE", "LICENSE-KaTeX", "LICENSE-KaTeX-fonts",
      "lean-toolchain", "fonts/README.md", "fonts/MANIFEST.tsv", "fonts/GUST-FONT-LICENSE.txt",
      "fonts/LPPL-1.3c.txt", "fonts/newcomputermodern/License.txt", "manual/api-allow.txt"] do
    out := out.push (root / f)
  for e in ← (root / "docs").readDir do
    if e.fileName.endsWith ".md" then out := out.push e.path
  for e in ← (root / "fonts" / "newcomputermodern").readDir do
    if e.fileName.endsWith ".otf" then out := out.push e.path
  return out.qsort (·.toString < ·.toString)

/-- Writes `LeAnTeXManualInputs.lean` below the build folder: a hash of `manualInputFiles`. The
pages import it, so that Lake elaborates them again when one of those files changes, although
it does not know that a page reads them. The file is rewritten only when the hash changes. -/
target manualInputs : Unit := do
  let pkg ← getRootPackage
  let root := pkg.dir / ".."
  let files ← manualInputFiles root
  let mut h : UInt64 := 7
  for f in files do
    h := mixHash h (hash f.fileName)
    h := mixHash h (hash (← IO.FS.readBinFile f))
  let dir := pkg.buildDir / "manual-inputs"
  let file := dir / "LeAnTeXManualInputs.lean"
  let text := "/-- A hash of the repository files the manual's pages read. -/\n" ++
    s!"def LeAnTeXManualInputs.hash : UInt64 := {h}\n"
  IO.FS.createDirAll dir
  let old ← if ← file.pathExists then some <$> IO.FS.readFile file else pure none
  unless old == some text do IO.FS.writeFile file text
  return .pure ()

/-- The generated module of `manualInputs`. -/
lean_lib LeAnTeXManualInputs where
  srcDir := ".lake/build/manual-inputs"
  roots := #[`LeAnTeXManualInputs]
  needs := #[manualInputs]

lean_lib LeAnTeXManual where
  roots := #[`LeAnTeXManual]
  globs := #[.andSubmodules `LeAnTeXManual]
  dynlibs := #[leantexShared]

/-- Writes the site. The agreement chapter runs LeAnTeX's test driver when the site is written,
so the driver (and the programs it runs) are built first. -/
@[default_target]
lean_exe «leantex-manual» where
  root := `Main
  needs := #[`@leantex/«leantex-test»]

/-- Writes the API reference's pages (`ApiGen.lean`); `--check` compares instead. -/
lean_exe «leantex-manual-api» where
  root := `ApiGen
