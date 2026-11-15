/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Text.Node

/-!
# Reading TeX source

The text layer's tokenizer and TeX's units: source text becomes tokens with LaTeX's category
codes, and lengths written in the source become scaled points as TeX computes them.

* **Tokens.** `\` starts a control sequence: a run of letters (spaces after it skipped) or one
  other character. `{` and `}` group, `$` shifts to math, `&` aligns, `#` marks a macro
  parameter, `^` and `_` are math's scripts, `~` is active, `%` comments to the end of the line
  (and the indentation of the next). Runs of spaces and a single line end are one space; an
  empty line is `\par`. Other characters stand for themselves.
* **Units.** `pt`, `pc`, `in`, `bp`, `cm`, `mm`, `dd`, `cc`, `sp`, and `em` and `ex` of the
  current font, with TeX's decimal rounding (seventeen digits) and its conversion ratios, so
  that `12.5pt` is 819200 sp and `1in` is 4736286 sp as in TeX.

Source is untrusted: the tokenizer is total and linear in its input, and every count is
bounded by the caller's caps.

## Main definitions

* `Tok`, `tokenize`, `Tok.text`.
* `roundDecimals`, `unitSp`, `scaleUnit`.
-/

namespace LeAnTeX.Text

/-- A token: a control sequence (its name, without the backslash), a character with its
category, or a parameter `#n` inside a macro body. `pos` is the offset of the token in the
source (in characters), 0 for tokens a macro produced. -/
inductive Tok where
  /-- A control sequence. -/
  | cs (name : String) (pos : Nat)
  /-- A character: a letter or other character (`cat` 11 or 12), a space (10), `{` (1),
  `}` (2), `$` (3), `&` (4), `#` (6), `^` (7), `_` (8), `~` (13). -/
  | char (c : Char) (cat : Nat) (pos : Nat)
  /-- Parameter `n` (1–9) of a macro body. -/
  | param (n : Nat)
  deriving BEq, Inhabited, Repr

namespace Tok

/-- Whether the token is the character `c` of category `cat`. -/
def isChar (t : Tok) (c : Char) (cat : Nat) : Bool :=
  match t with
  | .char d k _ => d == c && k == cat
  | _ => false

/-- Whether the token is the control sequence `n`. -/
def isCs (t : Tok) (n : String) : Bool := match t with | .cs m _ => m == n | _ => false

/-- Whether the token is a space. -/
def isSpace (t : Tok) : Bool := match t with | .char _ 10 _ => true | _ => false

/-- Whether the token opens a group. -/
def isBegin (t : Tok) : Bool := match t with | .char _ 1 _ => true | _ => false

/-- Whether the token closes a group. -/
def isEnd (t : Tok) : Bool := match t with | .char _ 2 _ => true | _ => false

/-- The token's position in the source, 0 if a macro produced it. -/
def pos : Tok → Nat
  | .cs _ p | .char _ _ p => p
  | .param _ => 0

/-- The token as source text (a control sequence named by letters followed by a space). -/
def text : Tok → String
  | .cs n _ => if n.length == 1 && !(n.toList.headD 'a').isAlpha then "\\" ++ n else "\\" ++ n ++ " "
  | .char c _ _ => c.toString
  | .param n => "#" ++ toString n

end Tok

/-- The category of a character outside control sequences. -/
def catcode (c : Char) : Nat :=
  match c with
  | '{' => 1 | '}' => 2 | '$' => 3 | '&' => 4 | '#' => 6 | '^' => 7 | '_' => 8
  | '~' => 13 | ' ' | '\t' => 10
  | c => if c.isAlpha then 11 else 12

/-- The tokens of source text (see the module docstring). Linear in the source. -/
def tokenize (src : String) : Array Tok := Id.run do
  let cs := src.toList.toArray
  let n := cs.size
  let mut out : Array Tok := #[]
  let mut i := 0
  -- whether the last token was a space or a control word (spaces after it are skipped), and
  -- whether the line so far holds only spaces (a line end there is `\par` or nothing)
  let mut skipSpace := true
  let mut lineBlank := true
  for _ in [0:n + 1] do
    if i ≥ n then break
    let c := cs[i]?.getD ' '
    if c == '\\' then
      lineBlank := false
      let start := i
      i := i + 1
      let first := cs[i]?.getD ' '
      if i ≥ n then out := out.push (.cs "" start); skipSpace := false
      else if first.isAlpha then
        let mut name := ""
        for _ in [i:n] do
          let d := cs[i]?.getD ' '
          if d.isAlpha then name := name.push d; i := i + 1 else break
        out := out.push (.cs name start); skipSpace := true
      else
        out := out.push (.cs first.toString start); i := i + 1
        skipSpace := first == ' '
    else if c == '%' then
      for _ in [i:n] do
        if cs[i]?.getD '\n' == '\n' then break
        i := i + 1
      i := i + 1
      for _ in [i:n] do
        let d := cs[i]?.getD 'x'
        if d == ' ' || d == '\t' then i := i + 1 else break
    else if c == '\n' || c == '\r' then
      if lineBlank then
        -- an empty line: `\par` (one for a run of empty lines)
        match out.back? with
        | some (.cs "par" _) => pure ()
        | _ =>
          if out.back?.map Tok.isSpace == some true then out := out.pop
          out := out.push (.cs "par" i)
        skipSpace := true
      else if !skipSpace then out := out.push (.char ' ' 10 i); skipSpace := true
      lineBlank := true
      i := i + 1
    else if c == ' ' || c == '\t' then
      if !skipSpace then out := out.push (.char ' ' 10 i); skipSpace := true
      i := i + 1
    else
      lineBlank := false
      out := out.push (.char c (catcode c) i); skipSpace := false
      i := i + 1
  return out

/-- TeX's `round_decimals`: the fraction `0.d₁d₂…` (at most seventeen digits used) in units of
2⁻¹⁶, rounded. -/
def roundDecimals (digits : List Nat) : Int := Id.run do
  let mut a : Nat := 0
  for d in (digits.take 17).reverse do
    a := (a + d * 0x20000) / 10
  return ((a + 1) / 2 : Nat)

/-- A unit's ratio to the point, `(num, den)`, as TeX defines it; `none` for an unknown unit
or one relative to the font (`em`, `ex`). -/
def unitRatio : String → Option (Nat × Nat)
  | "pt" => some (1, 1) | "pc" => some (12, 1) | "in" => some (7227, 100)
  | "bp" => some (7227, 7200) | "cm" => some (7227, 254) | "mm" => some (7227, 2540)
  | "dd" => some (1238, 1157) | "cc" => some (14856, 1157)
  | _ => none

/-- `whole + frac / 2¹⁶` points in a unit of ratio `num / den` to the point, in sp, as TeX's
`scan_dimen` converts it (`xn_over_d` with its remainder carried into the fraction). -/
def scaleUnit (whole : Nat) (frac : Nat) (num den : Nat) : Int :=
  if num == 1 && den == 1 then (whole * 65536 + frac : Nat)
  else
    let w := whole * num / den
    let r := whole * num % den
    let f := (num * frac + 65536 * r) / den
    ((w + f / 65536) * 65536 + f % 65536 : Nat)

end LeAnTeX.Text
