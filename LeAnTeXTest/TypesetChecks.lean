/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Text
import LeAnTeXTest.FrontChecks

/-!
# Typesetting goldens and front-end checks

* **Goldens.** Every `fixtures/typeset/*.tex` is typeset to a display list in its text form
  (`DisplayList.textForm`), with the two committed test fonts (`*.test.txt`, always) and with
  Latin Modern (`*.lm.txt`, when the fonts are installed), and must equal the file; each is
  typeset twice to check that the output is deterministic. `lake exe leantex-test --update`
  rewrites them.
* **Checks.** Named checks of the front end as a user writes source: macros, groups, spacing,
  errors with their messages; and untrusted source (mutated and hostile inputs) ending in a
  result or a clean error under the caps.
-/

namespace TypesetChecks

open LeAnTeX LeAnTeX.Text FontTest

/-- A resolver that gives the committed CFF test font for every key. -/
def testFonts : IO FontResolver := do
  let bytes ← IO.FS.readBinFile "fixtures/font/leantex-test-cff.otf"
  match OpenType.Font.read bytes with
  | .ok f =>
    let info := FontInfo.ofFont f "leantex-test-cff.otf"
    return fun _ => some info
  | .error _ => throw (IO.userError "the committed test font does not read")

/-- The text form of a file typeset with a resolver, or its error. -/
def render (src : String) (resolve : FontResolver) : String :=
  match typeset src resolve with
  | .ok d => d.toDisplayList.textForm
  | .error e => s!"error at {e.pos}: {e.message}\n"

/-- The golden files: compares (or with `update` writes) every file's text forms. -/
def goldens (update : Bool) : IO (Array String) := do
  let test ← testFonts
  let lm ← FrontChecks.latinModern
  let mut fails := #[]
  let mut n := 0
  let entries := (← System.FilePath.readDir "fixtures/typeset").map (·.path)
  for path in entries.qsort (·.toString < ·.toString) do
    if path.extension != some "tex" then continue
    let src ← IO.FS.readFile path
    for (suffix, res) in [("test", some test), ("lm", lm)] do
      let some res := res | continue
      let out := render src res
      let gold := path.withExtension s!"{suffix}.txt"
      n := n + 1
      if out != render src res then fails := fails.push s!"{gold}: not deterministic"
      if update then IO.FS.writeFile gold out
      else
        let have_ ← if ← gold.pathExists then IO.FS.readFile gold else pure ""
        if have_ != out then
          fails := fails.push s!"{gold}: differs (`lake exe leantex-test --update-typeset` after \
            checking the change)"
  IO.println s!"  typesetting goldens: {n - fails.size} of {n} display lists as recorded"
  return fails

/-- Whether typesetting `src` fails with a message containing `msg`. -/
def failsWith (res : FontResolver) (src msg : String) (cfg : Text.Settings := {}) : Bool :=
  match typeset src res cfg with
  | .error e => (e.message.splitOn msg).length > 1
  | .ok _ => false

/-- The glyphs of the first paragraph, as text. -/
def glyphText (res : FontResolver) (src : String) : String :=
  match typeset src res with
  | .ok d => String.ofList ((d.paragraphs[0]?.getD #[]).toList.filterMap fun
      | .glyph c .. => some c
      | .glue _ 13 => some ' '
      | _ => none)
  | .error e => "error: " ++ e.message

/-- The named checks, with Latin Modern if present (else the test font). -/
def checks : IO (Array (String × Bool)) := do
  let res ← match ← FrontChecks.latinModern with
    | some r => pure r
    | none => testFonts
  let g := glyphText res
  return #[
    ("macro without arguments", g "\\newcommand{\\x}{abc}\\x\\x" == "abcabc"),
    ("macro with two arguments", g "\\newcommand{\\p}[2]{#2#1}\\p{a}{b}" == "ba"),
    ("macro with a default argument", g "\\newcommand{\\d}[1][z]{#1}\\d \\d[y]" == "zy"),
    ("\\def with a parameter", g "\\def\\t#1{#1#1}\\t{ab}" == "abab"),
    ("definitions are local to groups",
      g "\\def\\a{x}{\\def\\a{y}\\a}\\a" == "yx"),
    ("\\renewcommand of an undefined command fails",
      failsWith res "\\renewcommand{\\nothing}{x}" "undefined"),
    ("\\newcommand of a defined command fails",
      failsWith res "\\newcommand{\\a}{x}\\newcommand{\\a}{y}" "already defined"),
    ("an undefined command fails with its name", failsWith res "a \\frobnicate b" "\\frobnicate"),
    ("a runaway argument fails", failsWith res "\\textbf{abc" "runaway"),
    ("an unclosed group fails", failsWith res "{abc" "group is not closed"),
    ("too many }'s fail", failsWith res "abc}" "Too many }"),
    ("an unclosed formula fails", failsWith res "a $x b" "formula not closed"),
    ("a bad formula fails with the math layout's message", failsWith res "$\\frac{a$" "formula"),
    ("& outside a table fails", failsWith res "a & b" "alignment tab"),
    ("^ outside math fails", failsWith res "a^b" "Missing $"),
    ("a macro bomb hits the token cap",
      failsWith res "\\def\\a{xxxxxxxxxx}\\def\\b{\\a\\a\\a\\a\\a\\a\\a\\a\\a\\a}\
        \\def\\c{\\b\\b\\b\\b\\b\\b\\b\\b\\b\\b}\\def\\d{\\c\\c\\c\\c\\c\\c\\c\\c\\c\\c}\
        \\d\\d\\d\\d\\d\\d\\d\\d\\d\\d" "Too many" { maxTokens := 10000 }),
    ("a recursive macro hits the expansion cap",
      failsWith res "\\def\\a{\\a}\\a" "Too many" { maxExpansions := 1000 }),
    ("deep nesting hits the depth cap",
      failsWith res (String.join (List.replicate 300 "{") ++ "x" ++
        String.join (List.replicate 300 "}")) "nested too deeply"),
    ("source past the size cap fails", failsWith res "abc" "too long" { maxSource := 2 }),
    ("--- and -- are dashes, `` and '' quotes", g "a---b--c ``d''" == "a—b–c “d”"),
    ("~ is a tie: a penalty and a space",
      match typeset "a~b" res with
      | .ok d => (d.paragraphs[0]?.getD #[]).any fun | .penalty 10000 => true | _ => false
      | .error _ => false),
    ("\\\\ ends a line", match typeset "a\\\\b" res with
      | .ok d => d.lines.size == 2 | .error _ => false),
    ("an empty line ends a paragraph", match typeset "a\n\nb" res with
      | .ok d => d.paragraphs.size == 2 | .error _ => false),
    ("\\noindent leaves out the indentation", match typeset "\\noindent a" res with
      | .ok d => !(d.paragraphs[0]?.getD #[]).any fun | .box .. => true | _ => false
      | .error _ => false),
    ("an inline formula is one node", match typeset "a $x+y$ b" res with
      | .ok d => ((d.paragraphs[0]?.getD #[]).filter fun | .math .. => true | _ => false).size
        == 1
      | .error _ => false),
    ("a displayed formula is a line of its own", match typeset "a \\[x\\] b" res with
      | .ok d => d.lines.size == 3 | .error _ => false),
    ("text macros reach formulas", match typeset "\\newcommand{\\R}{x}$\\R$" res with
      | .ok _ => true | .error _ => false),
    ("12.5pt is 819200 sp", match typeset "\\hsize=12.5pt a" res with
      | .ok d => d.width == 819200 | .error _ => false),
    ("1in is 4736286 sp", match typeset "\\hsize=1in a" res with
      | .ok d => d.width == 4736286 | .error _ => false),
    ("\\hspace{\\fill} is fill glue", match typeset "a\\hspace{\\fill}b" res with
      | .ok d => (d.paragraphs[0]?.getD #[]).any fun
        | .glue g _ => g.stretchOrder == 2 | _ => false
      | .error _ => false)]

/-- Mutated and hostile sources: every one must end in a document or an error. Returns the
number run and a checksum of the outcomes (so that a run is seen to have done the work). -/
def fuzz : IO (Nat × Nat) := do
  let res ← testFonts
  let seeds := #["In olden times \\textbf{when} wishing $x^2$ \\[y\\] ~ \\\\ {a}",
    "\\newcommand{\\a}[2][x]{#1#2}\\a{b} \\def\\c#1{#1} \\c{d} \\hspace{1em} \\vspace{2pt}",
    "\\hbox{\\mbox{a b}} \\parshape 2 1pt 10pt 2pt 20pt text text \\hangindent=5pt"]
  let pieces := #["{", "}", "$", "\\", "#", "%", "~", "&", "^", "\\def", "\\newcommand",
    "\\hbox", "[", "]", "\\par", "\n\n", "1", "pt", "\\hspace", "\\kern", "-", "\\fontsize",
    "\\penalty", "\\textbf", "=", "\\tolerance", "\\parshape", "99999999999", "\\[", "\\]"]
  let mut seed : Nat := 12345
  let mut n := 0
  let mut sum := 0
  for s in seeds do
    let cs := s.toList.toArray
    for _ in [0:300] do
      seed := (seed * 1103515245 + 12345) % 2147483648
      let pos := seed % (cs.size + 1)
      seed := (seed * 1103515245 + 12345) % 2147483648
      let piece := pieces[seed % pieces.size]?.getD ""
      seed := (seed * 1103515245 + 12345) % 2147483648
      let cut := seed % 4
      let src := String.ofList (cs.extract 0 pos).toList ++ piece ++
        String.ofList (cs.extract (pos + cut) cs.size).toList
      n := n + 1
      sum := sum + match typeset src res { maxTokens := 20000, maxExpansions := 2000 } with
        | .ok d => d.lines.size + 1
        | .error e => e.message.length
  return (n, sum)

/-- Runs the goldens, the checks and the fuzzing; prints summaries, returns failures. -/
def run (update : Bool := false) : IO (Array String) := do
  let mut fails ← goldens update
  let cs ← checks
  for (name, ok) in cs do
    if !ok then fails := fails.push s!"front-end check: {name}"
  IO.println s!"  front-end checks: {(cs.filter (·.2)).size} of {cs.size} hold"
  let (n, sum) ← fuzz
  IO.println s!"  front-end fuzz: {n} mutated sources, each a document or an error \
    (checksum {sum})"
  return fails

end TypesetChecks
