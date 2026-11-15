# Formula boxes against TeX

Written by `lake exe leantex-test --update-doc` (`LeAnTeXTest/MathBoxChecks.lean`): the box the math layout gives each formula of `corpus/math-box/formulas.tsv` at ten points (width, height and depth, as the document layer scales it) against TeX's (`fixtures/math-box/boxes.tsv`, `tools/math-box-reference.sh`). A formula counts in a column when all three dimensions are within that much of TeX's; the last column is the largest difference in sp.

| Construct (style) | Formulas | Same to the sp | Within 1 sp | Within 0.1 pt | Within 1 pt | Largest difference |
|---|---|---|---|---|---|---|
| ord (text) | 25 | 0 | 2 | 25 | 25 | 725 |
| ord (display) | 25 | 0 | 2 | 25 | 25 | 725 |
| bin-rel (text) | 20 | 0 | 0 | 19 | 20 | 52721 |
| bin-rel (display) | 20 | 0 | 0 | 19 | 20 | 52721 |
| sup (text) | 15 | 0 | 0 | 0 | 9 | 146397 |
| sup (display) | 15 | 0 | 0 | 0 | 9 | 146397 |
| sub (text) | 10 | 0 | 0 | 0 | 8 | 132956 |
| sub (display) | 10 | 0 | 0 | 0 | 8 | 132956 |
| subsup (text) | 8 | 0 | 0 | 0 | 5 | 125675 |
| subsup (display) | 8 | 0 | 0 | 0 | 5 | 125675 |
| frac (text) | 15 | 0 | 0 | 1 | 6 | 395918 |
| frac (display) | 15 | 0 | 0 | 8 | 13 | 173863 |
| sum-int (text) | 15 | 0 | 0 | 3 | 7 | 174918 |
| sum-int (display) | 15 | 0 | 0 | 3 | 12 | 174698 |
| limits-op (text) | 15 | 0 | 0 | 4 | 11 | 224592 |
| limits-op (display) | 15 | 0 | 0 | 4 | 13 | 224592 |
| sqrt (text) | 8 | 0 | 0 | 3 | 7 | 91927 |
| sqrt (display) | 8 | 0 | 0 | 4 | 7 | 91927 |
| delim (text) | 15 | 0 | 0 | 11 | 14 | 132596 |
| delim (display) | 15 | 0 | 0 | 12 | 15 | 48830 |
| accent (text) | 10 | 0 | 0 | 9 | 10 | 12740 |
| accent (display) | 10 | 0 | 0 | 9 | 10 | 12740 |
| font (text) | 10 | 0 | 0 | 7 | 9 | 108134 |
| font (display) | 10 | 0 | 0 | 7 | 9 | 108134 |
| text-in-math (text) | 4 | 0 | 0 | 0 | 2 | rejected |
| text-in-math (display) | 4 | 0 | 0 | 0 | 2 | rejected |
| spacing (text) | 8 | 0 | 0 | 7 | 8 | 54235 |
| spacing (display) | 8 | 0 | 0 | 7 | 8 | 54235 |
| matrix (text) | 6 | 0 | 0 | 4 | 5 | 81014 |
| matrix (display) | 6 | 0 | 0 | 6 | 6 | 749 |
| mixed (text) | 25 | 0 | 0 | 8 | 14 | 263040 |
| mixed (display) | 25 | 0 | 0 | 9 | 17 | 364704 |
| **all** | 418 | 0 | 4 | 214 | 339 | rejected |
