/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.OpenType
import LeAnTeX.OpenType.Display
import LeAnTeX.Json
import LeAnTeXTest.Cases
import LeAnTeXTest.JsonParse

/-!
# Tests of the font reader

* Against fontTools (`fixtures/font/*.jsonl`, written by `tools/font-reference.py`): for each
  recorded font that is found, the header metrics, names, `OS/2` and `post` fields, `MATH`
  constants, the whole character map, and every glyph's advance, left side bearing,
  control-point box, tight box and outline (by hash). The two test fonts of
  `tools/test-fonts.py` are committed; the Latin Modern fonts are looked for in TeX Live
  (`LEANTEX_FONT_DIRS`, a colon-separated list, or `/usr/local/texlive/*/texmf-dist/fonts/
  opentype/public/{lm,lm-math}`) and skipped, with a note, when absent or different.
* Against TeX (`fixtures/text/boxes.jsonl`): every recorded box's glyphs, their widths and the
  kerns between them, as LuaTeX set them, follow from the reader's character map, `liga`
  ligatures, advances and `GPOS` kerning, scaled to the box's size.
* Fuzzing (`fuzz`): mutated copies of the fonts (bytes changed, fields set to extreme values,
  files cut short) must each be read to a font or to a `FontError`, and every query on a font
  read must return.
-/

namespace FontTest

open LeAnTeX LeAnTeX.OpenType

/-- FNV-1a, 64 bit, of bytes. -/
def fnv1a (b : ByteArray) : UInt64 := Id.run do
  let mut h : UInt64 := 0xcbf29ce484222325
  for x in b do
    h := (h ^^^ x.toUInt64) * 0x100000001b3
  return h

/-- A 64-bit value as 16 lower-case hexadecimal digits. -/
def hex16 (v : UInt64) : String :=
  let d := Nat.toDigits 16 v.toNat
  String.ofList (List.replicate (16 - d.length) '0' ++ d)

/-- An outline as the canonical text `tools/font-reference.py` hashes. -/
def outlineText (p : Path Int) : String :=
  let pt (q : Point Int) : String := s!"{q.x} {q.y}"
  " ".intercalate (p.cmds.toList.map fun
    | .move q => "M" ++ pt q
    | .line q => "L" ++ pt q
    | .quad c q => "Q" ++ pt c ++ " " ++ pt q
    | .cubic a b q => "C" ++ pt a ++ " " ++ pt b ++ " " ++ pt q
    | .close => "Z")

/-- The integer value of a JSON number, `none` for anything else (or `null`). -/
def jint? (j : Json) : Option Int := do
  let x ← j.getNum?
  if x == x.floor then
    some (if x < 0 then -((-x).toUInt64.toNat : Int) else (x.toUInt64.toNat : Int))
  else none

/-- Element `i` of a JSON array. -/
def jat (j : Json) (i : Nat) : Json := ((j.getArr?.getD #[])[i]?).getD .null

/-- The directories searched for the Latin Modern fonts. -/
def fontDirs : IO (Array System.FilePath) := do
  if let some v ← IO.getEnv "LEANTEX_FONT_DIRS" then
    return (v.splitOn ":").toArray.filter (!·.isEmpty) |>.map (⟨·⟩)
  let root : System.FilePath := "/usr/local/texlive"
  if !(← root.isDir) then return #[]
  let mut out := #[]
  for e in ← root.readDir do
    for sub in ["lm", "lm-math"] do
      out := out.push (e.path / "texmf-dist" / "fonts" / "opentype" / "public" / sub)
  return out

/-- The file of a font: the committed test fonts in `fixtures/font/`, others from `fontDirs`. -/
def findFont (name : String) : IO (Option System.FilePath) := do
  let local_ : System.FilePath := "fixtures/font" / name
  if ← local_.pathExists then return some local_
  for d in ← fontDirs do
    if ← (d / name).pathExists then return some (d / name)
  return none

/-- The outcome of checking one font: its name, `none` if skipped (with the reason) or the
failures. -/
structure FontOutcome where
  /-- The font file's name. -/
  name : String
  /-- Why it was skipped, if it was. -/
  skipped : Option String := none
  /-- The checks that failed. -/
  failures : Array String := #[]
  /-- How many glyphs were compared. -/
  glyphs : Nat := 0

/-- Compares a font with its fontTools reference (`fixtures/font/<stem>.jsonl`). -/
def checkFont (ref : System.FilePath) : IO FontOutcome := do
  let lines ← IO.FS.lines ref
  let some metaLine := lines[0]? | return { name := ref.toString, failures := #["empty"] }
  let .ok mj := Json.parse metaLine | return { name := ref.toString, failures := #["meta"] }
  let m := (mj.get? "meta").getD .null
  let name := ((m.get? "font").bind Json.getStr?).getD "?"
  let some path ← findFont name | return { name, skipped := some "not found" }
  let data ← IO.FS.readBinFile path
  if hex16 (fnv1a data) != ((m.get? "fnv1a").bind Json.getStr?).getD "" then
    return { name, skipped := some s!"{path} is not the recorded file" }
  let f ← match Font.read data with
    | .ok f => pure f
    | .error e => return { name, failures := #[s!"read: {e}"] }
  let mut fails : Array String := #[]
  let mut glyphs := 0
  let check := fun (fails : Array String) (ok : Bool) (what : String) =>
    if ok then fails else fails.push what
  for l in lines.toList.drop 1 do
    let .ok j := Json.parse l | fails := fails.push "bad fixture line"; continue
    if let some info := j.get? "info" then
      let n := fun (k : String) => (info.get? k).bind jint?
      let arr := fun (k : String) (i : Nat) => jint? (jat ((info.get? k).getD .null) i)
      fails := check fails (n "unitsPerEm" == some (f.head.unitsPerEm : Int)) "unitsPerEm"
      fails := check fails (n "numGlyphs" == some (f.numGlyphs : Int)) "numGlyphs"
      fails := check fails ([0, 1, 2, 3, 4].map (arr "head") ==
        ([f.head.xMin, f.head.yMin, f.head.xMax, f.head.yMax, f.head.macStyle] : List Int).map some)
        "head"
      fails := check fails ([0, 1, 2, 3].map (arr "hhea") == ([f.hhea.ascender,
        f.hhea.descender, f.hhea.lineGap, f.hhea.numberOfHMetrics] : List Int).map some) "hhea"
      if let some o := f.os2 then
        fails := check fails ((List.range 12).map (arr "os2") == ([some (o.version : Int),
          some o.xAvgCharWidth, some o.weightClass, some o.widthClass, some o.fsType,
          some o.typoAscender, some o.typoDescender, some o.typoLineGap, some o.winAscent,
          some o.winDescent, o.xHeight, o.capHeight] : List (Option Int))) "OS/2"
      else fails := fails.push "OS/2 missing"
      if let some p := f.post then
        fails := check fails ([0, 1, 2].map (arr "post") ==
          ([p.italicAngle, p.underlinePosition, p.underlineThickness] : List Int).map some &&
          (jat ((info.get? "post").getD .null) 3).getBool? == some p.isFixedPitch) "post"
      for (k, v) in ((info.get? "names").bind Json.getObj?).getD #[] do
        fails := check fails (f.names.get? k.toNat! == v.getStr?) s!"name {k}"
      if let some ms := (info.get? "math").bind Json.getArr? then
        fails := check fails (ms.map jint? == (f.math.getD #[]).map some) "MATH constants"
    else if let some cm := (j.get? "cmap").bind Json.getArr? then
      for e in cm do
        let c := ((jint? (jat e 0)).getD 0).toNat
        let g := ((jint? (jat e 1)).getD 0).toNat
        if f.cmap.glyph c != g then
          fails := fails.push s!"cmap U+{String.ofList (Nat.toDigits 16 c)}"
    else if let some g := j.get? "g" then
      glyphs := glyphs + 1
      let gid := ((jint? (jat g 0)).getD 0).toNat
      let box := fun (b : Json) => (b.getArr?).map fun a => a.map jint?
      let mine := fun (b : Option (Bounds Int)) => b.map fun b =>
        #[some b.xMin, some b.yMin, some b.xMax, some b.yMax]
      fails := check fails (jint? (jat g 1) == some (f.advance gid : Int)) s!"advance {gid}"
      fails := check fails (jint? (jat g 2) == (f.hmtx.lsbs[gid]?)) s!"lsb {gid}"
      match f.outline gid with
      | .error e => fails := fails.push s!"outline {gid}: {e}"
      | .ok p =>
        fails := check fails (box (jat g 3) == mine p.controlBounds) s!"control box {gid}"
        -- The tight box: fontTools' extrema rounded to 1/65536, ours rounded outwards.
        let tight := (box (jat g 4)).map (·.map (·.getD 0))
        let ok := match tight, p.bounds with
          | some #[a, b, c, d], some m =>
            (m.xMin - a).natAbs ≤ 2 && (m.yMin - b).natAbs ≤ 2 &&
              (m.xMax - c).natAbs ≤ 2 && (m.yMax - d).natAbs ≤ 2
          | none, none => true
          | _, _ => false
        fails := check fails ok s!"box {gid}"
        fails := check fails ((jat g 5).getStr? == some (hex16 (fnv1a (outlineText p).toUTF8)))
          s!"outline {gid}"
        if let .cff c := f.outlines then
          match c.charstring gid with
          | .ok cs =>
            -- A width may be fractional (16.16) where `hmtx` has whole units.
            fails := check fails (Em.roundDiv cs.width 65536 == (f.advance gid : Int))
              s!"charstring width {gid}"
          | .error e => fails := fails.push s!"charstring {gid}: {e}"
  return { name, failures := fails, glyphs }

/-- The fonts `fixtures/font/*.jsonl` record, checked. -/
def checkFonts : IO (Array FontOutcome) := do
  let mut refs := #[]
  for e in ← System.FilePath.readDir "fixtures/font" do
    if e.path.extension == some "jsonl" then refs := refs.push e.path
  let sorted := refs.qsort (·.toString < ·.toString)
  sorted.mapM checkFont

/-- The fonts read for a box's font files, by file name. -/
abbrev FontCache := Array (String × OpenType.Font)

/-- TeX's items as `(kind, glyph, width)`: glyphs, kerns (as `("k", 0, width)`) and glue; a
discretionary by its unbroken text, one level deep (as LuaTeX makes them). -/
def flattenItems (items : List Json) : List (String × Int × Int) :=
  let one := fun (it : Json) => match (jat it 0).getStr? with
    | some "g" => [("g", (jint? (jat it 2)).getD 0, (jint? (jat it 3)).getD 0)]
    | some "k" => [("k", 0, (jint? (jat it 1)).getD 0)]
    | some "glue" => [("glue", 0, 0)]
    | _ => []
  items.flatMap fun it =>
    if (jat it 0).getStr? == some "d" then ((jat it 4).getArr?.getD #[]).toList.flatMap one
    else one it

/-- A list cut at its glue items (which are dropped). -/
def splitAtGlue (xs : List (String × Int × Int)) : List (List (String × Int × Int)) :=
  let (cur, acc) := xs.foldl (init := ([], [])) fun (cur, acc) x =>
    if x.1 == "glue" then ([], cur.reverse :: acc) else (x :: cur, acc)
  (cur.reverse :: acc).reverse

/-- Characters that LuaTeX's TeX ligatures (`tlig`, not a feature of the font) replace. -/
def texLigatureChars : List Char := ['`', '\'', '"', '-']

/-- Compares the boxes LuaTeX set (`fixtures/text/boxes.jsonl`, their texts from
`corpus/text/boxes.jsonl`) with the reader's glyphs, ligatures, advances and kerns. Returns
the number compared, the number skipped (a font not found, a character outside the font, or a
TeX ligature character) and the failures. -/
def checkBoxes : IO (Nat × Nat × Array String) := do
  let corpus ← readJsonLines "corpus/text/boxes.jsonl"
  let fixture ← readJsonLines "fixtures/text/boxes.jsonl"
  let texts : Std.HashMap String String := Std.HashMap.ofList (corpus.toList.filterMap fun c =>
    return (← (c.get? "id").bind Json.getStr?, ← (c.get? "text").bind Json.getStr?))
  let mut cache : FontCache := #[]
  let mut compared := 0
  let mut skipped := 0
  let mut fails := #[]
  for b in fixture do
    let id := ((b.get? "id").bind Json.getStr?).getD "?"
    let some text := texts[id]? | fails := fails.push s!"{id}: no corpus text"; continue
    let fontJ := jat ((b.get? "fonts").getD .null) 0
    let file := ((fontJ.get? "file").bind Json.getStr?).getD ""
    let size := ((fontJ.get? "size").bind jint?).getD 0
    if text.any (texLigatureChars.contains ·) then skipped := skipped + 1; continue
    let f? ← match cache.find? (·.1 == file) with
      | some (_, f) => pure (some f)
      | none => do
        let some p ← findFont file | pure none
        match Font.read (← IO.FS.readBinFile p) with
        | .ok f => cache := cache.push (file, f); pure (some f)
        | .error _ => pure none
    let some f := f? | skipped := skipped + 1; continue
    if text.any (fun c => c != ' ' && f.glyph c == 0) then skipped := skipped + 1; continue
    compared := compared + 1
    -- TeX's material word by word: glyphs (a discretionary by its unbroken text) and kerns.
    let tex := flattenItems ((b.get? "items").bind Json.getArr? |>.getD #[]).toList
    let texWords := (splitAtGlue tex).filter (!·.isEmpty)
    let scale := fun (v : Int) => Em.roundDiv (v * size) f.unitsPerEm
    let mine := ((text.splitOn " ").filter (!·.isEmpty)).map fun w =>
      let gs := f.ligate (w.toList.toArray.map f.glyph)
      (List.range gs.size).flatMap fun i =>
        let g : Nat := gs[i]?.getD 0
        let k := match gs[i + 1]? with | some r => f.kerning g r | none => 0
        [("g", (g : Int), scale (f.advance g))] ++ (if k != 0 then [("k", 0, scale k)] else [])
    let close := fun (a b : List (String × Int × Int)) =>
      a.length == b.length && (a.zip b).all fun (x, y) =>
        x.1 == y.1 && x.2.1 == y.2.1 && (x.2.2 - y.2.2).natAbs ≤ 1
    if !(texWords.length == mine.length && (texWords.zip mine).all fun (x, y) => close x y) then
      fails := fails.push s!"{id}: TeX {texWords.take 2} ours {mine.take 2}"
  return (compared, skipped, fails)

/-- A deterministic pseudo-random sequence (a 64-bit linear congruential generator). -/
structure Rng where
  /-- The state. -/
  state : UInt64

/-- The next value below `n` (`n > 0`) and the next generator. -/
def Rng.below (r : Rng) (n : Nat) : Nat × Rng :=
  let s := r.state * 6364136223846793005 + 1442695040888963407
  ((s >>> 33).toNat % (max n 1), ⟨s⟩)

/-- A mutant of `data`: kind 0 changes 1 to 8 bytes, kind 1 writes an extreme 16- or 32-bit
value at a random offset in the first 1024 bytes (where the directory and table headers are),
kind 2 cuts the file short. -/
def mutate (data : ByteArray) (r : Rng) : ByteArray × Rng := Id.run do
  let (kind, r) := r.below 3
  let mut r := r
  let mut d := data
  if kind == 0 then
    let (n, r1) := r.below 8
    r := r1
    for _ in [0:n + 1] do
      let (i, r2) := r.below d.size
      let (v, r3) := r2.below 256
      r := r3
      d := d.set! i v.toUInt8
  else if kind == 1 then
    let (i, r1) := r.below (min d.size 1024)
    let (w, r2) := r1.below 4
    r := r2
    let vals : Array UInt8 := match w with
      | 0 => #[0xFF, 0xFF] | 1 => #[0, 0] | 2 => #[0xFF, 0xFF, 0xFF, 0xFF] | _ => #[0x7F, 0xFF]
    for k in [0:vals.size] do
      if i + k < d.size then d := d.set! (i + k) (vals[k]?.getD 0)
  else
    let (n, r1) := r.below d.size
    r := r1
    d := d.extract 0 n
  return (d, r)

/-- Exercises every query on a font read from a mutant: outlines and boxes of up to
`maxGlyphs` glyphs, kerning and ligatures of a few runs, text layout and the `MATH` constants;
the result feeds a checksum so that nothing is skipped. -/
def exercise (f : OpenType.Font) (maxGlyphs : Nat := 1000) : Int := Id.run do
  let mut acc : Int := 0
  for g in [0:min f.numGlyphs maxGlyphs] do
    match f.outline g with
    | .ok p => acc := acc + p.size + ((p.bounds.map (·.xMax)).getD 0)
    | .error _ => acc := acc + 1
    acc := acc + f.advance g + f.kerning g (g + 1)
  acc := acc + (f.ligate #[1, 2, 3, 4, 5, 6, 55, 66, 72, 123]).size
  acc := acc + ((f.layoutText "Office AVATAR fluffy waffle").foldl (fun a p => a + p.2) 0)
  acc := acc + (f.mathConstant? "axisHeight").getD 0
  return acc

/-- Reads `count` mutants of each seed font: the number read to a font, the number rejected
with a `FontError`, and a checksum of the queries on the fonts read. A query or read that
crashed or hung would not return here. -/
def fuzz (seeds : Array ByteArray) (count : Nat) (seed : UInt64 := 0x5eed) :
    Nat × Nat × Int := Id.run do
  let mut r : Rng := ⟨seed⟩
  let mut ok := 0
  let mut err := 0
  let mut sum : Int := 0
  for data in seeds do
    for _ in [0:count] do
      let (d, r1) := mutate data r
      r := r1
      match Font.read d with
      | .ok f => ok := ok + 1; sum := sum + exercise f 300
      | .error _ => err := err + 1
  return (ok, err, sum)

/-- The operations that can panic: `!`-indexing, `get!`, `head!`, `back!`, `set!`, `toNat!`,
`panic!` and `unreachable!`. -/
def panicPatterns : List String :=
  ["]!", "get!", "head!", "back!", "set!", "panic!", "toNat!", "unreachable!"]

/-- The uses of panicking operations that are accepted, as a file and the text of the line, each
with the reason. Empty: no library source may use a panicking operation. -/
def panicAllowList : List (System.FilePath × String) := []

/-- The `.lean` files under a directory, recursively. -/
partial def leanFilesUnder (dir : System.FilePath) : IO (Array System.FilePath) := do
  let mut files := #[]
  for e in ← dir.readDir do
    if ← e.path.isDir then files := files ++ (← leanFilesUnder e.path)
    else if e.path.extension == some "lean" then files := files.push e.path
  return files

/-- The source files of the library, checked for operations that can panic (see
`panicPatterns`) outside `panicAllowList`: an input must never make the library panic. -/
def panicFree : IO (Array String) := do
  let mut bad := #[]
  let files := (← leanFilesUnder "LeAnTeX").push "LeAnTeX.lean"
  for p in files do
    if !(← p.pathExists) then continue
    let lines ← IO.FS.lines p
    for h : i in [0:lines.size] do
      let l := lines[i]'h.upper
      let code := (l.splitOn "--").headD ""
      if panicPatterns.any (code.contains ·) &&
          !panicAllowList.any (fun (q, t) => q == p && t == l.trimAscii.toString) then
        bad := bad.push s!"{p}:{i + 1}"
  return bad

/-- Checks of the committed test fonts' layout tables and of path output, by name. -/
def unitChecks : IO (Array (String × Bool)) := do
  let cff ← Font.read <$> IO.FS.readBinFile "fixtures/font/leantex-test-cff.otf"
  let ttf ← Font.read <$> IO.FS.readBinFile "fixtures/font/leantex-test-glyf.ttf"
  let some cff := cff.toOption | return #[("test CFF font read", false)]
  let some ttf := ttf.toOption | return #[("test glyf font read", false)]
  let g := fun (f : OpenType.Font) (c : Char) => f.glyph c
  let sq : Path Int := ⟨#[.move ⟨0, 0⟩, .line ⟨2, 0⟩, .quad ⟨3, 1⟩ ⟨2, 2⟩,
    .cubic ⟨1, 3⟩ ⟨0, 3⟩ ⟨0, 2⟩, .close]⟩
  let arch : Path Int := ⟨#[.move ⟨0, 0⟩, .quad ⟨2, 4⟩ ⟨4, 0⟩, .close]⟩
  return #[
    ("liga: f i becomes the ligature", cff.ligate #[g cff 'f', g cff 'i'] == #[g cff 'ﬁ']),
    ("liga: other glyphs unchanged",
      cff.ligate #[g cff 'A', g cff 'f'] == #[g cff 'A', g cff 'f']),
    ("GPOS pair A A", cff.kerning (g cff 'A') (g cff 'A') == -50),
    ("GPOS pair A f", cff.kerning (g cff 'A') (g cff 'f') == -30),
    ("GPOS class pair A i", cff.kerning (g cff 'A') (g cff 'i') == -10),
    ("GPOS class pair f Á", cff.kerning (g cff 'f') (g cff 'Á') == -10),
    ("GPOS no pair i A", cff.kerning (g cff 'i') (g cff 'A') == 0),
    ("kern table A A", ttf.kerning (g ttf 'A') (g ttf 'A') == -40),
    ("kern table f i", ttf.kerning (g ttf 'f') (g ttf 'i') == 15),
    ("unmapped character is .notdef", cff.glyph 'Z' == 0),
    ("layoutText ligates and kerns",
      cff.layoutText "AAfi" == #[(g cff 'A', 600 - 50), (g cff 'A', 600), (g cff 'ﬁ', 550)]),
    ("svgData", sq.svgData toString == "M0 0 L2 0 Q3 1 2 2 C1 3 0 3 0 2 Z"),
    ("bounds take a curve's extremum, not its control point",
      arch.bounds == some ⟨0, 0, 4, 2⟩ && arch.controlBounds == some ⟨0, 0, 4, 4⟩),
    ("controlBounds", sq.controlBounds == some ⟨0, 0, 3, 3⟩),
    ("a font collection is refused",
      (Font.read (ByteArray.mk #[0x74, 0x74, 0x63, 0x66, 0, 1, 0, 0])).toOption.isNone),
    ("an empty file is refused", (Font.read ByteArray.empty).toOption.isNone),
    ("fixedText", [0, 65536, -98304, 1, 65536 * 7 + 16384].map fixedText ==
      ["0", "1", "-1.5", "0.0000152587890625", "7.25"]),
    ("glyph path data, y down",
      (cff.glyphPathData (g cff 'A')).toOption.join.map (·.1) ==
        some "M0 0 L300 0 L300 -700 L600 -700 L600 0 L0 0 Z"),
    ("glyph item in its box",
      match cff.glyphItem (g cff 'A') 1 0 1 with
      | .ok (some (.path _ vb _ x y w h ..)) =>
        vb == "0 -700 600 700" && x == 1 && y == -(0.7 : Em) && w == (0.6 : Em) &&
          h == (0.7 : Em)
      | _ => false)]

/-- Runs the font tests; prints a summary and returns the failures. -/
def run (fuzzCount : Nat := 400) : IO (Array String) := do
  let mut fails := #[]
  let units ← unitChecks
  for (n, ok) in units do if !ok then fails := fails.push s!"unit check: {n}"
  IO.println s!"  font unit checks: {(units.filter (·.2)).size} of {units.size} hold"
  for o in ← checkFonts do
    match o.skipped with
    | some why => IO.println s!"  font {o.name}: skipped ({why})"
    | none =>
      if o.failures.isEmpty then IO.println s!"  font {o.name}: {o.glyphs} glyphs as fontTools"
      else
        IO.println s!"  font {o.name}: {o.failures.size} differences from fontTools"
        fails := fails ++ (o.failures.extract 0 20).map (s!"font {o.name}: " ++ ·)
  let (n, skipped, bfails) ← checkBoxes
  IO.println s!"  boxes: {n - bfails.size} of {n} TeX boxes reproduced ({skipped} skipped)"
  fails := fails ++ (bfails.extract 0 20).map ("box " ++ ·)
  let mut seeds := #[]
  for name in ["leantex-test-cff.otf", "leantex-test-glyf.ttf", "lmroman10-regular.otf"] do
    if let some p ← findFont name then seeds := seeds.push (← IO.FS.readBinFile p)
  let (ok, err, sum) := fuzz seeds fuzzCount
  IO.println s!"  fuzz: {ok + err} mutants of {seeds.size} fonts, {ok} read, {err} rejected \
    with an error (checksum {sum})"
  for b in ← panicFree do fails := fails.push s!"possible panic in the reader at {b}"
  return fails

end FontTest
