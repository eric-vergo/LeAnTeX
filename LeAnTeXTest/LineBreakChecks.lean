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

/-- A glue order of the fixtures (LuaTeX's: 0 finite, 1 `fi`, 2 `fil`, 3 `fill`, 4 `filll`)
as TeX's (0 finite, 1 `fil`, 2 `fill`, 3 `filll`); LuaTeX's `fi` does not occur in them. -/
def orderOf (o : Int) : Nat := if o ≤ 1 then 0 else (o - 1).toNat

/-- Glue from `[width, stretch, stretchOrder, shrink, shrinkOrder]`. -/
def glueOf (j : Json) : Glue :=
  { width := ji j 0, stretch := ji j 1, stretchOrder := orderOf (ji j 2), shrink := ji j 3,
    shrinkOrder := orderOf (ji j 4) }

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
    leftSkip := g "leftskip", rightSkip := g "rightskip", hangIndent := i "hangindent"
    hangAfter := if (j.get? "hangafter").isSome then i "hangafter" else 1 }

/-- Whether a glue ratio is TeX's: the fixture's nine significant digits identify a 32-bit
float, so the ratio must be that float exactly. -/
def sameRatio (a b : Float) : Bool := a == b.toFloat32.toFloat

/-- A corpus case's `\parshape` (indentation and length in pt per line), in sp. -/
def parShapeOf (c : Json) : Array (Int × Int) :=
  let sp := fun (j : Json) => ((j.getNum?.getD 0) * 65536).round.toInt64.toInt
  (((c.get? "parshape").bind Json.getArr?).getD #[]).map fun e => (sp (jat e 0), sp (jat e 1))

/-- The differences between `breakParagraph` and TeX on one fixture paragraph (`c` its corpus
case). -/
def checkOne (c r : Json) : Array String := Id.run do
  let id := ((r.get? "id").bind Json.getStr?).getD "?"
  let items := nodesOf 8 (((r.get? "items").bind Json.getArr?).getD #[])
  let p := { paramsOf ((r.get? "params").getD .null) with parShape := parShapeOf c }
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
            l.glue.order != orderOf (num "glueOrder") || !sameRatio l.glue.ratio ratio ||
            l.width != num "width" || l.indent != num "shift" then
          out := out.push s!"{id}: line ending at {num "break"}: natural {l.natural}, glue \
            {l.glue.sign}/{l.glue.order}/{l.glue.ratio}; TeX's {num "natural"}, \
            {num "glueSign"}/{num "glueOrder"}/{ratio}"
    return out

/-- Random horizontal lists (glyphs, glue of every order, penalties, kerns, discretionaries,
some malformed) under random parameters, and lists past the caps: each must be broken, its
breaks satisfying `checkBreaks`, or rejected with an error. Returns the failures, the number of
lists, and how many were rejected. -/
def fuzz : Array String × Nat × Nat := Id.run do
  let mut seed : Nat := 2024
  let mut fails := #[]
  let mut rejected := 0
  let next := fun (s : Nat) => (s * 6364136223846793005 + 1442695040888963407) % 2 ^ 64
  let n := 400
  for case in [0:n] do
    let mut items : Array HNode := #[]
    seed := next seed
    let len := seed % 120
    for _ in [0:len] do
      seed := next seed
      let r := seed % 1000
      seed := next seed
      let v : Int := (seed % 2000000 : Nat)
      items := items.push <| match r % 10 with
        | 0 | 1 | 2 | 3 => .glyph 'a' 1 v 0 0 0
        | 4 =>
          .glue
            { width := v / 4, stretch := v / 8, stretchOrder := if r == 997 then 4 else r % 4, shrink := v / 9,
              shrinkOrder := (r / 7) % 4 } 13
        | 5 => .penalty (v - 1000000)
        | 6 => .kern (v / 10 - 100000) (if r % 2 == 0 then .font else .explicit)
        | 7 => .disc 50 #[.glyph '-' 2 v 0 0 0] #[] (if r == 7 then #[.penalty 0] else #[])
            .syllable
        | 8 => .box v 0 0 0 #[]
        | _ => .glue {} 0
    items := items.push (.penalty 10000) |>.push (.glue { stretch := 65536, stretchOrder := 1 } 15)
    seed := next seed
    let p : Params :=
      { hsize := (seed % 30000000 : Nat), tolerance := (seed % 3 : Nat) * 4000,
        pretolerance := (seed % 5 : Int) * 50 - 50, looseness := (seed % 7 : Int) - 3,
        emergencyStretch := (seed % 2 : Nat) * 2000000, hangIndent := (seed % 11 : Int) * 100000,
        hangAfter := (seed % 5 : Int) - 2, maxActive := if case % 50 == 0 then 3 else 20000 }
    match breakParagraph items p with
    | .ok r =>
      if (checkBreaks items r).toBool != true then fails := fails.push s!"fuzz case {case}"
    | .error _ => rejected := rejected + 1
  -- past the caps
  let long := Array.replicate 50 (HNode.glyph 'a' 1 1 0 0 0)
  if (breakParagraph long { maxNodes := 10 }).toBool then fails := fails.push "maxNodes not kept"
  return (fails, n, rejected)

/-- Runs the comparison over every fixture paragraph; prints a summary, returns failures. -/
def run : IO (Array String) := do
  let fixture ← readJsonLines "fixtures/text/paragraphs.jsonl"
  let corpus ← readJsonLines "corpus/text/paragraphs.jsonl"
  let cases := (corpus.zip fixture).filter fun (_, r) => (r.get? "items").isSome
  let fails := cases.map fun (c, r) => checkOne c r
  let bad := (fails.filter (!·.isEmpty)).size
  IO.println s!"  line breaker: {cases.size - bad} of {cases.size} paragraphs broken as TeX \
    breaks them (breaks, demerits, line lengths and shifts, natural widths, glue)"
  let (ff, n, rej) := fuzz
  IO.println s!"  line breaker fuzz: {n} random lists, {n - rej} broken (every result \
    checked), {rej} rejected with an error"
  return fails.foldl (· ++ ·) ff

end LineBreakChecks
