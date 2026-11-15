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

/-- Whether our text is LuaLaTeX's: equal, a ligature glyph the font maps from a private-use
code point (U+E000–U+F8FF) standing for two or three letters of theirs. -/
def sameText (ours theirs : String) : Bool := Id.run do
  if ours == theirs then return true
  let isPua := fun (c : Char) => c.toNat ≥ 0xE000 && c.toNat ≤ 0xF8FF
  -- small capitals and other unmapped glyphs in LuaLaTeX's text: compared by position only
  if theirs.any isPua then return true
  if !ours.any isPua then return false
  -- match piece by piece, a private-use character taking two or three of theirs
  let a := ours.toList.toArray
  let b := theirs.toList.toArray
  let mut i := 0
  let mut j := 0
  for _ in [0:a.size + b.size + 1] do
    if i ≥ a.size then break
    let c := a[i]!
    if isPua c then
      -- try the shortest take that lets the next character match
      let next := a[i + 1]?
      let mut k := 2
      for t in [2:4] do
        if (next.map (b[j + t]? == some ·)).getD (j + t == b.size) then k := t; break
      i := i + 1
      j := j + k
    else
      if b[j]? != some c then return false
      i := i + 1
      j := j + 1
  return j == b.size

/-- The outcome for one document: the differences (empty when it agrees), the numbers of pages
and lines compared, and how many lines agree. -/
structure Outcome where
  /-- The document. -/
  name : String
  /-- The differences. -/
  diffs : Array String := #[]
  /-- Lines in LuaLaTeX's pages. -/
  lines : Nat := 0
  /-- Lines at the same place with the same text. -/
  sameLines : Nat := 0
  /-- Lines at the same place to within 1 pt. -/
  nearLines : Nat := 0
  /-- LuaLaTeX's page breaks (its pages less one). -/
  breaks : Nat := 0
  /-- Page breaks at LuaLaTeX's place: the page after the break begins with LuaLaTeX's first
  line. -/
  sameBreaks : Nat := 0
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

/-- The contents lines of the fixture as level, number, page (from the auxiliary file's
`\@writefile{toc}{\contentsline {section}{\numberline {1}Title}{page}{}}`). -/
def fixtureToc (j : Json) : Array (Nat × String × String) := Id.run do
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
    let num := if title.startsWith "\\numberline " then
        (fixtureLabels.groups title)[0]?.getD "" else ""
    out := out.push (level, num, (g[2]?.getD "").trimAscii.toString)
  return out

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
  match typesetDocument src resolve cfg with
  | .error e => return { name, diffs := #[s!"error: {e.message} at {e.pos}"], lines := total }
  | .ok r =>
    let mut o : Outcome :=
      { name, lines := total, breaks := theirs.size - 1, fallbacks := r.mathFallbacks }
    for i in [1:theirs.size] do
      let first := ((theirs[i]!.get? "lines").bind Json.getArr?).bind (·[0]?)
      let tt := norm (((first.bind (·.get? "text")).bind Json.getStr?).getD "")
      match (r.pages[i]?.bind (·.lines[0]?)) with
      | some a => if a.math || sameText (norm a.text) tt then
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
        let textOk := a.math || sameText (norm a.text) bt
        let posOk := a.x == bx && a.y == byy
        if posOk && textOk then o := { o with sameLines := o.sameLines + 1 }
        if textOk && (a.x - bx).natAbs ≤ 65536 && (a.y - byy).natAbs ≤ 65536 then
          o := { o with nearLines := o.nearLines + 1 }
        if !(posOk && textOk) then
          o := o.add s!"page {i + 1} line {k + 1}: ({a.x}, {a.y}) '{(norm a.text).take 40}', \
              LuaLaTeX ({bx}, {byy}) '{bt.take 40}' (dy {a.y - byy})"
    -- labels
    for (k, t, p) in fixtureLabels fx do
      match r.labels.find? (·.1 == k) with
      | some (_, t', p') =>
        if t' != t || p' != p then
          o := o.add s!"label {k}: '{t'}' p. {p'}, LuaLaTeX '{t}' p. {p}"
      | none => o := o.add s!"label {k}: missing"
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
    for ((l, n, p), (l', n', _, p')) in ft.zip ot do
      if l != l' || n != n' || p != p' then
        o := o.add s!"contents: {l'} {n'} p. {p'}, LuaLaTeX {l} {n} p. {p}"
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

/-- The totals of some outcomes: documents agreeing, documents, lines at the same place, lines,
lines within 1 pt, page breaks at the same place, page breaks. -/
def totals (outs : Array Outcome) : Nat × Nat × Nat × Nat × Nat × Nat × Nat :=
  ((outs.filter (·.diffs.isEmpty)).size, outs.size, outs.foldl (init := 0) (· + ·.sameLines),
    outs.foldl (init := 0) (· + ·.lines), outs.foldl (init := 0) (· + ·.nearLines),
    outs.foldl (init := 0) (· + ·.sameBreaks), outs.foldl (init := 0) (· + ·.breaks))

/-- A table row of totals: documents, lines to the sp, lines within 1 pt, page breaks. -/
def totalsRow (label : String) (outs : Array Outcome) : String :=
  let (a, n, same, lines, near, sb, b) := totals outs
  s!"| {label} | {a} / {n} | {same} / {lines} | {near} | {sb} / {b} |\n"

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
  let lines := outs.foldl (init := 0) (· + ·.lines)
  let same := outs.foldl (init := 0) (· + ·.sameLines)
  let near := outs.foldl (init := 0) (· + ·.nearLines)
  IO.println s!"  documents: {agree.size} of {outs.size} agree with LuaLaTeX; lines at the same \
    place {same} of {lines}, within 1 pt {near}"
  IO.println s!"  formulas the TeX-rule layout refused (set by the KaTeX-compatible layout): \
    {fallbackSummary outs}"
  if show?.isNone then IO.println s!"  {← MathBoxChecks.run update}"
  -- the held-out set is skipped with LEANTEX_SKIP_HELDOUT (while the layer is being worked on)
  let skipHeld := (← IO.getEnv "LEANTEX_SKIP_HELDOUT").isSome
  let held ← if show?.isNone && !skipHeld then heldOut resolve else pure #[]
  if !held.isEmpty then
    let (a, n, hs, hl, hn, hb, hbt) := totals held
    IO.println s!"  held-out documents (reported, not required): {a} of {n} agree; lines at the \
      same place {hs} of {hl}, within 1 pt {hn}; page breaks {hb} of {hbt}; formulas the \
      TeX-rule layout refused: {fallbackSummary held}"
  let held2 ← if show?.isNone && !skipHeld then heldOut resolve "doc-heldout-2" else pure #[]
  if !held2.isEmpty then
    let (a, n, hs, hl, hn, hb, hbt) := totals held2
    IO.println s!"  second held-out set (reported, not required): {a} of {n} agree; lines at \
      the same place {hs} of {hl}, within 1 pt {hn}; page breaks {hb} of {hbt}; formulas the \
      TeX-rule layout refused: {fallbackSummary held2}"
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
      counter steps are LuaLaTeX's. A page break is at LuaLaTeX's place when the page after it \
      begins with LuaLaTeX's line. The reference documents were written to cover the \
      features and the layer was tuned on them; the fresh and the held-out documents were \
      written by someone who had not read this library. The first held-out set agreed in 8 \
      of 20 documents when it was first run blind with the TeX-rule layout; one defect it \
      showed was fixed after that and four of its fixtures were re-recorded after a fix to the \
      recorder, so its figure below is no longer a blind one. The second held-out set was \
      written blind after that, run once and never tuned to: it is the honest measure.\n\n\
      | Set | Documents agreeing | Lines at the same place | Within 1 pt | Page breaks |\n\
      |---|---|---|---|---|\n"
    let fresh := outs.filter (·.name.startsWith "fresh-")
    md := md ++ totalsRow "reference documents (tuned on)" (outs.filter
      (!·.name.startsWith "fresh-")) ++ totalsRow "fresh documents (written blind)" fresh ++
      totalsRow "first held-out set (written blind; 8 / 20 when first run)" held ++
      (if held2.isEmpty then "" else
        totalsRow "**second held-out set (written blind, run once, not tuned to)**" held2)
    let refusedAll := fallbackSummary (outs ++ held ++ held2)
    md := md ++ s!"\nFormulas the TeX-rule layout refused although the metric files were \
      there, set by the KaTeX-compatible layout instead: {refusedAll}.\n"
    md := md ++ "\n| Feature | Documents agreeing | Lines at the same place | Within 1 pt | \
      Page breaks |\n|---|---|---|---|---|\n"
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
  -- the report holds no control characters (they are escaped where it is written)
  if reportCell "a\u0000b\u0015|c" != "a\\u{0}b\\u{15}\\|c" then
    fails := fails.push "report: a control character is not escaped in a table cell"
  if ← System.FilePath.pathExists "parity/DOC.md" then
    if hasControl (← IO.FS.readFile "parity/DOC.md") then
      fails := fails.push "parity/DOC.md has a control character"
  return fails

end DocChecks
