/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/

/-!
# TeX's arithmetic on scaled points

Lengths are integers of scaled points (sp, 2⁻¹⁶ pt), and every division rounds as TeX's does:
toward zero, with the sign handled apart. Agreement with TeX to the sp depends on it.

## Main definitions

* `half`: half of a length, odd values rounded up (TeX's `half`).
* `xOverN`: `x / n` toward zero and its remainder (TeX's `x_over_n`).
* `xnOverD`: `x * n / d` toward zero, for `n, d` below 2¹⁶ (TeX's `xn_over_d`).
* `nxPlusY`: `n * x + y` (TeX's `nx_plus_y`, without its overflow test: lengths are `Int`).
* `muMult`: a length in mu at the math unit `m` (TeX's `math_kern` and `math_glue`).

## References

* D. E. Knuth, *TeX: The Program*, §100 (`half`), §105 (`nx_plus_y`), §106 (`x_over_n`),
  §107 (`xn_over_d`), §716–§717 (`math_kern`, `math_glue`).
-/

namespace LeAnTeX.TeXMath

/-- TeX's `half`: `x / 2` toward zero for even `x`, `(x + 1) / 2` for odd `x`. -/
def half (x : Int) : Int := if x % 2 == 0 then x.tdiv 2 else (x + 1).tdiv 2

/-- TeX's `x_over_n`: the quotient `x / n` rounded toward zero, and the remainder with the sign
of `x` (TeX's global `remainder`). For `n = 0` the quotient is 0 and the remainder `x`, as TeX
gives after its "arithmetic overflow" error. -/
def xOverN (x n : Int) : Int × Int :=
  if n == 0 then (0, x)
  else
    let n' := if n < 0 then -n else n
    let x' := if n < 0 then -x else x
    if x' ≥ 0 then (x'.tdiv n', x'.tmod n')
    else (-((-x').tdiv n'), -((-x').tmod n'))

/-- TeX's `xn_over_d`: `x * n / d` rounded toward zero (the sign of `x` handled apart), for
`0 ≤ n` and `0 < d`. -/
def xnOverD (x n d : Int) : Int :=
  if d ≤ 0 then 0
  else if x ≥ 0 then (x * n).tdiv d else -(((-x) * n).tdiv d)

/-- TeX's `nx_plus_y`: `n * x + y`. -/
def nxPlusY (n x y : Int) : Int := n * x + y

/-- A length given in mu (`x`, in 2⁻¹⁶ mu) at the math unit `m` (sp per mu, the font's
`\fontdimen6` over 18): TeX splits `m` into whole sp and a fraction of 2¹⁶ and multiplies each
part, as `math_kern` and `math_glue` do. -/
def muMult (m x : Int) : Int :=
  let (n, f) := xOverN m 65536
  let (n, f) := if f < 0 then (n - 1, f + 65536) else (n, f)
  nxPlusY n x (xnOverD x f 65536)

end LeAnTeX.TeXMath
