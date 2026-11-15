/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/

/-!
# Metric files built for the tests

A metric file made byte by byte, so the tests of the reader and of the layout need no file of
an installed TeX: characters 0 to 127, each 0.5 of the size wide, 0.7 high and 0.2 deep, and
22 parameters (as many as a math symbol font has), every one nonzero. Character `a` (97) has a
one-step ligature program before itself, of a kind the caller chooses: with kind 3 (`|=:|`,
insert `a` between the two and look at the pair again) it is a font whose ligatures never end.
-/

namespace LeAnTeXTest.TfmSynth

/-- A 32-bit big-endian word. -/
def w32 (a b c d : Nat) : List UInt8 := [a.toUInt8, b.toUInt8, c.toUInt8, d.toUInt8]

/-- A fix-word's bytes (from a nonnegative value in 2⁻²⁰). -/
def fw (v : Nat) : List UInt8 :=
  w32 (v / 16777216 % 256) (v / 65536 % 256) (v / 256 % 256) (v % 256)

/-- A 16-bit big-endian half-word. -/
def h16 (v : Nat) : List UInt8 := [(v / 256).toUInt8, (v % 256).toUInt8]

/-- The metric file described in the module docstring, `a`'s ligature step of kind `op` before
`a` making `a`. -/
def ligFont (op : Nat) : ByteArray :=
  let one := 1048576
  -- lh, bc, ec, nw, nh, nd, ni, nl, nk, ne, np
  let lens := [2, 0, 127, 2, 2, 2, 1, 1, 0, 0, 22]
  let lf := 6 + lens.head! + 128 + 2 + 2 + 2 + 1 + 1 + 22
  let header := (lf :: lens).flatMap h16
  let hdr := w32 0 0 0 0 ++ fw (10 * one)
  let chars := (List.range 128).flatMap fun c =>
    if c == 97 then w32 1 (1 * 16 + 1) 1 0 else w32 1 (1 * 16 + 1) 0 0
  let dims := fw 0 ++ fw (one / 2) ++ fw 0 ++ fw (one * 7 / 10) ++ fw 0 ++ fw (one / 5) ++ fw 0
  let lig := w32 128 97 op 97
  let params := fw 0 ++ (List.range 21).flatMap fun k => fw (one * (k + 2) / 50)
  ByteArray.mk (header ++ hdr ++ chars ++ dims ++ lig ++ params).toArray

end LeAnTeXTest.TfmSynth
