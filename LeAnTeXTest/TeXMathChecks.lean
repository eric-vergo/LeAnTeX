/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX
import LeAnTeXTest.MathBoxChecks
import LeAnTeXTest.TfmSynth

/-!
# Tests of the TeX-rule math layout

* **The metric file reader** on a metric file built here (`testTfm`: three characters with
  widths, heights, depths and an italic correction, a ligature and kern program with a
  restart, a chain of larger characters, an extensible recipe and seven parameters): every
  value read back, scaled as TeX scales it, the program's kern and ligature and the skew;
  and every check of the reader on a file broken in that one way.
* **Fuzzing**: mutated copies of the built file and of the installed `cmmi10`, `cmsy10` and
  `cmex10` (bytes changed, lengths set to extreme values, files cut short) each read to a font
  or to an error, and every query on a font read returning.
* **Ligatures that never end**: metric files built here (`LeAnTeXTest.TfmSynth`) whose
  ligature programs insert or replace without end are refused by the reader, those that end
  are read, and a font past the reader's check stops the layout at its cap.
* **Hostile formulas** through the TeX-rule layout (deep nesting, `\mathchoice` and
  `\sqrt[n]` that multiply the work, huge delimiters): each ends in a list or an error
  naming a cap, within the work budget; every result is looked at and counted.
* **Formula boxes**: every box `parity/mathbox-baseline.tsv` lists as TeX's to the sp still is
  (when the metric files are installed).
* **Documents**: a narrow paragraph's formula breaks after a relation.
-/

namespace TeXMathChecks

open LeAnTeX LeAnTeX.TeXMath

/-- A 32-bit big-endian word. -/
def w32 (a b c d : Nat) : List UInt8 := [a.toUInt8, b.toUInt8, c.toUInt8, d.toUInt8]

/-- A fix-word's bytes (from a value in 2⁻²⁰). -/
def fw (v : Int) : List UInt8 :=
  let u : Nat := if v < 0 then (v + 4294967296).toNat else v.toNat
  w32 (u / 16777216 % 256) (u / 65536 % 256) (u / 256 % 256) (u % 256)

/-- A 16-bit big-endian half-word. -/
def h16 (v : Nat) : List UInt8 := [(v / 256).toUInt8, (v % 256).toUInt8]

/-- The test metric file: characters 65–67; `A` (width 0.5, height 0.7, italic 0.05) with a
lig/kern program whose first step restarts at step 1 (kern −0.1 before `B`, ligature
`A`+`C`→`B`, and a kern 0.02 before the skew character `C`); `B` (width 0.6, depth 0.2) with
`C` as its next larger; `C` (width 0.8, height 0.7, depth 0.2) extensible with `A` as top and
`B` as repeated piece; seven parameters. `lengths` overrides the twelve header lengths. -/
def testTfm (lengths : Option (List Nat) := none) : ByteArray :=
  let one : Int := 1048576
  let lens := lengths.getD [0, 2, 65, 67, 4, 2, 2, 2, 4, 2, 1, 7]
  -- lf = 6 + lh + nc + nw + nh + nd + ni + nl + nk + ne + np = 6+2+3+4+2+2+2+4+2+1+7 = 35
  let lens := match lens with
    | 0 :: r => (6 + r.headD 0 + 3 + 4 + 2 + 2 + 2 + 4 + 2 + 1 + 7) :: r
    | l => l
  let header := lens.flatMap h16
  let hdr := w32 0 0 0 1 ++ fw (10 * one)
  -- char_info: width index, height/depth, italic/tag, remainder
  let chars := w32 1 (1 * 16 + 0) (1 * 4 + 1) 0 ++ w32 2 (0 * 16 + 1) (0 * 4 + 2) 67 ++
    w32 3 (1 * 16 + 1) (0 * 4 + 3) 0
  let widths := fw 0 ++ fw (one / 2) ++ fw (one * 6 / 10) ++ fw (one * 8 / 10)
  let heights := fw 0 ++ fw (one * 7 / 10)
  let depths := fw 0 ++ fw (one * 2 / 10)
  let italics := fw 0 ++ fw (one / 20)
  -- step 0: restart at 1; 1: kern 0 before B; 2: ligature A+C→B (op 0); 3: kern 1 before C, stop
  let lig := w32 255 0 0 1 ++ w32 0 66 128 0 ++ w32 0 67 0 66 ++ w32 128 67 128 1
  let kerns := fw (-(one / 10)) ++ fw (one / 50)
  let exts := w32 65 0 0 66
  let params := fw 0 ++ fw (one / 3) ++ fw (one / 6) ++ fw (one / 9) ++ fw (one * 43 / 100) ++
    fw one ++ fw 0
  ByteArray.mk (header ++ hdr ++ chars ++ widths ++ heights ++ depths ++ italics ++ lig ++ kerns ++
    exts ++ params).toArray

/-- The test file with byte `i` set to `v`. -/
def withByte (i v : Nat) : ByteArray := (testTfm).set! i v.toUInt8

/-- The named checks of the reader. -/
def readerChecks : List (String × Bool) :=
  let ok := match Tfm.read testTfm with
    | .ok t => (t.at "test" (some (10 * 65536)) (some 67)).toOption
    | .error _ => none
  let refused := fun (b : ByteArray) => (Tfm.read b).toOption.isNone
  [("the test file reads", ok.isSome),
   ("A's width is 0.5 of 10pt", (ok.bind (·.char? 65)).map (·.width) == some (327680 : Int)),
   ("A's height and italic correction, TeX's truncation", (ok.bind (·.char? 65)).map (fun m =>
      (m.height, m.italic)) == some ((458751 : Int), (32767 : Int))),
   ("B's depth", (ok.bind (·.char? 66)).map (·.depth) == some (131071 : Int)),
   ("a missing character has no metrics", (ok.bind (·.char? 68)).isNone),
   ("the restarted program kerns A before B", ok.map (·.ligKern 65 66) ==
      some (.kern (-65536))),
   ("the program's ligature A+C", ok.map (·.ligKern 65 67) == some (.lig 0 66)),
   ("B's next larger is C", (ok.bind (·.char? 66)).map (·.tag) == some (.list 67)),
   ("C's recipe", (ok.bind (·.recipe? 67)).map (fun r => (r.top, r.rep)) == some (65, 66)),
   ("parameter 6 is the quad", ok.map (·.param 6) == some (655360 : Int)),
   ("the skew of A against C", ok.map (·.skew 65) == some (0 : Int)),
   ("TeX's scaling of 1/3 at 10pt", scaleFix 655360 (1048576 / 3) == 218453),
   ("TeX's scaling at 10.95pt", scaleFix 717619 524288 == 358809),
   ("a negative fix-word scales down", scaleFix 655360 (-104857) == -65536),
   ("lengths that do not add up are refused",
      refused (testTfm (some [36, 2, 65, 67, 4, 2, 2, 2, 4, 2, 1, 7]))),
   ("a file shorter than its lengths is refused", refused (testTfm.extract 0 100)),
   ("a width index past the table is refused", refused (withByte (24 + 8) 9)),
   ("a first width other than 0 is refused", refused (withByte (24 + 8 + 12 + 3) 1)),
   ("a next larger that is absent is refused", refused (withByte (24 + 8 + 4 + 3) 90)),
   ("a recipe piece that is absent is refused", refused (withByte (24 + 8 + 12 + 16 + 8 + 8 +
      8 + 16 + 8) 90)),
   ("a design size below 1pt is refused", refused (withByte (24 + 5) 0)),
   ("an empty file is refused", refused ByteArray.empty),
   ("a size of 2048pt is refused", (match Tfm.read testTfm with
      | .ok t => (t.at "test" (some (2048 * 65536))).toOption.isNone
      | .error _ => false)),
   ("ligatures that insert without end (|=:|) are refused",
      refused (LeAnTeXTest.TfmSynth.ligFont 3)),
   ("ligatures that replace without end (=:| and |=:) are refused",
      refused (LeAnTeXTest.TfmSynth.ligFont 1) && refused (LeAnTeXTest.TfmSynth.ligFont 2)),
   ("ligatures that end (=:, =:|>, |=:|>) are read",
      [0, 5, 7].all fun op => !refused (LeAnTeXTest.TfmSynth.ligFont op))]

/-- A deterministic pseudo-random sequence (a linear congruential generator). -/
def lcg (s : UInt64) : UInt64 := s * 6364136223846793005 + 1442695040888963407

/-- Mutates bytes of `b` with the seed: changed bytes, a length field set to an extreme, or the
file cut short. -/
def mutate (b : ByteArray) (seed : UInt64) : ByteArray := Id.run do
  let mut s := lcg seed
  let kind := s % 3
  s := lcg s
  if b.size == 0 then return b
  match kind with
  | 0 =>
    let mut out := b
    for _ in [0:4] do
      s := lcg s
      let i := (s / 7).toNat % b.size
      s := lcg s
      out := out.set! i ((s / 11).toNat % 256).toUInt8
    return out
  | 1 =>
    let i := 2 * ((s / 13).toNat % 12)
    return (b.set! i 0xFF).set! (i + 1) ((s / 17).toNat % 256).toUInt8
  | _ => return b.extract 0 ((s / 19).toNat % b.size)

/-- Every query on a font, combined into a number (so the queries are not optimised away). -/
def queryAll (f : TfmFont) : Nat := Id.run do
  let mut acc := 0
  for c in [0:256] do
    if let some m := f.char? c then acc := acc + (m.width % 7).toNat
    acc := acc + (f.skew c % 5).toNat
    if let some r := f.recipe? c then acc := acc + r.rep
    for d in [0:256:17] do
      match f.ligKern c d with
      | .kern k => acc := acc + (k % 3).toNat
      | .lig o x => acc := acc + o + x
      | .none => pure ()
  return acc

/-- Fuzzes the reader on mutants of the test file and of the installed fonts: the counts of
mutants read and refused, and a checksum. -/
def fuzz (n : Nat) : IO (Nat × Nat × Nat) := do
  let mut bases : Array ByteArray := #[testTfm]
  for d in ← MathBoxChecks.tfmDirs do
    for name in ["cmmi10", "cmsy10", "cmex10"] do
      if ← (d / (name ++ ".tfm")).pathExists then
        bases := bases.push (← IO.FS.readBinFile (d / (name ++ ".tfm")))
  let mut readN := 0
  let mut refused := 0
  let mut sum := 0
  for i in [0:n] do
    let b := bases[i % bases.size]?.getD testTfm
    let m := mutate b (UInt64.ofNat i)
    match Tfm.read m with
    | .ok t =>
      match t.at "fuzz" (some 655360) (some 127) with
      | .ok f => readN := readN + 1; sum := sum + queryAll f
      | .error _ => refused := refused + 1
    | .error _ => refused := refused + 1
  return (readN, refused, sum)

/-- Hostile formulas: each through the TeX-rule layout must end, in a list or an error. -/
def hostile : List String :=
  [String.join (List.replicate 60 "\\sqrt[3]{") ++ "x" ++ String.join (List.replicate 60 "}"),
   String.join (List.replicate 30 "\\mathchoice{") ++ "x" ++
     String.join (List.replicate 30 "}{x}{x}{x}"),
   String.join (List.replicate 200 "{") ++ "x" ++ String.join (List.replicate 200 "}"),
   String.join (List.replicate 150 "\\left(") ++ "x" ++ String.join (List.replicate 150 "\\right)"),
   "\\left(" ++ String.join (List.replicate 400 "\\frac{1}{") ++ "x" ++
     String.join (List.replicate 400 "}") ++ "\\right)",
   String.join (List.replicate 300 "x^{") ++ "y" ++ String.join (List.replicate 300 "}"),
   "\\Bigg(" ++ String.join (List.replicate 2000 "x+") ++ "\\Bigg)"]

/-- What the hostile formulas gave: lists, errors, and the errors that do not name a cap
(each formula's result is looked at, so none is left uncomputed). -/
structure HostileRun where
  /-- Formulas laid out to a list. -/
  lists : Nat := 0
  /-- Formulas that ended in an error. -/
  errors : Nat := 0
  /-- The errors that name no cap. -/
  stray : Array String := #[]
  /-- The nodes of all the lists. -/
  nodes : Nat := 0

/-- Whether an error of the TeX-rule layout names one of its caps. -/
def namesCap (e : String) : Bool :=
  ["work budget", "nesting", "too deep", "too costly", "too large", "do not end"].any
    fun c => (e.splitOn c).length > 1

/-- Runs the hostile formulas through the TeX-rule layout (none without metric files). -/
def runHostile : IO (Option HostileRun) := do
  let .ok m ← MathBoxChecks.fontSet | return none
  let .ok fs := m.families 655360 | return none
  let mut r : HostileRun := {}
  for src in hostile do
    match MathBoxChecks.texLayout m fs 10 src false with
    | .ok l => r := { r with lists := r.lists + 1, nodes := r.nodes + l.size }
    | .error e =>
      r := { r with errors := r.errors + 1 }
      if !namesCap e then r := { r with stray := r.stray.push e }
  return some r

/-- A font whose ligatures never end, past the reader's check (its program replaced after
reading): laying out `aa` with it must stop at the layout's own cap. `none` when it does. -/
def endlessLayout : Option String :=
  match Tfm.read (LeAnTeXTest.TfmSynth.ligFont 0) with
  | .error e => some s!"the font whose ligatures end is refused: {e}"
  | .ok t =>
    let t := { t with ligKern := #[{ skip := 128, next := 97, op := 3, rem := 97 }] }
    let m : MathFontSet := { tfms := mathTfmNames.foldl (fun acc n => acc.insert n t) {} }
    match m.families 655360 with
    | .error e => some s!"families: {e}"
    | .ok fs =>
      match MathBoxChecks.texLayout m fs 10 "aa" false with
      | .error e => if (e.splitOn "do not end").length > 1 then none else some e
      | .ok l => some s!"laid out to {l.size} nodes"

/-- The boxes `parity/mathbox-baseline.tsv` lists as TeX's that no longer are, or `none`
without metric files. With `update` the file is rewritten from the current boxes. -/
def baselineRegressions (update : Bool) : IO (Option (Array String)) := do
  let .ok bs ← MathBoxChecks.boxes | return none
  let key := fun (b : MathBoxChecks.Box) => s!"{b.size}\t{b.style}\t{b.formula}"
  let exact := bs.filter fun b => MathBoxChecks.dimDiff b.ours b.theirs == 0
  if update then
    IO.FS.writeFile "parity/mathbox-baseline.tsv"
      (String.join (exact.toList.map (key · ++ "\n")))
    return some #[]
  let path : System.FilePath := "parity/mathbox-baseline.tsv"
  if !(← path.pathExists) then return some #[s!"{path} is missing"]
  let want := ((← IO.FS.readFile path).splitOn "\n").filter (· ≠ "")
  let have_ : Std.HashSet String := Std.HashSet.ofList (exact.toList.map key)
  return some (want.filter (!have_.contains ·)).toArray

/-- Runs the checks; the failures. -/
def run (update : Bool := false) : IO (Array String) := do
  let mut fails := #[]
  for (name, ok) in readerChecks do
    if !ok then fails := fails.push s!"metric file reader: {name}"
  for name in MathBoxChecks.nodeChecks do
    fails := fails.push s!"formula box comparison: {name}"
  IO.println s!"  formula box comparison: {MathBoxChecks.nodeChecks.length} of its checks fail"
  IO.println s!"  metric file reader: {(readerChecks.filter (·.2)).length} of \
    {readerChecks.length} checks hold"
  let (r, x, sum) ← fuzz 1500
  IO.println s!"  metric file fuzz: 1500 mutants, {r} read, {x} refused (checksum {sum})"
  match ← runHostile with
  | none => IO.println "  TeX-rule layout, hostile formulas: skipped (no metric files)"
  | some h =>
    for e in h.stray do fails := fails.push s!"hostile formula: an error naming no cap: {e}"
    if h.lists + h.errors != hostile.length then
      fails := fails.push "hostile formulas: a result is missing"
    IO.println s!"  TeX-rule layout, hostile formulas: {h.lists} laid out ({h.nodes} nodes), \
      {h.errors} stopped at a cap, of {hostile.length}"
  match endlessLayout with
  | none => IO.println "  TeX-rule layout, endless ligatures: stopped at the cap"
  | some e => fails := fails.push s!"endless ligatures: {e}"
  match ← baselineRegressions update with
  | none => IO.println "  formula box baseline: skipped (no metric files)"
  | some regs =>
    for g in regs do fails := fails.push s!"formula box no longer TeX's: {g}"
    IO.println s!"  formula box baseline: {regs.size} regressions"
  return fails

end TeXMathChecks
