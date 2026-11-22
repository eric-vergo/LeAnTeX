/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX
import LeAnTeXTest.FrontChecks
import LeAnTeXTest.JsonParse
import LeAnTeXTest.MathBoxChecks

/-!
# Documents against LuaLaTeX

Every document of the document corpus (`corpus/doc/*.tex`) typeset with `typesetDocument` in
New Computer Modern and compared with LuaLaTeX's answers (`fixtures/doc/*.json`, recorded by
`tools/doc-reference.sh`):

* **pages**: the same number of pages;
* **lines**: on every page the same lines in the same order, each at the same position (its
  left edge and baseline, to the sp) with the same text (spaces normalised; a line with a
  formula is compared by position only);
* **numbers**: the labels' texts and pages (`\newlabel` of LaTeX's auxiliary file), the table
  of contents (level, number, page) and the counter steps (counter and printed value, for the
  counters both record).

A document agrees when all of these agree. `parity/doc-baseline.tsv` lists the documents that
agreed when it was written; `lake test` fails when one of them no longer agrees (or a fixture
is missing) and reports the others. `lake exe leantex-test --update-doc` rewrites the baseline
and `parity/DOC.md`; `--show-doc NAME` prints a document's differences, and `--show-vlist NAME`
the first node of each page's body (glue, box, penalty, kern, rule; empty glue left out) where
it differs from LuaLaTeX's recorded list.

The class parameters (`LeAnTeX.Doc.Class`) are also checked against the recorded values
(`fixtures/doc/class/params-*.txt`).
-/

namespace DocChecks

open LeAnTeX LeAnTeX.Text LeAnTeX.Doc

/-- A number of a JSON value as an integer. -/
def int (j : Json) : Int := match j.getNum? with
  | some x => if x < 0 then -((-x).toUInt64.toNat : Int) else (x.toUInt64.toNat : Int)
  | none => 0

/-- A text with runs of spaces made one and the ends trimmed. -/
def norm (s : String) : String :=
  let words := (s.splitOn " ").filter (· ≠ "")
  " ".intercalate words

/-- Whether a character is in the Basic Multilingual Plane's private use area (U+E000–U+F8FF). -/
def isPua (c : Char) : Bool := c.toNat ≥ 0xE000 && c.toNat ≤ 0xF8FF

/-- What the private-use characters of the fonts stand for: each such character a glyph of the
fonts maps from, with the texts it can stand for. A ligature glyph (the `liga` feature) stands
for its components (`ft` for the `ft` ligature); a small capital (the `smcp` feature) for the
letter it replaces. -/
abbrev PuaTable := Std.HashMap Char (Array String)

/-- The private-use characters of some fonts with what they stand for, read from the fonts'
own `liga` and `smcp` substitutions (`PuaTable`). An expansion that itself holds a private-use
character is left out. -/
def puaTableOf (infos : List FontInfo) : PuaTable := Id.run do
  let mut out : PuaTable := {}
  for i in infos do
    let some g := i.font.gsub | continue
    let charOf := fun (x : Nat) => i.chars[x]?
    let add := fun (t : PuaTable) (glyph : Nat) (text : String) =>
      match charOf glyph with
      | some c =>
        if isPua c && !text.isEmpty && !text.any isPua then
          let old := t.getD c #[]
          if old.contains text then t else t.insert c (old.push text)
        else t
      | none => t
    for feat in ["liga", "smcp"] do
      for li in g.table.lookupsFor feat "latn" do
        for st in g.substs[li]?.getD #[] do
          for g0 in [0:i.font.numGlyphs] do
            match st with
            | .ligature cov sets =>
              if let some k := cov.index? g0 then
                for (lig, rest) in sets[k]?.getD #[] do
                  let comps := (#[g0] ++ rest).filterMap charOf
                  if comps.size == rest.size + 1 then
                    out := add out lig (String.ofList comps.toList)
            | .single cov gl =>
              if let some k := cov.index? g0 then
                if let some c := charOf g0 then
                  out := add out (gl[k]?.getD 0) (String.singleton c)
            | .delta cov d =>
              if (cov.index? g0).isSome then
                if let some c := charOf g0 then
                  out := add out ((g0 + d) % 65536) (String.singleton c)
  return out

/-- The private-use table of the committed New Computer Modern fonts, read once per run. -/
initialize puaCache : IO.Ref (Option PuaTable) ← IO.mkRef none

/-- The private-use table of the committed New Computer Modern fonts (`puaTableOf`), read once
per run; empty without the fonts. -/
def puaTable : IO PuaTable := do
  if let some t := ← puaCache.get then return t
  let (infos, _) ← loadNewComputerModern "fonts/newcomputermodern"
  let t := puaTableOf (infos.toList.map (·.2))
  puaCache.set (some t)
  return t

/-- Matches our text against LuaLaTeX's, character by character. A private-use character on
either side that `table` knows is replaced by one of the texts it stands for (each tried in
turn); one it does not know matches exactly one character of the other side, and is counted.
Every other character must be equal. Returns `none` when the texts differ, else the number of
private-use characters matched without the table. -/
def textMatch (table : PuaTable) (ours theirs : String) : Option Nat :=
  if ours == theirs then some 0 else
  go (4 * (ours.length + theirs.length) + 16) ours.toList theirs.toList
where
  /-- The match of the rest of both texts, with a bound on the steps. -/
  go : Nat → List Char → List Char → Option Nat
    | 0, _, _ => none
    | _ + 1, [], [] => some 0
    | fuel + 1, a :: as, bs =>
      if isPua a then
        match table[a]? with
        | some es => es.toList.findSome? fun e => go fuel (e.toList ++ as) bs
        | none => match bs with
          | _ :: bs' => (go fuel as bs').map (· + 1)
          | [] => none
      else match bs with
        | b :: bs' =>
          if isPua b then
            match table[b]? with
            | some es => es.toList.findSome? fun e => go fuel (a :: as) (e.toList ++ bs')
            | none => (go fuel as bs').map (· + 1)
          else if a == b then go fuel as bs' else none
        | [] => none
    | fuel + 1, [], b :: bs' =>
      if isPua b then
        match table[b]? with
        | some es => es.toList.findSome? fun e => go fuel [] (e.toList ++ bs')
        | none => none
      else none

/-- Whether our text is LuaLaTeX's (`textMatch`): equal, but for private-use characters, each
replaced by what the fonts' tables say it stands for or matching one character. -/
def sameText (ours theirs : String) (table : PuaTable := {}) : Bool :=
  (textMatch table ours theirs).isSome

/-- The checks of the text comparison (`sameText`): the failures. Each case states what it
catches: a private-use character must stand for the characters at its own place only, and
through the fonts' tables where they know it. -/
def textChecks : IO (Array String) := do
  let table ← puaTable
  let ft := (table.toList.find? fun (_, es) => es.contains "ft").map (·.1)
  let sc := String.ofList ['S', .ofNat 0xF76D, .ofNat 0xF761, .ofNat 0xF76C, .ofNat 0xF76C]
  let cases : List (String × Bool) := [
    -- one unknown private-use character of LuaLaTeX's does not excuse the rest of the line
    ("an unknown private-use character takes one place",
      !sameText "completely different" "A\uE000"),
    ("one for one, without a table", sameText "AB" "A\uE000"),
    ("one for one: not two", !sameText "ABC" "A\uE000"),
    ("different text without private-use characters", !sameText "after" "afier" table),
    -- the small capitals of LuaLaTeX's text through the font's `smcp` table
    ("small capitals through the font's table", sameText "Small" sc table),
    ("small capitals: the letters are compared", !sameText "Smell" sc table),
    -- our `ft` ligature through the font's `liga` table
    ("the ft ligature is known to the fonts' table", ft.isSome),
    ("a ligature through the font's table",
      ft.all fun c => sameText (String.ofList ['a', c, 'e', 'r']) "after" table),
    ("a ligature: its components are compared",
      ft.all fun c => !sameText (String.ofList ['a', c, 'e', 'r']) "afier" table),
    ("a ligature: not one for one", ft.all fun c => !sameText (String.ofList ['a', c]) "af" table)]
  return (cases.filter (!·.2)).toArray.map fun (n, _) => s!"text comparison: {n}"

/-- The outcome for one document: the differences (empty when it agrees), the numbers of pages
and lines compared, and how many lines agree. -/
structure Outcome where
  /-- The document. -/
  name : String
  /-- The differences. -/
  diffs : Array String := #[]
  /-- Lines in LuaLaTeX's pages. -/
  lines : Nat := 0
  /-- Lines at the same place with the same text (a line with a formula: at the same place). -/
  sameLines : Nat := 0
  /-- Of `sameLines`, the lines with a formula, whose text is not compared. -/
  positionOnly : Nat := 0
  /-- Private-use characters of LuaLaTeX's or our text that the fonts' tables do not know,
  matched one for one in lines counted in `sameLines`. -/
  unmapped : Nat := 0
  /-- Lines at the same place to within 1 pt. -/
  nearLines : Nat := 0
  /-- LuaLaTeX's page breaks (its pages less one). -/
  breaks : Nat := 0
  /-- Page breaks at LuaLaTeX's place: the page after the break begins with LuaLaTeX's first
  line (its text, or for a line with a formula its position). -/
  sameBreaks : Nat := 0
  /-- Of `sameBreaks`, the breaks whose next page begins with a line with a formula, compared by
  that line's position only. -/
  breaksByPosition : Nat := 0
  /-- The formulas the TeX-rule layout refused (set by the KaTeX-compatible layout although the
  metric files were there): the offset in the source and the reason. -/
  fallbacks : Array (Nat × String) := #[]
  deriving Inhabited

/-- The outcome with one more difference. -/
def Outcome.add (o : Outcome) (d : String) : Outcome := { o with diffs := o.diffs.push d }

/-- The label lines of the fixture as key, text, page: LaTeX's `\newlabel{k}{{t}{p}}`. -/
def fixtureLabels (j : Json) : Array (String × String × String) := Id.run do
  let mut out := #[]
  for l in ((j.get? "labels").bind Json.getArr?).getD #[] do
    let some s := l.getStr? | continue
    -- \newlabel{key}{{text}{page}...}
    let parts := groups s
    if let some key := parts[0]? then
      let inner := groups (parts[1]?.getD "")
      out := out.push (key, inner[0]?.getD "", inner[1]?.getD "")
  return out
where
  /-- The top-level brace groups of a text. -/
  groups (s : String) : Array String := Id.run do
    let mut out := #[]
    let mut depth := 0
    let mut cur := ""
    for c in s.toList do
      if c == '{' then
        if depth > 0 then cur := cur.push c
        depth := depth + 1
      else if c == '}' then
        depth := depth - 1
        if depth == 0 then out := out.push cur; cur := "" else cur := cur.push c
      else if depth > 0 then cur := cur.push c
    return out

/-- The contents lines of the fixture as level, number, title, page (from the auxiliary file's
`\@writefile{toc}{\contentsline {section}{\numberline {1}Title}{page}{}}`; the title as LaTeX
wrote it, after the number). -/
def fixtureToc (j : Json) : Array (Nat × String × String × String) := Id.run do
  let mut out := #[]
  for l in ((j.get? "labels").bind Json.getArr?).getD #[] ++
      ((j.get? "toc").bind Json.getArr?).getD #[] do
    let some s := l.getStr? | continue
    let s := if s.startsWith "{" then (s.drop 1).toString else s
    if !(s.startsWith "\\contentsline") then continue
    let g := fixtureLabels.groups s
    let level := match (g[0]?.getD "").trimAscii.toString with
      | "section" => 1 | "subsection" => 2 | "subsubsection" => 3 | "paragraph" => 4
      | _ => 5
    let title := g[1]?.getD ""
    let (num, text) := if title.startsWith "\\numberline " then
        let rest := (title.drop "\\numberline ".length).toString
        let n := (fixtureLabels.groups rest)[0]?.getD ""
        (n, (rest.drop (n.length + 2)).toString)
      else ("", title)
    out := out.push (level, num, text, (g[2]?.getD "").trimAscii.toString)
  return out

/-- A contents title as text to compare: TeX's space after a control word dropped and runs of
spaces made one. -/
def tocTitle (s : String) : String :=
  norm ((s.replace "\\protect " "").replace " {" "{")

/-- A counter's printed value as LuaLaTeX's recorder writes it, with the footnote symbols
(`\TextOrMath {\textasteriskcentered }{*}`, …) as the characters they print. -/
def printedValue (v : String) : String := Id.run do
  let syms := [("textasteriskcentered", "∗"), ("textdaggerdbl", "‡"), ("textdagger", "†"),
    ("textsection", "§"), ("textparagraph", "¶"), ("textbardbl", "‖")]
  let mut out := ""
  for piece in (v.splitOn "\\TextOrMath").drop 1 do
    match syms.find? (fun (n, _) => (piece.splitOn ("\\" ++ n ++ " ")).length > 1) with
    | some (_, c) => out := out ++ c
    | none => return v
  return if out.isEmpty then v else out

/-- The directory of a document's source and fixture: `doc`, or `doc-heldout` for the held-out
documents (`held-…`). -/
def setOf (name : String) : String :=
  if name.startsWith "held-" then "doc-heldout"
  else if name.startsWith "blind-" then "doc-heldout-2" else "doc"

/-- Whether a document's source has a formula (`$`, `\(`, `\[` or a math environment):
such a document is set with TeX's boxes only when the metric files are there. -/
def hasFormulas (src : String) : Bool :=
  src.contains '$' || (src.splitOn "\\(").length > 1 || (src.splitOn "\\[").length > 1 ||
    ["equation", "align", "gather", "multline", "eqnarray", "displaymath", "math"].any
      fun e => (src.splitOn ("\\begin{" ++ e)).length > 1

/-- Compares one document with its fixture. -/
def compare (name : String) (resolve : FontResolver) : IO Outcome := do
  let src ← IO.FS.readFile s!"corpus/{setOf name}/{name}.tex"
  let fx ← match Json.parse (← IO.FS.readFile s!"fixtures/{setOf name}/{name}.json") with
    | .ok j => pure j
    | .error e => return { name, diffs := #[s!"fixture: {e}"] }
  let theirs := ((fx.get? "pages").bind Json.getArr?).getD #[]
  let total := theirs.foldl (init := 0) fun n p =>
    n + (((p.get? "lines").bind Json.getArr?).getD #[]).size
  -- the images the corpus documents include
  let png ← IO.FS.readBinFile "corpus/doc/images/square.png"
  let cfg : Text.Settings :=
    { images := fun p => if p == "images/square.png" then some png else none,
      mathTfms := ← MathBoxChecks.mathTfms }
  let table ← puaTable
  match typesetDocument src resolve cfg with
  | .error e => return { name, diffs := #[s!"error: {e.message} at {e.pos}"], lines := total }
  | .ok r =>
    let mut o : Outcome :=
      { name, lines := total, breaks := theirs.size - 1, fallbacks := r.mathFallbacks }
    for i in [1:theirs.size] do
      let first := ((theirs[i]!.get? "lines").bind Json.getArr?).bind (·[0]?)
      let tt := norm (((first.bind (·.get? "text")).bind Json.getStr?).getD "")
      let at_ := fun (a : PlacedLine) => match first with
        | some b => a.x == int ((b.get? "x").getD .null) && a.y == int ((b.get? "y").getD .null)
        | none => false
      match (r.pages[i]?.bind (·.lines[0]?)) with
      | some a =>
        if a.math then
          if at_ a then
            o := { o with sameBreaks := o.sameBreaks + 1,
                          breaksByPosition := o.breaksByPosition + 1 }
        else if sameText (norm a.text) tt table then
          o := { o with sameBreaks := o.sameBreaks + 1 }
      | none => pure ()
    if r.pages.size != theirs.size then
      o := o.add s!"pages: {r.pages.size}, LuaLaTeX {theirs.size}"
    for i in [0:min r.pages.size theirs.size] do
      let ours := r.pages[i]!.lines
      let tl := ((theirs[i]!.get? "lines").bind Json.getArr?).getD #[]
      if ours.size != tl.size then
        o := o.add s!"page {i + 1}: {ours.size} lines, LuaLaTeX {tl.size}"
      for k in [0:min ours.size tl.size] do
        let a := ours[k]!
        let b := tl[k]!
        let bx := int ((b.get? "x").getD .null)
        let byy := int ((b.get? "y").getD .null)
        let bt := norm (((b.get? "text").bind Json.getStr?).getD "")
        -- a line with a formula: our text is its source, LuaLaTeX's the glyphs of the math
        -- fonts, so the text is not compared
        let text := if a.math then some 0 else textMatch table (norm a.text) bt
        let textOk := text.isSome
        let posOk := a.x == bx && a.y == byy
        if posOk && textOk then
          o := { o with sameLines := o.sameLines + 1, unmapped := o.unmapped + text.getD 0,
                        positionOnly := o.positionOnly + (if a.math then 1 else 0) }
        if textOk && (a.x - bx).natAbs ≤ 65536 && (a.y - byy).natAbs ≤ 65536 then
          o := { o with nearLines := o.nearLines + 1 }
        if !(posOk && textOk) then
          o := o.add s!"page {i + 1} line {k + 1}: ({a.x}, {a.y}) '{(norm a.text).take 40}', \
              LuaLaTeX ({bx}, {byy}) '{bt.take 40}' (dy {a.y - byy})"
    -- labels: the same keys (the recorder reads `\newlabel` only, so our bibliography keys,
    -- `bib@…`, have no counterpart), each with LuaLaTeX's text and page
    for (k, t, p) in fixtureLabels fx do
      match r.labels.find? (·.1 == k) with
      | some (_, t', p') =>
        if t' != t || p' != p then
          o := o.add s!"label {k}: '{t'}' p. {p'}, LuaLaTeX '{t}' p. {p}"
      | none => o := o.add s!"label {k}: missing"
    let fkeys := (fixtureLabels fx).map (·.1)
    for (k, _, _) in r.labels do
      if !k.startsWith "bib@" && !fkeys.contains k then
        o := o.add s!"label {k}: not in LuaLaTeX's labels"
    -- contents
    let ft := fixtureToc fx
    let ot := r.toc.filter (·.1 ≤ 3)
    let ft := ft.filter (·.1 ≤ 3)
    -- the contents are compared when the document prints them: without `\tableofcontents`
    -- they are not part of the output (and the recorded entries depend on whether LaTeX's
    -- auxiliary file was written with them in the run the recorder read)
    let printsToc := (src.splitOn "\\tableofcontents").length > 1
    let ot := if printsToc then ot else #[]
    let ft := if printsToc then ft else #[]
    if ft.size != ot.size then
      o := o.add s!"contents: {ot.size} entries, LuaLaTeX {ft.size}"
    for ((l, n, t, p), (l', n', t', p')) in ft.zip ot do
      if l != l' || n != n' || p != p' || tocTitle t != tocTitle t' then
        o := o.add s!"contents: {l'} {n'} '{tocTitle t'}' p. {p'}, LuaLaTeX {l} {n} \
          '{tocTitle t}' p. {p}"
    -- counter steps of the counters both know
    let known := ["section", "subsection", "subsubsection", "equation", "figure", "table",
      "footnote", "enumi", "enumii", "enumiii", "enumiv"]
    let fs := (((fx.get? "counters").bind Json.getArr?).getD #[]).filterMap fun c =>
      match c.getArr? with
      | some #[_, n, v] => match n.getStr?, v.getStr? with
        | some n, some v => if known.contains n then some (n, printedValue v) else none
        | _, _ => none
      | _ => none
    let os := r.steps.filter fun (n, _) => known.contains n
    if fs.toList != os.toList then
      o := o.add s!"counter steps: {os.size}, LuaLaTeX {fs.size}"
    return o

/-- The documents of a set (`doc` or `doc-heldout`) that have a fixture. -/
def documents (set : String := "doc") : IO (Array String) := do
  let mut out := #[]
  if !(← System.FilePath.pathExists s!"corpus/{set}") then return out
  for e in ← System.FilePath.readDir s!"corpus/{set}" do
    if e.fileName.endsWith ".tex" then
      let n := e.fileName.dropEnd 4 |>.toString
      if ← System.FilePath.pathExists s!"fixtures/{set}/{n}.json" then out := out.push n
  return out.qsort (· < ·)

/-- Mutated documents: from every corpus document, `n` sources with characters deleted,
duplicated or replaced by TeX's special characters, or cut short (a fixed linear congruential
generator, so every run is the same). Each must end in pages or a clean error; returns how
many gave pages and how many errors. -/
def fuzz (resolve : FontResolver) (n : Nat) : IO (Nat × Nat) := do
  let specials := "{}\\$&#^_%~[]*@ \nabcx01".toList.toArray
  let mut seed : Nat := 20251115
  let mut ok := 0
  let mut err := 0
  let cfg : Text.Settings := { maxTokens := 200000, maxExpansions := 20000 }
  for name in ← documents do
    let src := (← IO.FS.readFile s!"corpus/doc/{name}.tex").toList.toArray
    for _ in [0:n] do
      let mut cs := src
      for _ in [0:3] do
        seed := (seed * 1103515245 + 12345) % 2147483648
        let pos := seed % (cs.size + 1)
        seed := (seed * 1103515245 + 12345) % 2147483648
        let c := specials[seed % specials.size]!
        match seed % 4 with
        | 0 => cs := cs.eraseIdxIfInBounds pos
        | 1 => cs := cs.insertIdxIfInBounds pos c
        | 2 => cs := cs.setIfInBounds pos c
        | _ => cs := cs.extract 0 (pos + cs.size / 2)
      match typesetDocument (String.ofList cs.toList) resolve cfg (maxPasses := 2) with
      | .ok _ => ok := ok + 1
      | .error _ => err := err + 1
  return (ok, err)

/-- A text as a cell of the report's Markdown tables: control characters (a fixture's text
may hold the bytes of a font's own encoding) written as `\u{…}` escapes, and `|` escaped. -/
def reportCell (s : String) : String :=
  s.foldl (init := "") fun out c =>
    if c == '|' then out ++ "\\|"
    else if c.toNat < 0x20 || c.toNat == 0x7F then
      out ++ "\\u{" ++ String.ofList (Nat.toDigits 16 c.toNat) ++ "}"
    else out.push c

/-- Whether a text has a control character other than a line feed (`parity/DOC.md` must not). -/
def hasControl (s : String) : Bool :=
  s.any fun c => c != '\n' && (c.toNat < 0x20 || c.toNat == 0x7F)

/-- The formulas the TeX-rule layout refused in some outcomes: their number and the first
few, as document and offset. -/
def fallbackSummary (outs : Array Outcome) : String :=
  let all := outs.toList.flatMap fun o => o.fallbacks.toList.map fun (p, _) => s!"{o.name}@{p}"
  let first := ", ".intercalate (all.take 5)
  if all.isEmpty then "none" else s!"{all.length} ({first}{if all.length > 5 then ", …" else ""})"

/-- The feature a document exercises, from its name. -/
def feature (name : String) : String :=
  let pre := (name.splitOn "-").headD name
  match pre with
  | "sections" | "title" | "toc" | "counters" | "refs" | "lengths" | "options" | "abstract" =>
    "structure"
  | "itemize" | "enumerate" | "description" => "lists"
  | "quote" | "center" | "verbatim" | "newenvironment" | "theorem" | "emph" | "accents"
  | "rules" | "equation" | "align" => "environments"
  | "footnotes" => "footnotes"
  | "float" => "floats"
  | "tabular" => "tables"
  | "pages" | "newpage" | "skips" | "widows" | "nopagebreak" | "pagestyle" | "thispagestyle" =>
    "page breaking"
  | "bib" => "bibliographies"
  | "fresh" => "fresh (written without reading LeAnTeX)"
  | _ => "combined"

/-- One node of a body's vertical list as the fixture writes it: `glue w stretch order shrink
order subtype`, `h w h d shift`, `p n`, `k w`, `r h d` (the text of a box left out). -/
def nodeText : VNode → Option String
  | .glue g st => some s!"glue {g.width} {g.stretch} {g.stretchOrder} {g.shrink} \
      {g.shrinkOrder} {st}"
  | .hbox w h d sh _ _ => some s!"h {w} {h} {d} {sh}"
  | .vbox w h d sh _ _ => some s!"h {w} {h} {d} {sh}"
  | .penalty n => some s!"p {n}"
  | .kern w => some s!"k {w}"
  | .rule _ h d => some s!"r {h} {d}"
  | _ => none

/-- The same for a fixture's item (`["glue", …]`, `["h", …]`, `["p", n]`, `["rule", w, h, d]`,
…); whatsits and other items are left out. LuaTeX's glue orders (0 finite, 1 `fi`, 2 `fil`,
3 `fill`, 4 `filll`) are written as `Glue` has them (0, 1 `fil`, 2 `fill`, 3 `filll`; `fi` as
`fi`). -/
def itemText (j : Json) : Option String :=
  match j.getArr? with
  | some a =>
    let n := fun (k : Nat) => int (a[k]?.getD .null)
    let order := fun (k : Nat) => match n k with
      | 0 => "0" | 1 => "fi" | o => toString (o - 1)
    match (a[0]?.bind Json.getStr?) with
    | some "glue" => some s!"glue {n 1} {n 2} {order 3} {n 4} {order 5} {n 6}"
    | some "h" | some "v" => some s!"h {n 1} {n 2} {n 3} {n 4}"
    | some "p" => some s!"p {n 1}"
    | some "k" => some s!"k {n 1}"
    | some "rule" => some s!"r {n 2} {n 3}"
    | _ => none
  | none => none

/-- The first node at which the body of each page differs from LuaLaTeX's, with six nodes before
it and three after for context (`--show-vlist NAME`); with `full` every node of every page,
side by side (`--dump-vlist NAME`). -/
def showVList (name : String) (full : Bool := false) : IO Unit := do
  let some resolve ← FrontChecks.newComputerModern | IO.println "fonts missing"; return
  let src ← IO.FS.readFile s!"corpus/{setOf name}/{name}.tex"
  let .ok fx := Json.parse (← IO.FS.readFile s!"fixtures/{setOf name}/{name}.json")
    | IO.println "fixture unreadable"; return
  let theirs := ((fx.get? "pages").bind Json.getArr?).getD #[]
  let png ← IO.FS.readBinFile "corpus/doc/images/square.png"
  let cfg : Text.Settings :=
    { images := fun p => if p == "images/square.png" then some png else none,
      mathTfms := ← MathBoxChecks.mathTfms }
  match typesetDocument src resolve cfg with
  | .error e => IO.println s!"error: {e.message}"
  | .ok r =>
    for i in [0:min r.pages.size theirs.size] do
      -- glue of nothing at all (LuaTeX keeps some that change no position) is left out
      let empty := fun (t : String) => t.startsWith "glue 0 0 0 0 0 "
      let ours := (r.pages[i]!.body.content.filterMap nodeText).filter (!empty ·)
      let items := (((((theirs[i]!.get? "body").bind (·.get? "items")).bind Json.getArr?).getD
        #[]).filterMap itemText).filter (!empty ·)
      if full then
        IO.println s!"page {i + 1}"
        for k in [0:max ours.size items.size] do
          IO.println s!"  {if ours[k]? == items[k]? then " " else "*"} ours {ours[k]?.getD ""}  \
            |  LuaLaTeX {items[k]?.getD ""}"
        continue
      match (List.range (min ours.size items.size)).find? (fun k => ours[k]! != items[k]!) with
      | some k =>
        IO.println s!"page {i + 1}: node {k} of {ours.size} (LuaLaTeX {items.size})"
        for j in [k - min k 6:min (k + 4) (min ours.size items.size)] do
          IO.println s!"  ours {ours[j]!}  |  LuaLaTeX {items[j]!}"
        break
      | none =>
        if ours.size != items.size then
          IO.println s!"page {i + 1}: same first {min ours.size items.size} nodes, then \
            {ours.size} against {items.size}"
          break

/-- The totals of some outcomes. -/
structure Totals where
  /-- Documents agreeing. -/
  agree : Nat
  /-- Documents. -/
  docs : Nat
  /-- Lines at the same place (with the same text, but for lines with a formula). -/
  same : Nat
  /-- Of `same`, lines with a formula, compared by position only. -/
  positionOnly : Nat
  /-- Private-use characters matched one for one, without the fonts' tables. -/
  unmapped : Nat
  /-- Lines. -/
  lines : Nat
  /-- Lines within 1 pt. -/
  near : Nat
  /-- Page breaks at the same place. -/
  sameBreaks : Nat
  /-- Of `sameBreaks`, those decided by the position of a line with a formula. -/
  breaksByPosition : Nat
  /-- Page breaks. -/
  breaks : Nat

/-- The totals of some outcomes. -/
def totals (outs : Array Outcome) : Totals :=
  let sum := fun (f : Outcome → Nat) => outs.foldl (init := 0) (· + f ·)
  { agree := (outs.filter (·.diffs.isEmpty)).size, docs := outs.size, same := sum (·.sameLines),
    positionOnly := sum (·.positionOnly), unmapped := sum (·.unmapped), lines := sum (·.lines),
    near := sum (·.nearLines), sameBreaks := sum (·.sameBreaks),
    breaksByPosition := sum (·.breaksByPosition), breaks := sum (·.breaks) }

/-- A table row of totals: documents, lines to the sp (and how many of them are lines with a
formula, compared by position only), lines within 1 pt, page breaks (and how many of them were
decided by a formula line's position). -/
def totalsRow (label : String) (outs : Array Outcome) : String :=
  let t := totals outs
  s!"| {label} | {t.agree} / {t.docs} | {t.same} / {t.lines} | {t.positionOnly} | {t.near} | \
    {t.sameBreaks} / {t.breaks} | {t.breaksByPosition} |\n"

/-- The header of a table of `totalsRow` rows, its first column named `first`. -/
def totalsHeader (first : String) : String :=
  s!"| {first} | Documents agreeing | Lines at the same place | Of them with a formula \
    (position only) | Within 1 pt | Page breaks | Of them by position only |\n\
    |---|---|---|---|---|---|---|\n"

/-- The driver's sentence for some outcomes' lines and page breaks, as `lake test` prints it. -/
def linesSentence (t : Totals) : String :=
  s!"lines at the same place {t.same} of {t.lines} ({t.positionOnly} of them with a formula, \
    by position only), within 1 pt {t.near}; page breaks {t.sameBreaks} of {t.breaks} \
    ({t.breaksByPosition} by position only); private-use characters matched without the \
    fonts' tables {t.unmapped}"

/-- The machine-readable lines of some outcomes' totals for the manual's figure table:
`figure KEY VALUE`, one per number, the key `set.field`. -/
def figureLines (set : String) (t : Totals) : String :=
  String.join ([("agree", t.agree), ("docs", t.docs), ("same", t.same),
    ("positionOnly", t.positionOnly), ("lines", t.lines), ("near", t.near),
    ("sameBreaks", t.sameBreaks), ("breaksByPosition", t.breaksByPosition),
    ("breaks", t.breaks), ("unmapped", t.unmapped)].map fun (k, v) =>
      s!"figure {set}.{k} {v}\n")

/-- The held-out documents (`corpus/doc-heldout/`, or the second set `corpus/doc-heldout-2/`),
written without reading this library; their agreement is reported, never required. The first
set has been run many times since it was written (see `docs/documents.md`); the second was run
once and never tuned to. -/
def heldOut (resolve : FontResolver) (set : String := "doc-heldout") : IO (Array Outcome) := do
  let mut outs := #[]
  for n in ← documents set do outs := outs.push (← compare n resolve)
  return outs

/-- One line per document of a set: whether it agrees, its lines and its first difference
(`--doc-table [heldout]`). -/
def table (set : String) : IO Unit := do
  let some resolve ← FrontChecks.newComputerModern | IO.println "fonts missing"; return
  let mut outs := #[]
  for n in ← documents set do
    let o ← compare n resolve
    outs := outs.push o
    IO.println s!"{n}\t{if o.diffs.isEmpty then "yes" else "no"}\t{o.sameLines}/{o.lines}\t\
      {o.nearLines}\t{o.sameBreaks}/{o.breaks}\t{(o.diffs[0]?.getD "").take 110}"
  IO.print (totalsRow "all" outs)
  IO.println (linesSentence (totals outs))

/-- The list parameters at every probe of `corpus/doc-probe/lists.tex` against LuaLaTeX's
(`fixtures/doc/probe/lists-<size>.txt`, `tools/list-params.sh`) for the three class sizes:
the differences, each as the probe's label, the parameter, ours and LuaLaTeX's. -/
def probeDiffs (resolve : FontResolver) : IO (Array String) := do
  let src ← IO.FS.readFile "corpus/doc-probe/lists.tex"
  let mut out := #[]
  for size in ["10pt", "11pt", "12pt"] do
    let path := s!"fixtures/doc/probe/lists-{size}.txt"
    if !(← System.FilePath.pathExists path) then
      out := out.push s!"{size}: no fixture"
      continue
    let theirs := (((← IO.FS.readFile path).splitOn "\n").filter (·.startsWith "PROBE ")).toArray
    let src' := src.replace "\\documentclass{article}" s!"\\documentclass[{size}]\{article}"
    match typesetDocument src' resolve { probes := true } (maxPasses := 1) with
    | .error e => out := out.push s!"{size}: error {e.message}"
    | .ok r =>
      if r.probes.size != theirs.size then
        out := out.push s!"{size}: {r.probes.size} probes, LuaLaTeX {theirs.size}"
      for (a, b) in r.probes.zip theirs do
        let fa := (a.splitOn " ").toArray
        let fb := (b.splitOn " ").toArray
        for (x, y) in fa.zip fb do
          if x != y then
            out := out.push s!"{size} {fa[1]?.getD ""}: {x}, LuaLaTeX {y}"
  return out

/-- A horizontal list in short form, for `--show-paragraphs`: characters as themselves, the
other nodes in brackets with their sizes. -/
partial def hShort (n : HNode) : String := match n with
  | .glyph c .. => c.toString
  | .kern w _ => s!"[k{w}]"
  | .glue g st => s!"[g{g.width}+{g.stretch}/{g.stretchOrder}-{g.shrink} s{st}]"
  | .penalty p => s!"[p{p}]"
  | .disc .. => "[-]"
  | .box w h d _ c => s!"[box {w} {h} {d} " ++ String.join (c.toList.map hShort) ++ "]"
  | .rule w h d => s!"[rule {w} {h} {d}]"
  | .math w h d _ _ => s!"[math {w} {h} {d}]"

/-- Every paragraph's horizontal list of a document as the line breaker received it
(`--show-paragraphs NAME`). -/
def showParagraphs (name : String) : IO Unit := do
  let some resolve ← FrontChecks.newComputerModern | IO.println "fonts missing"; return
  let src ← IO.FS.readFile s!"corpus/{setOf name}/{name}.tex"
  match typeset src resolve with
  | .error e => IO.println s!"error: {e.message}"
  | .ok d =>
    for h : k in [0:d.paragraphs.size] do
      IO.println s!"{k}: {String.join (d.paragraphs[k].toList.map hShort)}"

/-- Runs every document; with `update` rewrites the baseline and the report. Returns the
failures (a baselined document that no longer agrees). -/
def run (update : Bool := false) (show? : Option String := none) : IO (Array String) := do
  let some resolve ← FrontChecks.newComputerModern
    | return #["documents: the New Computer Modern fonts are missing"]
  let names ← documents
  let hasBase ← System.FilePath.pathExists "parity/doc-baseline.tsv"
  let baseText ← if hasBase then IO.FS.readFile "parity/doc-baseline.tsv" else pure ""
  let baseline := (baseText.splitOn "\n").filter (· ≠ "")
  let mut outs := #[]
  for n in names do
    if let some w := show? then if w != n then continue
    let o ← compare n resolve
    outs := outs.push o
    if show?.isSome then
      for d in o.diffs do IO.println s!"  {d}"
  let agree := outs.filter (·.diffs.isEmpty)
  let all := totals outs
  IO.println s!"  documents: {all.agree} of {all.docs} agree with LuaLaTeX; {linesSentence all}"
  let fresh := outs.filter (·.name.startsWith "fresh-")
  let reference := outs.filter (!·.name.startsWith "fresh-")
  if show?.isNone then
    IO.print (figureLines "reference" (totals reference))
    IO.print (figureLines "fresh" (totals fresh))
  IO.println s!"  formulas the TeX-rule layout refused (set by the KaTeX-compatible layout): \
    {fallbackSummary outs}"
  if show?.isNone then IO.println s!"  {← MathBoxChecks.run update}"
  -- the held-out set is skipped with LEANTEX_SKIP_HELDOUT (while the layer is being worked on)
  let skipHeld := (← IO.getEnv "LEANTEX_SKIP_HELDOUT").isSome
  let held ← if show?.isNone && !skipHeld then heldOut resolve else pure #[]
  if !held.isEmpty then
    let t := totals held
    IO.println s!"  held-out documents (reported, not required): {t.agree} of {t.docs} agree; \
      {linesSentence t}; formulas the TeX-rule layout refused: {fallbackSummary held}"
    IO.print (figureLines "heldout" t)
  let held2 ← if show?.isNone && !skipHeld then heldOut resolve "doc-heldout-2" else pure #[]
  if !held2.isEmpty then
    let t := totals held2
    IO.println s!"  second held-out set (reported, not required): {t.agree} of {t.docs} agree; \
      {linesSentence t}; formulas the TeX-rule layout refused: {fallbackSummary held2}"
    IO.print (figureLines "heldout2" t)
  if show?.isNone then
    let (fok, ferr) ← fuzz resolve 6
    IO.println s!"  mutated documents: {fok + ferr} ended ({fok} with pages, {ferr} with an error)"
  let mut fails := #[]
  -- a formula past the TeX-rule layout's work budget (16000 atoms) is set by the
  -- KaTeX-compatible layout as one box, which no line break enters, with a warning naming it
  let tfms ← MathBoxChecks.mathTfms
  if show?.isNone && tfms.contains "cmmi10" then
    let src := "\\documentclass{article}\\begin{document}$" ++
      "+".intercalate (List.replicate 16000 "a") ++ "$\\end{document}"
    match typesetDocument src resolve { mathTfms := tfms } with
    | .ok r =>
      let says := fun (w t : String) => (w.splitOn t).length > 1
      let warned := r.warnings.any fun w =>
        says w "1 formula set by the KaTeX-compatible layout" && says w "at character 39" &&
          says w "work budget"
      if r.mathFallbacks.size == 1 && warned && r.pages.size == 1 then
        IO.println "  a formula of 16000 atoms: one box by the KaTeX-compatible layout, warned"
      else
        fails := fails.push s!"a formula of 16000 atoms: {r.mathFallbacks.size} fallbacks, \
          {r.pages.size} pages, warnings {r.warnings}"
    | .error e => fails := fails.push s!"a formula of 16000 atoms: {e.message}"
  -- the example article's pages, byte for byte (`examples/article/`)
  if show?.isNone then
    let (fonts, missing) ← LeAnTeX.Backend.Fonts.load "fonts/newcomputermodern"
    if missing.isEmpty then
      let src ← IO.FS.readFile "examples/article/article.tex"
      let png ← IO.FS.readBinFile "examples/article/images/square.png"
      let cfg : Text.Settings :=
        { images := fun p => if p == "images/square.png" then some png else none }
      match typesetDocument src fonts.resolver cfg with
      | .ok r =>
        let pages := LeAnTeX.Backend.svgPages fonts.set r "article"
        for h : k in [0:pages.size] do
          let f := s!"examples/article/page-{k + 1}.svg"
          if update then IO.FS.writeFile f pages[k]
          else if (← IO.FS.readFile f) != pages[k] then
            fails := fails.push s!"example {f} differs from what the back end writes"
      | .error e => fails := fails.push s!"example article: {e.message}"
  -- without the metric files formulas are set by the KaTeX-compatible layout, so a baselined
  -- document with formulas is reported as skipped instead of failing
  let haveTfms := (← MathBoxChecks.mathTfms).contains "cmmi10"
  let mut skipped := 0
  for b in baseline do
    match outs.find? (·.name == b) with
    | some o => if !o.diffs.isEmpty then
        if !haveTfms && hasFormulas (← IO.FS.readFile s!"corpus/{setOf b}/{b}.tex") then
          skipped := skipped + 1
        else
          fails := fails.push s!"document {b} no longer agrees: {o.diffs[0]?.getD ""}"
    | none => if show?.isNone then fails := fails.push s!"document {b}: no fixture"
  if skipped > 0 then
    IO.println s!"  documents with formulas: {skipped} not compared with the baseline (no \
      Computer Modern metric files; set LEANTEX_TFM_DIRS)"
  if update then
    IO.FS.writeFile "parity/doc-baseline.tsv"
      (String.join (agree.toList.map (·.name ++ "\n")))
    let mut md := "# Documents against LuaLaTeX\n\nWritten by `lake exe leantex-test \
      --update-doc` (`LeAnTeXTest/DocChecks.lean`). A document agrees when its pages, every \
      line's position (to the sp) and text, its labels, its table of contents and its \
      counter steps are LuaLaTeX's, with these exemptions, counted in the table: a line with a \
      formula is compared by position only (our text of it is its source, LuaLaTeX's the \
      glyphs of the math fonts); a private-use character of either text is replaced by what \
      the fonts' own ligature and small-capital tables say it stands for, and one they do not \
      know matches one character (counted in the driver's line); the bibliography's keys are \
      not compared (the recorder reads `\\newlabel` only); the counter steps are compared for \
      the sectioning, equation, float, footnote and list counters; the contents (levels 1 to \
      3: number, title, page) only in documents that print them. A page break is at \
      LuaLaTeX's place when the page after it begins with LuaLaTeX's line: with its text, or \
      for a line with a formula at its position. The reference documents were written to \
      cover the features and the layer was tuned on them; the fresh and the held-out \
      documents were written by someone who had not read this library. The first held-out \
      set's first recorded score with the TeX-rule layout was 8 of 20 documents (commit \
      `e04b63b`, with the comparison of that commit); the set existed before the TeX-rule \
      layout was developed, four of its fixtures were re-recorded after a fix to the \
      recorder before that score, and a defect it showed was fixed after it, so it is no \
      untouched test. The second held-out set was written blind after that and first \
      recorded at `648d738`; its sources and fixtures have not changed since.\n\n" ++
      totalsHeader "Set"
    md := md ++ totalsRow "reference documents (tuned on)" reference ++
      totalsRow "fresh documents (written blind)" fresh ++
      totalsRow "first held-out set (written blind; 8 / 20 when first recorded)" held ++
      (if held2.isEmpty then "" else
        totalsRow "**second held-out set (written blind, not tuned to)**" held2)
    let refusedAll := fallbackSummary (outs ++ held ++ held2)
    md := md ++ s!"\nFormulas the TeX-rule layout refused although the metric files were \
      there, set by the KaTeX-compatible layout instead: {refusedAll}.\n"
    md := md ++ "\n" ++ totalsHeader "Feature"
    let feats := (outs.map (feature ·.name)).toList.eraseDups
    for f in feats do
      md := md ++ totalsRow f (outs.filter (feature ·.name == f))
    md := md ++ "\n## Per document\n\n| Document | Agrees | Lines same | First difference |\n\
      |---|---|---|---|\n"
    for o in outs ++ held ++ held2 do
      let first := reportCell (o.diffs[0]?.getD "")
      md := md ++ s!"| {o.name} | {if o.diffs.isEmpty then "yes" else "no"} | \
        {o.sameLines} / {o.lines} | {first} |\n"
    IO.FS.writeFile "parity/DOC.md" md
  fails := fails ++ (← textChecks)
  -- the report holds no control characters (they are escaped where it is written)
  if reportCell "a\u0000b\u0015|c" != "a\\u{0}b\\u{15}\\|c" then
    fails := fails.push "report: a control character is not escaped in a table cell"
  if ← System.FilePath.pathExists "parity/DOC.md" then
    if hasControl (← IO.FS.readFile "parity/DOC.md") then
      fails := fails.push "parity/DOC.md has a control character"
  return fails

end DocChecks
