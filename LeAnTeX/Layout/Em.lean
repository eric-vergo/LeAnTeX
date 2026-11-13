/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/

/-!
# Fixed-point lengths

`Em` is a length as an integer number of TeX's scaled points: 2⁻¹⁶ pt, at KaTeX's ten points
to the em 1/655360 em. The layout computes with it instead of floating point so that its
results are exact, reproducible on every platform, and open to proof.

KaTeX computes in JavaScript doubles and writes its CSS lengths rounded to 1e-4 em; its tables
have at most five decimals. A scaled point (about 1.5e-6 em) rounds each input by at most
7.6e-7 em and every product or quotient by at most half a unit, so even a deeply nested layout
stays far inside the 1e-4 em that KaTeX's own output resolves.

## Main definitions

* `Em`: the length, with `+`, `-`, `*`, `/`, `min`, `max` and order.
* `Em.ofRatio`, `Em.ofFloat`, literals such as `(0.5 : Em)` (rounded to the nearest unit).
* `Em.toFloat`, `Em.css`: the value as a float, and as KaTeX's `makeEm` writes it.

## Implementation notes

Rounding is to the nearest unit with halves away from zero, everywhere (literals, products,
quotients, `css`), matching JavaScript's `toFixed` and the table generator.
-/

namespace LeAnTeX

/-- A length in em, as a whole number of scaled points (1/655360 em). -/
structure Em where
  /-- The length in scaled points. -/
  raw : Int
  deriving BEq, DecidableEq, Hashable, Inhabited, Repr

namespace Em

/-- The number of scaled points in one em: 2¹⁶ to the point, ten points to the em. -/
def unit : Nat := 655360

/-- `a / b` rounded to the nearest integer, halves away from zero; `0` when `b = 0`. -/
def roundDiv (a b : Int) : Int :=
  if b == 0 then 0
  else
    let n := a.natAbs * 2 + b.natAbs
    let q : Int := (n / (2 * b.natAbs) : Nat)
    if (a < 0) != (b < 0) then -q else q

/-- The length `n / d` em, rounded to the nearest unit. -/
def ofRatio (n d : Int) : Em := ⟨roundDiv (n * unit) d⟩

/-- `n` em. -/
def ofInt (n : Int) : Em := ⟨n * unit⟩

/-- A float number of em, rounded to the nearest unit (`0` for a non-finite value). -/
def ofFloat (x : Float) : Em :=
  if x.isNaN || x.isInf then ⟨0⟩
  else
    let y := x.abs * unit.toFloat + 0.5
    let n : Int := y.floor.toUInt64.toNat
    ⟨if x < 0 then -n else n⟩

/-- The value as a float. -/
def toFloat (a : Em) : Float := Float.ofInt a.raw / unit.toFloat

instance (n : Nat) : OfNat Em n := ⟨⟨n * unit⟩⟩

instance : OfScientific Em where
  ofScientific m neg e :=
    if neg then ofRatio m (10 ^ e) else ⟨m * 10 ^ e * unit⟩

instance : Add Em := ⟨fun a b => ⟨a.raw + b.raw⟩⟩
instance : Sub Em := ⟨fun a b => ⟨a.raw - b.raw⟩⟩
instance : Neg Em := ⟨fun a => ⟨-a.raw⟩⟩

/-- The product of two lengths in em, rounded to the nearest unit. -/
instance : Mul Em := ⟨fun a b => ⟨roundDiv (a.raw * b.raw) unit⟩⟩

/-- The quotient of two lengths in em, rounded to the nearest unit (`0` for a zero divisor). -/
instance : Div Em := ⟨fun a b => ⟨roundDiv (a.raw * unit) b.raw⟩⟩

/-- An integer multiple. -/
instance : HMul Int Em Em := ⟨fun k a => ⟨k * a.raw⟩⟩

instance : LT Em := ⟨fun a b => a.raw < b.raw⟩
instance : LE Em := ⟨fun a b => a.raw ≤ b.raw⟩
instance (a b : Em) : Decidable (a < b) := inferInstanceAs (Decidable (a.raw < b.raw))
instance (a b : Em) : Decidable (a ≤ b) := inferInstanceAs (Decidable (a.raw ≤ b.raw))
instance : Max Em := ⟨fun a b => if a.raw < b.raw then b else a⟩
instance : Min Em := ⟨fun a b => if b.raw < a.raw then b else a⟩
instance : Ord Em := ⟨fun a b => compare a.raw b.raw⟩

/-- The absolute value. -/
def abs (a : Em) : Em := ⟨a.raw.natAbs⟩

/-- The smallest integer number of em at least `a` (`Math.ceil`). -/
def ceil (a : Em) : Int := -((-a.raw) / unit)

/-- The largest integer number of em at most `a` (`Math.floor`). -/
def floor (a : Em) : Int := a.raw / unit

/-- `a` rounded to the nearest integer number of em, halves up (`Math.round`). -/
def round (a : Em) : Int := (a.raw + unit / 2) / unit

/-- The digits of `a` rounded to `places` decimals, halves away from zero, without trailing
zeros (JavaScript's `+a.toFixed(places)` printed as a number). -/
def decimal (a : Em) (places : Nat) : String :=
  let q := roundDiv (a.raw * 10 ^ places) unit
  if q == 0 then "0"
  else
    let sign := if q < 0 then "-" else ""
    let n := q.natAbs
    let ip := n / 10 ^ places
    let fp := n % 10 ^ places
    if fp == 0 then sign ++ toString ip
    else
      let digits := toString fp
      let padded := String.ofList (List.replicate (places - digits.length) '0') ++ digits
      let trimmed := (padded.toList.reverse.dropWhile (· == '0')).reverse
      sign ++ toString ip ++ "." ++ String.ofList trimmed

/-- The CSS length KaTeX writes for `a` (`makeEm`): four decimals, then `em`. -/
def css (a : Em) : String := a.decimal 4 ++ "em"

instance : ToString Em := ⟨fun a => a.decimal 6⟩

end Em

end LeAnTeX
