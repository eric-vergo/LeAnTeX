/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Text.Source
import LeAnTeX.Text.Font
import LeAnTeX.Text.Pack
import LeAnTeX.Layout.Build
import LeAnTeX.Layout.Display

/-!
# Typesetting text

The text layer's front end: LaTeX source in, paragraphs broken into lines out. It reads the
source as TeX does (tokens, macros, groups), builds each paragraph's horizontal list (glyphs
through the caller's fonts, interword glue with TeX's space factors, hyphenation points,
formulas through the math layout), breaks it with TeX's line breaker and stacks the lines with
TeX's interline glue.

## What is understood

* Paragraphs: an empty line or `\par` ends one; `\noindent`, `\indent`; `\\` (and `\newline`)
  ends a line; `\vspace{…}` between paragraphs, `\vspace` inside one taking effect after it.
* Spaces: `~`, `\ `, `\,`, `\quad`, `\qquad`, `\enspace`, `\hspace{…}` (and `\hspace*`),
  `\hfill`, `\hfil`, `\hss`, `\hskip`, `\kern`, `\penalty`, `\nobreak`, `\break`,
  `\allowbreak`, `\-`, `\relax`, `\/` (an italic correction of 0).
* Fonts: `\textrm`, `\textsf`, `\texttt`, `\textbf`, `\textmd`, `\textit`, `\textsl`, `\textsc`,
  `\textup`, `\textnormal`, `\emph` (italic inside upright and upright inside italic), the
  declarations `\rmfamily`, `\sffamily`, `\ttfamily`, `\bfseries`, `\mdseries`, `\itshape`,
  `\slshape`, `\scshape`, `\upshape`, `\normalfont`, `\em`; sizes `\tiny` … `\Huge` (LaTeX's
  ten-point classes) and `\fontsize{…}{…}\selectfont`. Fonts are found by the caller's
  `FontResolver`.
* Boxes: `\hbox{…}`, `\mbox{…}`: unbreakable material at its natural width.
* Formulas: `$…$`, `\(…\)` in a line; `\[…\]`, `$$…$$` displayed, centred on a line of their
  own; laid out by LeAnTeX's math layout at the size of the current font.
* Macros: `\newcommand`, `\renewcommand`, `\providecommand` (with their `*` forms), with up to
  nine parameters and a default for the first; `\def` with undelimited parameters `#1`…`#9`.
  Definitions are local to the group they are made in. Text macros are also defined for the
  formulas (except those with a default argument).
* Parameters: `\hsize`, `\textwidth`, `\linewidth`, `\parindent`, `\emergencystretch`,
  `\hangindent` (dimensions); `\tolerance`, `\pretolerance`, `\looseness`, `\linepenalty`,
  `\hyphenpenalty`, `\exhyphenpenalty`, `\adjdemerits`, `\doublehyphendemerits`,
  `\finalhyphendemerits`, `\hangafter`, `\lefthyphenmin`, `\righthyphenmin` (integers);
  `\leftskip`, `\rightskip`, `\parfillskip`, `\baselineskip`, `\parskip` (glue), and
  `\parshape`; assigned as TeX assigns them (`\tolerance=500`) or with `\setlength`. Local to
  groups, as in TeX; the paragraph shape is reset after each paragraph.
* Escaped characters `\%`, `\&`, `\#`, `\$`, `\_`, `\{`, `\}`, and `\textbackslash`.

Everything else is an error naming the command: environments, lists and sectioning,
counters, references, floats, tables, accents (`\'e`), `\vadjust`, `\vbox`, and TeX's
programming primitives. Source is untrusted: the source length, the number of tokens all
macro expansions produce together (`Settings.maxTokens`), the number of expansions and the
nesting of groups and boxes are capped, and past a cap the result is an error, never a hang.

## Main definitions

* `FontKey`, `FontResolver`: what the caller supplies to name fonts.
* `Settings`: the caps and the hyphenation patterns.
* `typeset`: source to a `Document`.
* `Document`: the fonts used, the lines with their positions, warnings.

## Implementation notes

TeX's space factor: a character's `\sfcode` (999 for capitals, 3000 after `.`, `?`, `!`, 2000
after `:`, 1500 after `;`, 1250 after `,`, 0 for `)`, `]`, `'` and closing quotes, which leave
it unchanged, 1000 otherwise) sets it, with TeX's rule that a code above 1000 right after a
capital gives 1000. A space is set from the current font at the current space factor.
Hyphenation is applied as LuaTeX applies it (found against its output): to every run of
letters (`Char.isAlpha` and the Latin letters of U+00C0–U+024F) that starts the list or follows
a glue, a box or a character that is not a letter, but not one that follows a penalty, a kern,
a discretionary or an explicit hyphen, with the current minima; a word whose letters are split
over a font change is cut there.
-/

namespace LeAnTeX.Text

/-- A font family. -/
inductive Family where
  /-- Roman. -/
  | roman
  /-- Sans serif. -/
  | sans
  /-- Typewriter. -/
  | mono
  deriving BEq, Hashable, Inhabited, Repr

/-- A font shape. -/
inductive Shape where
  /-- Upright. -/
  | upright
  /-- Italic. -/
  | italic
  /-- Slanted. -/
  | slanted
  /-- Small capitals. -/
  | caps
  deriving BEq, Hashable, Inhabited, Repr

/-- The font asked for: family, series, shape and size (sp). -/
structure FontKey where
  /-- The family. -/
  family : Family := .roman
  /-- Bold. -/
  bold : Bool := false
  /-- The shape. -/
  shape : Shape := .upright
  /-- The size, in sp. -/
  size : Int := 10 * 65536
  deriving BEq, Hashable, Inhabited, Repr

/-- How the caller names fonts: the font to use for a key, `none` if there is none (an error
when text needs it). -/
abbrev FontResolver := FontKey → Option FontInfo

/-- The caps on the work, and the language. -/
structure Settings where
  /-- The most characters of source. -/
  maxSource : Nat := 4000000
  /-- The most tokens all macro expansions produce together. -/
  maxTokens : Nat := 1000000
  /-- The most macro expansions. -/
  maxExpansions : Nat := 100000
  /-- The deepest nesting of groups and boxes. -/
  maxDepth : Nat := 200
  /-- The hyphenation patterns (`Patterns.english`, LaTeX's default). -/
  patterns : Patterns := Patterns.english
  /-- Whether to hyphenate at all. -/
  hyphenate : Bool := true
  /-- The settings for formulas; the text's macros are added to them. -/
  math : LeAnTeX.Settings := {}

/-- A macro: its number of parameters, the default of its first (for an optional first
argument), and its body. -/
structure Macro where
  /-- The number of parameters. -/
  params : Nat
  /-- The default of the optional first argument, if it is optional. -/
  default : Option (Array Tok) := none
  /-- The body, with `Tok.param` for the parameters. -/
  body : Array Tok
  deriving Inhabited

/-- The values that groups keep local: the font, the macros and TeX's parameters. -/
structure Vars where
  /-- The current font. -/
  key : FontKey := {}
  /-- The macros. -/
  macros : Std.HashMap String Macro := {}
  /-- The line breaker's parameters. -/
  p : Params := {}
  /-- `\hyphenpenalty`. -/
  hyphenPenalty : Int := 50
  /-- `\exhyphenpenalty`. -/
  exHyphenPenalty : Int := 50
  /-- `\lefthyphenmin`. -/
  leftHyphenMin : Int := 2
  /-- `\righthyphenmin`. -/
  rightHyphenMin : Int := 3
  /-- `\parindent`. -/
  parIndent : Int := 15 * 65536
  /-- `\parfillskip`. -/
  parFillSkip : Glue := { stretch := 65536, stretchOrder := 1 }
  /-- `\baselineskip`. -/
  baselineSkip : Glue := { width := 12 * 65536 }
  /-- `\parskip`. -/
  parSkip : Glue := { stretch := 65536 }
  /-- `\lineskip`. -/
  lineSkip : Glue := { width := 65536 }
  /-- `\lineskiplimit`. -/
  lineSkipLimit : Int := 0
  deriving Inhabited

/-- Why source could not be typeset: a message and the source offset (in characters) of the
token it is about, if known. -/
structure TypesetError where
  /-- The message. -/
  message : String
  /-- The offset in the source. -/
  pos : Nat := 0
  deriving Inhabited, Repr

/-- A set document: its fonts (as the glyph nodes index them: the font and the size), its lines
with their positions (`Line.indent` from the left margin, `y` the baseline below the first
line's), its width (`\hsize` of the last paragraph) and the warnings. -/
structure Document where
  /-- The fonts, as glyph nodes index them. -/
  fonts : Array (FontInfo × Int) := #[]
  /-- The lines, each with its baseline below the first line's. -/
  lines : Array (Line × Int) := #[]
  /-- The width of the text. -/
  width : Int := 0
  /-- Each paragraph's horizontal list as the line breaker received it. -/
  paragraphs : Array (Array HNode) := #[]
  /-- Warnings (overfull lines, glue made finite). -/
  warnings : Array String := #[]

namespace Typeset

/-- A box being built: the depth of the group it closes with, and the list and space factor
outside it. -/
structure BoxFrame where
  /-- The group depth when the box began. -/
  depth : Nat
  /-- The horizontal list outside the box. -/
  outer : Array HNode
  /-- The space factor outside the box. -/
  sf : Nat
  /-- Whether the box began in vertical mode (it then starts a paragraph). -/
  wasVertical : Bool

/-- The front end's state. -/
structure St where
  /-- The tokens still to read, the next last. -/
  input : Array Tok
  /-- Tokens the expansions produced. -/
  produced : Nat := 0
  /-- Expansions done. -/
  expansions : Nat := 0
  /-- The group stack; the last is current. -/
  groups : Array Vars
  /-- Boxes being built, innermost last. -/
  boxes : Array BoxFrame := #[]
  /-- Whether a paragraph is being built. -/
  hmode : Bool := false
  /-- The current horizontal list. -/
  hlist : Array HNode := #[]
  /-- Characters not yet set, in the font `runKey`. -/
  run : Array Char := #[]
  /-- The font of `run`. -/
  runKey : FontKey := {}
  /-- The space factor. -/
  sf : Nat := 1000
  /-- The fonts used, and their indices. -/
  fonts : Array (FontInfo × Int) := #[]
  /-- The index of each font used, by key. -/
  fontIndex : Std.HashMap FontKey Nat := {}
  /-- The lines set. -/
  lines : Array (Line × Int) := #[]
  /-- The bottom of the last box stacked, and its depth (`none` before the first). -/
  cursor : Int := 0
  /-- The depth of the last box stacked. -/
  prevDepth : Option Int := none
  /-- Vertical space to add after the paragraph being built. -/
  pendingSkip : Int := 0
  /-- Whether the next paragraph starts without its indentation. -/
  noIndent : Bool := false
  /-- Warnings. -/
  warnings : Array String := #[]
  /-- The width of the text. -/
  width : Int := 0
  /-- The paragraphs' horizontal lists. -/
  paragraphs : Array (Array HNode) := #[]

/-- The front end's monad. -/
abbrev M := ReaderT (Settings × FontResolver) (StateT St (Except TypesetError))

/-- Fails with a message about token `t`. -/
def failAt {α : Type} (t : Tok) (msg : String) : M α := throw { message := msg, pos := t.pos }

/-- Fails with a message. -/
def fail {α : Type} (msg : String) : M α := throw { message := msg }

/-- The current group's values. -/
def vars : M Vars := do return (← get).groups.back?.getD {}

/-- Changes the current group's values. -/
def modifyVars (f : Vars → Vars) : M Unit :=
  modify fun s => { s with groups := s.groups.modify (s.groups.size - 1) f }

/-- The next token, unexpanded. -/
def next? : M (Option Tok) := do
  let s ← get
  match s.input.back? with
  | some t => set { s with input := s.input.pop }; return some t
  | none => return none

/-- Puts tokens back to be read next, in order. -/
def unread (ts : Array Tok) : M Unit :=
  modify fun s => { s with input := s.input ++ ts.reverse }

/-- The next token that is not a space. -/
def nextNonSpace? : M (Option Tok) := do
  for _ in [0:(← get).input.size + 1] do
    match ← next? with
    | some t => if !t.isSpace then return some t
    | none => return none
  return none

/-- Reads a balanced group's tokens after its `{` was read. -/
def readGroupBody (open_ : Tok) : M (Array Tok) := do
  let mut out := #[]
  let mut depth := 1
  for _ in [0:(← get).input.size + 1] do
    match ← next? with
    | none => failAt open_ "Missing } inserted (runaway argument)"
    | some t =>
      if t.isBegin then depth := depth + 1
      else if t.isEnd then
        depth := depth - 1
        if depth == 0 then return out
      out := out.push t
  failAt open_ "Missing } inserted (runaway argument)"

/-- Reads a macro argument: a balanced group's contents, or one token. -/
def readArg (at_ : Tok) : M (Array Tok) := do
  match ← nextNonSpace? with
  | none => failAt at_ "Missing argument"
  | some t =>
    if t.isBegin then readGroupBody t
    else if t.isEnd then failAt t "Argument of a command ends the group (missing argument)"
    else return #[t]

/-- Reads an optional argument `[…]` (balanced in braces), if one follows. -/
def readOptional? : M (Option (Array Tok)) := do
  match ← nextNonSpace? with
  | some t@(.char '[' 12 _) =>
    let mut out := #[]
    let mut depth := 0
    for _ in [0:(← get).input.size + 1] do
      match ← next? with
      | none => failAt t "Missing ] (runaway optional argument)"
      | some u =>
        if u.isBegin then depth := depth + 1
        if u.isEnd then depth := depth - 1
        if depth == 0 && u.isChar ']' 12 then return some out
        out := out.push u
    failAt t "Missing ] (runaway optional argument)"
  | some t => unread #[t]; return none
  | none => return none

/-- Whether a `*` follows (and reads it). -/
def readStar : M Bool := do
  match ← next? with
  | some (.char '*' 12 _) => return true
  | some t => unread #[t]; return false
  | none => return false

/-- Counts tokens an expansion produced against the caps. -/
def countExpansion (at_ : Tok) (n : Nat) : M Unit := do
  let (cfg, _) ← read
  let s ← get
  if s.produced + n > cfg.maxTokens then
    failAt at_ s!"Too many tokens: the macros expand to more than {cfg.maxTokens} tokens"
  if s.expansions + 1 > cfg.maxExpansions then
    failAt at_ s!"Too many expansions: more than {cfg.maxExpansions}"
  set { s with produced := s.produced + n, expansions := s.expansions + 1 }

/-- Expands macro `m` named by token `t`: reads its arguments and puts its body back with the
arguments in place of its parameters. -/
def expandMacro (t : Tok) (m : Macro) : M Unit := do
  let mut args : Array (Array Tok) := #[]
  if let some d := m.default then
    args := args.push ((← readOptional?).getD d)
  for _ in [args.size:m.params] do
    args := args.push (← readArg t)
  let body := m.body.foldl (init := #[]) fun acc b => match b with
    | .param n => acc ++ (args[n - 1]?.getD #[])
    | b => acc.push b
  countExpansion t body.size
  unread body

/-! ### Numbers, lengths and glue -/

/-- Reads a keyword (case-insensitive letters), spaces before it skipped; puts the tokens back
and answers `false` if it is not there. -/
def keyword (w : String) : M Bool := do
  let mut got := #[]
  match ← nextNonSpace? with
  | none => return false
  | some t => got := got.push t
  let ws := w.toList.toArray
  for i in [0:ws.size] do
    let want := (ws[i]?.getD ' ').toLower
    let t := got[i]?.getD (.param 0)
    match t with
    | .char c _ _ =>
      if c.toLower != want then unread got; return false
    | _ => unread got; return false
    if i + 1 < ws.size then
      match ← next? with
      | some u => got := got.push u
      | none => unread got; return false
  return true

/-- Reads an optional `=` (spaces around it skipped). -/
def skipEquals : M Unit := do
  match ← nextNonSpace? with
  | some (.char '=' 12 _) => pure ()
  | some t => unread #[t]
  | none => pure ()

/-- Reads one space, if one comes next (TeX's optional space after a number or unit). -/
def skipOneSpace : M Unit := do
  match ← next? with
  | some t => if !t.isSpace then unread #[t]
  | none => pure ()

/-- Reads signs: `true` if negative. -/
def readSigns : M Bool := do
  let mut neg := false
  for _ in [0:(← get).input.size + 1] do
    match ← nextNonSpace? with
    | some (.char '-' 12 _) => neg := !neg
    | some (.char '+' 12 _) => pure ()
    | some t => unread #[t]; break
    | none => break
  return neg

/-- Reads digits; their value and how many. -/
def readDigits : M (Nat × List Nat) := do
  let mut ds : List Nat := []
  for _ in [0:(← get).input.size + 1] do
    match ← next? with
    | some t@(.char c _ _) =>
      if c.isDigit then ds := ds ++ [c.toNat - '0'.toNat] else unread #[t]; break
    | some t => unread #[t]; break
    | none => break
  return (ds.foldl (fun a d => min (a * 10 + d) 0x7FFFFFFF) 0, ds)

/-- Reads an integer (TeX's `scan_int`, decimal only). -/
def readInt (at_ : Tok) : M Int := do
  let neg ← readSigns
  let (v, ds) ← readDigits
  if ds.isEmpty then failAt at_ "Missing number"
  skipOneSpace
  return if neg then -v else v

/-- The length of the internal dimension named by a control sequence, if it is one. -/
def dimenOf (name : String) : M (Option Int) := do
  let v ← vars
  return match name with
    | "hsize" | "textwidth" | "linewidth" | "columnwidth" => some v.p.hsize
    | "parindent" => some v.parIndent
    | "emergencystretch" => some v.p.emergencyStretch
    | "hangindent" => some v.p.hangIndent
    | "baselineskip" => some v.baselineSkip.width
    | "parskip" => some v.parSkip.width
    | "leftskip" => some v.p.leftSkip.width
    | "rightskip" => some v.p.rightSkip.width
    | "fill" => some 0
    | _ => none

/-- The current font's em (its size) and ex (its x-height, or half an em without one). -/
def fontUnits : M (Int × Int) := do
  let (_, resolve) ← read
  let key := (← vars).key
  let em := key.size
  -- the x-height as the height of the font's `x`
  let ex := match resolve key with
    | some info =>
      let h := (info.boxes[info.font.glyph 'x']?.map (·.1)).getD 0
      if h > 0 then Em.roundDiv (h * key.size) info.font.unitsPerEm else em / 2
    | none => em / 2
  return (em, ex)

/-- Reads a dimension (TeX's `scan_dimen`): a decimal number and a unit, or an internal
dimension, with an optional factor before it (`0.5\textwidth`). With `infinite`, `fil`,
`fill`, `filll` are units too and the order is returned. -/
def readDimen (at_ : Tok) (infinite : Bool := false) : M (Int × Nat) := do
  let neg ← readSigns
  let sign := fun (v : Int) => if neg then -v else v
  match ← nextNonSpace? with
  | some (.cs name _) =>
    match ← dimenOf name with
    | some v => return (sign v, 0)
    | none => failAt at_ s!"Missing number: \\{name} is not a length"
  | some t => unread #[t]
  | none => failAt at_ "Missing number"
  let (whole, ds) ← readDigits
  let mut frac : List Nat := []
  match ← next? with
  | some (.char '.' _ _) | some (.char ',' _ _) => frac := (← readDigits).2
  | some t => unread #[t]
  | none => pure ()
  if ds.isEmpty && frac.isEmpty then failAt at_ "Missing number"
  let f := (roundDecimals frac).toNat
  -- an internal dimension as the unit: the number is a factor
  match ← nextNonSpace? with
  | some u@(.cs name _) =>
    match ← dimenOf name with
    | some v => return (sign (Em.roundDiv (v * ((whole * 65536 + f : Nat) : Int)) 65536), 0)
    | none => unread #[u]
  | some u => unread #[u]
  | none => pure ()
  if infinite then
    if ← keyword "fil" then
      let mut order := 1
      for _ in [0:2] do
        if ← keyword "l" then order := order + 1
      skipOneSpace
      return (sign ((whole * 65536 + f : Nat) : Int), order)
  let (em, ex) ← fontUnits
  let times := fun (u : Int) => sign (Em.roundDiv (u * ((whole * 65536 + f : Nat) : Int)) 65536)
  if ← keyword "em" then skipOneSpace; return (times em, 0)
  if ← keyword "ex" then skipOneSpace; return (times ex, 0)
  let _ ← keyword "true"
  for u in ["pt", "pc", "in", "bp", "cm", "mm", "dd", "cc", "sp"] do
    if ← keyword u then
      skipOneSpace
      if u == "sp" then return (sign whole, 0)
      let (num, den) := (unitRatio u).getD (1, 1)
      return (sign (scaleUnit whole f num den), 0)
  failAt at_ "Illegal unit of measure (pt inserted)"

/-- Reads glue: a dimension with optional `plus` and `minus` parts. -/
def readGlue (at_ : Tok) : M Glue := do
  let (w, _) ← readDimen at_
  let mut g : Glue := { width := w }
  if ← keyword "plus" then
    let (s, o) ← readDimen at_ true
    g := { g with stretch := s, stretchOrder := o }
  if ← keyword "minus" then
    let (s, o) ← readDimen at_ true
    g := { g with shrink := s, shrinkOrder := o }
  return g

/-- Reads glue from a whole argument (`\hspace{…}`, `\setlength{…}{…}`): `\fill` alone is
`0pt plus 1fill`; `\stretch{n}` is `0pt plus n fill`. -/
def readGlueArg (at_ : Tok) : M Glue := do
  let arg ← readArg at_
  match arg.toList.filter (!·.isSpace) with
  | [.cs "fill" _] => return { stretch := 65536, stretchOrder := 2 }
  | [.cs "hfill" _] => return { stretch := 65536, stretchOrder := 2 }
  | _ =>
    let saved := (← get).input
    modify fun s => { s with input := arg.reverse }
    let g ← readGlue at_
    let rest := (← get).input
    modify fun s => { s with input := saved }
    if rest.any (!·.isSpace) then failAt at_ "Extra tokens in a length"
    return g

/-! ### Fonts and the horizontal list -/

/-- The font for a key, registered in the document's table. -/
def fontFor (key : FontKey) : M TextFont := do
  let (_, resolve) ← read
  let some info := resolve key
    | fail s!"No font for {repr key.family}, bold {key.bold}, {repr key.shape}, \
        {key.size} sp"
  let s ← get
  match s.fontIndex[key]? with
  | some i => return { info, size := key.size, index := i }
  | none =>
    let i := s.fonts.size
    set { s with fonts := s.fonts.push (info, key.size), fontIndex := s.fontIndex.insert key i }
    return { info, size := key.size, index := i }

/-- Whether a character is a letter for hyphenation. -/
def isLetter (c : Char) : Bool :=
  c.isAlpha || (c.toNat ≥ 0xC0 && c.toNat ≤ 0x24F && c.toNat != 0xD7 && c.toNat != 0xF7)

/-- A run split at its explicit hyphens. -/
def splitHyphens (cs : Array Char) : List (List Char) :=
  let (done, cur) := cs.foldl (init := (#[], #[])) fun (done, cur) c =>
    if c == '-' then (done.push cur.toList, #[]) else (done, cur.push c)
  (done.push cur.toList).toList

/-- Sets the pending characters into the horizontal list. -/
def flushRun : M Unit := do
  let s ← get
  if s.run.isEmpty then return
  let (cfg, _) ← read
  let v ← vars
  let tf ← fontFor s.runKey
  -- a monospaced font has neither TeX's ligatures nor hyphenation (LaTeX's typewriter
  -- families load it without them and set no hyphen character)
  let cs := if tf.info.mono then s.run else texLigatures s.run
  -- the words LuaTeX hyphenates: runs of letters that start the list, follow a glue or a
  -- box, or follow a character that is not a letter (other than an explicit hyphen); not
  -- those right after a penalty, a kern or a discretionary
  let before := match s.hlist.back? with
    | none | some (.glue ..) | some (.box ..) => true
    | _ => false
  let mut words : Array (Nat × Nat) := #[]
  if cfg.hyphenate && !tf.info.mono then
    let mut i := 0
    for _ in [0:cs.size + 1] do
      if i ≥ cs.size then break
      if isLetter (cs[i]?.getD ' ') then
        let mut j := i
        for _ in [i:cs.size] do
          if isLetter (cs[j]?.getD ' ') then j := j + 1 else break
        let ok := if i == 0 then before else cs[i - 1]?.getD '-' != '-'
        if ok then words := words.push (i, j)
        i := j
      else i := i + 1
  -- explicit hyphens split the run into parts
  let mut out := #[]
  let parts := splitHyphens cs
  let mut off := 0
  for h : k in [0:parts.length] do
    let part := parts[k].toArray
    let mut points := #[]
    for (i, j) in words do
      if off ≤ i && j ≤ off + part.size then
        let w := String.ofList (cs.extract i j).toList
        for p in cfg.patterns.points w v.leftHyphenMin.toNat v.rightHyphenMin.toNat do
          points := points.push (i - off + p)
    out := out ++ tf.shapeRun part points v.hyphenPenalty
    if k + 1 < parts.length then
      let hy := tf.shape #['-']
      out := out.push (.disc v.exHyphenPenalty hy #[] hy .automatic)
    off := off + part.size + 1
  set { (← get) with hlist := (← get).hlist ++ out, run := #[] }

/-- Appends a node to the horizontal list (after the pending characters). -/
def push (n : HNode) : M Unit := do
  flushRun
  modify fun s => { s with hlist := s.hlist.push n }

/-- The space factor code of a character (LaTeX's `\nonfrenchspacing`). -/
def sfCode (c : Char) : Nat :=
  if c.isUpper then 999
  else match c with
    | '.' | '?' | '!' => 3000 | ':' => 2000 | ';' => 1500 | ',' => 1250
    | ')' | ']' | '\'' | '’' | '”' => 0
    | _ => 1000

/-! ### Paragraphs and the vertical list -/

/-- Stacks a box of `height` and `depth` with TeX's interline glue; returns its baseline. -/
def stack (height depth : Int) : M Int := do
  let v ← vars
  let s ← get
  let base := match s.prevDepth with
    | none => s.cursor + height
    | some pd =>
      let gap := v.baselineSkip.width - pd - height
      let gap := if gap < v.lineSkipLimit then v.lineSkip.width else gap
      s.cursor + gap + height
  set { s with cursor := base + depth, prevDepth := some depth }
  return base

/-- Starts a paragraph (in vertical mode), with its indentation unless `\noindent` said not. -/
def startParagraph : M Unit := do
  let s ← get
  if s.hmode then return
  let v ← vars
  let indent := if s.noIndent then #[] else #[HNode.box v.parIndent 0 0 0 #[]]
  let cursor := if s.prevDepth.isSome then s.cursor + v.parSkip.width else s.cursor
  set { s with hmode := true, hlist := indent, sf := 1000, noIndent := false, cursor }

/-- Ends the paragraph being built: TeX's `\par`: the list's last glue removed,
`\penalty10000\parfillskip` appended, the lines broken, set and stacked. -/
def endParagraph : M Unit := do
  flushRun
  let s ← get
  if !s.hmode || !s.boxes.isEmpty then return
  let v ← vars
  let mut items := s.hlist
  if let some (.glue ..) := items.back? then items := items.pop
  items := items.push (.penalty 10000) |>.push (.glue v.parFillSkip 15)
  set { s with hmode := false, hlist := #[], paragraphs := s.paragraphs.push items }
  -- TeX resets the paragraph shape after every paragraph
  modifyVars fun x => { x with p := { x.p with hangIndent := 0, hangAfter := 1, parShape := #[] } }
  match breakParagraph items v.p with
  | .error e => fail s!"paragraph: {e.message}"
  | .ok r =>
    modify fun s => { s with warnings := s.warnings ++ r.warnings, width := v.p.hsize }
    for l in setLines items v.p r.breaks do
      if l.glue.sign == 2 && l.glue.ratio == 1 && l.natural > l.width then
        let msg := s!"overfull line by {l.natural - l.width} sp"
        modify fun s => { s with warnings := s.warnings.push msg }
      let y ← stack l.height l.depth
      modify fun s => { s with lines := s.lines.push (l, y) }
  let skip := (← get).pendingSkip
  modify fun s => { s with cursor := s.cursor + skip, pendingSkip := 0 }

/-- Adds vertical space: between paragraphs at once, inside one after it. -/
def vspace (w : Int) : M Unit := do
  if (← get).hmode then modify fun s => { s with pendingSkip := s.pendingSkip + w }
  else modify fun s => { s with cursor := s.cursor + w }

/-- The text macros as KaTeX macro definitions, for formulas. -/
def mathMacros : M (Array (String × String)) := do
  let v ← vars
  return v.macros.toArray.filterMap fun (name, m) =>
    if m.default.isSome then none
    else some ("\\" ++ name, String.join (m.body.toList.map Tok.text))

/-- Lays out a formula at the current size; a math node (or an error). -/
def formula (at_ : Tok) (src : String) (display : Bool) : M HNode := do
  let (cfg, _) ← read
  let size := (← vars).key.size
  let settings := { cfg.math with
    displayMode := display, macros := cfg.math.macros ++ (← mathMacros) }
  match (LeAnTeX.layout src settings).result with
  | .error e =>
    let msg := match e with
      | .katex k => k.message
      | .unsupported w => s!"unsupported in math: {w}"
    failAt at_ s!"formula: {msg}"
  | .ok b =>
    let dl := DisplayList.ofBox b
    -- the record of the whole formula, with its source (fields in order: items, box, source)
    let whole : Formula := ⟨0, dl.items.size, 0, 0, dl.width, dl.height, dl.depth, src, display⟩
    let dl := { dl with formulas := #[whole] }
    let sc := fun (e : Em) => Em.roundDiv (e.raw * size) Em.unit
    return .math (sc dl.width) (sc dl.height) (sc dl.depth) dl size

/-- Reads a formula's source up to its closing delimiter (`$`, `$$`, `\)` or `\]`). -/
def readFormula (at_ : Tok) (close : Tok → Bool) (double : Bool) : M String := do
  let mut out := ""
  for _ in [0:(← get).input.size + 1] do
    match ← next? with
    | none => failAt at_ "Missing $ inserted (formula not closed)"
    | some t =>
      if close t then
        if double then
          match ← next? with
          | some u => if !close u then failAt u "Display math should end with $$"
          | none => failAt at_ "Display math should end with $$"
        return out
      out := out ++ t.text
  failAt at_ "Missing $ inserted (formula not closed)"

/-- Sets a displayed formula: the paragraph so far ends (TeX's display interrupts it), the
formula is centred on a line of its own with `\abovedisplayskip` and `\belowdisplayskip`
(LaTeX's ten-point values, 10pt above and below at their natural widths), and the paragraph
goes on without indentation. -/
def displayFormula (at_ : Tok) (src : String) : M Unit := do
  let wasH := (← get).hmode
  if wasH then endParagraph
  let n ← formula at_ src true
  let v ← vars
  let (w, h, d) := match n with | .math w h d _ _ => (w, h, d) | _ => (0, 0, 0)
  modify fun s => { s with cursor := s.cursor + 10 * 65536 }
  let y ← stack h d
  let line : Line :=
    { nodes := #[n], width := w, indent := (v.p.hsize - w) / 2, natural := w,
      height := h, depth := d, glue := {} }
  modify fun s => { s with lines := s.lines.push (line, y), cursor := s.cursor + 10 * 65536 }
  if wasH then
    modify fun s => { s with noIndent := true }
    startParagraph

/-! ### Groups and boxes -/

/-- Opens a group. -/
def beginGroup (at_ : Tok) : M Unit := do
  let (cfg, _) ← read
  let s ← get
  if s.groups.size + s.boxes.size > cfg.maxDepth then failAt at_ "Groups nested too deeply"
  set { s with groups := s.groups.push (s.groups.back?.getD {}) }

/-- Closes a group; a box that began with it is finished. -/
def endGroup (at_ : Tok) : M Unit := do
  let s ← get
  if s.groups.size ≤ 1 then failAt at_ "Too many }'s"
  match s.boxes.back? with
  | some fr =>
    if fr.depth == s.groups.size then
      flushRun
      let s ← get
      let content := s.hlist
      let (w, _, _, h, d) := measure content
      set { s with
        boxes := s.boxes.pop, hlist := fr.outer.push (.box w h d 0 content), sf := 1000,
        groups := s.groups.pop }
      return
  | none => pure ()
  flushRun
  modify fun s => { s with groups := s.groups.pop }

/-- Begins `\hbox{…}`: reads `{` and starts a list inside it. -/
def beginBox (at_ : Tok) : M Unit := do
  match ← nextNonSpace? with
  | some t =>
    if !t.isBegin then failAt t "A <box> was supposed to be here (missing {)"
  | none => failAt at_ "A <box> was supposed to be here"
  let wasVertical := !(← get).hmode
  startParagraph
  flushRun
  beginGroup at_
  modify fun s => { s with
    boxes := s.boxes.push { depth := s.groups.size, outer := s.hlist, sf := s.sf, wasVertical }
    hlist := #[] }

/-! ### Commands -/

/-- The font key after a declaration, if `name` is one. -/
def fontDecl (name : String) (k : FontKey) : Option FontKey :=
  let at10 := fun (pt : Nat) (hundredths : Nat) =>
    ({ k with size := (pt * 65536 + hundredths * 65536 / 100 : Nat) } : FontKey)
  match name with
  | "rmfamily" => some { k with family := .roman }
  | "sffamily" => some { k with family := .sans }
  | "ttfamily" => some { k with family := .mono }
  | "bfseries" => some { k with bold := true }
  | "mdseries" => some { k with bold := false }
  | "itshape" => some { k with shape := .italic }
  | "slshape" => some { k with shape := .slanted }
  | "scshape" => some { k with shape := .caps }
  | "upshape" => some { k with shape := .upright }
  | "normalfont" => some { family := .roman, bold := false, shape := .upright, size := k.size }
  | "em" => some { k with shape := if k.shape == .upright then .italic else .upright }
  | "tiny" => some (at10 5 0) | "scriptsize" => some (at10 7 0)
  | "footnotesize" => some (at10 8 0) | "small" => some (at10 9 0)
  | "normalsize" => some (at10 10 0) | "large" => some (at10 12 0)
  | "Large" => some (at10 14 40) | "LARGE" => some (at10 17 28)
  | "huge" => some (at10 20 74) | "Huge" => some (at10 24 88)
  | _ => none

/-- LaTeX's `\baselineskip` for a size command (the ten-point classes). -/
def sizeBaseline : String → Option Int
  | "tiny" => some (6 * 65536) | "scriptsize" => some (8 * 65536)
  | "footnotesize" => some (9 * 65536 + 32768) | "small" => some (11 * 65536)
  | "normalsize" => some (12 * 65536) | "large" => some (14 * 65536)
  | "Large" => some (18 * 65536) | "LARGE" => some (22 * 65536)
  | "huge" => some (25 * 65536) | "Huge" => some (30 * 65536)
  | _ => none

/-- The font command a `\text…` command stands for. -/
def textFontCommand : String → Option String
  | "textrm" => some "rmfamily" | "textsf" => some "sffamily" | "texttt" => some "ttfamily"
  | "textbf" => some "bfseries" | "textmd" => some "mdseries" | "textit" => some "itshape"
  | "textsl" => some "slshape" | "textsc" => some "scshape" | "textup" => some "upshape"
  | "textnormal" => some "normalfont" | "emph" => some "em"
  | _ => none

/-- Assigns an integer parameter. -/
def setInt (name : String) (v : Int) : M Bool := do
  let f : Option (Vars → Vars) := match name with
    | "tolerance" => some fun x => { x with p := { x.p with tolerance := v } }
    | "pretolerance" => some fun x => { x with p := { x.p with pretolerance := v } }
    | "looseness" => some fun x => { x with p := { x.p with looseness := v } }
    | "linepenalty" => some fun x => { x with p := { x.p with linePenalty := v } }
    | "adjdemerits" => some fun x => { x with p := { x.p with adjDemerits := v } }
    | "doublehyphendemerits" =>
      some fun x => { x with p := { x.p with doubleHyphenDemerits := v } }
    | "finalhyphendemerits" => some fun x => { x with p := { x.p with finalHyphenDemerits := v } }
    | "hangafter" => some fun x => { x with p := { x.p with hangAfter := v } }
    | "hyphenpenalty" => some fun x => { x with hyphenPenalty := v }
    | "exhyphenpenalty" => some fun x => { x with exHyphenPenalty := v }
    | "lefthyphenmin" => some fun x => { x with leftHyphenMin := max 1 v }
    | "righthyphenmin" => some fun x => { x with rightHyphenMin := max 1 v }
    | _ => none
  match f with
  | some f => modifyVars f; return true
  | none => return false

/-- Whether `name` is an integer parameter. -/
def isIntParam (name : String) : Bool :=
  ["tolerance", "pretolerance", "looseness", "linepenalty", "adjdemerits",
    "doublehyphendemerits", "finalhyphendemerits", "hangafter", "hyphenpenalty",
    "exhyphenpenalty", "lefthyphenmin", "righthyphenmin"].contains name

/-- Assigns a glue or dimension parameter (a dimension takes the glue's width). -/
def setGlue (name : String) (g : Glue) : M Bool := do
  let f : Option (Vars → Vars) := match name with
    | "hsize" | "textwidth" | "linewidth" | "columnwidth" =>
      some fun x => { x with p := { x.p with hsize := g.width } }
    | "parindent" => some fun x => { x with parIndent := g.width }
    | "emergencystretch" => some fun x => { x with p := { x.p with emergencyStretch := g.width } }
    | "hangindent" => some fun x => { x with p := { x.p with hangIndent := g.width } }
    | "leftskip" => some fun x => { x with p := { x.p with leftSkip := g } }
    | "rightskip" => some fun x => { x with p := { x.p with rightSkip := g } }
    | "parfillskip" => some fun x => { x with parFillSkip := g }
    | "baselineskip" => some fun x => { x with baselineSkip := g }
    | "parskip" => some fun x => { x with parSkip := g }
    | _ => none
  match f with
  | some f => modifyVars f; return true
  | none => return false

/-- Whether `name` is a glue parameter (its value may have `plus` and `minus`). -/
def isGlueParam (name : String) : Bool :=
  ["leftskip", "rightskip", "parfillskip", "baselineskip", "parskip"].contains name

/-- Whether `name` is a dimension parameter. -/
def isDimenParam (name : String) : Bool :=
  ["hsize", "textwidth", "linewidth", "columnwidth", "parindent", "emergencystretch",
    "hangindent"].contains name

/-- Reads the name of a macro being defined: `\name` or `{\name}`. -/
def readMacroName (at_ : Tok) : M String := do
  let arg ← readArg at_
  match arg.toList.filter (!·.isSpace) with
  | [.cs n _] => return n
  | _ => failAt at_ "Missing control sequence (a macro name was expected)"

/-- A macro body with `#n` as parameters, checked against the number of parameters. -/
def paramBody (body : Array Tok) (n : Nat) : M (Array Tok) := do
  let mut out := #[]
  let mut i := 0
  for _ in [0:body.size + 1] do
    if i ≥ body.size then break
    let t := body[i]?.getD (.param 0)
    match t with
    | .char '#' 6 _ =>
      match body[i + 1]? with
      | some (.char c _ _) =>
        if c.isDigit && c != '0' && c.toNat - '0'.toNat ≤ n then
          out := out.push (.param (c.toNat - '0'.toNat)); i := i + 2
        else if c == '#' then out := out.push (.char '#' 6 0); i := i + 2
        else failAt t s!"Illegal parameter number in definition of a macro"
      | _ => failAt t "Illegal parameter number in definition of a macro"
    | t => out := out.push t; i := i + 1
  return out

/-- `\newcommand`, `\renewcommand`, `\providecommand`: `kind` 0, 1, 2. -/
def newCommand (at_ : Tok) (kind : Nat) : M Unit := do
  let _ ← readStar
  let name ← readMacroName at_
  let n := match ← readOptional? with
    | some ts => (String.join (ts.toList.map Tok.text)).trimAscii.toString.toNat?
    | none => some 0
  let some n := n | failAt at_ "You already have nine parameters (bad number of parameters)"
  if n > 9 then failAt at_ "You already have nine parameters"
  let default ← if n > 0 then readOptional? else pure none
  let body ← readArg at_
  let body ← paramBody body n
  let exists_ := (← vars).macros.contains name || isBuiltin name
  if kind == 0 && exists_ then failAt at_ s!"Command \\{name} already defined"
  if kind == 1 && !exists_ then failAt at_ s!"Command \\{name} undefined"
  if kind == 2 && exists_ then return
  modifyVars fun v => { v with macros := v.macros.insert name { params := n, default, body } }
where
  /-- Whether the front end itself defines `name`. -/
  isBuiltin (name : String) : Bool :=
    (fontDecl name {}).isSome || (textFontCommand name).isSome || isIntParam name ||
      isGlueParam name || isDimenParam name ||
      ["par", "parshape", "noindent", "indent", "hbox", "mbox", "hspace", "vspace", "hfill",
        "hfil", "hss",
        "quad", "qquad", "enspace", "newline", "penalty", "kern", "hskip", "nobreak", "break",
        "allowbreak", "relax", "newcommand", "renewcommand", "providecommand", "def",
        "setlength", "fontsize", "selectfont", "textbackslash"].contains name

/-- `\def\name#1#2{body}`: undelimited parameters only. -/
def defMacro (at_ : Tok) : M Unit := do
  let some (.cs name _) ← nextNonSpace? | failAt at_ "Missing control sequence after \\def"
  let mut n := 0
  for _ in [0:10] do
    match ← next? with
    | some t@(.char '#' 6 _) =>
      match ← next? with
      | some (.char c _ _) =>
        if c.toNat == '0'.toNat + n + 1 then n := n + 1
        else failAt t "Parameters must be numbered consecutively"
      | _ => failAt t "Parameters must be numbered consecutively"
    | some t =>
      if t.isBegin then
        let body ← readGroupBody t
        let body ← paramBody body n
        modifyVars fun v => { v with macros := v.macros.insert name { params := n, body } }
        return
      else failAt t "Only undelimited parameters are supported in \\def"
    | none => failAt at_ "Missing { in \\def"
  failAt at_ "Too many parameters in \\def"

/-- Adds a character to the paragraph. -/
def addChar (c : Char) : M Unit := do
  startParagraph
  let v ← vars
  let s ← get
  if !s.run.isEmpty && s.runKey != v.key then flushRun
  let code := sfCode c
  modify fun s => { s with
    run := s.run.push c, runKey := v.key
    sf := if code == 0 then s.sf
      else if code ≤ 1000 || s.sf ≥ 1000 then code else 1000 }

/-- Adds an interword space at the current space factor (`sf`, 1000 for `\ `). -/
def addSpace (sf : Option Nat := none) : M Unit := do
  if !(← get).hmode then return
  let v ← vars
  let tf ← fontFor v.key
  flushRun
  let f := sf.getD (← get).sf
  modify fun s => { s with hlist := s.hlist.push (.glue (tf.space f) 13) }

/-- Carries out a control sequence. -/
def command (t : Tok) (name : String) : M Unit := do
  let v ← vars
  if let some m := v.macros[name]? then expandMacro t m; return
  if let some k := fontDecl name v.key then
    flushRun
    modifyVars fun x => { x with key := k }
    if let some b := sizeBaseline name then
      modifyVars fun x => { x with baselineSkip := { width := b } }
    return
  if let some decl := textFontCommand name then
    let arg ← readArg t
    countExpansion t (arg.size + 3)
    unread (#[Tok.char '{' 1 t.pos, .cs decl t.pos] ++ arg ++ #[.char '}' 2 t.pos])
    return
  if isIntParam name then
    skipEquals
    let _ ← setInt name (← readInt t)
    return
  if isGlueParam name then
    skipEquals
    let _ ← setGlue name (← readGlue t)
    return
  if isDimenParam name then
    skipEquals
    let (d, _) ← readDimen t
    let _ ← setGlue name { width := d }
    return
  let em := v.key.size
  match name with
  | "par" => endParagraph
  | "noindent" =>
    if !(← get).hmode then modify fun s => { s with noIndent := true }
  | "indent" =>
    if (← get).hmode then push (.box v.parIndent 0 0 0 #[]) else startParagraph
  | "hbox" | "mbox" => beginBox t
  | "\\" | "newline" =>
    let _ ← readStar
    let _ ← readOptional?
    if (← get).hmode then
      flushRun
      modify fun s => { s with hlist := match s.hlist.back? with
        | some (.glue ..) => s.hlist.pop | _ => s.hlist }
      push (.glue { stretch := 65536, stretchOrder := 1 } 0)
      push (.penalty (-10000))
  | "hspace" =>
    let _ ← readStar
    let g ← readGlueArg t
    startParagraph
    push (.glue g 0)
  | "vspace" =>
    let _ ← readStar
    let g ← readGlueArg t
    vspace g.width
  | "hfill" => startParagraph; push (.glue { stretch := 65536, stretchOrder := 2 } 0)
  | "hfil" => startParagraph; push (.glue { stretch := 65536, stretchOrder := 1 } 0)
  | "hss" =>
    startParagraph
    push (.glue { stretch := 65536, stretchOrder := 1, shrink := 65536, shrinkOrder := 1 } 0)
  | "quad" => startParagraph; push (.glue { width := em } 0)
  | "qquad" => startParagraph; push (.glue { width := 2 * em } 0)
  | "enspace" => startParagraph; push (.kern (em / 2) .explicit)
  | "," => startParagraph; push (.kern (em / 6) .explicit)
  | " " => startParagraph; addSpace (some 1000)
  | "/" => pure ()
  | "-" =>
    startParagraph
    let tf ← fontFor v.key
    push (.disc v.hyphenPenalty (tf.shape #['-']) #[] #[] .explicit)
  | "penalty" => let p ← readInt t; startParagraph; push (.penalty p)
  | "kern" => let (d, _) ← readDimen t; startParagraph; push (.kern d .explicit)
  | "hskip" => let g ← readGlue t; startParagraph; push (.glue g 0)
  | "nobreak" => if (← get).hmode then push (.penalty 10000)
  | "break" => if (← get).hmode then push (.penalty (-10000))
  | "allowbreak" => if (← get).hmode then push (.penalty 0)
  | "relax" | "selectfont" => pure ()
  | "newcommand" => newCommand t 0
  | "renewcommand" => newCommand t 1
  | "providecommand" => newCommand t 2
  | "def" => defMacro t
  | "parshape" =>
    skipEquals
    let n ← readInt t
    if n < 0 || n > 10000 then failAt t "Bad \\parshape count"
    let mut shape := #[]
    for _ in [0:n.toNat] do
      let (i, _) ← readDimen t
      let (l, _) ← readDimen t
      shape := shape.push (i, l)
    modifyVars fun x => { x with p := { x.p with parShape := shape } }
  | "setlength" =>
    let some (.cs reg _) := (← readArg t).toList.find? (!·.isSpace)
      | failAt t "\\setlength needs a length register"
    let g ← readGlueArg t
    if isIntParam reg then failAt t s!"\\{reg} is not a length"
    let ok ← setGlue reg (if isGlueParam reg then g else { width := g.width })
    if !ok then failAt t s!"Undefined length \\{reg}"
  | "fontsize" =>
    let a ← readArg t
    let b ← readArg t
    let dim := fun (ts : Array Tok) => do
      let saved := (← get).input
      let src := ts ++ (if ts.any fun x => match x with | .char c _ _ => c.isAlpha | _ => false
        then #[] else #[Tok.char 'p' 11 0, .char 't' 11 0])
      modify fun s => { s with input := src.reverse }
      let (d, _) ← readDimen t
      modify fun s => { s with input := saved }
      return d
    let size ← dim a
    let skip ← dim b
    if size ≤ 0 then failAt t "Font size must be positive"
    flushRun
    modifyVars fun x => { x with key := { x.key with size }, baselineSkip := { width := skip } }
  | "(" => startParagraph; push (← formula t (← readFormula t (·.isCs ")") false) false)
  | "[" => displayFormula t (← readFormula t (·.isCs "]") false)
  | "%" | "&" | "#" | "$" | "_" | "{" | "}" => addChar (name.toList.headD ' ')
  | "textbackslash" => addChar '\\'
  | _ => failAt t s!"Undefined control sequence \\{name}"

/-- Carries out one token. -/
def step (t : Tok) : M Unit :=
  match t with
  | .cs name _ => command t name
  | .char c cat _ =>
    match cat with
    | 1 => beginGroup t
    | 2 => endGroup t
    | 3 => do
      match ← next? with
      | some u@(.char '$' 3 _) =>
        let _ := u
        displayFormula t (← readFormula t (·.isChar '$' 3) true)
      | some u =>
        unread #[u]
        startParagraph
        push (← formula t (← readFormula t (·.isChar '$' 3) false) false)
        modify fun s => { s with sf := 1000 }
      | none => failAt t "Missing $ inserted (formula not closed)"
    | 10 => addSpace
    | 13 => do
      startParagraph
      push (.penalty 10000)
      addSpace (some 1000)
    | 4 => failAt t "Misplaced alignment tab character &"
    | 6 => failAt t "You can't use the macro parameter character # here"
    | 7 | 8 => failAt t s!"Missing $ inserted ({c} is for formulas)"
    | _ => addChar c
  | .param _ => fail "internal: a parameter outside a macro body"

/-- Reads and carries out every token, then ends the last paragraph. -/
def process : M Unit := do
  let (cfg, _) ← read
  let fuel := (← get).input.size + cfg.maxTokens + 2
  for _ in [0:fuel] do
    match ← next? with
    | none => break
    | some t => step t
  if !(← get).input.isEmpty then fail "internal: the token budget ran out"
  if !(← get).boxes.isEmpty then fail "Missing } inserted (a box is not closed)"
  endParagraph
  if (← get).groups.size > 1 then fail "Missing } inserted (a group is not closed)"

end Typeset

open Typeset in
/-- Typesets LaTeX source (see the module docstring): the lines of its paragraphs and
formulas with their positions, the fonts named by `resolve`. `init` holds the starting
parameters (LaTeX's ten-point article class by default). An error for source the front end
does not understand or that exceeds a cap of `cfg`. -/
def typeset (src : String) (resolve : FontResolver) (cfg : Settings := {})
    (init : Vars := {}) : Except TypesetError Document := do
  if src.length > cfg.maxSource then
    throw { message := s!"source too long: more than {cfg.maxSource} characters" }
  let st : St := { input := (tokenize src).reverse, groups := #[init] }
  let ((), s) ← (process.run (cfg, resolve)).run st
  return { fonts := s.fonts, lines := s.lines, width := s.width, warnings := s.warnings
           paragraphs := s.paragraphs }

end LeAnTeX.Text
