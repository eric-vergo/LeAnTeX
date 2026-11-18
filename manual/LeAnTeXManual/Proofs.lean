/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import VersoManual
import LeAnTeXManual.Meta

open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean
open LeAnTeXManual

#doc (Manual) "What Is Proved" =>
%%%
tag := "proofs"
htmlSplit := .never
%%%

A few properties of LeAnTeX are theorems in the library, stated about the functions the library
calls (not about copies of them). Lean's kernel checks each theorem when the library is built
(`lake build`). Everything else is tested, mostly by comparison with recorded answers of TeX and
KaTeX ({ref "agreement"}[Agreement with TeX and KaTeX]); a theorem below says only what its
statement says.

Each theorem is shown here by a restatement that this manual's build checks against it: the
`example` must have the theorem as its proof, so if the theorem's statement changes, the manual
no longer builds until this page is changed with it. Below each, one paragraph says what the
statement establishes and what it does not. The table at the end lists every theorem of the
library's four modules of theorems with the axioms it rests on, read from the compiled library
when the manual is built; the build fails if any rests on an axiom other than Lean's three
standard ones (`propext`, `Classical.choice`, `Quot.sound`). The library's own check is
`lake build LeAnTeXTest.TextAxioms LeAnTeXTest.DocAxioms LeAnTeXTest.BackendAxioms
LeAnTeXTest.TeXMathAxioms`.

# Escaping in the Back Ends
%%%
tag := "proofs-escape"
%%%

{name}`LeAnTeX.Backend.escape` is the function the SVG and HTML back ends use for text and
attribute values that come from the source.

```lean
open LeAnTeX.Backend in
example (s : String) : '<' ∉ (escape s).toList := escape_no_lt s

open LeAnTeX.Backend in
example (s : String) : '>' ∉ (escape s).toList := escape_no_gt s

open LeAnTeX.Backend in
example (s : String) : '"' ∉ (escape s).toList := escape_no_quot s

open LeAnTeX.Backend in
example (s : String) : '\'' ∉ (escape s).toList := escape_no_apos s
```

*Establishes:* for every string, the result of `escape` contains none of the four characters
`<`, `>`, `"` and `'`, so escaped text can neither open markup nor end a quoted attribute value.
*Does not establish:* that every writer passes every piece of text from the source through
`escape`. That is tested (the back ends' checks run hostile sources and look for script, event
handlers and foreign objects in the output), not proved. It says nothing about `&`, which the
next theorem covers.

```lean
open LeAnTeX.Backend in
example (l : List Char) : unescapeList (escapeList l) = l.filter xmlChar :=
  unescape_escape l
```

*Establishes:* decoding the five entities `escape` writes (`unescapeList`) gives the input back,
less the characters XML cannot carry, which `escape` drops; so every `&` that escaping writes
starts one of its own entities. The statement is about `escapeList` on lists of characters;
`escape` is defined as `escapeList` on the string's characters.
*Does not establish:* anything about a browser's or an XML parser's decoding beyond these five
entities, or about text that did not go through `escape`.

```lean
open LeAnTeX.Backend in
example (fs : FontSet) (dl : LeAnTeX.DisplayList) (opts : SvgOptions) (u : SvgUse)
    (h : Sum.inl u ∈ (picture fs dl opts).body) :
    ∃ d ∈ (picture fs dl opts).defs, d.1 = u.ref :=
  exists_def_of_mem_picture_body fs dl opts u h
```

*Establishes:* every glyph an SVG picture draws refers to a definition inside the same picture.
*Does not establish:* that the right glyph is drawn: it holds by construction, because the
picture keeps a reference only if its definition is there. The module documentation of
{name}`LeAnTeX.Backend.exists_def_of_mem_picture_body`'s module says which references that
filter can drop (glyphs with an empty outline, which draw nothing).

# Line Breaking and Hyphenation
%%%
tag := "proofs-text"
%%%

```lean
open LeAnTeX.Text in
example {items : Array HNode} {p : Params} {r : Breaks}
    (h : breakParagraph items p = .ok r) :
    ∀ b ∈ r.breaks, b.pos = items.size ∨ legalBreak items b.pos = true :=
  breakParagraph_legal h

open LeAnTeX.Text in
example {items : Array HNode} {p : Params} {r : Breaks}
    (h : breakParagraph items p = .ok r) :
    increasing (r.breaks.toList.map (·.pos)) = true :=
  breakParagraph_increasing h

open LeAnTeX.Text in
example {items : Array HNode} {p : Params} {r : Breaks}
    (h : breakParagraph items p = .ok r) :
    r.breaks.back?.map (·.pos) = some items.size :=
  breakParagraph_ends h
```

*Establishes:* when the line breaker returns breaks, each is a legal breakpoint of its input
(or the end), they increase, and the last is the end of the paragraph.
*Does not establish:* that the breaks are TeX's, or optimal in TeX's sense. The line breaker
checks these three conditions on its own result before returning it and returns an error
otherwise, so the theorems hold by construction; that the algorithm is TeX's is shown by the
comparison with LuaLaTeX's breaks, not proved.

```lean
open LeAnTeX.Text in
example {items : Array HNode} {bs : Array Nat} {a b : Nat}
    (h : (lineRanges items bs)[0]? = some (a, b)) : a = 0 :=
  lineRanges_first h

open LeAnTeX.Text in
example {items : Array HNode} {bs : Array Nat} {k a b : Nat}
    (h : (lineRanges items bs)[k]? = some (a, b)) : bs[k]? = some b :=
  lineRanges_stop h

open LeAnTeX.Text in
example {items : Array HNode} {bs : Array Nat} {k a b a' b' : Nat}
    (h : (lineRanges items bs)[k]? = some (a, b))
    (h' : (lineRanges items bs)[k + 1]? = some (a', b')) :
    b < a' ∧ ∀ j, b < j → j < a' →
      ∃ n, items[j]? = some n ∧ n.discardable = true :=
  lineRanges_next h h'
```

*Establishes:* the ranges of nodes the lines are built from start at the first node, each ends
at its break, and the next starts after it with only discardable nodes (glue, penalties, kerns)
between: together, the lines hold the input's nodes in order, without the nodes dropped at
breaks.
*Does not establish:* how each line is set (its glue setting), which is tested against TeX.

```lean
open LeAnTeX.Text in
example (ps : Patterns) (w : String) (left right k : Nat)
    (h : k ∈ ps.points w left right) : left ≤ k ∧ k + right ≤ w.length :=
  points_minima ps w left right k h

open LeAnTeX.Text in
example (t s : Int) : badness t s ≤ infBad := badness_le t s
```

*Establishes:* no hyphenation point is closer to a word's start than the left minimum or to its
end than the right minimum; a badness is at most `infBad` (10000).
*Does not establish:* that the points are the patterns' (TeX's) points, which is tested on 1,691
words against LuaLaTeX.

# Pages, Counters, References and Images
%%%
tag := "proofs-doc"
%%%

```lean
open LeAnTeX.Doc in
example (items : Array LeAnTeX.Doc.VNode) (p : PageParams) (pages : Array PageOut)
    (h : buildPages items p = .ok pages) : pagesPartition items pages = true :=
  buildPages_boxes items p pages h
```

*Establishes:* when the page builder returns pages, they pass `pagesPartition`: the sizes of the
boxes on them, in order, are the sizes of the vertical list's boxes in order, so no box is lost,
repeated or moved (the boxes of floats set here and the material of insertions are not in the
count).
*Does not establish:* where the pages are cut. The builder makes the comparison before it
returns, so the theorem holds by construction; the page breaks are compared with LuaLaTeX's.

```lean
open LeAnTeX.Doc in
example (cs : Counters) (n : String) (v : Int) (c : Counter)
    (h : cs.table.get? n = some c) : (cs.add n v).value n = c.value + v :=
  Counters.add_value cs n v c h

open LeAnTeX.Doc in
example (cs : Counters) (n : String) (v : Int) (c : Counter)
    (h : cs.table.get? n = some c) : (cs.set n v).value n = v :=
  Counters.set_value cs n v c h

open LeAnTeX.Doc in
example (cs : Counters) (n : String) : (cs.newCounter n none).value n = 0 :=
  Counters.newCounter_value cs n
```

*Establishes:* adding to and setting a defined counter give the value asked for; a new counter
(not within another) is zero.
*Does not establish:* that LaTeX's resets of dependent counters happen as in LaTeX, which is
tested through the recorded counter steps.

```lean
open LeAnTeX.Doc in
example (refs : Std.HashMap String (String × String)) (key : String) (page : Bool)
    (s : String) (h : lookupRef refs key page = some s) :
    ∃ t p, refs[key]? = some (t, p) ∧ s = if page then p else t :=
  lookupRef_some refs key page s h

open LeAnTeX.Doc in
example (refs : Std.HashMap String (String × String)) (key : String) (page : Bool)
    (h : lookupRef refs key page = none) : refs[key]? = none :=
  lookupRef_none refs key page h
```

*Establishes:* a reference that resolves gives the text (or the page) the table of labels holds
for its key, and one that does not has no entry there.
*Does not establish:* that the table holds the right values: the labels come from the previous
pass, and their agreement with LaTeX's is tested.

```lean
open LeAnTeX.Doc LeAnTeX.Text in
example (p : String) (h : Typeset.safeImagePath p = true) :
    p.startsWith "/" = false :=
  safeImagePath_relative p h

open LeAnTeX.Doc LeAnTeX.Text in
example (p : String) (h : Typeset.safeImagePath p = true) :
    ∀ seg ∈ p.splitOn "/", seg ≠ ".." :=
  safeImagePath_noParent p h

open LeAnTeX.Doc in
example (n : Int) (h : n ≤ 0) : romanLower n = "" := romanLower_nonpos n h
```

*Establishes:* a path that passes the check the document layer makes before it asks the caller
for an image does not start with `/` and has no `..` segment; `\roman` of zero or less prints
nothing.
*Does not establish:* what the caller's function does with the path: the document layer only
asks, and the caller decides which files are reachable.

# The TeX-Rule Layout
%%%
tag := "proofs-texmath"
%%%

```lean
open LeAnTeX.TeXMath in
example (s : Style) : s.sub.isCramped = true := Style.sub_isCramped s

open LeAnTeX.TeXMath in
example (s : Style) : s.denom.isCramped = true := Style.denom_isCramped s

open LeAnTeX.TeXMath in
example (s : Style) (h : s.isCramped = true) : s.sup.isCramped = true :=
  Style.sup_isCramped_of s h

open LeAnTeX.TeXMath in
example (s : Style) : s.cramped.cramped = s.cramped := Style.cramped_cramped s

open LeAnTeX.TeXMath in
example (s : Style) : s.size ≤ s.sub.size := Style.size_le_sub s

open LeAnTeX.TeXMath in
example (s : Style) : s.size ≤ s.num.size := Style.size_le_num s

open LeAnTeX.TeXMath in
example (s : Style) : s.sub.size = s.sup.size := Style.sub_size_eq_sup_size s

open LeAnTeX.TeXMath in
example (s : Style) (h : 4 ≤ s.code.val) : s.sub.size = 2 := Style.sub_of_script s h
```

*Establishes:* properties of the style functions the layout calls: a subscript's and a
denominator's style is cramped, a cramped style's superscript is cramped, `cramped` is
idempotent, a script or numerator is never set at a larger size than what it belongs to (a
larger `size` code is a smaller size), subscript and superscript share a size, and the scripts
of a script style are scriptscript.
*Does not establish:* that these are all of *The TeXbook*'s style rules, or that the layout
uses them where TeX does; the boxes are compared with LuaLaTeX's.

```lean
open LeAnTeX.TeXMath in
example (l r : Fin 8) :
    spacingTable l r = 2 ↔
      (l = 0 ∧ r = 1) ∨ (l = 1 ∧ r = 0) ∨ (l = 1 ∧ r = 1) ∨ (l = 5 ∧ r = 1) ∨
        (l = 7 ∧ r = 1) :=
  spacingTable_eq_two_iff l r

open LeAnTeX.TeXMath in
example (r : Fin 8) : spacingTable 4 r = 0 := spacingTable_after_open r

open LeAnTeX.TeXMath in
example (l : Fin 8) (h : l ≠ 6) : spacingTable l 5 = 0 := spacingTable_before_close l h

open LeAnTeX.TeXMath in
example (p : Params) (l r : Fin 8) (s : Style) (mu : Int) (h : s.isLarge = false) :
    interAtomGlue p l r s mu = none ∨ spacingTable l r = 2 :=
  interAtomGlue_script p l r s mu h
```

*Establishes:* properties of the inter-atom spacing table as it is written in the library: where
it has the unconditional thin space (code 2), that it has no space after an opening atom and none
before a closing atom except after punctuation, and that in script styles the only glue between
atoms is that thin space.
*Does not establish:* that the table's entries are *The TeXbook*'s. That is a reading of the two
tables side by side, and is tested through the boxes.

```lean
open LeAnTeX.TeXMath in
example (l : Array Node) :
    (hpack l).width = l.foldl (init := 0) fun a n => a + n.width :=
  hpack_width l

open LeAnTeX.TeXMath in
example (l : Array Node) (n : Node) (h : n ∈ l) : n.height ≤ (hpack l).boxHeight :=
  le_hpack_height l n h

open LeAnTeX.TeXMath in
example (l : Array Node) (n : Node) (h : n ∈ l) : n.depth ≤ (hpack l).boxDepth :=
  le_hpack_depth l n h
```

*Establishes:* a box packed at its natural width is as wide as its children together and at
least as high and as deep as each of them.
*Does not establish:* anything about boxes packed to a given width (glue set), or that the rules
of Appendix G are followed: those are shown by the boxes, not proved.

# Axioms
%%%
tag := "proofs-axioms"
%%%

Every theorem of `LeAnTeX.Backend.Proofs`, `LeAnTeX.Text.Proofs`, `LeAnTeX.Doc.Proofs` and
`LeAnTeX.TeXMath.Proofs` (helper lemmas included), with the axioms Lean's `#print axioms` would
report for it:

{axiomTable}
