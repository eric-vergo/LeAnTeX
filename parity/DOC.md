# Documents against LuaLaTeX

Written by `lake exe leantex-test --update-doc` (`LeAnTeXTest/DocChecks.lean`). A document agrees when its pages, every line's position (to the sp) and text, its labels, its table of contents and its counter steps are LuaLaTeX's, with these exemptions, counted in the table: a line with a formula is compared by position only (our text of it is its source, LuaLaTeX's the glyphs of the math fonts); a private-use character of either text is replaced by what the fonts' own ligature and small-capital tables say it stands for, and one they do not know matches one character (counted in the driver's line); the bibliography's keys are not compared (the recorder reads `\newlabel` only); the counter steps are compared for the sectioning, equation, float, footnote and list counters; the contents (levels 1 to 3: number, title, page) only in documents that print them. A page break is at LuaLaTeX's place when the page after it begins with LuaLaTeX's line: with its text, or for a line with a formula at its position. The reference documents were written to cover the features and the layer was tuned on them; the fresh and the held-out documents were written by someone who had not read this library. The first held-out set's first recorded score with the TeX-rule layout was 8 of 20 documents (commit `e04b63b`, with the comparison of that commit); the set existed before the TeX-rule layout was developed, four of its fixtures were re-recorded after a fix to the recorder before that score, and a defect it showed was fixed after it, so it is no untouched test. The second held-out set was written blind after that and first recorded at `648d738`; its sources and fixtures have not changed since.

| Set | Documents agreeing | Lines at the same place | Of them with a formula (position only) | Within 1 pt | Page breaks | Of them by position only |
|---|---|---|---|---|---|---|
| reference documents (tuned on) | 87 / 87 | 1810 / 1810 | 88 | 1810 | 20 / 20 | 0 |
| fresh documents (written blind) | 7 / 10 | 367 / 398 | 56 | 367 | 10 / 10 | 2 |
| first held-out set (written blind; 8 / 20 when first recorded) | 9 / 20 | 398 / 469 | 163 | 405 | 3 / 3 | 0 |
| **second held-out set (written blind, not tuned to)** | 5 / 10 | 374 / 400 | 157 | 375 | 10 / 10 | 5 |

Formulas the TeX-rule layout refused although the metric files were there, set by the KaTeX-compatible layout instead: 3 (held-13@983, held-20@624, blind-06@1780).

| Feature | Documents agreeing | Lines at the same place | Of them with a formula (position only) | Within 1 pt | Page breaks | Of them by position only |
|---|---|---|---|---|---|---|
| structure | 17 / 17 | 457 / 457 | 1 | 457 | 5 / 5 | 0 |
| environments | 16 / 16 | 167 / 167 | 48 | 167 | 0 / 0 | 0 |
| combined | 22 / 22 | 337 / 337 | 38 | 337 | 1 / 1 | 0 |
| bibliographies | 4 / 4 | 77 / 77 | 0 | 77 | 1 / 1 | 0 |
| lists | 5 / 5 | 42 / 42 | 1 | 42 | 0 / 0 | 0 |
| floats | 8 / 8 | 136 / 136 | 0 | 136 | 5 / 5 | 0 |
| footnotes | 3 / 3 | 205 / 205 | 0 | 205 | 3 / 3 | 0 |
| fresh (written without reading LeAnTeX) | 7 / 10 | 367 / 398 | 56 | 367 | 10 / 10 | 2 |
| page breaking | 7 / 7 | 312 / 312 | 0 | 312 | 5 / 5 | 0 |
| tables | 5 / 5 | 77 / 77 | 0 | 77 | 0 / 0 | 0 |

## Per document

| Document | Agrees | Lines same | First difference |
|---|---|---|---|
| abstract | yes | 15 / 15 |  |
| accents | yes | 3 / 3 |  |
| align | yes | 15 / 15 |  |
| align-pairs | yes | 23 / 23 |  |
| align-rows | yes | 23 / 23 |  |
| article | yes | 52 / 52 |  |
| bib-labels | yes | 13 / 13 |  |
| bib-long | yes | 40 / 40 |  |
| bib-numbered | yes | 16 / 16 |  |
| bib-space | yes | 8 / 8 |  |
| center | yes | 7 / 7 |  |
| counters | yes | 4 / 4 |  |
| description | yes | 5 / 5 |  |
| description-label | yes | 7 / 7 |  |
| description-long | yes | 12 / 12 |  |
| emph | yes | 3 / 3 |  |
| enumerate | yes | 8 / 8 |  |
| env-item-space | yes | 9 / 9 |  |
| equation | yes | 13 / 13 |  |
| float-bottom | yes | 14 / 14 |  |
| float-default | yes | 50 / 50 |  |
| float-deferred | yes | 5 / 5 |  |
| float-here | yes | 17 / 17 |  |
| float-here-vertical | yes | 8 / 8 |  |
| float-page | yes | 19 / 19 |  |
| float-pagedepth | yes | 8 / 8 |  |
| float-top | yes | 15 / 15 |  |
| flush-declarations | yes | 11 / 11 |  |
| footnote-club | yes | 8 / 8 |  |
| footnotes | yes | 14 / 14 |  |
| footnotes-pages | yes | 67 / 67 |  |
| footnotes-split | yes | 124 / 124 |  |
| fresh-01 | yes | 43 / 43 |  |
| fresh-02 | no | 10 / 37 | page 1: 27 lines, LuaLaTeX 30 |
| fresh-03 | yes | 43 / 43 |  |
| fresh-04 | no | 38 / 40 | page 2 line 7: (9226367, 17081490) '[Knu84] Donald E. Knuth, The Art of Comp', LuaLaTeX (9226367, 17081490) '[Knu84] Donald E. Knuth, The Art of Comp' (dy 0) |
| fresh-05 | yes | 32 / 32 |  |
| fresh-06 | yes | 44 / 44 |  |
| fresh-07 | yes | 46 / 46 |  |
| fresh-08 | yes | 37 / 37 |  |
| fresh-09 | no | 32 / 34 | page 1 line 9: (10069277, 24137766) 'To read slowly is not to read less; it i', LuaLaTeX (10069277, 24137766) 'To read slowly is not to read less; it i' (dy 0) |
| fresh-10 | yes | 42 / 42 |  |
| hyphen-hard | yes | 23 / 23 |  |
| hyphen-strut | yes | 6 / 6 |  |
| image-scale | yes | 3 / 3 |  |
| inline-limits | yes | 9 / 9 |  |
| itemize | yes | 10 / 10 |  |
| label-heading | yes | 5 / 5 |  |
| lengths | yes | 18 / 18 |  |
| linebreak | yes | 18 / 18 |  |
| lists-deep | yes | 24 / 24 |  |
| lists-mixed | yes | 26 / 26 |  |
| lists-sizes | yes | 13 / 13 |  |
| math-12pt | yes | 5 / 5 |  |
| math-after-display | yes | 11 / 11 |  |
| math-between-displays | yes | 11 / 11 |  |
| math-display | yes | 14 / 14 |  |
| math-inline-break | yes | 8 / 8 |  |
| math-sizes | yes | 6 / 6 |  |
| math-tags | yes | 18 / 18 |  |
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
| quote | yes | 23 / 23 |  |
| quote-nested | yes | 16 / 16 |  |
| refs | yes | 31 / 31 |  |
| rules | yes | 3 / 3 |  |
| sections-basic | yes | 15 / 15 |  |
| sections-levels | yes | 14 / 14 |  |
| sections-numbered | yes | 25 / 25 |  |
| sections-pages | yes | 86 / 86 |  |
| skips | yes | 20 / 20 |  |
| tabular | yes | 13 / 13 |  |
| tabular-mixed | yes | 21 / 21 |  |
| tabular-multi | yes | 10 / 10 |  |
| tabular-para | yes | 23 / 23 |  |
| tabular-sloppy | yes | 10 / 10 |  |
| theorem | yes | 6 / 6 |  |
| theorem-amsthm | yes | 6 / 6 |  |
| thispagestyle | yes | 46 / 46 |  |
| title | yes | 15 / 15 |  |
| title-thanks | yes | 8 / 8 |  |
| toc | yes | 19 / 19 |  |
| toc-none | yes | 13 / 13 |  |
| toc-pages | yes | 91 / 91 |  |
| verbatim | yes | 5 / 5 |  |
| verbatim-lines | yes | 7 / 7 |  |
| verbatim-mixed | yes | 11 / 11 |  |
| widows | yes | 61 / 61 |  |
| held-01 | no | 27 / 32 | page 1: 28 lines, LuaLaTeX 27 |
| held-02 | no | 19 / 21 | page 1 line 14: (6767902, 28289636) 'Remark. Proposition 1.1 is Lagrange’s th', LuaLaTeX (6767902, 28289636) 'Remark. Proposition 1.1 is Lagrange’s th' (dy 0) |
| held-03 | yes | 36 / 36 |  |
| held-04 | no | 4 / 18 | page 1 line 4: (7750942, 16981233) '1 Basic notions', LuaLaTeX (7750942, 18057661) '1 Basic notions' (dy -1076428) |
| held-05 | yes | 26 / 26 |  |
| held-06 | no | 30 / 31 | page 1 line 16: (17073293, 39787706) '$ \sum _{p\equiv a\ (\mathrm {mod}\ q)}\', LuaLaTeX (17053632, 39787706) 'X p\u{11}a (mod q) 1 p = 1:' (dy 0) |
| held-07 | yes | 28 / 28 |  |
| held-08 | yes | 45 / 45 |  |
| held-09 | yes | 18 / 18 |  |
| held-10 | yes | 18 / 18 |  |
| held-11 | yes | 15 / 15 |  |
| held-12 | no | 14 / 15 | page 1 line 13: (14042830, 26386349) '$ \det (A-\lambda I)=(2-\lambda )^2-1=\l', LuaLaTeX (14042829, 26386349) 'det(A \u{0} \u{15}I) = (2 \u{0} \u{15})2 \u{0} 1 = \u{15}2 \u{0} 4\u{15} + 3' (dy 0) |
| held-13 | no | 21 / 23 | page 1 line 3: (7750942, 15541533) 'January 1, 2000', LuaLaTeX (7750942, 15541533) 'November 15, 2026' (dy 0) |
| held-14 | no | 5 / 17 | page 1 line 5: (6767902, 14098472) 'Biânchi, Hurwitz, and ˘Sevchenko.', LuaLaTeX (6767902, 13838948) 'Biânchi, Hurwitz, and S̆evchenko.' (dy 259524) |
| held-15 | no | 19 / 23 | page 1 line 6: (8275230, 16243948) '1.1 Cauchy–Schwarz', LuaLaTeX (8275230, 16243948) '1.1 Cauchy--Schwarz' (dy 0) |
| held-16 | yes | 27 / 27 |  |
| held-17 | no | 4 / 21 | page 1 line 4: (8275230, 16778524) 'Abstract', LuaLaTeX (8275230, 17564956) 'Abstract' (dy -786432) |
| held-18 | no | 13 / 15 | page 2 line 7: (7292190, 23826064) 'Convergence tests. The ratio test says $', LuaLaTeX (7292190, 24186507) 'Convergence tests. The ratio test says P' (dy -360443) |
| held-19 | yes | 21 / 21 |  |
| held-20 | no | 8 / 19 | page 1 line 9: (9782558, 14810018) 'Product', LuaLaTeX (9782558, 15072162) 'Product' (dy -262144) |
| blind-01 | yes | 35 / 35 |  |
| blind-02 | no | 36 / 46 | page 1: 28 lines, LuaLaTeX 30 |
| blind-03 | no | 32 / 33 | page 2: 8 lines, LuaLaTeX 7 |
| blind-04 | yes | 38 / 38 |  |
| blind-05 | no | 24 / 33 | page 1: 22 lines, LuaLaTeX 21 |
| blind-06 | yes | 51 / 51 |  |
| blind-07 | yes | 35 / 35 |  |
| blind-08 | yes | 42 / 42 |  |
| blind-09 | no | 40 / 41 | page 1 line 19: (14423349, 38149082) '$ \inner {x-p}{y-p}\le 0\quad \text {for', LuaLaTeX (14374551, 38149082) 'hx \u{0} p; y \u{0} pi \u{14} 0 for all y 2 C:' (dy 0) |
| blind-10 | no | 41 / 46 | page 1: 30 lines, LuaLaTeX 31 |
