# The OpenType reader

`LeAnTeX.OpenType` reads OpenType fonts in pure Lean (`Init` and `Std` only), for the text mode
and for back ends that draw glyphs as outlines.

```lean
import LeAnTeX

open LeAnTeX.OpenType in
def demo (bytes : ByteArray) : Except FontError (Nat × Int) := do
  let f ← Font.read bytes
  let g := f.glyph 'A'
  return (f.advance g, f.kerning g (f.glyph 'V'))
```

## What it reads

| Table | What |
|---|---|
| directory | `sfntVersion` `0x00010000`, `OTTO` or `true` (font collections are refused) |
| `head`, `hhea`, `maxp`, `hmtx` | units per em, the font box, style bits, ascender, descender, line gap, the number of glyphs, advance widths and left side bearings |
| `OS/2`, `post` | weight and width classes, embedding permissions (`fsType`), typographic and Windows metrics, x-height, cap height, the PANOSE proportion (9: monospaced); italic angle, underline, fixed pitch |
| `name` | names by id, Windows US English preferred |
| `cmap` | formats 0, 4, 6 and 12; a full-repertoire Unicode subtable preferred |
| `CFF ` | INDEXes, DICTs (reals included), Private DICTs, local and global subroutines, CID-keyed fonts (FDArray, FDSelect formats 0 and 3); Type 2 charstrings to outlines and widths |
| `glyf`, `loca` | simple glyphs (implied on-curve points made explicit) and composites placed by offset and 2×2 transform |
| `GSUB` | single (type 1) and ligature (type 4) substitution, through extension lookups (type 7); `Font.ligate` applies `liga` |
| `GPOS`, `kern` | pair adjustment (type 2, formats 1 and 2, through type 9) for the `kern` feature; the old `kern` table (version 0, format 0) when there is no `GPOS` |
| `MATH` | the 56 `MathConstants`; `MathVariants`: each glyph's vertical and horizontal size variants with their sizes (glyph assemblies are not read) |

Outlines are `Path Int` (`LeAnTeX.Path`) in 1/65536 font units: Type 2's 16.16 numbers and
TrueType's half units are exact. `Font.glyphItem` (`LeAnTeX.OpenType.Display`) turns a glyph
into a display-list `Item.path`.

Not read or not applied: lookup flags (marks are not skipped), contextual and chaining lookups,
the second glyph's adjustment of a pair, `GDEF`, CFF2 and variable fonts, the arithmetic
operators of the original Type 2 specification and `seac`-style accented `endchar` (reported as
errors), components placed by matching points, hinting.

## Untrusted input

A font is untrusted input. Every read goes through a `Slice` that checks the offset against the
end of its window, so a bad offset or length is a `FontError` naming the table. There is no
`partial` definition and no operation that can panic (`lake test` checks the sources for
`!`-indexing, `get!` and the like). Work is bounded by the input:

- a charstring runs at most 20,000 operators, nests subroutines at most 10 deep and keeps at
  most 48 arguments;
- composite glyphs nest at most 8 deep, with at most 65,536 points and components together;
- layout subtables are read once each, and the entries read from `GSUB` and `GPOS` may not exceed
  eight per byte of the table (shared sets cannot multiply a small table into a vast one);
- a CID-keyed font has at most 256 Font DICTs; `cmap` format 12 keeps its groups as ranges.

## How it is checked

`lake test` (`LeAnTeXTest/Font.lean`):

- **fontTools.** `tools/font-reference.py` records what fontTools reads from each font into
  `fixtures/font/<font>.jsonl`: header metrics, names, `OS/2` and `post` fields, `MATH`
  constants, the whole character map, and per glyph the advance, left side bearing, control box,
  tight box and an FNV-1a hash of the outline. The test reads the same file (matched by size
  and hash) and compares everything: all 4802 glyphs of Latin Modern Math and every glyph of the
  fourteen Latin Modern text fonts the box fixtures use agree. The Latin Modern fonts are found
  in TeX Live (`LEANTEX_FONT_DIRS` overrides the search) and skipped when absent; two small
  fonts made by `tools/test-fonts.py` (one CFF font exercising every path operator, subroutines,
  hint masks and flex, with `liga` and pair and class kerning; one TrueType font with implied
  points, a scaled composite and a `kern` table) are committed and always checked.
- **TeX.** Every box of `fixtures/text/boxes.jsonl` (`docs/text-reference.md`) is rebuilt from
  the reader's character map, ligatures, advances and kerning, scaled as TeX scales them, and
  must give TeX's glyphs, widths and kerns (cases with TeX's own ligature characters `` ` ``,
  `'`, `"`, `-`, or characters the font lacks, are skipped and counted).
- **Fuzzing.** Mutated copies of the fonts (bytes changed, header fields set to extreme values,
  files cut short) must each read to a font or a `FontError`, and every query on a font read
  must return.
