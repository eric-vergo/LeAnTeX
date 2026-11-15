# Documents against LuaLaTeX

Written by `lake exe leantex-test --update-doc` (`LeAnTeXTest/DocChecks.lean`). A document agrees when its pages, every line's position (to the sp) and text, its labels, its table of contents and its counter steps are LuaLaTeX's.

| Feature | Documents agreeing | Lines at the same place | Within 1 pt |
|---|---|---|---|
| structure | 13 / 15 | 418 / 419 | 419 |
| environments | 8 / 11 | 65 / 87 | 70 |
| combined | 1 / 2 | 62 / 82 | 73 |
| lists | 3 / 3 | 23 / 23 | 23 |
| floats | 4 / 5 | 114 / 115 | 115 |
| footnotes | 2 / 2 | 81 / 81 | 81 |
| page breaking | 7 / 7 | 312 / 312 | 312 |
| tables | 1 / 2 | 13 / 23 | 13 |

## Per document

| Document | Agrees | Lines same | First difference |
|---|---|---|---|
| abstract | yes | 15 / 15 |  |
| accents | yes | 3 / 3 |  |
| align | no | 1 / 15 | page 1: 8 lines, LuaLaTeX 15 |
| article | no | 32 / 52 | page 2 line 5: (8799518, 12010782) 'Table 1 and Figure 1 on page 2; Theorem ', LuaLaTeX (17618696, 12722500) 'Step' (dy -711718) |
| center | yes | 7 / 7 |  |
| counters | yes | 4 / 4 |  |
| description | yes | 5 / 5 |  |
| emph | yes | 3 / 3 |  |
| enumerate | yes | 8 / 8 |  |
| equation | no | 8 / 13 | page 1 line 6: (18347177, 12797214) '$ x^2 + y^2 = z^2 $', LuaLaTeX (18299587, 12797214) 'x2 + y2 = z2' (dy 0) |
| float-bottom | no | 13 / 14 | page 1 line 13: (16494428, 44117141) 'Figure 1: At the bottom.', LuaLaTeX (16494428, 44117157) 'Figure 1: At the bottom.' (dy -16) |
| float-default | yes | 50 / 50 |  |
| float-here | yes | 17 / 17 |  |
| float-page | yes | 19 / 19 |  |
| float-top | yes | 15 / 15 |  |
| footnotes | yes | 14 / 14 |  |
| footnotes-pages | yes | 67 / 67 |  |
| itemize | yes | 10 / 10 |  |
| lengths | yes | 18 / 18 |  |
| mixed | yes | 30 / 30 |  |
| newenvironment | yes | 3 / 3 |  |
| newpage | yes | 21 / 21 |  |
| nopagebreak | yes | 47 / 47 |  |
| options-11pt | yes | 16 / 16 |  |
| options-12pt | yes | 16 / 16 |  |
| options-12pt-a4 | yes | 37 / 37 |  |
| options-a4 | yes | 34 / 34 |  |
| pages-long | yes | 71 / 71 |  |
| pagestyle-empty | yes | 46 / 46 |  |
| quote | no | 20 / 23 | page 1 line 14: (10437918, 20661534) 'Vertical space between paragraphs and ar', LuaLaTeX (10437918, 20661534) 'Vertical space between paragraphs and ar' (dy 0) |
| refs | no | 30 / 31 | page 1 line 3: (19353582, 11745347) '$ a = b $', LuaLaTeX (19353738, 11745347) 'a = b' (dy 0) |
| rules | yes | 3 / 3 |  |
| sections-basic | yes | 15 / 15 |  |
| sections-levels | yes | 14 / 14 |  |
| sections-pages | yes | 86 / 86 |  |
| skips | yes | 20 / 20 |  |
| tabular | yes | 13 / 13 |  |
| tabular-multi | no | 0 / 10 | page 1: 9 lines, LuaLaTeX 10 |
| theorem | yes | 6 / 6 |  |
| theorem-amsthm | yes | 6 / 6 |  |
| thispagestyle | yes | 46 / 46 |  |
| title | yes | 15 / 15 |  |
| title-thanks | no | 8 / 8 | counter steps: 1, LuaLaTeX 1 |
| toc | yes | 19 / 19 |  |
| toc-pages | yes | 91 / 91 |  |
| verbatim | yes | 5 / 5 |  |
| widows | yes | 61 / 61 |  |
