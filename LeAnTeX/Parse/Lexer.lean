/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Parse.Base

/-!
# Lexer

Splits a TeX string into tokens exactly as KaTeX's `Lexer` does: whitespace runs, control
spaces, single characters with their combining accents, `\verb` and `\verb*` with their
delimited text, control words (eating the spaces after them) and control symbols, with `%`
comments skipped while `%` has category code 14.

## Main definitions

* `Lexer`: the state of a lexer over one source text.
* `Lexer.lex`: the next token.
* `lexAll`: every token of a text (for macro bodies).

## Implementation notes

KaTeX's lexer is one regular expression (`tokenRegex`) applied at the current position; this
module spells the same alternatives out, in the same order. JavaScript's `.` does not match line
terminators (`\n`, `\r`, U+2028, U+2029), which matters for where `\verb` may end. A character
the expression does not match is KaTeX's "Unexpected character" error.

## References

* KaTeX's `src/Lexer.ts` (MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- The state of a lexer over one source. -/
structure Lexer where
  /-- The text. -/
  src : Source
  /-- The text as characters. -/
  chars : Array Char
  /-- The current position, in characters. -/
  pos : Nat := 0
  /-- The current position, in UTF-16 code units. -/
  u16 : Nat := 0
  /-- Category codes that differ from TeX's defaults: `%` is 14 (comment), `~` is 13
  (active); the parser changes them temporarily for raw and URL arguments. -/
  catcodes : List (String × Nat) := [("%", 14), ("~", 13)]
  deriving Inhabited

/-- A lexer at the start of `src`. -/
def Lexer.ofSource (src : Source) : Lexer := { src, chars := src.text.toList.toArray }

/-- The category code of a token text, if one is set. -/
def Lexer.catcode (lx : Lexer) (text : String) : Option Nat :=
  (lx.catcodes.find? (·.1 == text)).map (·.2)

/-- The lexer with the category code of `char` set to `code`. -/
def Lexer.setCatcode (lx : Lexer) (char : String) (code : Nat) : Lexer :=
  { lx with catcodes := (char, code) :: lx.catcodes.filter (·.1 != char) }

/-- TeX's whitespace as KaTeX's lexer sees it: space, return, newline, tab. -/
private def isSpace (c : Char) : Bool := c == ' ' || c == '\r' || c == '\n' || c == '\t'

/-- A combining diacritical mark (U+0300 to U+036F). -/
def isCombining (c : Char) : Bool := c.val ≥ 0x300 && c.val ≤ 0x36F

/-- A JavaScript line terminator, which `.` does not match. -/
private def isLineTerminator (c : Char) : Bool :=
  c == '\n' || c == '\r' || c.val == 0x2028 || c.val == 0x2029

/-- A character that may form a token on its own: printable ASCII except `\`, the BMP except
controls, U+2028/U+2029, surrogates and the private use area, and every astral character. -/
private def isTokenChar (c : Char) : Bool :=
  let v := c.val
  (v ≥ 0x21 && v ≤ 0x5B) || (v ≥ 0x5D && v ≤ 0x2027) || (v ≥ 0x202A && v ≤ 0xD7FF) ||
    (v ≥ 0xF900 && v ≤ 0xFFFF) || v ≥ 0x10000

/-- A letter of a control word: ASCII letters and `@`. -/
private def isWordChar (c : Char) : Bool :=
  (c ≥ 'a' && c ≤ 'z') || (c ≥ 'A' && c ≤ 'Z') || c == '@'

/-- The characters `chars[a:b]` as a string. -/
private def sliceStr (chars : Array Char) (a b : Nat) : String :=
  (chars.extract a b).foldl String.push ""

/-- The UTF-16 length of `chars[a:b]`. -/
private def sliceU16 (chars : Array Char) (a b : Nat) : Nat :=
  (chars.extract a b).foldl (fun n c => n + utf16Len c) 0

/-- The position after `[ \r\t]*` starting at `i`. -/
private partial def skipBlank (chars : Array Char) (i : Nat) : Nat :=
  if h : i < chars.size then
    let c := chars[i]
    if c == ' ' || c == '\r' || c == '\t' then skipBlank chars (i + 1) else i
  else i

/-- The position after the run of characters satisfying `p` starting at `i`. -/
private partial def skipWhile (chars : Array Char) (p : Char → Bool) (i : Nat) : Nat :=
  if h : i < chars.size then (if p chars[i] then skipWhile chars p (i + 1) else i) else i

/-- The end of `\verb` text: the position after the first `delim` at or after `i`, unless a line
terminator comes first (JavaScript's lazy `.*?` followed by the delimiter). -/
private partial def verbEnd (chars : Array Char) (delim : Char) (i : Nat) : Option Nat :=
  if h : i < chars.size then
    let c := chars[i]
    if c == delim then some (i + 1)
    else if isLineTerminator c then none
    else verbEnd chars delim (i + 1)
  else none

/-- The match of KaTeX's token expression at position `i`: the end position and the token text,
or `none` if nothing matches there. -/
private def matchAt (chars : Array Char) (i : Nat) : Option (Nat × String) := do
  let c ← chars[i]?
  if isSpace c then
    return (skipWhile chars isSpace i, " ")
  if c == '\\' then
    -- control space: `\` then a newline, or blanks and at most one newline, then blanks
    match chars[i + 1]? with
    | some '\n' => return (skipBlank chars (i + 2), "\\ ")
    | some d =>
      if d == ' ' || d == '\r' || d == '\t' then
        let j := skipBlank chars (i + 1)
        let j := if chars[j]? == some '\n' then j + 1 else j
        return (skipBlank chars j, "\\ ")
    | none => pure ()
  if isTokenChar c then
    return (skipWhile chars isCombining (i + 1), sliceStr chars i (skipWhile chars isCombining
      (i + 1)))
  if c != '\\' then none
  -- `\verb*` with any delimiter, then `\verb` with a delimiter other than `*` and letters
  let isVerb := chars[i + 1]? == some 'v' && chars[i + 2]? == some 'e' &&
    chars[i + 3]? == some 'r' && chars[i + 4]? == some 'b'
  let verbStar : Option Nat :=
    if isVerb && chars[i + 5]? == some '*' then
      match chars[i + 6]? with
      | some d => verbEnd chars d (i + 7)
      | none => none
    else none
  if let some e := verbStar then return (e, sliceStr chars i e)
  let verbPlain : Option Nat :=
    if isVerb then
      match chars[i + 5]? with
      | some d => if d == '*' || (d ≥ 'a' && d ≤ 'z') || (d ≥ 'A' && d ≤ 'Z') then none
          else verbEnd chars d (i + 6)
      | none => none
    else none
  if let some e := verbPlain then return (e, sliceStr chars i e)
  -- control word, eating the whitespace after it
  let w := skipWhile chars isWordChar (i + 1)
  if w > i + 1 then
    return (skipWhile chars isSpace w, sliceStr chars i w)
  -- control symbol: `\` and any BMP character
  let d ← chars[i + 1]?
  if d.val < 0x10000 then return (i + 2, sliceStr chars i (i + 2))
  none

/-- The next token and the lexer after it, KaTeX's `Lexer.lex`, with the strict-mode warning
raised on the way, if any. Comments are skipped; one that runs to the end of the input is
reported under `strict`. -/
partial def Lexer.lex (lx : Lexer) (strict : Strict) :
    Except KError (Token × Lexer × Option Warning) := do
  if lx.pos ≥ lx.chars.size then
    return ({ text := "EOF", loc := .at ⟨lx.src, lx.u16, lx.u16⟩ }, lx, none)
  match matchAt lx.chars lx.pos with
  | none =>
    let c := lx.chars[lx.pos]!
    throw (.parse s!"Unexpected character: '{c}'" (.at ⟨lx.src, lx.u16, lx.u16 + 1⟩))
  | some (e, text) =>
    let u16 := lx.u16 + sliceU16 lx.chars lx.pos e
    if lx.catcode text == some 14 then
      -- a comment: skip to the character after the next newline, or to the end
      match (List.range (lx.chars.size - e)).find? (fun k => lx.chars[e + k]! == '\n') with
      | some k =>
        let e' := e + k + 1
        Lexer.lex { lx with pos := e', u16 := u16 + sliceU16 lx.chars e e' } strict
      | none =>
        let w ← strictReport strict "commentAtEnd" ("% comment has no terminating newline; " ++
          "LaTeX would fail because of commenting the end of math mode (e.g. $)") .absent
        let n := lx.chars.size
        let (tok, lx', w') ← Lexer.lex { lx with pos := n, u16 := u16 + sliceU16 lx.chars e n }
          strict
        return (tok, lx', w.orElse fun _ => w')
    else
      return ({ text, loc := .at ⟨lx.src, lx.u16, u16⟩ }, { lx with pos := e, u16 }, none)

/-- Every token of a text up to (not including) the end, for a macro body, with the warnings
raised while lexing it. -/
partial def lexAll (src : Source) (strict : Strict) :
    Except KError (Array Token × Array Warning) :=
  go (Lexer.ofSource src) #[] #[]
where
  /-- Lex from `lx`, appending to `acc` and `ws`. -/
  go (lx : Lexer) (acc : Array Token) (ws : Array Warning) :
      Except KError (Array Token × Array Warning) := do
    let (tok, lx, w) ← lx.lex strict
    let ws := match w with | some w => ws.push w | none => ws
    if tok.text == "EOF" then return (acc, ws) else go lx (acc.push tok) ws

end LeAnTeX
