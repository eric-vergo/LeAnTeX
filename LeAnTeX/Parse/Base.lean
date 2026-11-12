/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Spec

/-!
# Source locations, tokens, errors and settings

The parser's basic vocabulary: a source text, a location in it, a token, a parse error with
KaTeX's exact message, and the settings that change how a formula is parsed.

## Main definitions

* `Source`, `Loc`, `OLoc`: a text, a range in it, and a location that may be absent or null.
* `Token`: a lexed token.
* `KError`: a `ParseError` (KaTeX's message and position) or an internal error.
* `Settings`, `Strict`: the parse options.

## Implementation notes

Positions are UTF-16 code unit offsets, as JavaScript counts them, so that error positions and
the `loc` fields of parse nodes are KaTeX's numbers. KaTeX distinguishes a location that is not
set (`undefined`, dropped from the JSON) from one that is `null` (the range of two tokens from
different lexers); `OLoc` keeps that distinction.

## References

* KaTeX's `src/SourceLocation.ts`, `src/Token.ts`, `src/ParseError.ts`, `src/Settings.ts` and
  `src/strict.ts` (MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- The number of UTF-16 code units of a character. -/
def utf16Len (c : Char) : Nat := if c.val ≥ 0x10000 then 2 else 1

/-- The length of a string in UTF-16 code units (JavaScript's `length`). -/
def utf16Length (s : String) : Nat := s.foldl (fun n c => n + utf16Len c) 0

/-- The characters of `s` whose UTF-16 range lies within `[a, b)` (JavaScript's `slice`, except
that a surrogate pair cut in half is dropped). -/
def utf16Slice (s : String) (a b : Nat) : String := Id.run do
  let mut out := ""
  let mut pos := 0
  for c in s.toList do
    let next := pos + utf16Len c
    if pos ≥ a && next ≤ b then out := out.push c
    pos := next
  return out

/-- A text that tokens are lexed from: the formula itself or a macro body. `id` tells texts
apart (KaTeX compares lexers by identity). -/
structure Source where
  /-- A number unique to this text within one parse. -/
  id : Nat
  /-- The text. -/
  text : String
  deriving Inhabited

/-- A range of a source, in UTF-16 code units, end exclusive. -/
structure Loc where
  /-- The text. -/
  src : Source
  /-- Start offset. -/
  start : Nat
  /-- End offset. -/
  stop : Nat
  deriving Inhabited

/-- A location as KaTeX stores it: not set, `null`, or a range. -/
inductive OLoc where
  /-- No location (`undefined` in KaTeX). -/
  | absent
  /-- An explicit `null` (a range over two texts). -/
  | null
  /-- A range. -/
  | at (loc : Loc)
  deriving Inhabited

/-- The range from the start of `a` to the end of `b` (`SourceLocation.range`): `null` unless
both are ranges of the same text. -/
def OLoc.range (a b : OLoc) : OLoc :=
  match a, b with
  | .at x, .at y => if x.src.id == y.src.id then .at ⟨x.src, x.start, y.stop⟩ else .null
  | _, _ => .null

/-- A token: its text, its location and the two flags `\noexpand` sets. -/
structure Token where
  /-- The token text (`"EOF"` at the end of the input). -/
  text : String
  /-- Where it came from. -/
  loc : OLoc := .absent
  /-- Do not expand this token. -/
  noexpand : Bool := false
  /-- Treat this token as `\relax` (set by `\noexpand`). -/
  treatAsRelax : Bool := false
  deriving Inhabited

/-- The token spanning `a` to `b` with the given text (`Token.range`). -/
def Token.range (a b : Token) (text : String) : Token := { text, loc := OLoc.range a.loc b.loc }

/-- An error of the parser. -/
inductive KError where
  /-- KaTeX's `ParseError`: the message without context, and the location it points at. -/
  | parse (raw : String) (loc : OLoc)
  /-- An error KaTeX raises as a plain JavaScript error: its class and message. -/
  | internal (cls : String) (msg : String)
  deriving Inhabited

/-- A `ParseError` at a token. -/
def KError.at (raw : String) (tok : Token) : KError := .parse raw tok.loc

/-- The combining low line KaTeX puts after every character of the offending text. -/
private def underline (s : String) : String :=
  s.foldl (fun acc c => (acc.push c).push '̲') ""

/-- The full message of an error, as KaTeX's `ParseError` builds it: `KaTeX parse error: `, the
raw message, and the position with fifteen characters of context on each side. -/
def KError.message : KError → String
  | .internal _ msg => msg
  | .parse raw loc =>
    let base := "KaTeX parse error: " ++ raw
    match loc with
    | .at l =>
      if l.start ≤ l.stop then
        let input := l.src.text
        let len := utf16Length input
        let pos := if l.start == len then " at end of input: "
          else s!" at position {l.start + 1}: "
        let left := if l.start > 15 then "…" ++ utf16Slice input (l.start - 15) l.start
          else utf16Slice input 0 l.start
        let right := if l.stop + 15 < len then utf16Slice input l.stop (l.stop + 15) ++ "…"
          else utf16Slice input l.stop len
        base ++ pos ++ left ++ underline (utf16Slice input l.start l.stop) ++ right
      else base
    | _ => base

/-- The position (UTF-16 offset) and length a `ParseError` reports, if it has a location. -/
def KError.position : KError → Option (Nat × Nat)
  | .parse _ (.at l) => if l.start ≤ l.stop then some (l.start, l.stop - l.start) else none
  | _ => none

/-- KaTeX's `strict` setting: what to do with input LaTeX would not accept. -/
inductive Strict where
  /-- Accept silently (`false`, `"ignore"`). -/
  | ignore
  /-- Accept with a warning (`"warn"`, the default). -/
  | warn
  /-- Reject (`true`, `"error"`). -/
  | error
  deriving BEq, Repr, Inhabited

/-- A strict-mode warning raised while parsing: KaTeX's full warning text. -/
abbrev Warning := String

/-- KaTeX's `handleStrict` with `report: true`: under `error` a `ParseError` (at `loc`), under
`warn` the warning text, under `ignore` nothing. -/
def strictReport (strict : Strict) (code msg : String) (loc : OLoc) :
    Except KError (Option Warning) :=
  match strict with
  | .error => throw (.parse ("LaTeX-incompatible input and strict mode is set to 'error': " ++
      s!"{msg} [{code}]") loc)
  | .warn => pure (some ("LaTeX-incompatible input and strict mode is set to 'warn': " ++
      s!"{msg} [{code}]"))
  | .ignore => pure none

/-- The options that affect parsing (KaTeX's `Settings`, minus the output-only ones). -/
structure Settings where
  /-- Display style (`displayMode`). -/
  displayMode : Bool := false
  /-- Equation numbers on the left (`leqno`). -/
  leqno : Bool := false
  /-- Flush-left display equations (`fleqn`). -/
  fleqn : Bool := false
  /-- Raise an error for an undefined command instead of rendering it in red. -/
  throwOnError : Bool := true
  /-- The colour of unsupported commands when `throwOnError` is off. -/
  errorColor : String := "#cc0000"
  /-- User macros: name and body (`macros`). -/
  macros : Array (String × String) := #[]
  /-- `\color` behaves as `\textcolor`. -/
  colorIsTextColor : Bool := false
  /-- The strict-mode behaviour. -/
  strict : Strict := .warn
  /-- Whether `\href`, `\url`, `\includegraphics` and the `\html…` commands are trusted. -/
  trust : Bool := false
  /-- The limit on macro expansions. -/
  maxExpand : Nat := 1000
  /-- Definitions at top level are global (`globalGroup`). -/
  globalGroup : Bool := false
  deriving Inhabited

end LeAnTeX
