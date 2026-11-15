/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.TeXMath.Arith
import LeAnTeX.TeXMath.Font
import LeAnTeX.TeXMath.Noad

/-!
# A math list to a horizontal list

TeX's conversion of a formula's math list into boxes, as *The TeXbook*'s Appendix G states it
in rules 1 to 22 and *TeX: The Program* implements it in `mlist_to_hlist` (§719–§767),
implemented here from that description: two passes over the list, the first setting each atom
(characters with their italic corrections and the ligatures and kerns of rule 14, large
operators with their limits, fractions, radicals, accents, `\overline`, `\underline`,
`\vcenter`, superscripts and subscripts with all of rule 18's clearances and `\scriptspace`),
the second sizing `\left`, `\middle` and `\right` delimiters to the list's height and depth
(rule 19 and the delimiter search of §706), putting the inter-atom spacing of the table of
*The TeXbook* (Chapter 18) between atoms, suppressed in script styles where it says so, and the
penalties after binary operations and relations in a paragraph's formula.

Every length is computed in sp with TeX's rounding (`LeAnTeX.TeXMath.Arith`): the boxes are
TeX's to the sp when the fonts are TeX's.

## Main definitions

* `Params`: the parameters the conversion reads (`\thinmuskip` … `\scriptspace`,
  `\delimiterfactor`, `\delimitershortfall`, `\nulldelimiterspace`, the penalties).
* `mlistToHlist`: the conversion.
* `Budget`: the bound on its work.

## Implementation notes

Untrusted input: a formula's nesting is bounded by the recursion's fuel, and every step (an
atom set, a variant of a delimiter looked at, a piece of an extensible delimiter, a ligature
applied) is charged to a work budget; past either the result is an error, never a hang. A
missing character is skipped with a warning, as TeX skips it; a family without a font is an
error, as in TeX.

`\middle` (e-TeX) is a delimiter sized with the whole list: before it the spacing is that
before a closing atom, after it that after an opening one, and the style returns to the list's
own.

## References

* D. E. Knuth, *The TeXbook*, Chapter 17 (styles), Chapter 18 (the spacing table),
  Appendix G (rules 1–22).
* D. E. Knuth, *TeX: The Program*, §699–§767; the e-TeX extensions for `\middle`.
-/

namespace LeAnTeX.TeXMath

open LeAnTeX.Text (Glue KernKind)

/-- The parameters the conversion reads, with LaTeX's values. -/
structure Params where
  /-- `\thinmuskip` (in mu, 2⁻¹⁶ mu units): 3mu. -/
  thinMuSkip : Glue := { width := 3 * 65536 }
  /-- `\medmuskip`: 4mu plus 2mu minus 4mu. -/
  medMuSkip : Glue := { width := 4 * 65536, stretch := 2 * 65536, shrink := 4 * 65536 }
  /-- `\thickmuskip`: 5mu plus 5mu. -/
  thickMuSkip : Glue := { width := 5 * 65536, stretch := 5 * 65536 }
  /-- `\scriptspace`: 0.5pt. -/
  scriptSpace : Int := 32768
  /-- `\delimiterfactor`: 901. -/
  delimiterFactor : Int := 901
  /-- `\delimitershortfall`: 5pt. -/
  delimiterShortfall : Int := 5 * 65536
  /-- `\nulldelimiterspace`: 1.2pt. -/
  nullDelimiterSpace : Int := 78643
  /-- `\binoppenalty`: 700. -/
  binOpPenalty : Int := 700
  /-- `\relpenalty`: 500. -/
  relPenalty : Int := 500
  deriving Inhabited

/-- What the conversion reads: the families and the parameters. -/
structure Env where
  /-- The fonts and the family table. -/
  fams : Families
  /-- The parameters. -/
  params : Params := {}

/-- The work done so far and the warnings. -/
structure St where
  /-- Steps taken. -/
  work : Nat := 0
  /-- The most steps allowed. -/
  budget : Nat := 1000000
  /-- Warnings (missing characters), in order. -/
  warnings : Array String := #[]

/-- The conversion's monad: the environment, the work and warnings, and an error. -/
abbrev M := ReaderT Env (StateT St (Except String))

/-- The default bound on the steps of one formula. -/
def Budget.default : Nat := 1000000

/-- Charges `n` steps to the budget; an error past it. -/
def charge (n : Nat := 1) : M Unit := do
  let s ← get
  if s.work + n > s.budget then throw "formula too costly to lay out (work budget)"
  set { s with work := s.work + n }

/-- The font of a family at a size, with its index; an error when the family has none. -/
def famFont (fam : Nat) (s : MathSize) : M (Nat × MathFont) := do
  let fs := (← read).fams
  match fs.index? fam s with
  | some i => match fs.fonts[i]? with
    | some f => return (i, f)
    | none => throw s!"\\fam{fam} is undefined"
  | none => throw s!"\\textfont{fam} is undefined (or \\scriptfont, \\scriptscriptfont)"

/-- `\fontdimen n` of family 2 at a size (TeX's `mathsy`). -/
def mathsy (n : Nat) (s : MathSize) : M Int := do return (← famFont 2 s).2.param n

/-- `\fontdimen n` of family 3 at a size (TeX's `mathex`). -/
def mathex (n : Nat) (s : MathSize) : M Int := do return (← famFont 3 s).2.param n

/-- The axis height at a size (family 2's `\fontdimen22`). -/
def axisHeight (s : MathSize) : M Int := mathsy 22 s

/-- The default rule thickness at a size (family 3's `\fontdimen8`). -/
def ruleThickness (s : MathSize) : M Int := mathex 8 s

/-- The math unit at a size: the quad of family 2 over 18, rounded toward zero. -/
def mathUnit (s : MathSize) : M Int := do return (xOverN (← mathsy 6 s) 18).1

/-- A character of a family at a size: its font index, font and metrics; `none`, with TeX's
warning, when the font has no such character. -/
def fetch (fam code : Nat) (s : MathSize) : M (Option (Nat × MathFont × CharMetrics)) := do
  let (i, f) ← famFont fam s
  match f.char? code with
  | some m => return some (i, f, m)
  | none =>
    modify fun st => { st with
      warnings := st.warnings.push s!"Missing character: There is no {code} in font {f.name}" }
    return none

/-- A character node. -/
def newChar (i code : Nat) (m : CharMetrics) : Node := .char i code m.width m.height m.depth

/-- A box holding one character, its width including the italic correction (TeX's
`char_box`). -/
def charBox (i code : Nat) (m : CharMetrics) : Node :=
  .box false (m.width + m.italic) m.height m.depth 0 {} #[newChar i code m]

/-- TeX's `ss_glue`: 0pt plus 1fil minus 1fil. -/
def ssGlue : Node :=
  let g : Glue := { stretch := 65536, stretchOrder := 1, shrink := 65536, shrinkOrder := 1 }
  .glue g 0

/-- A box centred in width `w` (TeX's `rebox`): a vertical box is first put in a horizontal
one, a lone character gets a kern making up its box's width, and the list is put between
`\hss` glue and set to `w`; an empty box only gets the width. -/
def rebox (b : Node) (w : Int) : Node :=
  match b with
  | .box vert bw _ _ _ _ l =>
    if bw != w && !l.isEmpty then
      let b' := if vert then hpack #[b] else b
      let p := b'.list
      let p := match p with
        | #[.char f c cw ch cd] =>
          if b'.width != cw then #[.char f c cw ch cd, .kern (b'.width - cw) .font]
          else #[.char f c cw ch cd]
        | p => p
      hpack (#[ssGlue] ++ p ++ #[ssGlue]) (some w)
    else b.withWidth w
  | n => n

/-- A rule of thickness `t` as wide as its box (TeX's `fraction_rule`). -/
def fractionRule (t : Int) : Node := .rule none (some t) (some 0)

/-- A box with a rule above it (TeX's `overbar`): kern `t`, a rule of thickness `t`, kern `k`,
the box. -/
def overbar (b : Node) (k t : Int) : Node :=
  vpack #[.kern t .font, fractionRule t, .kern k .font, b]

/-- TeX's `math_glue`: glue in mu at the math unit `m`; infinite stretch or shrink is kept. -/
def mathGlue (g : Glue) (m : Int) : Glue :=
  { width := muMult m g.width, stretchOrder := g.stretchOrder, shrinkOrder := g.shrinkOrder,
    stretch := if g.stretchOrder == 0 then muMult m g.stretch else g.stretch,
    shrink := if g.shrinkOrder == 0 then muMult m g.shrink else g.shrink }

/-- An extensible delimiter of character `c` of font `i` (TeX §713): its pieces stacked in a
vertical box, the repeated piece used as often as it takes to reach `v`, as wide as the
repeated piece with its italic correction. -/
def extensible (i : Nat) (f : MathFont) (c : Nat) (v : Int) : M Node := do
  let some r := f.recipe? c | return .box true 0 0 0 0 {} #[]
  let hd := fun (x : Nat) => match f.char? x with
    | some m => m.height + m.depth
    | none => 0
  let piece := fun (x : Nat) => match f.char? x with
    | some m => charBox i x m
    | none => .box false 0 0 0 0 {} #[]
  let repM := (f.char? r.rep).getD default
  let width := repM.width + repM.italic
  let u := hd r.rep
  let mut w := 0
  if r.bot != 0 then w := w + hd r.bot
  if r.mid != 0 then w := w + hd r.mid
  if r.top != 0 then w := w + hd r.top
  let mut n := 0
  if u > 0 then
    -- each step adds at least u ≥ 1 sp; the work budget bounds the steps
    for _ in [0:(← get).budget + 1] do
      if w ≥ v then break
      charge
      w := w + u
      n := n + 1
      if r.mid != 0 then w := w + u
  -- the list from the top: top, repeats, middle, repeats, bottom (TeX stacks from the bottom)
  let mut l : Array Node := #[]
  if r.top != 0 then l := l.push (piece r.top)
  if r.mid != 0 then
    l := l ++ Array.replicate n (piece r.rep)
    l := l.push (piece r.mid)
  l := l ++ Array.replicate n (piece r.rep)
  if r.bot != 0 then l := l.push (piece r.bot)
  -- LuaTeX sets the whole size as the height (TeX82 would take the top piece's height and the
  -- rest as depth); the box is centred on the axis afterwards either way
  return .box true width w 0 0 {} l

/-- TeX's `var_delimiter`: the delimiter `d` at size `s` at least `v` tall (height plus
depth), or the largest there is: the small variant's family at `s` and the smaller sizes down
to text size when `largerSizes` (TeX82 always; LuaTeX, which this follows, for a fraction's
delimiters only), each with its chain of larger characters, then the large variant's; an
extensible character ends the search. Centred on the axis; the empty box of a null delimiter
too unless `centreNull` is false (LuaTeX leaves it unshifted for `\left.` and `\right.`). -/
def varDelimiter (d : Delim) (s : MathSize) (v : Int) (centreNull : Bool := true)
    (largerSizes : Bool := false) : M Node := do
  let fs := (← read).fams
  let mut best : Option (Nat × MathFont × Nat × CharMetrics) := none
  let mut bestSize : MathSize := s
  let mut w : Int := 0
  let mut ext := false
  let mut done := false
  for attempt in [0:2] do
    if done then break
    let (z, x) := if attempt == 0 then (d.smallFam, d.smallChar) else (d.largeFam, d.largeChar)
    if z != 0 || x != 0 then
      -- TeX82 goes on to the larger sizes down to text size (§707); LuaTeX, whose boxes these
      -- are, does so for a fraction's delimiters only (found against its lists)
      for k in [0:(if largerSizes then s.val + 1 else 1)] do
        if done then break
        let sz : MathSize := ⟨s.val - k, by omega⟩
        match fs.index? z sz with
        | none => pure ()
        | some gi =>
          let some g := fs.fonts[gi]? | pure ()
          let mut y := x
          -- at most 256 steps along the chain of larger characters
          for _ in [0:257] do
            charge
            match g.char? y with
            | none => break
            | some m =>
              if m.tag matches .ext _ then
                best := some (gi, g, y, m); bestSize := sz; ext := true; done := true; break
              let u := m.height + m.depth
              if u > w then
                best := some (gi, g, y, m); bestSize := sz; w := u
                if u ≥ v then done := true; break
              match m.tag with
              | .list nx => y := nx
              | _ => break
  let b ← match best with
    | some (gi, g, c, m) => if ext then extensible gi g c v else pure (charBox gi c m)
    | none =>
      let nds := (← read).params.nullDelimiterSpace
      pure (.box false nds 0 0 0 {} #[])
  -- centred on the axis of the size the delimiter was found at (LuaTeX; TeX82 takes `s`'s)
  let ax ← axisHeight bestSize
  if best.isNone && !centreNull then return b
  return b.withShift (half (b.boxHeight - b.boxDepth) - ax)

/-- The type of the previous noad in the first pass, for rules 5 and 6. -/
inductive RType where
  /-- An atom of this kind (a radical, an accent, a fraction count as ordinary). -/
  | atom (k : AtomKind)
  /-- `\left`, or `\middle` (after which a binary operation becomes ordinary, as after an
  opening). -/
  | left
  deriving BEq, Inhabited

/-- An item after the first pass: a set atom (its spacing class, its penalty, its list), a
delimiter waiting for the list's size, a style change, or a node passed through. -/
inductive Item where
  /-- An atom: its kind for spacing, and its horizontal list. -/
  | atom (kind : AtomKind) (hlist : Array Node)
  /-- `\left` (0), `\middle` (1) or `\right` (2). -/
  | delim (side : Nat) (d : Delim)
  /-- A style change. -/
  | style (s : Style)
  /-- A node. -/
  | node (n : Node) (isPenalty : Bool)
  deriving Inhabited

/-- The spacing between two atoms of the kinds with indices `l` and `r` (rows and columns
ord, op, bin, rel, open, close, punct, inner), as *The TeXbook*'s table in Chapter 18 gives it
(and *TeX: The Program* §764 encodes it): 0 none, 1 a thin space in display and text style, 2 a
thin space, 3 a medium space in display and text style, 4 a thick space in display and text
style. The pairs the table leaves blank
(they cannot occur once rules 5 and 6 have run) are 0. -/
def spacingTable (l r : Fin 8) : Fin 5 :=
  let row : Array (Fin 5) := match l.val with
    | 0 => #[0, 2, 3, 4, 0, 0, 0, 1]
    | 1 => #[2, 2, 0, 4, 0, 0, 0, 1]
    | 2 => #[3, 3, 0, 0, 3, 0, 0, 3]
    | 3 => #[4, 4, 0, 0, 4, 0, 0, 4]
    | 4 => #[0, 0, 0, 0, 0, 0, 0, 0]
    | 5 => #[0, 2, 3, 4, 0, 0, 0, 1]
    | 6 => #[1, 1, 0, 1, 1, 1, 1, 1]
    | _ => #[1, 2, 3, 4, 1, 0, 1, 1]
  row.getD r.val 0

/-- The glue between atoms of spacing indices `l` and `r` in style `s` at math unit `mu`, with
LuaTeX's subtype (17 thin, 18 medium, 19 thick), or `none`. -/
def interAtomGlue (p : Params) (l r : Fin 8) (s : Style) (mu : Int) : Option Node :=
  match spacingTable l r with
  | 1 => if s.isLarge then some (.glue (mathGlue p.thinMuSkip mu) 17) else none
  | 2 => some (.glue (mathGlue p.thinMuSkip mu) 17)
  | 3 => if s.isLarge then some (.glue (mathGlue p.medMuSkip mu) 18) else none
  | 4 => if s.isLarge then some (.glue (mathGlue p.thickMuSkip mu) 19) else none
  | _ => none

/-- The recursive call the rules use: a math list in a style to a horizontal list (without
penalties, as for every list inside a formula). -/
abbrev Rec := Array Noad → Style → M (Array Node)

/-- TeX's `clean_box`: a field as a box in a style. A box with no shift is kept, other material
is packed; a lone character's trailing kern is removed (the box keeps its width). -/
def cleanBox (rec : Rec) (p : Field) (s : Style) : M Node := do
  let q : Array Node ← match p with
    | .mathChar f c => rec #[.atom .ord (.mathChar f c) .empty .empty] s
    | .textChar f c => rec #[.atom .ord (.textChar f c) .empty .empty] s
    | .box b => pure #[b]
    | .list l => rec l s
    | .empty => pure #[.box false 0 0 0 0 {} #[]]
  let x := match q with
    | #[b@(.box _ _ _ _ 0 _ _)] => b
    | q => hpack q
  match x with
  | .box v w h d sh g #[c@(.char ..), .kern ..] => return .box v w h d sh g #[c]
  | x => return x

/-- Attaches the superscript and subscript of an atom to its list (rule 18, TeX's
`make_scripts`): `delta` is the italic correction the superscript is moved right by. -/
def makeScripts (rec : Rec) (hl : Array Node) (sup sub : Field) (style : Style)
    (delta : Int) : M (Array Node) := do
  let p := (← read).params
  let cs := style.size
  let t : MathSize := if style.isLarge then 1 else 2
  let (shiftUp, shiftDown) ← match hl[0]? with
    | some (.char ..) => pure ((0 : Int), (0 : Int))
    | _ =>
      let z := hpack hl
      pure (z.height - (← mathsy 18 t), z.depth + (← mathsy 19 t))
  let xh ← mathsy 5 cs
  let mut shiftUp := shiftUp
  let mut shiftDown := shiftDown
  let x ← if sup.isEmpty then do
      -- rule 18b: a subscript alone
      let x ← cleanBox rec sub style.sub
      let x := x.withWidth (x.width + p.scriptSpace)
      shiftDown := max shiftDown (← mathsy 16 cs)
      shiftDown := max shiftDown (x.height - (xh.natAbs * 4 : Int).tdiv 5)
      pure (x.withShift shiftDown)
    else do
      -- rule 18c: the superscript
      let x ← cleanBox rec sup style.sup
      let x := x.withWidth (x.width + p.scriptSpace)
      let clr ← if style.isCramped then mathsy 15 cs
        else if style.isDisplay then mathsy 13 cs else mathsy 14 cs
      shiftUp := max shiftUp clr
      shiftUp := max shiftUp (x.depth + (xh.natAbs : Int).tdiv 4)
      if sub.isEmpty then pure (x.withShift (-shiftUp))
      else do
        -- rules 18d–18f: both
        let y ← cleanBox rec sub style.sub
        let y := y.withWidth (y.width + p.scriptSpace)
        shiftDown := max shiftDown (← mathsy 17 cs)
        let clr := 4 * (← ruleThickness cs) - ((shiftUp - x.depth) - (y.height - shiftDown))
        if clr > 0 then
          shiftDown := shiftDown + clr
          let clr2 := (xh.natAbs * 4 : Int).tdiv 5 - (shiftUp - x.depth)
          if clr2 > 0 then
            shiftUp := shiftUp + clr2
            shiftDown := shiftDown - clr2
        let k : Node := .kern ((shiftUp - x.depth) - (y.height - shiftDown)) .font
        pure ((vpack #[x.withShift delta, k, y]).withShift shiftDown)
  return hl.push x

/-- The nucleus of an atom as a horizontal list (rule 17): a character with its italic
correction as a kern unless a subscript follows (then returned as `delta`, the superscript's
shift) or it is a text font's character inside a word; a list laid out and packed. -/
def nucleusList (rec : Rec) (nuc sub : Field) (style : Style) : M (Array Node × Int) := do
  match nuc with
  | .mathChar fam c | .textChar fam c =>
    match ← fetch fam c style.size with
    | none => return (#[], 0)
    | some (i, f, m) =>
      let text := nuc matches .textChar .. && f.param 2 != 0
      let delta := if text then 0 else m.italic
      if sub.isEmpty && delta != 0 then return (#[newChar i c m, .kern delta .italic], 0)
      return (#[newChar i c m], delta)
  | .empty => return (#[], 0)
  | .box b => return (#[b], 0)
  | .list l => return (#[hpack (← rec l style)], 0)

/-- A large operator (rule 13, TeX's `make_op`): the larger variant in display style, centred
on the axis; with limits, the scripts above and below it in a vertical box. Returns the
operator's list when it has limits (the scripts are then set), else the new nucleus and the
italic correction `delta` for its scripts. -/
def makeOp (rec : Rec) (nuc sup sub : Field) (lim : Limits) (style : Style) :
    M (Sum (Array Node) (Field × Int)) := do
  let lim := if lim == .normal && style.isDisplay then Limits.limits else lim
  let cs := style.size
  let (nuc, delta) ← match nuc with
    | .mathChar fam c | .textChar fam c => do
      match ← fetch fam c cs with
      | none => pure (nuc, (0 : Int))
      | some (_, f, m) =>
        let (c, m) := match m.tag with
          | .list nx =>
            if style.isDisplay then
              match f.char? nx with
              | some m' => (nx, m')
              | none => (c, m)
            else (c, m)
          | _ => (c, m)
        let delta := m.italic
        let x ← cleanBox rec (.mathChar fam c) style
        let x := if !sub.isEmpty && lim != .limits then x.withWidth (x.width - delta) else x
        let x := x.withShift (half (x.height - x.depth) - (← axisHeight cs))
        pure (Field.box x, delta)
    | n => pure (n, 0)
  if lim != .limits then return .inr (nuc, delta)
  -- rule 13a: limits
  let x ← cleanBox rec sup style.sup
  let y ← cleanBox rec nuc style
  let z ← cleanBox rec sub style.sub
  let w := max x.width (max y.width z.width)
  let x := rebox x w
  let y := rebox y w
  let z := rebox z w
  let x := x.withShift (half delta)
  let z := z.withShift (-(half delta))
  let mut l : Array Node := #[y]
  let mut h := y.height
  let mut d := y.depth
  let bos5 ← mathex 13 cs
  if !sup.isEmpty then
    let shiftUp := max ((← mathex 11 cs) - x.boxDepth) (← mathex 9 cs)
    l := #[.kern bos5 .font, x, .kern shiftUp .font] ++ l
    h := h + bos5 + x.boxHeight + x.boxDepth + shiftUp
  if !sub.isEmpty then
    let shiftDown := max ((← mathex 12 cs) - z.boxHeight) (← mathex 10 cs)
    l := l ++ #[.kern shiftDown .font, z, .kern bos5 .font]
    d := d + bos5 + z.boxHeight + z.boxDepth + shiftDown
  return .inl #[.box true w h d 0 {} l]

/-- A generalised fraction (rule 15, TeX's `make_fraction`), with its delimiters. -/
def makeFraction (rec : Rec) (num den : Field) (thick : Option Int) (left right : Delim)
    (style : Style) : M (Array Node) := do
  let cs := style.size
  let t ← match thick with
    | some t => pure t
    | none => ruleThickness cs
  let x ← cleanBox rec num style.num
  let z ← cleanBox rec den style.denom
  let (x, z) := if x.width < z.width then (rebox x z.width, z) else (x, rebox z x.width)
  let mut shiftUp ← if style.isDisplay then mathsy 8 cs
    else if t != 0 then mathsy 9 cs else mathsy 10 cs
  let mut shiftDown ← if style.isDisplay then mathsy 11 cs else mathsy 12 cs
  let ax ← axisHeight cs
  let l : Array Node ← if t == 0 then do
      -- rule 15c
      let rt ← ruleThickness cs
      let clr := if style.isDisplay then 7 * rt else 3 * rt
      let delta := half (clr - ((shiftUp - x.depth) - (z.height - shiftDown)))
      if delta > 0 then
        shiftUp := shiftUp + delta
        shiftDown := shiftDown + delta
      pure #[x, .kern ((shiftUp - x.depth) - (z.height - shiftDown)) .font, z]
    else do
      -- rule 15d
      let clr := if style.isDisplay then 3 * t else t
      let delta := half t
      let delta1 := clr - ((shiftUp - x.depth) - (ax + delta))
      let delta2 := clr - ((ax - delta) - (z.height - shiftDown))
      if delta1 > 0 then shiftUp := shiftUp + delta1
      if delta2 > 0 then shiftDown := shiftDown + delta2
      pure #[x, .kern ((shiftUp - x.depth) - (ax + delta)) .font, fractionRule t,
        .kern ((ax - delta) - (z.height - shiftDown)) .font, z]
  let v : Node := .box true x.width (shiftUp + x.height) (z.depth + shiftDown) 0 {} l
  -- rule 15e
  let dl ← if style.isDisplay then mathsy 20 cs else mathsy 21 cs
  let ld ← varDelimiter left cs dl (largerSizes := true)
  let rd ← varDelimiter right cs dl (largerSizes := true)
  return #[hpack #[ld, v, rd]]

/-- A radical (rule 11, TeX's `make_radical`): the nucleus cramped under a rule, the radical
sign a delimiter tall enough for it and the clearance. -/
def makeRadical (rec : Rec) (nuc : Field) (d : Delim) (style : Style) : M Node := do
  let cs := style.size
  let x ← cleanBox rec nuc style.cramped
  let t ← ruleThickness cs
  let xh ← mathsy 5 cs
  let mut clr := if style.isDisplay then t + (xh.natAbs : Int).tdiv 4
    else t + (t.natAbs : Int).tdiv 4
  let y ← varDelimiter d cs (x.height + x.depth + clr + t)
  let delta := y.boxDepth - (x.height + x.depth + clr)
  if delta > 0 then clr := clr + half delta
  let y := y.withShift (-(x.height + clr))
  return hpack #[y, overbar x clr y.boxHeight]

/-- A math accent (rule 12, TeX's `make_math_accent`): the accent over the cramped nucleus,
moved by the nucleus's skew, the largest variant not wider than the nucleus; a character
nucleus takes its scripts into the box. Returns the new nucleus and whether the scripts were
taken. -/
def makeAccent (rec : Rec) (nuc sup sub : Field) (fam code : Nat) (style : Style) :
    M (Field × Bool) := do
  let cs := style.size
  let some (fi, f, m) ← fetch fam code cs | return (nuc, false)
  let s ← match nuc with
    | .mathChar nf nc | .textChar nf nc => do
      match ← fetch nf nc cs with
      | some (_, g, _) => pure (g.skew nc)
      | none => pure 0
    | _ => pure 0
  let mut x ← cleanBox rec nuc style.cramped
  let w := x.width
  let mut h := x.height
  -- the largest variant in the accent's chain that is not wider than the nucleus
  let mut c := code
  let mut cm := m
  for _ in [0:257] do
    match cm.tag with
    | .list nx =>
      match f.char? nx with
      | some m' => if m'.width > w then break else c := nx; cm := m'
      | none => break
    | _ => break
  let xHeight := f.param 5
  let mut delta := if h < xHeight then h else xHeight
  let mut took := false
  if (!sup.isEmpty || !sub.isEmpty) && (nuc matches .mathChar ..) then
    x ← cleanBox rec (.list #[.atom .ord nuc sup sub]) style
    delta := delta + x.height - h
    h := x.height
    took := true
  -- LuaTeX places an accent over a nucleus that is not a character 1sp further right than
  -- TeX's rule gives (found against its lists)
  let extra : Int := if nuc matches .mathChar .. || nuc matches .textChar .. then 0 else 1
  let y := (charBox fi c cm).withShift (s + half (w - (cm.width + cm.italic)) + extra)
  let y := y.withWidth 0
  let y := (vpack #[y, .kern (-delta) .font, x]).withWidth x.width
  let y := if y.height < h then
      match y with
      | .box v yw yh yd ys g l => .box v yw h yd ys g (#[Node.kern (h - yh) .font] ++ l)
      | n => n
    else y
  return (.box y, took)

/-- The first pass's rule 14 on the ord atom at `i` of `l`: while its nucleus is a character
followed by an atom whose nucleus is a character of the same family, the font's ligature or
kern for the pair is applied. Returns the list and whether the atom's nucleus became a text
character. -/
def ligatureRule (l : Array Noad) (i : Nat) (style : Style) : M (Array Noad) := do
  let mut l := l
  for _ in [0:(← get).budget + 1] do
    charge
    let .atom .ord (.mathChar fam c) .empty .empty lim := l[i]?.getD default | return l
    let next := l[i + 1]?
    let some (.atom pk (.mathChar pf pc) psup psub plim) := next | return l
    if pf != fam || pk == .inner || pk == .over || pk == .under || pk == .vcenter then
      return l
    l := l.setIfInBounds i (.atom .ord (.textChar fam c) .empty .empty lim)
    let (_, f) ← famFont fam style.size
    match f.ligKern c pc with
    | .none => return l
    | .kern k => return l.insertIdxIfInBounds (i + 1) (.kern k false)
    | .lig op ch =>
      match op with
      | 1 | 5 => l := l.setIfInBounds i (.atom .ord (.textChar fam ch) .empty .empty lim)
      | 2 | 6 => l := l.setIfInBounds (i + 1) (.atom pk (.mathChar pf ch) psup psub plim)
      | 3 | 7 | 11 =>
        let r : Field := if op < 11 then .mathChar fam ch else .textChar fam ch
        l := l.insertIdxIfInBounds (i + 1) (.atom .ord r .empty .empty)
      | _ =>
        l := (l.setIfInBounds i (.atom .ord (.textChar fam ch) psup psub lim)).eraseIdxIfInBounds
          (i + 1)
      if op > 3 then return l
      match l[i]? with
      | some (.atom .ord (.textChar f' c') s1 s2 lim') =>
        l := l.setIfInBounds i (.atom .ord (.mathChar f' c') s1 s2 lim')
      | _ => pure ()
  return l

/-- TeX's `make_left_right`: the delimiter sized to cover the list's maximum height and depth
from the axis, at least `\delimiterfactor`/1000 of it and within `\delimitershortfall`. -/
def makeLeftRight (d : Delim) (style : Style) (maxH maxD : Int) : M Node := do
  let p := (← read).params
  let cs := style.size
  let ax ← axisHeight cs
  let delta2 := maxD + ax
  let delta1 := max (maxH + maxD - delta2) delta2
  let delta := max ((delta1.tdiv 500) * p.delimiterFactor) (delta1 + delta1 - p.delimiterShortfall)
  varDelimiter d cs delta (centreNull := false)

/-- The first pass: each item set in the style in force, with the list's largest height and
depth. -/
def firstPass (rec : Rec) (l : Array Noad) (style : Style) :
    M (Array Item × Int × Int) := do
  let p := (← read).params
  let mut l := l
  let mut out : Array Item := #[]
  let mut cur := style
  let mut rType : RType := .atom .op
  let mut rIdx : Option Nat := none
  let mut maxH : Int := 0
  let mut maxD : Int := 0
  let mut i := 0
  for _ in [0:(← get).budget + 1] do
    if i ≥ l.size then break
    charge
    let mu ← mathUnit cur.size
    match l[i]?.getD default with
    | .style s => cur := s; out := out.push (.style s); i := i + 1
    | .choice d t s ss =>
      let chosen := match cur.code.val / 2 with
        | 0 => d | 1 => t | 2 => s | _ => ss
      l := l.extract 0 i ++ #[Noad.style cur] ++ chosen ++ l.extract (i + 1) l.size
    | .glue g isMu cond =>
      let g' := if isMu then mathGlue g mu else g
      out := out.push (.node (.glue g' (if isMu then 99 else if cond then 98 else 0)) false)
      if cond && cur.size.val != 0 then
        match l[i + 1]? with
        | some (.glue ..) | some (.kern ..) => l := l.eraseIdxIfInBounds (i + 1)
        | _ => pure ()
      i := i + 1
    | .kern w isMu =>
      out := out.push (.node (.kern (if isMu then muMult mu w else w)
        (if isMu then .explicit else .font)) false)
      i := i + 1
    | .penalty q => out := out.push (.node (.penalty q) true); i := i + 1
    | .node n =>
      if n matches .rule .. then
        maxH := max maxH n.height
        maxD := max maxD n.depth
      out := out.push (.node n false); i := i + 1
    | .delim side d =>
      if side != 0 && rType == .atom .bin then
        if let some r := rIdx then out := out.modify r fun it => match it with
          | .atom _ hl => .atom .ord hl
          | it => it
      out := out.push (.delim side d)
      if side != 0 then cur := style
      rType := .left
      rIdx := none
      i := i + 1
    | n =>
      -- an atom of some kind: rules 5 and 6, then its own rule, then the scripts
      let (kind, nuc, sup, sub) := match n with
        | .atom k nu su sb _ => (k, nu, su, sb)
        | .radical nu su sb _ => (AtomKind.ord, nu, su, sb)
        | .accent nu su sb _ _ => (.ord, nu, su, sb)
        | _ => (.inner, Field.empty, Field.empty, Field.empty)
      let kind := if kind == .bin && (rType == .atom .bin || rType == .atom .op ||
          rType == .atom .rel || rType == .atom .open || rType == .atom .punct ||
          rType == .left) then AtomKind.ord else kind
      if (kind == .rel || kind == .close || kind == .punct) && rType == .atom .bin then
        if let some r := rIdx then out := out.modify r fun it => match it with
          | .atom _ hl => .atom .ord hl
          | it => it
      let mut nuc := nuc
      let mut sup := sup
      let mut sub := sub
      let mut delta : Int := 0
      let mut hl : Option (Array Node) := none
      match n with
      | .fraction num den t ld rd =>
        hl := some (← makeFraction rec num den t ld rd cur)
      | .radical _ _ _ d => nuc := .box (← makeRadical rec nuc d cur)
      | .accent _ _ _ fam code =>
        let (nu, took) ← makeAccent rec nuc sup sub fam code cur
        nuc := nu
        if took then sup := .empty; sub := .empty
      | .atom .op _ _ _ lim =>
        match ← makeOp rec nuc sup sub lim cur with
        | .inl h => hl := some h
        | .inr (nu, d) => nuc := nu; delta := d
      | .atom .over .. => nuc := .box (overbar (← cleanBox rec nuc cur.cramped)
          (3 * (← ruleThickness cur.size)) (← ruleThickness cur.size))
      | .atom .under .. =>
        let x ← cleanBox rec nuc cur
        let t ← ruleThickness cur.size
        let y := vpack #[x, .kern (3 * t) .font, fractionRule t]
        let dd := y.height + y.depth + t
        nuc := .box (y.withHD x.height (dd - x.height))
      | .atom .vcenter .. =>
        match nuc with
        | .box (.box true w h d s g bl) =>
          let dd := h + d
          let h' := (← axisHeight cur.size) + half dd
          nuc := .box (.box true w h' (dd - h') s g bl)
        | _ => throw "\\vcenter of something other than a vertical box"
      | .atom .ord .. =>
        l := ← ligatureRule l i cur
        match l[i]? with
        | some (.atom _ nu su sb _) => nuc := nu; sup := su; sub := sb
        | _ => pure ()
      | _ => pure ()
      let hlist ← match hl with
        | some h => pure h
        | none => do
          let (base, d) ← nucleusList rec nuc sub cur
          let delta' := if nuc matches .box _ then delta else d
          if sup.isEmpty && sub.isEmpty then pure base
          else makeScripts rec base sup sub cur delta'
      let z := hpack hlist
      maxH := max maxH z.height
      maxD := max maxD z.depth
      let sk := match n with
        | .fraction .. => AtomKind.inner
        | _ => kind
      out := out.push (.atom sk hlist)
      rType := .atom (match n with
        | .fraction .. | .radical .. | .accent .. => AtomKind.ord
        | _ => kind)
      rIdx := some (out.size - 1)
      i := i + 1
  if rType == .atom .bin then
    if let some r := rIdx then out := out.modify r fun it => match it with
      | .atom _ hl => .atom .ord hl
      | it => it
  let _ := p
  return (out, maxH, maxD)

/-- The second pass: delimiters sized, inter-atom spacing and (with `penalties`) the penalties
after binary operations and relations. -/
def secondPass (items : Array Item) (style : Style) (maxH maxD : Int) (penalties : Bool) :
    M (Array Node) := do
  let p := (← read).params
  let mut out : Array Node := #[]
  let mut cur := style
  let mut rType : Option (Fin 8) := none
  for k in [0:items.size] do
    charge
    match items[k]?.getD default with
    | .style s => cur := s
    | .node n _ => out := out.push n
    | it =>
      let (t, hl, pen) ← match it with
        | .atom kind hl =>
          let pen := match kind with
            | .bin => p.binOpPenalty
            | .rel => p.relPenalty
            | _ => 10000
          pure (kind.spacingIndex, hl, pen)
        | .delim side d =>
          let b ← makeLeftRight d style maxH maxD
          cur := style
          pure ((if side == 0 then AtomKind.open else .close).spacingIndex, #[b], (10000 : Int))
        | _ => pure (0, #[], 10000)
      let mu ← mathUnit cur.size
      if let some r := rType then
        if let some g := interAtomGlue p r t cur mu then out := out.push g
      out := out ++ hl
      if penalties && pen < 10000 then
        match items[k + 1]? with
        | some (.node _ true) | some (.atom .rel _) | none => pure ()
        | some _ => out := out.push (.penalty pen)
      rType := some (match it with
        | .delim 1 _ => AtomKind.open.spacingIndex
        | _ => t)
  return out

/-- A math list to a horizontal list in a style (Appendix G), `penalties` for a formula in a
paragraph; `fuel` bounds the nesting of lists inside lists (an error beyond it). -/
def mlistToHlist : Nat → Array Noad → Style → Bool → M (Array Node)
  | 0, _, _, _ => throw "formula nested too deeply"
  | fuel + 1, l, style, penalties => do
    let rec_ : Rec := fun l s => mlistToHlist fuel l s false
    let (items, maxH, maxD) ← firstPass rec_ l style
    secondPass items style maxH maxD penalties

/-- The deepest nesting `layout` allows. -/
def maxNesting : Nat := 400

/-- Lays out a math list in a style with the families and parameters, as TeX's `mlist_to_hlist`
(`penalties` for a formula in a paragraph): the horizontal list, the warnings, or an error. -/
def layoutList (env : Env) (l : Array Noad) (style : Style) (penalties : Bool := false)
    (budget : Nat := Budget.default) : Except String (Array Node × Array String) :=
  match (mlistToHlist maxNesting l style penalties).run env |>.run { budget } with
  | .ok (r, st) => .ok (r, st.warnings)
  | .error e => .error e

end LeAnTeX.TeXMath
