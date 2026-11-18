/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import VersoManual
import LeAnTeXManual
import LeAnTeXManual.Style

/-!
# `leantex-manual`: write the manual's web site

`lake exe leantex-manual` (run in `manual/`) writes the site to `_out/html-multi`; the options
are Verso's (`manualMain`; `--output DIR` writes elsewhere). This file adds the configuration:

* the stylesheet of `LeAnTeXManual.Style`;
* the fonts the HTML samples load (`LeAnTeXManual.siteFonts`), copied from the repository's
  `fonts/newcomputermodern` into the site's `fonts/` folder after the pages are written;
* the footer: a link to the repository and the licence;
* no KaTeX: the manual's formulas are LeAnTeX's own pictures.

The pictures were made when the pages were elaborated (`LeAnTeXManual.Meta`); writing the site
typesets nothing.
-/

open Verso.Genre.Manual

/-- The footer of every page (raw HTML). -/
def footer : String :=
  s!"<footer class=\"ltx-footer\">LeAnTeX · \
    <a href=\"{LeAnTeXManual.repositoryUrl}\">Source</a> · Apache License 2.0 · every picture \
    in this manual was typeset by LeAnTeX when the manual was built</footer>"

/-- The manual's configuration. -/
def config : RenderConfig :=
  let base : RenderConfig := {}
  { base with
    htmlDepth := 2
    extraContents := base.extraContents.push (.text false footer)
    extraCss := base.extraCss.insert ⟨LeAnTeXManual.css⟩
    sourceLink := some LeAnTeXManual.repositoryUrl
    issueLink := some (LeAnTeXManual.repositoryUrl ++ "/issues")
    sectionTocDepth := some 2
    rootTocDepth := some 1 }

/-- The output folder Verso's options name (`--output DIR`, default `_out`). -/
def outputDir : List String → System.FilePath
  | "--output" :: d :: _ => d
  | _ :: more => outputDir more
  | [] => "_out"

/-- Copies the HTML samples' fonts into the written site. -/
def copyFonts (out : System.FilePath) : IO Unit := do
  let root ← LeAnTeXManual.repoRoot
  let dest := out / "html-multi" / "fonts"
  IO.FS.createDirAll dest
  for f in LeAnTeXManual.siteFonts do
    let bytes ← IO.FS.readBinFile (root / "fonts" / "newcomputermodern" / f)
    IO.FS.writeBinFile (dest / f) bytes

/-- Writes the site, then the fonts its HTML samples load. -/
def main (args : List String) : IO UInt32 := do
  let code ← manualMain (%doc LeAnTeXManual) (options := args) (config := config)
  if code == 0 then copyFonts (outputDir args)
  return code
