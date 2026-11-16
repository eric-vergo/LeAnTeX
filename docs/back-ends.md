# Back ends: SVG and HTML

LeAnTeX draws its display lists (`docs/display-list.md`) in two forms: an SVG picture that needs
nothing else, and an HTML page whose text is real text. Both take text and formulas together, as
the text layer sets them (`docs/text.md`), and both use the fonts of New Computer Modern that
the repository carries (`fonts/README.md`).

```
lake exe leantex-render FILE.tex OUT.svg                 # SVG
lake exe leantex-render --html FILE.tex OUT.html         # HTML (fonts from fonts/newcomputermodern)
lake exe leantex-render --math FORMULA.tex OUT.svg       # one formula in display mode
lake exe leantex-render --html --font-url URL FILE.tex OUT.html
```

```lean
import LeAnTeX
open LeAnTeX LeAnTeX.Backend

def demo : IO Unit := do
  let (fonts, _) ← Fonts.load "fonts/newcomputermodern"
  match render fonts "Hello, $x^2$." with
  | .ok svg => IO.FS.writeFile "hello.svg" svg
  | .error (pos, msg) => IO.eprintln s!"{pos}: {msg}"
```

`examples/` has three samples, each as source, SVG and HTML: a paragraph in the text fonts
(`paragraph`), text with inline and displayed formulas (`mixed`) and macros (`macros`).

## Fonts

| What | Files |
|---|---|
| Text (`\rmfamily`, the default) | `NewCM10-Book`, `NewCM10-BookItalic`, `NewCM10-Bold`, `NewCM10-BoldItalic`; `NewCM08-Book` and `NewCM08-BookItalic` up to 8 points |
| Sans serif | `NewCMSans10-Book`, `-BookOblique`, `-Bold`, `-BoldOblique`; the 8-point designs up to 8 points |
| Typewriter | `NewCMMono10-Book`, `-BookItalic`, `-Bold`, `-BoldOblique` |
| Slanted, small capitals | the upright font slanted by 0.25; its `smcp` feature |
| Math | `NewCMMath-Book` (and `NewCMMath-Bold` for bold upright) |

The text layer chooses the file for a font as the package's own `fontspec` files do
(`LeAnTeX.Text.newComputerModernFace`). With these fonts, the text layer gives LuaLaTeX's
horizontal lists, lines and paragraph boxes for all 174 paragraphs of the text corpus, as it
does with Latin Modern (`fixtures/text/paragraphs-ncm.jsonl`, recorded by
`bash tools/tex-reference.sh --ncm paragraphs`).

**Math.** Formulas are laid out by the math layout, with KaTeX's metrics, and drawn with New
Computer Modern Math: each of KaTeX's faces maps a character to the Unicode mathematical
character it stands for (`Math-Italic` `x` to U+1D465 *𝑥*, `AMS-Regular` `R` to ℝ, `Fraktur`,
`Caligraphic`, sans serif and typewriter likewise), and the larger delimiters and operators of
KaTeX's `Size1`–`Size4` faces are the math font's size variants (its `MATH` table), the
smallest at least as tall as KaTeX's glyph. What does not line up:

* The positions are KaTeX's, the shapes New Computer Modern's; where a glyph's width differs
  from KaTeX's font, the space after it is KaTeX's. Most of KaTeX's fonts and New Computer
  Modern descend from Computer Modern and agree closely.
* KaTeX's `Script` face (a round hand) and its `Caligraphic` face both become Unicode's script
  letters, which New Computer Modern draws as calligraphic capitals; its round-hand script is
  behind a variation selector the reader does not apply.
* A size variant's height is the font's, not KaTeX's glyph's; a variant can be a little taller
  or shorter than the space KaTeX left for it.
* Extensible delimiters built from pieces and KaTeX's SVG paths (roots, wide accents, arrows)
  are drawn as KaTeX gives them, not from the math font's glyph assemblies.
* Text inside formulas (`\text`) uses the math layout's text faces, drawn with the math font's
  upright letters, not with the text layer's fonts.

## SVG

* One user unit is one of TeX's points; the picture's `width` and `height` are in CSS points
  (1/72 inch), so it has TeX's size.
* Each glyph used is one `<path>` in `<defs>` (its outline in font units) and each occurrence a
  `<use>` with a transformation: size, position, slant, mirroring. The picture refers to no font
  file and looks the same everywhere.
* Rules are rectangles; the display list's paths are nested `<svg>` elements with their view
  boxes; colours (`\color`) are fills when they are CSS colours.
* `role="img"`, a `<title>` with the source and a `<desc>`.
* Deterministic: numbers are written from integers (three decimals of a point, two of a font
  unit).

## HTML

* The text is text: runs of glyphs (a word, or the part of a word in one font) in `span`s at
  TeX's positions, set by the browser in the same fonts (`@font-face` rules that load the files
  of `fonts/newcomputermodern` from `--font-url`). Interword spaces are kept in the text, so
  copying and searching work; justified and hyphenated lines keep TeX's breaks and spacing.
* A run is placed by its baseline without knowing the font's ascent: a baseline-aligned flex box
  whose first item is an empty strut two ems tall.
* Formulas are inline SVG pictures with `role="img"`, the source as `aria-label` and as hidden
  text.
* One style sheet, no script and no event handler; positions are `style` attributes. The page
  works under a content security policy such as `default-src 'none'; style-src 'unsafe-inline';
  font-src <the fonts' origin>`.
* For a stricter policy, a document's pages can take every position from a generated style
  sheet instead (`HtmlDocOptions.externalStyles`, `leantex-render --document --external-css`):
  each element gets a class of its own and the page links `document.css`; it then works under
  `style-src <the sheet's origin>` without `'unsafe-inline'`. Inline styles stay the default:
  one self-contained file, nothing to keep beside it.

## MathML

`mathML` (`LeAnTeX/Backend/MathML.lean`) writes a formula's parse tree as MathML Core, for a
page that shows the formula as a picture and wants screen readers and other software to read
it: identifiers, numbers and operators with their characters, fractions, roots, scripts and
limits, fences, accents, braces, matrices, text, font changes as Unicode's mathematical
alphanumeric characters, the source as an `application/x-tex` annotation. Spacing, colours,
sizes and boxes keep only their content. Text is escaped and nesting past 200 levels is left
out. It is not drawn: the picture stays the formula's appearance.

## Documents

`leantex-render --document FILE OUTDIR` typesets a whole document (`docs/documents.md`) and
writes `page-N.svg` per page (the paper's size), `document.svg` (every page on a sheet, one
below the other), `document.html` (the pages as sheets) and `web.html` (one continuous page, no
page breaks, floats where they are given: the document typeset with `Settings.continuous`).
Images are `<image>` elements with the file as a `data:` URL; the table of contents' dotted
leaders are drawn as LaTeX aligns them.

## Untrusted input

Everything from TeX source (text, formula sources in titles and alternative text, colour names)
is escaped or checked: `<`, `>`, `&`, `"` and `'` become entities and characters XML cannot carry
are dropped (`LeAnTeX.Backend.escape`); a colour is used only if it is `#` and 3, 4, 6 or 8
hexadecimal digits or a name of ASCII letters. The MathML writer escapes every text with the
same function. Fonts are read with the reader's checks (`docs/opentype.md`). The back ends'
sources are in the test that refuses panicking operations.

## Proved and tested

Proved (`LeAnTeX.Backend.Proofs`; axioms `propext`, `Classical.choice`, `Quot.sound` only):

* `escape_no_lt`, `escape_no_gt`, `escape_no_quot`, `escape_no_apos`: the result of `escape`
  contains no `<`, `>`, `"` or `'`. (That the writers pass every text from the source through
  `escape` is not a theorem: the tests check it on hostile sources.)
* `unescape_escape`: decoding the five entities gives the input back, less the characters XML
  cannot carry (so every `&` written starts an entity).
* `exists_def_of_mem_picture_body`: every glyph an SVG picture draws has its definition in the picture.

Tested (`lake test`, `LeAnTeXTest/BackendChecks.lean`): the examples' SVG and HTML byte for byte
(`lake exe leantex-test --update-examples` rewrites them) and rendered twice; in each, every
`<use>` has its definition and there is no script, event handler or foreign object; 43 named
checks, 41 without the metric files (faces, size variants, colours, hostile source, runs, slant
and small capitals, units, MathML, documents).

**Against LuaLaTeX's own rendering.** `bash tools/tex-render-compare.sh FRAGMENT.tex` sets a
fragment with `leantex-render` and with LuaLaTeX (text in New Computer Modern, math in LaTeX's
default fonts) on pages of the same size, renders both with macOS's Quick Look at 4 pixels to
the point and compares them pixel by pixel (`tools/compare-pixels.py`, which aligns the two by
their ink boxes). On the fragments of `tools/tex-render/`:

| Fragment | Mean difference (levels of 255) | Pixels within 32 levels |
|---|---|---|
| `paragraph.tex` (text only) | 9.4 | 89.7 % |
| `display-integral.tex` (text and a display) | 6.0 | 93.8 % |
| `display-cases.tex` | 4.8 | 94.3 % |

The text lines fall on the same pixels; the differences are the two renderers' anti-aliasing
(PDFKit draws the same outlines lighter) and glyph positions within a pixel. In formulas,
glyphs move by one to three pixels (a quarter to three quarters of a point): the math layout is
KaTeX's and LaTeX's math fonts are Computer Modern's Type 1 fonts. Inline formulas are
KaTeX's width, not TeX's, so a paragraph with inline formulas can break into different lines
than LuaLaTeX's. The tolerance a fragment of text must meet: a mean below 12 levels and 85 % of
pixels within 32 levels. The comparison needs LuaLaTeX and macOS and is not part of `lake test`.

## Not implemented

* No PDF: pages are SVG pictures and HTML sheets (*Documents*, above).
* In HTML, text inside formulas is not selectable as text (the formula's source is); `\rule`s and
  glyphs drawn as outlines outside formulas are one SVG picture per line.
* Fonts other than New Computer Modern for drawing formulas need a `FontSet` of their own; the
  text layer takes any fonts through its resolver.
* `leantex-render` takes about 1.6 s of processor time for a small sample (one core of an
  Apple M2 Ultra), most of it reading the fonts.
