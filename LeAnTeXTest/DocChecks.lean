/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX
import LeAnTeXTest.FrontChecks

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
and `parity/DOC.md`; `--show-doc NAME` prints a document's differences.

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

/-- Compares one document with its fixture. -/
def compare (name : String) (resolve : FontResolver) : IO Outcome := do
  let src ← IO.FS.readFile s!"corpus/doc/{name}.tex"
  let fx ← match Json.parse (← IO.FS.readFile s!"fixtures/doc/{name}.json") with
    | .ok j => pure j
    | .error e => return { name, diffs := #[s!"fixture: {e}"] }
  let theirs := ((fx.get? "pages").bind Json.getArr?).getD #[]
  let total := theirs.foldl (init := 0) fun n p =>
    n + (((p.get? "lines").bind Json.getArr?).getD #[]).size
  match typesetDocument src resolve with
  | .error e => return { name, diffs := #[s!"error: {e.message} at {e.pos}"], lines := total }
  | .ok r =>
    let mut o : Outcome := { name, lines := total }
    if r.pages.size != theirs.size then
      o := o.add s!"pages: {r.pages.size}, LuaLaTeX {theirs.size}"
    for h : i in [0:min r.pages.size theirs.size] do
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
    let ot := if (src.splitOn "\\tableofcontents").length > 1 then ot else #[]
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
        | some n, some v => if known.contains n then some (n, v) else none
        | _, _ => none
      | _ => none
    let os := r.steps.filter fun (n, _) => known.contains n
    if fs.toList != os.toList then
      o := o.add s!"counter steps: {os.size}, LuaLaTeX {fs.size}"
    return o

/-- The documents of the corpus that have a fixture. -/
def documents : IO (Array String) := do
  let mut out := #[]
  for e in ← System.FilePath.readDir "corpus/doc" do
    if e.fileName.endsWith ".tex" then
      let n := e.fileName.dropEnd 4 |>.toString
      if ← System.FilePath.pathExists s!"fixtures/doc/{n}.json" then out := out.push n
  return out.qsort (· < ·)

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
  | _ => "combined"

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
  let mut fails := #[]
  for b in baseline do
    match outs.find? (·.name == b) with
    | some o => if !o.diffs.isEmpty then
        fails := fails.push s!"document {b} no longer agrees: {o.diffs[0]?.getD ""}"
    | none => if show?.isNone then fails := fails.push s!"document {b}: no fixture"
  if update then
    IO.FS.writeFile "parity/doc-baseline.tsv"
      (String.join (agree.toList.map (·.name ++ "\n")))
    let mut md := "# Documents against LuaLaTeX\n\nWritten by `lake exe leantex-test \
      --update-doc` (`LeAnTeXTest/DocChecks.lean`). A document agrees when its pages, every \
      line's position (to the sp) and text, its labels, its table of contents and its \
      counter steps are LuaLaTeX's.\n\n| Feature | Documents agreeing | Lines at the same \
      place | Within 1 pt |\n|---|---|---|---|\n"
    let feats := (outs.map (feature ·.name)).toList.eraseDups
    for f in feats do
      let fo := outs.filter (feature ·.name == f)
      md := md ++ s!"| {f} | {(fo.filter (·.diffs.isEmpty)).size} / {fo.size} | \
        {fo.foldl (init := 0) (· + ·.sameLines)} / {fo.foldl (init := 0) (· + ·.lines)} | \
        {fo.foldl (init := 0) (· + ·.nearLines)} |\n"
    md := md ++ "\n## Per document\n\n| Document | Agrees | Lines same | First difference |\n\
      |---|---|---|---|\n"
    for o in outs do
      let first := (o.diffs[0]?.getD "").replace "|" "\\|"
      md := md ++ s!"| {o.name} | {if o.diffs.isEmpty then "yes" else "no"} | \
        {o.sameLines} / {o.lines} | {first} |\n"
    IO.FS.writeFile "parity/DOC.md" md
  return fails

end DocChecks
