/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Json

/-!
# Reading JSON text

The reader of the recorded fixtures (`fixtures/*.jsonl`) and other JSON files of this repository,
which the tests compare with. It is test support, not library: its input is the repository's own
files. It reads one value with nothing after it, refuses misspelt literals, and refuses numbers
whose exponent is beyond ±400 instead of computing a huge power of ten.

## Main definitions

* `LeAnTeX.Json.parse`
-/

namespace LeAnTeX

namespace Json

/-- A JSON parser over the characters of a text. -/
structure P where
  /-- The characters of the text. -/
  cs : Array Char
  /-- The position of the next character. -/
  i : Nat

/-- Skip whitespace. -/
partial def ws (p : P) : P :=
  if p.i < p.cs.size && (p.cs[p.i]! == ' ' || p.cs[p.i]! == '\n' || p.cs[p.i]! == '\r' ||
    p.cs[p.i]! == '\t') then ws { p with i := p.i + 1 } else p

/-- Four hex digits as a number. -/
def hex4 (cs : Array Char) (i : Nat) : Option Nat := do
  let mut v := 0
  for k in [0:4] do
    let c ← cs[i + k]?
    let d ← if c.isDigit then some (c.toNat - '0'.toNat)
      else if c ≥ 'a' && c ≤ 'f' then some (c.toNat - 'a'.toNat + 10)
      else if c ≥ 'A' && c ≤ 'F' then some (c.toNat - 'A'.toNat + 10) else none
    v := v * 16 + d
  return v

/-- A string literal starting at the opening quote. -/
partial def pstr (p : P) : Except String (String × P) := do
  let rec go (i : Nat) (acc : String) : Except String (String × Nat) := do
    let some c := p.cs[i]? | throw "unterminated string"
    if c == '"' then return (acc, i + 1)
    if c != '\\' then return ← go (i + 1) (acc.push c)
    let some e := p.cs[i + 1]? | throw "bad escape"
    match e with
    | 'n' => go (i + 2) (acc.push '\n')
    | 't' => go (i + 2) (acc.push '\t')
    | 'r' => go (i + 2) (acc.push '\r')
    | 'b' => go (i + 2) (acc.push '\x08')
    | 'f' => go (i + 2) (acc.push '\x0c')
    | 'u' =>
      let some v := hex4 p.cs (i + 2) | throw "bad \\u escape"
      if v ≥ 0xD800 && v < 0xDC00 then
        if p.cs[i + 6]? == some '\\' && p.cs[i + 7]? == some 'u' then
          if let some w := hex4 p.cs (i + 8) then
            if w ≥ 0xDC00 && w < 0xE000 then
              let cp := 0x10000 + (v - 0xD800) * 0x400 + (w - 0xDC00)
              return ← go (i + 12) (acc.push (Char.ofNat cp))
        go (i + 6) (acc.push '�')
      else if v ≥ 0xDC00 && v < 0xE000 then go (i + 6) (acc.push '�')
      else go (i + 6) (acc.push (Char.ofNat v))
    | c => go (i + 2) (acc.push c)
  let (s, j) ← go (p.i + 1) ""
  return (s, { p with i := j })

/-- A number literal. -/
def pnum (p : P) : Except String (Float × P) := do
  let mut i := p.i
  let start := i
  while i < p.cs.size && ("+-0123456789.eE".contains p.cs[i]!) do i := i + 1
  let text := String.ofList (p.cs.extract start i).toList
  let (neg, body) := if text.startsWith "-" then (true, (text.drop 1).toString) else (false, text)
  let (mant, ex) := match body.splitOn "e" ++ [] with
    | [m, e] => (m, e)
    | _ => match body.splitOn "E" with
      | [m, e] => (m, e)
      | _ => (body, "0")
  let ip := (mant.splitOn ".")[0]!
  let fp := (mant.splitOn ".")[1]?.getD ""
  let m := (ip ++ fp).foldl (fun acc c => acc * 10 + (c.toNat - '0'.toNat)) 0
  let some e0 := (if ex.startsWith "+" then (ex.drop 1).toString else ex).toInt?
    | throw s!"bad number {text}"
  if ip.isEmpty || !(ip ++ fp).all Char.isDigit then throw s!"bad number {text}"
  -- beyond these exponents every double is 0 or infinite: refuse rather than compute 10 ^ e
  if e0 > 400 || e0 < -400 then throw s!"number out of range {text}"
  let e : Int := e0 - fp.length
  let v := if e ≥ 0 then Float.ofNat (m * 10 ^ e.toNat) else Float.ofScientific m true e.natAbs
  return (if neg then -v else v, { p with i })

/-- A value. -/
partial def pval (p : P) : Except String (Json × P) := do
  let p := ws p
  let some c := p.cs[p.i]? | throw "unexpected end"
  match c with
  | '{' =>
    let mut q := ws { p with i := p.i + 1 }
    let mut kvs := #[]
    if q.cs[q.i]? == some '}' then return (obj kvs, { q with i := q.i + 1 })
    repeat
      q := ws q
      let (k, q1) ← pstr q
      let q2 := ws q1
      if q2.cs[q2.i]? != some ':' then throw "expected ':'"
      let (v, q3) ← pval { q2 with i := q2.i + 1 }
      kvs := kvs.push (k, v)
      let q4 := ws q3
      match q4.cs[q4.i]? with
      | some ',' => q := { q4 with i := q4.i + 1 }
      | some '}' => return (obj kvs, { q4 with i := q4.i + 1 })
      | _ => throw "expected ',' or '}'"
    throw "unreachable"
  | '[' =>
    let mut q := ws { p with i := p.i + 1 }
    let mut xs := #[]
    if q.cs[q.i]? == some ']' then return (arr xs, { q with i := q.i + 1 })
    repeat
      let (v, q1) ← pval q
      xs := xs.push v
      let q2 := ws q1
      match q2.cs[q2.i]? with
      | some ',' => q := { q2 with i := q2.i + 1 }
      | some ']' => return (arr xs, { q2 with i := q2.i + 1 })
      | _ => throw "expected ',' or ']'"
    throw "unreachable"
  | '"' =>
    let (s, q) ← pstr p
    return (str s, q)
  | 't' | 'f' | 'n' =>
    for (word, v) in [("true", bool true), ("false", bool false), ("null", null)] do
      if String.ofList (p.cs.extract p.i (p.i + word.length)).toList == word then
        return (v, { p with i := p.i + word.length })
    throw s!"unexpected character at {p.i}"
  | _ =>
    let (x, q) ← pnum p
    return (num x, q)

/-- Parse a JSON text: one value, nothing but whitespace after it; literals spelled exactly;
numbers with an exponent beyond ±400 refused. Fixtures only (the recorded files of this
repository). -/
def parse (s : String) : Except String Json := do
  let (v, q) ← pval ⟨s.toList.toArray, 0⟩
  if (ws q).i != q.cs.size then throw s!"unexpected text after the value at {(ws q).i}"
  return v

end Json

end LeAnTeX
