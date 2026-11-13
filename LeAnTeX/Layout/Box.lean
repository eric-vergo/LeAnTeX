/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Layout.Options

/-!
# The box tree

The result of laying out a formula: KaTeX's HTML box tree (`domTree.ts`), node for node, with
every vertical dimension KaTeX computes. It is what KaTeX's `buildHTML` returns, so a back end
that writes KaTeX's markup prints it directly, and the display list (`LeAnTeX.Layout.Display`)
is computed from it.

## Main definitions

* `CssValue`, `Css`: a CSS property's value and an ordered set of properties (KaTeX's
  `CssStyle`; the order is the order KaTeX sets them in, which its markup keeps).
* `SvgChild`: a `path` or a `line` of an inline SVG image.
* `BoxKind`: span, anchor, symbol, document fragment, SVG image, image.
* `Box`: a node with its classes, height, depth, maxFontSize, style, attributes and children.

## Invariants

The layout keeps KaTeX's conventions:

* `height` and `depth` are in em of the node's own font size; a span that changes the font size
  (`katex-sizing reset-sizeA sizeB`) has its own `height` and `depth` scaled to the parent's
  size, so a parent's extent is the maximum of its children's.
* `maxFontSize` is the largest size multiplier inside the node; `makeVList` uses it for the
  height of its struts.
* Lengths in `style` are em of the node's font size; they are rounded to 1e-4 em only when
  printed (`Em.css`).

`loc` (the source range of the parse node a box was built for) and a symbol's `font` (the
metric font KaTeX measured it in) are LeAnTeX's additions; KaTeX's tree has neither.
`middle` is KaTeX's own marker on a `\middle` delimiter, which the markup does not show.

## References

* KaTeX's `src/domTree.ts` and `src/tree.ts` (MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- A CSS property value: a length (printed as KaTeX's `makeEm` does) or a string. -/
inductive CssValue where
  /-- A length in em. -/
  | em (x : Em)
  /-- Any other value (`relative`, a colour, `0.04em solid`, …). -/
  | str (s : String)
  deriving BEq, Inhabited, Repr

/-- The text of a value as it appears in KaTeX's markup. -/
def CssValue.text : CssValue → String
  | .em x => x.css
  | .str s => s

/-- A decimal number (`-0.5`, `.25`, `3`) as a length in em, rounded to the nearest unit. -/
def parseDecimal (s : String) : Option Em := Id.run do
  let (neg, body) := if s.startsWith "-" then (true, (s.drop 1).toString) else (false, s)
  let parts := body.splitOn "."
  let (ip, fp) := match parts with
    | [a] => (a, "")
    | [a, b] => (a, b)
    | _ => ("x", "")
  if (ip.isEmpty && fp.isEmpty) || !(ip ++ fp).all Char.isDigit then return none
  let digits := (ip ++ fp).foldl (fun n c => n * 10 + (c.toNat - '0'.toNat)) 0
  let x := Em.ofRatio digits (10 ^ fp.length)
  return some (if neg then -x else x)

/-- A CSS value from its text: a length when it is a number followed by `em`. -/
def CssValue.ofText (s : String) : CssValue :=
  if s.endsWith "em" then
    let num := (s.dropEnd 2).toString
    match parseDecimal num with
    | some x => .em x
    | none => .str s
  else .str s

/-- A node's style: CSS properties under KaTeX's camel-case names, in the order set. -/
structure Css where
  /-- The properties. -/
  props : Array (String × CssValue) := #[]
  deriving BEq, Inhabited, Repr

namespace Css

/-- The value of a property. -/
def get? (c : Css) (key : String) : Option CssValue :=
  (c.props.find? (·.1 == key)).map (·.2)

/-- Set a property: a property already set keeps its place (a JavaScript object's key
order). -/
def set (c : Css) (key : String) (v : CssValue) : Css :=
  match c.props.findIdx? (·.1 == key) with
  | some i => ⟨c.props.set! i (key, v)⟩
  | none => ⟨c.props.push (key, v)⟩

/-- Set a length. -/
def setEm (c : Css) (key : String) (x : Em) : Css := c.set key (.em x)

/-- Whether two styles set the same properties to the same values, in any order. -/
def sameAs (a b : Css) : Bool :=
  a.props.all (fun (k, v) => b.get? k == some v) && b.props.all (fun (k, v) => a.get? k == some v)

/-- Whether no property is set. -/
def isEmpty (c : Css) : Bool := c.props.isEmpty

end Css

/-- A child of an inline SVG image. -/
inductive SvgChild where
  /-- A path of KaTeX's path table by name, or with explicit data (`alternate`). -/
  | path (name : String) (alternate : Option String)
  /-- A line, with its attributes. -/
  | line (attrs : Array (String × String))
  deriving BEq, Inhabited, Repr

/-- The kind of a box node. -/
inductive BoxKind where
  /-- A `span`. -/
  | span
  /-- A link (`a`). -/
  | anchor
  /-- A run of text in one font: KaTeX's `SymbolNode`. `font` is the metric font. -/
  | symbol (text : String) (font : String)
  /-- A document fragment: its children stand in its place. -/
  | fragment
  /-- An inline SVG image (its attributes are the node's `attrs`). -/
  | svg (children : Array SvgChild)
  /-- An image. -/
  | img (src : String) (alt : String)
  deriving BEq, Inhabited, Repr

/-- A node of the box tree. -/
structure Box where
  /-- What the node is. -/
  kind : BoxKind := .span
  /-- Its classes, in KaTeX's order. Empty strings may occur, as in KaTeX; markup and comparisons
  drop them. -/
  classes : Array String := #[]
  /-- Height above the baseline, in em of the node's font size. -/
  height : Em := 0
  /-- Depth below the baseline. -/
  depth : Em := 0
  /-- The largest size multiplier inside. -/
  maxFontSize : Em := 0
  /-- The CSS style. -/
  style : Css := {}
  /-- HTML attributes. -/
  attrs : Array (String × String) := #[]
  /-- Children. -/
  children : Array Box := #[]
  /-- The italic correction: always set on symbols, on some spans. -/
  italic : Option Em := none
  /-- The skew of a symbol (for accents). -/
  skew : Em := 0
  /-- The advance width: always set on symbols, on some spans. -/
  width : Option Em := none
  /-- The source range of the parse node the box was built for. -/
  loc : OLoc := .absent
  /-- For a `\middle` delimiter, the delimiter and the options it was built in: the enclosing
  `\left … \right` rebuilds it at the height of its contents (KaTeX's `isMiddle`). -/
  middle : Option (String × Options) := none
  deriving Inhabited

namespace Box

/-- Whether the node has a class. -/
def hasClass (b : Box) (c : String) : Bool := b.classes.contains c

/-- Add a class at the end. -/
def addClass (b : Box) (c : String) : Box := { b with classes := b.classes.push c }

/-- Set a style property to a length. -/
def setStyle (b : Box) (key : String) (x : Em) : Box := { b with style := b.style.setEm key x }

/-- Set a style property to a string. -/
def setStyleStr (b : Box) (key s : String) : Box := { b with style := b.style.set key (.str s) }

/-- Whether the node is a symbol. -/
def isSymbol (b : Box) : Bool := match b.kind with
  | .symbol .. => true
  | _ => false

/-- Whether the node is a document fragment. -/
def isFragment (b : Box) : Bool := b.kind == .fragment

/-- The italic correction (zero when unset). -/
def italicOr0 (b : Box) : Em := b.italic.getD 0

/-- The symbol's text (empty for other nodes). -/
def text (b : Box) : String := match b.kind with
  | .symbol t _ => t
  | _ => ""

end Box

end LeAnTeX
