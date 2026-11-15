/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Doc.State

/-!
# Counters

LaTeX's counters as values: stepping (`\stepcounter`: the counter goes up by one and the
counters within it go to zero), setting and adding, and the number styles of `\arabic`,
`\roman`, `\Roman`, `\alph`, `\Alph` and `\fnsymbol`, as LaTeX's documentation gives them
(`\alph` and `\Alph` for 1 to 26, `\fnsymbol` for 1 to 9; other values are errors in LaTeX and
print as `?` here, after a warning from the caller).

## Main definitions

* `Counters`: the table of counters; `Counters.step`, `Counters.set`, `Counters.add`,
  `Counters.newCounter`.
* `romanLower`, `NumberStyle.format`.
-/

namespace LeAnTeX.Doc

namespace Counters

/-- The value of a counter (0 for one not defined). -/
def value (cs : Counters) (name : String) : Int := ((cs.table.get? name).map (·.value)).getD 0

/-- Defines a counter at 0, reset by `within` when that is given and defined. -/
def newCounter (cs : Counters) (name : String) (within : Option String := none) : Counters :=
  let cs : Counters := { table := cs.table.insert name {} }
  match within with
  | some w =>
    match cs.table.get? w with
    | some c => { table := cs.table.insert w { c with resets := c.resets.push name } }
    | none => cs
  | none => cs

/-- Sets a counter (LaTeX's `\setcounter`); the counters within it are not changed. -/
def set (cs : Counters) (name : String) (v : Int) : Counters :=
  match cs.table.get? name with
  | some c => { table := cs.table.insert name { c with value := v } }
  | none => cs

/-- Adds to a counter (LaTeX's `\addtocounter`). -/
def add (cs : Counters) (name : String) (v : Int) : Counters :=
  match cs.table.get? name with
  | some c => { table := cs.table.insert name { c with value := c.value + v } }
  | none => cs

/-- Resets the counters within `name` to zero, and those within them, `fuel` levels deep. -/
def resetWithin (cs : Counters) (name : String) : Nat → Counters
  | 0 => cs
  | fuel + 1 =>
    match cs.table.get? name with
    | some c => c.resets.foldl (init := cs) fun acc r =>
        (acc.set r 0).resetWithin r fuel
    | none => cs

/-- Steps a counter (LaTeX's `\stepcounter`): one more, and every counter within it (and
within those) zero. -/
def step (cs : Counters) (name : String) : Counters :=
  (cs.add name 1).resetWithin name 16

end Counters

/-- Lower-case Roman numerals (`\roman`): empty for 0 or less, as TeX's `\romannumeral`. -/
def romanLower (n : Int) : String := Id.run do
  if n ≤ 0 then return ""
  let table : List (Nat × String) :=
    [(1000, "m"), (900, "cm"), (500, "d"), (400, "cd"), (100, "c"), (90, "xc"), (50, "l"),
     (40, "xl"), (10, "x"), (9, "ix"), (5, "v"), (4, "iv"), (1, "i")]
  -- at most 2^31 thousands are written, TeX's own limit
  let mut k := min n.toNat 2147483647
  let mut out := ""
  for (v, s) in table do
    let q := k / v
    out := out ++ String.join (List.replicate (min q 2147483) s)
    k := k % v
  return out

/-- The number styles of LaTeX's counters. -/
inductive NumberStyle where
  /-- `\arabic`. -/
  | arabic
  /-- `\roman`. -/
  | roman
  /-- `\Roman`. -/
  | romanUpper
  /-- `\alph`. -/
  | alph
  /-- `\Alph`. -/
  | alphUpper
  /-- `\fnsymbol`. -/
  | fnsymbol
  deriving BEq, Repr, Inhabited

/-- The style a command names (`arabic` …), if it is one. -/
def NumberStyle.ofName? : String → Option NumberStyle
  | "arabic" => some .arabic | "roman" => some .roman | "Roman" => some .romanUpper
  | "alph" => some .alph | "Alph" => some .alphUpper | "fnsymbol" => some .fnsymbol
  | _ => none

/-- `\fnsymbol`'s symbols for 1 to 9, as LaTeX prints them in text. -/
def fnSymbols : Array String := #["*", "†", "‡", "§", "¶", "‖", "**", "††", "‡‡"]

/-- A value in a style; `none` when the style has no symbol for it (`\alph` beyond 1–26,
`\fnsymbol` beyond 1–9). -/
def NumberStyle.format? (st : NumberStyle) (n : Int) : Option String :=
  match st with
  | .arabic => some (toString n)
  | .roman => some (romanLower n)
  | .romanUpper => some (romanLower n).toUpper
  | .alph => if 1 ≤ n && n ≤ 26 then some (Char.ofNat ('a'.toNat + n.toNat - 1)).toString
      else if n == 0 then some "" else none
  | .alphUpper => if 1 ≤ n && n ≤ 26 then some (Char.ofNat ('A'.toNat + n.toNat - 1)).toString
      else if n == 0 then some "" else none
  | .fnsymbol => if n == 0 then some "" else fnSymbols[n.toNat - 1]?

end LeAnTeX.Doc
