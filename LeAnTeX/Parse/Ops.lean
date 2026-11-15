/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Parse.MacroExpander

/-!
# Parser primitives and the handler interface

The parts of KaTeX's `Parser` that do not recurse into the grammar — the lookahead token, mode
switches, the string, colour, size and URL arguments, single symbols — and the interface
through which function and environment handlers call back into the parser.

## Main definitions

* `fetch`, `consume`, `expect`, `consumeSpacesP`, `switchMode`: the lookahead token.
* `parseStringGroup`, `parseColorGroup`, `parseSizeGroup`, `parseUrlGroup`: typed arguments.
* `parseSymbol`, `formLigatures`, `formatUnsupportedCmd`.
* `Ops`, `Ctx`, `Handler`, `EnvCtx`, `EnvHandler`: what a handler receives.

## Implementation notes

KaTeX's handlers receive the parser object and call its methods; here they receive `Ops`, a
record of the parser's recursive functions, which `LeAnTeX.Parse.Parser` fills in. That keeps
the handlers in their own modules although the parser and the handlers call each other. The
regular expressions of the size and colour arguments are spelled out as small matchers.

## References

* KaTeX's `src/Parser.ts`, `src/units.ts`, `src/utils.ts` (`protocolFromUrl`) and
  `src/defineFunction.ts` (MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- The lookahead token, expanding macros to get one if there is none (KaTeX's `fetch`). -/
def fetch : M Token := do
  match (← get).nextToken with
  | some t => return t
  | none =>
    let t ← expandNextToken
    modify fun s => { s with nextToken := some t }
    return t

/-- Consume the lookahead token. -/
def consume : M Unit := modify fun s => { s with nextToken := none }

/-- Check that the lookahead token is `text` (an error otherwise) and consume it unless
`doConsume` is false. -/
def expect (text : String) (doConsume : Bool := true) : M Unit := do
  let t ← fetch
  if t.text != text then perrAt s!"Expected '{text}', got '{t.text}'" t
  if doConsume then consume

/-- Skip space tokens, expanding macros (the parser's `consumeSpaces`). -/
partial def consumeSpacesP : M Unit := do
  if (← fetch).text == " " then
    consume
    consumeSpacesP

/-- Switch between math and text mode. -/
def switchMode (m : Mode) : M Unit := modify fun s => { s with mode := m }

/-- The current mode. -/
def curMode : M Mode := return (← get).mode

/-- The settings. -/
def settings : M Settings := return (← get).settings

/-- The text of a braced (or, if `optional`, bracketed) argument, expanded, as one token with
the argument's location (KaTeX's `parseStringGroup`). -/
partial def parseStringGroup (optional : Bool) : M (Option Token) := do
  let some argToken ← scanArgument optional | return none
  let rec loop (str : String) : M String := do
    let t ← fetch
    if t.text == "EOF" then return str
    consume
    loop (str ++ t.text)
  let str ← loop ""
  consume
  return some { argToken with text := str }

/-- The character at an index, or NUL past the end (callers test the index first). -/
private def chAt (cs : Array Char) (i : Nat) : Char := cs.getD i '\x00'

/-- Whether `s` is a size as `parseRegexGroup` accepts it: `^[-+]? *(?:$|\d+|\d+\.\d*|\.\d*)
*[a-z]{0,2} *$`. -/
def isSizePrefix (s : String) : Bool := Id.run do
  let cs := s.toList.toArray
  let n := cs.size
  let mut i := 0
  if i < n && ((chAt cs i) == '-' || (chAt cs i) == '+') then i := i + 1
  while i < n && (chAt cs i) == ' ' do i := i + 1
  if i == n then return true
  if (chAt cs i).isDigit then
    while i < n && (chAt cs i).isDigit do i := i + 1
    if i < n && (chAt cs i) == '.' then
      i := i + 1
      while i < n && (chAt cs i).isDigit do i := i + 1
  else if (chAt cs i) == '.' then
    i := i + 1
    while i < n && (chAt cs i).isDigit do i := i + 1
  else return false
  while i < n && (chAt cs i) == ' ' do i := i + 1
  let mut k := 0
  while i < n && k < 2 && (chAt cs i) ≥ 'a' && (chAt cs i) ≤ 'z' do
    i := i + 1
    k := k + 1
  while i < n && (chAt cs i) == ' ' do i := i + 1
  return i == n

/-- The first match of `([-+]?) *(\d+(?:\.\d*)?|\.\d+) *([a-z]{2})` in `s`: sign, magnitude
and unit. -/
def matchSize (s : String) : Option (String × String × String) := Id.run do
  let cs := s.toList.toArray
  let n := cs.size
  let str (a b : Nat) : String := (cs.extract a b).foldl String.push ""
  for start in [0:n] do
    let mut i := start
    let mut sign := ""
    if (chAt cs i) == '-' || (chAt cs i) == '+' then
      sign := (chAt cs i).toString
      i := i + 1
    while i < n && (chAt cs i) == ' ' do i := i + 1
    let m0 := i
    if i < n && (chAt cs i).isDigit then
      while i < n && (chAt cs i).isDigit do i := i + 1
      if i < n && (chAt cs i) == '.' then
        i := i + 1
        while i < n && (chAt cs i).isDigit do i := i + 1
    else if i + 1 < n && (chAt cs i) == '.' && (chAt cs (i + 1)).isDigit then
      i := i + 1
      while i < n && (chAt cs i).isDigit do i := i + 1
    else continue
    let m1 := i
    while i < n && (chAt cs i) == ' ' do i := i + 1
    if i + 1 < n && 'a' ≤ chAt cs i && chAt cs i ≤ 'z' && 'a' ≤ chAt cs (i + 1) &&
        chAt cs (i + 1) ≤ 'z' then
      return some (sign, str m0 m1, str i (i + 2))
  return none

/-- JavaScript's `Number` of a decimal written as sign, digits, optional point and digits. -/
def decimalToFloat (s : String) : Float := Id.run do
  let (neg, body) := match s.toList with
    | '-' :: r => (true, r)
    | '+' :: r => (false, r)
    | r => (false, r)
  let ip := body.takeWhile (· != '.')
  let fp := (body.dropWhile (· != '.')).drop 1
  let digits := ip ++ fp
  let m := digits.foldl (fun acc c => acc * 10 + (c.toNat - '0'.toNat)) 0
  let v := Float.ofScientific m true fp.length
  return if neg then -v else v

/-- The units KaTeX accepts. -/
def validUnits : List String :=
  ["pt", "mm", "cm", "in", "bp", "pc", "dd", "cc", "nd", "nc", "sp", "px", "ex", "em", "mu"]

/-- A size argument (KaTeX's `parseSizeGroup`): a braced group, or for a mandatory argument the
longest run of tokens that still reads as a size. An empty mandatory argument is `0pt` with
`isBlank` set. -/
partial def parseSizeGroup (optional : Bool) : M (Option Node) := do
  consumeSpaces
  let res ← do
    if !optional && (← future).text != "{" then
      let first ← fetch
      let rec loop (last : Token) (str : String) : M (Token × String) := do
        let t ← fetch
        if t.text != "EOF" && isSizePrefix (str ++ t.text) then
          consume
          loop t (str ++ t.text)
        else return (last, str)
      let (last, str) ← loop first ""
      if str.isEmpty then perrAt s!"Invalid size: '{first.text}'" first
      pure (some (first.range last str))
    else parseStringGroup optional
  let some res := res | return none
  let mut res := res
  let mut isBlank := false
  if !optional && res.text.isEmpty then
    res := { res with text := "0pt" }
    isBlank := true
  let some (sign, mag, unit) := matchSize res.text | perrAt s!"Invalid size: '{res.text}'" res
  if !validUnits.contains unit then perrAt s!"Invalid unit: '{unit}'" res
  return some (.size (← curMode) .absent ⟨decimalToFloat (sign ++ mag), unit⟩ isBlank)

/-- Whether a character is an ASCII hex digit. -/
private def isHex (c : Char) : Bool :=
  c.isDigit || (c ≥ 'a' && c ≤ 'f') || (c ≥ 'A' && c ≤ 'F')

/-- A colour argument (KaTeX's `parseColorGroup`): `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`,
`rrggbb` (gets a `#`) or a name of letters. -/
def parseColorGroup (optional : Bool) : M (Option Node) := do
  let some res ← parseStringGroup optional | return none
  let cs := res.text.toList
  let ok := match cs with
    | '#' :: r => r.all isHex && (r.length == 3 || r.length == 4 || r.length == 6 ||
        r.length == 8)
    | r => (r.length == 6 && r.all isHex) ||
        (!r.isEmpty && r.all fun c => (c ≥ 'a' && c ≤ 'z') || (c ≥ 'A' && c ≤ 'Z'))
  if !ok then perrAt s!"Invalid color: '{res.text}'" res
  let color := if cs.length == 6 && cs.all isHex then "#" ++ res.text else res.text
  return some (.colorToken (← curMode) .absent color)

/-- A URL argument (KaTeX's `parseUrlGroup`): `%` is active and `~` ordinary while it is read,
and `\` before one of `#$%&~_^{}` is dropped. -/
def parseUrlGroup (optional : Bool) : M (Option Node) := do
  let lx := (← get).lexer
  let (pc, tc) := (lx.catcode "%", lx.catcode "~")
  modify fun s => { s with lexer := (s.lexer.setCatcode "%" 13).setCatcode "~" 12 }
  let res ← parseStringGroup optional
  let restored (cc : List (String × Nat)) : List (String × Nat) :=
    (match pc with | some c => [("%", c)] | none => []) ++
    (match tc with | some c => [("~", c)] | none => []) ++
    cc.filter (fun p => p.1 != "%" && p.1 != "~")
  modify fun s => { s with lexer := { s.lexer with catcodes := restored s.lexer.catcodes } }
  let some res := res | return none
  let rec unescape : List Char → List Char
    | '\\' :: c :: r =>
      if "#$%&~_^{}".contains c then c :: unescape r else '\\' :: unescape (c :: r)
    | c :: r => c :: unescape r
    | [] => []
  return some (.url (← curMode) .absent (String.ofList (unescape res.text.toList)))

/-- A raw argument: spaces skipped, then the text with `%` an ordinary character. -/
def parseRawGroup (optional : Bool) : M (Option Node) := do
  consumeSpaces
  let pc := (← get).lexer.catcode "%"
  modify fun s => { s with lexer := s.lexer.setCatcode "%" 12 }
  let tok ← parseStringGroup optional
  modify fun s => { s with lexer := match pc with
    | some c => s.lexer.setCatcode "%" c
    | none => { s.lexer with catcodes := s.lexer.catcodes.filter (·.1 != "%") } }
  return tok.map fun t => .raw .text .absent t.text

/-- The red text KaTeX shows for an undefined command when `throwOnError` is off. -/
def formatUnsupportedCmd (text : String) : M Node := do
  let m ← curMode
  let ords := text.toList.toArray.map fun c => Node.sym .text .absent .textord c.toString
  return .color m .absent (← settings).errorColor #[.text m .absent ords none]

/-- The protocol of a URL, `_relative` without one, `none` for a malformed one (KaTeX's
`protocolFromUrl`). -/
def protocolFromUrl (url : String) : Option String := Id.run do
  let cs := url.toList.dropWhile (fun c => c.val ≤ 0x20)
  let lower := cs.map Char.toLower
  -- the shortest scheme candidate before a colon or an encoded colon
  let mut i := 0
  let n := cs.length
  while i < n do
    let c := (cs.getD i (Char.ofNat 0))
    if c == '\\' || c == '/' || c == '#' || c == '?' then return "_relative"
    let rest := lower.drop i
    if c == ':' then
      let scheme := String.ofList (cs.take i)
      let ok := match scheme.toList with
        | f :: r => f.isAlpha && r.all fun d => d.isAlphanum || d == '+' || d == '-' || d == '.'
        | [] => false
      return if ok then some scheme.toLower else none
    let encoded :=
      (rest.take 2 == ['&', '#'] && ((rest.drop 2).dropWhile (· == '0')).take 2 == ['5', '8'])
      || (rest.take 3 == ['&', '#', 'x'] && ((rest.drop 3).dropWhile (· == '0')).take 2 ==
        ['3', 'a'])
      || rest.take 6 == "&colon".toList
    if encoded then return none
    i := i + 1
  return "_relative"

/-- Whether a command with a URL (or none) is trusted (KaTeX's `Settings.isTrusted`). -/
def isTrusted (url : Option String) : M Bool := do
  if let some u := url then
    if !u.isEmpty && (protocolFromUrl u).isNone then return false
  return (← settings).trust

/-- Text-mode ligatures (`--`, `---`, ` `` `, `''`) merged into one `textord`, in place
(KaTeX's `formLigatures`). -/
def formLigatures (group : Array Node) : Array Node := Id.run do
  let mut g := group
  let mut n : Int := g.size - 1
  let mut i : Int := 0
  let txt (k : Int) (g : Array Node) : Option (String × OLoc) :=
    if k < 0 then none else match g[k.toNat]? with
      | some (.sym _ l .textord t) => some (t, l)
      | _ => none
  while i < n do
    match txt i g, txt (i + 1) g with
    | some (v, la), some (w, lb) =>
      if v == "-" && w == "-" then
        match txt (i + 2) g with
        | some ("-", lc) =>
          if i + 1 < n then
            let node := Node.sym .text (OLoc.range la lc) .textord "---"
            g := (g.extract 0 i.toNat).push node ++ g.extract (i.toNat + 3) g.size
            n := n - 2
          else
            let node := Node.sym .text (OLoc.range la lb) .textord "--"
            g := (g.extract 0 i.toNat).push node ++ g.extract (i.toNat + 2) g.size
            n := n - 1
        | _ =>
          let node := Node.sym .text (OLoc.range la lb) .textord "--"
          g := (g.extract 0 i.toNat).push node ++ g.extract (i.toNat + 2) g.size
          n := n - 1
      -- `next` is still the node read before the splice, as in KaTeX
      if (v == "'" || v == "`") && w == v then
        let node := Node.sym .text (OLoc.range la lb) .textord (v ++ v)
        g := (g.extract 0 i.toNat).push node ++ g.extract (i.toNat + 2) g.size
        n := n - 1
    | _, _ => pure ()
    i := i + 1
  return g

/-- What a function handler receives about the call. -/
structure Ctx where
  /-- The function's name. -/
  funcName : String
  /-- The token that named it, if it came from the input. -/
  token : Option Token := none
  /-- The token that ends the enclosing expression, if any. -/
  breakOnTokenText : Option String := none

/-- The argument properties `parseArguments` needs, shared by functions and environments. -/
structure ArgSpec where
  /-- Mandatory arguments. -/
  numArgs : Nat
  /-- Optional arguments (first). -/
  numOptionalArgs : Nat := 0
  /-- Argument types, when given. -/
  argTypes : Array ArgType := #[]
  /-- A primitive: untyped arguments are primitive groups. -/
  isPrimitive : Bool := false
  /-- `\sqrt`: without its optional argument the body is a primitive group. -/
  isSqrt : Bool := false

/-- The parser's recursive functions, as handlers call them. -/
structure Ops where
  /-- `parseExpression breakOnInfix breakOnTokenText`. -/
  parseExpression : Bool → Option String → M (Array Node)
  /-- `parseFunction breakOnTokenText name`. -/
  parseFunction : Option String → Option String → M (Option Node)
  /-- `parseArguments funcName spec`. -/
  parseArguments : String → ArgSpec → M (Array Node × Array (Option Node))
  /-- `callFunction name args optArgs token breakOnTokenText`. -/
  callFunction : String → Array Node → Array (Option Node) → Option Token → Option String →
    M Node
  /-- `subparse tokens`: parse a token list (in reverse order) as a separate expression. -/
  subparse : Array Token → M (Array Node)
  deriving Inhabited

/-- A function handler. -/
abbrev Handler := Ops → Ctx → Array Node → Array (Option Node) → M Node

/-- The argument at an index of a handler's argument array; the parser passes as many arguments as
the function's specification declares, so a missing one is an internal error. -/
def argAt (args : Array Node) (i : Nat) : M Node :=
  match args[i]? with
  | some a => pure a
  | none => ierr s!"internal: missing argument {i}"

/-- What an environment handler receives. -/
structure EnvCtx where
  /-- The mode at `\begin`. -/
  mode : Mode
  /-- The environment's name. -/
  envName : String

/-- An environment handler. -/
abbrev EnvHandler := Ops → EnvCtx → Array Node → Array (Option Node) → M Node

/-- Raise KaTeX's `assertNodeType` error for a node of the wrong type. -/
def wrongNode {α : Type} (expected : String) (n : Option Node) : M α :=
  ierr (s!"Expected node of type {expected}, but got " ++
    (match n with | some n => s!"node of type {n.type}" | none => "undefined"))

/-- The text of a group of plain characters, or the given `ParseError` at the group (KaTeX's
`assertCharacterGroup`); with `allowSpaces`, a literal space counts. -/
def assertCharacterGroup (group : Node) (msg : String) (allowSpaces : Bool := false) :
    M String := do
  match group with
  | .ordgroup _ _ body _ =>
    let mut s := ""
    for n in body do
      match n with
      | .sym _ _ .textord t => s := s ++ t
      | .sym _ _ .spacing " " => if allowSpaces then s := s ++ " " else perrLoc msg group.loc
      | _ => perrLoc msg group.loc
    return s
  | n => wrongNode "ordgroup" (some n)

end LeAnTeX
