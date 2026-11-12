/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/

/-!
# Table entry types

The shapes of the entries in KaTeX's tables, as the generated modules under `LeAnTeX.Data` list
them: functions, environments and symbols, and the small enumerations they use.

## Main definitions

* `Mode`: math or text mode.
* `ArgType`: how a function argument is parsed.
* `Group`, `Font`, `SymbolInfo`: a symbol's class, font and replacement character.
* `FunctionSpec`, `EnvSpec`: the parsing properties of a function or an environment.

## References

* KaTeX's `src/defineFunction.ts`, `src/defineEnvironment.ts`, `src/symbols.ts` and
  `src/types/index.ts` (MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- The parser's mode: math (the default) or text (inside `\text` and friends). -/
inductive Mode where
  /-- Math mode. -/
  | math
  /-- Text mode. -/
  | text
  deriving BEq, Repr, Inhabited, DecidableEq

/-- KaTeX's name of a mode (`"math"` or `"text"`). -/
def Mode.name : Mode → String
  | .math => "math"
  | .text => "text"

/-- How a function's argument is parsed (KaTeX's `ArgType`). -/
inductive ArgType where
  /-- A colour name or HTML colour. -/
  | color
  /-- A dimension such as `1em`. -/
  | size
  /-- A URL, with `\` escapes. -/
  | url
  /-- Raw text, with `%` an ordinary character. -/
  | raw
  /-- The mode the function itself is in. -/
  | original
  /-- Text, wrapped as `\hbox` (text style, math font reset). -/
  | hbox
  /-- A single group, as a TeX primitive takes it. -/
  | primitive
  /-- Math mode. -/
  | math
  /-- Text mode. -/
  | text
  deriving BEq, Repr, Inhabited

/-- A symbol's group: one of the six atom classes or one of the five ordinary kinds. -/
inductive Group where
  /-- Binary operator atom. -/
  | bin
  /-- Closing delimiter atom. -/
  | close
  /-- Inner atom. -/
  | inner
  /-- Opening delimiter atom. -/
  | «open»
  /-- Punctuation atom. -/
  | punct
  /-- Relation atom. -/
  | rel
  /-- An accent character. -/
  | accentToken
  /-- An ordinary math symbol (italic letters). -/
  | mathord
  /-- A large operator character. -/
  | opToken
  /-- A spacing command. -/
  | spacing
  /-- An ordinary symbol (upright). -/
  | textord
  deriving BEq, Repr, Inhabited, DecidableEq

/-- KaTeX's name of a group (`"rel"`, `"accent-token"`, `"mathord"`, …). -/
def Group.name : Group → String
  | .bin => "bin"
  | .close => "close"
  | .inner => "inner"
  | .open => "open"
  | .punct => "punct"
  | .rel => "rel"
  | .accentToken => "accent-token"
  | .mathord => "mathord"
  | .opToken => "op-token"
  | .spacing => "spacing"
  | .textord => "textord"

/-- Whether the group is an atom class (its parse node has type `atom`). -/
def Group.isAtom : Group → Bool
  | .bin | .close | .inner | .open | .punct | .rel => true
  | _ => false

/-- The font family a symbol is drawn from. -/
inductive Font where
  /-- KaTeX's Main fonts. -/
  | main
  /-- KaTeX's AMS fonts. -/
  | ams
  deriving BEq, Repr, Inhabited

/-- A symbol table entry: font, group and the character drawn (when it differs from the name). -/
structure SymbolInfo where
  /-- The font. -/
  font : Font
  /-- The group. -/
  group : Group
  /-- The character drawn for the symbol, if any. -/
  replace : Option String
  deriving Repr, Inhabited

/-- The parsing properties of a KaTeX function (`FunctionSpec` in `defineFunction.ts`). -/
structure FunctionSpec where
  /-- The parse node type the handler produces. -/
  type : String
  /-- The number of mandatory arguments. -/
  numArgs : Nat
  /-- The number of optional (bracketed) arguments, which come first. -/
  numOptionalArgs : Nat := 0
  /-- The argument types, optional arguments first; empty when KaTeX gives none. -/
  argTypes : Array ArgType := #[]
  /-- Whether the function may stand alone as an argument of a primitive. -/
  allowedInArgument : Bool := false
  /-- Whether the function is allowed in text mode. -/
  allowedInText : Bool := false
  /-- Whether the function is allowed in math mode. -/
  allowedInMath : Bool := true
  /-- Whether the function is an infix operator (`\over`). -/
  isInfix : Bool := false
  /-- Whether the function is a TeX primitive (its arguments are parsed as primitives). -/
  isPrimitive : Bool := false
  /-- Whether KaTeX gives it a handler. -/
  hasHandler : Bool := true
  /-- The key of the handler: the first name of the definition that defines the function. -/
  handler : String
  deriving Repr, Inhabited

/-- The parsing properties of a KaTeX environment (`EnvSpec` in `defineEnvironment.ts`). -/
structure EnvSpec where
  /-- The parse node type the handler produces. -/
  type : String
  /-- The number of mandatory arguments after `\begin{name}`. -/
  numArgs : Nat
  /-- The number of optional arguments. -/
  numOptionalArgs : Nat := 0
  /-- The argument types; empty when KaTeX gives none. -/
  argTypes : Array ArgType := #[]
  /-- Whether the environment is allowed in text mode. -/
  allowedInText : Bool := false
  /-- The key of the handler: the first name of the definition. -/
  handler : String
  deriving Repr, Inhabited

end LeAnTeX
