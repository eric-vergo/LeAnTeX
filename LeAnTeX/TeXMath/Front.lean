/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Parse.Parser
import LeAnTeX.TeXMath.MList
import LeAnTeX.TeXMath.Data.MathCodes

/-!
# From the parse tree to TeX's math list

The parser's tree (KaTeX's, `LeAnTeX.Parse`) turned into the math list TeX builds for the same
source in LaTeX with amsmath and amssymb: each symbol gets the math code LaTeX gives it
(recorded from LuaLaTeX, `LeAnTeX.TeXMath.Data`), and each command is built as LaTeX's and
amsmath's macros build it, so that its boxes come out as TeX's.

## What is built as LaTeX builds it

* Symbols by their math codes: class, family, slot; letters and digits (class 7) take the
  family of `\mathrm`, `\mathbf`, `\mathit`, `\mathsf`, `\mathtt`, `\mathcal`, `\mathbb`,
  `\mathfrak` around them.
* Groups `{…}`: an ordinary atom with the group as its nucleus, a group of one plain ordinary
  character reduced to the character (TeX's §1186).
* Superscripts and subscripts on the atom before them (an empty ordinary atom when there is
  none that can take them); `'` as `^{\prime}`.
* Large operators: the `cmex` characters of `\sum`, `\prod`, `\int`, `\oint`, `\bigcup` and the
  others with amsmath's limits (`\displaylimits` for sums, `\nolimits` for integrals);
  `\lim`, `\max`, `\sin` and the other named operators as amsmath's `\qopname` builds them (a
  zero kern and the name in the text font; `\displaylimits` for `\lim`, `\max`, `\min`, `\sup`,
  `\inf`, `\det`, `\gcd`, `\Pr`, `\limsup`, `\liminf`, `\nolimits` for the others);
  `\operatorname`, `\operatorname*`; `\limits`, `\nolimits`.
* `\frac`, `\dfrac`, `\tfrac`, `\binom` and `\genfrac`'s fractions, inside amsmath's groups;
  `\sqrt` as LaTeX's `\radical"270370`, `\sqrt[n]` as LaTeX's `\root` (`\mathpalette`, the
  index in scriptscript style raised by 0.6 of the radical's height less depth, `\mkern5mu`
  before and `\mkern-10mu` after it).
* `\left`, `\middle`, `\right` with LaTeX's delimiter codes; `\bigl` … `\Biggr` and their
  relatives as amsmath's `\bBigg@` builds them (a `\left…\right.` around a `\vcenter` of 1, 1.5,
  2 or 2.5 times 1.2 `\ht\strutbox`, in text style, with `\nulldelimiterspace` 0).
* Accents with their math codes (`\hat`, `\bar`, `\vec`, …), `\widehat` and `\widetilde` with
  amsmath's choice of the `msbm` accent for a nucleus wider than 2em; `\overline`,
  `\underline`.
* `\text`, `\textrm`, `\textbf`, `\textit`, `\mbox`: the text font at the size of the style
  (amstext's `\mathchoice`), shaped by the text layer's font.
* Spacing: `\,`, `\:`, `\;`, `\!` as `\thinmuskip`, `\medmuskip`, `\thickmuskip` glue (an
  explicit `\mkern` of 3, 4 or 5mu is read the same way: the parser's tree does not tell them
  apart; the width is the same, only the stretch differs), other kerns in their units,
  `\quad` and `\qquad` as 1em and 2em of the text font, `\ ` as its interword space, `~` with a
  `\nobreak` before it, `\nobreak`, `\allowbreak`.
* `\displaystyle` and the other styles, `\mathchoice`, `\mathord` … `\mathinner`, `\mathop`,
  colours (which change no box), `\phantom`, `\hphantom`, `\vphantom`, `\smash`.
* `\ldots`, `\cdots` (and amsmath's `\dots` as the parser resolves it) as `\mathinner` of three
  `\ldotp` or `\cdotp`; `\ne`, `\neq` as `\not=`; `\pmod` with amsmath's 8mu (18mu in a
  displayed formula).

Everything else is refused with an error naming it (the caller then lays the formula out with
the KaTeX-compatible layout): arrays and environments, `\overbrace`, extensible arrows,
`\boldsymbol`, `\iint`, `\notin`, `\not` before anything but `=`, raw TeX boxes and rules,
size commands.

## Main definitions

* `FrontCtx`: what the conversion needs besides the tree.
* `toMathList`: the tree to a math list.
* `parseForTeX`: the parser with the macros that differ from KaTeX's replaced by LaTeX's.

## References

* LaTeX's `fontmath.ltx`, `latex.ltx` (`\root`, `\mathpalette`), amsmath's `amsmath.sty`,
  `amsopn.sty`, `amstext.sty`, as recorded in `fixtures/math-codes/codes.tsv`; D. E. Knuth,
  *TeX: The Program*, §1151–§1193 (the math list a formula's source builds).
-/

namespace LeAnTeX.TeXMath

open LeAnTeX.Text (Glue KernKind FontKey TextFont)

/-- What the conversion needs besides the tree. -/
structure FrontCtx where
  /-- The source the tree was parsed from (for messages). -/
  source : String := ""
  /-- Whether the formula is displayed (`\[…\]`, `$$…$$`): amsmath's `\pmod` spacing. -/
  displayMath : Bool := false
  /-- The text font's quad (`\fontdimen6`, the em of `\quad` and of `em` units). -/
  quad : Int := 10 * 65536
  /-- The text font's x-height (the `ex` unit). -/
  xHeight : Int := 282168
  /-- The text font's interword space (`\ `). -/
  space : Glue := { width := 218453, stretch := 109227, shrink := 72818 }
  /-- `\ht\strutbox`: 0.7 `\baselineskip` (the struts of arrays). -/
  strutHeight : Int := 550502
  /-- `\dp\strutbox`: 0.3 `\baselineskip`. -/
  strutDepth : Int := 235930
  /-- `\arraycolsep`. -/
  arrayColSep : Int := 5 * 65536
  /-- The current family for class-7 characters, if any. -/
  fam : Option Nat := none
  /-- For each dots command of the source in order (`dotsInSource`), whether amsmath puts a
  thin space after it. -/
  dots : Array Bool := #[]

/-- The conversion's monad: the context, and the layout's monad (for the boxes LaTeX sets while
it builds the list: `\sqrt[n]`'s index, `\text`, phantoms), and the count of the dots
commands met so far (`FrontCtx.dots`). -/
abbrev FM := ReaderT FrontCtx (StateT Nat M)

/-- An error for something the conversion does not build. -/
def unsupported {α : Type} (what : String) : FM α :=
  throw s!"not supported by the TeX-rule layout: {what}"

/-- The math characters by name. -/
def mathCharMap : Std.HashMap String (Nat × Nat × Nat) :=
  Std.HashMap.ofList (Data.mathChars.toList.map fun (n, c, f, s) => (n, (c, f, s)))

/-- The delimiters by name: class and the 24-bit delimiter. -/
def delimMap : Std.HashMap String (Nat × Delim) :=
  Std.HashMap.ofList (Data.delimiters.toList.map fun (n, c, a, b, d, e) =>
    (n, (c, { smallFam := a, smallChar := b, largeFam := d, largeChar := e })))

/-- The accents by name: family and slot. -/
def accentMap : Std.HashMap String (Nat × Nat) :=
  Std.HashMap.ofList (Data.accents.toList.map fun (n, f, s) => (n, (f, s)))

/-- The `\mathcode` of the ASCII characters. -/
def mathCodeMap : Std.HashMap Char (Nat × Nat × Nat) :=
  Std.HashMap.ofList (Data.mathCodes.toList.map fun (c, k, f, s) => (c, (k, f, s)))

/-- The `\delcode` of the ASCII characters. -/
def delCodeMap : Std.HashMap Char Delim :=
  Std.HashMap.ofList (Data.delCodes.toList.map fun (c, a, b, d, e) =>
    (c, { smallFam := a, smallChar := b, largeFam := d, largeChar := e }))

/-- Symbols the parser names differently from LaTeX, or LaTeX defines as macros: class,
family, slot. -/
def extraChars : Std.HashMap String (Nat × Nat × Nat) := Std.HashMap.ofList [
  ("\\@not", (3, 2, 0x36)), ("\\not", (3, 2, 0x36)),
  ("\\ldotp", (6, 1, 0x3A)), ("\\cdotp", (6, 2, 0x01)),
  ("\\lbrace", (4, 2, 0x66)), ("\\rbrace", (5, 2, 0x67)),
  ("\\{", (4, 2, 0x66)), ("\\}", (5, 2, 0x67)),
  ("\\langle", (4, 2, 0x68)), ("\\rangle", (5, 2, 0x69)),
  ("\\|", (0, 2, 0x6B)), ("\\Vert", (0, 2, 0x6B)), ("\\vert", (0, 2, 0x6A)),
  ("\\lvert", (4, 2, 0x6A)), ("\\rvert", (5, 2, 0x6A)),
  ("\\lVert", (4, 2, 0x6B)), ("\\rVert", (5, 2, 0x6B)),
  ("\\lfloor", (4, 2, 0x62)), ("\\rfloor", (5, 2, 0x63)),
  ("\\lceil", (4, 2, 0x64)), ("\\rceil", (5, 2, 0x65)),
  ("\\backslash", (0, 2, 0x6E)), ("\\setminus", (2, 2, 0x6E))]

/-- The large operators: name, slot in family 3, and amsmath's limits for them. -/
def bigOps : Std.HashMap String (Nat × Limits) := Std.HashMap.ofList [
  ("\\sum", (0x50, .normal)), ("\\prod", (0x51, .normal)), ("\\coprod", (0x60, .normal)),
  ("\\int", (0x52, .noLimits)), ("\\intop", (0x52, .normal)), ("\\oint", (0x48, .noLimits)),
  ("\\ointop", (0x48, .normal)), ("\\smallint", (0x73, .noLimits)),
  ("\\bigcup", (0x53, .normal)), ("\\bigcap", (0x54, .normal)),
  ("\\bigsqcup", (0x46, .normal)), ("\\bigvee", (0x57, .normal)),
  ("\\bigwedge", (0x56, .normal)), ("\\bigodot", (0x4A, .normal)),
  ("\\bigotimes", (0x4E, .normal)), ("\\bigoplus", (0x4C, .normal)),
  ("\\biguplus", (0x55, .normal))]

/-- The named operators amsmath sets with `\displaylimits` (`\qopname … m`). -/
def limitsOperators : List String :=
  ["lim", "limsup", "liminf", "max", "min", "sup", "inf", "det", "gcd", "Pr", "injlim",
   "projlim", "varlimsup", "varliminf", "varinjlim", "varprojlim"]

/-- The atom kind of a math class (7, variable family, is ordinary). -/
def kindOfClass : Nat → AtomKind
  | 1 => .op | 2 => .bin | 3 => .rel | 4 => .open | 5 => .close | 6 => .punct | 7 => .ord
  | _ => .ord

/-- The math code of a symbol as LaTeX defines it: class, family, slot. -/
def symbolCode (name : String) : Option (Nat × Nat × Nat) :=
  match name.toList with
  | [c] => mathCodeMap[c]? <|> (if c.toNat < 128 then none else none)
  | _ => mathCharMap[name]? <|> extraChars[name]? <|> (delimMap[name]?.map fun (k, d) =>
      (k, d.smallFam, d.smallChar))

/-- A delimiter by the parser's name: `.` for none, a character's `\delcode`, a named
delimiter. -/
def delimOf (name : String) : FM Delim := do
  if name == "." then return .null
  match name.toList with
  | [c] => match delCodeMap[c]? with
    | some d => return d
    | none => unsupported s!"delimiter {name}"
  | _ =>
    let alias_ := match name with
      | "\\{" => "\\lbrace" | "\\}" => "\\rbrace" | "\\lbrack" => "[" | "\\rbrack" => "]" | "\\vert" => "|" | "\\Vert" => "\\|"
      | "\\lvert" => "|" | "\\rvert" => "|" | "\\lVert" => "\\|" | "\\rVert" => "\\|"
      | n => n
    match alias_.toList with
    | [c] => match delCodeMap[c]? with
      | some d => return d
      | none => unsupported s!"delimiter {name}"
    | _ => match delimMap[alias_]? with
      | some (_, d) => return d
      | none => unsupported s!"delimiter {name}"

/-- A length of the parser's tree in sp: `number unit` as TeX reads it, `mu` returned
apart (in 2⁻¹⁶ mu). -/
def lengthOf (m : LeAnTeX.Measurement) : FM (Int × Bool) := do
  let ctx ← read
  let neg := m.number < 0
  let a := if neg then -m.number else m.number
  let ip := a.floor
  let f : Int := (((a - ip) * 65536).round).toUInt64.toNat
  let ipN : Int := ip.toUInt64.toNat
  let scaled := fun (u : Int) => nxPlusY ipN u (xnOverD u f 65536)
  let v ← match m.unit with
    | "pt" => pure (ipN * 65536 + f)
    | "em" => pure (scaled ctx.quad)
    | "ex" => pure (scaled ctx.xHeight)
    | "mu" => pure (ipN * 65536 + f)
    | "bp" => pure (xnOverD (ipN * 65536 + f) 7227 7200)
    | "mm" => pure (xnOverD (ipN * 65536 + f) 7227 2540)
    | "cm" => pure (xnOverD (ipN * 65536 + f) 7227 254)
    | "in" => pure (xnOverD (ipN * 65536 + f) 7227 100)
    | "pc" => pure (12 * (ipN * 65536 + f))
    | "sp" => pure ipN
    | u => unsupported s!"unit {u}"
  return (if neg then -v else v, m.unit == "mu")

/-- An atom of a symbol in the current family context. -/
def symbolAtom (name : String) : FM Noad := do
  let some (cls, fam, slot) := symbolCode name | unsupported s!"symbol {name}"
  if cls == 8 then unsupported s!"active character {name}"
  let cur := (← read).fam
  let fam := if cls == 7 then cur.getD fam else fam
  return .atom (kindOfClass cls) (.mathChar fam slot) .empty .empty

/-- A math list as a field, with TeX's reduction of a group holding one ordinary atom without
scripts to that atom's nucleus (§1186). -/
def fieldOf (l : Array Noad) : Field :=
  match l with
  | #[.atom .ord n .empty .empty _] => n
  | l => .list l

/-- A group as an atom: ordinary with the group as its nucleus. -/
def groupAtom (l : Array Noad) : Noad := .atom .ord (fieldOf l) .empty .empty

/-- Lays out a list in a style (the boxes LaTeX sets while building a list), with the math
nodes of a formula of its own around it. -/
def boxOf (l : Array Noad) (s : Style) : FM Node := do
  let h ← mlistToHlist maxNesting l s false
  return hpack (#[Node.math false 0] ++ h ++ #[Node.math true 0])

/-- `\mathchoice` of one list built for each style. -/
def paletteOf (f : Style → FM (Array Noad)) : FM Noad := do
  return .choice (← f .display) (← f .text) (← f .script) (← f .scriptscript)

/-- The text-mode content of a node of the parser's tree, as characters (spaces as spaces). -/
partial def textChars (n : LeAnTeX.Node) : Option String :=
  match n with
  | .sym _ _ _ t => if t == "\\ " || t == "~" then some " " else
      if t.length == 1 then some t else none
  | .text _ _ _ (some _) => none
  | .ordgroup _ _ b _ | .text _ _ b _ =>
    b.foldlM (init := "") fun acc x => (acc ++ ·) <$> textChars x
  | _ => none

/-- Text in a formula (amstext's `\text`): the text font of `key` at the size of style `s`,
shaped; spaces are the font's interword glue. -/
def textBox (s : String) (fam : Nat) (st : Style) : FM Node := do
  let (_, f) ← famFont fam st.size
  let .otf tf := f | unsupported "text in a formula without a text font"
  let mut out : Array Node := #[]
  let words := s.splitOn " "
  let mut first := true
  for w in words do
    if !first then out := out.push (.glue tf.space 13)
    first := false
    let cs := (LeAnTeX.Text.texLigatures w.toList.toArray)
    for h in tf.shape cs do
      match h with
      | .glyph c g gw gh gd _ => out := out.push (.glyph (← fontIndex tf) c g gw gh gd)
      | .kern k _ => out := out.push (.kern k .font)
      | _ => pure ()
  return hpack out
where
  /-- The index of a text font in the formula's table of fonts. -/
  fontIndex (tf : TextFont) : FM Nat := do
    let fs := (← readThe Env).fams
    match fs.fonts.findIdx? (fun g => g.name == tf.info.name && g.size == tf.size) with
    | some i => return i
    | none => unsupported "a text font outside the table"

/-- The family of a math alphabet. -/
def alphabetFam : String → Option Nat
  | "mathrm" | "mathup" | "operatorname" => some 0
  | "mathnormal" => some 1
  | "mathcal" => some 2
  | "mathbb" => some 5
  | "mathbf" => some 7
  | "mathit" => some 8
  | "mathsf" => some 9
  | "mathtt" => some 10
  | "mathfrak" => some 11
  | _ => none

/-- amsmath's `\big` sizes: 1, 1.5, 2 or 2.5 times `b` (amsmath's `\big@size`) for size 1–4,
as TeX multiplies a length by a decimal. -/
def bigSize (b : Int) (n : Nat) : Int :=
  match n with
  | 1 => b
  | 2 => nxPlusY 1 b (xnOverD b 32768 65536)
  | 3 => 2 * b
  | _ => nxPlusY 2 b (xnOverD b 32768 65536)

/-- `\mathinner` of three of a dot character (`\ldots`, `\cdots`). -/
def dots (dot : String) : Noad :=
  let (_, f, s) := (extraChars[dot]?).getD (6, 1, 0x3A)
  let d : Noad := .atom .punct (.mathChar f s) .empty .empty
  .atom .inner (.list #[d, d, d]) .empty .empty

/-- A box as an ordinary atom. -/
def groupAtom' (b : Node) : Noad := .atom .ord (.box b) .empty .empty

/-- Glue with its width, stretch and shrink negated. -/
def negGlue (g : Glue) : Glue :=
  { g with width := -g.width, stretch := -g.stretch, shrink := -g.shrink }

/-- Scripts attached to the last atom of a list that can take them (an empty ordinary atom
added when there is none). -/
def attachScripts (l : Array Noad) (sup sub : Field) : FM (Array Noad) := do
  let canTake := fun (s1 s2 : Field) => (sup.isEmpty || s1.isEmpty) && (sub.isEmpty || s2.isEmpty)
  let pick := fun (a b : Field) => if a.isEmpty then b else a
  match l.back? with
  | some (.atom k nuc s1 s2 lim) =>
    if canTake s1 s2 then return l.pop.push (.atom k nuc (pick sup s1) (pick sub s2) lim)
  | some (.radical nuc s1 s2 d) =>
    if canTake s1 s2 then return l.pop.push (.radical nuc (pick sup s1) (pick sub s2) d)
  | some (.accent nuc s1 s2 f c) =>
    if canTake s1 s2 then return l.pop.push (.accent nuc (pick sup s1) (pick sub s2) f c)
  | _ => pure ()
  return l.push (.atom .ord .empty sup sub)

/-- A relation atom of a character. -/
def relChar (fam slot : Nat) : Noad := .atom .rel (.mathChar fam slot) .empty .empty

/-- LaTeX's `\joinrel`: `\mathrel{\mkern-3mu}`. -/
def joinrel : Noad := .atom .rel (.list #[.kern (-3 * 65536) true]) .empty .empty

/-- LaTeX's `\Relbar`: `\mathrel=`. -/
def bigRelbar : Noad := relChar 0 0x3D

/-- The arrows and relations LaTeX builds from pieces (`fontmath.ltx`, amsmath): their lists;
`\relbar` (a smashed minus) is passed in, as it needs the layout. -/
def composite (relbar : Noad) (thick : Glue) : String → Option (Array Noad)
  | "\\mapsto" => some #[relChar 2 0x37, relChar 2 0x21]
  | "\\longmapsto" => some #[relChar 2 0x37, relbar, joinrel, relChar 2 0x21]
  | "\\longrightarrow" => some #[relbar, joinrel, relChar 2 0x21]
  | "\\Longrightarrow" => some #[bigRelbar, joinrel, relChar 2 0x29]
  | "\\longleftarrow" => some #[relChar 2 0x20, joinrel, relbar]
  | "\\Longleftarrow" => some #[relChar 2 0x28, joinrel, bigRelbar]
  | "\\longleftrightarrow" => some #[relChar 2 0x24, joinrel, relChar 2 0x21]
  | "\\Longleftrightarrow" => some #[relChar 2 0x28, joinrel, relChar 2 0x29]
  | "\\hookrightarrow" => some #[relChar 1 0x2C, joinrel, relChar 2 0x21]
  | "\\hookleftarrow" => some #[relChar 2 0x20, joinrel, relChar 1 0x2D]
  | "\\iff" => some #[.glue thick true, relChar 2 0x28, joinrel, relChar 2 0x29,
      .glue thick true]
  | "\\implies" => some #[.glue thick true, bigRelbar, joinrel, relChar 2 0x29, .glue thick true]
  | "\\impliedby" => some #[.glue thick true, relChar 2 0x28, joinrel, bigRelbar,
      .glue thick true]
  | _ => none

/-- A column of an array: its alignment and what stands before and after it (`none` for
`\arraycolsep`, else a width: `@{}` is 0, cases' `@{\quad}` 1em). -/
structure Column where
  /-- `l`, `c` or `r`. -/
  align : String
  /-- Before the column. -/
  pre : Option Int := none
  /-- After it. -/
  post : Option Int := none

/-- LaTeX's `array` as `\halign` sets it in a `\vcenter` (`latex.ltx`'s `\@array`): every
cell a formula in text style between `\arraycolsep` (or the column's own material) and
`\hfil` glue as its alignment asks, a strut of `\arraystretch` times the strut box in the first
column of every row, the columns as wide as their widest cell, the rows stacked with
`\baselineskip` and `\lineskip` 0. -/
def arrayBox (cols : Array Column) (cells : Array (Array (Array Node))) (sep sh sd : Int) :
    Node := Id.run do
  let ncols := cells.foldl (init := 0) fun m r => max m r.size
  let hfil : Node := .glue { stretch := 65536, stretchOrder := 1 } 0
  -- each cell's material before packing
  let mut mats : Array (Array (Array Node)) := #[]
  for row in cells do
    let mut r : Array (Array Node) := #[]
    for j in [0:ncols] do
      let col := cols[j]?.getD { align := "c" }
      let body := row[j]?.getD #[]
      let pre : Array Node := #[.glue { width := col.pre.getD sep } 0]
      let post : Array Node := #[.glue { width := col.post.getD sep } 0]
      let (l, rr) := match col.align with
        | "l" => (#[], #[hfil])
        | "r" => (#[hfil], #[])
        | _ => (#[hfil], #[hfil])
      let strut : Array Node := if j == 0 then #[.rule (some 0) (some sh) (some sd)] else #[]
      r := r.push (strut ++ pre ++ l ++ #[Node.math false 0] ++ body ++ #[.math true 0] ++ rr ++
        post)
    mats := mats.push r
  let widths := (Array.range ncols).map fun j =>
    mats.foldl (init := 0) fun m r => max m ((hpack (r[j]?.getD #[])).width)
  let mut rows : Array Node := #[]
  let mut first := true
  for r in mats do
    if !first then rows := rows.push (.glue {} 1)
    first := false
    let mut line : Array Node := #[.glue {} 12]
    for j in [0:ncols] do
      line := line.push (hpack (r[j]?.getD #[]) (some (widths.getD j 0)))
      line := line.push (.glue {} 12)
    rows := rows.push (hpack line)
  return vpack rows

mutual

/-- The math list of a node. -/
partial def convNode (n : LeAnTeX.Node) : FM (Array Noad) := do
  charge
  match n with
  | .sym _ _ g t =>
    match g with
    | .spacing => spacing t
    | _ =>
      let p := (← readThe Env).params
      let relbar := Noad.atom .rel (.list #[← paletteOf fun st => do
        let z ← boxOf #[Noad.style st, groupAtom #[.atom .bin (.mathChar 2 0) .empty .empty]] .text
        pure #[groupAtom' (.box false z.width 0 0 0 {} z.list)]]) .empty .empty
      if let some l := composite relbar p.thickMuSkip t then return l
      let isL := t == "\\ldots" || t == "\\@ldots" || t == "\\mathellipsis" || t == "…"
      let isC := t == "\\cdots" || t == "\\@cdots" || t == "⋯"
      if isL || isC then
        let k ← getModify (· + 1)
        let d := dots (if isL then "\\ldotp" else "\\cdotp")
        if ((← read).dots[k]?).getD false then
          return #[d, .glue (← readThe Env).params.thinMuSkip true]
        return #[d]
      return #[← symbolAtom t]
  | .ordgroup _ _ b _ => return #[groupAtom (← convList b)]
  | .supsub _ _ base sup sub => do
    let l ← match base with
      | some b => convNode b
      | none => pure #[]
    let supF ← fieldOpt sup
    let subF ← fieldOpt sub
    attachScripts l supF subF
  | .op _ _ lim always _ _ symbol name body => convOp lim always symbol name body
  | .operatorname _ _ body _ lim _ =>
    let b ← withReader (fun c => { c with fam := some 0 }) (convList body)
    let word := String.join (body.toList.filterMap fun x => x.symText?)
    let star := match n with
      | .operatorname _ _ _ always _ _ => always
      | _ => false
    return #[.atom .op (.list (#[Noad.kern 0 false] ++ b)) .empty .empty
      (if lim || star || limitsOperators.contains word then .normal else .noLimits)]
  | .hbox _ _ body =>
    let some s := (body.foldlM (init := "") fun acc x => (acc ++ ·) <$> textChars x)
      | unsupported "a box that is not plain text"
    return #[groupAtom' (← textBox s 0 .text)]
  | .genfrac _ _ _ num den bar ld rd size =>
    let thick ← match size with
      | some m => some <$> (Prod.fst <$> lengthOf m)
      | none => pure (if bar then none else some 0)
    let l ← match ld with | some d => delimOf d | none => pure .null
    let r ← match rd with | some d => delimOf d | none => pure .null
    let fr := Noad.fraction (fieldOf (← convNode' num)) (fieldOf (← convNode' den)) thick l r
    return #[groupAtom #[fr]]
  | .styling _ _ st _ body =>
    let s := match st with
      | "display" => Style.display | "script" => .script | "scriptscript" => .scriptscript
      | _ => .text
    let b ← convList body
    match body with
    | #[.genfrac ..] => return #[groupAtom (#[Noad.style s] ++ b)]
    | _ => return #[Noad.style s] ++ b
  | .sqrt _ _ body index =>
    let rad := fun (s : Option Style) => do
      let nuc := fieldOf (← convNode' body)
      let r : Noad := .radical nuc .empty .empty (Delim.ofCode 0x270370)
      pure (match s with | some s => #[Noad.style s, r] | none => #[r])
    match index with
    | none => rad none
    | some ix =>
      -- LaTeX's \root: the index set once in scriptscript style, then \mathpalette
      let ixl ← convNode' ix
      let rootBox ← boxOf (#[Noad.style .scriptscript, groupAtom ixl]) .text
      let choice ← paletteOf fun s => do
        let z ← boxOf (← rad (some s)) .text
        let raise := xnOverD (z.height - z.depth) 39322 65536
        pure #[Noad.kern 0 true, Noad.kern (5 * 65536) true,
          groupAtom' (rootBox.withShift (-raise)), Noad.kern (-10 * 65536) true,
          Noad.kern 0 true, groupAtom' z]
      return #[groupAtom #[choice]]
  | .leftright _ _ body l r _ =>
    let b ← convList body
    return #[.atom .inner (.list (#[Noad.delim 0 (← delimOf l)] ++ b ++
      #[Noad.delim 2 (← delimOf r)])) .empty .empty]
  | .middle _ _ d => return #[.delim 1 (← delimOf d)]
  | .delimsizing _ _ size mclass d =>
    let dl ← delimOf d
    -- amsmath's \big@size: 1.2 times the height plus 1.2 times the depth of `(`
    let paren := (← fetch 6 0x28 0).map (·.2.2)
    let ht := (paren.map (·.height)).getD 0
    let dp := (paren.map (·.depth)).getD 0
    let h := bigSize ((ht + xnOverD ht 13107 65536) + (dp + xnOverD dp 13107 65536)) size
    let inner : Array Noad := #[.delim 0 dl,
      .atom .vcenter (.box (.box true 0 h 0 0 {} #[])) .empty .empty, .delim 2 .null]
    let z ← withTheReader Env (fun e => { e with params :=
      { e.params with nullDelimiterSpace := 0 } }) (boxOf inner .text)
    let kind := match mclass with
      | "mopen" => AtomKind.open | "mclose" => .close | "mrel" => .rel | "mbin" => .bin
      | "mpunct" => .punct | "minner" => .inner | _ => .ord
    return #[.atom kind (fieldOf #[groupAtom #[groupAtom' z]]) .empty .empty]
  | .accent _ _ label _ _ base =>
    let nuc := fieldOf (← convNode' base)
    if label == "\\widehat" || label == "\\widetilde" then
      let w := (← boxOf #[.atom .ord nuc .empty .empty] .text).width
      let (wide, narrow) := if label == "\\widehat" then (0x5B, 0x62) else (0x5D, 0x65)
      let (fam, slot) := if w > 2 * (← read).quad then (5, wide) else (3, narrow)
      return #[.accent nuc .empty .empty fam slot]
    match accentMap[label]? with
    | some (fam, slot) => return #[.accent nuc .empty .empty fam slot]
    | none => unsupported s!"accent {label}"
  | .overline _ _ body => return #[.atom .over (fieldOf (← convNode' body)) .empty .empty]
  | .underline _ _ body => return #[.atom .under (fieldOf (← convNode' body)) .empty .empty]
  | .font _ _ font body =>
    match alphabetFam font with
    | some fam =>
      let b ← withReader (fun c => { c with fam := some fam }) (convNode' body)
      return #[groupAtom b]
    | none => unsupported s!"\\{font}"
  | .text _ _ body font =>
    let some s := (body.foldlM (init := "") fun acc x => (acc ++ ·) <$> textChars x)
      | unsupported "text that is not plain characters"
    let fam := match font with
      | some "\\textbf" => 7 | some "\\textit" => 8 | some "\\textsf" => 9
      | some "\\texttt" => 10 | _ => 0
    let ch ← paletteOf fun st => do pure #[groupAtom' (← textBox s fam st)]
    return #[groupAtom #[ch]]
  | .mclass _ _ mc body _ =>
    let b ← convList body
    let kind := match mc with
      | "mbin" => AtomKind.bin | "mrel" => .rel | "mopen" => .open | "mclose" => .close
      | "mpunct" => .punct | "minner" => .inner | "mop" => .op | _ => .ord
    return #[.atom kind (fieldOf b) .empty .empty]
  | .mathchoice _ _ d t s ss =>
    return #[.choice (← convList d) (← convList t) (← convList s) (← convList ss)]
  | .kern _ _ m =>
    let (v, mu) ← lengthOf m
    if mu then
      let p := (← readThe Env).params
      if v == 3 * 65536 then return #[.glue p.thinMuSkip true]
      if v == -3 * 65536 then return #[.glue (negGlue p.thinMuSkip) true]
      if v == 4 * 65536 then return #[.glue p.medMuSkip true]
      if v == 5 * 65536 then return #[.glue p.thickMuSkip true]
      return #[.kern v true]
    -- \quad, \hspace, \kern: TeX's \hskip in the text font's units
    return #[.glue { width := v } false]
  | .color _ _ _ body => convList body
  | .phantom _ _ body =>
    let b ← convList body
    return #[← paletteOf fun s => do
      let z ← boxOf (#[Noad.style s, groupAtom b]) .text
      pure #[groupAtom' (.box false z.width z.height z.depth 0 {} #[])]]
  | .vphantom _ _ body =>
    let b ← convNode' body
    return #[← paletteOf fun s => do
      let z ← boxOf (#[Noad.style s, groupAtom b]) .text
      pure #[groupAtom' (.box false 0 z.height z.depth 0 {} #[])]]
  | .smash _ _ body sh sd =>
    let b ← convNode' body
    return #[← paletteOf fun s => do
      let z ← boxOf (#[Noad.style s, groupAtom b]) .text
      pure #[groupAtom' (.box false z.width (if sh then 0 else z.height)
        (if sd then 0 else z.depth) 0 {} z.list)]]
  | .internal .. => return #[]
  | .array _ _ sep hskip jot cols stretch body rowGaps hlines tags _ =>
    if sep.isSome || jot.isSome then unsupported "this array environment"
    if rowGaps.any (·.isSome) then unsupported "array row gaps"
    if hlines.any (!·.isEmpty) then unsupported "array rules"
    if tags.isSome then unsupported "array tags"
    let c ← read
    let columns ← (cols.getD #[]).filterMapM fun a => match a with
      | .align al pre post => do
        let w := fun (g : Option Float) => g.map fun x =>
          if x == 0 then (0 : Int) else xnOverD c.quad ((x * 65536).round.toUInt64.toNat) 65536
        pure (some ({ align := al, pre := w pre, post := w post } : Column))
      | .separator _ => unsupported "array separators"
    let mut cells : Array (Array (Array Node)) := #[]
    for row in body do
      let mut r : Array (Array Node) := #[]
      for cell in row do
        let l ← match cell with
          | .styling _ _ "text" _ #[g] => convNode' g
          | .styling .. => unsupported "array cells in script style"
          | x => convNode' x
        r := r.push (← mlistToHlist maxNesting l .text false)
      cells := cells.push r
    let sh := if stretch == 1 then c.strutHeight
      else xnOverD c.strutHeight ((stretch * 65536).round.toUInt64.toNat) 65536
    let sd := if stretch == 1 then c.strutDepth
      else xnOverD c.strutDepth ((stretch * 65536).round.toUInt64.toNat) 65536
    let v := arrayBox columns cells c.arrayColSep sh sd
    let vc : Noad := .atom .vcenter (.box v) .empty .empty
    if hskip == some false then
      let neg : Noad := .glue { width := -c.arrayColSep } false
      return #[neg, vc, neg]
    return #[vc]
  | n => unsupported n.type

/-- The math list of a node, an argument of a command (its group's content when it is a
group). -/
partial def convNode' (n : LeAnTeX.Node) : FM (Array Noad) := do
  match n with
  | .ordgroup _ _ b _ => convList b
  | n => convNode n

/-- The math list of a list of nodes. -/
partial def convList (l : Array LeAnTeX.Node) : FM (Array Noad) := do
  let mut out : Array Noad := #[]
  for n in l do out := out ++ (← convNode n)
  return out

/-- A script as a field. -/
partial def fieldOpt (n : Option LeAnTeX.Node) : FM Field := do
  match n with
  | none => return .empty
  | some x => return fieldOf (← convNode' x)

/-- A large operator. -/
partial def convOp (lim : Bool) (always : Option Bool) (symbol : Bool) (name : Option String)
    (body : Option (Array LeAnTeX.Node)) : FM (Array Noad) := do
  let explicit : Option Limits := match always with
    | some true => some (if lim then .limits else .noLimits)
    | _ => none
  match name, body with
  | some nm, _ =>
    let ints := match nm with
      | "\\iint" => 2 | "\\iiint" => 3 | "\\iiiint" => 4 | _ => 0
    if symbol && ints > 0 then
      -- amsmath's \MultiIntegral with \nolimits: integral signs closed up by \intkern@
      if explicit.isSome then unsupported s!"{nm} with \\limits or \\nolimits"
      let int := fun (l : Limits) => Noad.atom .op (.mathChar 3 0x52) .empty .empty l
      let kern : Array Noad := #[.kern (-6 * 65536) true,
        .choice #[.kern (-3 * 65536) true] #[] #[] #[]]
      let mut l : Array Noad := #[]
      for _ in [1:ints] do l := l.push (int .normal) ++ kern
      return l.push (int .noLimits)
    if symbol then
      match bigOps[nm]? with
      | some (slot, l) => return #[.atom .op (.mathChar 3 slot) .empty .empty (explicit.getD l)]
      | none => unsupported s!"operator {nm}"
    else
      let word := nm.drop 1 |>.toString
      let text := match word with
        | "limsup" => "lim\\,sup" | "liminf" => "lim\\,inf" | "injlim" => "inj\\,lim"
        | "projlim" => "proj\\,lim" | w => w
      let mut l : Array Noad := #[.kern 0 false]
      for part in (text.splitOn "\\,") do
        if l.size > 1 then l := l.push (.glue (← readThe Env).params.thinMuSkip true)
        for c in part.toList do
          let some (_, _, slot) := mathCodeMap[c]? | unsupported s!"operator {nm}"
          l := l.push (.atom .ord (.mathChar 0 slot) .empty .empty)
      let d := if limitsOperators.contains word then Limits.normal else .noLimits
      return #[.atom .op (.list l) .empty .empty (explicit.getD d)]
  | none, some b =>
    return #[.atom .op (fieldOf (← convList b)) .empty .empty (explicit.getD .normal)]
  | none, none => unsupported "operator"

/-- Spacing commands. -/
partial def spacing (t : String) : FM (Array Noad) := do
  let c ← read
  match t with
  | "\\ " | " " => return #[.glue c.space false]
  | "~" | "\\nobreakspace" => return #[.penalty 10000, .glue c.space false]
  | "\\nobreak" => return #[.penalty 10000]
  | "\\allowbreak" => return #[.penalty 0]
  | "\\quad" => return #[.glue { width := c.quad } false]
  | "\\qquad" => return #[.glue { width := 2 * c.quad } false]
  | t => unsupported s!"spacing {t}"

end

/-- The macros LaTeX and amsmath define differently from the parser's built-ins, for a formula
that is displayed (`display`) or not: `\pmod`'s space, `\ne` and `\neq` as `\not=`. -/
def texMacros (display : Bool) : Array (String × String) := #[
  ("\\pmod", s!"\\allowbreak\\mkern{if display then 18 else 8}mu(\\mathrm\{mod}\\mkern6mu #1)"),
  ("\\pod", s!"\\allowbreak\\mkern{if display then 18 else 8}mu(#1)"),
  ("\\mod", s!"\\allowbreak\\mkern{if display then 18 else 12}mu\\mathrm\{mod}\\,\\,#1"),
  ("\\ne", "\\@not="), ("\\neq", "\\@not="), ("\\not", "\\@not"), ("\\mbox", "\\hbox{#1}")]

/-- The dots commands of a source in order, each with whether amsmath sets a thin space after
it: `\cdots`, `\dotsb`, `\dotsm`, `\dotsi`, `\dotso` and `\dots` (amsmath's `\extrap@`) when
the next token is `,`, `;`, `.`, the end of the formula or a closing delimiter (`\extra@`);
`\dotsc` only before `;`, `.`, the end or a closing delimiter; `\ldots` never. -/
def dotsInSource (src : String) : Array Bool := Id.run do
  let cs := src.toList.toArray
  let mut out : Array Bool := #[]
  let mut i := 0
  for _ in [0:cs.size + 1] do
    if i ≥ cs.size then break
    if cs[i]? == some '\\' then
      let mut j := i + 1
      for _ in [0:cs.size] do
        if (cs[j]?.map Char.isAlpha).getD false then j := j + 1 else break
      let name := String.ofList (cs.extract (i + 1) j).toList
      if ["ldots", "dots", "cdots", "dotsb", "dotsm", "dotsi", "dotso", "dotsc",
          "mathellipsis"].contains name then
        let mut k := j
        for _ in [0:cs.size] do
          if (cs[k]?.map Char.isWhitespace).getD false then k := k + 1 else break
        let rest := String.ofList (cs.extract k cs.size).toList
        let closing := rest.isEmpty || ["\\right", ")", "]", "\\}", "\\rangle", "|", "\\|",
          "\\rvert", "\\rVert", "\\rbrace", "\\rfloor", "\\rceil", "}"].any (fun (p : String) => rest.startsWith p)
        let punct := rest.startsWith "," || rest.startsWith ";" || rest.startsWith "."
        let thin := match name with
          | "ldots" | "mathellipsis" | "dotsi" => false
          | "dotsc" => closing || rest.startsWith ";" || rest.startsWith "."
          | "dots" => if rest.startsWith "," then false else closing || punct
          | _ => closing || punct
        out := out.push thin
      i := max j (i + 1)
    else i := i + 1
  return out

/-- Whether a source uses what the parser's tree cannot tell apart from other constructs: the
generalised fractions `\over`, `\atop`, `\above`, `\choose`, `\brace`, `\brack` (TeX's,
without amsmath's groups) and glue with `plus` or `minus`. -/
def hasUnsupportedSyntax (src : String) : Bool :=
  ["\\over", "\\atop", "\\above", "\\choose", "\\brace", "\\brack"].any (fun c =>
    (src.splitOn c).drop 1 |>.any fun r => !(r.toList.headD ' ').isAlpha) ||
  (["\\hskip", "\\mskip", "\\hspace"].any (fun c => (src.splitOn c).length > 1) &&
    (src.splitOn "plus").length + (src.splitOn "minus").length > 2)

/-- Parses a formula for the TeX-rule layout: the parser with `texMacros` added. -/
def parseForTeX (src : String) (settings : LeAnTeX.Settings) (displayMath : Bool) :
    Except String (Array LeAnTeX.Node) :=
  if hasUnsupportedSyntax src then .error "not supported by the TeX-rule layout: \\over, \\atop, \\choose, \\above or glue with plus or minus" else
  let s := { settings with macros := texMacros displayMath ++ settings.macros }
  match (LeAnTeX.parse src s).result with
  | .ok t => .ok t
  | .error e => .error e.message

/-- The math list of a parsed formula. -/
def toMathList (t : Array LeAnTeX.Node) (ctx : FrontCtx) : M (Array Noad) :=
  (convList t).run { ctx with dots := dotsInSource ctx.source } |>.run' 0

end LeAnTeX.TeXMath
