/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Parse.Environments

/-!
# Parser

KaTeX's recursive-descent parser: expressions of atoms, atoms with super- and subscripts and
primes, groups, functions with their typed arguments, symbols with combining accents, infix
operators rewritten into fractions, and the entry point that parses a whole formula (with the
`\tag` wrapper of KaTeX's `parseTree`).

## Main definitions

* `parseExpression`, `parseAtom`, `parseGroup`, `parseFunction`, `parseArguments`,
  `callFunction`, `subparse`: the grammar.
* `parseSymbol`: a single symbol or `\verb`.
* `parseTree`: parse a formula under `Settings`.
* `parse`: `parseTree` from a string, with the warnings raised.

## References

* KaTeX's `src/Parser.ts` and `src/parseTree.ts` (MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- The tokens that end an expression. -/
def endOfExpression : List String := ["}", "\\endgroup", "\\end", "\\right", "&"]

/-- A single symbol, with its combining accents turned into accent nodes, or `\verb` text, or
`none` when the lookahead token is not a symbol (KaTeX's `parseSymbol`). -/
def parseSymbol : M (Option Node) := do
  let nucleus ← fetch
  let mut text := nucleus.text
  let mode ← curMode
  let strict := (← settings).strict
  let cs := text.toList
  -- `\verb` with its delimiters (the lexer guarantees they match)
  if text.startsWith "\\verb" && cs.length > 5 && !(cs[5]!.isAlpha) then
    consume
    let mut arg := cs.drop 5
    let star := arg.head? == some '*'
    if star then arg := arg.drop 1
    if arg.length < 2 || arg.head? != arg.getLast? then
      perr ("\\verb assertion failed --\n                    please report what input caused " ++
        "this bug")
    return some (.verb .text .absent (String.ofList (arg.drop 1).dropLast) star)
  -- a precomposed accented letter becomes its base letter and combining accents
  if let some c0 := cs.head? then
    if let some dec := Tables.unicodeSymbols[c0.toString]? then
      if !(Tables.symbolsIn mode).contains c0.toString then
        if mode == .math then
          reportStrict "unicodeTextInMathMode"
            s!"Accented Unicode text character \"{c0}\" used in math mode" nucleus.loc
        text := dec ++ String.ofList cs.tail
  -- strip the combining accents
  let tcs := text.toList
  let base := (tcs.reverse.dropWhile isCombining).reverse
  let accents := tcs.drop base.length
  if !accents.isEmpty then
    text := String.ofList base
    if text == "i" then text := "ı"
    else if text == "j" then text := "ȷ"
  let first := text.toList.head?
  let firstText := match first with
    | some c => if c.val ≥ 0x10000 then "\uFFFD" else c.toString
    | none => ""
  let mut symbol : Node ← do
    match (Tables.symbolsIn mode)[text]? with
    | some info =>
      if mode == .math && (Data.extraLatin.splitOn text).length > 1 then
        reportStrict "unicodeTextInMathMode"
          s!"Latin-1/Unicode text character \"{firstText}\" used in math mode" nucleus.loc
      pure (Node.sym mode nucleus.loc info.group text)
    | none =>
      let code := (charCodeAt text 0).getD 0
      if code ≥ 0x80 then
        if strict != .ignore then
          if !Tables.supportedCodepoint code then
            reportStrict "unknownSymbol"
              s!"Unrecognized Unicode character \"{firstText}\" ({code})" nucleus.loc
          else if mode == .math then
            reportStrict "unicodeTextInMathMode"
              s!"Unicode text character \"{firstText}\" used in math mode" nucleus.loc
        pure (Node.sym .text nucleus.loc .textord text)
      else return none
  consume
  for a in accents do
    let some (textCmd, mathCmd) := Tables.unicodeAccents[a.toString]?
      | perrAt s!"Unknown accent ' {a}'" nucleus
    let command := if mode == .math then mathCmd.getD textCmd else textCmd
    symbol := .accent mode nucleus.loc command (some false) (some true) symbol
  return some symbol

mutual

/-- A list of atoms up to the end of the group, `breakOnTokenText`, or (with `breakOnInfix`) an
infix operator; ligatures are formed in text mode and an infix operator becomes its fraction
(KaTeX's `parseExpression`). -/
partial def parseExpression (breakOnInfix : Bool) (breakOnTokenText : Option String := none) :
    M (Array Node) := do
  let mut body := #[]
  repeat
    if (← curMode) == .math then consumeSpacesP
    let lex ← fetch
    if endOfExpression.contains lex.text then break
    if breakOnTokenText == some lex.text then break
    if breakOnInfix && ((Tables.functions[lex.text]?.map (·.isInfix)).getD false) then break
    match ← parseAtom breakOnTokenText with
    | none => break
    | some (.internal ..) => continue
    | some atom => body := body.push atom
  if (← curMode) == .text then body := formLigatures body
  handleInfixNodes body

/-- The expression with its one infix operator (`\over`, `\choose`, `\above` …) replaced by
the fraction it stands for. -/
partial def handleInfixNodes (body : Array Node) : M (Array Node) := do
  let mut overIndex : Option Nat := none
  let mut funcName := ""
  for i in [0:body.size] do
    if let .infix _ _ rw _ tok := body[i]! then
      if overIndex.isSome then
        perrLoc "only one infix operator per group" (tok.map (·.loc) |>.getD .absent)
      overIndex := some i
      funcName := rw
  let some oi := overIndex | return body
  let mode ← curMode
  let wrap (ns : Array Node) : Node :=
    if h : ns.size = 1 then
      match ns[0] with
      | n@(.ordgroup ..) => n
      | _ => .ordgroup mode .absent ns none
    else .ordgroup mode .absent ns none
  let numer := wrap (body.extract 0 oi)
  let denom := wrap (body.extract (oi + 1) body.size)
  let node ← if funcName == "\\\\abovefrac" then
      callFunction funcName #[numer, body[oi]!, denom] #[] none none
    else callFunction funcName #[numer, denom] #[] none none
  return #[node]

/-- The group after `^` or `_` (KaTeX's `handleSupSubscript`). -/
partial def handleSupSubscript (name : String) : M Node := do
  let symbolToken ← fetch
  consume
  consumeSpacesP
  let rec loop : M (Option Node) := do
    match ← parseGroup name none with
    | some (.internal ..) => loop
    | g => return g
  let some group ← loop | perrAt s!"Expected group after '{symbolToken.text}'" symbolToken
  return group

/-- A group with its super- and subscripts, primes and limit controls (KaTeX's `parseAtom`). -/
partial def parseAtom (breakOnTokenText : Option String) : M (Option Node) := do
  let base ← parseGroup "atom" breakOnTokenText
  if let some (.internal ..) := base then return base
  if (← curMode) == .text then return base
  let mut base := base
  let mut superscript : Option Node := none
  let mut subscript : Option Node := none
  repeat
    consumeSpacesP
    let lex ← fetch
    if lex.text == "\\limits" || lex.text == "\\nolimits" then
      let lim := lex.text == "\\limits"
      match base with
      | some (.op m l _ _ sbs pis sym nm bd) =>
        base := some (.op m l lim (some true) sbs pis sym nm bd)
      | some (.operatorname m l bd ahs lims pis) =>
        base := some (.operatorname m l bd ahs (if ahs then lim else lims) pis)
      | _ => perrAt "Limit controls must follow a math operator" lex
      consume
    else if lex.text == "^" then
      if superscript.isSome then perrAt "Double superscript" lex
      superscript := some (← handleSupSubscript "superscript")
    else if lex.text == "_" then
      if subscript.isSome then perrAt "Double subscript" lex
      subscript := some (← handleSupSubscript "subscript")
    else if lex.text == "'" then
      if superscript.isSome then perrAt "Double superscript" lex
      let mode ← curMode
      let prime := Node.sym mode .absent .textord "\\prime"
      let mut primes := #[prime]
      consume
      while (← fetch).text == "'" do
        primes := primes.push prime
        consume
      if (← fetch).text == "^" then
        primes := primes.push (← handleSupSubscript "superscript")
      superscript := some (.ordgroup mode .absent primes none)
    else if let some (plain, isSub) := Tables.subSup[lex.text]? then
      let mut toks : Array Token := #[{ text := plain }]
      consume
      repeat
        let t := (← fetch).text
        let some (p, s) := Tables.subSup[t]? | break
        if s != isSub then break
        toks := #[{ text := p }] ++ toks
        consume
      let body ← subparse toks
      if isSub then subscript := some (.ordgroup .math .absent body none)
      else superscript := some (.ordgroup .math .absent body none)
    else break
  let mode ← curMode
  if superscript.isSome || subscript.isSome then
    return some (.supsub mode .absent base superscript subscript)
  return base

/-- A function call with its arguments, or `none` if the lookahead token is not a function
(KaTeX's `parseFunction`). `name` says what the call is an argument of, for errors. -/
partial def parseFunction (breakOnTokenText : Option String := none)
    (name : Option String := none) : M (Option Node) := do
  let token ← fetch
  let func := token.text
  let some spec := Tables.functions[func]? | return none
  consume
  let mode ← curMode
  if name.isSome && name != some "atom" && !spec.allowedInArgument then
    perrAt (s!"Got function '{func}' with no arguments" ++
      (match name with | some n => s!" as {n}" | none => "")) token
  else if mode == .text && !spec.allowedInText then
    perrAt s!"Can't use function '{func}' in text mode" token
  else if mode == .math && !spec.allowedInMath then
    perrAt s!"Can't use function '{func}' in math mode" token
  let argSpec : ArgSpec := {
    numArgs := spec.numArgs, numOptionalArgs := spec.numOptionalArgs, argTypes := spec.argTypes
    isPrimitive := spec.isPrimitive, isSqrt := spec.type == "sqrt" }
  let (args, optArgs) ← parseArguments func argSpec
  some <$> callFunction func args optArgs (some token) breakOnTokenText

/-- Run a function's handler (KaTeX's `callFunction`). -/
partial def callFunction (name : String) (args : Array Node) (optArgs : Array (Option Node))
    (token : Option Token) (breakOnTokenText : Option String) : M Node := do
  let some spec := Tables.functions[name]? | perr s!"No function handler for {name}"
  if !spec.hasHandler then perr s!"No function handler for {name}"
  let ctx : Ctx := { funcName := name, token, breakOnTokenText }
  if spec.handler == "\\begin" then return ← beginHandler ctx args
  let some h := functionHandler spec.handler
    | ierr s!"LeAnTeX has no handler for the KaTeX function {name}"
  h (mkOps ()) ctx args optArgs

/-- The arguments of a function or environment: optional ones first, then mandatory ones,
each parsed by its type (KaTeX's `parseArguments`). -/
partial def parseArguments (func : String) (spec : ArgSpec) :
    M (Array Node × Array (Option Node)) := do
  let total := spec.numArgs + spec.numOptionalArgs
  let mut args := #[]
  let mut optArgs : Array (Option Node) := #[]
  for i in [0:total] do
    let mut argType := spec.argTypes[i]?
    let isOptional := i < spec.numOptionalArgs
    if (spec.isPrimitive && argType.isNone) ||
        (spec.isSqrt && i == 1 && (optArgs[0]?.join).isNone) then
      argType := some .primitive
    let arg ← parseGroupOfType s!"argument to '{func}'" argType isOptional
    if isOptional then optArgs := optArgs.push arg
    else match arg with
      | some a => args := args.push a
      | none => perr "Null argument, please report this as a bug"
  return (args, optArgs)

/-- An argument of the given type (KaTeX's `parseGroupOfType`). -/
partial def parseGroupOfType (name : String) (type : Option ArgType) (optional : Bool) :
    M (Option Node) := do
  match type with
  | some .color => parseColorGroup optional
  | some .size => parseSizeGroup optional
  | some .url => parseUrlGroup optional
  | some .math => parseArgumentGroup optional (some .math)
  | some .text => parseArgumentGroup optional (some .text)
  | some .hbox =>
    let g ← parseArgumentGroup optional (some .text)
    return g.map fun g => .styling g.mode .absent "text" (some true) #[g]
  | some .raw => parseRawGroup optional
  | some .primitive =>
    if optional then perr "A primitive argument cannot be optional"
    let some g ← parseGroup name none | perrAt s!"Expected group as {name}" (← fetch)
    return some g
  | some .original | none => parseArgumentGroup optional none

/-- A braced (or bracketed) argument parsed as an expression in its own group, optionally in
another mode (KaTeX's `parseArgumentGroup`). -/
partial def parseArgumentGroup (optional : Bool) (mode : Option Mode) : M (Option Node) := do
  let some argToken ← scanArgument optional | return none
  let outer ← curMode
  if let some m := mode then switchMode m
  beginGroup
  let expression ← parseExpression false (some "EOF")
  expect "EOF"
  endGroup
  let result := Node.ordgroup (← curMode) argToken.loc expression none
  if mode.isSome then switchMode outer
  return some result

/-- A group: braces or `\begingroup … \endgroup`, a function call, or a symbol; an undefined
control sequence is an error (or red text without `throwOnError`) (KaTeX's `parseGroup`). -/
partial def parseGroup (name : String) (breakOnTokenText : Option String) :
    M (Option Node) := do
  let firstToken ← fetch
  let text := firstToken.text
  if text == "{" || text == "\\begingroup" then
    consume
    let groupEnd := if text == "{" then "}" else "\\endgroup"
    beginGroup
    let expression ← parseExpression false (some groupEnd)
    let lastToken ← fetch
    expect groupEnd
    endGroup
    return some (.ordgroup (← curMode) (OLoc.range firstToken.loc lastToken.loc) expression
      (if text == "\\begingroup" then some true else none))
  let mut result ← parseFunction breakOnTokenText (some name)
  if result.isNone then result ← parseSymbol
  if result.isNone && text.startsWith "\\" && !implicitCommands.contains text then
    if (← settings).throwOnError then
      perrAt s!"Undefined control sequence: {text}" firstToken
    result := some (← formatUnsupportedCmd text)
    consume
  return result

/-- Parse a token list (in reverse order) as a separate expression, keeping the current
lookahead token (KaTeX's `subparse`). -/
partial def subparse (tokens : Array Token) : M (Array Node) := do
  let old := (← get).nextToken
  consume
  pushToken { text := "}" }
  pushTokens tokens
  let parse ← parseExpression false
  expect "}"
  modify fun s => { s with nextToken := old }
  return parse

/-- The parser's functions as handlers see them. -/
partial def mkOps (_ : Unit) : Ops where
  parseExpression := fun b t => parseExpression b t
  parseFunction := fun t n => parseFunction t n
  parseArguments := fun f sp => parseArguments f sp
  callFunction := fun n a o t b => callFunction n a o t b
  subparse := fun ts => subparse ts

/-- The handler of `\begin` and `\end` (KaTeX's `environment.ts`). -/
partial def beginHandler (c : Ctx) (args : Array Node) : M Node := do
  let nameGroup := args[0]!
  unless nameGroup matches .ordgroup .. do perrLoc "Invalid environment name" nameGroup.loc
  let envName ← assertCharacterGroup nameGroup
    "Environment name should contain only text characters and spaces" true
  if c.funcName != "\\begin" then return .environment (← curMode) .absent envName nameGroup
  let some env := Tables.environments[envName]?
    | perrLoc s!"No such environment: {envName}" nameGroup.loc
  let argSpec : ArgSpec := {
    numArgs := env.numArgs, numOptionalArgs := env.numOptionalArgs, argTypes := env.argTypes }
  let (eargs, eopt) ← parseArguments s!"\\begin\{{envName}}" argSpec
  let some h := environmentHandler env.handler
    | ierr s!"LeAnTeX has no handler for the KaTeX environment {envName}"
  let mode ← curMode
  let result ← h (mkOps ()) { mode, envName } eargs eopt
  expect "\\end" false
  let endNameToken := (← get).nextToken
  match ← parseFunction none none with
  | some (.environment _ _ endName _) =>
    if endName != envName then
      perrLoc s!"Mismatch: \\begin\{{envName}} matched by \\end\{{endName}}"
        (endNameToken.map (·.loc) |>.getD .absent)
  | some n => wrongNode "environment" (some n)
  | none => ierr "Expected node of type environment, but got null"
  return result

end

/-- Parse a whole formula: the expression, then the end of input; a `\tag` wraps the result
(KaTeX's `Parser.parse` and `parseTree`). -/
def parseTree : M (Array Node) := do
  modifyMacros fun ns => { ns with current := ns.current.erase "\\df@tag" }
  let s ← settings
  let tree ← tryFinally (do
      if !s.globalGroup then beginGroup
      if s.colorIsTextColor then setMacro "\\color" (some (.str "\\textcolor"))
      let parse ← parseExpression false
      expect "EOF"
      if !s.globalGroup then endGroup
      pure parse)
    endGroups
  modifyMacros fun ns => { ns with current := (ns.current.erase "\\current@color").erase "\\color" }
  if ((← getMacro "\\df@tag").map MacroDef.truthy).getD false then
    if !s.displayMode then perr "\\tag works only in display equations"
    let tag ← subparse #[{ text := "\\df@tag" }]
    return #[.tag .text .absent tree tag]
  return tree

/-- The result of parsing a formula. -/
structure ParseResult where
  /-- The parse tree, or the error. -/
  result : Except KError (Array Node)
  /-- The strict-mode warnings raised, in order. -/
  warnings : Array Warning

/-- Parse a formula under the given settings. -/
def parse (input : String) (settings : Settings := {}) : ParseResult :=
  let src : Source := ⟨0, input⟩
  let user := settings.macros.toList.map fun (k, v) => (k, MacroDef.str v)
  let macros : Namespace := { current := Std.HashMap.ofList user }
  let st : State := { settings, lexer := Lexer.ofSource src, macros }
  match parseTree.run st with
  | .ok t s => { result := .ok t, warnings := s.warnings }
  | .error e s => { result := .error e, warnings := s.warnings }

end LeAnTeX
