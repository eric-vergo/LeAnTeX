/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/

/-!
# JSON values

A small JSON value type with a printer and a parser, for the parse tree's JSON form and the
recorded KaTeX fixtures (the library may not import `Lean`, whose `Lean.Json` this replaces).

## Main definitions

* `Json`: a JSON value; objects keep their key order.
* `Json.compress`: the compact text, keys in the order given.
* `Json.parse`: a value from text.
* `Json.sameAs`: equality with object keys compared as sets.
-/

namespace LeAnTeX

/-- A JSON value. -/
inductive Json where
  /-- `null`. -/
  | null
  /-- `true` or `false`. -/
  | bool (b : Bool)
  /-- A number. -/
  | num (x : Float)
  /-- A string. -/
  | str (s : String)
  /-- An array. -/
  | arr (xs : Array Json)
  /-- An object: key-value pairs in order. -/
  | obj (kvs : Array (String × Json))
  deriving Inhabited

namespace Json

/-- A string literal with JSON escapes. -/
def quote (s : String) : String := Id.run do
  let mut out := "\""
  for c in s.toList do
    if c == '"' then out := out ++ "\\\""
    else if c == '\\' then out := out ++ "\\\\"
    else if c == '\n' then out := out ++ "\\n"
    else if c == '\r' then out := out ++ "\\r"
    else if c == '\t' then out := out ++ "\\t"
    else if c.val < 0x20 then
      let h := (Nat.toDigits 16 c.val.toNat)
      out := out ++ "\\u" ++ String.ofList (List.replicate (4 - h.length) '0' ++ h)
    else out := out.push c
  return out.push '"'

/-- A number as text: integers without a fraction, others in Lean's notation. -/
def numText (x : Float) : String :=
  if x.isNaN then "null"
  else if x == x.floor && x.abs < 1e15 then
    if x < 0 then "-" ++ toString (-x).toUInt64.toNat else toString x.toUInt64.toNat
  else toString x

/-- The compact JSON text. -/
partial def compress : Json → String
  | null => "null"
  | bool b => if b then "true" else "false"
  | num x => numText x
  | str s => quote s
  | arr xs => "[" ++ ",".intercalate (xs.toList.map compress) ++ "]"
  | obj kvs => "{" ++ ",".intercalate (kvs.toList.map fun (k, v) => quote k ++ ":" ++
      compress v) ++ "}"

/-- Equality of values, with object keys compared regardless of order and numbers within a
relative tolerance of `1e-12`. -/
partial def sameAs : Json → Json → Bool
  | null, null => true
  | bool a, bool b => a == b
  | num a, num b => a == b || (a - b).abs ≤ 1e-12 * max a.abs b.abs
  | str a, str b => a == b
  | arr a, arr b => a.size == b.size && (a.zip b).all fun (x, y) => sameAs x y
  | obj a, obj b =>
    a.size == b.size && a.all fun (k, v) =>
      match b.find? (·.1 == k) with
      | some (_, w) => sameAs v w
      | none => false
  | _, _ => false

/-- The value of a key in an object. -/
def get? (j : Json) (key : String) : Option Json :=
  match j with
  | obj kvs => (kvs.find? (·.1 == key)).map (·.2)
  | _ => none

/-- The string, if the value is one. -/
def getStr? : Json → Option String
  | str s => some s
  | _ => none

/-- The number, if the value is one. -/
def getNum? : Json → Option Float
  | num x => some x
  | _ => none

/-- The boolean, if the value is one. -/
def getBool? : Json → Option Bool
  | bool b => some b
  | _ => none

/-- The elements, if the value is an array. -/
def getArr? : Json → Option (Array Json)
  | arr xs => some xs
  | _ => none

/-- The pairs, if the value is an object. -/
def getObj? : Json → Option (Array (String × Json))
  | obj kvs => some kvs
  | _ => none

/-- A JSON parser over the characters of a text. -/
private structure P where
  cs : Array Char
  i : Nat

/-- Skip whitespace. -/
private partial def ws (p : P) : P :=
  if p.i < p.cs.size && (p.cs[p.i]! == ' ' || p.cs[p.i]! == '\n' || p.cs[p.i]! == '\r' ||
    p.cs[p.i]! == '\t') then ws { p with i := p.i + 1 } else p

/-- Four hex digits as a number. -/
private def hex4 (cs : Array Char) (i : Nat) : Option Nat := do
  let mut v := 0
  for k in [0:4] do
    let c ← cs[i + k]?
    let d ← if c.isDigit then some (c.toNat - '0'.toNat)
      else if c ≥ 'a' && c ≤ 'f' then some (c.toNat - 'a'.toNat + 10)
      else if c ≥ 'A' && c ≤ 'F' then some (c.toNat - 'A'.toNat + 10) else none
    v := v * 16 + d
  return v

/-- A string literal starting at the opening quote. -/
private partial def pstr (p : P) : Except String (String × P) := do
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
private def pnum (p : P) : Except String (Float × P) := do
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
  let e : Int := (match ex.toInt? with | some v => v | none => 0) - fp.length
  let v := if e ≥ 0 then Float.ofNat (m * 10 ^ e.toNat) else Float.ofScientific m true e.natAbs
  return (if neg then -v else v, { p with i })

/-- A value. -/
private partial def pval (p : P) : Except String (Json × P) := do
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
  | 't' => return (bool true, { p with i := p.i + 4 })
  | 'f' => return (bool false, { p with i := p.i + 5 })
  | 'n' => return (null, { p with i := p.i + 4 })
  | _ =>
    let (x, q) ← pnum p
    return (num x, q)

/-- Parse a JSON text. -/
def parse (s : String) : Except String Json := do
  let (v, _) ← pval ⟨s.toList.toArray, 0⟩
  return v

end Json

end LeAnTeX
