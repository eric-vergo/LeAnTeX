/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Text.Source
import LeAnTeX.Text.Font
import LeAnTeX.Text.Pack
import LeAnTeX.Layout.Build
import LeAnTeX.Layout.Display
import LeAnTeX.Doc.State
import LeAnTeX.TeXMath.Front
import LeAnTeX.TeXMath.Setup
import LeAnTeX.TeXMath.Display

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
macro expansions produce together (`Settings.maxTokens`), the number of expansions, the
nesting of groups and boxes, and the steps of the line breaker (per paragraph and over the
document, `Settings.maxBreakWork`) are capped, and past a cap the result is an error naming the
cap, never a hang.

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
  /-- The most steps the line breaker may take over all paragraphs together (each paragraph is
  also held to `LeAnTeX.Text.Params.maxWork`). -/
  maxBreakWork : Nat := 100000000
  /-- The hyphenation patterns (`Patterns.english`, LaTeX's default). -/
  patterns : Patterns := Patterns.english
  /-- Whether to hyphenate at all. -/
  hyphenate : Bool := true
  /-- The images a document may include (`\includegraphics`), by the path it gives: their
  bytes, or `none`. The caller decides which files are reachable; paths are checked before
  they are asked for (relative, no `..`, letters, digits, `.`, `_`, `-`, `/` only). -/
  images : String → Option ByteArray := fun _ => none
  /-- The most bytes an image may have. -/
  maxImage : Nat := 16777216
  /-- The most bytes the distinct images of a document may have together (each file counted
  once, however often it is included). -/
  maxImagesTotal : Nat := 33554432
  /-- A document is set on one continuous page (no page breaks, floats where they are given):
  the web view of the HTML back end. -/
  continuous : Bool := false
  /-- What `\today` prints (a document's output must not depend on the clock). -/
  today : String := "January 1, 2000"
  /-- The settings for formulas; the text's macros are added to them. -/
  math : LeAnTeX.Settings := {}
  /-- The metric files of the Computer Modern math fonts (`LeAnTeX.TeXMath.MathFontSet`): with
  them formulas are laid out by the TeX-rule layout (`LeAnTeX.TeXMath`), TeX's boxes, and
  inline formulas may break after relations and binary operations; without them (or for a
  formula that layout does not build) by the KaTeX-compatible layout, as one box. -/
  mathTfms : Std.HashMap String LeAnTeX.TeXMath.Tfm := {}
  /-- Whether `\leantexprobe{label}` records the list parameters in force (for the comparison
  with LuaLaTeX's, `tools/list-params.sh`); when off the command is undefined. -/
  probes : Bool := false

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
  /-- `\interlinepenalty`. -/
  interlinePenalty : Int := 0
  /-- The space factor code of `.` (`3000`; LaTeX's bibliography sets `1000`). -/
  periodSf : Nat := 3000
  /-- `\clubpenalty`. -/
  clubPenalty : Int := 150
  /-- `\widowpenalty`. -/
  widowPenalty : Int := 150
  /-- `\displaywidowpenalty`. -/
  displayWidowPenalty : Int := 50
  /-- `\brokenpenalty`. -/
  brokenPenalty : Int := 100
  /-- `\predisplaypenalty`. -/
  preDisplayPenalty : Int := 10000
  /-- `\postdisplaypenalty`. -/
  postDisplayPenalty : Int := 0
  /-- `\abovedisplayskip`. -/
  aboveDisplaySkip : Glue := { width := 10 * 65536, stretch := 2 * 65536, shrink := 5 * 65536 }
  /-- `\belowdisplayskip`. -/
  belowDisplaySkip : Glue := { width := 10 * 65536, stretch := 2 * 65536, shrink := 5 * 65536 }
  /-- `\abovedisplayshortskip`. -/
  aboveDisplayShortSkip : Glue := { stretch := 3 * 65536 }
  /-- `\belowdisplayshortskip`. -/
  belowDisplayShortSkip : Glue :=
    { width := 6 * 65536, stretch := 3 * 65536, shrink := 3 * 65536 }
  /-- The left margin of the lists open (LaTeX's `\@totalleftmargin`). -/
  totalLeftMargin : Int := 0
  /-- The width of a line in the lists open (LaTeX's `\linewidth`), when it is not
  `\hsize`. -/
  lineWidth : Option Int := none
  /-- The size's own list skips at level 1 (`\topsep`, `\itemsep`, `\parsep` of the
  `\@listi` that `\small` and `\footnotesize` define); `none` for the class's. -/
  listOne : Option (Glue × Glue × Glue) := none
  /-- Whether `\\` ends the paragraph (LaTeX's `\centering`, `\raggedright`,
  `\raggedleft`). -/
  crPar : Bool := false
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
  /-- The width it is set to (`\hbox to`), if not its natural width. -/
  target : Option Int := none

/-- What a nested vertical list saves of the list around it: TeX's semantic nest, one level. -/
structure Outer where
  /-- The vertical list outside. -/
  vlist : Array LeAnTeX.Doc.VNode
  /-- Its `\prevdepth`. -/
  vPrev : Int
  /-- Whether a paragraph was being built outside. -/
  hmode : Bool
  /-- The horizontal list outside. -/
  hlist : Array HNode
  /-- Its pending characters. -/
  run : Array Char
  /-- Their font. -/
  runKey : FontKey
  /-- Its space factor. -/
  sf : Nat
  /-- Its vertical material waiting for the lines. -/
  adjust : Array (Nat × LeAnTeX.Doc.VNode)
  /-- Its `\noindent` state. -/
  noIndent : Bool
  /-- The boxes being built outside. -/
  boxes : Array BoxFrame
  /-- The document layer's paragraph flags outside (after a heading, an item's label, after
  an environment). -/
  flags : Bool × Bool × Bool × Option HNode × Bool
  /-- The paragraph flags of the paragraph outside. -/
  par : Bool × Bool × Bool
  deriving Inhabited

/-- A nested vertical list being built: what for, the group depth it closes with, and what it
saved. -/
structure Frame where
  /-- What it is for. -/
  kind : LeAnTeX.Doc.FrameKind
  /-- The group depth when it began. -/
  depth : Nat
  /-- The state outside. -/
  outer : Outer
  deriving Inhabited

/-- The front end's state. -/
structure St where
  /-- The tokens still to read, the next last. -/
  input : Array Tok
  /-- Tokens the expansions produced. -/
  produced : Nat := 0
  /-- Steps the line breaker took over all paragraphs so far. -/
  breakWork : Nat := 0
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
  /-- The vertical list being built (the main one, or a nested one's). -/
  vlist : Array LeAnTeX.Doc.VNode := #[]
  /-- Its `\prevdepth`. -/
  vPrev : Int := LeAnTeX.Doc.ignoreDepth
  /-- Vertical material made in the paragraph (labels, insertions, `\vadjust`), with the
  index in the horizontal list where it was made: it goes after the line that holds it. -/
  adjust : Array (Nat × LeAnTeX.Doc.VNode) := #[]
  /-- The nested vertical lists being built, innermost last. -/
  nest : Array Frame := #[]
  /-- The document layer's state. -/
  doc : LeAnTeX.Doc.DocState := {}
  /-- Whether the paragraph being built continues one interrupted by a display (no `\parskip`;
  the `\clubpenalty` applies to its first line, as TeX numbers the lines after a display from
  `prev_graf` + 1). -/
  afterDisplay : Bool := false
  /-- Whether the paragraph being built takes no `\clubpenalty` (after a display or a
  heading). -/
  noClub : Bool := false
  /-- Whether the first line of the paragraph being built takes `\clubpenalty` 10000 (the
  first paragraph after a heading). -/
  clubMax : Bool := false
  /-- TeX's `\predisplaysize` from the last line set. -/
  preDisplay : Int := -1073741823
  /-- The math families made for each text size (the TeX-rule layout's fonts). -/
  mathFams : Std.HashMap Int LeAnTeX.TeXMath.Families := {}

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
  if let some g := (← get).doc.lengths[name]? then return some g.width
  return match name with
    | "hsize" | "textwidth" | "linewidth" | "columnwidth" => some v.p.hsize
    | "parindent" => some v.parIndent
    | "emergencystretch" => some v.p.emergencyStretch
    | "hangindent" => some v.p.hangIndent
    | "baselineskip" => some v.baselineSkip.width
    | "parskip" => some v.parSkip.width
    | "leftskip" => some v.p.leftSkip.width
    | "rightskip" => some v.p.rightSkip.width
    | "lineskip" => some v.lineSkip.width
    | "lineskiplimit" => some v.lineSkipLimit
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

/-- A length `v` times a decimal factor `whole + f / 65536` as TeX computes it for a factor
before an internal length or an `em` or `ex` unit (`nx_plus_y(whole, v, xn_over_d(v, f,
65536))`: the fraction's part truncated toward zero). -/
def texTimes (v : Int) (whole f : Nat) : Int :=
  let fracPart := if v ≥ 0 then v * f / 65536 else -((-v) * f / 65536)
  v * whole + fracPart

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
    | some v => return (sign (texTimes v whole f), 0)
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
  let times := fun (u : Int) => sign (texTimes u whole f)
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
  -- the words LuaTeX hyphenates: runs of letters that start the list, follow a glue, a box
  -- or a rule (a strut), or follow a character that is not a letter (other than an explicit
  -- hyphen); not those right after a penalty, a kern or a discretionary
  let before := match s.hlist.back? with
    | none | some (.glue ..) | some (.box ..) | some (.rule ..) => true
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
  let parts := (splitHyphens cs).toArray
  let mut off := 0
  -- the words are in order and inside one part each, so one pass over them serves all parts
  let mut wi := 0
  for h : k in [0:parts.size] do
    let part := parts[k].toArray
    let mut points := #[]
    for _ in [wi:words.size] do
      let some (i, j) := words[wi]? | break
      if i ≥ off + part.size then break
      wi := wi + 1
      if off ≤ i && j ≤ off + part.size then
        let w := String.ofList (cs.extract i j).toList
        for p in cfg.patterns.points w v.leftHyphenMin.toNat v.rightHyphenMin.toNat do
          points := points.push (i - off + p)
    out := out ++ tf.shapeRun part points v.hyphenPenalty
    if k + 1 < parts.size then
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

/-- The interline parameters in force. -/
def interline : M LeAnTeX.Doc.Interline := do
  let v ← vars
  return { baselineSkip := v.baselineSkip, lineSkip := v.lineSkip,
           lineSkipLimit := v.lineSkipLimit }

/-- Appends a box to the vertical list with TeX's interline glue (`append_to_vlist`). -/
def appendV (n : LeAnTeX.Doc.VNode) : M Unit := do
  let p ← interline
  let s ← get
  let (l, pd) := LeAnTeX.Doc.appendBox s.vlist p s.vPrev n
  set { s with vlist := l, vPrev := pd }

/-- Appends an item other than a box to the vertical list. -/
def pushV (n : LeAnTeX.Doc.VNode) : M Unit :=
  modify fun s => { s with vlist := s.vlist.push n }

/-- The index in the paragraph's horizontal list where material made now sits: the end of the
list, or, inside a box, where the outermost box will go. -/
def hereIndex : M Nat := do
  let s ← get
  return match s.boxes[0]? with
    | some fr => fr.outer.size
    | none => s.hlist.size + (if s.run.isEmpty then 0 else 1)

/-- Adds vertical material: in a paragraph it goes after the line that holds this place (as
TeX moves insertions and `\vadjust` material out of a line); else to the vertical list. -/
def adjustV (n : LeAnTeX.Doc.VNode) : M Unit := do
  if (← get).hmode then
    let i ← hereIndex
    modify fun s => { s with adjust := s.adjust.push (i, n) }
  else pushV n

/-- Starts a paragraph (in vertical mode), with its indentation unless `\noindent` said not:
TeX's `new_graf`, with `\parskip` glue first (in a nested list only when it is not empty).
After a heading (LaTeX's `\@afterheading`) there is no indentation and no break after the
first line; after an `\item` the item's label starts the paragraph. -/
def startParagraph : M Unit := do
  let s ← get
  if s.hmode then return
  let v ← vars
  let afterHeading := s.doc.afterHeading || s.doc.endPe
  let indent := if s.noIndent || afterHeading || s.doc.inLabel then #[]
    else #[HNode.box v.parIndent 0 0 0 #[]]
  let indent := match s.doc.labelBox with
    | some b => if s.doc.inLabel then indent.push b |>.push (.penalty 0) else indent
    | none => indent
  let cursor := if s.prevDepth.isSome then s.cursor + v.parSkip.width else s.cursor
  let vlist := if s.afterDisplay then s.vlist
    else if s.nest.isEmpty || !s.vlist.isEmpty then s.vlist.push (.glue v.parSkip 3)
    else s.vlist
  set { s with hmode := true, hlist := indent, sf := 1000, noIndent := false, cursor, vlist,
               noClub := false, clubMax := if s.afterDisplay then s.clubMax else s.doc.noBreak,
               afterDisplay := false,
               doc := { s.doc with afterHeading := false, noBreak := false, inLabel := false,
                                   labelBox := none, endPe := false } }

/-- TeX's `pre_display_size` for a display after line `l` (shifted by its indentation): the
right end of its last visible item plus two em of the current font. -/
def preDisplaySize (l : Line) (em : Int) : Int := Id.run do
  let mut v := l.indent + 2 * em
  let mut w : Int := -1073741823
  for n in l.nodes do
    match n with
    | .glyph .. | .box .. | .rule .. | .math .. =>
      v := v + n.width
      w := v
    | .glue g _ =>
      if (l.glue.sign == 1 && l.glue.order == g.stretchOrder && g.stretch != 0) ||
         (l.glue.sign == 2 && l.glue.order == g.shrinkOrder && g.shrink != 0) then
        v := 1073741823
      else v := v + g.width
    | n => v := v + n.width
  return w

/-- Ends the paragraph being built: TeX's `\par`: the list's last glue removed,
`\penalty10000\parfillskip` appended, the lines broken, set and stacked. On the vertical
list the lines go with TeX's interline penalties between them (`\interlinepenalty`, with
`\clubpenalty` after the first line, `\widowpenalty` before the last, or
`\displaywidowpenalty` when a display follows, and `\brokenpenalty` after a hyphen) and the
vertical material made in each line after it. An empty paragraph (after a display) adds no
line. Inside a list the lines take the list's margin and width (LaTeX's `\parshape`). -/
def endParagraph (display : Bool := false) : M Unit := do
  flushRun
  let s ← get
  if !s.hmode || !s.boxes.isEmpty then return
  let v ← vars
  let empty := s.hlist.isEmpty
  let mut items := s.hlist
  if let some (.glue ..) := items.back? then items := items.pop
  items := items.push (.penalty 10000) |>.push (.glue v.parFillSkip 15)
  let adjust := s.adjust
  set { s with hmode := false, hlist := #[], paragraphs := s.paragraphs.push items,
               adjust := #[] }
  -- TeX resets the paragraph shape after every paragraph
  modifyVars fun x => { x with p := { x.p with hangIndent := 0, hangAfter := 1, parShape := #[] } }
  let p := if v.p.parShape.isEmpty && v.p.hangIndent == 0 then
      match v.lineWidth with
      | some w => { v.p with parShape := #[(v.totalLeftMargin, w)] }
      | none => v.p
    else v.p
  let (cfg, _) ← read
  let left := cfg.maxBreakWork - min cfg.maxBreakWork (← get).breakWork
  let p := { p with maxWork := min p.maxWork left }
  match breakParagraph items p with
  | .error (.tooMuchWork n) =>
    if n < cfg.maxBreakWork && n == left then
      fail s!"paragraph: the document's paragraphs are too costly to break: more than \
        {cfg.maxBreakWork} steps"
    else fail s!"paragraph: {(BreakError.tooMuchWork n).message}"
  | .error e => fail s!"paragraph: {e.message}"
  | .ok r =>
    modify fun s => { s with warnings := s.warnings ++ r.warnings, width := v.p.hsize,
                             breakWork := s.breakWork + r.work }
    let ls := setLines items p r.breaks
    let ranges := lineRanges items (r.breaks.map (·.pos))
    let noClub := (← get).noClub
    let clubMax := (← get).clubMax
    for h : k in [0:ls.size] do
      let l := ls[k]
      if l.glue.sign == 2 && l.glue.ratio == 1 && l.natural > l.width then
        let msg := s!"overfull line by {l.natural - l.width} sp"
        modify fun s => { s with warnings := s.warnings.push msg }
      let y ← stack l.height l.depth
      modify fun s => { s with lines := s.lines.push (l, y) }
      if empty then continue
      appendV (.hbox l.width l.height l.depth l.indent l.nodes l.glue)
      -- the material made in this line: before its break, after the previous line's
      for (i, n) in adjust do
        if lineOf ranges ls.size i == k then pushV n
      if k + 1 < ls.size then
        let mut pen := v.interlinePenalty
        if k == 0 && !noClub then pen := pen + (if clubMax then 10000 else v.clubPenalty)
        if k + 2 == ls.size then
          pen := pen + (if display then v.displayWidowPenalty else v.widowPenalty)
        if (r.breaks[k]?.map (·.hyphenated)).getD false then pen := pen + v.brokenPenalty
        if pen != 0 then pushV (.penalty pen)
    if empty then
      for (_, n) in adjust do pushV n
    if let some l := ls.back? then
      if !empty then
        let (em, _) ← fontUnits
        modify fun s => { s with preDisplay := preDisplaySize l em }
  let skip := (← get).pendingSkip
  -- a paragraph interrupted by a display keeps its `\clubpenalty`: LaTeX's `\everypar`, which
  -- resets it after a heading, runs only when a new paragraph starts
  modify fun s => { s with cursor := s.cursor + skip, pendingSkip := 0, noClub := false,
                           clubMax := display && s.clubMax }
where
  /-- The line that holds material made before node `i`: the first whose break is at or
  after it, else the last; material made among the glue and penalties that a break removes
  from the start of a line goes with the line before (as LuaTeX moves a `\vadjust` there). -/
  lineOf (ranges : Array (Nat × Nat)) (n i : Nat) : Nat :=
    match ranges.findIdx? (fun r => i ≤ r.2) with
    | some k =>
      if k > 0 && i < (ranges[k]?.map (·.1)).getD 0 then k - 1 else k
    | none => n - 1

/-- Adds vertical space: between paragraphs at once, inside one after the line it is in (as
LaTeX's `\vspace` adds `\vskip` glue followed by zero glue, through `\vadjust` in a
paragraph). -/
def vspace (g : Glue) : M Unit := do
  if (← get).hmode then
    modify fun s => { s with pendingSkip := s.pendingSkip + g.width }
    adjustV (.glue g 0)
    adjustV (.glue {} 0)
  else
    modify fun s => { s with cursor := s.cursor + g.width }
    pushV (.glue g 0)
    pushV (.glue {} 0)

/-- The text macros as KaTeX macro definitions, for formulas. -/
def mathMacros : M (Array (String × String)) := do
  let v ← vars
  return v.macros.toArray.filterMap fun (name, m) =>
    if m.default.isSome then none
    else some ("\\" ++ name, String.join (m.body.toList.map Tok.text))

/-- The families of the TeX-rule layout at the current size, made once per size; `none` when
the document has no metric files or a font is missing. -/
def mathFamilies : M (Option LeAnTeX.TeXMath.Families) := do
  let (cfg, resolve) ← read
  if cfg.mathTfms.isEmpty then return none
  let size := (← vars).key.size
  if let some fs := (← get).mathFams[size]? then return some fs
  let pk := (← get).doc.packages
  let set : LeAnTeX.TeXMath.MathFontSet :=
    { tfms := cfg.mathTfms,
      amsfonts := pk.contains "amssymb" || pk.contains "amsfonts" || pk.contains "amsmath",
      text := fun k => (resolve k).map fun i => (⟨i, k.size, 0⟩ : TextFont) }
  match set.families size with
  | .ok fs =>
    modify fun s => { s with mathFams := s.mathFams.insert size fs }
    return some fs
  | .error _ => return none

/-- A formula laid out by the TeX-rule layout at the current size, as TeX's `mlist_to_hlist`
makes it (in display style for a displayed one; `penalties` for one in a paragraph): its
list and the families, or `none` when it is not built so (no metric files, or a construct the
layout refuses). -/
def texFormula (src : String) (display penalties : Bool) :
    M (Option (Array LeAnTeX.TeXMath.Node × LeAnTeX.TeXMath.Families)) := do
  let some fs ← mathFamilies | return none
  let (cfg, resolve) ← read
  let v ← vars
  let size := v.key.size
  let macros := cfg.math.macros ++ (← mathMacros)
  let settings := { cfg.math with displayMode := display, macros }
  let .ok tree := LeAnTeX.TeXMath.parseForTeX src settings display | return none
  let tf : Option TextFont := (resolve { size }).map fun i => { info := i, size, index := 0 }
  let bskip := v.baselineSkip.width
  let ctx : LeAnTeX.TeXMath.FrontCtx :=
    { source := src, displayMath := display, quad := size,
      xHeight := (tf.map fun t => (LeAnTeX.TeXMath.MathFont.otf t).param 5).getD 0,
      space := (tf.map (·.space)).getD {},
      strutHeight := LeAnTeX.TeXMath.xnOverD bskip 45875 65536,
      strutDepth := LeAnTeX.TeXMath.xnOverD bskip 19661 65536 }
  let env : LeAnTeX.TeXMath.Env := { fams := fs }
  let style := if display then LeAnTeX.TeXMath.Style.display else .text
  let run : LeAnTeX.TeXMath.M (Array LeAnTeX.TeXMath.Node) := do
    let l ← LeAnTeX.TeXMath.toMathList tree ctx
    LeAnTeX.TeXMath.mlistToHlist LeAnTeX.TeXMath.maxNesting l style penalties
  match (run.run env).run {} with
  | .ok (h, _) => return some (h, fs)
  | .error _ => return none

/-- A part of a formula drawn as one unbreakable node: its list's display list in em of the
size, with the formula's record (`source` empty for a part after the first). -/
def mathChunk (fs : LeAnTeX.TeXMath.Families) (l : Array LeAnTeX.TeXMath.Node) (size : Int)
    (src : String) (display : Bool) : HNode :=
  let b := LeAnTeX.TeXMath.hpack l
  let dl := LeAnTeX.TeXMath.displayListOf fs l size
  let whole : Formula := ⟨0, dl.items.size, 0, 0, dl.width, dl.height, dl.depth, src, display⟩
  .math b.width b.height b.depth { dl with formulas := #[whole] } size

/-- Lays out a formula at the current size as one node (or an error): by the TeX-rule layout
when it builds the formula, else by the KaTeX-compatible one. -/
def formula (at_ : Tok) (src : String) (display : Bool) : M HNode := do
  let size := (← vars).key.size
  if let some (h, fs) ← texFormula src display false then
    return mathChunk fs h size src display
  let (cfg, _) ← read
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

/-- An inline formula appended to the horizontal list. Laid out by the TeX-rule layout, it is
TeX's list of the formula between its math nodes: the math nodes become explicit kerns of 0 (a
line may break after the formula's end before glue, as TeX's math node allows), glue and
penalties stay themselves, with a `\nobreak` before each glue (TeX does not break at glue
inside a formula), and the material between them is drawn as unbreakable parts. A line may so
break at the penalties after relations and binary operations (in a paragraph; not in a box).
Laid out by the KaTeX-compatible layout, it is one box. The space factor becomes 1000. -/
def inlineFormula (at_ : Tok) (src : String) : M Unit := do
  let size := (← vars).key.size
  let penalties := (← get).hmode && (← get).boxes.isEmpty
  match ← texFormula src false penalties with
  | none => push (← formula at_ src false)
  | some (h, fs) =>
    push (.kern 0 .explicit)
    let mut part : Array LeAnTeX.TeXMath.Node := #[]
    let mut first := true
    for n in h do
      match n with
      | .glue g st =>
        if !part.isEmpty then
          push (mathChunk fs part size (if first then src else "") false); first := false
          part := #[]
        push (.penalty 10000)
        push (.glue g st)
      | .penalty p =>
        if !part.isEmpty then
          push (mathChunk fs part size (if first then src else "") false); first := false
          part := #[]
        push (.penalty p)
      | n => part := part.push n
    if !part.isEmpty || first then
      push (mathChunk fs part size (if first then src else "") false)
    push (.kern 0 .explicit)
  modify fun s => { s with sf := 1000 }

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

/-- TeX's `half`: half of `x`, rounded up when odd. -/
def half (x : Int) : Int := if x % 2 == 1 || x % 2 == -1 then (x + 1) / 2 else x / 2

/-- Sets a displayed formula: the paragraph so far ends (TeX's display interrupts it), the
formula is centred on a line of its own and the paragraph goes on without indentation, the
spaces after the display ignored. The document's width is `\hsize`, as for a paragraph.

On the vertical list it is TeX's display (*TeX: The Program* §1199–§1205): `\predisplaypenalty`,
`\abovedisplayskip` (or `\abovedisplayshortskip` when the formula starts to the right of
`\predisplaysize`), the formula's box shifted to the centre of the display width (the list's
line width inside a list) with its interline glue, `\postdisplaypenalty` and the matching skip
below. An equation number `eqno` goes at the right: with `fullWidth` (amsmath's equations) the
line is the display width with the formula centred and the number flush right; else TeX's
`\eqno` placement (the formula moved left when the number would come closer than its own
width). -/
def displayFormula (at_ : Tok) (src : String) (eqno : Option HNode := none)
    (fullWidth : Bool := false) : M Unit := do
  let wasH := (← get).hmode
  if wasH then endParagraph (display := true)
  let n ← formula at_ src true
  let v ← vars
  let (w, h, d) := match n with | .math w h d _ _ => (w, h, d) | _ => (0, 0, 0)
  modify fun s => { s with cursor := s.cursor + 10 * 65536 }
  let y ← stack h d
  let line : Line :=
    { nodes := #[n], width := w, indent := (v.p.hsize - w) / 2, natural := w,
      height := h, depth := d, glue := {} }
  modify fun s =>
    { s with lines := s.lines.push (line, y), cursor := s.cursor + 10 * 65536, width := v.p.hsize }
  -- the vertical list
  let z := v.lineWidth.getD v.p.hsize
  let sh := v.totalLeftMargin
  let preD := (← get).preDisplay
  let pre := if wasH then preD else -1073741823
  let e := match eqno with | some b => b.width | none => 0
  let mut dd := half (z - w)
  if e > 0 && !fullWidth && dd < 2 * e then dd := half (z - w - e)
  let short := !(dd + sh ≤ pre)
  pushV (.penalty v.preDisplayPenalty)
  pushV (.glue (if short then v.aboveDisplayShortSkip else v.aboveDisplaySkip)
    (if short then 6 else 4))
  let box : LeAnTeX.Doc.VNode := match eqno with
    | none => .hbox w h d (sh + dd) #[n] {}
    | some b =>
      -- the formula and the number are boxes of their own in the line, as TeX makes them
      let fb := HNode.box w h d 0 #[n]
      if fullWidth then
        let dc := half (z - w)
        let content := #[HNode.kern dc .explicit, fb, .kern (z - dc - w - e) .explicit, b]
        .hbox z (max h b.height) (max d b.depth) sh content {}
      else
        let content := #[fb, HNode.kern (z - w - e - dd) .explicit, b]
        .hbox (z - dd) (max h b.height) (max d b.depth) (sh + dd) content {}
  appendV box
  pushV (.penalty v.postDisplayPenalty)
  pushV (.glue (if short then v.belowDisplayShortSkip else v.belowDisplaySkip)
    (if short then 7 else 5))
  if wasH then
    modify fun s => { s with noIndent := true, afterDisplay := true }
    startParagraph
  -- spaces after a display are ignored (TeX after `$$`, LaTeX's `\]` with `\ignorespaces`)
  if let some t ← nextNonSpace? then unread #[t]

/-! ### Groups and boxes -/

/-- A list's glue fixed at the sizes a setting gives it (TeX's `hlist_out` arithmetic): each
glue becomes glue of its set width, so the list keeps its look as a box's content at its
natural width. -/
def freezeGlue (nodes : Array HNode) (g : GlueSet) : Array HNode := Id.run do
  if g.sign == 0 then return nodes
  let glues := nodes.filterMap fun n => match n with
    | .glue gl _ => some gl
    | _ => none
  let sizes := LeAnTeX.Doc.glueSizes g glues
  let mut out := #[]
  let mut k := 0
  for n in nodes do
    match n with
    | .glue _ st =>
      out := out.push (.glue { width := sizes.getD k 0 } st)
      k := k + 1
    | n => out := out.push n
  return out

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
      let (w, st, sh, h, d) := measure content
      let (w, content) := match fr.target with
        | some tw => (tw, freezeGlue content (hpackGlue w tw st sh))
        | none => (w, content)
      set { s with
        boxes := s.boxes.pop, hlist := fr.outer.push (.box w h d 0 content), sf := 1000,
        groups := s.groups.pop }
      return
  | none => pure ()
  flushRun
  modify fun s => { s with groups := s.groups.pop }

/-- Begins `\hbox{…}`: reads `{` and starts a list inside it. -/
def beginBox (at_ : Tok) (target : Option Int := none) : M Unit := do
  match ← nextNonSpace? with
  | some t =>
    if !t.isBegin then failAt t "A <box> was supposed to be here (missing {)"
  | none => failAt at_ "A <box> was supposed to be here"
  let wasVertical := !(← get).hmode
  startParagraph
  flushRun
  beginGroup at_
  modify fun s => { s with
    boxes := s.boxes.push
      { depth := s.groups.size, outer := s.hlist, sf := s.sf, wasVertical, target }
    hlist := #[] }

/-! ### Nested vertical lists -/

/-- Starts a nested vertical list (TeX's internal vertical mode) for `kind`, closed with the
current group: what is being built outside is saved and a new list begins. -/
def openFrame (kind : LeAnTeX.Doc.FrameKind) : M Unit := do
  flushRun
  let s ← get
  let d := s.doc
  let outer : Outer :=
    { vlist := s.vlist, vPrev := s.vPrev, hmode := s.hmode, hlist := s.hlist, run := s.run,
      runKey := s.runKey, sf := s.sf, adjust := s.adjust, noIndent := s.noIndent,
      boxes := s.boxes, flags := (d.afterHeading, d.noBreak, d.inLabel, d.labelBox, d.endPe),
      par := (s.afterDisplay, s.noClub, s.clubMax) }
  set { s with nest := s.nest.push { kind, depth := s.groups.size, outer },
               vlist := #[], vPrev := LeAnTeX.Doc.ignoreDepth, hmode := false, hlist := #[],
               run := #[], adjust := #[], noIndent := false, boxes := #[],
               afterDisplay := false, noClub := false, clubMax := false,
               doc := { d with afterHeading := false, noBreak := false, inLabel := false,
                               labelBox := none, endPe := false } }

/-- Ends the innermost nested vertical list: its paragraph ended, its items returned with its
kind, and the state outside restored. -/
def closeFrame : M (Option (LeAnTeX.Doc.FrameKind × Array LeAnTeX.Doc.VNode)) := do
  let some fr := (← get).nest.back? | return none
  endParagraph
  let s ← get
  let o := fr.outer
  let (ah, nb, il, lbx, ep) := o.flags
  let (ad, nc, cm) := o.par
  set { s with nest := s.nest.pop, vlist := o.vlist, vPrev := o.vPrev, hmode := o.hmode,
               hlist := o.hlist, run := o.run, runKey := o.runKey, sf := o.sf,
               adjust := o.adjust, noIndent := o.noIndent, boxes := o.boxes,
               afterDisplay := ad, noClub := nc, clubMax := cm,
               doc := { s.doc with afterHeading := ah, noBreak := nb, inLabel := il,
                                   labelBox := lbx, endPe := ep } }
  return some (fr.kind, s.vlist)

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
    | "interlinepenalty" => some fun x => { x with interlinePenalty := v }
    | "clubpenalty" => some fun x => { x with clubPenalty := v }
    | "widowpenalty" => some fun x => { x with widowPenalty := v }
    | "displaywidowpenalty" => some fun x => { x with displayWidowPenalty := v }
    | "brokenpenalty" => some fun x => { x with brokenPenalty := v }
    | "predisplaypenalty" => some fun x => { x with preDisplayPenalty := v }
    | "postdisplaypenalty" => some fun x => { x with postDisplayPenalty := v }
    | _ => none
  match f with
  | some f => modifyVars f; return true
  | none => return false

/-- Whether `name` is an integer parameter. -/
def isIntParam (name : String) : Bool :=
  ["tolerance", "pretolerance", "looseness", "linepenalty", "adjdemerits",
    "doublehyphendemerits", "finalhyphendemerits", "hangafter", "hyphenpenalty",
    "exhyphenpenalty", "lefthyphenmin", "righthyphenmin", "interlinepenalty", "clubpenalty",
    "widowpenalty", "displaywidowpenalty", "brokenpenalty", "predisplaypenalty",
    "postdisplaypenalty"].contains name

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
    | "lineskip" => some fun x => { x with lineSkip := g }
    | "lineskiplimit" => some fun x => { x with lineSkipLimit := g.width }
    | "abovedisplayskip" => some fun x => { x with aboveDisplaySkip := g }
    | "belowdisplayskip" => some fun x => { x with belowDisplaySkip := g }
    | "abovedisplayshortskip" => some fun x => { x with aboveDisplayShortSkip := g }
    | "belowdisplayshortskip" => some fun x => { x with belowDisplayShortSkip := g }
    | _ => none
  match f with
  | some f => modifyVars f; return true
  | none => return false

/-- Whether `name` is a glue parameter (its value may have `plus` and `minus`). -/
def isGlueParam (name : String) : Bool :=
  ["leftskip", "rightskip", "parfillskip", "baselineskip", "parskip", "lineskip",
    "abovedisplayskip", "belowdisplayskip", "abovedisplayshortskip",
    "belowdisplayshortskip"].contains name

/-- Whether `name` is a dimension parameter. -/
def isDimenParam (name : String) : Bool :=
  ["hsize", "textwidth", "linewidth", "columnwidth", "parindent", "emergencystretch",
    "hangindent", "lineskiplimit"].contains name

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
  let code := if c == '.' then v.periodSf else sfCode c
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

/-- Carries out a control sequence of the text layer (the document layer's dispatcher,
`LeAnTeX.Text.Typeset.command`, calls it for the names it does not handle itself). -/
def textCommand (t : Tok) (name : String) : M Unit := do
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
  | "hbox" =>
    if ← keyword "to" then
      let (w, _) ← readDimen t
      beginBox t (some w)
    else beginBox t
  | "mbox" => beginBox t
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
    vspace g
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
  | "(" => startParagraph; inlineFormula t (← readFormula t (·.isCs ")") false)
  | "[" => displayFormula t (← readFormula t (·.isCs "]") false)
  | "%" | "&" | "#" | "$" | "_" | "{" | "}" => addChar (name.toList.headD ' ')
  | "textbackslash" => addChar '\\'
  | _ => failAt t s!"Undefined control sequence \\{name}"

/-- The control sequences `command` carries out itself (besides macros, font declarations and
parameters). -/
def basicNames : Array String :=
  #[" ", "#", "$", "%", "&", "(", ",", "-", "/", "[", "\\", "_", "allowbreak", "break",
    "def", "enspace", "fontsize", "hbox", "hfil", "hfill", "hskip", "hspace", "hss",
    "indent", "kern", "mbox", "newcommand", "newline", "nobreak", "noindent", "par",
    "parshape", "penalty", "providecommand", "qquad", "quad", "relax", "renewcommand",
    "selectfont", "setlength", "textbackslash", "vspace", "{", "}"]

end Typeset

end LeAnTeX.Text
