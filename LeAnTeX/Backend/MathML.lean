/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Backend.Escape
import LeAnTeX.Backend.Fonts
import LeAnTeX.Parse.Parser
import LeAnTeX.Parse.Tables

/-!
# MathML

A formula's parse tree written as MathML (Core), for screen readers and other software that
reads mathematics: a page that shows the formula as a picture (`LeAnTeX.Backend.Svg`) can carry
this beside it. The MathML says what the formula is, not how it is drawn: identifiers, numbers
and operators (`mi`, `mn`, `mo`) with their characters from KaTeX's symbol table, fractions,
roots, scripts, limits, fences, accents, over- and underbraces, matrices and arrays, text, and
font changes as Unicode's mathematical alphanumeric characters. Spacing, colours, sizes, boxes
and other presentational commands keep only their content; a phantom stays a phantom. The
source is kept as an `application/x-tex` annotation.

Every text is escaped (`escape`), and nesting deeper than `maxDepth` is left out, so hostile
source gives well-formed markup of bounded size.

## Main definitions

* `mathMLOfTree`: a parse tree as a `<math>` element.
* `mathML`: a formula's source parsed and written, or the parse error.
-/

namespace LeAnTeX.Backend

/-- The deepest nesting of the tree written; deeper material is left out. -/
def maxDepth : Nat := 200

/-- The character KaTeX draws for a symbol's name in math mode (the name itself when the
table has no character for it, without its backslash). -/
def symbolChar (name : String) : String :=
  match (Tables.mathSymbols.get? name).bind (·.replace) with
  | some r => r
  | none => if name.startsWith "\\" then (name.drop 1).toString else name

/-- An element with its attributes (already escaped) and content. -/
private def el (tag : String) (attrs : String) (body : String) : String :=
  s!"<{tag}{attrs}>{body}</{tag}>"

/-- The character of an accent command, for `mover`. -/
def accentChar : String → String
  | "\\hat" | "\\widehat" | "\\widecheck" => "^"
  | "\\check" => "ˇ"
  | "\\tilde" | "\\widetilde" | "\\utilde" => "~"
  | "\\bar" | "\\overline" => "¯"
  | "\\vec" | "\\overrightarrow" | "\\xrightarrow" => "→"
  | "\\overleftarrow" | "\\underleftarrow" | "\\xleftarrow" => "←"
  | "\\overleftrightarrow" | "\\underleftrightarrow" => "↔"
  | "\\dot" => "˙"
  | "\\ddot" => "¨"
  | "\\dddot" => "⃛"
  | "\\acute" => "´"
  | "\\grave" => "`"
  | "\\breve" => "˘"
  | "\\mathring" => "˚"
  | "\\overbrace" => "⏞"
  | "\\underbrace" => "⏟"
  | "\\overbracket" => "⎴"
  | "\\underbracket" => "⎵"
  | "\\underline" | "\\underbar" => "_"
  | l => symbolChar l

/-- The KaTeX face a font command sets letters in, for `mathAlphanumeric`. -/
def fontFace (font : String) : String :=
  match if font.startsWith "\\" then (font.drop 1).toString else font with
  | "mathbf" | "boldsymbol" | "bm" | "bold" => "Main-Bold"
  | "mathbb" | "Bbb" => "AMS-Regular"
  | "mathcal" => "Caligraphic-Regular"
  | "mathscr" => "Script-Regular"
  | "mathfrak" | "frak" => "Fraktur-Regular"
  | "mathsf" | "sf" => "SansSerif-Regular"
  | "mathtt" | "tt" => "Typewriter-Regular"
  | "mathit" | "it" => "Math-Italic"
  | _ => "Main-Regular"

/-- A text in the mathematical alphanumeric characters of the face (unchanged where Unicode
has none). -/
def styled (face : String) (s : String) : String :=
  if face == "Main-Regular" || face == "Math-Italic" then s
  else String.ofList (s.toList.map fun c => (mathAlphanumeric face c).getD c)

/-- Whether a character (one the symbol table does not class, such as the MathML branch of
`\\ne`) is an operator: a relation sign, an arrow or one of Unicode's mathematical
operators. -/
def isOperatorChar (ch : String) : Bool :=
  match ch.toList with
  | [c] => "=<>+-*/|:".contains c || (0x2190 ≤ c.toNat && c.toNat ≤ 0x22FF) ||
      (0x27F0 ≤ c.toNat && c.toNat ≤ 0x27FF) || (0x2A00 ≤ c.toNat && c.toNat ≤ 0x2AFF)
  | _ => false

/-- A symbol as a token element: a digit string as `mn`, an atom of an operator class as `mo`,
anything else as `mi` (a single letter in the face's characters when a font is set). -/
def symbolToken (face : Option String) (group : Group) (text : String) : String :=
  let ch := symbolChar text
  if ch.isEmpty then ""
  else if ch.all Char.isDigit || ch == "." && group == .textord then el "mn" "" (escape ch)
  else if group.isAtom || isOperatorChar ch then el "mo" "" (escape ch)
  else
    let ch := match face with | some f => styled f ch | none => ch
    let attr := match face with
      | some f => if f == "Main-Regular" && ch.length == 1 then " mathvariant=\"normal\"" else ""
      | none => ""
    el "mi" attr (escape ch)

/-- A delimiter of `\left`, `\right` or `\big` as an `mo` (nothing for `.`). -/
def fence (d : String) (attrs : String := " fence=\"true\"") : String :=
  if d == "." || d.isEmpty then "" else el "mo" attrs (escape (symbolChar d))

/-- The plain text of nodes (for `\text` and `\operatorname`). -/
def plainText : Nat → Array Node → String
  | 0, _ => ""
  | fuel + 1, ns => String.join <| ns.toList.map fun
    | .sym _ _ g t => if g == .spacing then " " else symbolChar t
    | .ordgroup _ _ b _ | .text _ _ b _ | .styling _ _ _ _ b | .sizing _ _ _ b
    | .color _ _ _ b | .mclass _ _ _ b _ => plainText fuel b
    | .font _ _ _ b => plainText fuel #[b]
    | _ => ""

/-- The MathML of nodes in a row, with the font a font command set (`none`: the default). -/
def rowOf (face : Option String) : Nat → Array Node → String
  | 0, _ => ""
  | fuel + 1, ns => String.join (ns.toList.map (nodeOf face fuel))
where
  /-- One node. -/
  nodeOf (face : Option String) : Nat → Node → String
    | 0, _ => ""
    | fuel + 1, n =>
      let row := rowOf face fuel
      let one := fun (x : Node) => match x with
        | .ordgroup _ _ b _ => el "mrow" "" (row b)
        | x => el "mrow" "" (row #[x])
      match n with
      | .sym _ _ g t => if g == .spacing then "" else symbolToken face g t
      | .ordgroup _ _ b _ | .styling _ _ _ _ b | .sizing _ _ _ b | .color _ _ _ b
      | .mclass _ _ _ b _ | .html _ _ _ b | .hbox _ _ b | .pmb _ _ _ b =>
        el "mrow" "" (row b)
      | .href _ _ _ b => el "mrow" "" (row b)
      | .htmlmathml _ _ _ m => el "mrow" "" (row m)
      | .tag _ _ b t => el "mrow" "" (row b ++ el "mtext" "" (escape ("(" ++ plainText 50 t ++
          ")")))
      | .text _ _ b _ => el "mtext" "" (escape (plainText 50 b))
      | .verb _ _ b _ => el "mtext" "" (escape b)
      | .operatorname _ _ b _ _ _ => el "mi" "" (escape (plainText 50 b))
      | .font _ _ f b => el "mrow" "" (rowOf (some (fontFace f)) fuel #[b])
      | .supsub _ _ base sup sub =>
        let limits := match base with
          | some (.op _ _ l ..) => l
          | some (.operatorname _ _ _ _ l _) => l
          | _ => false
        let b := match base with | some x => one x | none => el "mrow" "" ""
        match sup, sub with
        | some p, some q =>
          if limits then el "munderover" "" (b ++ one q ++ one p)
          else el "msubsup" "" (b ++ one q ++ one p)
        | some p, none => if limits then el "mover" "" (b ++ one p) else el "msup" "" (b ++ one p)
        | none, some q => if limits then el "munder" "" (b ++ one q) else el "msub" "" (b ++ one q)
        | none, none => b
      | .genfrac _ _ _ num den bar l r _ =>
        let frac := el "mfrac" (if bar then "" else " linethickness=\"0\"") (one num ++ one den)
        match l, r with
        | none, none => frac
        | _, _ => el "mrow" "" (fence (l.getD ".") ++ frac ++ fence (r.getD "."))
      | .sqrt _ _ b none => el "msqrt" "" (row #[b])
      | .sqrt _ _ b (some i) => el "mroot" "" (one b ++ one i)
      | .leftright _ _ b l r _ => el "mrow" "" (fence l ++ row b ++ fence r)
      | .middle _ _ d => fence d
      | .delimsizing _ _ _ _ d => fence d " stretchy=\"false\""
      | .op _ _ _ _ _ _ sym name body =>
        match name, body with
        | some nm, _ =>
          if sym then el "mo" " largeop=\"true\"" (escape (symbolChar nm))
          else el "mi" "" (escape (if nm.startsWith "\\" then (nm.drop 1).toString else nm))
        | none, some b => el "mrow" "" (row b)
        | none, none => ""
      | .accent _ _ l _ _ b =>
        el "mover" " accent=\"true\"" (one b ++ el "mo" "" (escape (accentChar l)))
      | .accentUnder _ _ l b =>
        el "munder" " accentunder=\"true\"" (one b ++ el "mo" "" (escape (accentChar l)))
      | .horizBrace _ _ l over b =>
        el (if over then "mover" else "munder") "" (one b ++ el "mo" "" (escape (accentChar l)))
      | .overline _ _ b => el "mover" " accent=\"true\"" (one b ++ el "mo" "" "¯")
      | .underline _ _ b => el "munder" " accentunder=\"true\"" (one b ++ el "mo" "" "_")
      | .xArrow _ _ l b below =>
        let arrow := el "mo" " stretchy=\"true\"" (escape (accentChar l))
        let over := match b with | some x => one x | none => el "mrow" "" ""
        match below.join with
        | some u => el "munderover" "" (arrow ++ one u ++ over)
        | none => el "mover" "" (arrow ++ over)
      | .array _ _ _ _ _ _ _ body _ _ _ _ =>
        el "mtable" "" <| String.join <| body.toList.map fun r =>
          el "mtr" "" (String.join (r.toList.map fun c => el "mtd" "" (one c)))
      | .phantom _ _ b => el "mphantom" "" (row b)
      | .vphantom _ _ b => el "mphantom" "" (row #[b])
      | .enclose _ _ l _ _ b =>
        let kind := match l with
          | "\\cancel" => "updiagonalstrike"
          | "\\bcancel" => "downdiagonalstrike"
          | "\\xcancel" => "updiagonalstrike downdiagonalstrike"
          | "\\sout" => "horizontalstrike"
          | _ => "box"
        el "menclose" s!" notation=\"{kind}\"" (row #[b])
      | .smash _ _ b _ _ | .vcenter _ _ b | .raisebox _ _ _ b | .lap _ _ _ b
      | .reflectbox _ _ b | .cdlabel _ _ _ b | .cdlabelparent _ _ b => one b
      | .mathchoice _ _ d _ _ _ => el "mrow" "" (row d)
      | _ => ""

/-- A parse tree as a `<math>` element (in display mode `display="block"`), the source kept as
its TeX annotation. -/
def mathMLOfTree (tree : Array Node) (display : Bool) (source : String) : String :=
  let body := rowOf none maxDepth tree
  s!"<math xmlns=\"http://www.w3.org/1998/Math/MathML\"\
    {if display then " display=\"block\"" else ""}><semantics><mrow>{body}</mrow>\
    <annotation encoding=\"application/x-tex\">{escape source}</annotation></semantics></math>"

/-- A formula's source parsed with `settings` and written as MathML (see the module
docstring), or the parser's error message. -/
def mathML (source : String) (settings : Settings := {}) : Except String String :=
  match (parse source settings).result with
  | .ok tree => .ok (mathMLOfTree tree settings.displayMode source)
  | .error e => .error e.message

end LeAnTeX.Backend
