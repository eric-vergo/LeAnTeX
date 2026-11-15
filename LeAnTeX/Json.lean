/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/

/-!
# JSON values

A small JSON value type with a printer, for the parse tree's JSON form (the library may not
import `Lean`, whose `Lean.Json` this replaces). The reader of JSON text the tests use for the
recorded fixtures is in the test support (`LeAnTeXTest.JsonParse`), not in the library.

## Main definitions

* `Json`: a JSON value; objects keep their key order.
* `Json.compress`: the compact text, keys in the order given.
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

end Json

end LeAnTeX
