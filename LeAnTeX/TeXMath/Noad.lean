/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.TeXMath.Node

/-!
# Math lists

The lists TeX builds in math mode before it lays them out: atoms (TeX's *noads*) with a
nucleus, a superscript and a subscript, generalised fractions, radicals, accents, the
delimiters of `\left`, `\middle` and `\right`, style changes, `\mathchoice`, and the glue,
kerns, penalties and rules a formula may hold. A field of an atom is empty, a math character (a
family and a slot), a box, or a math list of its own.

## Main definitions

* `Style`: TeX's eight styles, with `cramped`, `sub`, `sup`, `num`, `denom` and `size`.
* `AtomKind`, `Limits`, `Delim`, `Field`, `Noad`.

## References

* D. E. Knuth, *The TeXbook*, Chapter 17 and Appendix G; *TeX: The Program*, §680–§698
  (the noad types and the style codes), §702 (the style functions).
-/

namespace LeAnTeX.TeXMath

open LeAnTeX.Text (Glue)

/-- A style: display (0), text (2), script (4), scriptscript (6), each with its cramped
variant one above (TeX's numbering). -/
structure Style where
  /-- TeX's style code, 0 to 7. -/
  code : Fin 8
  deriving BEq, DecidableEq, Inhabited, Repr

namespace Style

/-- Display style. -/
def display : Style := ⟨0⟩
/-- Text style. -/
def text : Style := ⟨2⟩
/-- Script style. -/
def script : Style := ⟨4⟩
/-- Scriptscript style. -/
def scriptscript : Style := ⟨6⟩

/-- A style from TeX's code, taken modulo 8. -/
def ofNat (n : Nat) : Style := ⟨Fin.ofNat 8 n⟩

/-- Whether the style is cramped (an odd code). -/
def isCramped (s : Style) : Bool := s.code.val % 2 == 1

/-- The cramped variant (TeX's `cramped_style`). -/
def cramped (s : Style) : Style := ofNat (2 * (s.code.val / 2) + 1)

/-- The style of a subscript (TeX's `sub_style`): script or scriptscript, cramped. -/
def sub (s : Style) : Style := ofNat (2 * (s.code.val / 4) + 4 + 1)

/-- The style of a superscript (TeX's `sup_style`): script or scriptscript, cramped as `s`. -/
def sup (s : Style) : Style := ofNat (2 * (s.code.val / 4) + 4 + s.code.val % 2)

/-- The style of a numerator (TeX's `num_style`). -/
def num (s : Style) : Style := ofNat (s.code.val + 2 - 2 * (s.code.val / 6))

/-- The style of a denominator (TeX's `denom_style`): cramped. -/
def denom (s : Style) : Style := ofNat (2 * (s.code.val / 2) + 1 + 2 - 2 * (s.code.val / 6))

/-- The math size of a style: text for display and text, script, scriptscript. -/
def size (s : Style) : Fin 3 :=
  if s.code.val < 4 then 0 else if s.code.val < 6 then 1 else 2

/-- Whether the style is display or text (TeX's `cur_style < script_style`): spacing of the
kinds TeX suppresses in scripts applies. -/
def isLarge (s : Style) : Bool := s.code.val < 4

/-- Whether the style is display (TeX's `cur_style < text_style`). -/
def isDisplay (s : Style) : Bool := s.code.val < 2

end Style

/-- The class of an atom. -/
inductive AtomKind where
  /-- Ordinary. -/
  | ord
  /-- Large operator. -/
  | op
  /-- Binary operation. -/
  | bin
  /-- Relation. -/
  | rel
  /-- Opening. -/
  | «open»
  /-- Closing. -/
  | close
  /-- Punctuation. -/
  | punct
  /-- Inner (a `\left…\right` group, a fraction). -/
  | inner
  /-- `\overline`. -/
  | over
  /-- `\underline`. -/
  | under
  /-- `\vcenter` (its nucleus a vertical box). -/
  | vcenter
  deriving BEq, DecidableEq, Inhabited, Repr

/-- The index of an atom kind in the inter-atom spacing table (`over`, `under` and `vcenter`
are ordinary there): 0 ord, 1 op, 2 bin, 3 rel, 4 open, 5 close, 6 punct, 7 inner. -/
def AtomKind.spacingIndex : AtomKind → Fin 8
  | .ord | .over | .under | .vcenter => 0
  | .op => 1 | .bin => 2 | .rel => 3 | .open => 4 | .close => 5 | .punct => 6 | .inner => 7

/-- The limits of a large operator: as the style decides (`\displaylimits`), `\limits`,
`\nolimits`. -/
inductive Limits where
  /-- Above and below in display style, at the side otherwise. -/
  | normal
  /-- Always above and below. -/
  | limits
  /-- Always at the side. -/
  | noLimits
  deriving BEq, Inhabited, Repr

/-- A delimiter code: the small variant (a family and a slot) and the large one; a slot of 0
in family 0 for none, as in TeX. -/
structure Delim where
  /-- The small variant's family. -/
  smallFam : Nat := 0
  /-- The small variant's slot. -/
  smallChar : Nat := 0
  /-- The large variant's family. -/
  largeFam : Nat := 0
  /-- The large variant's slot. -/
  largeChar : Nat := 0
  deriving BEq, Inhabited, Repr

/-- The null delimiter (`.`). -/
def Delim.null : Delim := {}

/-- A delimiter from TeX's 24-bit `\delcode` value `"uvvxyy` (small family `u`, slot `vv`,
large family `x`, slot `yy`). -/
def Delim.ofCode (v : Nat) : Delim :=
  { smallFam := (v / 1048576) % 16, smallChar := (v / 4096) % 256,
    largeFam := (v / 256) % 16, largeChar := v % 256 }

mutual

/-- A field of an atom. -/
inductive Field where
  /-- Empty. -/
  | empty
  /-- A math character: a family and a slot. -/
  | mathChar (fam code : Nat)
  /-- A math character marked by the ligature rule as part of a word (TeX's
  `math_text_char`). -/
  | textChar (fam code : Nat)
  /-- A box. -/
  | box (b : Node)
  /-- A math list. -/
  | list (l : Array Noad)

/-- An item of a math list. -/
inductive Noad where
  /-- An atom: its kind, nucleus, superscript, subscript and (for an operator) its limits. -/
  | atom (kind : AtomKind) (nucleus sup sub : Field) (lim : Limits := .normal)
  /-- A radical: its nucleus, scripts and delimiter (the radical sign). -/
  | radical (nucleus sup sub : Field) (delim : Delim)
  /-- A math accent: its nucleus, scripts and accent character. -/
  | accent (nucleus sup sub : Field) (fam code : Nat)
  /-- A generalised fraction: numerator, denominator, rule thickness (`none` for the
  default, TeX's `\over`), left and right delimiters. -/
  | fraction (num den : Field) (thickness : Option Int) (left right : Delim)
  /-- `\left` (`side = 0`), `\middle` (1) or `\right` (2) with its delimiter. -/
  | delim (side : Nat) (d : Delim)
  /-- A style change. -/
  | style (s : Style)
  /-- `\mathchoice`: the lists for display, text, script and scriptscript style. -/
  | choice (d t s ss : Array Noad)
  /-- Glue: in mu when `mu`; `cond` for glue after `\nonscript`. -/
  | glue (g : Glue) (mu : Bool) (cond : Bool := false)
  /-- A kern: in mu when `mu`. -/
  | kern (width : Int) (mu : Bool)
  /-- A penalty. -/
  | penalty (p : Int)
  /-- Material passed through unchanged (a rule, a box set by `\hbox` in a list). -/
  | node (n : Node)

end

instance : Inhabited Field := ⟨.empty⟩
instance : Inhabited Noad := ⟨.penalty 0⟩

/-- Whether a field is empty. -/
def Field.isEmpty : Field → Bool
  | .empty => true
  | _ => false

end LeAnTeX.TeXMath
