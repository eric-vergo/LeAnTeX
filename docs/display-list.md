# The display list

The display list is LeAnTeX's back-end-neutral output: a laid-out formula as positioned
drawing operations, which an editor's glyph renderer, a rasteriser or an SVG writer can draw
without a browser. It is defined in `LeAnTeX/Layout/Display.lean` (`DisplayList`,
`DisplayList.ofBox`); this page states its contract. Back ends that need KaTeX's HTML instead
print the box tree (`LeAnTeX/Layout/Box.lean`), from which the display list is computed.

```lean
let r := LeAnTeX.layout "\\frac{a}{b}" {}
match r.result with
| .ok box => LeAnTeX.DisplayList.ofBox box                        -- the display list
| .error e => …                         -- KaTeX's error (or `unsupported`, see below)

-- a display-mode formula centred in a line 40 em wide, its tag at the right end
LeAnTeX.DisplayList.ofBox box { lineWidth := some 40 }
```

## Definition

```
DisplayList := { width height depth : Em, items : Array Item, regions : Array Region,
                 parts : Array Part, lines : Array Line, mirrored : Array (Nat × Nat) }
Item := glyph (face : Face) (char : Char) (x y size : Em) (exact shadow : Bool)
              (color : Option String) (source : Option (Nat × Nat))
      | rule (x y width height : Em) (color) (source)
      | path (data viewBox preserveAspectRatio : String) (x y width height : Em)
             (clip : Option (Em × Em × Em × Em)) (color) (source)
Face := { family : String, bold italic : Bool }      -- Face.name = "Main-Regular", …
Region := { x y width height depth : Em, source : Nat × Nat }
Part := { x width : Em, line : Nat, tag : Bool }
Line := { start stop : Nat, width height depth : Em }
DisplayOptions := { lineWidth : Option Em := none, firstEquationNumber : Nat := 1 }
Em := an integer number of TeX scaled points (1/655360 em)
```

`DisplayList.ofBox (b : Box) (opts : DisplayOptions := {})`.

## Units and coordinates

- **Units.** Every length is an `Em`, a multiple of the formula's font size: the font size of
  KaTeX's `katex` element (KaTeX sets it to 1.21 times the surrounding text). An `Em` is exact:
  an integer number of TeX's scaled points, 2⁻¹⁶ pt, at ten points to the em.
- **Coordinates.** The origin is the left end of the formula's baseline (of its line, see
  *Lines*). `x` grows to the right, `y` downwards (screen convention): a point above the
  baseline has a negative `y`.
- **Extent.** `width` is the advance of the widest line; `height` and `depth` the extent above
  and below the baseline as KaTeX's struts give it. Ink may extend beyond this box (italic
  overhangs, the tails of SVG images), as it does in KaTeX's rendering.

## Items

- **Glyphs.** One character (a Unicode scalar value) of one of KaTeX's twenty font faces, named
  as KaTeX's font files are (`Main-Regular`, `Math-Italic`, `Size2-Regular`, …), at a font size
  (in em of the formula), with its baseline origin at `(x, y)`. A back end maps the character to
  a glyph of the face's font through the font's `cmap`. Advances are the fonts' own, as a
  browser uses them. `exact` is false for a character KaTeX has no metrics of its own for in
  that face (characters of other scripts, which KaTeX measures as an `M` and leaves to the
  browser's fallback fonts, and a few symbols): draw it with a fallback font; its advance is an
  estimate. Spaces have no item (their advance is kept).
- **Shadows.** `\pmb` thickens its material with a copy offset by (0.02 em, 0.01 em) of its font
  size, drawn first; those glyphs have `shadow` set (KaTeX's CSS `text-shadow`; its 0.04 px blur
  is left out).
- **Rules.** A filled rectangle given by its top-left corner, width and height: fraction bars,
  overlines and underlines, `\rule`, the horizontal and vertical rules of arrays, the strike of
  `\sout`, the borders of `\fbox`, `\boxed`, `\fcolorbox` and `\angl`, and the backgrounds of
  `\colorbox` and `\fcolorbox` (a background comes before the material it is behind, then the
  top, bottom, left and right borders). A **dashed** rule (`\hdashline`, a `:` column) is a run
  of rules: dashes three times the rule's thickness long, with gaps of at least twice the
  thickness, spread so that the line starts and ends with a dash (a line too short for two
  dashes is solid). Browsers draw dashed borders each in their own pattern; this is LeAnTeX's.
- **Paths.** SVG path data with the `viewBox` and `preserveAspectRatio` of KaTeX's `svg`
  element, drawn into the rectangle given, with SVG's viewport rules: the surd of `\sqrt`,
  stacked delimiters, stretchy accents, extensible arrows, horizontal braces, the angle of
  `\phase`, the ovals of `\oiint`. `clip`, when set, is the rectangle the image is clipped to
  (KaTeX's `overflow: hidden` spans); the path data of a stretchy image is much wider than the
  clip. The strokes of `\cancel`, `\bcancel` and `\xcancel` (SVG `line` elements in KaTeX) are
  paths too: the outline of the stroke, 0.046 em wide with square-cut ends, in a viewBox that is
  the rectangle in thousandths of an em, `preserveAspectRatio` `none`, clipped to the rectangle.
- **Colour.** The CSS colour the item is drawn in, as the formula gave it (`red`, `#933`), or
  `none` for the colour of the surrounding text. KaTeX accepts any word as a colour name; a
  browser ignores one it does not know (text keeps the surrounding colour, a box gets no
  background), and a back end should do the same. Material inside `\phantom` is not drawn and
  has no items, except the backgrounds of boxes, which a browser still draws.
- **Source.** The source range of the innermost parse node that has one: start and end offsets
  in UTF-16 code units of the formula, end exclusive (the parser's locations).
- **Order.** Items are in the order of KaTeX's markup, which is the order a browser paints them.

## Structure

- **Regions.** For every parse node with a source range that produced a box, the box's
  rectangle: left end, width, baseline, height and depth, outermost first. A back end maps a
  position to the source by taking the innermost region that contains it (hovers, selection).
  Regions are where the material is drawn, mirrored material included.
- **Parts.** The formula's unbreakable parts, KaTeX's `katex-base` spans, in order and without
  gaps on a line: a back end that breaks a long inline formula may break between parts, as a
  browser does. The equation tag (`\tag`, or the numbers of `{equation}`, `{align}`,
  `{gather}`, …) is the last part, with `tag` set.
- **Lines.** `\\` and `\newline` at the top level break a formula into lines. `lines` partitions
  `items` into them (one line otherwise); each line's items are relative to that line's own
  baseline and left end, and a back end stacks the lines with the spacing of its surrounding
  text, as a browser does.
- **Mirrored material.** `\reflectbox` mirrors its material (CSS `transform: scaleX(-1)` about
  the box's middle). `mirrored` lists the items drawn mirrored, as ranges `[start, stop)` of
  `items`, in order and disjoint (material mirrored twice is not mirrored). Their positions are
  already the mirrored ones; such a glyph is drawn reflected in the vertical line through its
  origin, so that its advance runs leftwards from `x`; such a path is drawn reflected within its
  rectangle. A back end that ignores `mirrored` draws the material in the right places,
  unmirrored.
- **Equation numbers.** KaTeX numbers `{equation}`, `{align}`, `{gather}` and their kin with a
  CSS counter; the display list writes the numbers out as glyphs, `(1)`, `(2)`, … in document
  order, from `opts.firstEquationNumber`. A back end that numbers equations across a document
  passes the number of the formula's first equation.

## Display mode

Without `opts.lineWidth`, a display-mode formula starts at `x = 0` and its tag follows it on
the line. With `opts.lineWidth = some w`, it is placed in a line `w` em wide as KaTeX's style
sheet places it: each line of the formula centred (with `fleqn`, indented 2 em instead; a line
wider than `w` starts at 0), the tag ending at the right end of the line (with `leqno`, starting
at its left end, or at the 2 em indent with `fleqn`). `x` is then measured from the left end of
the line, and a line's width is at least `w`. Inline formulas ignore `lineWidth`.

## Invariants

1. Every glyph's face is one of KaTeX's twenty font files and its size is positive.
2. Rules and path rectangles have non-negative width and height.
3. `lines` is a partition of `0 … items.size` into consecutive ranges, one per line.
4. `mirrored` is a list of non-empty, disjoint ranges of `items`, in order.
5. The display list is a function of the box tree and the options: equal inputs give equal
   display lists.

`lake test` checks 1–4 on every formula of the corpora (`DisplayList.wellFormed`), and the
behaviour of this page's features on chosen formulas (`LeAnTeXTest/DisplayChecks.lean`).

## Stability

From this version on, the interface above changes only by addition: new fields with defaults
(as `mirrored` and `DisplayOptions`), new optional arguments. Back ends should construct
`DisplayOptions` with field names (`{ lineWidth := some w }`) and match `Item` by its three
constructors. `BuildError.unsupported` stays in the error type although nothing raises it now.

## Not represented

- `\includegraphics` images (only with `trust`) have no item; their space is kept.
- KaTeX's style sheet gives a vertical rule of an array a least width of one pixel; the display
  list, which has no pixels, gives it its border's width. At 400 px to the em that moves the
  columns after it 0.0025 em per rule.

## How it is checked

`lake test` checks the box tree against KaTeX's own (`parity/LAYOUT.md`). The display list is
computed from the box tree by evaluating the part of KaTeX's style sheet that its trees use;
`tools/check-display.mjs` checks that evaluation against a browser: it renders every formula
LeAnTeX lays out with KaTeX, its CSS and fonts in headless Chromium at 400 px, display-mode
formulas in a line as wide as `lake exe leantex-display --line-width` gives (40 em), and
compares every glyph's position, face and size, every rule's rectangle (dashed rules as the
dashes above) and every SVG image's viewport, in order, and the width. Over the corpora
(11,100 formulas, 49,234 glyphs, 719 rules, 648 SVG images): no count, face or character
differs; glyph positions agree within 0.0049 em horizontally (99 % within 0.0003 em) and 0.0002 em
vertically, rules and SVG
viewports within 0.01 em (the same array: four one-pixel rules; otherwise 0.0053 em, a box
border rounded to whole pixels at a smaller size, and 0.0025 em, one pixel, for the rest).
Left out: the 87 formulas with a character KaTeX has no metrics of its own for (the browser
draws it with a fallback font whose advance no table holds) and 4 with a colour the browser
does not know.
