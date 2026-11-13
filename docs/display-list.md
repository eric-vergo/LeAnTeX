# The display list

The display list is LeAnTeX's back-end-neutral output: a laid-out formula as positioned
drawing operations, which an editor's glyph renderer, a rasteriser or an SVG writer can draw
without a browser. It is defined in `LeAnTeX/Layout/Display.lean` (`DisplayList`,
`DisplayList.ofBox`); this page states its contract. Back ends that need KaTeX's HTML instead
print the box tree (`LeAnTeX/Layout/Box.lean`), from which the display list is computed.

```lean
let r := LeAnTeX.layout "\\frac{a}{b}" {}
match r.result with
| .ok box => LeAnTeX.DisplayList.ofBox box   -- the display list
| .error e => …                              -- KaTeX's error, or a construct not laid out yet
```

## Definition

```
DisplayList := { width height depth : Em, items : Array Item, regions : Array Region,
                 parts : Array Part, lines : Array Line }
Item := glyph (face : Face) (char : Char) (x y size : Em) (exact shadow : Bool)
              (color : Option String) (source : Option (Nat × Nat))
      | rule (x y width height : Em) (color) (source)
      | path (data viewBox preserveAspectRatio : String) (x y width height : Em)
             (clip : Option (Em × Em × Em × Em)) (color) (source)
Face := { family : String, bold italic : Bool }      -- Face.name = "Main-Regular", …
Region := { x y width height depth : Em, source : Nat × Nat }
Part := { x width : Em, line : Nat, tag : Bool }
Line := { start stop : Nat, width height depth : Em }
Em := an integer number of TeX scaled points (1/655360 em)
```

## Units and coordinates

- **Units.** Every length is an `Em`, a multiple of the formula's font size: the font size of
  KaTeX's `katex` element (KaTeX sets it to 1.21 times the surrounding text). An `Em` is exact:
  an integer number of TeX's scaled points, 2⁻¹⁶ pt, at ten points to the em.
- **Coordinates.** The origin is the left end of the formula's baseline. `x` grows to the right,
  `y` downwards (screen convention): a point above the baseline has a negative `y`.
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
  estimate.
- **Shadows.** `\pmb` thickens its material with a copy offset by (0.02 em, 0.01 em) of its font
  size, drawn first; those glyphs have `shadow` set (KaTeX's CSS `text-shadow`; its 0.04 px blur
  is left out).
- **Rules.** A filled rectangle given by its top-left corner, width and height: fraction bars,
  overlines and underlines, `\rule`.
- **Paths.** SVG path data with the `viewBox` and `preserveAspectRatio` of KaTeX's `svg`
  element, drawn into the rectangle given, with SVG's viewport rules: the surd of `\sqrt`,
  stacked delimiters, stretchy accents, the ovals of `\oiint`. `clip`, when set, is the
  rectangle the image is clipped to (KaTeX's `overflow: hidden` spans); the path data of a
  stretchy image is much wider than the clip.
- **Colour.** The CSS colour the item is drawn in, as the formula gave it (`red`, `#933`), or
  `none` for the colour of the surrounding text. Material inside `\phantom` is not drawn and has
  no items.
- **Source.** The source range of the innermost parse node that has one: start and end offsets
  in UTF-16 code units of the formula, end exclusive (the parser's locations).
- **Order.** Items are in the order of KaTeX's markup, which is the order a browser paints them.

## Structure

- **Regions.** For every parse node with a source range that produced a box, the box's
  rectangle: left end, width, baseline, height and depth, outermost first. A back end maps a
  position to the source by taking the innermost region that contains it (hovers, selection).
- **Parts.** The formula's unbreakable parts, KaTeX's `katex-base` spans, in order and without
  gaps on a line: a back end that breaks a long inline formula may break between parts, as a
  browser does. The equation tag, if any, is the last part with `tag` set; it is placed right
  after the formula, whereas in display mode KaTeX puts it at the right end of the line (a back
  end moves the items from the tag's left end on).
- **Lines.** `\\` and `\newline` at the top level break a formula into lines. `lines` partitions
  `items` into them (one line otherwise); each line's items are relative to that line's own
  baseline and left end, and a back end stacks the lines with the spacing of its surrounding
  text, as a browser does.

## Invariants

1. Every glyph's face is one of KaTeX's twenty font files and its size is positive.
2. Rules and path rectangles have non-negative width and height.
3. `lines` is a partition of `0 … items.size` into consecutive ranges, one per line.
4. The display list is a function of the box tree: two equal trees give equal display lists.

## Not represented

- `\reflectbox` mirrors its material in KaTeX (CSS `transform`); the display list places the
  material unmirrored.
- `\includegraphics` images (only with `trust`) have no item; their space is kept.
- Display mode centres the formula in the line and puts the tag at the right end; the display
  list is left-aligned at `x = 0`, and the back end centres it.

## How it is checked

`lake test` checks the box tree against KaTeX's own (`parity/LAYOUT.md`). The display list is
computed from the box tree by evaluating the part of KaTeX's style sheet that its trees use;
`tools/check-display.mjs` checks that evaluation against a browser: it renders every formula
LeAnTeX lays out with KaTeX, its CSS and fonts in headless Chromium at 400 px and compares every
glyph's position, face and size, every rule's rectangle and every SVG image's viewport, in
order. Over the corpora (10,721 formulas, 44,663 glyphs, 358 rules, 257 SVG images): glyph
positions agree within 0.002 em horizontally (99 % within 0.0004 em) and 0.0002 em vertically,
widths within 0.002 em, SVG viewports within 0.0006 em, rules within 0.0025 em (Chromium rounds
border widths to whole pixels: 0.0025 em is one pixel at 400 px). Left out of the comparison:
the 96 formulas with a character KaTeX has no metrics of its own for (the browser draws it with
a fallback font whose advance no table holds), formulas with `\reflectbox`, and the tag in
display mode.
