/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Parse.Ops

/-!
# Function handlers

The handlers of KaTeX's functions: given the parsed arguments they build the parse node, and
some of them (`\left`, `\color`, `\def`, `\begin`, the style and size switches) read more of
the input themselves. Each handler is keyed by the first name of the KaTeX definition it ports
(the `handler` field of `LeAnTeX.Data.functionList`).

## Main definitions

* `functionHandler`: the handler for a key, if there is one.
* `isCharacterBox`, `binrelClass`, `checkDelimiter`: helpers several handlers share.

## Implementation notes

Errors keep KaTeX's classes: a `ParseError` where KaTeX throws one, and an internal `Error`
where KaTeX's `assertNodeType` fails. Strict-mode reports have no location, as in KaTeX.

## References

* KaTeX's `src/functions/*.ts` (accent, accentunder, arrow, char, color, cr, def, delimsizing,
  enclose, environment, font, genfrac, hbox, horizBrace, href, html, htmlmathml,
  includegraphics, kern, lap, math, mathchoice, mclass, op, operatorname, overline, phantom,
  pmb, raisebox, reflectbox, relax, rule, sizing, smash, sqrt, styling, text, underline,
  vcenter, verb), `src/environments/cd.ts` (the label functions), `src/parseNode.ts` and
  `src/utils.ts` (MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

open Std

/-- The innermost group of a node through one-element groups, colours and fonts
(KaTeX's `getBaseElem`). -/
partial def getBaseElem : Node → Node
  | n@(.ordgroup _ _ body _) => if h : body.size = 1 then getBaseElem body[0] else n
  | n@(.color _ _ _ body) => if h : body.size = 1 then getBaseElem body[0] else n
  | .font _ _ _ body => getBaseElem body
  | n => n

/-- Whether a node is a single character, for TeX's character-box rules (KaTeX's
`isCharacterBox`). -/
def isCharacterBox (n : Node) : Bool :=
  match getBaseElem n with
  | .sym _ _ g _ => g.isAtom || g == .mathord || g == .textord
  | _ => false

/-- The class `\binrel@` gives: `mbin` or `mrel` after a binary or relation atom, else `mord`. -/
def binrelClass (arg : Node) : String :=
  let atom := match arg with
    | .ordgroup _ _ body _ => if h : 0 < body.size then body[0] else arg
    | _ => arg
  match atom with
  | .sym _ _ .bin _ => "mbin"
  | .sym _ _ .rel _ => "mrel"
  | _ => "mord"

/-- The delimiters `\big`, `\left`, `\right` and `\middle` accept. -/
def delimiters : HashSet String := HashSet.ofList
  ["(", "\\lparen", ")", "\\rparen", "[", "\\lbrack", "]", "\\rbrack", "\\{", "\\lbrace",
    "\\}", "\\rbrace", "\\lfloor", "\\rfloor", "⌊", "⌋", "\\lceil", "\\rceil", "⌈", "⌉", "<",
    ">", "\\langle", "⟨", "\\rangle", "⟩", "\\lt", "\\gt", "\\lvert", "\\rvert", "\\lVert",
    "\\rVert", "\\lgroup", "\\rgroup", "⟮", "⟯", "\\lmoustache", "\\rmoustache", "⎰", "⎱", "/",
    "\\backslash", "|", "\\vert", "\\|", "\\Vert", "\\uparrow", "\\Uparrow", "\\downarrow",
    "\\Downarrow", "\\updownarrow", "\\Updownarrow", "."]

/-- A delimiter argument's text, or KaTeX's error for anything else. -/
def checkDelimiter (delim : Node) (funcName : String) : M String := do
  match delim.symText? with
  | some t =>
    if delimiters.contains t then return t
    perrLoc s!"Invalid delimiter '{t}' after '{funcName}'" delim.loc
  | none => perrLoc s!"Invalid delimiter type '{delim.type}'" delim.loc

/-- The sizes and classes of `\big` and its relatives. -/
private def delimiterSize (name : String) : Nat × String :=
  let cls := match name.back with
    | 'l' => "mopen" | 'r' => "mclose" | 'm' => "mrel" | _ => "mord"
  let base := if cls == "mord" then name else (name.dropEnd 1).toString
  let size := match base with
    | "\\big" => 1 | "\\Big" => 2 | "\\bigg" => 3 | _ => 4
  (size, cls)

/-- The node a handler must have been given, or KaTeX's `assertNodeType` error. -/
private def expectSize : Node → M Measurement
  | .size _ _ v _ => pure v
  | n => wrongNode "size" (some n)

/-- The colour of a `color-token` argument. -/
private def expectColor : Node → M String
  | .colorToken _ _ c => pure c
  | n => wrongNode "color-token" (some n)

/-- The string of a `raw` argument. -/
private def expectRaw : Node → M String
  | .raw _ _ s => pure s
  | n => wrongNode "raw" (some n)

/-- The URL of a `url` argument. -/
private def expectUrl : Node → M String
  | .url _ _ u => pure u
  | n => wrongNode "url" (some n)

/-- Prefix commands and the definitions they turn the next command into (KaTeX's
`globalMap`). -/
private def globalMap (name : String) : Option String :=
  match name with
  | "\\global" => some "\\global" | "\\long" => some "\\\\globallong"
  | "\\\\globallong" => some "\\\\globallong" | "\\def" => some "\\gdef"
  | "\\gdef" => some "\\gdef" | "\\edef" => some "\\xdef" | "\\xdef" => some "\\xdef"
  | "\\let" => some "\\\\globallet" | "\\futurelet" => some "\\\\globalfuture"
  | _ => none

/-- A control sequence to define, or KaTeX's error. -/
private def checkControlSequence (tok : Token) : M String := do
  if ["\\", "{", "}", "$", "&", "#", "^", "_", "EOF"].contains tok.text then
    perrAt "Expected a control sequence" tok
  return tok.text

/-- `\let`'s right-hand side, after an optional `=` and one optional space. -/
private def getRHS : M Token := do
  let mut tok ← popToken
  if tok.text == "=" then
    tok ← popToken
    if tok.text == " " then tok ← popToken
  return tok

/-- Give `name` the meaning of `tok` (KaTeX's `letCommand`); returns `tok` as `\let` leaves it
(marked not to expand when it is not a macro). -/
private def letCommand (name : String) (tok : Token) (global : Bool) : M Token := do
  match ← getMacro tok.text with
  | some m =>
    setMacro name (some m) global
    return tok
  | none =>
    let tok := { tok with noexpand := true }
    let unexp := !(← isExpandable tok.text)
    setMacro name (some (.exp #[tok] 0 none unexp)) global
    return tok

/-- JavaScript's `parseInt(s)` in base 10 (with the `0x` prefix meaning base 16). -/
def jsParseInt (s : String) : Option Int := Id.run do
  let cs := s.toList.dropWhile isJsSpace
  let (neg, cs) := match cs with
    | '-' :: r => (true, r)
    | '+' :: r => (false, r)
    | r => (false, r)
  let (base, cs) := match cs with
    | '0' :: 'x' :: r | '0' :: 'X' :: r => (16, r)
    | r => (10, r)
  let digit (c : Char) : Option Nat :=
    if c.isDigit then some (c.toNat - '0'.toNat)
    else if base == 16 && c ≥ 'a' && c ≤ 'f' then some (c.toNat - 'a'.toNat + 10)
    else if base == 16 && c ≥ 'A' && c ≤ 'F' then some (c.toNat - 'A'.toNat + 10)
    else none
  let ds := cs.takeWhile (digit · |>.isSome)
  if ds.isEmpty then return none
  let v := ds.foldl (fun acc c => acc * base + (digit c).getD 0) 0
  return some (if neg then -(v : Int) else v)

/-- The text of a code point, as JavaScript builds it; a lone surrogate becomes U+FFFD. -/
private def codePointText (code : Nat) : String :=
  if code ≥ 0xD800 && code ≤ 0xDFFF then "�" else (Char.ofNat code).toString

/-- JavaScript's `String.prototype.trim`. -/
private def jsTrim (s : String) : String :=
  String.ofList ((s.toList.dropWhile isJsSpace).reverse.dropWhile isJsSpace).reverse

/-- `\includegraphics`'s size values: a bare number is in `bp`. -/
private def sizeData (str : String) : M Measurement := do
  let bare := match str.toList with
    | c :: r => (c == '-' || c == '+' || c.isDigit || c == '.') &&
        isSizeNumber (if c == '-' || c == '+' then (r.dropWhile (· == ' ')) else c :: r)
    | [] => false
  if bare then
    let n := if str.contains ' ' then 0.0 / 0.0 else decimalToFloat str
    return ⟨n, "bp"⟩
  let some (sign, mag, unit) := matchSize str
    | perr s!"Invalid size: '{str}' in \\includegraphics"
  if !validUnits.contains unit then perr s!"Invalid unit: '{unit}' in \\includegraphics."
  return ⟨decimalToFloat (sign ++ mag), unit⟩
where
  /-- `\d+(\.\d*)?|\.\d+` matching all of `cs`. -/
  isSizeNumber (cs : List Char) : Bool :=
    match cs with
    | '.' :: r => !r.isEmpty && r.all Char.isDigit
    | _ =>
      let ip := cs.takeWhile Char.isDigit
      let rest := cs.dropWhile Char.isDigit
      !ip.isEmpty && (rest.isEmpty || (rest.head? == some '.' && rest.tail.all Char.isDigit))

/-- The accents KaTeX never stretches (its `NON_STRETCHY_ACCENT_REGEX`, a substring test). -/
private def nonStretchy (name : String) : Bool :=
  ["\\acute", "\\grave", "\\ddot", "\\tilde", "\\bar", "\\breve", "\\check", "\\hat", "\\vec",
    "\\dot", "\\mathring"].any fun a => (name.splitOn a).length > 1

/-- The fraction commands' style wrapper (KaTeX's `wrapWithStyle`). -/
private def wrapWithStyle (frac : Node) (style : Option String) : Node :=
  match style with
  | some s => .styling frac.mode .absent s none #[frac]
  | none => frac

/-- The single-character big operators and the commands they stand for. -/
private def singleCharOp (s : String) : String :=
  match s with
  | "∏" => "\\prod" | "∐" => "\\coprod" | "∑" => "\\sum" | "⋀" => "\\bigwedge"
  | "⋁" => "\\bigvee" | "⋂" => "\\bigcap" | "⋃" => "\\bigcup" | "⨀" => "\\bigodot"
  | "⨁" => "\\bigoplus" | "⨂" => "\\bigotimes" | "⨄" => "\\biguplus" | "⨆" => "\\bigsqcup"
  | "∫" => "\\int" | "∬" => "\\iint" | "∭" => "\\iiint" | "∮" => "\\oint" | "∯" => "\\oiint"
  | "∰" => "\\oiiint"
  | _ => s

/-- The size switches, in order (size 1 to 11). -/
def sizeFuncs : Array String :=
  #["\\tiny", "\\sixptsize", "\\scriptsize", "\\footnotesize", "\\small", "\\normalsize",
    "\\large", "\\Large", "\\LARGE", "\\huge", "\\Huge"]

/-- The handler for a function key, if LeAnTeX has one. -/
def functionHandler (key : String) : Option Handler :=
  match key with
  | "\\'" => some fun _ c args _ => do
    let mut mode ← curMode
    if mode == .math then
      reportStrict "mathVsTextAccents" s!"LaTeX's accent {c.funcName} works only in text mode"
      mode := .text
    return .accent mode .absent c.funcName (some false) (some true) args[0]!
  | "\\acute" => some fun _ c args _ => do
    let base := args[0]!.normalizeArgument
    let isStretchy := !nonStretchy c.funcName
    let isShifty := !isStretchy || c.funcName == "\\widehat" || c.funcName == "\\widetilde" ||
      c.funcName == "\\widecheck"
    return .accent (← curMode) .absent c.funcName (some isStretchy) (some isShifty) base
  | "\\underleftarrow" => some fun _ c args _ => do
    return .accentUnder (← curMode) .absent c.funcName args[0]!
  | "\\xleftarrow" => some fun _ c args opt => do
    return .xArrow (← curMode) .absent c.funcName args[0]! opt[0]!
  | "\\@char" => some fun _ _ args _ => do
    let arg := args[0]!
    unless arg matches .ordgroup .. do wrongNode "ordgroup" (some arg)
    let number ← assertCharacterGroup arg "\\@char has non-numeric argument"
    let some code := jsParseInt number | perr s!"\\@char has non-numeric argument {number}"
    if code < 0 || code > 0x10ffff then perr s!"\\@char with invalid code point {number}"
    return .sym (← curMode) .absent .textord (codePointText code.toNat)
  | "\\textcolor" => some fun _ _ args _ => do
    let color ← expectColor args[0]!
    return .color (← curMode) .absent color args[1]!.ordargument
  | "\\color" => some fun ops c args _ => do
    let color ← expectColor args[0]!
    setMacro "\\current@color" (some (.str color))
    let body ← ops.parseExpression true c.breakOnTokenText
    return .color (← curMode) .absent color body
  | "\\\\" => some fun _ _ _ _ => do
    let size ← if (← future).text == "[" then parseSizeGroup true else pure none
    let newLine ← do
      if !(← settings).displayMode then pure true
      else
        let s ← useStrictBehavior "newLineInDisplayMode"
          "In LaTeX, \\\\ or \\newline does nothing in display mode"
        pure !s
    let size ← match size with
      | some n => some <$> expectSize n
      | none => pure none
    return .cr (← curMode) .absent newLine size
  | "\\global" => some fun ops c _ _ => do
    consumeSpacesP
    let token ← fetch
    match globalMap token.text with
    | some g =>
      if c.funcName == "\\global" || c.funcName == "\\\\globallong" then
        modify fun s => { s with nextToken := some { token with text := g } }
      match ← ops.parseFunction none none with
      | some n@(.internal ..) => return n
      | some n => wrongNode "internal" (some n)
      | none => ierr "Expected node of type internal, but got null"
    | none => perrAt "Invalid token after macro prefix" token
  | "\\def" => some fun _ c _ _ => do
    let tok ← popToken
    let name := tok.text
    if ["\\", "{", "}", "$", "&", "#", "^", "_", "EOF"].contains name then
      perrAt "Expected a control sequence" tok
    let mut numArgs := 0
    let mut insert : Option Token := none
    let mut delims : Array (Array String) := #[#[]]
    let mut go := true
    while go && (← future).text != "{" do
      let t ← popToken
      if t.text == "#" then
        if (← future).text == "{" then
          insert := some (← future)
          delims := delims.modify numArgs (·.push "{")
          go := false
        else
          let t ← popToken
          match t.text.toList with
          | [d] =>
            if !(d ≥ '1' && d ≤ '9') then perr s!"Invalid argument number \"{t.text}\""
            if d.toNat - '0'.toNat != numArgs + 1 then
              perr s!"Argument number \"{t.text}\" out of order"
          | _ => perr s!"Invalid argument number \"{t.text}\""
          numArgs := numArgs + 1
          delims := delims.push #[]
      else if t.text == "EOF" then perr "Expected a macro definition"
      else delims := delims.modify numArgs (·.push t.text)
    let (tokens, _, _) ← consumeArg
    let mut tokens := tokens
    if let some i := insert then tokens := #[i] ++ tokens
    if c.funcName == "\\edef" || c.funcName == "\\xdef" then
      tokens := (← expandTokens tokens).reverse
    setMacro name (some (.exp tokens numArgs (some delims) false))
      (globalMap c.funcName == some c.funcName)
    return .internal (← curMode) .absent
  | "\\let" => some fun _ c _ _ => do
    let name ← checkControlSequence (← popToken)
    consumeSpaces
    let tok ← getRHS
    let _ ← letCommand name tok (c.funcName == "\\\\globallet")
    return .internal (← curMode) .absent
  | "\\futurelet" => some fun _ c _ _ => do
    let name ← checkControlSequence (← popToken)
    let middle ← popToken
    let tok ← popToken
    let tok ← letCommand name tok (c.funcName == "\\\\globalfuture")
    pushToken tok
    pushToken middle
    return .internal (← curMode) .absent
  | "\\bigl" => some fun _ c args _ => do
    let delim ← checkDelimiter args[0]!.normalizeArgument c.funcName
    let (size, mclass) := delimiterSize c.funcName
    return .delimsizing (← curMode) .absent size mclass delim
  | "\\right" => some fun _ c args _ => do
    let color ← match ← getMacro "\\current@color" with
      | some (.str s) => pure (some s)
      | some _ => perr "\\current@color set to non-string in \\right"
      | none => pure none
    let delim ← checkDelimiter args[0]! c.funcName
    return .leftrightRight (← curMode) .absent delim color
  | "\\left" => some fun ops c args _ => do
    let delim ← checkDelimiter args[0]! c.funcName
    modify fun s => { s with leftrightDepth := s.leftrightDepth + 1 }
    let body ← ops.parseExpression false none
    modify fun s => { s with leftrightDepth := s.leftrightDepth - 1 }
    expect "\\right" false
    match ← ops.parseFunction none none with
    | some (.leftrightRight _ _ rd rc) => return .leftright (← curMode) .absent body delim rd rc
    | some n => wrongNode "leftright-right" (some n)
    | none => ierr "Expected node of type leftright-right, but got null"
  | "\\middle" => some fun _ c args _ => do
    let delim ← checkDelimiter args[0]! c.funcName
    if (← get).leftrightDepth == 0 then
      perrLoc "\\middle without preceding \\left" args[0]!.loc
    return .middle (← curMode) .absent delim
  | "\\colorbox" => some fun _ c args _ => do
    let color ← expectColor args[0]!
    return .enclose (← curMode) .absent c.funcName (some color) none args[1]!
  | "\\fcolorbox" => some fun _ c args _ => do
    let border ← expectColor args[0]!
    let bg ← expectColor args[1]!
    return .enclose (← curMode) .absent c.funcName (some bg) (some border) args[2]!
  | "\\fbox" => some fun _ _ args _ => do
    return .enclose (← curMode) .absent "\\fbox" none none args[0]!
  | "\\cancel" => some fun _ c args _ => do
    return .enclose (← curMode) .absent c.funcName none none args[0]!
  | "\\sout" => some fun _ c args _ => do
    if (← curMode) == .math then
      reportStrict "mathVsSout" "LaTeX's \\sout works only in text mode"
    return .enclose (← curMode) .absent c.funcName none none args[0]!
  | "\\angl" => some fun _ _ args _ => do
    return .enclose (← curMode) .absent "\\angl" none none args[0]!
  | "\\mathrm" => some fun _ c args _ => do
    let func := match c.funcName with
      | "\\Bbb" => "\\mathbb" | "\\bold" => "\\mathbf" | "\\frak" => "\\mathfrak" | f => f
    return .font (← curMode) .absent (func.drop 1).toString args[0]!.normalizeArgument
  | "\\boldsymbol" => some fun _ _ args _ => do
    let m ← curMode
    let body := args[0]!
    return .mclass m .absent (binrelClass body) #[.font m .absent "boldsymbol" body]
      (isCharacterBox body)
  | "\\rm" => some fun ops c _ _ => do
    let mode ← curMode
    let body ← ops.parseExpression true c.breakOnTokenText
    return .font mode .absent ("math" ++ (c.funcName.drop 1).toString)
      (.ordgroup (← curMode) .absent body none)
  | "\\cfrac" => some fun _ c args _ => do
    let (hasBarLine, leftDelim, rightDelim) : Bool × Option String × Option String :=
      match c.funcName with
      | "\\\\atopfrac" => (false, none, none)
      | "\\dbinom" | "\\binom" | "\\tbinom" => (false, some "(", some ")")
      | "\\\\bracefrac" => (false, some "\\{", some "\\}")
      | "\\\\brackfrac" => (false, some "[", some "]")
      | _ => (true, none, none)
    let continued := c.funcName == "\\cfrac"
    let style := if continued || c.funcName.startsWith "\\d" then some "display"
      else if c.funcName.startsWith "\\t" then some "text" else none
    let frac := Node.genfrac (← curMode) .absent continued args[0]! args[1]! hasBarLine
      leftDelim rightDelim none
    return wrapWithStyle frac style
  | "\\over" => some fun _ c _ _ => do
    let replaceWith := match c.funcName with
      | "\\over" => "\\frac" | "\\choose" => "\\binom" | "\\atop" => "\\\\atopfrac"
      | "\\brace" => "\\\\bracefrac" | _ => "\\\\brackfrac"
    return .infix (← curMode) .absent replaceWith none c.token
  | "\\genfrac" => some fun _ _ args _ => do
    let leftDelim := match args[0]!.normalizeArgument with
      | .sym _ _ .open t => if t.isEmpty || t == "." then none else some t
      | _ => none
    let rightDelim := match args[1]!.normalizeArgument with
      | .sym _ _ .close t => if t.isEmpty || t == "." then none else some t
      | _ => none
    let (hasBarLine, barSize) ← match args[2]! with
      | .size _ _ v isBlank => pure (if isBlank then (true, none) else (v.number > 0, some v))
      | n => wrongNode "size" (some n)
    let style ← match args[3]! with
      | .ordgroup _ _ body _ =>
        if h : 0 < body.size then
          match body[0] with
          | .sym _ _ .textord t =>
            pure (match t with
              | "0" => some "display" | "1" => some "text" | "2" => some "script"
              | "3" => some "scriptscript" | _ => none)
          | n => wrongNode "textord" (some n)
        else pure none
      | n => wrongNode "textord" (some n)
    let frac := Node.genfrac (← curMode) .absent false args[4]! args[5]! hasBarLine leftDelim
      rightDelim barSize
    return wrapWithStyle frac style
  | "\\above" => some fun _ c args _ => do
    let v ← expectSize args[0]!
    return .infix (← curMode) .absent "\\\\abovefrac" (some v) c.token
  | "\\\\abovefrac" => some fun _ _ args _ => do
    let barSize ← match args[1]! with
      | .infix _ _ _ size _ => pure size
      | n => wrongNode "infix" (some n)
    let some bs := barSize | ierr "\\\\abovefrac expected size, but got undefined"
    return .genfrac (← curMode) .absent false args[0]! args[2]! (bs.number > 0) none none
      (some bs)
  | "\\hbox" => some fun _ _ args _ => do
    return .hbox (← curMode) .absent args[0]!.ordargument
  | "\\overbrace" => some fun _ c args _ => do
    return .horizBrace (← curMode) .absent c.funcName ((c.funcName.splitOn "\\over").length > 1)
      args[0]!
  | "\\href" => some fun _ _ args _ => do
    let href ← expectUrl args[0]!
    if !(← isTrusted (some href)) then formatUnsupportedCmd "\\href"
    else return .href (← curMode) .absent href args[1]!.ordargument
  | "\\url" => some fun _ _ args _ => do
    let href ← expectUrl args[0]!
    if !(← isTrusted (some href)) then formatUnsupportedCmd "\\url"
    else
      let chars := href.toList.toArray.map fun ch =>
        Node.sym .text .absent .textord (if ch == '~' then "\\textasciitilde" else ch.toString)
      let m ← curMode
      return .href m .absent href #[.text m .absent chars (some "\\texttt")]
  | "\\htmlClass" => some fun _ c args _ => do
    let value ← expectRaw args[0]!
    reportStrict "htmlExtension" "HTML extension is disabled on strict mode"
    let attributes ← match c.funcName with
      | "\\htmlClass" => pure #[("class", value)]
      | "\\htmlId" => pure #[("id", value)]
      | "\\htmlStyle" => pure #[("style", value)]
      | _ => htmlData value
    if !(← isTrusted none) then formatUnsupportedCmd c.funcName
    else return .html (← curMode) .absent attributes args[1]!.ordargument
  | "\\html@mathml" => some fun _ _ args _ => do
    return .htmlmathml (← curMode) .absent args[0]!.ordargument args[1]!.ordargument
  | "\\includegraphics" => some fun _ _ args opt => do
    let mut width : Measurement := ⟨0, "em"⟩
    let mut height : Measurement := ⟨0.9, "em"⟩
    let mut totalheight : Measurement := ⟨0, "em"⟩
    let mut alt := ""
    if let some o := opt[0]! then
      let attrs ← expectRaw o
      for a in attrs.splitOn "," do
        let kv := a.splitOn "="
        if kv.length == 2 then
          let str := jsTrim kv[1]!
          match jsTrim kv[0]! with
          | "alt" => alt := str
          | "width" => width ← sizeData str
          | "height" => height ← sizeData str
          | "totalheight" => totalheight ← sizeData str
          | _ => perr s!"Invalid key: '{kv[0]!}' in \\includegraphics."
    let src ← expectUrl args[0]!
    if alt.isEmpty then
      let cs := src.toList
      -- `^.*[\\/]`: up to the last slash or backslash before the first line break
      let line := cs.takeWhile fun ch => !(ch == '\n' || ch == '\r' || ch.val == 0x2028 ||
        ch.val == 0x2029)
      let cut := (line.zipIdx.filter fun (ch, _) => ch == '/' || ch == '\\').getLast?.map
        (·.2 + 1)
      let rest := cs.drop (cut.getD 0)
      let lastDot := (rest.zipIdx.filter (·.1 == '.')).getLast?.map (·.2)
      alt := String.ofList (rest.take (lastDot.getD 0))
    if !(← isTrusted (some src)) then formatUnsupportedCmd "\\includegraphics"
    else return .includegraphics (← curMode) .absent alt width height totalheight src
  | "\\kern" => some fun _ c args _ => do
    let v ← expectSize args[0]!
    let mathFunction := c.funcName.toList[1]? == some 'm'
    let muUnit := v.unit == "mu"
    if mathFunction then
      if !muUnit then
        reportStrict "mathVsTextUnits"
          s!"LaTeX's {c.funcName} supports only mu units, not {v.unit} units"
      if (← curMode) != .math then
        reportStrict "mathVsTextUnits" s!"LaTeX's {c.funcName} works only in math mode"
    else if muUnit then
      reportStrict "mathVsTextUnits" s!"LaTeX's {c.funcName} doesn't support mu units"
    return .kern (← curMode) .absent v
  | "\\mathllap" => some fun _ c args _ => do
    return .lap (← curMode) .absent (c.funcName.drop 5).toString args[0]!
  | "\\(" => some fun ops c _ _ => do
    let outer ← curMode
    switchMode .math
    let close := if c.funcName == "\\(" then "\\)" else "$"
    let body ← ops.parseExpression false (some close)
    expect close
    switchMode outer
    return .styling (← curMode) .absent "text" (some true) body
  | "\\)" => some fun _ c _ _ => perr s!"Mismatched {c.funcName}"
  | "\\mathchoice" => some fun _ _ args _ => do
    return .mathchoice (← curMode) .absent args[0]!.ordargument args[1]!.ordargument
      args[2]!.ordargument args[3]!.ordargument
  | "\\mathord" => some fun _ c args _ => do
    return .mclass (← curMode) .absent ("m" ++ (c.funcName.drop 5).toString)
      args[0]!.ordargument (isCharacterBox args[0]!)
  | "\\@binrel" => some fun _ _ args _ => do
    return .mclass (← curMode) .absent (binrelClass args[0]!) args[1]!.ordargument
      (isCharacterBox args[1]!)
  | "\\stackrel" => some fun _ c args _ => do
    let baseArg := args[1]!
    let shifted := args[0]!
    let mclass := if c.funcName != "\\stackrel" then binrelClass baseArg else "mrel"
    let baseOp := Node.op baseArg.mode .absent true (some true) (some (c.funcName != "\\stackrel"))
      false false none (some baseArg.ordargument)
    let supsub := if c.funcName == "\\underset" then
        Node.supsub shifted.mode .absent (some baseOp) none (some shifted)
      else Node.supsub shifted.mode .absent (some baseOp) (some shifted) none
    return .mclass (← curMode) .absent mclass #[supsub] (isCharacterBox supsub)
  | "\\coprod" => some fun _ c _ _ => do
    return .op (← curMode) .absent true none none false true (some (singleCharOp c.funcName))
      none
  | "\\mathop" => some fun _ _ args _ => do
    return .op (← curMode) .absent false none none false false none (some args[0]!.ordargument)
  | "\\arcsin" => some fun _ c _ _ => do
    return .op (← curMode) .absent false none none false false (some c.funcName) none
  | "\\det" => some fun _ c _ _ => do
    return .op (← curMode) .absent true none none false false (some c.funcName) none
  | "\\int" => some fun _ c _ _ => do
    return .op (← curMode) .absent false none none false true (some (singleCharOp c.funcName))
      none
  | "\\operatorname@" => some fun _ c args _ => do
    return .operatorname (← curMode) .absent args[0]!.ordargument
      (c.funcName == "\\operatornamewithlimits") false false
  | "\\overline" => some fun _ _ args _ => do return .overline (← curMode) .absent args[0]!
  | "\\phantom" => some fun _ _ args _ => do
    return .phantom (← curMode) .absent args[0]!.ordargument
  | "\\vphantom" => some fun _ _ args _ => do return .vphantom (← curMode) .absent args[0]!
  | "\\pmb" => some fun _ _ args _ => do
    return .pmb (← curMode) .absent (binrelClass args[0]!) args[0]!.ordargument
  | "\\raisebox" => some fun _ _ args _ => do
    let dy ← expectSize args[0]!
    return .raisebox (← curMode) .absent dy args[1]!
  | "\\reflectbox" | "\\mathreflectbox" => some fun _ _ args _ => do
    return .reflectbox (← curMode) .absent args[0]!
  | "\\relax" => some fun _ _ _ _ => do return .internal (← curMode) .absent
  | "\\rule" => some fun _ _ args opt => do
    let shift ← match opt[0]! with
      | some n => some <$> expectSize n
      | none => pure none
    let w ← expectSize args[0]!
    let h ← expectSize args[1]!
    return .rule (← curMode) .absent shift w h
  | "\\tiny" => some fun ops c _ _ => do
    let body ← ops.parseExpression false c.breakOnTokenText
    let size := (sizeFuncs.findIdx? (· == c.funcName)).getD 0 + 1
    return .sizing (← curMode) .absent size body
  | "\\smash" => some fun _ _ args opt => do
    let mut smashHeight := false
    let mut smashDepth := false
    match opt[0]! with
    | some (.ordgroup _ _ body _) =>
      for n in body do
        let some letter := n.symText?
          | ierr s!"Expected node of symbol group type, but got node of type {n.type}"
        if letter == "t" then smashHeight := true
        else if letter == "b" then smashDepth := true
        else
          smashHeight := false
          smashDepth := false
          break
    | some n => wrongNode "ordgroup" (some n)
    | none =>
      smashHeight := true
      smashDepth := true
    return .smash (← curMode) .absent args[0]! smashHeight smashDepth
  | "\\sqrt" => some fun _ _ args opt => do
    return .sqrt (← curMode) .absent args[0]! opt[0]!
  | "\\displaystyle" => some fun ops c _ _ => do
    let body ← ops.parseExpression true c.breakOnTokenText
    let style := ((c.funcName.drop 1).dropEnd 5).toString
    return .styling (← curMode) .absent style none body
  | "\\text" => some fun _ c args _ => do
    return .text (← curMode) .absent args[0]!.ordargument (some c.funcName)
  | "\\underline" => some fun _ _ args _ => do return .underline (← curMode) .absent args[0]!
  | "\\vcenter" => some fun _ _ args _ => do return .vcenter (← curMode) .absent args[0]!
  | "\\verb" => some fun _ _ _ _ =>
    perr "\\verb ended by end of line instead of matching delimiter"
  | "\\hline" => some fun _ c _ _ => perr s!"{c.funcName} valid only within array environment"
  | "\\\\cdleft" => some fun _ c args _ => do
    return .cdlabel (← curMode) .absent (c.funcName.drop 4).toString args[0]!
  | "\\\\cdparent" => some fun _ _ args _ => do
    return .cdlabelparent (← curMode) .absent args[0]!
  | _ => none
where
  /-- `\htmlData`'s comma-separated `key=value` list; `{,}` is a literal comma. -/
  htmlData (value : String) : M (Array (String × String)) := do
    let cs := value.toList.toArray
    let mut items : Array String := #[]
    let mut cur := ""
    let mut i := 0
    while i < cs.size do
      if cs[i]! == '{' && cs[i + 1]? == some ',' && cs[i + 2]? == some '}' then
        cur := cur.push ','
        i := i + 3
      else if cs[i]! == ',' then
        items := items.push cur
        cur := ""
        i := i + 1
      else
        cur := cur.push cs[i]!
        i := i + 1
    items := items.push cur
    let mut attrs : Array (String × String) := #[]
    for item in items do
      match item.splitOn "=" with
      | [_] => perr s!"\\htmlData key/value '{item}' missing equals sign"
      | k :: rest =>
        let key := "data-" ++ jsTrim k
        let v := "=".intercalate rest
        attrs := match attrs.findIdx? (·.1 == key) with
          | some j => attrs.set! j (key, v)
          | none => attrs.push (key, v)
      | [] => pure ()
    return attrs

end LeAnTeX
