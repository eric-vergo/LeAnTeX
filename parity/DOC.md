# Documents against LuaLaTeX

Written by `lake exe leantex-test --update-doc` (`LeAnTeXTest/DocChecks.lean`). A document agrees when its pages, every line's position (to the sp) and text, its labels, its table of contents and its counter steps are LuaLaTeX's.

| Feature | Documents agreeing | Lines at the same place | Within 1 pt |
|---|---|---|---|
| structure | 15 / 17 | 456 / 457 | 457 |
| environments | 9 / 13 | 87 / 114 | 92 |
| combined | 5 / 8 | 158 / 209 | 171 |
| lists | 3 / 4 | 28 / 35 | 28 |
| floats | 4 / 5 | 114 / 115 | 115 |
| footnotes | 3 / 3 | 205 / 205 | 205 |
| page breaking | 7 / 7 | 312 / 312 | 312 |
| tables | 1 / 4 | 18 / 67 | 20 |

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
| description-long | no | 5 / 12 | page 1 line 2: (10437918, 10175774) 'a Short label, with a description that r', LuaLaTeX (10437918, 10175774) 'a Short label, with a description that r' (dy 0) |
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
| footnotes-split | yes | 124 / 124 |  |
| hyphen-hard | no | 0 / 23 | page 1: 20 lines, LuaLaTeX 23 |
| inline-limits | no | 1 / 9 | page 1 line 1: (8799518, 8870958) 'In a paragraph with a sum $\sum _{i=1}^n', LuaLaTeX (8799518, 8871248) 'In a paragraph with a sum Pni=1 xi and a' (dy -290) |
| itemize | yes | 10 / 10 |  |
| lengths | yes | 18 / 18 |  |
| linebreak | yes | 18 / 18 |  |
| lists-deep | yes | 24 / 24 |  |
| lists-mixed | yes | 26 / 26 |  |
| mixed | yes | 30 / 30 |  |
| mixed-floats | yes | 27 / 27 |  |
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
| quote-nested | yes | 16 / 16 |  |
| refs | no | 30 / 31 | page 1 line 3: (19353582, 11745347) '$ a = b $', LuaLaTeX (19353738, 11745347) 'a = b' (dy 0) |
| rules | yes | 3 / 3 |  |
| sections-basic | yes | 15 / 15 |  |
| sections-levels | yes | 14 / 14 |  |
| sections-numbered | yes | 25 / 25 |  |
| sections-pages | yes | 86 / 86 |  |
| skips | yes | 20 / 20 |  |
| tabular | yes | 13 / 13 |  |
| tabular-mixed | no | 1 / 21 | page 1 line 1: (12143130, 8786408) 'Name', LuaLaTeX (12034013, 8786408) 'Name' (dy 0) |
| tabular-multi | no | 0 / 10 | page 1: 9 lines, LuaLaTeX 10 |
| tabular-para | no | 4 / 23 | page 1: 22 lines, LuaLaTeX 23 |
| theorem | yes | 6 / 6 |  |
| theorem-amsthm | yes | 6 / 6 |  |
| thispagestyle | yes | 46 / 46 |  |
| title | yes | 15 / 15 |  |
| title-thanks | no | 8 / 8 | counter steps: 1, LuaLaTeX 1 |
| toc | yes | 19 / 19 |  |
| toc-none | yes | 13 / 13 |  |
| toc-pages | yes | 91 / 91 |  |
| verbatim | yes | 5 / 5 |  |
| verbatim-mixed | no | 6 / 11 | page 1 line 6: (8799518, 14894366) 'Lines of a paragraph are chosen together', LuaLaTeX (8799518, 14107934) 'Lines of a paragraph are chosen together' (dy 786432) |
| widows | yes | 61 / 61 |  |
