/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Parse.Lexer
import LeAnTeX.Parse.Node
import LeAnTeX.Parse.Tables

/-!
# Parser state

The state the macro expander and the parser share while parsing one formula, and the monad
they run in: the main lexer, the token stack, the macro namespace with its group nesting, the
expansion count, the mode, the lookahead token and the strict-mode warnings.

## Main definitions

* `MacroDef`: a macro definition (string, token list, built-in function, or the closures the
  `braket` macros install).
* `Namespace`: macro definitions with TeX's grouping (`beginGroup`, `endGroup`, global set).
* `State`, `M`: the state and the monad (`EStateM` with `KError`).

## Implementation notes

KaTeX's macro expander and parser are two objects that share one lexer; here they are one state
record, and the parser's `mode` is the expander's mode (KaTeX keeps the two equal). Macro
definitions that KaTeX implements as JavaScript closures are data: `native` names a built-in,
`braketMid` carries what `braketHelper`'s inner closure captures.

## References

* KaTeX's `src/Namespace.ts`, `src/defineMacro.ts`, `src/MacroExpander.ts` and `src/Parser.ts`
  (MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

open Std

/-- A macro definition. -/
inductive MacroDef where
  /-- A string body, lexed at each expansion; `#1`…`#9` are its parameters. -/
  | str (body : String)
  /-- A token list (in reverse order), with the parameter count, the delimiters of a `\def`
  parameter text, and whether `\let` made it unexpandable. -/
  | exp (tokens : Array Token) (numArgs : Nat) (delimiters : Option (Array (Array String)))
      (unexpandable : Bool)
  /-- A built-in macro KaTeX implements as a function, by name. -/
  | native (name : String)
  /-- The `|` (or `\|`) macro installed by `\bra@ket` / `\bra@set`. -/
  | braketMid (one : Bool) (double : Bool) (middle : Array Token) (middleDouble : Array Token)
      (oldMiddle : Option MacroDef) (oldMiddleDouble : Option MacroDef)
  deriving Inhabited

/-- Whether a definition counts as true in JavaScript (`if (macros.get(name))`): anything but
the empty string. -/
def MacroDef.truthy : MacroDef → Bool
  | .str s => !s.isEmpty
  | _ => true

/-- Macro definitions with TeX grouping (KaTeX's `Namespace`). -/
structure Namespace where
  /-- The current definitions (user macros and every definition made while parsing). -/
  current : HashMap String MacroDef := {}
  /-- Per open group, the values to restore at its end (`none`: delete). -/
  undefStack : Array (HashMap String (Option MacroDef)) := #[]
  deriving Inhabited

namespace Namespace

/-- The built-in definition of a name. -/
def builtin (name : String) : Option MacroDef :=
  match Tables.builtinStringMacros[name]? with
  | some body => some (.str body)
  | none => if Tables.nativeMacros.contains name then some (.native name) else none

/-- The current definition of a name. -/
def get (ns : Namespace) (name : String) : Option MacroDef :=
  ns.current[name]?.orElse fun _ => builtin name

/-- Whether a name has a definition. -/
def has (ns : Namespace) (name : String) : Bool := (ns.get name).isSome

/-- Open a group. -/
def beginGroup (ns : Namespace) : Namespace := { ns with undefStack := ns.undefStack.push {} }

/-- Close a group, restoring the definitions it changed; an error at top level. -/
def endGroup (ns : Namespace) : Except KError Namespace := do
  match ns.undefStack.back? with
  | none => throw (.parse ("Unbalanced namespace destruction: attempt to pop global " ++
      "namespace; please report this as a bug") .absent)
  | some undefs =>
    let cur := undefs.fold (init := ns.current) fun cur k v =>
      match v with
      | none => cur.erase k
      | some d => cur.insert k d
    return { current := cur, undefStack := ns.undefStack.pop }

/-- Close every open group. -/
def endGroups (ns : Namespace) : Namespace :=
  ns.undefStack.foldr (init := { ns with undefStack := #[] }) fun undefs acc =>
    { acc with current := undefs.fold (init := acc.current) fun cur k v =>
        match v with
        | none => cur.erase k
        | some d => cur.insert k d }

/-- Set (or with `none` delete) a definition, locally or globally (KaTeX's `Namespace.set`). -/
def set (ns : Namespace) (name : String) (value : Option MacroDef) (global : Bool := false) :
    Namespace :=
  let stack :=
    if global then
      let st := ns.undefStack.map (·.erase name)
      if st.isEmpty then st else st.modify (st.size - 1) (·.insert name value)
    else
      match ns.undefStack.back? with
      | some top =>
        if top.contains name then ns.undefStack
        else ns.undefStack.modify (ns.undefStack.size - 1) (·.insert name ns.current[name]?)
      | none => ns.undefStack
  let cur := match value with
    | none => ns.current.erase name
    | some v => ns.current.insert name v
  { current := cur, undefStack := stack }

end Namespace

/-- The shared state of the expander and the parser while parsing one formula. -/
structure State where
  /-- The options. -/
  settings : Settings
  /-- The lexer of the formula. -/
  lexer : Lexer
  /-- The next free source id (each macro body lexed gets one). -/
  nextSrcId : Nat := 1
  /-- Tokens pushed back or produced by expansion, top at the end. -/
  stack : Array Token := #[]
  /-- The macro definitions. -/
  macros : Namespace := {}
  /-- Expansions so far, against `Settings.maxExpand`. -/
  expansionCount : Nat := 0
  /-- Tokens the expansions produced so far, against `Settings.maxTokens`. -/
  tokenCount : Nat := 0
  /-- The current mode. -/
  mode : Mode := .math
  /-- The nesting depth of `\left`, for `\middle`. -/
  leftrightDepth : Nat := 0
  /-- The parser's lookahead token. -/
  nextToken : Option Token := none
  /-- The strict-mode warnings raised so far. -/
  warnings : Array Warning := #[]
  deriving Inhabited

/-- The monad of the expander and the parser. -/
abbrev M := EStateM KError State

/-- Raise a `ParseError` with no location. -/
def perr {α : Type} (msg : String) : M α := throw (.parse msg .absent)

/-- Raise a `ParseError` at a token. -/
def perrAt {α : Type} (msg : String) (tok : Token) : M α := throw (.parse msg tok.loc)

/-- Raise a `ParseError` at a location. -/
def perrLoc {α : Type} (msg : String) (loc : OLoc) : M α := throw (.parse msg loc)

/-- Raise an error KaTeX raises as a plain JavaScript `Error`. -/
def ierr {α : Type} (msg : String) : M α := throw (.internal "Error" msg)

/-- Run an `Except` computation in `M`. -/
def liftE {α : Type} (x : Except KError α) : M α :=
  match x with
  | .ok a => pure a
  | .error e => throw e

/-- KaTeX's `handleStrict` with `report: true`, at `loc`. -/
def reportStrict (code msg : String) (loc : OLoc := .absent) : M Unit := do
  let w ← liftE (strictReport (← get).settings.strict code msg loc)
  if let some w := w then modify fun s => { s with warnings := s.warnings.push w }

/-- KaTeX's `handleStrict` with `report: false`: whether to apply LaTeX's strict behaviour
(only under `error`; `warn` warns and says no). -/
def useStrictBehavior (code msg : String) : M Bool := do
  match (← get).settings.strict with
  | .error => return true
  | .ignore => return false
  | .warn =>
    let w := "LaTeX-incompatible input and strict mode is set to 'warn': " ++ s!"{msg} [{code}]"
    modify fun s => { s with warnings := s.warnings.push w }
    return false

/-- Update the macro namespace. -/
def modifyMacros (f : Namespace → Namespace) : M Unit :=
  modify fun s => { s with macros := f s.macros }

/-- Set a macro (KaTeX's `macros.set`). -/
def setMacro (name : String) (value : Option MacroDef) (global : Bool := false) : M Unit :=
  modifyMacros (·.set name value global)

/-- The current definition of a macro. -/
def getMacro (name : String) : M (Option MacroDef) := return (← get).macros.get name

/-- Open a macro group. -/
def beginGroup : M Unit := modifyMacros Namespace.beginGroup

/-- Close a macro group. -/
def endGroup : M Unit := do
  let ns ← liftE (← get).macros.endGroup
  modify fun s => { s with macros := ns }

/-- Close every macro group. -/
def endGroups : M Unit := modifyMacros Namespace.endGroups

/-- A fresh source for a macro body or other text lexed separately. -/
def freshSource (text : String) : M Source := do
  let s ← get
  set { s with nextSrcId := s.nextSrcId + 1 }
  return ⟨s.nextSrcId, text⟩

end LeAnTeX
