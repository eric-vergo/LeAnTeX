/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Parse.State

/-!
# Macro expander

TeX's "gullet" as KaTeX implements it: a stack of tokens over the lexer, macro arguments
(undelimited, delimited, optional), one-step and full expansion with the expansion limit, and
KaTeX's built-in macros that are functions rather than strings (`\noexpand`, `\expandafter`,
`\@ifnextchar`, `\char`, `\newcommand`, the `\dots` family, `\tag@literal`, `\bra@ket`, …).

## Main definitions

* `future`, `popToken`, `pushToken`, `consumeSpaces`, `consumeArg`, `consumeArgs`,
  `scanArgument`: the token stack and argument scanning.
* `expandOnce`, `expandNextToken`, `expandTokens`, `expandMacroAsText`: expansion.
* `isDefined`, `isExpandable`: what a control sequence means.

## Implementation notes

The token stack holds tokens in reverse order (the next token last), as KaTeX's does; so do the
token lists of `MacroDef.exp`. The function-valued macros are interpreted by `runNative` inside
the expansion's mutual recursion, since they themselves expand and consume tokens. KaTeX's
`\message`, `\errmessage` and `\show` print to the console; here they consume their argument
and print nothing.

## References

* KaTeX's `src/MacroExpander.ts` and `src/macros.ts` (MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

open Std

/-- Commands that act like macros without being defined as one (`implicitCommands`). -/
def implicitCommands : List String := ["^", "_", "\\limits", "\\nolimits"]

/-- The top token of the stack, lexing one if the stack is empty (KaTeX's `future`). -/
def future : M Token := do
  let s ← get
  match s.stack.back? with
  | some t => return t
  | none =>
    let (tok, lx, w) ← liftE (s.lexer.lex s.settings.strict)
    let ws := match w with | some w => s.warnings.push w | none => s.warnings
    set { s with lexer := lx, stack := s.stack.push tok, warnings := ws }
    return tok

/-- Remove and return the next unexpanded token. -/
def popToken : M Token := do
  let t ← future
  modify fun s => { s with stack := s.stack.pop }
  return t

/-- Push a token back. -/
def pushToken (t : Token) : M Unit := modify fun s => { s with stack := s.stack.push t }

/-- Push a token list (in reverse order) onto the stack. -/
def pushTokens (ts : Array Token) : M Unit := modify fun s => { s with stack := s.stack ++ ts }

/-- Drop space tokens without expanding anything. -/
partial def consumeSpaces : M Unit := do
  if (← future).text == " " then
    modify fun s => { s with stack := s.stack.pop }
    consumeSpaces

/-- One macro argument: its tokens in reverse order, and the first and last token read. An
undelimited argument is the next non-space token or a braced group (without the braces); a
delimited one runs to the delimiter list `delims` at brace depth zero. -/
partial def consumeArg (delims : Option (Array String) := none) :
    M (Array Token × Token × Token) := do
  let isDelimited := match delims with | some d => d.size > 0 | none => false
  let ds := delims.getD #[]
  if !isDelimited then consumeSpaces
  let start ← future
  let rec loop (tokens : Array Token) (depth : Int) (matched : Nat) :
      M (Array Token × Token) := do
    let tok ← popToken
    let tokens := tokens.push tok
    let mut depth := depth
    if tok.text == "{" then depth := depth + 1
    else if tok.text == "}" then
      depth := depth - 1
      if depth == -1 then perrAt "Extra }" tok
    else if tok.text == "EOF" then
      let expected := if isDelimited then ds.getD matched "" else "}"
      perrAt ("Unexpected end of input in a macro argument, expected '" ++ expected ++ "'") tok
    let mut matched := matched
    let mut tokens := tokens
    if isDelimited then
      let d := ds.getD matched ""
      if (depth == 0 || (depth == 1 && d == "{")) && tok.text == d then
        matched := matched + 1
        if matched == ds.size then
          tokens := tokens.extract 0 (tokens.size - matched)
          return (tokens, tok)
      else matched := 0
    if depth != 0 || isDelimited then loop tokens depth matched else return (tokens, tok)
  let (tokens, last) ← loop #[] 0 0
  let tokens :=
    if start.text == "{" && tokens.back?.map (·.text) == some "}" then
      (tokens.pop).extract 1 tokens.size
    else tokens
  return (tokens.reverse, start, last)

/-- The arguments of a macro with `numArgs` parameters and, for a `\def` with a parameter text,
its delimiters (`delimiters[0]` precedes the first argument). -/
def consumeArgs (numArgs : Nat) (delimiters : Option (Array (Array String)) := none) :
    M (Array (Array Token)) := do
  if let some ds := delimiters then
    if ds.size != numArgs + 1 then
      perr "The length of delimiters doesn't match the number of args!"
    for d in ds.getD 0 #[] do
      let tok ← popToken
      if d != tok.text then perrAt "Use of the macro doesn't match its definition" tok
  let mut args := #[]
  for i in [0:numArgs] do
    let (ts, _, _) ← consumeArg (delimiters.map (·.getD (i + 1) #[]))
    args := args.push ts
  return args

/-- Scan an argument without expanding it and push its tokens back followed by an end marker,
so the parser reads it as a separate stream ending in `EOF`. Returns a token spanning the
argument, or `none` for an absent optional argument. -/
def scanArgument (isOptional : Bool) : M (Option Token) := do
  let mut tokens := #[]
  let mut start : Token := default
  let mut stop : Token := default
  if isOptional then
    consumeSpaces
    if (← future).text != "[" then return none
    start ← popToken
    let (ts, _, e) ← consumeArg (some #["]"])
    tokens := ts
    stop := e
  else
    let (ts, s, e) ← consumeArg
    tokens := ts
    start := s
    stop := e
  pushToken { text := "EOF", loc := stop.loc }
  pushTokens tokens
  return some { text := "", loc := OLoc.range start.loc stop.loc }

/-- Count `n` expansions; an error past `maxExpand`. -/
def countExpansion (n : Nat) : M Unit := do
  let s ← get
  set { s with expansionCount := s.expansionCount + n }
  if s.expansionCount + n > s.settings.maxExpand then
    perr "Too many expansions: infinite loop or need to increase maxExpand setting"

/-- Count `n` tokens produced by an expansion; an error past `maxTokens`. -/
def countTokens (n : Nat) : M Unit := do
  let s ← get
  set { s with tokenCount := s.tokenCount + n }
  if let some mx := s.settings.maxTokens then
    if s.tokenCount + n > mx then
      perr s!"Too many tokens: the macros expand to more than {mx} tokens (maxTokens setting)"

/-- Whether a command has a meaning: a macro, a function, a symbol or an implicit command. -/
def isDefined (name : String) : M Bool := do
  return (← get).macros.has name || Tables.functions.contains name ||
    Tables.mathSymbols.contains name || Tables.textSymbols.contains name ||
    implicitCommands.contains name

/-- Whether a command is expandable: a macro not made unexpandable by `\let`, or a function
that is not a primitive. -/
def isExpandable (name : String) : M Bool := do
  match (← get).macros.get name with
  | some (.exp _ _ _ unexpandable) => return !unexpandable
  | some _ => return true
  | none => return (Tables.functions[name]?.map (!·.isPrimitive)).getD false

/-- An expansion: tokens in reverse order, the parameter count, the `\def` delimiters, and
whether it is unexpandable. -/
structure Expansion where
  /-- The tokens, in reverse order. -/
  tokens : Array Token
  /-- The number of parameters. -/
  numArgs : Nat
  /-- The delimiters of a `\def` parameter text. -/
  delimiters : Option (Array (Array String)) := none
  /-- Set by `\let` for a non-expandable meaning. -/
  unexpandable : Bool := false

/-- What a macro function returns: a string body or a ready expansion. -/
inductive NativeResult where
  /-- A string, lexed like a string macro. -/
  | str (s : String)
  /-- A token expansion. -/
  | exp (e : Expansion)

/-- The tokens after which `\dots` becomes `\dotsc`, `\dotsb` or `\dotsi`
(amsmath's `\mdots@@`, as KaTeX's `dotsByToken`). -/
private def dotsByToken : HashMap String String := HashMap.ofList <|
  [(",", "\\dotsc"), ("\\not", "\\dotsb")] ++
  (["+", "=", "<", ">", "-", "*", ":", "\\DOTSB", "\\coprod", "\\bigvee", "\\bigwedge",
    "\\biguplus", "\\bigcap", "\\bigcup", "\\prod", "\\sum", "\\bigotimes", "\\bigoplus",
    "\\bigodot", "\\bigsqcup", "\\And", "\\longrightarrow", "\\Longrightarrow",
    "\\longleftarrow", "\\Longleftarrow", "\\longleftrightarrow", "\\Longleftrightarrow",
    "\\mapsto", "\\longmapsto", "\\hookrightarrow", "\\doteq", "\\mathbin", "\\mathrel",
    "\\relbar", "\\Relbar", "\\xrightarrow", "\\xleftarrow"].map (·, "\\dotsb")) ++
  (["\\DOTSI", "\\int", "\\oint", "\\iint", "\\iiint", "\\iiiint", "\\idotsint"].map
    (·, "\\dotsi")) ++
  [("\\DOTSX", "\\dotsx")]

/-- The tokens after which the `\dots` macros add a thin space (KaTeX's `spaceAfterDots`). -/
private def spaceAfterDots : List String :=
  [")", "]", "\\rbrack", "\\}", "\\rbrace", "\\rangle", "\\rceil", "\\rfloor", "\\rgroup",
    "\\rmoustache", "\\right", "\\bigr", "\\biggr", "\\Bigr", "\\Biggr", "$", ";", ".", ","]

/-- The value of a digit in bases up to 16 (KaTeX's `digitToNumber`). -/
private def digitToNumber (s : String) : Option Nat :=
  match s.toList with
  | [c] =>
    if c ≥ '0' && c ≤ '9' then some (c.toNat - '0'.toNat)
    else if c ≥ 'a' && c ≤ 'f' then some (c.toNat - 'a'.toNat + 10)
    else if c ≥ 'A' && c ≤ 'F' then some (c.toNat - 'A'.toNat + 10)
    else none
  | _ => none

/-- JavaScript's `charCodeAt(i)`: the UTF-16 code unit at index `i`, or `none`. -/
def charCodeAt (s : String) (i : Nat) : Option Nat := Id.run do
  let mut pos := 0
  for c in s.toList do
    if c.val ≥ 0x10000 then
      let v := c.val.toNat - 0x10000
      if pos == i then return some (0xD800 + v / 0x400)
      if pos + 1 == i then return some (0xDC00 + v % 0x400)
      pos := pos + 2
    else
      if pos == i then return some c.val.toNat
      pos := pos + 1
  return none

/-- JavaScript's `\s`: whitespace and line terminators. -/
def isJsSpace (c : Char) : Bool :=
  c == ' ' || c == '\t' || c == '\n' || c == '\r' || c.val == 0x0B || c.val == 0x0C ||
    c.val == 0xA0 || c.val == 0x1680 || (c.val ≥ 0x2000 && c.val ≤ 0x200A) ||
    c.val == 0x2028 || c.val == 0x2029 || c.val == 0x202F || c.val == 0x205F ||
    c.val == 0x3000 || c.val == 0xFEFF

/-- The number of parameters of a string macro body: `#1`, `#2`, … in order, ignoring `##`. -/
private def countParams (body : String) : Nat := Id.run do
  if !body.contains '#' then return 0
  let stripped := body.replace "##" ""
  let mut n := 0
  while (stripped.splitOn s!"#{n + 1}").length > 1 do
    n := n + 1
  return n

/-- The function-valued built-in macros `runNative` implements. -/
def implementedNatives : List String :=
  ["\\noexpand", "\\expandafter", "\\@firstoftwo", "\\@secondoftwo", "\\@ifnextchar",
    "\\TextOrMath", "\\char", "\\newcommand", "\\renewcommand", "\\providecommand",
    "\\message", "\\errmessage", "\\show", "\\dots", "\\dotso", "\\dotsc", "\\cdots",
    "\\tag@literal", "\\bra@ket", "\\bra@set"]

mutual

/-- The expansion of a macro name, or `none` if it is not a macro here (KaTeX's
`_getExpansion`): string bodies are lexed afresh, function macros run. A single character with
a category code other than 13 (active) never expands. -/
partial def getExpansion (name : String) : M (Option Expansion) := do
  let some d ← getMacro name | return none
  if utf16Length name == 1 then
    if let some c := (← get).lexer.catcode name then
      if c != 13 then return none
  let r ← match d with
    | .str s => pure (NativeResult.str s)
    | .exp tokens numArgs delims unexp => pure (.exp ⟨tokens, numArgs, delims, unexp⟩)
    | .native n => runNative n
    | .braketMid one dbl middle middleDouble oldM oldMD =>
      runBraketMid one dbl middle middleDouble oldM oldMD
  match r with
  | .exp e => return some e
  | .str body =>
    let src ← freshSource body
    let (tokens, ws) ← liftE (lexAll src (← get).settings.strict)
    modify fun s => { s with warnings := s.warnings ++ ws }
    return some { tokens := tokens.reverse, numArgs := countParams body }

/-- Expand the next token once if it is a macro (KaTeX's `expandOnce`). Returns the number of
tokens the expansion pushed, or `none` (the token stays on the stack) if it does not expand;
with `expandableOnly`, an unexpandable macro does not expand and an undefined control sequence
is an error. -/
partial def expandOnce (expandableOnly : Bool := false) : M (Option Nat) := do
  let top ← popToken
  let name := top.text
  let expansion ← if !top.noexpand then getExpansion name else pure none
  let blocked := match expansion with
    | none => true
    | some e => expandableOnly && e.unexpandable
  if blocked then
    if expandableOnly && expansion.isNone && name.startsWith "\\" && !(← isDefined name) then
      perr s!"Undefined control sequence: {name}"
    pushToken top
    return none
  let some e := expansion | return none
  countExpansion 1
  let args ← consumeArgs e.numArgs e.delimiters
  let mut tokens := e.tokens
  if e.numArgs > 0 then
    let mut i : Int := tokens.size - 1
    while i ≥ 0 do
      let some tok := tokens[i.toNat]? | ierr "internal: macro body index out of range"
      if tok.text == "#" then
        if i == 0 then perrAt "Incomplete placeholder at end of macro body" tok
        i := i - 1
        let some tok := tokens[i.toNat]? | ierr "internal: macro body index out of range"
        if tok.text == "#" then
          tokens := tokens.extract 0 (i.toNat + 1) ++ tokens.extract (i.toNat + 2) tokens.size
        else
          match tok.text.toList with
          | [c] =>
            if c ≥ '1' && c ≤ '9' then
              let arg := args[c.toNat - '1'.toNat]?.getD #[]
              tokens := tokens.extract 0 i.toNat ++ arg ++ tokens.extract (i.toNat + 2) tokens.size
            else perrAt "Not a valid argument number" tok
          | _ => perrAt "Not a valid argument number" tok
      i := i - 1
  countTokens tokens.size
  pushTokens tokens
  return some tokens.size

/-- Expand once and return the top token (KaTeX's `expandAfterFuture`). -/
partial def expandAfterFuture : M Token := do
  let _ ← expandOnce
  future

/-- Expand until the next token does not expand and return it; a token marked by `\noexpand`
reads as `\relax` (KaTeX's `expandNextToken`). -/
partial def expandNextToken : M Token := do
  match ← expandOnce with
  | some _ => expandNextToken
  | none =>
    let tok ← popToken
    return if tok.treatAsRelax then { tok with text := "\\relax" } else tok

/-- Fully expand a token list (in reverse order) and return the result in forward order
(KaTeX's `expandTokens`); every output token counts as an expansion. -/
partial def expandTokens (tokens : Array Token) : M (Array Token) := do
  let old := (← get).stack.size
  pushTokens tokens
  let rec loop (out : Array Token) : M (Array Token) := do
    if (← get).stack.size > old then
      match ← expandOnce true with
      | some _ => loop out
      | none =>
        let tok ← popToken
        let tok := if tok.treatAsRelax then { tok with noexpand := false, treatAsRelax := false }
          else tok
        loop (out.push tok)
    else return out
  let out ← loop #[]
  countExpansion out.size
  return out

/-- The `|` macro of `\bra@ket` / `\bra@set` (the inner closure of KaTeX's `braketHelper`). -/
partial def runBraketMid (one double : Bool) (middle middleDouble : Array Token)
    (oldMiddle oldMiddleDouble : Option MacroDef) : M NativeResult := do
  if one then
    setMacro "|" oldMiddle
    if middleDouble.size > 0 then setMacro "\\|" oldMiddleDouble
  let mut doubled := double
  if !double && middleDouble.size > 0 then
    if (← future).text == "|" then
      let _ ← popToken
      doubled := true
  return .exp { tokens := if doubled then middleDouble else middle, numArgs := 0 }

/-- `\newcommand`, `\renewcommand` and `\providecommand`. -/
partial def newcommand (existsOK nonexistsOK skipIfExists : Bool) : M NativeResult := do
  let (arg, _, _) ← consumeArg
  let #[nameTok] := arg | perr "\\newcommand's first argument must be a macro name"
  let name := nameTok.text
  let ex ← isDefined name
  if ex && !existsOK then
    perr s!"\\newcommand\{{name}} attempting to redefine {name}; use \\renewcommand"
  if !ex && !nonexistsOK then
    perr s!"\\renewcommand\{{name}} when command {name} does not yet exist; use \\newcommand"
  let mut numArgs := 0
  let (arg, _, _) ← consumeArg
  let mut arg := arg
  if arg.size == 1 && arg[0]?.map (·.text) == some "[" then
    let mut argText := ""
    let mut tok ← expandNextToken
    while tok.text != "]" && tok.text != "EOF" do
      argText := argText ++ tok.text
      tok ← expandNextToken
    let trimmed := (argText.toList.dropWhile isJsSpace).reverse.dropWhile isJsSpace |>.reverse
    if trimmed.isEmpty || !trimmed.all Char.isDigit then
      perr s!"Invalid number of arguments: {argText}"
    let some n := (String.ofList trimmed).toNat? | perr s!"Invalid number of arguments: {argText}"
    numArgs := n
    let (a, _, _) ← consumeArg
    arg := a
  if !(ex && skipIfExists) then
    setMacro name (some (.exp arg numArgs none false))
  return .str ""

/-- The function-valued built-in macros of KaTeX's `macros.ts`, by name. -/
partial def runNative (name : String) : M NativeResult := do
  match name with
  | "\\noexpand" =>
    let t ← popToken
    let t ← do
      if ← isExpandable t.text then pure { t with noexpand := true, treatAsRelax := true }
      else pure t
    return .exp { tokens := #[t], numArgs := 0 }
  | "\\expandafter" =>
    let t ← popToken
    let _ ← expandOnce true
    return .exp { tokens := #[t], numArgs := 0 }
  | "\\@firstoftwo" =>
    let args ← consumeArgs 2
    return .exp { tokens := args.getD 0 #[], numArgs := 0 }
  | "\\@secondoftwo" =>
    let args ← consumeArgs 2
    return .exp { tokens := args.getD 1 #[], numArgs := 0 }
  | "\\@ifnextchar" =>
    let args ← consumeArgs 3
    consumeSpaces
    let next ← future
    if (args.getD 0 #[]).map (·.text) == #[next.text] then
      return .exp { tokens := args.getD 1 #[], numArgs := 0 }
    else return .exp { tokens := args.getD 2 #[], numArgs := 0 }
  | "\\TextOrMath" =>
    let args ← consumeArgs 2
    let mode := (← get).mode
    return .exp { tokens := args.getD (if mode == .text then 0 else 1) #[], numArgs := 0 }
  | "\\char" =>
    let mut token ← popToken
    let mut base : Option Nat := none
    let mut number := 0
    if token.text == "'" then
      base := some 8
      token ← popToken
    else if token.text == "\"" then
      base := some 16
      token ← popToken
    else if token.text == "`" then
      token ← popToken
      if token.text.startsWith "\\" then number := (charCodeAt token.text 1).getD 0
      else if token.text == "EOF" then perr "\\char` missing argument"
      else number := (charCodeAt token.text 0).getD 0
    else base := some 10
    if let some b := base then
      match digitToNumber token.text with
      | some d =>
        if d ≥ b then perr s!"Invalid base-{b} digit {token.text}"
        number := d
      | none => perr s!"Invalid base-{b} digit {token.text}"
      let mut go := true
      while go do
        match digitToNumber (← future).text with
        | some d =>
          if d < b then
            number := number * b + d
            let _ ← popToken
          else go := false
        | none => go := false
    return .str s!"\\@char\{{number}}"
  | "\\newcommand" => newcommand false true false
  | "\\renewcommand" => newcommand true false false
  | "\\providecommand" => newcommand true true true
  | "\\message" | "\\errmessage" =>
    let _ ← consumeArgs 1
    return .str ""
  | "\\show" =>
    let _ ← popToken
    return .str ""
  | "\\dots" =>
    let next := (← expandAfterFuture).text
    let thedots :=
      match dotsByToken[next]? with
      | some d => d
      | none =>
        if (next.take 4).toString == "\\not" then "\\dotsb"
        else match Tables.mathSymbols[next]? with
          | some info => if info.group == .bin || info.group == .rel then "\\dotsb" else "\\dotso"
          | none => "\\dotso"
    return .str thedots
  | "\\dotso" =>
    let next := (← future).text
    return .str (if spaceAfterDots.contains next then "\\ldots\\," else "\\ldots")
  | "\\dotsc" =>
    let next := (← future).text
    return .str (if spaceAfterDots.contains next && next != "," then "\\ldots\\," else "\\ldots")
  | "\\cdots" =>
    let next := (← future).text
    return .str (if spaceAfterDots.contains next then "\\@cdots\\," else "\\@cdots")
  | "\\tag@literal" =>
    if ((← getMacro "\\df@tag").map MacroDef.truthy).getD false then perr "Multiple \\tag"
    return .str "\\gdef\\df@tag{\\text{#1}}"
  | "\\bra@ket" | "\\bra@set" =>
    let one := name == "\\bra@set"
    let (left, _, _) ← consumeArg
    let (middle, _, _) ← consumeArg
    let (middleDouble, _, _) ← consumeArg
    let (right, _, _) ← consumeArg
    let oldMiddle ← getMacro "|"
    let oldMiddleDouble ← getMacro "\\|"
    beginGroup
    setMacro "|" (some (.braketMid one false middle middleDouble oldMiddle oldMiddleDouble))
    if middleDouble.size > 0 then
      setMacro "\\|" (some (.braketMid one true middle middleDouble oldMiddle oldMiddleDouble))
    let (arg, _, _) ← consumeArg
    let expanded ← expandTokens (right ++ arg ++ left)
    endGroup
    return .exp { tokens := expanded.reverse, numArgs := 0 }
  | _ => ierr s!"no implementation of the built-in macro {name}"

end

/-- Fully expand a macro and return its text, or `none` if it is not defined (KaTeX's
`expandMacroAsText`). -/
def expandMacroAsText (name : String) : M (Option String) := do
  if !(← get).macros.has name then return none
  let toks ← expandTokens #[{ text := name }]
  return some (toks.foldl (fun s t => s ++ t.text) "")

end LeAnTeX
