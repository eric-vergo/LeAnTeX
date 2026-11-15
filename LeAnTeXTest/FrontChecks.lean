/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Text.LatinModern
import LeAnTeX.Text.NewComputerModern
import LeAnTeXTest.LineBreakChecks

/-!
# The front end against TeX

Every paragraph of the text corpus is written as LaTeX source (its parameters as assignments,
its font as a font command, its control items as `\penalty`, `\hskip`, `\kern`, `\hbox` and
`~`) and typeset by `typeset` with the Latin Modern fonts; the horizontal list given to the line
breaker must be the one TeX's line breaker received (`fixtures/text/paragraphs.jsonl`), node for
node, its lines as long, and the paragraph's box as high and as deep (the lines stacked
with `\baselineskip`). Skipped, with a note, when the fonts are not installed.
-/

namespace FrontChecks

open LeAnTeX LeAnTeX.Text FontTest

/-- Loads the Latin Modern fonts for the keys a document may use: every family, series and
shape at LaTeX's sizes; a resolver over those found. -/
def latinModern : IO (Option FontResolver) := do
  let mut infos : Std.HashMap String FontInfo := {}
  let sizes : List Int := [5, 6, 7, 8, 9, 10, 12, 14, 17, 20, 25].map (· * 65536)
  for fam in [Family.roman, .sans, .mono] do
    for bold in [false, true] do
      for shape in [Shape.upright, .italic, .slanted, .caps] do
        for size in sizes do
          let name := latinModernFile { family := fam, bold, shape, size }
          if infos.contains name then continue
          let some path ← findFont (name ++ ".otf") | continue
          match OpenType.Font.read (← IO.FS.readBinFile path) with
          | .ok f => infos := infos.insert name (FontInfo.ofFont f (name ++ ".otf"))
          | .error _ => pure ()
  if !infos.contains "lmroman10-regular" then return none
  let table := infos
  return some fun k => table[latinModernFile k]?

/-- A node as a short string, for comparing lists and showing where they differ. -/
partial def nodeText : HNode → String
  | .glyph c g w h d f => s!"g{c.toNat}/{g}/{w}/{h}/{d}/{f}"
  | .kern w k => s!"k{w}/{repr k}"
  | .glue g st => s!"glue{g.width}/{g.stretch}/{g.stretchOrder}/{g.shrink}/{g.shrinkOrder}/{st}"
  | .penalty p => s!"p{p}"
  | .disc p a b c k => s!"d{p}[{",".intercalate (a.toList.map nodeText)}]\
      [{",".intercalate (b.toList.map nodeText)}][{",".intercalate (c.toList.map nodeText)}]\
      {repr k}"
  | .box w h d s c => s!"box{w}/{h}/{d}/{s}[{",".intercalate (c.toList.map nodeText)}]"
  | .rule w h d => s!"rule{w}/{h}/{d}"
  | .math w h d _ s => s!"math{w}/{h}/{d}/{s}"

/-- A number of points as TeX source. -/
def ptText (x : Float) : String :=
  let cs := (toString x).toList
  let cs := if cs.contains '.' then (cs.reverse.dropWhile (· == '0')).reverse else cs
  let cs := if cs.getLast? == some '.' then cs.dropLast else cs
  String.ofList cs ++ "pt"

/-- The LaTeX source of a corpus paragraph (`tools/tex-reference/reference.lua` writes the same
material for TeX). -/
def sourceOf (c : Json) : String := Id.run do
  let num := fun (k : String) => (c.get? k).bind Json.getNum?
  let font := ((c.get? "font").bind Json.getStr?).getD "regular"
  let size := (num "size").getD 10
  let mut s := match font with
    | "italic" => "\\itshape " | "bold" => "\\bfseries " | "bolditalic" => "\\bfseries\\itshape "
    | "sans" => "\\sffamily " | "mono" => "\\ttfamily " | "caps" => "\\scshape "
    | "slanted" => "\\slshape " | _ => ""
  s := s ++ s!"\\fontsize\{{ptText size}}\{{ptText (size * 1.2)}}\\selectfont "
  s := s ++ s!"\\hsize={ptText ((num "hsize").getD 345)} \\parindent=0pt \\parskip=0pt "
  for k in ["tolerance", "pretolerance", "looseness", "linepenalty", "hyphenpenalty",
      "exhyphenpenalty", "adjdemerits", "doublehyphendemerits", "finalhyphendemerits"] do
    if let some v := (c.get? k).bind jint? then s := s ++ s!"\\{k}={v} "
  if let some v := (c.get? "hangafter").bind jint? then s := s ++ s!"\\hangafter={v} "
  if let some sh := (c.get? "parshape").bind Json.getArr? then
    s := s ++ s!"\\parshape {sh.size} "
    for e in sh do
      s := s ++ s!"{ptText ((jat e 0).getNum?.getD 0)} {ptText ((jat e 1).getNum?.getD 0)} "
  for k in ["parindent", "emergencystretch", "hangindent"] do
    if let some v := num k then s := s ++ s!"\\{k}={ptText v} "
  for k in ["leftskip", "rightskip", "parfillskip"] do
    if let some v := (c.get? k).bind Json.getStr? then s := s ++ s!"\\{k}={v}\\relax "
  let parts := ((c.get? "parts").bind Json.getArr?).getD
    #[((c.get? "text").getD (.str ""))]
  for p in parts do
    match p with
    | .str t => s := s ++ t
    | p =>
      if let some v := (p.get? "penalty").bind jint? then s := s ++ s!"\\penalty{v} "
      else if let some g := (p.get? "glue").bind Json.getStr? then s := s ++ s!"\\hskip {g}\\relax "
      else if let some k := (p.get? "kern").bind Json.getNum? then s := s ++ s!"\\kern{ptText k} "
      else if let some b := (p.get? "hbox").bind Json.getStr? then s := s ++ s!"\\hbox\{{b}}"
      else if (p.get? "tie").isSome then s := s ++ "~"
  return s ++ "\\par"

/-- The New Computer Modern fonts of the repository (`fonts/newcomputermodern`), as a resolver;
`none` if the roman Book font is missing. -/
def newComputerModern : IO (Option FontResolver) := do
  let (infos, _) ← loadNewComputerModern "fonts/newcomputermodern"
  if !infos.contains "NewCM10-Book" then return none
  return some (newComputerModernResolver infos)

/-- Runs the comparison against `fixture` (TeX's answers with the fonts `resolve` stands for);
prints a summary under `label`, returns the differences. -/
def runWith (resolve : FontResolver) (fixture label : String) : IO (Array String) := do
  let corpus ← readJsonLines "corpus/text/paragraphs.jsonl"
  let fixture ← readJsonLines fixture
  let mut fails := #[]
  let mut same := 0
  let mut n := 0
  for (c, r) in corpus.zip fixture do
    let some id := (c.get? "id").bind Json.getStr? | continue
    n := n + 1
    let src := sourceOf c
    match typeset src resolve with
    | .error e => fails := fails.push s!"{id}: {e.message} at {e.pos} in {src.take 80}"
    | .ok doc =>
      let ours := ((doc.paragraphs[0]?).getD #[]).map nodeText
      let theirs := (LineBreakChecks.nodesOf 8
        (((r.get? "items").bind Json.getArr?).getD #[])).map nodeText
      let lines := ((r.get? "lines").bind Json.getArr?).getD #[]
      let natural := lines.map fun l => ((l.get? "natural").bind jint?).getD 0
      let height := ((r.get? "height").bind jint?).getD 0
      let depth := ((r.get? "depth").bind jint?).getD 0
      let lastY := (doc.lines.back?.map (·.2)).getD 0
      let lastD := (doc.lines.back?.map (·.1.depth)).getD 0
      if ours == theirs && doc.lines.map (·.1.natural) == natural && lastY == height &&
          lastD == depth then same := same + 1
      else if ours == theirs then
        fails := fails.push s!"{id}: lines {doc.lines.map (·.1.natural)} ending at {lastY}, \
          depth {lastD}; TeX's {natural}, {height}, {depth}"
      else
        let i := ((List.range (max ours.size theirs.size)).find? fun i =>
          ours[i]? != theirs[i]?).getD 0
        fails := fails.push s!"{id}: node {i} is {ours[i]?.getD "-"}, TeX's {theirs[i]?.getD "-"} \
          ({ours.size} and {theirs.size} nodes)"
  IO.println s!"  front end{label}: {same} of {n} corpus paragraphs give TeX's horizontal list, \
    lines and box"
  return fails

/-- Runs the comparison with Latin Modern (`fixtures/text/paragraphs.jsonl`) and with New
Computer Modern (`fixtures/text/paragraphs-ncm.jsonl`); prints the summaries, returns the
differences. -/
def run : IO (Array String) := do
  let lm ← match ← latinModern with
    | some r => runWith r "fixtures/text/paragraphs.jsonl" ""
    | none => IO.println "  front end: skipped (no Latin Modern fonts found)"; pure #[]
  let ncm ← match ← newComputerModern with
    | some r => runWith r "fixtures/text/paragraphs-ncm.jsonl" " (New Computer Modern)"
    | none => IO.println "  front end (New Computer Modern): fonts missing"; pure #["no NCM"]
  return lm ++ ncm

end FrontChecks
