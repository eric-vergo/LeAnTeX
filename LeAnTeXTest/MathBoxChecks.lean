/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX
import LeAnTeXTest.JsonParse

/-!
# Formula boxes against TeX

Every formula of `corpus/math-box/formulas.tsv`, in text and display style, in the `article`
class at 10, 11 and 12 points, laid out by the TeX-rule layout (`LeAnTeX.TeXMath`) and compared
with the box LuaLaTeX made for it (`fixtures/math-box/boxes-<size>pt.jsonl`, recorded by
`tools/math-box-reference.sh` with its whole node list): the width, height and depth to the sp,
and the first node where the lists differ. A formula the TeX-rule layout does not build is
laid out by the KaTeX-compatible layout instead and counted apart. The KaTeX-compatible
layout's own boxes are compared too, for the record.

The Computer Modern metric files are read from a TeX installation (`LEANTEX_TFM_DIRS`, a
colon-separated list of directories, or the `tfm` directories of `/usr/local/texlive/*`);
without one the comparison is skipped with a note.
-/

namespace MathBoxChecks

open LeAnTeX LeAnTeX.TeXMath LeAnTeX.Text

/-- The directories searched for metric files. -/
def tfmDirs : IO (Array System.FilePath) := do
  if let some v ← IO.getEnv "LEANTEX_TFM_DIRS" then
    return (v.splitOn ":").toArray.filter (!·.isEmpty) |>.map (⟨·⟩)
  let root : System.FilePath := "/usr/local/texlive"
  if !(← root.isDir) then return #[]
  let mut out := #[]
  for e in ← root.readDir do
    let t := e.path / "texmf-dist" / "fonts" / "tfm" / "public"
    for sub in ["cm", "amsfonts/cmextra", "amsfonts/symbols", "amsfonts/euler"] do
      out := out.push (t / sub)
  return out

/-- The metric files of `mathTfmNames` found in the directories. -/
def readTfms : IO (Std.HashMap String ByteArray) := do
  let dirs ← tfmDirs
  let mut out : Std.HashMap String ByteArray := {}
  for n in mathTfmNames do
    for d in dirs do
      let p := d / (n ++ ".tfm")
      if ← p.pathExists then
        out := out.insert n (← IO.FS.readBinFile p)
        break
  return out

/-- The math fonts with the committed New Computer Modern text fonts, or why not. -/
def fontSet : IO (Except String MathFontSet) := do
  let files ← readTfms
  if !files.contains "cmmi10" then
    return .error "no Computer Modern metric files (set LEANTEX_TFM_DIRS)"
  let (infos, _) ← loadNewComputerModern "fonts/newcomputermodern"
  let resolve := newComputerModernResolver infos
  match MathFontSet.ofFiles (files[·]?) with
  | .error e => return .error e
  | .ok m =>
    return .ok { m with text := fun k => (resolve k).map fun i =>
      ({ info := i, size := k.size, index := 0 } : TextFont) }

/-- The text size (sp) and `\baselineskip` of the class options. -/
def classSize : Nat → Int × Int
  | 11 => (717619, 891290)
  | 12 => (786432, 950272)
  | _ => (655360, 786432)

/-- The integer at index `i` of a JSON array (0 when absent or not a number). -/
def ji (j : Json) (i : Nat) : Int :=
  match ((j.getArr?.getD #[])[i]?).bind Json.getNum? with
  | some x => if x < 0 then -((-x).round.toUInt64.toNat : Int) else (x.round.toUInt64.toNat : Int)
  | none => 0

/-- Element `i` of a JSON array. -/
def jat (j : Json) (i : Nat) : Json := ((j.getArr?.getD #[])[i]?).getD .null

/-- The string at index `i`. -/
def js (j : Json) (i : Nat) : String := ((jat j i).getStr?).getD ""

/-- A font's name as the recorder writes it (its file without extension). -/
def fontLabel (fs : Families) (i : Nat) : String :=
  match fs.fonts[i]? with
  | some f => (f.name.splitOn ".otf").headD f.name
  | none => "?"

/-- A short description of one of our nodes. -/
def ourText (fs : Families) : TeXMath.Node → String
  | .char f c w h d => s!"char {fontLabel fs f} {c} {w} {h} {d}"
  | .glyph f c _ w h d => s!"char {fontLabel fs f} {c.toNat} {w} {h} {d}"
  | .box v w h d s _ l => s!"{if v then "vbox" else "hbox"} {w} {h} {d} shift {s} ({l.size})"
  | .rule w h d => s!"rule {w} {h} {d}"
  | .glue g _ => s!"glue {g.width} {g.stretch} {g.shrink}"
  | .kern w _ => s!"kern {w}"
  | .penalty p => s!"penalty {p}"
  | .math a _ => s!"math {a}"

/-- A short description of a recorded node. -/
def texText (j : Json) : String :=
  match js j 0 with
  | "c" => s!"char {js j 1} {ji j 3} {ji j 4} {ji j 5} {ji j 6}"
  | "h" | "v" =>
    s!"{if js j 0 == "v" then "vbox" else "hbox"} {ji j 1} {ji j 2} {ji j 3} shift {ji j 4} \
      ({((jat j 8).getArr?.getD #[]).size})"
  | "r" => s!"rule {ji j 1} {ji j 2} {ji j 3}"
  | "g" => s!"glue {ji j 1} {ji j 2} {ji j 4}"
  | "k" => s!"kern {ji j 1}"
  | "p" => s!"penalty {ji j 1}"
  | "m" => s!"math {ji j 1 == 1}"
  | t => s!"node {t}"

/-- Whether one of our nodes is the recorded one (children not compared). -/
def sameNode (fs : Families) (n : TeXMath.Node) (j : Json) : Bool :=
  let opt := fun (o : Option Int) (k : Nat) => match o, jat j k with
    | none, .null => true
    | some v, _ => v == ji j k
    | _, _ => false
  match n, js j 0 with
  | .char f c w h d, "c" => fontLabel fs f == js j 1 && c == (ji j 3).toNat && w == ji j 4 &&
      h == ji j 5 && d == ji j 6
  | .glyph f c _ w h d, "c" => fontLabel fs f == js j 1 && c.toNat == (ji j 3).toNat &&
      w == ji j 4 && h == ji j 5 && d == ji j 6
  | .box v w h d s _ _, t => t == (if v then "v" else "h") && w == ji j 1 && h == ji j 2 &&
      d == ji j 3 && s == ji j 4
  | .rule w h d, "r" => opt w 1 && opt h 2 && opt d 3
  | .glue g _, "g" => g.width == ji j 1 && g.stretch == ji j 2 && g.shrink == ji j 4
  | .kern w _, "k" => w == ji j 1
  | .penalty p, "p" => p == ji j 1
  | .math .., "m" => true
  | _, _ => false

/-- The first place where our list and the recorded one differ: its path and both nodes;
`none` when they are the same throughout. At most `fuel` levels deep. -/
def firstDiff (fs : Families) : Nat → Array TeXMath.Node → Array Json → String →
    Option String
  | 0, _, _, _ => none
  | fuel + 1, ours, theirs, path => Id.run do
    for i in [0:max ours.size theirs.size] do
      match ours[i]?, theirs[i]? with
      | some n, some j =>
        if !sameNode fs n j then
          return some s!"{path}{i}: {ourText fs n}, TeX {texText j}"
        match n with
        | .box _ _ _ _ _ _ l =>
          if let some d := firstDiff fs fuel l ((jat j 8).getArr?.getD #[]) s!"{path}{i}." then
            return some d
        | _ => pure ()
      | some n, none => return some s!"{path}{i}: {ourText fs n}, TeX nothing"
      | none, some j => return some s!"{path}{i}: nothing, TeX {texText j}"
      | none, none => pure ()
    return none

/-- One formula's outcome. -/
structure Box where
  /-- The construct. -/
  construct : String
  /-- The formula. -/
  formula : String
  /-- `text` or `display`. -/
  style : String
  /-- The class size in points. -/
  size : Nat
  /-- TeX's width, height, depth. -/
  theirs : Int × Int × Int
  /-- Ours (`none` when neither layout builds it). -/
  ours : Option (Int × Int × Int)
  /-- Whether the TeX-rule layout built it (else the KaTeX-compatible layout did). -/
  tex : Bool
  /-- The first differing node, or the reason the TeX-rule layout refused the formula. -/
  diff : Option String
  /-- The KaTeX-compatible layout's box (at the size), for the record. -/
  katex : Option (Int × Int × Int)

/-- The largest difference of the three dimensions (2³⁰ for none). -/
def dimDiff (a : Option (Int × Int × Int)) (b : Int × Int × Int) : Int :=
  match a with
  | some (w, h, d) =>
    let (w', h', d') := b
    max (w - w').natAbs (max (h - h').natAbs (d - d').natAbs)
  | none => 1073741824

/-- The KaTeX-compatible layout's box of a formula at a size. -/
def katexBox (src : String) (display : Bool) (size : Int) : Option (Int × Int × Int) :=
  match (LeAnTeX.layout src { displayMode := display }).result with
  | .ok b =>
    let dl := DisplayList.ofBox b
    let sc := fun (e : Em) => Em.roundDiv (e.raw * size) Em.unit
    some (sc dl.width, sc dl.height, sc dl.depth)
  | .error _ => none

/-- Lays out a formula with the TeX-rule layout: the box's list (math nodes around it), or the
error. -/
def texLayout (m : MathFontSet) (fs : Families) (cls : Nat) (src : String) (display : Bool) :
    Except String (Array TeXMath.Node) := do
  let (size, bskip) := classSize cls
  let tree ← parseForTeX src {} false
  let tf := m.text { size }
  let ctx : FrontCtx := {
    source := src, quad := size,
    xHeight := (tf.map fun t => (MathFont.otf t).param 5).getD 282168,
    space := (tf.map (·.space)).getD {},
    strutHeight := xnOverD bskip 45875 65536, strutDepth := xnOverD bskip 19661 65536 }
  let env : Env := { fams := fs }
  let run : TeXMath.M (Array TeXMath.Node) := do
    let l ← toMathList tree ctx
    let l := if display then #[Noad.style .display] ++ l else l
    mlistToHlist maxNesting l .text false
  match (run.run env).run {} with
  | .ok (h, _) => return #[TeXMath.Node.math false 0] ++ h ++ #[.math true 0]
  | .error e => throw e

/-- Every recorded formula compared, at the sizes recorded. -/
def boxes : IO (Except String (Array Box)) := do
  let m ← match ← fontSet with
    | .ok m => pure m
    | .error e => return .error e
  let corpus := ((← IO.FS.readFile "corpus/math-box/formulas.tsv").splitOn "\n").filter
    (· ≠ "") |>.toArray
  let mut out : Array Box := #[]
  for cls in [10, 11, 12] do
    let path : System.FilePath := s!"fixtures/math-box/boxes-{cls}pt.jsonl"
    if !(← path.pathExists) then continue
    let (size, _) := classSize cls
    let fs ← match m.families size with
      | .ok f => pure f
      | .error e => return .error e
    for line in (← IO.FS.readFile path).splitOn "\n" do
      if line.isEmpty then continue
      let .ok j := LeAnTeX.Json.parse line | continue
      let k := (ji j 0).toNat
      let style := js j 1
      let some cl := corpus[k - 1]? | continue
      let (construct, src) := match cl.splitOn "\t" with
        | c :: rest => (c, "\t".intercalate rest)
        | [] => ("", "")
      let theirs := (ji j 2, ji j 3, ji j 4)
      let display := style == "display"
      let kb := katexBox src display size
      match texLayout m fs cls src display with
      | .ok l =>
        let b := hpack l
        let d := firstDiff fs 64 l ((jat j 5).getArr?.getD #[]) ""
        let r : Box := { construct, formula := src, style, size := cls, theirs,
                         ours := some (b.width, b.height, b.depth), tex := true, diff := d,
                         katex := kb }
        out := out.push r
      | .error e =>
        let r : Box := { construct, formula := src, style, size := cls, theirs, ours := kb,
                         tex := false, diff := some e, katex := kb }
        out := out.push r
  return .ok out

/-- The report, per construct and style over all sizes: boxes, those the TeX-rule layout built,
boxes the same to the sp, within 0.1 pt, within 1 pt, lists the same throughout, and the
KaTeX-compatible layout's boxes the same; with `update` written to `parity/MATHBOX.md`
together with the first difference of each box that is not TeX's. Returns the summary
line. -/
def run (update : Bool := false) : IO String := do
  let bs ← match ← boxes with
    | .ok b => pure b
    | .error e => return s!"formula boxes against TeX: skipped ({e})"
  let groups := (bs.map fun b => (b.construct, b.style)).toList.eraseDups
  let cnt := fun (g : Array Box) (t : Int) => (g.filter fun b => dimDiff b.ours b.theirs ≤ t).size
  let row := fun (label : String) (g : Array Box) =>
    let k := (g.filter fun b => dimDiff b.katex b.theirs == 0).size
    s!"| {label} | {g.size} | {(g.filter (·.tex)).size} | {cnt g 0} | {cnt g 6554} | \
      {cnt g 65536} | {(g.filter fun b => b.tex && b.diff.isNone).size} | {k} |\n"
  let mut md := "# Formula boxes against TeX\n\nWritten by `lake exe leantex-test --update-doc` \
    (`LeAnTeXTest/MathBoxChecks.lean`): every formula of `corpus/math-box/formulas.tsv` in text \
    and display style, in the `article` class at 10, 11 and 12 points, laid out by the TeX-rule \
    layout (`docs/math-boxes.md`) and compared with the box LuaLaTeX made for it \
    (`fixtures/math-box/boxes-*pt.jsonl`, `tools/math-box-reference.sh`). A box counts in a \
    column when its width, height and depth are all within that much of TeX's; *lists same* \
    counts the boxes whose whole node list is TeX's (every node's kind, font, character and \
    dimensions); a formula the TeX-rule layout refuses is laid out by the KaTeX-compatible \
    layout and counted only in the columns of dimensions. The last column is the \
    KaTeX-compatible layout's own boxes the same to the sp.\n\n\
    | Construct (style) | Boxes | TeX-rule layout | Same to the sp | Within 0.1 pt | \
    Within 1 pt | Lists same | KaTeX layout same |\n|---|---|---|---|---|---|---|---|\n"
  for (c, st) in groups do
    md := md ++ row s!"{c} ({st})" (bs.filter fun b => b.construct == c && b.style == st)
  md := md ++ row "**all**" bs
  md := md ++ "\n## Boxes that are not TeX's\n\nThe formula, style and size, the largest \
    difference in sp, and the first node that differs (path of indices into the box's list) \
    or why the TeX-rule layout refused it.\n\n| Formula | Style | Size | Difference | First \
    difference |\n|---|---|---|---|---|\n"
  for b in bs do
    let dd := dimDiff b.ours b.theirs
    if dd != 0 || b.diff.isSome then
      let cell := fun (s : String) => s.replace "|" "\\|"
      md := md ++ s!"| `{cell b.formula}` | {b.style} | {b.size} | \
        {if dd ≥ 1073741824 then "none" else toString dd} | {cell (b.diff.getD "")} |\n"
  if update then IO.FS.writeFile "parity/MATHBOX.md" md
  return s!"formula boxes against TeX (reported, not required): {cnt bs 0} of {bs.size} the \
    same to the sp ({(bs.filter (·.tex)).size} by the TeX-rule layout), {cnt bs 6554} within \
    0.1 pt, {cnt bs 65536} within 1 pt"

end MathBoxChecks
