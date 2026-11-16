/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX

/-!
# `leantex-render`

Typesets a LaTeX fragment with the text layer and New Computer Modern, and writes it as SVG or
HTML.

```
lake exe leantex-render [--html] [--math] [--fonts DIR] [--font-url URL] FILE OUT
lake exe leantex-render --document [--external-css] [--fonts DIR] [--font-url URL]
  [--tfm DIR]… FILE OUTDIR
```

`--html` writes an HTML page (else an SVG picture); `--math` takes the file as one formula in
display mode instead of text. The fonts are read from `DIR` (default `fonts/newcomputermodern`);
`--font-url` is where the HTML page finds them (default `DIR`). Exit status 1 when the source
does not typeset (the error is printed with its position) or is a file too large to be
typeset (it is not read), 2 for bad usage or missing fonts.

`--document` typesets a whole LaTeX document (`\documentclass{article}`) and writes into
`OUTDIR`: `page-N.svg` for every page, `document.svg` (all pages), `document.html` (the pages
as sheets) and `web.html` (one continuous page); with `--external-css` the HTML files take
their positions from `document.css` and `web.css` instead of `style` attributes. Images
(`\includegraphics`) are read from the source file's directory only: a path that is not
relative, contains `..`, or leads (through a link) outside that directory is refused, as is a
file over 16 MiB. Formulas are set with TeX's own rules and the Computer Modern metric files
read from the directories `--tfm` names (by default those of `/usr/local/texlive/*`), when they
are there; else with the KaTeX-compatible layout. Without `--document`, `--tfm` is ignored
with a warning: a fragment's formulas are laid out by the KaTeX-compatible layout.
-/

open LeAnTeX LeAnTeX.Backend

/-- The options read from the command line. -/
structure Args where
  /-- Write HTML. -/
  html : Bool := false
  /-- Take the source as one display formula. -/
  math : Bool := false
  /-- The font directory. -/
  fonts : String := "fonts/newcomputermodern"
  /-- Where the HTML page finds the fonts, if not `fonts`. -/
  fontUrl : Option String := none
  /-- Typeset a whole document into a directory. -/
  document : Bool := false
  /-- Generated style sheets instead of `style` attributes. -/
  externalCss : Bool := false
  /-- The directories of the metric files (`--tfm`). -/
  tfm : Array String := #[]
  /-- The source file and the output file. -/
  files : List String := []

/-- Reads the command line. -/
def parseArgs : List String → Args → Option Args
  | [], a => some a
  | "--html" :: r, a => parseArgs r { a with html := true }
  | "--math" :: r, a => parseArgs r { a with math := true }
  | "--document" :: r, a => parseArgs r { a with document := true }
  | "--external-css" :: r, a => parseArgs r { a with externalCss := true }
  | "--fonts" :: d :: r, a => parseArgs r { a with fonts := d }
  | "--font-url" :: u :: r, a => parseArgs r { a with fontUrl := some u }
  | "--tfm" :: d :: r, a => parseArgs r { a with tfm := a.tfm.push d }
  | f :: r, a => if f.startsWith "--" then none else parseArgs r { a with files := a.files ++ [f] }

/-- The images of a document in `dir`: every file the source names that is a regular file
inside `dir` (its real path under `dir`'s), read whole up to `Settings.maxImage` bytes each and
`Settings.maxImagesTotal` together (a file named twice is read once; the files past the total
are left out, so the typesetter reports them). -/
def loadImages (dir : System.FilePath) (src : String) : IO (Std.HashMap String ByteArray) := do
  let root ← IO.FS.realPath dir
  let mut out : Std.HashMap String ByteArray := {}
  let mut total := 0
  let cfg : Text.Settings := {}
  for piece in (src.splitOn "\\includegraphics").drop 1 do
    let after := (piece.splitOn "{").drop 1
    let some p := after.head? | continue
    let p := ((p.splitOn "}").headD "").trimAscii.toString
    if !Text.Typeset.safeImagePath p || out.contains p then continue
    let f := dir / p
    if !(← f.pathExists) then continue
    let real ← IO.FS.realPath f
    if !(real.toString.startsWith (root.toString ++ "/")) then continue
    let md ← real.metadata
    if md.type != .file || md.byteSize.toNat > cfg.maxImage then continue
    if total + md.byteSize.toNat > cfg.maxImagesTotal then continue
    let bytes ← IO.FS.readBinFile real
    total := total + bytes.size
    out := out.insert p bytes
  return out

/-- The most bytes the files of one document may have together (512 MiB): the text of a document
is bounded by the typesetter's caps and each image is written once per file, so this is a last
guard, refused before anything is written. -/
def maxOutputBytes : Nat := 512 * 1024 * 1024

/-- Typesets a document into a directory (see the module docstring). -/
def renderDocument (fonts : Fonts) (a : Args) (src out : String) : IO UInt32 := do
  let .ok source ← readSource src
    | IO.eprintln s!"{terminalText src}: error: source too long"; return 1
  let dir := (System.FilePath.mk src).parent.getD "."
  let images ← loadImages dir source
  let dirs ← if a.tfm.isEmpty then TeXMath.texLiveTfmDirs else pure (a.tfm.map (⟨·⟩))
  let (tfms, refused) ← TeXMath.readTfmDirs dirs
  for r in refused do IO.eprintln s!"warning: metric file refused: {r}"
  let cfg : Text.Settings := { images := fun p => images[p]?, mathTfms := tfms }
  let title := (System.FilePath.mk src).fileStem.getD "document"
  match Doc.typesetDocument source fonts.resolver cfg,
      Doc.typesetDocument source fonts.resolver { cfg with continuous := true } with
  | .ok r, .ok web =>
    let pages := svgPages fonts.set r title
    let combined := svgCombined fonts.set r title
    let fontUrl := a.fontUrl.getD a.fonts
    let (html, css) := htmlPages fonts.set r
      { fontUrl, title, externalStyles := a.externalCss, styleUrl := "document.css" }
    let (wh, wc) := htmlPages fonts.set web
      { fontUrl, title, externalStyles := a.externalCss, styleUrl := "web.css" }
    let total := pages.foldl (· + ·.utf8ByteSize) 0 + combined.utf8ByteSize + html.utf8ByteSize +
      css.utf8ByteSize + wh.utf8ByteSize + wc.utf8ByteSize
    if total > maxOutputBytes then
      IO.eprintln s!"{terminalText src}: error: the output would have {total} bytes, more than \
        {maxOutputBytes}"
      return 1
    IO.FS.createDirAll out
    for h : k in [0:pages.size] do
      IO.FS.writeFile (System.FilePath.mk out / s!"page-{k + 1}.svg") pages[k]
    IO.FS.writeFile (System.FilePath.mk out / "document.svg") combined
    IO.FS.writeFile (System.FilePath.mk out / "document.html") html
    if a.externalCss then IO.FS.writeFile (System.FilePath.mk out / "document.css") css
    IO.FS.writeFile (System.FilePath.mk out / "web.html") wh
    if a.externalCss then IO.FS.writeFile (System.FilePath.mk out / "web.css") wc
    for w in r.warnings do IO.eprintln s!"{terminalText src}: warning: {terminalText w}"
    IO.println s!"{terminalText src}: {r.pages.size} pages, {r.passes} passes"
    return 0
  | .error e, _ | _, .error e =>
    IO.eprintln s!"{terminalText src}: error at character {e.pos}: {terminalText e.message}"
    return 1

/-- Renders the file named on the command line. -/
def main (argv : List String) : IO UInt32 := do
  let some a := parseArgs argv {} | IO.eprintln "leantex-render: bad option"; return 2
  let [src, out] := a.files
    | IO.eprintln "usage: leantex-render [--html] [--math] [--fonts DIR] [--font-url URL] \
        FILE OUT"
      return 2
  let (fonts, missing) ← Fonts.load a.fonts
  if !missing.isEmpty then
    for m in missing do IO.eprintln s!"leantex-render: font {terminalText m}"
    return 2
  if a.document then return ← renderDocument fonts a src out
  if !a.tfm.isEmpty then
    IO.eprintln "leantex-render: warning: --tfm applies to --document only; formulas here are \
      laid out by the KaTeX-compatible layout"
  let .ok source ← readSource src
    | IO.eprintln s!"{terminalText src}: error: source too long"; return 1
  let opts : RenderOptions := { html := a.html, math := a.math, fontUrl := a.fontUrl.getD a.fonts }
  match render fonts source opts with
  | .ok s => IO.FS.writeFile out s; return 0
  | .error (pos, msg) =>
    IO.eprintln s!"{terminalText src}: error at character {pos}: {terminalText msg}"; return 1
