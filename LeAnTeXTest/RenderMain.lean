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
```

`--html` writes an HTML page (else an SVG picture); `--math` takes the file as one formula in
display mode instead of text. The fonts are read from `DIR` (default `fonts/newcomputermodern`);
`--font-url` is where the HTML page finds them (default `DIR`). Exit status 1 when the source
does not typeset (the error is printed with its position), 2 for bad usage or missing fonts.
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
  /-- The source file and the output file. -/
  files : List String := []

/-- Reads the command line. -/
def parseArgs : List String → Args → Option Args
  | [], a => some a
  | "--html" :: r, a => parseArgs r { a with html := true }
  | "--math" :: r, a => parseArgs r { a with math := true }
  | "--fonts" :: d :: r, a => parseArgs r { a with fonts := d }
  | "--font-url" :: u :: r, a => parseArgs r { a with fontUrl := some u }
  | f :: r, a => if f.startsWith "--" then none else parseArgs r { a with files := a.files ++ [f] }

/-- Renders the file named on the command line. -/
def main (argv : List String) : IO UInt32 := do
  let some a := parseArgs argv {} | IO.eprintln "leantex-render: bad option"; return 2
  let [src, out] := a.files
    | IO.eprintln "usage: leantex-render [--html] [--math] [--fonts DIR] [--font-url URL] \
        FILE OUT"
      return 2
  let (fonts, missing) ← Fonts.load a.fonts
  if !missing.isEmpty then
    for m in missing do IO.eprintln s!"leantex-render: font {m}"
    return 2
  let source ← IO.FS.readFile src
  let opts : RenderOptions := { html := a.html, math := a.math, fontUrl := a.fontUrl.getD a.fonts }
  match render fonts source opts with
  | .ok s => IO.FS.writeFile out s; return 0
  | .error (pos, msg) => IO.eprintln s!"{src}: error at character {pos}: {msg}"; return 1
