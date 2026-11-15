/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX

/-!
# Formula boxes against TeX

The box the math layout gives every formula of `corpus/math-box/formulas.tsv` (text and display
style, at ten points, as the document layer scales it) against the box TeX makes for it
(`fixtures/math-box/boxes.tsv`, recorded by `tools/math-box-reference.sh` with the documents'
fonts). The comparison is reported per construct, never required: the math layout follows
KaTeX's metrics and rules, and TeX's boxes come from the Computer Modern math fonts' own
metrics at each size.
-/

namespace MathBoxChecks

open LeAnTeX LeAnTeX.Text

/-- One formula's outcome: its construct, its style, and our and TeX's width, height and
depth. -/
structure Box where
  /-- The construct. -/
  construct : String
  /-- `text` or `display`. -/
  style : String
  /-- Ours: width, height, depth (`none` when the math layout rejects the formula). -/
  ours : Option (Int × Int × Int)
  /-- TeX's. -/
  theirs : Int × Int × Int

/-- The largest difference of the three dimensions (for a rejected formula, 2³⁰). -/
def Box.diff (b : Box) : Int :=
  match b.ours with
  | some (w, h, d) =>
    let (w', h', d') := b.theirs
    max (w - w').natAbs (max (h - h').natAbs (d - d').natAbs)
  | none => 1073741824

/-- The box of a formula at ten points, as the document layer makes it. -/
def oursOf (src : String) (display : Bool) : Option (Int × Int × Int) :=
  match (LeAnTeX.layout src { displayMode := display }).result with
  | .ok b =>
    let dl := DisplayList.ofBox b
    let sc := fun (e : Em) => Em.roundDiv (e.raw * 655360) Em.unit
    some (sc dl.width, sc dl.height, sc dl.depth)
  | .error _ => none

/-- Every recorded formula compared. -/
def boxes : IO (Array Box) := do
  let corpus := ((← IO.FS.readFile "corpus/math-box/formulas.tsv").splitOn "\n").filter
    (· ≠ "") |>.toArray
  let rows := ((← IO.FS.readFile "fixtures/math-box/boxes.tsv").splitOn "\n").filter (· ≠ "")
  let mut out := #[]
  for r in rows do
    match r.splitOn "\t" with
    | [n, style, w, h, d] =>
      let some k := n.toNat? | continue
      let some line := corpus[k - 1]? | continue
      match line.splitOn "\t" with
      | construct :: rest =>
        let src := "\t".intercalate rest
        let theirs := ((w.toInt?).getD 0, (h.toInt?).getD 0, (d.toInt?).getD 0)
        out := out.push { construct, style, ours := oursOf src (style == "display"), theirs }
      | [] => pure ()
    | _ => pure ()
  return out

/-- The report: per construct and style, the formulas, those with the same box to the sp,
within 1 sp, within 0.1 pt and within 1 pt, and the largest difference; with `update` written
to `parity/MATHBOX.md`. Returns the summary line. -/
def run (update : Bool := false) : IO String := do
  let bs ← boxes
  let groups := (bs.map fun b => (b.construct, b.style)).toList.eraseDups
  let row := fun (label : String) (g : Array Box) =>
    let c := fun (t : Int) => (g.filter (·.diff ≤ t)).size
    let worst := g.foldl (init := (0 : Int)) fun m b => max m b.diff
    s!"| {label} | {g.size} | {c 0} | {c 1} | {c 6554} | {c 65536} | \
      {if worst ≥ 1073741824 then "rejected" else toString worst} |\n"
  let mut md := "# Formula boxes against TeX\n\nWritten by `lake exe leantex-test --update-doc` \
    (`LeAnTeXTest/MathBoxChecks.lean`): the box the math layout gives each formula of \
    `corpus/math-box/formulas.tsv` at ten points (width, height and depth, as the document \
    layer scales it) against TeX's (`fixtures/math-box/boxes.tsv`, \
    `tools/math-box-reference.sh`). A formula counts in a column when all three dimensions are \
    within that much of TeX's; the last column is the largest difference in sp.\n\n\
    | Construct (style) | Formulas | Same to the sp | Within 1 sp | Within 0.1 pt | Within 1 pt \
    | Largest difference |\n|---|---|---|---|---|---|---|\n"
  for (c, st) in groups do
    md := md ++ row s!"{c} ({st})" (bs.filter fun b => b.construct == c && b.style == st)
  md := md ++ row "**all**" bs
  if update then IO.FS.writeFile "parity/MATHBOX.md" md
  let c := fun (t : Int) => (bs.filter (·.diff ≤ t)).size
  return s!"formula boxes against TeX (reported, not required): {c 0} of {bs.size} the same \
    to the sp, {c 6554} within 0.1 pt, {c 65536} within 1 pt"

end MathBoxChecks
