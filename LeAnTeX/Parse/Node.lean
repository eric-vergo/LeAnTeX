/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Parse.Base

/-!
# Parse nodes

The parse tree: one constructor per KaTeX parse node type, with KaTeX's field names, so that a
tree prints to the same JSON as KaTeX's `__parse` (`LeAnTeX.Parse.NodeJson`).

## Main definitions

* `Measurement`: a number with a TeX unit.
* `AlignSpec`: a column of an array (alignment and gaps, or a separator rule).
* `Node`: a parse node.

## Implementation notes

Every constructor starts with the node's mode and location. An `Option` field is `none` where
KaTeX leaves the field out or sets it to `null`; which of the two is a property of the field,
and the JSON printer knows it. Symbols of all six atom classes and five ordinary kinds share
the constructor `sym`, whose `Group` gives KaTeX's type (`atom` with a family, or the kind).

## References

* KaTeX's `src/types/nodes.ts` and `src/environments/array.ts` (MIT licence, see
  `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- A dimension: a number and a TeX unit (`pt`, `em`, `mu`, …). -/
structure Measurement where
  /-- The number. -/
  number : Float
  /-- The unit, two letters. -/
  unit : String
  deriving Inhabited, Repr

/-- A column specification of an array. -/
inductive AlignSpec where
  /-- A vertical rule between columns: `|` or `:` (dashed). -/
  | separator (separator : String)
  /-- A column: `l`, `c` or `r`, with the gaps before and after it in em, when set. -/
  | align (align : String) (pregap : Option Float) (postgap : Option Float)
  deriving Inhabited, Repr

/-- A KaTeX parse node. Field names and meanings are KaTeX's. -/
inductive Node where
  /-- An array or matrix: rows of cells, row gaps, horizontal lines and equation tags (a tag is
  `inl b` for "numbered or not", `inr nodes` for an explicit `\tag`). -/
  | array (mode : Mode) (loc : OLoc) (colSeparationType : Option String)
      (hskipBeforeAndAfter : Option Bool) (addJot : Option Bool) (cols : Option (Array AlignSpec))
      (arraystretch : Float) (body : Array (Array Node)) (rowGaps : Array (Option Measurement))
      (hLinesBeforeRow : Array (Array Bool)) (tags : Option (Array (Sum Bool (Array Node))))
      (leqno : Option Bool)
  /-- A label beside a vertical arrow in a commutative diagram. -/
  | cdlabel (mode : Mode) (loc : OLoc) (side : String) (label : Node)
  /-- The group of a vertical arrow and its labels in a commutative diagram. -/
  | cdlabelparent (mode : Mode) (loc : OLoc) (fragment : Node)
  /-- Coloured material. -/
  | color (mode : Mode) (loc : OLoc) (color : String) (body : Array Node)
  /-- A parsed colour argument. -/
  | colorToken (mode : Mode) (loc : OLoc) (color : String)
  /-- A large operator: a symbol (`\sum`), a name (`\sin`) or a body (`\mathop{…}`). -/
  | op (mode : Mode) (loc : OLoc) (limits : Bool) (alwaysHandleSupSub : Option Bool)
      (suppressBaseShift : Option Bool) (parentIsSupSub : Bool) (symbol : Bool)
      (name : Option String) (body : Option (Array Node))
  /-- A group of nodes (`{…}`, an argument); `semisimple` for `\begingroup … \endgroup`. -/
  | ordgroup (mode : Mode) (loc : OLoc) (body : Array Node) (semisimple : Option Bool)
  /-- A raw string argument. -/
  | raw (mode : Mode) (loc : OLoc) (string : String)
  /-- A parsed size argument; `isBlank` when it was empty. -/
  | size (mode : Mode) (loc : OLoc) (value : Measurement) (isBlank : Bool)
  /-- A style change (`\displaystyle` …); `resetFont` resets the math font. -/
  | styling (mode : Mode) (loc : OLoc) (style : String) (resetFont : Option Bool)
      (body : Array Node)
  /-- A nucleus with a superscript, a subscript or both; the nucleus may be missing. -/
  | supsub (mode : Mode) (loc : OLoc) (base : Option Node) (sup : Option Node)
      (sub : Option Node)
  /-- A formula with an equation tag. -/
  | tag (mode : Mode) (loc : OLoc) (body : Array Node) (tag : Array Node)
  /-- Text (`\text{…}` and friends), with the command that set its font. -/
  | text (mode : Mode) (loc : OLoc) (body : Array Node) (font : Option String)
  /-- A parsed URL argument. -/
  | url (mode : Mode) (loc : OLoc) (url : String)
  /-- `\verb` text. -/
  | verb (mode : Mode) (loc : OLoc) (body : String) (star : Bool)
  /-- A symbol: an atom of the given class or an ordinary symbol of the given kind. -/
  | sym (mode : Mode) (loc : OLoc) (group : Group) (text : String)
  /-- An accent over a base. -/
  | accent (mode : Mode) (loc : OLoc) (label : String) (isStretchy : Option Bool)
      (isShifty : Option Bool) (base : Node)
  /-- An accent under a base. -/
  | accentUnder (mode : Mode) (loc : OLoc) (label : String) (base : Node)
  /-- A line break (`\\`, `\newline`), with an optional extra gap. -/
  | cr (mode : Mode) (loc : OLoc) (newLine : Bool) (size : Option Measurement)
  /-- A sized delimiter (`\big(` …). -/
  | delimsizing (mode : Mode) (loc : OLoc) (size : Nat) (mclass : String) (delim : String)
  /-- An enclosure (`\boxed`, `\cancel`, `\colorbox`, …). -/
  | enclose (mode : Mode) (loc : OLoc) (label : String) (backgroundColor : Option String)
      (borderColor : Option String) (body : Node)
  /-- An `\end{…}` (or a `\begin{…}` before its handler replaces it). -/
  | environment (mode : Mode) (loc : OLoc) (name : String) (nameGroup : Node)
  /-- A font change (`\mathbf{…}` …). -/
  | font (mode : Mode) (loc : OLoc) (font : String) (body : Node)
  /-- A generalised fraction (`\frac`, `\binom`, `\genfrac`, …). -/
  | genfrac (mode : Mode) (loc : OLoc) (continued : Bool) (numer : Node) (denom : Node)
      (hasBarLine : Bool) (leftDelim : Option String) (rightDelim : Option String)
      (barSize : Option Measurement)
  /-- `\hbox{…}`. -/
  | hbox (mode : Mode) (loc : OLoc) (body : Array Node)
  /-- A horizontal brace or bracket over or under a base. -/
  | horizBrace (mode : Mode) (loc : OLoc) (label : String) (isOver : Bool) (base : Node)
  /-- A link. -/
  | href (mode : Mode) (loc : OLoc) (href : String) (body : Array Node)
  /-- Material with HTML attributes (`\htmlClass` …). -/
  | html (mode : Mode) (loc : OLoc) (attributes : Array (String × String)) (body : Array Node)
  /-- Different material for HTML and MathML output. -/
  | htmlmathml (mode : Mode) (loc : OLoc) (html : Array Node) (mathml : Array Node)
  /-- An image. -/
  | includegraphics (mode : Mode) (loc : OLoc) (alt : String) (width : Measurement)
      (height : Measurement) (totalheight : Measurement) (src : String)
  /-- An infix operator (`\over` …) before it is replaced by its fraction. -/
  | «infix» (mode : Mode) (loc : OLoc) (replaceWith : String) (size : Option Measurement)
      (token : Option Token)
  /-- A node that does not appear in the tree (`\relax`, a definition). -/
  | internal (mode : Mode) (loc : OLoc)
  /-- A kern or skip. -/
  | kern (mode : Mode) (loc : OLoc) (dimension : Measurement)
  /-- An overlapping box (`\mathllap` …). -/
  | lap (mode : Mode) (loc : OLoc) (alignment : String) (body : Node)
  /-- `\left … \right`. -/
  | leftright (mode : Mode) (loc : OLoc) (body : Array Node) (left : String) (right : String)
      (rightColor : Option String)
  /-- The `\right` of a `\left … \right` before it is merged. -/
  | leftrightRight (mode : Mode) (loc : OLoc) (delim : String) (color : Option String)
  /-- `\mathchoice`. -/
  | mathchoice (mode : Mode) (loc : OLoc) (display : Array Node) (text : Array Node)
      (script : Array Node) (scriptscript : Array Node)
  /-- `\middle`. -/
  | middle (mode : Mode) (loc : OLoc) (delim : String)
  /-- Material of a given atom class (`\mathrel{…}` …). -/
  | mclass (mode : Mode) (loc : OLoc) (mclass : String) (body : Array Node)
      (isCharacterBox : Bool)
  /-- `\operatorname{…}`. -/
  | operatorname (mode : Mode) (loc : OLoc) (body : Array Node) (alwaysHandleSupSub : Bool)
      (limits : Bool) (parentIsSupSub : Bool)
  /-- `\overline{…}`. -/
  | overline (mode : Mode) (loc : OLoc) (body : Node)
  /-- `\underline{…}`. -/
  | underline (mode : Mode) (loc : OLoc) (body : Node)
  /-- `\phantom{…}`. -/
  | phantom (mode : Mode) (loc : OLoc) (body : Array Node)
  /-- `\vphantom{…}`. -/
  | vphantom (mode : Mode) (loc : OLoc) (body : Node)
  /-- Poor man's bold (`\pmb`). -/
  | pmb (mode : Mode) (loc : OLoc) (mclass : String) (body : Array Node)
  /-- `\raisebox`. -/
  | raisebox (mode : Mode) (loc : OLoc) (dy : Measurement) (body : Node)
  /-- `\rule`. -/
  | rule (mode : Mode) (loc : OLoc) (shift : Option Measurement) (width : Measurement)
      (height : Measurement)
  /-- A size change (`\large` …), size 1 to 11. -/
  | sizing (mode : Mode) (loc : OLoc) (size : Nat) (body : Array Node)
  /-- `\smash`. -/
  | smash (mode : Mode) (loc : OLoc) (body : Node) (smashHeight : Bool) (smashDepth : Bool)
  /-- A square root with an optional index. -/
  | sqrt (mode : Mode) (loc : OLoc) (body : Node) (index : Option Node)
  /-- `\vcenter`. -/
  | vcenter (mode : Mode) (loc : OLoc) (body : Node)
  /-- An extensible arrow (`\xrightarrow` …). The body and the label below are missing (not
  `null`) for the `{CD}` environment's `@=`, which calls the handler without arguments. -/
  | xArrow (mode : Mode) (loc : OLoc) (label : String) (body : Option Node)
      (below : Option (Option Node))
  /-- `\reflectbox`. -/
  | reflectbox (mode : Mode) (loc : OLoc) (body : Node)
  deriving Inhabited

namespace Node

/-- KaTeX's type name of the node (`"genfrac"`, `"atom"`, `"leftright-right"`, …). -/
def type : Node → String
  | array .. => "array" | cdlabel .. => "cdlabel" | cdlabelparent .. => "cdlabelparent"
  | color .. => "color" | colorToken .. => "color-token" | op .. => "op"
  | ordgroup .. => "ordgroup" | raw .. => "raw" | size .. => "size" | styling .. => "styling"
  | supsub .. => "supsub" | tag .. => "tag" | text .. => "text" | url .. => "url"
  | verb .. => "verb"
  | sym _ _ g _ => if g.isAtom then "atom" else g.name
  | accent .. => "accent" | accentUnder .. => "accentUnder" | cr .. => "cr"
  | delimsizing .. => "delimsizing" | enclose .. => "enclose" | environment .. => "environment"
  | font .. => "font" | genfrac .. => "genfrac" | hbox .. => "hbox"
  | horizBrace .. => "horizBrace" | href .. => "href" | html .. => "html"
  | htmlmathml .. => "htmlmathml" | includegraphics .. => "includegraphics"
  | «infix» .. => "infix" | internal .. => "internal" | kern .. => "kern" | lap .. => "lap"
  | leftright .. => "leftright" | leftrightRight .. => "leftright-right"
  | mathchoice .. => "mathchoice" | middle .. => "middle" | mclass .. => "mclass"
  | operatorname .. => "operatorname" | overline .. => "overline" | underline .. => "underline"
  | phantom .. => "phantom" | vphantom .. => "vphantom" | pmb .. => "pmb"
  | raisebox .. => "raisebox" | rule .. => "rule" | sizing .. => "sizing" | smash .. => "smash"
  | sqrt .. => "sqrt" | vcenter .. => "vcenter" | xArrow .. => "xArrow"
  | reflectbox .. => "reflectbox"

/-- The node's mode. -/
def mode : Node → Mode
  | array m .. | cdlabel m .. | cdlabelparent m .. | color m .. | colorToken m ..
  | op m .. | ordgroup m .. | raw m .. | size m .. | styling m .. | supsub m .. | tag m ..
  | text m .. | url m .. | verb m .. | sym m .. | accent m .. | accentUnder m .. | cr m ..
  | delimsizing m .. | enclose m .. | environment m .. | font m .. | genfrac m .. | hbox m ..
  | horizBrace m .. | href m .. | html m .. | htmlmathml m .. | includegraphics m ..
  | «infix» m .. | internal m .. | kern m .. | lap m .. | leftright m .. | leftrightRight m ..
  | mathchoice m .. | middle m .. | mclass m .. | operatorname m .. | overline m ..
  | underline m .. | phantom m .. | vphantom m .. | pmb m .. | raisebox m .. | rule m ..
  | sizing m .. | smash m .. | sqrt m .. | vcenter m .. | xArrow m .. | reflectbox m .. => m

/-- The node's location. -/
def loc : Node → OLoc
  | array _ l .. | cdlabel _ l .. | cdlabelparent _ l .. | color _ l .. | colorToken _ l ..
  | op _ l .. | ordgroup _ l .. | raw _ l .. | size _ l .. | styling _ l .. | supsub _ l ..
  | tag _ l .. | text _ l .. | url _ l .. | verb _ l .. | sym _ l .. | accent _ l ..
  | accentUnder _ l .. | cr _ l .. | delimsizing _ l .. | enclose _ l .. | environment _ l ..
  | font _ l .. | genfrac _ l .. | hbox _ l .. | horizBrace _ l .. | href _ l .. | html _ l ..
  | htmlmathml _ l .. | includegraphics _ l .. | «infix» _ l .. | internal _ l .. | kern _ l ..
  | lap _ l .. | leftright _ l .. | leftrightRight _ l .. | mathchoice _ l .. | middle _ l ..
  | mclass _ l .. | operatorname _ l .. | overline _ l .. | underline _ l .. | phantom _ l ..
  | vphantom _ l .. | pmb _ l .. | raisebox _ l .. | rule _ l .. | sizing _ l .. | smash _ l ..
  | sqrt _ l .. | vcenter _ l .. | xArrow _ l .. | reflectbox _ l .. => l

/-- The symbol text of a symbol node, KaTeX's `checkSymbolNodeType`. -/
def symText? : Node → Option String
  | sym _ _ _ t => some t
  | _ => none

/-- An empty `ordgroup` in `mode`. -/
def emptyGroup (mode : Mode) : Node := ordgroup mode .absent #[] none

/-- The body of an argument as a list: the group's nodes, or the node itself
(KaTeX's `ordargument`). -/
def ordargument : Node → Array Node
  | ordgroup _ _ body _ => body
  | n => #[n]

/-- A group of one node stands for that node (KaTeX's `normalizeArgument`). -/
def normalizeArgument : Node → Node
  | n@(ordgroup _ _ body _) => if h : body.size = 1 then body[0] else n
  | n => n

end Node

end LeAnTeX
