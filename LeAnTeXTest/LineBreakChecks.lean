/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Text.Pack
import LeAnTeXTest.Font

/-!
# The line breaker against TeX

For every paragraph of `fixtures/text/paragraphs.jsonl`, the item list TeX's line breaker
received is fed to `breakParagraph` with the parameters TeX had; the breaks, the total demerits,
the number of lines, and every line's natural width and glue setting (`setLines`) must be TeX's.
The glue ratio, a 32-bit float in LuaTeX, must be the float the fixture's nine significant
digits name.
-/

namespace LineBreakChecks

open LeAnTeX LeAnTeX.Text FontTest

/-- An integer field of a JSON array, 0 if absent. -/
def ji (j : Json) (i : Nat) : Int := (jint? (jat j i)).getD 0

/-- Glue from `[width, stretch, stretchOrder, shrink, shrinkOrder]`. -/
def glueOf (j : Json) : Glue :=
  { width := ji j 0, stretch := ji j 1, stretchOrder := (ji j 2).toNat, shrink := ji j 3,
    shrinkOrder := (ji j 4).toNat }

/-- A fixture's items as nodes (`docs/text-reference.md`, *Items*), `fuel` bounding the
nesting. -/
def nodesOf (fuel : Nat) (items : Array Json) : Array HNode :=
  match fuel with
  | 0 => #[]
  | fuel + 1 => items.map fun it =>
    let arr := fun i => (jat it i).getArr?.getD #[]
    match (jat it 0).getStr? with
    | some "g" => .glyph (Char.ofNat (ji it 1).toNat) (ji it 2).toNat (ji it 3) (ji it 4)
        (ji it 5) (ji it 6).toNat
    | some "k" => .kern (ji it 1) (match ji it 2 with
        | 1 => .explicit | 2 => .accent | 3 => .italic | _ => .font)
    | some "glue" => .glue (glueOf (.arr ((it.getArr?.getD #[]).extract 1 6))) (ji it 6).toNat
    | some "p" => .penalty (ji it 1)
    | some "d" => .disc (ji it 1) (nodesOf fuel (arr 2)) (nodesOf fuel (arr 3))
        (nodesOf fuel (arr 4)) (match ji it 5 with
          | 0 => .discretionary | 1 => .explicit | 2 => .automatic | _ => .syllable)
    | some "box" => .box (ji it 1) (ji it 2) (ji it 3) 0 (nodesOf fuel (arr 4))
    | some "rule" => .rule (ji it 1) (ji it 2) (ji it 3)
    | _ => .penalty 0

/-- The line breaker's parameters from a fixture's `params`. -/
def paramsOf (j : Json) : Params :=
  let i := fun k => ((j.get? k).bind jint?).getD 0
  let g := fun k => glueOf ((j.get? k).getD .null)
  { hsize := i "hsize", pretolerance := i "pretolerance", tolerance := i "tolerance",
    looseness := i "looseness", linePenalty := i "linepenalty", adjDemerits := i "adjdemerits",
    doubleHyphenDemerits := i "doublehyphendemerits",
    finalHyphenDemerits := i "finalhyphendemerits", emergencyStretch := i "emergencystretch",
    leftSkip := g "leftskip", rightSkip := g "rightskip" }

/-- Whether a glue ratio is TeX's: the fixture's nine significant digits identify a 32-bit
float, so the ratio must be that float exactly. -/
def sameRatio (a b : Float) : Bool := a == b.toFloat32.toFloat

/-- The differences between `breakParagraph` and TeX on one fixture paragraph. -/
def checkOne (r : Json) : Array String := Id.run do
  let id := ((r.get? "id").bind Json.getStr?).getD "?"
  let items := nodesOf 8 (((r.get? "items").bind Json.getArr?).getD #[])
  let p := paramsOf ((r.get? "params").getD .null)
  let lines := ((r.get? "lines").bind Json.getArr?).getD #[]
  match breakParagraph items p with
  | .error e => return #[s!"{id}: {e.message}"]
  | .ok res =>
    let mut out := #[]
    let ours := res.breaks.map fun b => if b.pos == items.size then items.size - 1 else b.pos
    let theirs := lines.map fun l => (((l.get? "break").bind jint?).getD (-1)).toNat
    if ours != theirs then out := out.push s!"{id}: breaks {ours} ≠ TeX's {theirs}"
    let dem := (r.get? "demerits").bind jint?
    if dem != some res.demerits then
      out := out.push s!"{id}: demerits {res.demerits} ≠ TeX's {dem.getD 0}"
    if ours == theirs then
      let set := setLines items p res.breaks
      for (l, t) in set.zip lines do
        let num := fun k => ((t.get? k).bind jint?).getD 0
        let ratio := ((t.get? "glueSet").bind Json.getNum?).getD 0
        if l.natural != num "natural" || (l.glue.sign : Int) != num "glueSign" ||
            (l.glue.order : Int) != num "glueOrder" || !sameRatio l.glue.ratio ratio then
          out := out.push s!"{id}: line ending at {num "break"}: natural {l.natural}, glue \
            {l.glue.sign}/{l.glue.order}/{l.glue.ratio}; TeX's {num "natural"}, \
            {num "glueSign"}/{num "glueOrder"}/{ratio}"
    return out

/-- Runs the comparison over every fixture paragraph; prints a summary, returns failures. -/
def run : IO (Array String) := do
  let fixture ← readJsonLines "fixtures/text/paragraphs.jsonl"
  let cases := fixture.filter fun r => (r.get? "items").isSome
  let fails := cases.map checkOne
  let bad := (fails.filter (!·.isEmpty)).size
  IO.println s!"  line breaker: {cases.size - bad} of {cases.size} paragraphs broken as TeX \
    breaks them (breaks, demerits, natural widths, glue)"
  return fails.foldl (· ++ ·) #[]

end LineBreakChecks
