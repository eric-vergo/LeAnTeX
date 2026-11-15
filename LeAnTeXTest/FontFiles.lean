/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.OpenType

/-!
# The bundled font files

`fonts/MANIFEST.tsv` lists every file of `fonts/newcomputermodern/` with its size, SHA-256 and
licence. The check reads every file, compares its size and hash with the manifest (so a font
that was modified, renamed or added is caught), refuses the files the manifest's licence rule
leaves out (`NewCM10-Regular`, `NewCMUncial*`, `NewCM*Devanagari*`, under another licence)
anywhere in the repository,
and reads every glyph of every font with the OpenType reader.

## Main definitions

* `FontFiles.sha256`: SHA-256 (FIPS 180-4), for the manifest check.
* `FontFiles.run`: the check.
-/

namespace FontFiles

/-- SHA-256's round constants (FIPS 180-4, 4.2.2). -/
def roundK : Array UInt32 := #[
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2]

/-- Rotation right. -/
def rotr (x : UInt32) (n : UInt32) : UInt32 := (x >>> n) ||| (x <<< (32 - n))

/-- One 64-byte block at `off` of `msg` processed into the state `h`. -/
def block (h : Array UInt32) (msg : ByteArray) (off : Nat) : Array UInt32 := Id.run do
  let byte := fun (i : Nat) => (msg.get! (off + i)).toUInt32
  let mut w : Array UInt32 := Array.mkEmpty 64
  for t in [0:16] do
    w := w.push ((byte (4 * t) <<< 24) ||| (byte (4 * t + 1) <<< 16) |||
      (byte (4 * t + 2) <<< 8) ||| byte (4 * t + 3))
  for t in [16:64] do
    let x := w[t - 15]!
    let y := w[t - 2]!
    let s0 := rotr x 7 ^^^ rotr x 18 ^^^ (x >>> 3)
    let s1 := rotr y 17 ^^^ rotr y 19 ^^^ (y >>> 10)
    w := w.push (w[t - 16]! + s0 + w[t - 7]! + s1)
  let mut a := h[0]!; let mut b := h[1]!; let mut c := h[2]!; let mut d := h[3]!
  let mut e := h[4]!; let mut f := h[5]!; let mut g := h[6]!; let mut k := h[7]!
  for t in [0:64] do
    let t1 := k + (rotr e 6 ^^^ rotr e 11 ^^^ rotr e 25) + ((e &&& f) ^^^ (~~~e &&& g)) +
      roundK[t]! + w[t]!
    let t2 := (rotr a 2 ^^^ rotr a 13 ^^^ rotr a 22) + ((a &&& b) ^^^ (a &&& c) ^^^ (b &&& c))
    k := g; g := f; f := e; e := d + t1; d := c; c := b; b := a; a := t1 + t2
  return #[h[0]! + a, h[1]! + b, h[2]! + c, h[3]! + d, h[4]! + e, h[5]! + f, h[6]! + g,
    h[7]! + k]

/-- The SHA-256 of the bytes, as 64 lower-case hexadecimal digits. -/
def sha256 (data : ByteArray) : String := Id.run do
  let n := data.size
  let mut msg := data.push 0x80
  while msg.size % 64 != 56 do msg := msg.push 0
  for i in [0:8] do msg := msg.push ((n * 8) >>> (8 * (7 - i))).toUInt8
  let mut h : Array UInt32 := #[0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f,
    0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
  for b in [0:msg.size / 64] do h := block h msg (64 * b)
  let hex := fun (v : UInt32) =>
    let s := String.ofList (Nat.toDigits 16 v.toNat)
    String.ofList (List.replicate (8 - s.length) '0') ++ s
  return String.join (h.toList.map hex)

/-- Whether a file name is one of those the licence rule leaves out. -/
def excluded (name : String) : Bool :=
  name == "NewCM10-Regular.otf" || name.startsWith "NewCMUncial" ||
    (name.startsWith "NewCM" && (name.splitOn "Devanagari").length > 1)

/-- The files below `root` whose name `excluded` refuses, skipping the build folder `.lake` and
the version control folder `.git` (at most 64 levels and 200000 entries are visited). -/
def excludedAnywhere (root : System.FilePath) : IO (Array String) := do
  let mut out := #[]
  let mut todo : Array (System.FilePath × Nat) := #[(root, 0)]
  let mut seen := 0
  for _ in [0:200000] do
    let some (d, depth) := todo.back? | break
    todo := todo.pop
    if depth > 64 then continue
    for e in ← d.readDir do
      seen := seen + 1
      if e.fileName == ".lake" || e.fileName == ".git" then continue
      let md ← e.path.symlinkMetadata
      if md.type == .dir then todo := todo.push (e.path, depth + 1)
      else if excluded e.fileName then out := out.push e.path.toString
    if seen > 200000 then break
  return out

/-- Runs the check; prints a summary, returns the failures. -/
def run : IO (Array String) := do
  let dir : System.FilePath := "fonts/newcomputermodern"
  let rows := (← IO.FS.lines "fonts/MANIFEST.tsv").toList.drop 1 |>.filter (· != "")
  let mut fails := #[]
  let mut listed : Array String := #[]
  let mut glyphs := 0
  if sha256 "abc".toUTF8 !=
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" then
    fails := fails.push "sha256: the FIPS 180-4 example"
  for row in rows do
    match row.splitOn "\t" with
    | [name, size, hash, _licence] =>
      listed := listed.push name
      if excluded name then fails := fails.push s!"{name}: excluded by its licence"
      let path := dir / name
      if !(← path.pathExists) then fails := fails.push s!"{name}: missing"; continue
      let data ← IO.FS.readBinFile path
      if toString data.size != size then fails := fails.push s!"{name}: size {data.size}"
      if sha256 data != hash then fails := fails.push s!"{name}: SHA-256 differs"
      if name.endsWith ".otf" then
        match LeAnTeX.OpenType.Font.read data with
        | .error e => fails := fails.push s!"{name}: {e.table}: {e.message}"
        | .ok f =>
          for g in [0:f.numGlyphs] do
            if (f.outline g).toOption.isNone then fails := fails.push s!"{name}: glyph {g}"
          glyphs := glyphs + f.numGlyphs
    | _ => fails := fails.push s!"manifest row: {row}"
  for e in ← dir.readDir do
    if !listed.contains e.fileName then fails := fails.push s!"{e.fileName}: not in the manifest"
  -- an excluded file is refused wherever it is in the repository, not only among the fonts
  for p in ← excludedAnywhere "." do
    fails := fails.push s!"{p}: excluded by its licence"
  IO.println s!"  font files: {listed.size} files as the manifest lists them, {glyphs} glyphs \
    read ({fails.size} failures)"
  return fails

end FontFiles
