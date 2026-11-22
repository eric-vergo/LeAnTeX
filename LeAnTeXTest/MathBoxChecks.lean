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

/-- The directories searched for metric files: `LEANTEX_TFM_DIRS` (colon-separated) or TeX
Live's. -/
def tfmDirs : IO (Array System.FilePath) := do
  if let some v ← IO.getEnv "LEANTEX_TFM_DIRS" then
    return (v.splitOn ":").toArray.filter (!·.isEmpty) |>.map (⟨·⟩)
  texLiveTfmDirs

/-- The metric files read once per run; empty without a TeX installation. -/
initialize tfmCache : IO.Ref (Option (Std.HashMap String LeAnTeX.TeXMath.Tfm)) ← IO.mkRef none

/-- The metric files of `tfmDirs`, read once per run (a file that fails its checks is left
out). -/
def mathTfms : IO (Std.HashMap String LeAnTeX.TeXMath.Tfm) := do
  if let some m := ← tfmCache.get then return m
  let (out, _) ← readTfmDirs (← tfmDirs)
  tfmCache.set (some out)
  return out

/-- The math fonts with the committed New Computer Modern text fonts, or why not. -/
def fontSet : IO (Except String MathFontSet) := do
  let tfms ← mathTfms
  if !tfms.contains "cmmi10" then
    return .error "no Computer Modern metric files (set LEANTEX_TFM_DIRS)"
  let (infos, _) ← loadNewComputerModern "fonts/newcomputermodern"
  let resolve := newComputerModernResolver infos
  return .ok { tfms, text := fun k => (resolve k).map fun i =>
    ({ info := i, size := k.size, index := 0 } : TextFont) }

/-- The text size (sp) and `\baselineskip` of the class options. -/
def classSize : Nat → Int × Int
  | 11 => (717619, 891290)
  | 12 => (786432, 950272)
  | _ => (655360, 786432)

/-- The integer at index `i` of a JSON array: `none` when it is absent or not an integer (a
fraction is not rounded). -/
def jint? (j : Json) (i : Nat) : Option Int := do
  let x ← ((j.getArr?.getD #[])[i]?).bind Json.getNum?
  let a := x.abs
  let n := a.toUInt64.toNat
  if n.toFloat != a || a ≥ 9.0e15 then none
  else some (if x < 0 then -(n : Int) else n)

/-- The integer at index `i` of a JSON array, for messages (0 when it is not one). -/
def ji (j : Json) (i : Nat) : Int := (jint? j i).getD 0

/-- Whether the integer at index `i` is `v`. -/
def isInt (j : Json) (i : Nat) (v : Int) : Bool := jint? j i == some v

/-- Element `i` of a JSON array. -/
def jat (j : Json) (i : Nat) : Json := ((j.getArr?.getD #[])[i]?).getD .null

/-- The string at index `i`. -/
def js (j : Json) (i : Nat) : String := ((jat j i).getStr?).getD ""

/-- A font's name as the recorder writes it (its file without extension). -/
def fontLabel (fs : Families) (i : Nat) : String :=
  match fs.fonts[i]? with
  | some f => (f.name.splitOn ".otf").headD f.name
  | none => "?"

/-- LuaTeX's number of a glue order (0 finite, 1 `fi`, 2 `fil`, 3 `fill`, 4 `filll`) from the
library's (0 finite, 1 `fil`, 2 `fill`, 3 `filll`). -/
def luaOrder (o : Nat) : Nat := if o == 0 then 0 else o + 1

/-- LuaTeX's subtype of a kern. -/
def kernSubtype : KernKind → Nat
  | .font => 0 | .explicit => 1 | .accent => 2 | .italic => 3

/-- The size (sp) of font `i`. -/
def fontSize (fs : Families) (i : Nat) : Int := (fs.fonts[i]?.map MathFont.size).getD 0

/-- A short description of one of our nodes, with the fields the recorder writes. -/
def ourText (fs : Families) : TeXMath.Node → String
  | .char f c w h d => s!"char {fontLabel fs f} {fontSize fs f} {c} {w} {h} {d}"
  | .glyph f c _ w h d => s!"char {fontLabel fs f} {fontSize fs f} {c.toNat} {w} {h} {d}"
  | .box v w h d s g l => s!"{if v then "vbox" else "hbox"} {w} {h} {d} shift {s} set \
      {g.sign} {luaOrder g.order} {g.ratio} ({l.size})"
  | .rule w h d => s!"rule {w} {h} {d}"
  | .glue g st => s!"glue {g.width} {g.stretch} {luaOrder g.stretchOrder} {g.shrink} \
      {luaOrder g.shrinkOrder} subtype {st}"
  | .kern w k => s!"kern {w} subtype {kernSubtype k}"
  | .penalty p => s!"penalty {p}"
  | .math a _ => s!"math {if a then 1 else 0}"

/-- A short description of a recorded node. -/
def texText (j : Json) : String :=
  match js j 0 with
  | "c" => s!"char {js j 1} {ji j 2} {ji j 3} {ji j 4} {ji j 5} {ji j 6}"
  | "h" | "v" =>
    s!"{if js j 0 == "v" then "vbox" else "hbox"} {ji j 1} {ji j 2} {ji j 3} shift {ji j 4} \
      set {ji j 5} {ji j 6} {(jat j 7).compress} ({((jat j 8).getArr?.getD #[]).size})"
  | "r" => s!"rule {(jat j 1).compress} {(jat j 2).compress} {(jat j 3).compress}"
  | "g" => s!"glue {ji j 1} {ji j 2} {ji j 3} {ji j 4} {ji j 5} subtype {ji j 6}"
  | "k" => s!"kern {ji j 1} subtype {ji j 2}"
  | "p" => s!"penalty {ji j 1}"
  | "m" => s!"math {ji j 1}"
  | t => s!"node {t}"

/-- Whether a glue ratio is the recorded one: equal within one part in a million (the library
keeps it as TeX's single-precision ratio, LuaTeX records it as a double). -/
def sameRatio (r : Float) (j : Json) : Bool :=
  match j.getNum? with
  | some x => (r - x).abs ≤ 1e-6 * Max.max 1 x.abs
  | none => false

/-- Whether one of our nodes is the recorded one, field by field as the recorder writes it
(`tools/math-box-reference.lua`); children not compared. A character: font, size, code, width,
height, depth. A box: kind, width, height, depth, shift, glue sign and order, and the glue ratio
when the glue is set (sign not 0). A rule: its three dimensions (`null` running). Glue: width,
stretch and its order, shrink and its order, subtype. A kern: width and subtype. A penalty. A
math node: whether it is the start (0) or the end (1). -/
def sameNode (fs : Families) (n : TeXMath.Node) (j : Json) : Bool :=
  let opt := fun (o : Option Int) (k : Nat) => match o, jat j k with
    | none, .null => true
    | some v, _ => isInt j k v
    | _, _ => false
  let hasList := (jat j 8).getArr?.isSome
  match n, js j 0 with
  | .char f c w h d, "c" => fontLabel fs f == js j 1 && isInt j 2 (fontSize fs f) &&
      isInt j 3 c && isInt j 4 w && isInt j 5 h && isInt j 6 d
  | .glyph f c _ w h d, "c" => fontLabel fs f == js j 1 && isInt j 2 (fontSize fs f) &&
      isInt j 3 c.toNat && isInt j 4 w && isInt j 5 h && isInt j 6 d
  | .box v w h d s g _, t => t == (if v then "v" else "h") && isInt j 1 w && isInt j 2 h &&
      isInt j 3 d && isInt j 4 s && isInt j 5 g.sign && isInt j 6 (luaOrder g.order) &&
      (g.sign == 0 || sameRatio g.ratio (jat j 7)) && hasList
  | .rule w h d, "r" => opt w 1 && opt h 2 && opt d 3
  | .glue g st, "g" => isInt j 1 g.width && isInt j 2 g.stretch &&
      isInt j 3 (luaOrder g.stretchOrder) && isInt j 4 g.shrink &&
      isInt j 5 (luaOrder g.shrinkOrder) && isInt j 6 st
  | .kern w k, "k" => isInt j 1 w && isInt j 2 (kernSubtype k)
  | .penalty p, "p" => isInt j 1 p
  | .math a _, "m" => isInt j 1 (if a then 1 else 0)
  | _, _ => false

/-- The first place where our list and the recorded one differ: its path and both nodes;
`none` when they are the same throughout. At most `fuel` levels deep: a list nested deeper is
reported as a difference, never taken as the same. -/
def firstDiff (fs : Families) : Nat → Array TeXMath.Node → Array Json → String →
    Option String
  | 0, _, _, path => some s!"{path}: nested deeper than the comparison goes"
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

/-- The checks of the node comparison (`sameNode`, `firstDiff`, `jint?`) on made-up nodes: the
names of those that fail. Each would catch a recorded field the comparison ignores. -/
def nodeChecks : List String :=
  let fs : Families := {}
  let rec_ := fun (s : String) => (LeAnTeX.Json.parse s).toOption.getD .null
  let fil : Glue := { width := 0, stretch := 65536, stretchOrder := 1 }
  let cases : List (String × Bool) := [
    ("a math node's start and end are told apart",
      sameNode fs (.math false 0) (rec_ "[\"m\",0]") &&
        !sameNode fs (.math false 0) (rec_ "[\"m\",1]")),
    ("a kern's subtype is compared",
      sameNode fs (.kern 5 .italic) (rec_ "[\"k\",5,3]") &&
        !sameNode fs (.kern 5 .explicit) (rec_ "[\"k\",5,3]")),
    ("glue orders are compared (fil is LuaTeX's 2, not fi)",
      sameNode fs (.glue fil 0) (rec_ "[\"g\",0,65536,2,0,0,0]") &&
        !sameNode fs (.glue fil 0) (rec_ "[\"g\",0,65536,1,0,0,0]")),
    ("glue's subtype is compared", !sameNode fs (.glue {} 99) (rec_ "[\"g\",0,0,0,0,0,0]")),
    ("a box's glue sign is compared",
      !sameNode fs (.box false 1 0 0 0 { sign := 1, order := 0, ratio := 0.5 } #[])
        (rec_ "[\"h\",1,0,0,0,0,0,0.5,[]]")),
    ("a set box's glue ratio is compared",
      !sameNode fs (.box false 1 0 0 0 { sign := 1, order := 0, ratio := 0.5 } #[])
        (rec_ "[\"h\",1,0,0,0,1,0,0.25,[]]")),
    ("a number that is not an integer is no integer", jint? (rec_ "[1.5]") 0 == none),
    ("an absent number is not zero",
      jint? (rec_ "[]") 0 == none && !sameNode fs (.penalty 0) (rec_ "[\"p\"]")),
    ("lists nested past the depth compared are a difference",
      (firstDiff fs 0 #[] #[] "").isSome)]
  (cases.filter (!·.2)).map (·.1)

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
    -- a fixture that is missing or does not read is an error, never a smaller comparison
    if !(← path.pathExists) then throw (IO.userError s!"{path} is missing")
    let (size, _) := classSize cls
    let fs ← match m.families size with
      | .ok f => pure f
      | .error e => return .error e
    let mut row := 0
    for line in (← IO.FS.readFile path).splitOn "\n" do
      row := row + 1
      if line.isEmpty then continue
      let bad := fun (why : String) => IO.userError s!"{path}:{row}: {why}"
      let j ← match LeAnTeX.Json.parse line with
        | .ok j => pure j
        | .error e => throw (bad s!"not JSON ({e})")
      let some k := jint? j 0 | throw (bad "no formula number")
      let style := js j 1
      if style != "text" && style != "display" then throw (bad s!"style '{style}'")
      let some cl := (if k < 1 then none else corpus[k.toNat - 1]?)
        | throw (bad s!"no formula {k} in the corpus")
      let (some w, some h, some d) := (jint? j 2, jint? j 3, jint? j 4)
        | throw (bad "width, height or depth not an integer")
      if (jat j 5).getArr?.isNone then throw (bad "no node list")
      let (construct, src) := match cl.splitOn "\t" with
        | c :: rest => (c, "\t".intercalate rest)
        | [] => ("", "")
      let theirs := (w, h, d)
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
line, followed by the totals as `figure mathbox.KEY VALUE` lines for the manual. -/
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
    counts the boxes whose whole node list is TeX's in every field the recorder writes (every \
    node's kind and subtype, a character's font, size and code, every dimension, glue's orders, \
    a box's glue setting, the ratio within one part in a million; `sameNode`); a formula the \
    TeX-rule layout refuses is laid out by the KaTeX-compatible layout and counted only in the \
    columns of dimensions. The last column is the \
    KaTeX-compatible layout's own boxes the same to the sp.\n\n\
    | Construct (style) | Boxes | TeX-rule layout | Same to the sp | Within 0.1 pt | \
    Within 1 pt | Lists same | KaTeX layout same |\n|---|---|---|---|---|---|---|---|\n"
  for (c, st) in groups do
    md := md ++ row s!"{c} ({st})" (bs.filter fun b => b.construct == c && b.style == st)
  md := md ++ row "**all**" bs
  let built := bs.filter (·.tex)
  let refused := bs.filter (!·.tex)
  let split := s!"{cnt built 0} of the {built.size} the TeX-rule layout builds, \
    {cnt refused 0} of the {refused.size} it refuses"
  md := md ++ s!"\nThe boxes the same to the sp: {split} (those set by the KaTeX-compatible \
    layout).\n"
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
  let lists := (bs.filter fun b => b.tex && b.diff.isNone).size
  let fields := [("same", cnt bs 0), ("boxes", bs.size), ("builtSame", cnt built 0),
    ("built", built.size), ("refusedSame", cnt refused 0), ("refused", refused.size),
    ("within01", cnt bs 6554), ("within1", cnt bs 65536), ("listsSame", lists)]
  return s!"formula boxes against TeX (reported, not required): {cnt bs 0} of {bs.size} the \
    same to the sp ({split}), {cnt bs 6554} within 0.1 pt, {cnt bs 65536} within 1 pt; whole \
    node lists TeX's in every recorded field {lists}" ++
    String.join (fields.map fun (k, v) => s!"\nfigure mathbox.{k} {v}")

end MathBoxChecks
