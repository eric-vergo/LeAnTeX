# The text-mode reference

LeAnTeX's text mode (line breaking, hyphenation, boxes of text) is tested against real TeX.
`tools/tex-reference.sh` typesets the cases of `corpus/text/*.jsonl` with LuaLaTeX and records
TeX's answers in `fixtures/text/*.jsonl`. The fixtures are committed, so `lake test` needs no
TeX; the script regenerates them.

```
python3 -I tools/text-corpus.py        # corpus/text/*.jsonl
bash tools/tex-reference.sh [name …]   # fixtures/text/*.jsonl (needs LuaLaTeX)
bash tools/tex-reference.sh --ncm paragraphs   # fixtures/text/paragraphs-ncm.jsonl
```

With `--ncm` the fonts are New Computer Modern from `fonts/newcomputermodern`, set as the
package's `fontspec` files set them (`tools/tex-reference/ncm.tex`), and the fixture's name
ends in `-ncm`. The recording run otherwise uses LaTeX's defaults (article class, Latin Modern in the TU encoding, US
English hyphenation with `\lefthyphenmin=2`, `\righthyphenmin=3`) except where a case sets a
parameter. TeX's caches go to a temporary directory the script removes. Every fixture starts with
a `meta` line naming the engine, luaotfload's version and the format.

## Units

Lengths are TeX's scaled points (sp, 2⁻¹⁶ pt). Glue orders are LuaTeX's: 0 (finite), 1 (`fi`,
LuaTeX's own, not used here), 2 (`fil`), 3 (`fill`), 4 (`filll`); LeAnTeX's own glue uses TeX's
numbering (0 finite, 1 `fil`, 2 `fill`, 3 `filll`) and the tests convert. A line's `glueSign`
is 0 (natural), 1 (stretched), 2 (shrunk); its `glueSet` is LuaTeX's glue ratio, a 32-bit float,
written with nine significant digits (enough to name it exactly).

## Items

A horizontal list is written as an array of items, in order:

| Item | Fields |
|---|---|
| `["g", char, gid, width, height, depth, font]` | a glyph: its code point (after ligatures, so `ﬁ` for a ligature), its glyph index in the font, its box, and the index of its font in the case's `fonts` |
| `["k", width, subtype]` | a kern; subtype 0 is a font kern, 1 an explicit one |
| `["glue", width, stretch, stretchOrder, shrink, shrinkOrder, subtype]` | glue; subtype 13 is an interword space, 15 `\parfillskip` |
| `["p", penalty]` | a penalty |
| `["d", penalty, pre, post, replace, subtype]` | a discretionary with its three item lists and LuaTeX's subtype: 2 after an explicit hyphen, 3 a hyphenation point of the patterns (TeX's first pass does not break at those) |
| `["box", width, height, depth, items]` | a box (the paragraph's indentation box) |
| `["rule", width, height, depth]` | a rule |

The items are what TeX's line breaker receives: after hyphenation, ligatures and kerning.

## Cases

**Paragraphs** (`paragraphs.jsonl`, kind `paragraph`). A case gives `hsize` (pt) and `text`, or
`parts`: strings and control items (`{"penalty": n}`, `{"glue": "10pt plus 5pt minus 3pt"}`,
`{"kern": pt}`, `{"hbox": "text"}`, `{"tie": true}`), and may set `font` (`regular`, `italic`,
`bold`, `bolditalic`, `sans`, `mono`, `caps`, `slanted`), `size` (pt), the integer parameters
`tolerance`, `pretolerance`, `looseness`, `linepenalty`, `hyphenpenalty`, `exhyphenpenalty`,
`adjdemerits`, `doublehyphendemerits`, `finalhyphendemerits`, `hangafter`, the lengths
`parindent`, `emergencystretch` and `hangindent` (pt), the glue `leftskip`, `rightskip`,
`parfillskip`, and `parshape` (a list of `[indent, length]` in pt). The answer:

- `fonts`: the font files and sizes (sp) the items refer to;
- `params`: every parameter in force when the paragraph was broken;
- `items`: the list the line breaker received;
- `lines`: for each line, `break` (the index of the item TeX broke at; the last line's is the
  last item, `\parfillskip`), `width` (the line's length: `\hsize`, or less under hanging
  indentation or `\parshape`), `shift` (its indentation), `natural` (the line's natural width),
  and `glueSign`, `glueOrder`, `glueSet`;
- `demerits` (the total of the chosen breaks), `prevgraf` (the number of lines), and the
  paragraph's `height` and `depth`.

A line ends at its break item and the next line starts after it, without the glue, kerns and
penalties TeX discards after a break; a broken discretionary ends its line with `pre` and
starts the next with `post`.

**Words** (`words.jsonl`, kind `word`). The answer's `hyphenated` is the word with `-` at each
point TeX's patterns and exceptions allow, under the hyphen minima of the `meta` line.

**Boxes** (`boxes.jsonl`, kind `hbox`). A single line set as `\hbox`: its `width`, `height`,
`depth` and `items`.

## Sources

The paragraphs are public-domain prose (the Grimms' *Frog King* in Margaret Hunt's
translation, the opening of the Declaration of Independence, the Gettysburg Address, Melville,
Darwin) and text written for this corpus. The words are a fixed sample of Webster's Second
International word list (1934, copyright lapsed) and a list chosen for hyphenation.

## Checks

`lake test` (`LeAnTeXTest/TextFixtures.lean`) keeps every fixture coherent with its corpus: one
answer per case in order, breaks ascending at breakable items and ending at the last item, line
widths equal to `\hsize`, hyphenated words equal to their words, box widths equal to the sum of
their items. The boxes also test the font reader (`docs/opentype.md`).

The fixtures are the reference for the text layer (`docs/text.md`): the hyphenator must give
every word's points, the line breaker every paragraph's breaks, demerits and lines from the
recorded item list, and the front end the recorded item list itself from the corpus text.
