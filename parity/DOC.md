# Documents against LuaLaTeX

Written by `lake exe leantex-test --update-doc` (`LeAnTeXTest/DocChecks.lean`). A document agrees when its pages, every line's position (to the sp) and text, its labels, its table of contents and its counter steps are LuaLaTeX's.

| Feature | Documents agreeing | Lines at the same place | Within 1 pt |
|---|---|---|---|
| structure | 8 / 15 | 332 / 419 | 332 |
| environments | 2 / 11 | 30 / 87 | 30 |
| combined | 0 / 2 | 0 / 82 | 0 |
| lists | 3 / 3 | 23 / 23 | 23 |
| floats | 0 / 5 | 0 / 115 | 0 |
| footnotes | 0 / 2 | 0 / 81 | 0 |
| page breaking | 6 / 7 | 296 / 312 | 296 |
| tables | 0 / 2 | 0 / 23 | 0 |

## Per document

| Document | Agrees | Lines same | First difference |
|---|---|---|---|
| abstract | no | 0 / 15 | error: Undefined control sequence \title at 41 |
| accents | no | 0 / 3 | error: Undefined control sequence \' at 44 |
| align | no | 0 / 15 | error: Environment align undefined at 78 |
| article | no | 0 / 52 | error: Undefined control sequence \newtheorem at 83 |
| center | yes | 7 / 7 |  |
| counters | yes | 4 / 4 |  |
| description | yes | 5 / 5 |  |
| emph | yes | 3 / 3 |  |
| enumerate | yes | 8 / 8 |  |
| equation | no | 0 / 13 | error: Environment equation undefined at 399 |
| float-bottom | no | 0 / 14 | error: Environment figure undefined at 378 |
| float-default | no | 0 / 50 | error: Environment figure undefined at 958 |
| float-here | no | 0 / 17 | error: Environment figure undefined at 378 |
| float-page | no | 0 / 19 | error: Environment figure undefined at 378 |
| float-top | no | 0 / 15 | error: Environment figure undefined at 378 |
| footnotes | no | 0 / 14 | error: Undefined control sequence \footnote at 58 |
| footnotes-pages | no | 0 / 67 | error: Undefined control sequence \footnote at 377 |
| itemize | yes | 10 / 10 |  |
| lengths | no | 0 / 18 | error: Undefined control sequence \addtolength at 706 |
| mixed | no | 0 / 30 | error: Undefined control sequence \footnote at 448 |
| newenvironment | no | 0 / 3 | error: Undefined control sequence \newenvironment at 41 |
| newpage | yes | 21 / 21 |  |
| nopagebreak | yes | 47 / 47 |  |
| options-11pt | yes | 16 / 16 |  |
| options-12pt | yes | 16 / 16 |  |
| options-12pt-a4 | yes | 37 / 37 |  |
| options-a4 | yes | 34 / 34 |  |
| pages-long | yes | 71 / 71 |  |
| pagestyle-empty | yes | 46 / 46 |  |
| quote | no | 20 / 23 | page 1 line 14: (10437918, 20661534) 'Vertical space between paragraphs and ar', LuaLaTeX (10437918, 20661534) 'Vertical space between paragraphs and ar' (dy 0) |
| refs | no | 0 / 31 | error: Environment equation undefined at 170 |
| rules | no | 0 / 3 | error: Undefined control sequence \rule at 48 |
| sections-basic | yes | 15 / 15 |  |
| sections-levels | yes | 14 / 14 |  |
| sections-pages | yes | 86 / 86 |  |
| skips | no | 4 / 20 | page 1: 22 lines, LuaLaTeX 20 |
| tabular | no | 0 / 13 | error: Environment tabular undefined at 41 |
| tabular-multi | no | 0 / 10 | error: Environment tabular undefined at 56 |
| theorem | no | 0 / 6 | error: Undefined control sequence \newtheorem at 41 |
| theorem-amsthm | no | 0 / 6 | error: Undefined control sequence \newtheorem at 61 |
| thispagestyle | yes | 46 / 46 |  |
| title | no | 0 / 15 | error: Undefined control sequence \title at 41 |
| title-thanks | no | 0 / 8 | error: Undefined control sequence \title at 41 |
| toc | no | 19 / 19 | contents: 5 entries, LuaLaTeX 0 |
| toc-pages | no | 91 / 91 | contents: 5 entries, LuaLaTeX 0 |
| verbatim | no | 0 / 5 | error: Undefined control sequence \verb at 48 |
| widows | yes | 61 / 61 |  |
