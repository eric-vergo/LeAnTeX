/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/

/-!
# Checked reads of font data

A font file is untrusted input. Every table is read through a `Slice`, a window of the file's
bytes whose reads are checked against the window's end: a read past it, or a sub-window that
does not fit, is a `FontError` naming the table, never an out-of-bounds access or a panic.

## Main definitions

* `FontError`, `Result`: the error of a failed read and the result type of every reader.
* `Slice`: a checked window; `Slice.u8`, `u16`, `i16`, `u24`, `u32`, `i32`, `tag`, `sub`,
  `drop`.
* `Slice.fixed1616`, `Slice.f2dot14`: OpenType's fixed-point numbers as exact `Int`s in
  1/65536.
-/

namespace LeAnTeX.OpenType

/-- Why a font could not be read: the table (or reader) and what was wrong. -/
structure FontError where
  /-- The table or part of the file being read. -/
  table : String
  /-- What was wrong. -/
  message : String
  deriving BEq, Inhabited, Repr

instance : ToString FontError := ⟨fun e => e.table ++ ": " ++ e.message⟩

/-- The result of reading font data. -/
abbrev Result := Except FontError

/-- Fail with a message about a table. -/
def fail {α : Type} (table message : String) : Result α := .error ⟨table, message⟩

/-- A window `[start, start + size)` of a font file's bytes, the unit of every checked read.
`Slice.ofBytes` and `Slice.sub` keep the window inside `data`; reads check the offset against
`size`. -/
structure Slice where
  /-- The whole file. -/
  data : ByteArray
  /-- The window's first byte in `data`. -/
  start : Nat
  /-- The window's length. -/
  size : Nat
  /-- The table it belongs to, for error messages. -/
  table : String

namespace Slice

/-- The whole of `data` as a window. -/
def ofBytes (data : ByteArray) (table : String := "file") : Slice := ⟨data, 0, data.size, table⟩

/-- Fail with a message about this window's table. -/
def fail {α : Type} (s : Slice) (message : String) : Result α := OpenType.fail s.table message

/-- The byte at `off`. -/
def u8 (s : Slice) (off : Nat) : Result Nat :=
  if off < s.size then
    match s.data[s.start + off]? with
    | some b => .ok b.toNat
    | none => s.fail s!"offset {off} outside the file"
  else s.fail s!"read at {off} past the end ({s.size} bytes)"

/-- Whether `len` bytes from `off` lie inside the window. -/
def fits (s : Slice) (off len : Nat) : Bool := off + len ≤ s.size

/-- Fail unless `len` bytes from `off` lie inside the window. -/
def need (s : Slice) (off len : Nat) : Result Unit :=
  if s.fits off len then .ok () else s.fail s!"{len} bytes at {off} past the end ({s.size})"

/-- The big-endian unsigned integer of `n` bytes at `off`. -/
def uN (s : Slice) (off n : Nat) : Result Nat := do
  s.need off n
  let mut v := 0
  for i in [0:n] do
    v := v * 256 + (← s.u8 (off + i))
  return v

/-- An unsigned 16-bit integer. -/
def u16 (s : Slice) (off : Nat) : Result Nat := s.uN off 2

/-- An unsigned 24-bit integer. -/
def u24 (s : Slice) (off : Nat) : Result Nat := s.uN off 3

/-- An unsigned 32-bit integer. -/
def u32 (s : Slice) (off : Nat) : Result Nat := s.uN off 4

/-- The two's-complement value of the `bits`-bit unsigned `v`. -/
def signed (v bits : Nat) : Int := if v ≥ 2 ^ (bits - 1) then (v : Int) - 2 ^ bits else v

/-- A signed 16-bit integer. -/
def i16 (s : Slice) (off : Nat) : Result Int := return signed (← s.u16 off) 16

/-- A signed 32-bit integer. -/
def i32 (s : Slice) (off : Nat) : Result Int := return signed (← s.u32 off) 32

/-- A 16.16 fixed-point number, as an `Int` in 1/65536. -/
def fixed1616 (s : Slice) (off : Nat) : Result Int := s.i32 off

/-- A 2.14 fixed-point number, as an `Int` in 1/65536. -/
def f2dot14 (s : Slice) (off : Nat) : Result Int := return (← s.i16 off) * 4

/-- A four-byte tag as text (its bytes as Latin-1 characters). -/
def tag (s : Slice) (off : Nat) : Result String := do
  s.need off 4
  let mut out := ""
  for i in [0:4] do
    out := out.push (Char.ofNat (← s.u8 (off + i)))
  return out

/-- The window of `len` bytes at `off`, for table `table` (this window's table if empty). -/
def sub (s : Slice) (off len : Nat) (table : String := "") : Result Slice := do
  s.need off len
  return ⟨s.data, s.start + off, len, if table.isEmpty then s.table else table⟩

/-- The window from `off` to the end. -/
def drop (s : Slice) (off : Nat) : Result Slice :=
  if off ≤ s.size then .ok ⟨s.data, s.start + off, s.size - off, s.table⟩
  else s.fail s!"offset {off} past the end ({s.size})"

/-- The window's bytes. -/
def bytes (s : Slice) : ByteArray := s.data.extract s.start (s.start + s.size)

end Slice

end LeAnTeX.OpenType
