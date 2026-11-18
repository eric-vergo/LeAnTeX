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
