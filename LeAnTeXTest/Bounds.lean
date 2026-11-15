/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX
import LeAnTeXTest.JsonParse

/-!
# Bounded work on hostile sources

The command-line programs are run as a user runs them, in child processes under a CPU-time
limit and a wall-clock watchdog, on sources made to cost as much as the caps allow, and their
peak resident memory and CPU time are measured with `/usr/bin/time`. A check fails if a child is
killed, gives the wrong answer (a result, or an error naming the cap), or uses more memory or
CPU time than its bound. The bounds are far above what the programs take and far below what
unbounded work takes on these sources (minutes, or gigabytes).

The sources are in `fixtures/hostile/` or generated here (the large ones and the images).

## Main definitions

* `Run`, `runLimited`: a child under limits, and what it used.
* `ioChecks`: the checks; `checks`: the ones that need no child.
-/

namespace LeAnTeXTest.Bounds

open LeAnTeX LeAnTeX.Backend

/-- What a child used. -/
structure Run where
  /-- The exit status, or none if the watchdog killed it. -/
  status : Option UInt32
  /-- Its standard output. -/
  out : String
  /-- Its standard error. -/
  err : String
  /-- The peak resident memory in bytes, if `/usr/bin/time` reported it. -/
  rss : Option Nat
  /-- The user CPU time in milliseconds, if reported. -/
  userMs : Option Nat

/-- The number in the line of `/usr/bin/time` output that has `label`: the first word of the
line (`before`) or the last. -/
def timeField (txt label : String) (before : Bool) : Option Nat := Id.run do
  for l in txt.splitOn "\n" do
    if (l.splitOn label).length > 1 then
      let ws := (l.splitOn " ").filter (!·.isEmpty)
      return (if before then ws.head? else ws.getLast?).bind String.toNat?
  return none

/-- A decimal number of seconds such as `9.20` in milliseconds. -/
def secondsMs (s : String) : Option Nat :=
  match s.splitOn "." with
  | [a] => a.toNat?.map (· * 1000)
  | [a, b] => do
    let f := (b ++ "000").take 3
    return (← a.toNat?) * 1000 + (← f.toString.toNat?)
  | _ => none

/-- The user time from `/usr/bin/time` output (`-l` on macOS, `-v` elsewhere). -/
def userTime (txt : String) : Option Nat := Id.run do
  for l in txt.splitOn "\n" do
    let ws := (l.splitOn " ").filter (!·.isEmpty)
    if let some i := ws.idxOf? "user" then
      if i > 0 then return ws[i - 1]?.bind secondsMs
    if (l.splitOn "User time (seconds):").length > 1 then return ws.getLast?.bind secondsMs
  return none

/-- Runs `exe` (a sibling of the test driver) with `args` in its own process group under a CPU
limit of `cpuS` seconds, killed after `wallMs` milliseconds, measured with `/usr/bin/time`. -/
def runLimited (exe : String) (args : Array String) (cpuS wallMs : Nat)
    (scratch : System.FilePath) : IO Run := do
  let app := ((← IO.appPath).parent.getD ".") / exe
  let outF := scratch / "child.out"
  let errF := scratch / "child.err"
  let timeF := scratch / "child.time"
  let mac := System.Platform.isOSX
  let flag := if mac then "-l" else "-v"
  let script := s!"ulimit -t {cpuS}; o=$1; e=$2; t=$3; shift 3; export o e; " ++
    s!"exec /usr/bin/time {flag} /bin/sh -c 'exec \"$@\" > \"$o\" 2> \"$e\"' sh \"$@\" " ++
    "2> \"$t\""
  let shArgs := #["-c", script, "sh", outF.toString, errF.toString, timeF.toString,
    app.toString] ++ args
  let child ← IO.Process.spawn { cmd := "/bin/sh", args := shArgs, setsid := true }
  let mut status : Option UInt32 := none
  for _ in [0:wallMs / 50 + 1] do
    if let some s ← child.tryWait then
      status := some s
      break
    IO.sleep 50
  if status.isNone then
    child.kill
    let _ ← child.wait
  let out ← try IO.FS.readFile outF catch _ => pure ""
  let err ← try IO.FS.readFile errF catch _ => pure ""
  let tm ← try IO.FS.readFile timeF catch _ => pure ""
  let rss := if mac then timeField tm "maximum resident set size" true
    else (timeField tm "Maximum resident set size" false).map (· * 1024)
  return { status := status, out := out, err := err, rss := rss, userMs := userTime tm }

/-- A PNG of 1 × 1 pixel padded with a `tEXt` chunk to about `n` bytes (CRCs left wrong: the
typesetter reads only the size from `IHDR`). -/
def paddedPng (n : Nat) : ByteArray := Id.run do
  let sig : ByteArray := ⟨#[137, 80, 78, 71, 13, 10, 26, 10]⟩
  let be := fun (v : Nat) => (ByteArray.mk #[(v >>> 24).toUInt8, (v >>> 16).toUInt8,
    (v >>> 8).toUInt8, v.toUInt8])
  let ihdr := be 13 ++ "IHDR".toUTF8 ++ be 1 ++ be 1 ++ ⟨#[8, 0, 0, 0, 0]⟩ ++ be 0
  let mut pad := ByteArray.emptyWithCapacity n
  for _ in [0:n] do pad := pad.push 120
  return sig ++ ihdr ++ be n ++ "tEXt".toUTF8 ++ pad ++ be 0

/-- One case: the program, its arguments (`@` stands for the scratch folder), the files to
write into the scratch folder first, the expected text in the output or the error, and the
bounds. -/
structure Case where
  /-- The case's name. -/
  name : String
  /-- The program. -/
  exe : String
  /-- Its arguments; an argument starting with `@/` is a path in the scratch folder. -/
  args : Array String
  /-- Files to write first: a name in the scratch folder and the bytes. -/
  files : Unit → Array (String × ByteArray) := fun _ => #[]
  /-- Text the standard output or error must contain. -/
  expect : String
  /-- The bound on peak resident memory, in bytes. -/
  maxRss : Nat := 400 <<< 20
  /-- The bound on user CPU time, in milliseconds. -/
  maxUserMs : Nat := 30000

/-- The fonts `leantex-render` reads. -/
def fontDir : String := "fonts/newcomputermodern"

/-- A source repeated: `s` written `n` times. -/
def rep (s : String) (n : Nat) : String := String.join (List.replicate n s)

/-- The cases. -/
def cases : Array Case := #[
  { name := "line breaking: thousands of active breakpoints stop at the step budget",
    exe := "leantex-typeset", args := #["--test-fonts", "fixtures/hostile/many-actives.tex"],
    expect := "too costly to break" },
  { name := "line breaking: the same in a document stops at the step budget",
    exe := "leantex-render",
    args := #["--document", "--fonts", fontDir, "fixtures/hostile/many-actives-doc.tex", "@/o1"],
    expect := "too costly to break" },
  { name := "hyphenation: one word of 8800 letters in linear time",
    exe := "leantex-typeset", args := #["--test-fonts", "@/word.tex"],
    files := fun _ => #[("word.tex", ("\\hsize=100pt " ++ rep "hyphenation" 800).toUTF8)],
    expect := "display width", maxUserMs := 15000 },
  { name := "hyphenation: a run of 30000 explicit hyphens in linear time",
    exe := "leantex-typeset", args := #["--test-fonts", "@/hyphens.tex"],
    files := fun _ => #[("hyphens.tex", ("\\hsize=100pt " ++ rep "ab-" 30000).toUTF8)],
    expect := "display width", maxUserMs := 15000 },
  { name := "formula: macros that expand past the token cap (math mode)",
    exe := "leantex-render", args := #["--math", "--fonts", fontDir, "@/m.tex", "@/m.svg"],
    files := fun _ => #[("m.tex", ("\\def\\a{" ++ rep "x" 4000 ++ "}" ++ rep "\\a" 1000).toUTF8)],
    expect := "Too many tokens" },
  { name := "formula: the same inside $…$ in text",
    exe := "leantex-typeset", args := #["--test-fonts", "@/mt.tex"],
    files := fun _ => #[("mt.tex",
      ("$\\def\\a{" ++ rep "x" 4000 ++ "}" ++ rep "\\a" 1000 ++ "$").toUTF8)],
    expect := "Too many tokens" },
  { name := "TeX-rule layout: nested \\sqrt[n], each level built in four styles, stays bounded",
    exe := "leantex-render", args := #["--document", "--fonts", fontDir, "@/root.tex", "@/o3"],
    files := fun _ => #[("root.tex", ("\\documentclass{article}\\begin{document}$" ++
      rep "\\sqrt[3]{" 12 ++ "x" ++ rep "}" 12 ++ "$\\end{document}").toUTF8)],
    expect := "pages" },
  { name := "TeX-rule layout: a paragraph of 3000 breakable formulas in linear time",
    exe := "leantex-render", args := #["--document", "--fonts", fontDir, "@/inl.tex", "@/o4"],
    files := fun _ => #[("inl.tex", ("\\documentclass{article}\\begin{document}" ++
      rep "$a+b=c$ " 3000 ++ "\\end{document}").toUTF8)],
    expect := "pages" },
  { name := "TeX-rule layout: delimiters around 4000 atoms and fractions 300 deep",
    exe := "leantex-render", args := #["--document", "--fonts", fontDir, "@/del.tex", "@/o5"],
    files := fun _ => #[("del.tex", ("\\documentclass{article}\\begin{document}$\\left(" ++
      rep "x+" 4000 ++ "\\right)$ $" ++ rep "\\frac{1}{" 300 ++ "x" ++ rep "}" 300 ++
      "$\\end{document}").toUTF8)],
    expect := "pages" },
  { name := "images: one 1 MiB image included 400 times is read and written once per file",
    exe := "leantex-render", args := #["--document", "--fonts", fontDir, "@/img.tex", "@/o2"],
    files := fun _ => #[("mid.png", paddedPng (1 <<< 20)), ("img.tex",
      ("\\documentclass{article}\\usepackage{graphicx}\\begin{document}" ++
        rep "\\includegraphics[width=1cm]{mid.png}\n" 400 ++ "\\end{document}").toUTF8)],
    expect := "pages, 1 passes", maxRss := 300 <<< 20 },
  { name := "images: a path spelt with ./ is refused (one spelling per file)",
    exe := "leantex-render", args := #["--document", "--fonts", fontDir, "@/alias.tex", "@/o3"],
    files := fun _ => #[("mid.png", paddedPng 1000), ("alias.tex",
      ("\\documentclass{article}\\usepackage{graphicx}\\begin{document}" ++
        "\\includegraphics{./mid.png}\\end{document}").toUTF8)],
    expect := "Image path not allowed" },
  { name := "images: distinct images past the document's total are refused",
    exe := "leantex-render", args := #["--document", "--fonts", fontDir, "@/many.tex", "@/o4"],
    files := fun _ => #[("a.png", paddedPng (15 <<< 20)), ("b.png", paddedPng (15 <<< 20)),
      ("c.png", paddedPng (15 <<< 20)), ("many.tex",
      ("\\documentclass{article}\\usepackage{graphicx}\\begin{document}" ++
        "\\includegraphics{a.png}\\includegraphics{b.png}\\includegraphics{c.png}" ++
        "\\end{document}").toUTF8)],
    expect := "not found", maxRss := 300 <<< 20 },
  { name := "messages: control and bidirectional characters of the source are printed escaped",
    exe := "leantex-typeset", args := #["--test-fonts", "@/ctrl.tex"],
    files := fun _ => #[("ctrl.tex", "ctrl \u001b[31m $x\u000B\u202E$".toUTF8)],
    expect := "\\u{b}" }]

/-- Whether the text has a character `terminalUnsafe` refuses, other than line feeds. -/
def hasUnsafe (s : String) : Bool := s.any fun c => c != '\n' && terminalUnsafe c

/-- Runs every case. -/
def ioChecks : IO (Array (String × Bool)) := do
  let scratch ← IO.FS.realPath (← IO.FS.createTempDir)
  let mut r : Array (String × Bool) := #[]
  try
    for c in cases do
      for (f, b) in c.files () do IO.FS.writeBinFile (scratch / f) b
      let args := c.args.map fun a =>
        if a.startsWith "@/" then (scratch / (a.drop 2).toString).toString else a
      let run ← runLimited c.exe args 120 240000 scratch
      let mem := match run.rss with
        | some m => s!"{m / 1048576} MiB (bound {c.maxRss / 1048576} MiB)"
        | none => "memory not measured"
      let cpu := match run.userMs with | some t => s!"{t} ms" | none => "?"
      let said := (run.out ++ run.err)
      IO.println s!"  bounds: {c.name}: {terminalText ((said.take 120).toString)}; {mem}; \
        user {cpu}"
      let ok := run.status.isSome && (said.splitOn c.expect).length > 1 && !hasUnsafe run.err &&
        (run.rss.map (fun m => decide (m ≤ c.maxRss))).getD true &&
        (run.userMs.map (fun t => decide (t ≤ c.maxUserMs))).getD true
      r := r.push (s!"bounds: {c.name}", ok)
  finally
    IO.FS.removeDirAll scratch
  return r

/-- The checks that need no child: the fixture reader's strictness and the terminal escape. -/
def checks : Array (String × Bool) :=
  let everyChar := Id.run do
    let mut s := ""
    for v in [0:0x110000] do
      if v < 0xD800 || 0xDFFF < v then s := s.push (Char.ofNat v)
    return s
  #[("json: a misspelt literal is refused", (Json.parse "trux").toOption.isNone &&
      (Json.parse "nul").toOption.isNone && (Json.parse "true").toOption.isSome),
    ("json: an exponent beyond 400 is refused, not computed",
      (Json.parse "1e300000000").toOption.isNone && (Json.parse "1e300").toOption.isSome),
    ("json: text after the value is refused", (Json.parse "[1] x").toOption.isNone),
    ("terminal: no character terminalText lets through is unsafe",
      !(terminalText everyChar).any terminalUnsafe)]

end LeAnTeXTest.Bounds
