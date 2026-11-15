/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Layout.Display

/-!
# Horizontal lists

The material of a paragraph as TeX's line breaker receives it: glyphs, kerns, glue, penalties,
discretionaries, boxes and rules. Every length is an integer number of TeX's scaled points
(sp, 2⁻¹⁶ pt), so that the line breaker computes exactly what TeX computes.

## Main definitions

* `Glue`: a natural width with a stretch and a shrink, each of an order (finite, `fil`, `fill`,
  `filll`).
* `KernKind`, `DiscKind`: the subtypes of kerns and discretionaries that the line breaker tells
  apart (they are LuaTeX's subtypes).
* `HNode`: a node of a horizontal list.
* `HNode.width`, `listWidth`: widths, a discretionary counted by its unbroken text.
* `HNode.discardable`: the nodes TeX drops at the start of a line.

## Implementation notes

A discretionary's three texts may hold only glyphs, kerns, boxes and rules, as in TeX; the line
breaker rejects any other node there. `listWidth` therefore counts a discretionary nested in
another as empty. A box's content is kept for drawing; its dimensions are stored with it.
-/

namespace LeAnTeX.Text

/-- Glue: a natural width, a stretch and a shrink (sp), each of an order: 0 finite, 1 `fil`,
2 `fill`, 3 `filll`. -/
structure Glue where
  /-- The natural width. -/
  width : Int := 0
  /-- The stretch. -/
  stretch : Int := 0
  /-- The order of the stretch. -/
  stretchOrder : Nat := 0
  /-- The shrink. -/
  shrink : Int := 0
  /-- The order of the shrink. -/
  shrinkOrder : Nat := 0
  deriving BEq, DecidableEq, Inhabited, Repr

/-- The kind of a kern, as LuaTeX's subtypes: a font's kern between two glyphs, an explicit
`\kern`, an accent's kern, an italic correction. A line may break at an explicit kern or an
italic correction followed by glue; a font kern is never discarded at a break. -/
inductive KernKind where
  /-- A font kern (subtype 0). -/
  | font
  /-- An explicit `\kern` (subtype 1). -/
  | explicit
  /-- An accent kern (subtype 2). -/
  | accent
  /-- An italic correction (subtype 3). -/
  | italic
  deriving BEq, DecidableEq, Inhabited, Repr

/-- The kind of a discretionary, as LuaTeX's subtypes: `\discretionary`, `\-`, the automatic
discretionary after an explicit hyphen, and a hyphenation point found by the patterns
(`syllable`). The first pass of the line breaker does not break at a `syllable`
discretionary, as TeX's first pass does not hyphenate. -/
inductive DiscKind where
  /-- `\discretionary` (subtype 0). -/
  | discretionary
  /-- `\-` (subtype 1). -/
  | explicit
  /-- After an explicit hyphen (subtype 2). -/
  | automatic
  /-- From the hyphenation patterns (subtype 3). -/
  | syllable
  deriving BEq, DecidableEq, Inhabited, Repr

/-- A node of a horizontal list. Lengths are in sp. -/
inductive HNode where
  /-- A glyph: its character (after ligatures), its glyph index in its font, its width,
  height and depth, and its font (an index into the caller's table of fonts). -/
  | glyph (char : Char) (glyph : Nat) (width height depth : Int) (font : Nat)
  /-- A kern. -/
  | kern (width : Int) (kind : KernKind)
  /-- Glue, with LuaTeX's subtype (13 an interword space, 15 `\parfillskip`, 0 user glue). -/
  | glue (g : Glue) (subtype : Nat)
  /-- A penalty: 10000 or more forbids a break, -10000 or less forces one. -/
  | penalty (p : Int)
  /-- A discretionary: the penalty of breaking at it, the text that ends the line (`pre`), the
  text that starts the next (`post`), and the text when it is not broken at (`replace`). -/
  | disc (penalty : Int) (pre post replace : Array HNode) (kind : DiscKind)
  /-- A box of material set at its natural width: its dimensions, its shift down from the
  baseline, and its content. -/
  | box (width height depth shift : Int) (content : Array HNode)
  /-- A rule. -/
  | rule (width height depth : Int)
  /-- A formula laid out by the math layout, as an unbreakable box: its dimensions and its
  display list, whose em is `size` sp. -/
  | math (width height depth : Int) (display : DisplayList) (size : Int)
  deriving Inhabited

namespace HNode

/-- The width of a node outside a discretionary's text: a glue's natural width, a
discretionary's by its `replace` text (a discretionary inside it counting as empty), 0 for a
penalty. -/
def width : HNode → Int
  | glyph _ _ w _ _ _ | kern w _ | box w _ _ _ _ | rule w _ _ | math w _ _ _ _ => w
  | glue g _ => g.width
  | penalty _ => 0
  | disc _ _ _ r _ => r.foldl (init := 0) fun acc n => acc + match n with
    | glyph _ _ w _ _ _ | kern w _ | box w _ _ _ _ | rule w _ _ | math w _ _ _ _ => w
    | glue g _ => g.width
    | _ => 0

/-- The nodes TeX drops at the start of a line after a break: glue, penalties and kerns other
than a font's or an accent's. -/
def discardable : HNode → Bool
  | glue .. | penalty _ => true
  | kern _ k => k == .explicit || k == .italic
  | _ => false

/-- Whether a node may appear in a discretionary's text. -/
def allowedInDisc : HNode → Bool
  | glyph .. | kern .. | box .. | rule .. => true
  | _ => false

/-- The height of a node above the baseline, as `\hbox` measures it (a box's less its
shift). -/
def height : HNode → Int
  | glyph _ _ _ h _ _ | rule _ h _ | math _ h _ _ _ => h
  | box _ h _ s _ => h - s
  | _ => 0

/-- The depth of a node below the baseline, as `\hbox` measures it. -/
def depth : HNode → Int
  | glyph _ _ _ _ d _ | rule _ _ d | math _ _ d _ _ => d
  | box _ _ d s _ => d + s
  | _ => 0

end HNode

/-- The width of a list of nodes, each by `HNode.width`. -/
def listWidth (l : Array HNode) : Int := l.foldl (init := 0) fun acc n => acc + n.width

end LeAnTeX.Text
