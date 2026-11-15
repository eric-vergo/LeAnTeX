/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeXTest.TypesetChecks

/-!
# `leantex-typeset`

Typesets a LaTeX source file with LeAnTeX's text layer and prints its display list in the
stable text form of `DisplayList.textForm`.

```
lake exe leantex-typeset FILE          # Latin Modern from TeX Live, else the test font
lake exe leantex-typeset --test-fonts FILE
```

Exit status 1 when the source does not typeset (the error is printed), 2 for bad usage.
-/

open LeAnTeX LeAnTeX.Text

/-- Typesets the file named on the command line. -/
def main (args : List String) : IO UInt32 := do
  let (test, file) := match args with
    | ["--test-fonts", f] => (true, some f)
    | [f] => (false, some f)
    | _ => (false, none)
  let some file := file
    | IO.eprintln "usage: leantex-typeset [--test-fonts] FILE"; return 2
  let res ← if test then TypesetChecks.testFonts else
    match ← FrontChecks.latinModern with
    | some r => pure r
    | none => TypesetChecks.testFonts
  match typeset (← IO.FS.readFile file) res with
  | .ok d =>
    IO.print d.toDisplayList.textForm
    for w in d.warnings do IO.eprintln s!"warning: {w}"
    return 0
  | .error e =>
    IO.eprintln s!"{file}: error at character {e.pos}: {e.message}"
    return 1
