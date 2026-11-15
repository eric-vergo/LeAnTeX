# Formula boxes against TeX

Written by `lake exe leantex-test --update-doc` (`LeAnTeXTest/MathBoxChecks.lean`): every formula of `corpus/math-box/formulas.tsv` in text and display style, in the `article` class at 10, 11 and 12 points, laid out by the TeX-rule layout (`docs/math-boxes.md`) and compared with the box LuaLaTeX made for it (`fixtures/math-box/boxes-*pt.jsonl`, `tools/math-box-reference.sh`). A box counts in a column when its width, height and depth are all within that much of TeX's; *lists same* counts the boxes whose whole node list is TeX's (every node's kind, font, character and dimensions); a formula the TeX-rule layout refuses is laid out by the KaTeX-compatible layout and counted only in the columns of dimensions. The last column is the KaTeX-compatible layout's own boxes the same to the sp.

| Construct (style) | Boxes | TeX-rule layout | Same to the sp | Within 0.1 pt | Within 1 pt | Lists same | KaTeX layout same |
|---|---|---|---|---|---|---|---|
| ord (text) | 75 | 75 | 75 | 75 | 75 | 75 | 0 |
| ord (display) | 75 | 75 | 75 | 75 | 75 | 75 | 0 |
| bin-rel (text) | 60 | 60 | 60 | 60 | 60 | 60 | 0 |
| bin-rel (display) | 60 | 60 | 60 | 60 | 60 | 60 | 0 |
| sup (text) | 45 | 45 | 45 | 45 | 45 | 45 | 0 |
| sup (display) | 45 | 45 | 45 | 45 | 45 | 45 | 0 |
| sub (text) | 30 | 30 | 30 | 30 | 30 | 30 | 0 |
| sub (display) | 30 | 30 | 30 | 30 | 30 | 30 | 0 |
| subsup (text) | 24 | 24 | 24 | 24 | 24 | 24 | 0 |
| subsup (display) | 24 | 24 | 24 | 24 | 24 | 24 | 0 |
| frac (text) | 45 | 45 | 45 | 45 | 45 | 42 | 0 |
| frac (display) | 45 | 45 | 45 | 45 | 45 | 42 | 0 |
| sum-int (text) | 45 | 45 | 45 | 45 | 45 | 45 | 0 |
| sum-int (display) | 45 | 45 | 45 | 45 | 45 | 45 | 0 |
| limits-op (text) | 45 | 45 | 45 | 45 | 45 | 45 | 0 |
| limits-op (display) | 45 | 45 | 45 | 45 | 45 | 45 | 0 |
| sqrt (text) | 24 | 24 | 24 | 24 | 24 | 24 | 0 |
| sqrt (display) | 24 | 24 | 24 | 24 | 24 | 24 | 0 |
| delim (text) | 45 | 45 | 45 | 45 | 45 | 39 | 0 |
| delim (display) | 45 | 45 | 45 | 45 | 45 | 39 | 0 |
| accent (text) | 30 | 30 | 30 | 30 | 30 | 30 | 0 |
| accent (display) | 30 | 30 | 30 | 30 | 30 | 30 | 0 |
| font (text) | 30 | 30 | 30 | 30 | 30 | 30 | 0 |
| font (display) | 30 | 30 | 30 | 30 | 30 | 30 | 0 |
| text-in-math (text) | 12 | 12 | 12 | 12 | 12 | 12 | 0 |
| text-in-math (display) | 12 | 12 | 12 | 12 | 12 | 12 | 0 |
| spacing (text) | 24 | 24 | 24 | 24 | 24 | 24 | 0 |
| spacing (display) | 24 | 24 | 24 | 24 | 24 | 24 | 0 |
| matrix (text) | 18 | 18 | 18 | 18 | 18 | 0 | 0 |
| matrix (display) | 18 | 18 | 18 | 18 | 18 | 0 | 0 |
| mixed (text) | 75 | 75 | 75 | 75 | 75 | 69 | 0 |
| mixed (display) | 75 | 75 | 75 | 75 | 75 | 69 | 0 |
| gen-spacing (text) | 342 | 342 | 342 | 342 | 342 | 342 | 0 |
| gen-spacing (display) | 342 | 342 | 342 | 342 | 342 | 342 | 0 |
| gen-scripts (text) | 495 | 495 | 492 | 495 | 495 | 486 | 0 |
| gen-scripts (display) | 495 | 495 | 492 | 495 | 495 | 486 | 0 |
| gen-frac (text) | 225 | 225 | 222 | 222 | 222 | 165 | 0 |
| gen-frac (display) | 225 | 225 | 222 | 222 | 222 | 165 | 0 |
| gen-radical (text) | 186 | 186 | 186 | 186 | 186 | 180 | 0 |
| gen-radical (display) | 186 | 186 | 186 | 186 | 186 | 180 | 0 |
| gen-op (text) | 933 | 918 | 918 | 918 | 919 | 909 | 0 |
| gen-op (display) | 933 | 918 | 918 | 918 | 919 | 909 | 0 |
| gen-accent (text) | 786 | 684 | 684 | 739 | 755 | 636 | 0 |
| gen-accent (display) | 786 | 684 | 684 | 739 | 755 | 636 | 0 |
| gen-delim (text) | 1230 | 1230 | 1230 | 1230 | 1230 | 1095 | 1 |
| gen-delim (display) | 1230 | 1230 | 1230 | 1230 | 1230 | 1095 | 1 |
| gen-font (text) | 339 | 327 | 327 | 335 | 339 | 327 | 0 |
| gen-font (display) | 339 | 327 | 327 | 335 | 339 | 327 | 0 |
| gen-misc (text) | 978 | 819 | 821 | 835 | 882 | 672 | 4 |
| gen-misc (display) | 978 | 819 | 821 | 841 | 879 | 672 | 4 |
| doc (text) | 222 | 222 | 222 | 222 | 222 | 222 | 0 |
| doc (display) | 222 | 222 | 222 | 222 | 222 | 222 | 0 |
| **all** | 12726 | 12150 | 12142 | 12308 | 12435 | 11256 | 10 |

## Boxes that are not TeX's

The formula, style and size, the largest difference in sp, and the first node that differs (path of indices into the box's list) or why the TeX-rule layout refused it.

| Formula | Style | Size | Difference | First difference |
|---|---|---|---|---|
| `\frac{a}{\frac{b}{c}}` | text | 10 | 0 | 1.0.1.4.0: hbox 78643 0 0 shift -114688 (0), TeX hbox 370090 403671 157909 shift 0 (3) |
| `\frac{a}{\frac{b}{c}}` | display | 10 | 0 | 1.0.1.4.0: hbox 78643 0 0 shift -163840 (0), TeX hbox 391495 576613 225995 shift 0 (3) |
| `\bigl(x\bigr)` | text | 10 | 0 | 1.1: hbox 300375 26213 760226 shift -530846 (1), TeX hbox 300375 557059 229380 shift 0 (3) |
| `\bigl(x\bigr)` | display | 10 | 0 | 1.1: hbox 300375 26213 760226 shift -530846 (1), TeX hbox 300375 557059 229380 shift 0 (3) |
| `\Bigl(x\Bigr)` | text | 10 | 0 | 1.1: hbox 391396 26213 1153446 shift -727456 (1), TeX hbox 391396 753669 425990 shift 0 (3) |
| `\Bigl(x\Bigr)` | display | 10 | 0 | 1.1: hbox 391396 26213 1153446 shift -727456 (1), TeX hbox 391396 753669 425990 shift 0 (3) |
| `\begin{pmatrix}a&b\\c&d\end{pmatrix}` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\begin{pmatrix}a&b\\c&d\end{pmatrix}` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\begin{bmatrix}1&0\\0&1\end{bmatrix}` | text | 10 | 0 | 1.2.0.3: hbox 983041 422343 0 shift 0 (7), TeX hbox 983041 550500 235932 shift 0 (10) |
| `\begin{bmatrix}1&0\\0&1\end{bmatrix}` | display | 10 | 0 | 1.2.0.3: hbox 983041 422343 0 shift 0 (7), TeX hbox 983041 550500 235932 shift 0 (10) |
| `\begin{vmatrix}a&b\\c&d\end{vmatrix}` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\begin{vmatrix}a&b\\c&d\end{vmatrix}` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\binom{n}{k}` | text | 10 | 0 | 1.0: hbox 924716 557059 229380 shift 0 (3), TeX hbox 300375 557059 229380 shift 0 (1) |
| `\binom{n}{k}` | display | 10 | 0 | 1.0: hbox 1358210 950279 622600 shift 0 (3), TeX hbox 482420 950279 622600 shift 0 (1) |
| `\binom{2n}{n}` | text | 10 | 0 | 1.0: hbox 1185951 586443 229380 shift 0 (3), TeX hbox 300375 557059 229380 shift 0 (1) |
| `\binom{2n}{n}` | display | 10 | 0 | 1.0: hbox 1685891 950279 622600 shift 0 (3), TeX hbox 482420 950279 622600 shift 0 (1) |
| `\begin{cases}1 & x>0\\0 & x\le 0\end{cases}` | text | 10 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}1 & x>0\\0 & x\le 0\end{cases}` | display | 10 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `f\colon A\to B` | text | 10 | 0 | 4: kern 72816, TeX glue 72816 0 0 |
| `f\colon A\to B` | display | 10 | 0 | 4: kern 72816, TeX glue 72816 0 0 |
| `(1+x)^n=\sum_{k=0}^n \binom{n}{k}x^k` | text | 10 | 0 | 15.0: hbox 924716 557059 229380 shift 0 (3), TeX hbox 300375 557059 229380 shift 0 (1) |
| `(1+x)^n=\sum_{k=0}^n \binom{n}{k}x^k` | display | 10 | 0 | 14.0: hbox 1358210 950279 622600 shift 0 (3), TeX hbox 482420 950279 622600 shift 0 (1) |
| `x_{\binom{n}{k}}` | text | 10 | 0 | 2.0.0: char cmr10 40 254863 491520 163840, TeX hbox 254863 491520 163840 shift 0 (3) |
| `x_{\binom{n}{k}}` | display | 10 | 0 | 2.0.0: char cmr10 40 254863 491520 163840, TeX hbox 254863 491520 163840 shift 0 (3) |
| `x^{\sqrt{\frac12}}_{\frac{\frac12}{3}}` | text | 10 | 0 | 2.2.1.0.0: hbox 78643 0 0 shift -81920 (0), TeX hbox 380294 338135 174295 shift 0 (3) |
| `x^{\sqrt{\frac12}}_{\frac{\frac12}{3}}` | display | 10 | 0 | 2.2.1.0.0: hbox 78643 0 0 shift -81920 (0), TeX hbox 380294 338135 174295 shift 0 (3) |
| `x^{\scriptscriptstyle\sqrt2}` | text | 10 | 2435 | 2: hbox 615320 306897 39133 shift -237825 (2), TeX hbox 615320 304462 39133 shift -237825 (2) |
| `x^{\scriptscriptstyle\sqrt2}` | display | 10 | 2435 | 2: hbox 615320 306897 39133 shift -270593 (2), TeX hbox 615320 304462 39133 shift -270593 (2) |
| `\dbinom{n}{k}` | text | 10 | 0 | 1.0: hbox 1358210 950279 622600 shift 0 (1), TeX hbox 482420 950279 622600 shift 0 (1) |
| `\dbinom{n}{k}` | display | 10 | 0 | 1.0: hbox 1358210 950279 622600 shift 0 (1), TeX hbox 482420 950279 622600 shift 0 (1) |
| `\tbinom{n}{k}` | text | 10 | 0 | 1.0: hbox 924716 557059 229380 shift 0 (1), TeX hbox 300375 557059 229380 shift 0 (1) |
| `\tbinom{n}{k}` | display | 10 | 0 | 1.0: hbox 924716 557059 229380 shift 0 (1), TeX hbox 300375 557059 229380 shift 0 (1) |
| `\binom{n+1}{k-1}` | text | 10 | 0 | 1.0: hbox 1588271 586443 280609 shift 0 (3), TeX hbox 300375 557059 229380 shift 0 (1) |
| `\binom{n+1}{k-1}` | display | 10 | 0 | 1.0: hbox 2486881 950279 622600 shift 0 (3), TeX hbox 482420 950279 622600 shift 0 (1) |
| `\dbinom{n+1}{k-1}` | text | 10 | 0 | 1.0: hbox 2486881 950279 622600 shift 0 (1), TeX hbox 482420 950279 622600 shift 0 (1) |
| `\dbinom{n+1}{k-1}` | display | 10 | 0 | 1.0: hbox 2486881 950279 622600 shift 0 (1), TeX hbox 482420 950279 622600 shift 0 (1) |
| `\tbinom{n+1}{k-1}` | text | 10 | 0 | 1.0: hbox 1588271 586443 280609 shift 0 (1), TeX hbox 300375 557059 229380 shift 0 (1) |
| `\tbinom{n+1}{k-1}` | display | 10 | 0 | 1.0: hbox 1588271 586443 280609 shift 0 (1), TeX hbox 300375 557059 229380 shift 0 (1) |
| `\binom{\frac12}{k}` | text | 10 | 0 | 1.0: hbox 981044 697254 245159 shift 0 (3), TeX hbox 300375 557059 229380 shift 0 (1) |
| `\binom{\frac12}{k}` | display | 10 | 0 | 1.0: hbox 1383361 997032 622600 shift 0 (3), TeX hbox 482420 950279 622600 shift 0 (1) |
| `\binom{n}{\frac{k}{2}}` | text | 10 | 0 | 1.0: hbox 1011763 557059 383904 shift 0 (3), TeX hbox 300375 557059 229380 shift 0 (1) |
| `\binom{n}{\frac{k}{2}}` | display | 10 | 0 | 1.0: hbox 1411806 950279 675540 shift 0 (3), TeX hbox 482420 950279 622600 shift 0 (1) |
| `\binom{a}{b}^2` | text | 10 | 0 | 1.0: hbox 885022 557059 229380 shift 0 (3), TeX hbox 300375 557059 229380 shift 0 (1) |
| `\binom{a}{b}^2` | display | 10 | 0 | 1.0: hbox 1311256 950279 622600 shift 0 (3), TeX hbox 482420 950279 622600 shift 0 (1) |
| `\binom{n}{k}_q` | text | 10 | 0 | 1.0: hbox 924716 557059 229380 shift 0 (3), TeX hbox 300375 557059 229380 shift 0 (1) |
| `\binom{n}{k}_q` | display | 10 | 0 | 1.0: hbox 1358210 950279 622600 shift 0 (3), TeX hbox 482420 950279 622600 shift 0 (1) |
| `\genfrac{(}{)}{0pt}{}{n}{k}` | text | 10 | 0 | 1.0: hbox 924716 557059 229380 shift 0 (3), TeX hbox 300375 557059 229380 shift 0 (1) |
| `\genfrac{(}{)}{0pt}{}{n}{k}` | display | 10 | 0 | 1.0: hbox 1358210 950279 622600 shift 0 (3), TeX hbox 482420 950279 622600 shift 0 (1) |
| `\genfrac{(}{)}{0.4pt}{}{n}{k}` | text | 10 | 0 | 1.0: hbox 924716 557059 229380 shift 0 (3), TeX hbox 300375 557059 229380 shift 0 (1) |
| `\genfrac{(}{)}{0.4pt}{}{n}{k}` | display | 10 | 0 | 1.0: hbox 1358210 950279 622600 shift 0 (3), TeX hbox 482420 950279 622600 shift 0 (1) |
| `\genfrac{[}{]}{1pt}{0}{a}{b}` | text | 10 | 0 | 1.0: hbox 1038188 950279 622600 shift 0 (1), TeX hbox 345886 950279 622600 shift 0 (1) |
| `\genfrac{[}{]}{1pt}{0}{a}{b}` | display | 10 | 0 | 1.0: hbox 1038188 950279 622600 shift 0 (1), TeX hbox 345886 950279 622600 shift 0 (1) |
| `\genfrac{\{}{\}}{0pt}{1}{a}{b}` | text | 10 | 0 | 1.0: hbox 1048862 557059 229380 shift 0 (1), TeX hbox 382295 557059 229380 shift 0 (1) |
| `\genfrac{\{}{\}}{0pt}{1}{a}{b}` | display | 10 | 0 | 1.0: hbox 1048862 557059 229380 shift 0 (1), TeX hbox 382295 557059 229380 shift 0 (1) |
| `\genfrac{\langle}{\rangle}{0pt}{2}{a}{b}` | text | 10 | 0 | 1.0: hbox 763491 491520 163840 shift 0 (1), TeX hbox 254863 491520 163840 shift 0 (1) |
| `\genfrac{\langle}{\rangle}{0pt}{2}{a}{b}` | display | 10 | 0 | 1.0: hbox 763491 491520 163840 shift 0 (1), TeX hbox 254863 491520 163840 shift 0 (1) |
| `\genfrac{\|}{\|}{0.8pt}{3}{x+1}{y}` | text | 10 | 206804 | 1: hbox 976497 433634 238010 shift 0 (1), TeX hbox 1183301 491520 238010 shift 0 (5) |
| `\genfrac{\|}{\|}{0.8pt}{3}{x+1}{y}` | display | 10 | 206804 | 1: hbox 976497 433634 238010 shift 0 (1), TeX hbox 1183301 491520 238010 shift 0 (5) |
| `\genfrac{(}{]}{0pt}{}{a}{b}` | text | 10 | 0 | 1.0: hbox 857715 557059 229380 shift 0 (3), TeX hbox 300375 557059 229380 shift 0 (1) |
| `\genfrac{(}{]}{0pt}{}{a}{b}` | display | 10 | 0 | 1.0: hbox 1174722 950279 622600 shift 0 (3), TeX hbox 482420 950279 622600 shift 0 (1) |
| `\frac{1}{\frac{1}{\frac{1}{x}}}` | text | 10 | 0 | 1.0.1.4.0: hbox 78643 0 0 shift -114688 (0), TeX hbox 573987 387287 431164 shift 0 (3) |
| `\frac{1}{\frac{1}{\frac{1}{x}}}` | display | 10 | 0 | 1.0.1.4.0: hbox 78643 0 0 shift -163840 (0), TeX hbox 573987 553676 420676 shift 0 (3) |
| `\frac{\frac{a}{b}}{\frac{c}{d}}` | text | 10 | 0 | 1.0.1.0.0: hbox 78643 0 0 shift -114688 (0), TeX hbox 411051 317200 157909 shift 0 (3) |
| `\frac{\frac{a}{b}}{\frac{c}{d}}` | display | 10 | 0 | 1.0.1.0.0: hbox 78643 0 0 shift -163840 (0), TeX hbox 441558 455554 225995 shift 0 (3) |
| `\frac{\frac{\frac{a}{b}}{c}}{d}` | text | 10 | 0 | 1.0.1.0.0: hbox 78643 0 0 shift -114688 (0), TeX hbox 568337 590453 157909 shift 0 (3) |
| `\frac{\frac{\frac{a}{b}}{c}}{d}` | display | 10 | 0 | 1.0.1.0.0: hbox 78643 0 0 shift -163840 (0), TeX hbox 568337 678269 225995 shift 0 (3) |
| `\frac{a}{\frac{b}{\frac{c}{d}}}` | text | 10 | 0 | 1.0.1.4.0: hbox 78643 0 0 shift -114688 (0), TeX hbox 556958 403671 361077 shift 0 (3) |
| `\frac{a}{\frac{b}{\frac{c}{d}}}` | display | 10 | 0 | 1.0.1.4.0: hbox 78643 0 0 shift -163840 (0), TeX hbox 556958 576613 383904 shift 0 (3) |
| `\sqrt{\frac{\frac12}{3}}` | text | 10 | 0 | 1.1.3.1.0.0: hbox 78643 0 0 shift -114688 (0), TeX hbox 380294 387287 157909 shift 0 (3) |
| `\sqrt{\frac{\frac12}{3}}` | display | 10 | 0 | 1.1.3.1.0.0: hbox 78643 0 0 shift -163840 (0), TeX hbox 418521 553676 225995 shift 0 (3) |
| `\sqrt{\binom{n}{k}}` | text | 10 | 0 | 1.1.3.0: hbox 300375 26213 760226 shift -530846 (1), TeX hbox 300375 557059 229380 shift 0 (1) |
| `\sqrt{\binom{n}{k}}` | display | 10 | 0 | 1.1.3.0: hbox 482420 26213 1546666 shift -924066 (1), TeX hbox 482420 950279 622600 shift 0 (1) |
| `\iint\limits_a^b` | text | 10 | 100415 | not supported by the TeX-rule layout: \iint with \limits or \nolimits |
| `\iint\limits_a^b` | display | 10 | 90589 | not supported by the TeX-rule layout: \iint with \limits or \nolimits |
| `\iint\nolimits_a^b` | text | 10 | 134079 | not supported by the TeX-rule layout: \iint with \limits or \nolimits |
| `\iint\nolimits_a^b` | display | 10 | 124253 | not supported by the TeX-rule layout: \iint with \limits or \nolimits |
| `\iiint\limits_a^b` | text | 10 | 200688 | not supported by the TeX-rule layout: \iiint with \limits or \nolimits |
| `\iiint\limits_a^b` | display | 10 | 194579 | not supported by the TeX-rule layout: \iiint with \limits or \nolimits |
| `\iiint\nolimits_a^b` | text | 10 | 234352 | not supported by the TeX-rule layout: \iiint with \limits or \nolimits |
| `\iiint\nolimits_a^b` | display | 10 | 228243 | not supported by the TeX-rule layout: \iiint with \limits or \nolimits |
| `\sum_{\substack{i<j\\ j<n}}x_{ij}` | text | 10 | 184170 | not supported by the TeX-rule layout: array cells in script style |
| `\sum_{\substack{i<j\\ j<n}}x_{ij}` | display | 10 | 85544 | not supported by the TeX-rule layout: array cells in script style |
| `\prod_{\sqrt{n}}^{\binom{n}{k}}` | text | 10 | 0 | 2.0.0.0: char cmr10 40 254863 491520 163840, TeX hbox 254863 491520 163840 shift 0 (3) |
| `\prod_{\sqrt{n}}^{\binom{n}{k}}` | display | 10 | 0 | 1.1.1.0: char cmr10 40 254863 491520 163840, TeX hbox 254863 491520 163840 shift 0 (3) |
| `\sum_{k}\binom{n}{k}` | text | 10 | 0 | 4.0: hbox 924716 557059 229380 shift 0 (3), TeX hbox 300375 557059 229380 shift 0 (1) |
| `\sum_{k}\binom{n}{k}` | display | 10 | 0 | 3.0: hbox 1358210 950279 622600 shift 0 (3), TeX hbox 482420 950279 622600 shift 0 (1) |
| `\det\begin{pmatrix}a&b\\c&d\end{pmatrix}` | text | 10 | 0 | 3.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\det\begin{pmatrix}a&b\\c&d\end{pmatrix}` | display | 10 | 0 | 3.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\hat{\imath}` | text | 10 | 299 | not supported by the TeX-rule layout: htmlmathml |
| `\hat{\imath}` | display | 10 | 299 | not supported by the TeX-rule layout: htmlmathml |
| `\hat{\jmath}` | text | 10 | 20 | not supported by the TeX-rule layout: htmlmathml |
| `\hat{\jmath}` | display | 10 | 20 | not supported by the TeX-rule layout: htmlmathml |
| `\check{\imath}` | text | 10 | 299 | not supported by the TeX-rule layout: htmlmathml |
| `\check{\imath}` | display | 10 | 299 | not supported by the TeX-rule layout: htmlmathml |
| `\check{\jmath}` | text | 10 | 20 | not supported by the TeX-rule layout: htmlmathml |
| `\check{\jmath}` | display | 10 | 20 | not supported by the TeX-rule layout: htmlmathml |
| `\tilde{\imath}` | text | 10 | 299 | not supported by the TeX-rule layout: htmlmathml |
| `\tilde{\imath}` | display | 10 | 299 | not supported by the TeX-rule layout: htmlmathml |
| `\tilde{\jmath}` | text | 10 | 20 | not supported by the TeX-rule layout: htmlmathml |
| `\tilde{\jmath}` | display | 10 | 20 | not supported by the TeX-rule layout: htmlmathml |
| `\acute{\imath}` | text | 10 | 299 | not supported by the TeX-rule layout: htmlmathml |
| `\acute{\imath}` | display | 10 | 299 | not supported by the TeX-rule layout: htmlmathml |
| `\acute{\jmath}` | text | 10 | 20 | not supported by the TeX-rule layout: htmlmathml |
| `\acute{\jmath}` | display | 10 | 20 | not supported by the TeX-rule layout: htmlmathml |
| `\grave{\imath}` | text | 10 | 299 | not supported by the TeX-rule layout: htmlmathml |
| `\grave{\imath}` | display | 10 | 299 | not supported by the TeX-rule layout: htmlmathml |
| `\grave{\jmath}` | text | 10 | 20 | not supported by the TeX-rule layout: htmlmathml |
| `\grave{\jmath}` | display | 10 | 20 | not supported by the TeX-rule layout: htmlmathml |
| `\dot{\imath}` | text | 10 | 299 | not supported by the TeX-rule layout: htmlmathml |
| `\dot{\imath}` | display | 10 | 299 | not supported by the TeX-rule layout: htmlmathml |
| `\dot{\jmath}` | text | 10 | 20 | not supported by the TeX-rule layout: htmlmathml |
| `\dot{\jmath}` | display | 10 | 20 | not supported by the TeX-rule layout: htmlmathml |
| `\ddot{\imath}` | text | 10 | 299 | not supported by the TeX-rule layout: htmlmathml |
| `\ddot{\imath}` | display | 10 | 299 | not supported by the TeX-rule layout: htmlmathml |
| `\ddot{\jmath}` | text | 10 | 20 | not supported by the TeX-rule layout: htmlmathml |
| `\ddot{\jmath}` | display | 10 | 20 | not supported by the TeX-rule layout: htmlmathml |
| `\breve{\imath}` | text | 10 | 299 | not supported by the TeX-rule layout: htmlmathml |
| `\breve{\imath}` | display | 10 | 299 | not supported by the TeX-rule layout: htmlmathml |
| `\breve{\jmath}` | text | 10 | 20 | not supported by the TeX-rule layout: htmlmathml |
| `\breve{\jmath}` | display | 10 | 20 | not supported by the TeX-rule layout: htmlmathml |
| `\bar{\imath}` | text | 10 | 299 | not supported by the TeX-rule layout: htmlmathml |
| `\bar{\imath}` | display | 10 | 299 | not supported by the TeX-rule layout: htmlmathml |
| `\bar{\jmath}` | text | 10 | 20 | not supported by the TeX-rule layout: htmlmathml |
| `\bar{\jmath}` | display | 10 | 20 | not supported by the TeX-rule layout: htmlmathml |
| `\vec{\imath}` | text | 10 | 299 | not supported by the TeX-rule layout: htmlmathml |
| `\vec{\imath}` | display | 10 | 299 | not supported by the TeX-rule layout: htmlmathml |
| `\vec{\jmath}` | text | 10 | 291 | not supported by the TeX-rule layout: htmlmathml |
| `\vec{\jmath}` | display | 10 | 291 | not supported by the TeX-rule layout: htmlmathml |
| `\mathring{\imath}` | text | 10 | 299 | not supported by the TeX-rule layout: htmlmathml |
| `\mathring{\imath}` | display | 10 | 299 | not supported by the TeX-rule layout: htmlmathml |
| `\mathring{\jmath}` | text | 10 | 20 | not supported by the TeX-rule layout: htmlmathml |
| `\mathring{\jmath}` | display | 10 | 20 | not supported by the TeX-rule layout: htmlmathml |
| `\dddot x` | text | 10 | 132690 | not supported by the TeX-rule layout: raisebox |
| `\dddot x` | display | 10 | 132690 | not supported by the TeX-rule layout: raisebox |
| `\dddot{x}^2` | text | 10 | 141109 | not supported by the TeX-rule layout: raisebox |
| `\dddot{x}^2` | display | 10 | 141109 | not supported by the TeX-rule layout: raisebox |
| `\widehat{\widehat{x}}` | text | 10 | 0 | 1.0: hbox 0 473316 0 shift 5234 (1), TeX hbox 0 473316 0 shift 23438 (1) |
| `\widehat{\widehat{x}}` | display | 10 | 0 | 1.0: hbox 0 473316 0 shift 5234 (1), TeX hbox 0 473316 0 shift 23438 (1) |
| `\hat{\hat{x}}` | text | 10 | 0 | 1: vbox 374556 628054 0 shift 0 (3), TeX vbox 410966 628054 0 shift 0 (3) |
| `\hat{\hat{x}}` | display | 10 | 0 | 1: vbox 374556 628054 0 shift 0 (3), TeX vbox 410966 628054 0 shift 0 (3) |
| `\hat{\tilde{x}}` | text | 10 | 0 | 1: vbox 374556 610631 0 shift 0 (3), TeX vbox 410966 610631 0 shift 0 (3) |
| `\hat{\tilde{x}}` | display | 10 | 0 | 1: vbox 374556 610631 0 shift 0 (3), TeX vbox 410966 610631 0 shift 0 (3) |
| `\tilde{\hat{x}}` | text | 10 | 0 | 1: vbox 374556 610631 0 shift 0 (3), TeX vbox 410966 610631 0 shift 0 (3) |
| `\tilde{\hat{x}}` | display | 10 | 0 | 1: vbox 374556 610631 0 shift 0 (3), TeX vbox 410966 610631 0 shift 0 (3) |
| `\bar{\bar{x}}` | text | 10 | 0 | 1: vbox 374556 462028 0 shift 0 (3), TeX vbox 410966 462028 0 shift 0 (3) |
| `\bar{\bar{x}}` | display | 10 | 0 | 1: vbox 374556 462028 0 shift 0 (3), TeX vbox 410966 462028 0 shift 0 (3) |
| `\dot{\hat{x}}` | text | 10 | 0 | 1: vbox 374556 610631 0 shift 0 (3), TeX vbox 410966 610631 0 shift 0 (3) |
| `\dot{\hat{x}}` | display | 10 | 0 | 1: vbox 374556 610631 0 shift 0 (3), TeX vbox 410966 610631 0 shift 0 (3) |
| `\ddot{\vec{x}}` | text | 10 | 0 | 1: vbox 374556 623738 0 shift 0 (3), TeX vbox 410966 623738 0 shift 0 (3) |
| `\ddot{\vec{x}}` | display | 10 | 0 | 1: vbox 374556 623738 0 shift 0 (3), TeX vbox 410966 623738 0 shift 0 (3) |
| `\vec{\dot{x}}` | text | 10 | 0 | 1: vbox 374556 623738 0 shift 0 (3), TeX vbox 410966 623738 0 shift 0 (3) |
| `\vec{\dot{x}}` | display | 10 | 0 | 1: vbox 374556 623738 0 shift 0 (3), TeX vbox 410966 623738 0 shift 0 (3) |
| `\hat{\bar{A}}` | text | 10 | 0 | 1: vbox 491521 710701 0 shift 0 (3), TeX vbox 673571 710701 0 shift 0 (3) |
| `\hat{\bar{A}}` | display | 10 | 0 | 1: vbox 491521 710701 0 shift 0 (3), TeX vbox 673571 710701 0 shift 0 (3) |
| `\acute{\grave{x}}` | text | 10 | 0 | 1: vbox 374556 628054 0 shift 0 (3), TeX vbox 410966 628054 0 shift 0 (3) |
| `\acute{\grave{x}}` | display | 10 | 0 | 1: vbox 374556 628054 0 shift 0 (3), TeX vbox 410966 628054 0 shift 0 (3) |
| `\check{\breve{y}}` | text | 10 | 0 | 1: vbox 344824 584819 127431 shift 0 (3), TeX vbox 417644 584819 127431 shift 0 (3) |
| `\check{\breve{y}}` | display | 10 | 0 | 1: vbox 344824 584819 127431 shift 0 (3), TeX vbox 417644 584819 127431 shift 0 (3) |
| `\vec{\vec{v}}` | text | 10 | 0 | 1: vbox 341181 654268 0 shift 0 (3), TeX vbox 377591 654268 0 shift 0 (3) |
| `\vec{\vec{v}}` | display | 10 | 0 | 1: vbox 341181 654268 0 shift 0 (3), TeX vbox 377591 654268 0 shift 0 (3) |
| `\dot{\dot{x}}` | text | 10 | 0 | 1: vbox 374556 593208 0 shift 0 (3), TeX vbox 410966 593208 0 shift 0 (3) |
| `\dot{\dot{x}}` | display | 10 | 0 | 1: vbox 374556 593208 0 shift 0 (3), TeX vbox 410966 593208 0 shift 0 (3) |
| `\tilde{\tilde{f}}` | text | 10 | 0 | 1: vbox 391398 766151 127431 shift 0 (3), TeX vbox 609858 766151 127431 shift 0 (3) |
| `\tilde{\tilde{f}}` | display | 10 | 0 | 1: vbox 391398 766151 127431 shift 0 (3), TeX vbox 609858 766151 127431 shift 0 (3) |
| `\overrightarrow{AB}` | text | 10 | 101662 | not supported by the TeX-rule layout: accent \overrightarrow |
| `\overrightarrow{AB}` | display | 10 | 101662 | not supported by the TeX-rule layout: accent \overrightarrow |
| `\overleftarrow{AB}` | text | 10 | 101662 | not supported by the TeX-rule layout: accent \overleftarrow |
| `\overleftarrow{AB}` | display | 10 | 101662 | not supported by the TeX-rule layout: accent \overleftarrow |
| `\overrightarrow{x}` | text | 10 | 101667 | not supported by the TeX-rule layout: accent \overrightarrow |
| `\overrightarrow{x}` | display | 10 | 101667 | not supported by the TeX-rule layout: accent \overrightarrow |
| `\underrightarrow{AB}` | text | 10 | 16466 | not supported by the TeX-rule layout: accentUnder |
| `\underrightarrow{AB}` | display | 10 | 16466 | not supported by the TeX-rule layout: accentUnder |
| `\overbrace{a+b+c}^{3}` | text | 10 | 112724 | not supported by the TeX-rule layout: horizBrace |
| `\overbrace{a+b+c}^{3}` | display | 10 | 112724 | not supported by the TeX-rule layout: horizBrace |
| `\underbrace{a+b+c}_{3}` | text | 10 | 90878 | not supported by the TeX-rule layout: horizBrace |
| `\underbrace{a+b+c}_{3}` | display | 10 | 90878 | not supported by the TeX-rule layout: horizBrace |
| `\overbrace{x}` | text | 10 | 131084 | not supported by the TeX-rule layout: horizBrace |
| `\overbrace{x}` | display | 10 | 131084 | not supported by the TeX-rule layout: horizBrace |
| `\underbrace{x}` | text | 10 | 131084 | not supported by the TeX-rule layout: horizBrace |
| `\underbrace{x}` | display | 10 | 131084 | not supported by the TeX-rule layout: horizBrace |
| `\overset{a}{=}` | text | 10 | 0 | 1.0.3.0: char cmr10 61 509726 240435 -87245, TeX kern 0 |
| `\overset{a}{=}` | display | 10 | 0 | 1.0.3.0: char cmr10 61 509726 240435 -87245, TeX kern 0 |
| `\underset{a}{=}` | text | 10 | 0 | 1.0.0.0: char cmr10 61 509726 240435 -87245, TeX kern 0 |
| `\underset{a}{=}` | display | 10 | 0 | 1.0.0.0: char cmr10 61 509726 240435 -87245, TeX kern 0 |
| `\xrightarrow{a}` | text | 10 | 260762 | not supported by the TeX-rule layout: xArrow |
| `\xrightarrow{a}` | display | 10 | 260762 | not supported by the TeX-rule layout: xArrow |
| `\xleftarrow[b]{a}` | text | 10 | 260762 | not supported by the TeX-rule layout: xArrow |
| `\xleftarrow[b]{a}` | display | 10 | 260762 | not supported by the TeX-rule layout: xArrow |
| `\left( \begin{matrix}a&b\\c&d\end{matrix}\right)` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left( \begin{matrix}a&b\\c&d\end{matrix}\right)` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left( \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right)` | text | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left( \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right)` | display | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left( \frac{\frac12}{\frac34}\right)` | text | 10 | 0 | 1.1.0.1.0.0: hbox 78643 0 0 shift -114688 (0), TeX hbox 380294 387287 157909 shift 0 (3) |
| `\left( \frac{\frac12}{\frac34}\right)` | display | 10 | 0 | 1.1.0.1.0.0: hbox 78643 0 0 shift -163840 (0), TeX hbox 418521 553676 225995 shift 0 (3) |
| `\left[ \begin{matrix}a&b\\c&d\end{matrix}\right]` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left[ \begin{matrix}a&b\\c&d\end{matrix}\right]` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left[ \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right]` | text | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left[ \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right]` | display | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left[ \frac{\frac12}{\frac34}\right]` | text | 10 | 0 | 1.1.0.1.0.0: hbox 78643 0 0 shift -114688 (0), TeX hbox 380294 387287 157909 shift 0 (3) |
| `\left[ \frac{\frac12}{\frac34}\right]` | display | 10 | 0 | 1.1.0.1.0.0: hbox 78643 0 0 shift -163840 (0), TeX hbox 418521 553676 225995 shift 0 (3) |
| `\left\{ \begin{matrix}a&b\\c&d\end{matrix}\right\}` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\{ \begin{matrix}a&b\\c&d\end{matrix}\right\}` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\{ \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\}` | text | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\{ \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\}` | display | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\langle \begin{matrix}a&b\\c&d\end{matrix}\right\rangle` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\langle \begin{matrix}a&b\\c&d\end{matrix}\right\rangle` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\langle \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rangle` | text | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\langle \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rangle` | display | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\| \begin{matrix}a&b\\c&d\end{matrix}\right\|` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\| \begin{matrix}a&b\\c&d\end{matrix}\right\|` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\| \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\|` | text | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\| \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\|` | display | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\\| \begin{matrix}a&b\\c&d\end{matrix}\right\\|` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\\| \begin{matrix}a&b\\c&d\end{matrix}\right\\|` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\\| \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\\|` | text | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\\| \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\\|` | display | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\lfloor \begin{matrix}a&b\\c&d\end{matrix}\right\rfloor` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\lfloor \begin{matrix}a&b\\c&d\end{matrix}\right\rfloor` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\lfloor \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rfloor` | text | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\lfloor \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rfloor` | display | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\lceil \begin{matrix}a&b\\c&d\end{matrix}\right\rceil` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\lceil \begin{matrix}a&b\\c&d\end{matrix}\right\rceil` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\lceil \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rceil` | text | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\lceil \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rceil` | display | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left/ \begin{matrix}a&b\\c&d\end{matrix}\right\backslash` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left/ \begin{matrix}a&b\\c&d\end{matrix}\right\backslash` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left/ \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\backslash` | text | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left/ \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\backslash` | display | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\uparrow \begin{matrix}a&b\\c&d\end{matrix}\right\downarrow` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\uparrow \begin{matrix}a&b\\c&d\end{matrix}\right\downarrow` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\uparrow \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\downarrow` | text | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\uparrow \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\downarrow` | display | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\Uparrow \begin{matrix}a&b\\c&d\end{matrix}\right\updownarrow` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\Uparrow \begin{matrix}a&b\\c&d\end{matrix}\right\updownarrow` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\Uparrow \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\updownarrow` | text | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\Uparrow \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\updownarrow` | display | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left. \begin{matrix}a&b\\c&d\end{matrix}\right)` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left. \begin{matrix}a&b\\c&d\end{matrix}\right)` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left. \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right)` | text | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left. \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right)` | display | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left( \begin{matrix}a&b\\c&d\end{matrix}\right.` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left( \begin{matrix}a&b\\c&d\end{matrix}\right.` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left( \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right.` | text | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left( \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right.` | display | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left( \frac{\frac12}{\frac34}\right.` | text | 10 | 0 | 1.1.0.1.0.0: hbox 78643 0 0 shift -114688 (0), TeX hbox 380294 387287 157909 shift 0 (3) |
| `\left( \frac{\frac12}{\frac34}\right.` | display | 10 | 0 | 1.1.0.1.0.0: hbox 78643 0 0 shift -163840 (0), TeX hbox 418521 553676 225995 shift 0 (3) |
| `\left. \begin{matrix}a&b\\c&d\end{matrix}\right.` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left. \begin{matrix}a&b\\c&d\end{matrix}\right.` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left. \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right.` | text | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left. \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right.` | display | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\Downarrow \begin{matrix}a&b\\c&d\end{matrix}\right\Updownarrow` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\Downarrow \begin{matrix}a&b\\c&d\end{matrix}\right\Updownarrow` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\Downarrow \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\Updownarrow` | text | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\Downarrow \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\Updownarrow` | display | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\backslash \begin{matrix}a&b\\c&d\end{matrix}\right/` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\backslash \begin{matrix}a&b\\c&d\end{matrix}\right/` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\backslash \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right/` | text | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\backslash \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right/` | display | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\lvert \begin{matrix}a&b\\c&d\end{matrix}\right\rvert` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\lvert \begin{matrix}a&b\\c&d\end{matrix}\right\rvert` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\lvert \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rvert` | text | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\lvert \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rvert` | display | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\lVert \begin{matrix}a&b\\c&d\end{matrix}\right\rVert` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\lVert \begin{matrix}a&b\\c&d\end{matrix}\right\rVert` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\lVert \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rVert` | text | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\lVert \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rVert` | display | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\lbrace \begin{matrix}a&b\\c&d\end{matrix}\right\rbrace` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\lbrace \begin{matrix}a&b\\c&d\end{matrix}\right\rbrace` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\lbrace \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rbrace` | text | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\lbrace \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rbrace` | display | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\lbrack \begin{matrix}a&b\\c&d\end{matrix}\right\rbrack` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\lbrack \begin{matrix}a&b\\c&d\end{matrix}\right\rbrack` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\lbrack \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rbrack` | text | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left\lbrack \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rbrack` | display | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\left(\begin{array}{cc}a&b\\c&d\end{array}\right)` | text | 10 | 0 | 1.1.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left(\begin{array}{cc}a&b\\c&d\end{array}\right)` | display | 10 | 0 | 1.1.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\left\{\begin{array}{ll}a&b\\c&d\end{array}\right.` | text | 10 | 0 | 1.1.0.3: hbox 996466 455111 0 shift 0 (6), TeX hbox 996466 550500 235932 shift 0 (9) |
| `\left\{\begin{array}{ll}a&b\\c&d\end{array}\right.` | display | 10 | 0 | 1.1.0.3: hbox 996466 455111 0 shift 0 (6), TeX hbox 996466 550500 235932 shift 0 (9) |
| `\text{\textbf{a}}` | text | 10 | 5610 | not supported by the TeX-rule layout: text that is not plain characters |
| `\text{\textbf{a}}` | display | 10 | 5610 | not supported by the TeX-rule layout: text that is not plain characters |
| `\text{a$x$b}` | text | 10 | 7209 | not supported by the TeX-rule layout: text that is not plain characters |
| `\text{a$x$b}` | display | 10 | 7209 | not supported by the TeX-rule layout: text that is not plain characters |
| `\boldsymbol{\alpha}` | text | 10 | 233 | not supported by the TeX-rule layout: \boldsymbol |
| `\boldsymbol{\alpha}` | display | 10 | 233 | not supported by the TeX-rule layout: \boldsymbol |
| `\boldsymbol{x}` | text | 10 | 18 | not supported by the TeX-rule layout: \boldsymbol |
| `\boldsymbol{x}` | display | 10 | 18 | not supported by the TeX-rule layout: \boldsymbol |
| `a\hphantom{b}c` | text | 10 | 0 | 2.0: math false, TeX nothing |
| `a\hphantom{b}c` | display | 10 | 0 | 2.0: math false, TeX nothing |
| `\smash{\frac12}` | text | 10 | 0 | 1: hbox 418521 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `\smash{\frac12}` | display | 10 | 0 | 1: hbox 484967 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\smash{b}c` | text | 10 | 0 | 2: hbox 281258 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\smash{b}c` | display | 10 | 0 | 2: hbox 281258 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `\smash{x_i}` | text | 10 | 0 | 1: hbox 592744 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `\smash{x_i}` | display | 10 | 0 | 1: hbox 592744 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `\hphantom{\frac12}` | text | 10 | 0 | 1.0: math false, TeX nothing |
| `\hphantom{\frac12}` | display | 10 | 0 | 1.0: math false, TeX nothing |
| `\smash[t]{\frac12}` | text | 10 | 0 | 1: hbox 418521 0 225995 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `\smash[t]{\frac12}` | display | 10 | 0 | 1: hbox 484967 0 449545 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `\smash[b]{\frac12}` | text | 10 | 0 | 1: hbox 418521 553676 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `\smash[b]{\frac12}` | display | 10 | 0 | 1: hbox 484967 865699 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\mkern-3mu b` | text | 10 | 0 | 2: glue -109224 0 0, TeX kern -109224 |
| `a\mkern-3mu b` | display | 10 | 0 | 2: glue -109224 0 0, TeX kern -109224 |
| `a\kern2pt b` | text | 10 | 0 | 2: glue 131072 0 0, TeX kern 131072 |
| `a\kern2pt b` | display | 10 | 0 | 2: glue 131072 0 0, TeX kern 131072 |
| `a\hskip 3pt plus 1pt b` | text | 10 | 2114141 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `a\hskip 3pt plus 1pt b` | display | 10 | 2114141 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `a\negmedspace b` | text | 10 | 0 | 2: kern -145632, TeX glue -145632 -72816 -145632 |
| `a\negmedspace b` | display | 10 | 0 | 2: kern -145632, TeX glue -145632 -72816 -145632 |
| `a\negthickspace b` | text | 10 | 0 | 2: kern -182040, TeX glue -182040 -182040 0 |
| `a\negthickspace b` | display | 10 | 0 | 2: kern -182040, TeX glue -182040 -182040 0 |
| `a\mskip 5mu b` | text | 10 | 0 | 2: glue 182040 182040 0, TeX glue 182040 0 0 |
| `a\mskip 5mu b` | display | 10 | 0 | 2: glue 182040 182040 0, TeX glue 182040 0 0 |
| `a\enspace b` | text | 10 | 0 | 2: glue 327680 0 0, TeX kern 327680 |
| `a\enspace b` | display | 10 | 0 | 2: glue 327680 0 0, TeX kern 327680 |
| `\vdots` | text | 10 | 19661 | not supported by the TeX-rule layout: symbol \varvdots |
| `\vdots` | display | 10 | 19661 | not supported by the TeX-rule layout: symbol \varvdots |
| `\ddots` | text | 10 | 447611 | not supported by the TeX-rule layout: symbol \ddots |
| `\ddots` | display | 10 | 447611 | not supported by the TeX-rule layout: symbol \ddots |
| `\vdots+x` | text | 10 | 3932 | not supported by the TeX-rule layout: symbol \varvdots |
| `\vdots+x` | display | 10 | 3932 | not supported by the TeX-rule layout: symbol \varvdots |
| `a\bmod n` | text | 10 | 0 | 2: kern 36408, TeX glue 0 0 0 |
| `a\bmod n` | display | 10 | 0 | 2: kern 36408, TeX glue 0 0 0 |
| `a\bmod{n+1}` | text | 10 | 0 | 2: kern 36408, TeX glue 0 0 0 |
| `a\bmod{n+1}` | display | 10 | 0 | 2: kern 36408, TeX glue 0 0 0 |
| `a\bmod b\bmod c` | text | 10 | 0 | 2: kern 36408, TeX glue 0 0 0 |
| `a\bmod b\bmod c` | display | 10 | 0 | 2: kern 36408, TeX glue 0 0 0 |
| `a\notin B` | text | 10 | 138217 | not supported by the TeX-rule layout: htmlmathml |
| `a\notin B` | display | 10 | 138217 | not supported by the TeX-rule layout: htmlmathml |
| `a\longrightarrow b` | text | 10 | 0 | 3.0: hbox 509726 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\longrightarrow b` | display | 10 | 0 | 3.0: hbox 509726 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\longleftarrow b` | text | 10 | 0 | 5.0: hbox 509726 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\longleftarrow b` | display | 10 | 0 | 5.0: hbox 509726 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\longmapsto b` | text | 10 | 0 | 4.0: hbox 509726 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\longmapsto b` | display | 10 | 0 | 4.0: hbox 509726 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\longleftrightarrow b` | text | 10 | 0 | 3: char cmsy10 36 655361 240435 -87245, TeX char cmsy10 32 655361 240435 -87245 |
| `a\longleftrightarrow b` | display | 10 | 0 | 3: char cmsy10 36 655361 240435 -87245, TeX char cmsy10 32 655361 240435 -87245 |
| `f\colon X\hookrightarrow Y` | text | 10 | 0 | 4: kern 72816, TeX glue 72816 0 0 |
| `f\colon X\hookrightarrow Y` | display | 10 | 0 | 4: kern 72816, TeX glue 72816 0 0 |
| `x\xrightarrow{f}y` | text | 10 | 238192 | not supported by the TeX-rule layout: xArrow |
| `x\xrightarrow{f}y` | display | 10 | 238192 | not supported by the TeX-rule layout: xArrow |
| `x\xrightarrow[g]{f}y` | text | 10 | 238192 | not supported by the TeX-rule layout: xArrow |
| `x\xrightarrow[g]{f}y` | display | 10 | 238192 | not supported by the TeX-rule layout: xArrow |
| `x\overset{f}{\longrightarrow}y` | text | 10 | 0 | 3.0.3.0: hbox 509726 0 0 shift 0 (1), TeX kern 0 |
| `x\overset{f}{\longrightarrow}y` | display | 10 | 0 | 3.0.3.0: hbox 509726 0 0 shift 0 (1), TeX kern 0 |
| `A\xleftarrow{\frac12}B` | text | 10 | 165067 | not supported by the TeX-rule layout: xArrow |
| `A\xleftarrow{\frac12}B` | display | 10 | 165067 | not supported by the TeX-rule layout: xArrow |
| `a\cong b` | text | 10 | 32768 | not supported by the TeX-rule layout: symbol \cong |
| `a\cong b` | display | 10 | 32768 | not supported by the TeX-rule layout: symbol \cong |
| `a\models b` | text | 10 | 14326 | not supported by the TeX-rule layout: symbol \models |
| `a\models b` | display | 10 | 14326 | not supported by the TeX-rule layout: symbol \models |
| `\hbar` | text | 10 | 23705 | not supported by the TeX-rule layout: symbol \hbar |
| `\hbar` | display | 10 | 23705 | not supported by the TeX-rule layout: symbol \hbar |
| `\checkmark` | text | 10 | 220 | not supported by the TeX-rule layout: symbol \checkmark |
| `\checkmark` | display | 10 | 220 | not supported by the TeX-rule layout: symbol \checkmark |
| `\begin{matrix}a&b\\c&d\end{matrix}` | text | 10 | 0 | 2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\begin{matrix}a&b\\c&d\end{matrix}` | display | 10 | 0 | 2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\begin{bmatrix}a&b\\c&d\end{bmatrix}` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\begin{bmatrix}a&b\\c&d\end{bmatrix}` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\begin{Bmatrix}a&b\\c&d\end{Bmatrix}` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\begin{Bmatrix}a&b\\c&d\end{Bmatrix}` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\begin{Vmatrix}a&b\\c&d\end{Vmatrix}` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\begin{Vmatrix}a&b\\c&d\end{Vmatrix}` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\begin{smallmatrix}a&b\\c&d\end{smallmatrix}` | text | 10 | 221415 | not supported by the TeX-rule layout: this array environment |
| `\begin{smallmatrix}a&b\\c&d\end{smallmatrix}` | display | 10 | 221415 | not supported by the TeX-rule layout: this array environment |
| `\left(\begin{smallmatrix}a&b\\c&d\end{smallmatrix}\right)` | text | 10 | 196617 | not supported by the TeX-rule layout: this array environment |
| `\left(\begin{smallmatrix}a&b\\c&d\end{smallmatrix}\right)` | display | 10 | 196617 | not supported by the TeX-rule layout: this array environment |
| `\begin{pmatrix}1&0&0\\0&1&0\\0&0&1\end{pmatrix}` | text | 10 | 0 | 1.2.0.3: hbox 983041 422343 0 shift 0 (7), TeX hbox 983041 550500 235932 shift 0 (7) |
| `\begin{pmatrix}1&0&0\\0&1&0\\0&0&1\end{pmatrix}` | display | 10 | 0 | 1.2.0.3: hbox 983041 422343 0 shift 0 (7), TeX hbox 983041 550500 235932 shift 0 (7) |
| `\begin{pmatrix}a\\b\end{pmatrix}` | text | 10 | 0 | 1.2.0.1.6: glue 0 65536 0, TeX math false |
| `\begin{pmatrix}a\\b\end{pmatrix}` | display | 10 | 0 | 1.2.0.1.6: glue 0 65536 0, TeX math false |
| `\begin{pmatrix}a&b\end{pmatrix}` | text | 10 | 0 | 1.2.0.3: hbox 936618 455111 0 shift 0 (7), TeX hbox 936618 550500 235932 shift 0 (7) |
| `\begin{pmatrix}a&b\end{pmatrix}` | display | 10 | 0 | 1.2.0.3: hbox 936618 455111 0 shift 0 (7), TeX hbox 936618 550500 235932 shift 0 (7) |
| `\begin{pmatrix}\frac12&\frac34\\x&y\end{pmatrix}` | text | 10 | 0 | 1.2.0.3: hbox 1073881 553676 225995 shift 0 (7), TeX hbox 1073881 553676 235932 shift 0 (10) |
| `\begin{pmatrix}\frac12&\frac34\\x&y\end{pmatrix}` | display | 10 | 0 | 1.2.0.3: hbox 1073881 553676 225995 shift 0 (7), TeX hbox 1073881 553676 235932 shift 0 (10) |
| `\begin{bmatrix}x^2&\sum_i y_i\\\sqrt{z}&w\end{bmatrix}` | text | 10 | 0 | 1.2.0.3: hbox 2214042 491524 196611 shift 0 (11), TeX hbox 2214042 550500 235932 shift 0 (14) |
| `\begin{bmatrix}x^2&\sum_i y_i\\\sqrt{z}&w\end{bmatrix}` | display | 10 | 0 | 1.2.0.3: hbox 2214042 491524 196611 shift 0 (11), TeX hbox 2214042 550500 235932 shift 0 (14) |
| `\begin{pmatrix}1&\cdots&n\\\vdots&\ddots&\vdots\\m&\cdots&mn\end{pmatrix}` | text | 10 | 33809 | not supported by the TeX-rule layout: symbol \varvdots |
| `\begin{pmatrix}1&\cdots&n\\\vdots&\ddots&\vdots\\m&\cdots&mn\end{pmatrix}` | display | 10 | 33809 | not supported by the TeX-rule layout: symbol \varvdots |
| `\begin{vmatrix}a&b&c\\d&e&f\\g&h&i\end{vmatrix}` | text | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\begin{vmatrix}a&b&c\\d&e&f\\g&h&i\end{vmatrix}` | display | 10 | 0 | 1.2.0.3: hbox 1032951 455111 0 shift 0 (7), TeX hbox 1032951 550500 235932 shift 0 (7) |
| `\begin{pmatrix}a&b\\c&d\end{pmatrix}^2` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\begin{pmatrix}a&b\\c&d\end{pmatrix}^2` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\begin{pmatrix}a&b\\c&d\end{pmatrix}\begin{pmatrix}x\\y\end{pmatrix}` | text | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\begin{pmatrix}a&b\\c&d\end{pmatrix}\begin{pmatrix}x\\y\end{pmatrix}` | display | 10 | 0 | 1.2.0.3: hbox 996466 455111 0 shift 0 (7), TeX hbox 996466 550500 235932 shift 0 (10) |
| `\begin{matrix}abc&d\\e&fghij\end{matrix}` | text | 10 | 0 | 2.0.3: hbox 2293624 455111 0 shift 0 (7), TeX hbox 2293624 550500 235932 shift 0 (10) |
| `\begin{matrix}abc&d\\e&fghij\end{matrix}` | display | 10 | 0 | 2.0.3: hbox 2293624 455111 0 shift 0 (7), TeX hbox 2293624 550500 235932 shift 0 (10) |
| `\begin{cases}a&x>0\\b&x\le0\end{cases}` | text | 10 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}a&x>0\\b&x\le0\end{cases}` | display | 10 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `f(x)=\begin{cases}1&x>0\\0&\text{otherwise}\end{cases}` | text | 10 | 0 | 9.1.0.1.1: glue 0 0 0, TeX math false |
| `f(x)=\begin{cases}1&x>0\\0&\text{otherwise}\end{cases}` | display | 10 | 0 | 9.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}\frac12&a\\\sqrt{x}&b\\c&d\end{cases}` | text | 10 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}\frac12&a\\\sqrt{x}&b\\c&d\end{cases}` | display | 10 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}a\end{cases}` | text | 10 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}a\end{cases}` | display | 10 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}x&\text{if }x\ge0,\\-x&\text{if }x<0\end{cases}` | text | 10 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}x&\text{if }x\ge0,\\-x&\text{if }x<0\end{cases}` | display | 10 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{array}{lcr}a&b&c\\dd&ee&ff\end{array}` | text | 10 | 0 | 1.0.3: hbox 1265666 455111 0 shift 0 (7), TeX hbox 1265666 550500 235932 shift 0 (7) |
| `\begin{array}{lcr}a&b&c\\dd&ee&ff\end{array}` | display | 10 | 0 | 1.0.3: hbox 1265666 455111 0 shift 0 (7), TeX hbox 1265666 550500 235932 shift 0 (7) |
| `\begin{array}{c}a\\b\end{array}` | text | 10 | 0 | 1.0.1.6: glue 0 65536 0, TeX math false |
| `\begin{array}{c}a\\b\end{array}` | display | 10 | 0 | 1.0.1.6: glue 0 65536 0, TeX math false |
| `\begin{array}{l}a\\bbb\end{array}` | text | 10 | 0 | 1.0.1.5: glue 0 65536 0, TeX math false |
| `\begin{array}{l}a\\bbb\end{array}` | display | 10 | 0 | 1.0.1.5: glue 0 65536 0, TeX math false |
| `\begin{array}{r}a\\bbb\end{array}` | text | 10 | 0 | 1.0.1.6: glue 327680 0 0, TeX math false |
| `\begin{array}{r}a\\bbb\end{array}` | display | 10 | 0 | 1.0.1.6: glue 327680 0 0, TeX math false |
| `\begin{array}{cc}a&b\end{array}` | text | 10 | 0 | 1.0.3: hbox 936618 455111 0 shift 0 (7), TeX hbox 936618 550500 235932 shift 0 (7) |
| `\begin{array}{cc}a&b\end{array}` | display | 10 | 0 | 1.0.3: hbox 936618 455111 0 shift 0 (7), TeX hbox 936618 550500 235932 shift 0 (7) |
| `\begin{array}{rl}x&=1\\yyy&=2\end{array}` | text | 10 | 0 | 1.0.3: hbox 1674807 422343 0 shift 0 (8), TeX hbox 1674807 550500 235932 shift 0 (11) |
| `\begin{array}{rl}x&=1\\yyy&=2\end{array}` | display | 10 | 0 | 1.0.3: hbox 1674807 422343 0 shift 0 (8), TeX hbox 1674807 550500 235932 shift 0 (11) |
| `\begin{array}{c\|c}a&b\\\hline c&d\end{array}` | text | 10 | 13107 | not supported by the TeX-rule layout: array rules |
| `\begin{array}{c\|c}a&b\\\hline c&d\end{array}` | display | 10 | 13107 | not supported by the TeX-rule layout: array rules |
| `\begin{array}{ccc}\frac12&x&\sum\\a&\sqrt{b}&c\end{array}` | text | 10 | 0 | 1.0.3: hbox 1482753 282168 0 shift 0 (7), TeX hbox 1482753 553676 235932 shift 0 (7) |
| `\begin{array}{ccc}\frac12&x&\sum\\a&\sqrt{b}&c\end{array}` | display | 10 | 0 | 1.0.3: hbox 1482753 282168 0 shift 0 (7), TeX hbox 1482753 553676 235932 shift 0 (7) |
| `\begin{array}{lcr}1&22&333\\4444&55&6\end{array}` | text | 10 | 0 | 1.0.3: hbox 1310722 422343 0 shift 0 (8), TeX hbox 1310722 550500 235932 shift 0 (8) |
| `\begin{array}{lcr}1&22&333\\4444&55&6\end{array}` | display | 10 | 0 | 1.0.3: hbox 1310722 422343 0 shift 0 (8), TeX hbox 1310722 550500 235932 shift 0 (8) |
| `\begin{array}[t]{c}a\\b\end{array}` | text | 10 | none | KaTeX parse error: Unknown column alignment: [ at position 14: \begin{array}[̲t]{c}a\\b\end{a… |
| `\begin{array}[t]{c}a\\b\end{array}` | display | 10 | none | KaTeX parse error: Unknown column alignment: [ at position 14: \begin{array}[̲t]{c}a\\b\end{a… |
| `\begin{array}[b]{c}a\\b\end{array}` | text | 10 | none | KaTeX parse error: Unknown column alignment: [ at position 14: \begin{array}[̲b]{c}a\\b\end{a… |
| `\begin{array}[b]{c}a\\b\end{array}` | display | 10 | none | KaTeX parse error: Unknown column alignment: [ at position 14: \begin{array}[̲b]{c}a\\b\end{a… |
| `\begin{array}{@{}c@{}}a\end{array}` | text | 10 | none | KaTeX parse error: Unknown column alignment: @ at position 15: \begin{array}{@̲{}c@{}}a\end{ar… |
| `\begin{array}{@{}c@{}}a\end{array}` | display | 10 | none | KaTeX parse error: Unknown column alignment: @ at position 15: \begin{array}{@̲{}c@{}}a\end{ar… |
| `\begin{array}{c@{\,}c}a&b\end{array}` | text | 10 | none | KaTeX parse error: Unknown column alignment: @ at position 16: \begin{array}{c@̲{\,}c}a&b\end{a… |
| `\begin{array}{c@{\,}c}a&b\end{array}` | display | 10 | none | KaTeX parse error: Unknown column alignment: @ at position 16: \begin{array}{c@̲{\,}c}a&b\end{a… |
| `\substack{a\\b}` | text | 10 | 123410 | not supported by the TeX-rule layout: array cells in script style |
| `\substack{a\\b}` | display | 10 | 123410 | not supported by the TeX-rule layout: array cells in script style |
| `\sum_{\substack{a\\b}}` | text | 10 | 81888 | not supported by the TeX-rule layout: array cells in script style |
| `\sum_{\substack{a\\b}}` | display | 10 | 97874 | not supported by the TeX-rule layout: array cells in script style |
| `\begin{aligned}a&=b\\c&=d\end{aligned}` | text | 10 | 102 | not supported by the TeX-rule layout: this array environment |
| `\begin{aligned}a&=b\\c&=d\end{aligned}` | display | 10 | 102 | not supported by the TeX-rule layout: this array environment |
| `\begin{gathered}a\\bb\end{gathered}` | text | 10 | 218 | not supported by the TeX-rule layout: this array environment |
| `\begin{gathered}a\\bb\end{gathered}` | display | 10 | 218 | not supported by the TeX-rule layout: this array environment |
| `\overset{\mathrm{def}}{=}` | text | 10 | 0 | 1.0.3.1: char cmr10 61 509726 240435 -87245, TeX kern 0 |
| `\overset{\mathrm{def}}{=}` | display | 10 | 0 | 1.0.3.1: char cmr10 61 509726 240435 -87245, TeX kern 0 |
| `\boxed{x}` | text | 10 | 52118 | not supported by the TeX-rule layout: enclose |
| `\boxed{x}` | display | 10 | 52118 | not supported by the TeX-rule layout: enclose |
| `\boxed{\frac12}` | text | 10 | 52429 | not supported by the TeX-rule layout: enclose |
| `\boxed{\frac12}` | display | 10 | 52429 | not supported by the TeX-rule layout: enclose |
| `\fbox{x}` | text | 10 | 52428 | not supported by the TeX-rule layout: enclose |
| `\fbox{x}` | display | 10 | 52428 | not supported by the TeX-rule layout: enclose |
| `\left(a\atop b\right)` | text | 10 | 42032 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `\left(a\atop b\right)` | display | 10 | 32 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `a\over b` | text | 10 | 41592 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `a\over b` | display | 10 | 223582 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\over b}` | text | 10 | 41592 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\over b}` | display | 10 | 327 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\choose b}` | text | 10 | 42032 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\choose b}` | display | 10 | 119 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\above 1pt b}` | text | 10 | 41592 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\above 1pt b}` | display | 10 | 327 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\overwithdelims() b}` | text | 10 | none | KaTeX parse error: Undefined control sequence: \overwithdelims at position 3: {a\̲o̲v̲e̲r̲w̲i̲t̲h̲d̲e̲l̲i̲m̲s̲() b} |
| `{a\overwithdelims() b}` | display | 10 | none | KaTeX parse error: Undefined control sequence: \overwithdelims at position 3: {a\̲o̲v̲e̲r̲w̲i̲t̲h̲d̲e̲l̲i̲m̲s̲() b} |
| `{a\atopwithdelims[] b}` | text | 10 | none | KaTeX parse error: Undefined control sequence: \atopwithdelims at position 3: {a\̲a̲t̲o̲p̲w̲i̲t̲h̲d̲e̲l̲i̲m̲s̲[] b} |
| `{a\atopwithdelims[] b}` | display | 10 | none | KaTeX parse error: Undefined control sequence: \atopwithdelims at position 3: {a\̲a̲t̲o̲p̲w̲i̲t̲h̲d̲e̲l̲i̲m̲s̲[] b} |
| `{a\brace b}` | text | 10 | 42032 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\brace b}` | display | 10 | 267 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\brack b}` | text | 10 | 41158 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\brack b}` | display | 10 | 557 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `\mathchar"7141` | text | 10 | none | KaTeX parse error: Undefined control sequence: \mathchar at position 1: \̲m̲a̲t̲h̲c̲h̲a̲r̲"7141 |
| `\mathchar"7141` | display | 10 | none | KaTeX parse error: Undefined control sequence: \mathchar at position 1: \̲m̲a̲t̲h̲c̲h̲a̲r̲"7141 |
| `\delimiter"4266308` | text | 10 | none | KaTeX parse error: Undefined control sequence: \delimiter at position 1: \̲d̲e̲l̲i̲m̲i̲t̲e̲r̲"4266308 |
| `\delimiter"4266308` | display | 10 | none | KaTeX parse error: Undefined control sequence: \delimiter at position 1: \̲d̲e̲l̲i̲m̲i̲t̲e̲r̲"4266308 |
| `\radical"270370{x}` | text | 10 | none | KaTeX parse error: Undefined control sequence: \radical at position 1: \̲r̲a̲d̲i̲c̲a̲l̲"270370{x} |
| `\radical"270370{x}` | display | 10 | none | KaTeX parse error: Undefined control sequence: \radical at position 1: \̲r̲a̲d̲i̲c̲a̲l̲"270370{x} |
| `\skew{3}\hat{x}` | text | 10 | none | KaTeX parse error: Undefined control sequence: \skew at position 1: \̲s̲k̲e̲w̲{3}\hat{x} |
| `\skew{3}\hat{x}` | display | 10 | none | KaTeX parse error: Undefined control sequence: \skew at position 1: \̲s̲k̲e̲w̲{3}\hat{x} |
| `\vcenter{\hbox{x}}` | text | 10 | 144 | not supported by the TeX-rule layout: vcenter |
| `\vcenter{\hbox{x}}` | display | 10 | 144 | not supported by the TeX-rule layout: vcenter |
| `\raise2pt\hbox{x}` | text | 10 | none | KaTeX parse error: Undefined control sequence: \raise at position 1: \̲r̲a̲i̲s̲e̲2pt\hbox{x} |
| `\raise2pt\hbox{x}` | display | 10 | none | KaTeX parse error: Undefined control sequence: \raise at position 1: \̲r̲a̲i̲s̲e̲2pt\hbox{x} |
| `\lower2pt\hbox{x}` | text | 10 | none | KaTeX parse error: Undefined control sequence: \lower at position 1: \̲l̲o̲w̲e̲r̲2pt\hbox{x} |
| `\lower2pt\hbox{x}` | display | 10 | none | KaTeX parse error: Undefined control sequence: \lower at position 1: \̲l̲o̲w̲e̲r̲2pt\hbox{x} |
| `\mathsurround=3pt a` | text | 10 | none | KaTeX parse error: Undefined control sequence: \mathsurround at position 1: \̲m̲a̲t̲h̲s̲u̲r̲r̲o̲u̲n̲d̲=3pt a |
| `\mathsurround=3pt a` | display | 10 | none | KaTeX parse error: Undefined control sequence: \mathsurround at position 1: \̲m̲a̲t̲h̲s̲u̲r̲r̲o̲u̲n̲d̲=3pt a |
| `\rule{1pt}{1em}` | text | 10 | 0 | not supported by the TeX-rule layout: rule |
| `\rule{1pt}{1em}` | display | 10 | 0 | not supported by the TeX-rule layout: rule |
| `\rule[-2pt]{3pt}{2pt}` | text | 10 | 0 | not supported by the TeX-rule layout: rule |
| `\rule[-2pt]{3pt}{2pt}` | display | 10 | 0 | not supported by the TeX-rule layout: rule |
| `x\hbox to 10pt{\hfil a}y` | text | 10 | none | KaTeX parse error: Undefined control sequence: \hfil at position 16: x\hbox to 10pt{\̲h̲f̲i̲l̲ ̲a}y |
| `x\hbox to 10pt{\hfil a}y` | display | 10 | none | KaTeX parse error: Undefined control sequence: \hfil at position 16: x\hbox to 10pt{\̲h̲f̲i̲l̲ ̲a}y |
| `\mathchar"0161` | text | 10 | none | KaTeX parse error: Undefined control sequence: \mathchar at position 1: \̲m̲a̲t̲h̲c̲h̲a̲r̲"0161 |
| `\mathchar"0161` | display | 10 | none | KaTeX parse error: Undefined control sequence: \mathchar at position 1: \̲m̲a̲t̲h̲c̲h̲a̲r̲"0161 |
| `\fam1 a` | text | 10 | none | KaTeX parse error: Undefined control sequence: \fam at position 1: \̲f̲a̲m̲1 a |
| `\fam1 a` | display | 10 | none | KaTeX parse error: Undefined control sequence: \fam at position 1: \̲f̲a̲m̲1 a |
| `\hbox{$x^2$}` | text | 10 | 31549 | not supported by the TeX-rule layout: a box that is not plain text |
| `\hbox{$x^2$}` | display | 10 | 31549 | not supported by the TeX-rule layout: a box that is not plain text |
| `\vrule` | text | 10 | none | KaTeX parse error: Undefined control sequence: \vrule at position 1: \̲v̲r̲u̲l̲e̲ |
| `\vrule` | display | 10 | none | KaTeX parse error: Undefined control sequence: \vrule at position 1: \̲v̲r̲u̲l̲e̲ |
| `a\nonscript\mskip 4mu b` | text | 10 | none | KaTeX parse error: Undefined control sequence: \nonscript at position 2: a\̲n̲o̲n̲s̲c̲r̲i̲p̲t̲\mskip 4mu b |
| `a\nonscript\mskip 4mu b` | display | 10 | none | KaTeX parse error: Undefined control sequence: \nonscript at position 2: a\̲n̲o̲n̲s̲c̲r̲i̲p̲t̲\mskip 4mu b |
| `x_{a\nonscript\mskip4mu b}` | text | 10 | none | KaTeX parse error: Undefined control sequence: \nonscript at position 5: x_{a\̲n̲o̲n̲s̲c̲r̲i̲p̲t̲\mskip4mu b} |
| `x_{a\nonscript\mskip4mu b}` | display | 10 | none | KaTeX parse error: Undefined control sequence: \nonscript at position 5: x_{a\̲n̲o̲n̲s̲c̲r̲i̲p̲t̲\mskip4mu b} |
| `\frac{a}{\frac{b}{c}}` | text | 11 | 0 | 1.0.1.4.0: hbox 78643 0 0 shift -131072 (0), TeX hbox 377150 487413 205608 shift 0 (3) |
| `\frac{a}{\frac{b}{c}}` | display | 11 | 0 | 1.0.1.4.0: hbox 78643 0 0 shift -179404 (0), TeX hbox 398559 646638 247464 shift 0 (3) |
| `\bigl(x\bigr)` | text | 11 | 0 | 1.1: hbox 328910 28704 832447 shift -581275 (1), TeX hbox 328910 609979 251172 shift 0 (3) |
| `\bigl(x\bigr)` | display | 11 | 0 | 1.1: hbox 328910 28704 832447 shift -581275 (1), TeX hbox 328910 609979 251172 shift 0 (3) |
| `\Bigl(x\Bigr)` | text | 11 | 0 | 1.1: hbox 428579 28704 1263023 shift -796563 (1), TeX hbox 428579 825267 466460 shift 0 (3) |
| `\Bigl(x\Bigr)` | display | 11 | 0 | 1.1: hbox 428579 28704 1263023 shift -796563 (1), TeX hbox 428579 825267 466460 shift 0 (3) |
| `\begin{pmatrix}a&b\\c&d\end{pmatrix}` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\begin{pmatrix}a&b\\c&d\end{pmatrix}` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\begin{bmatrix}1&0\\0&1\end{bmatrix}` | text | 11 | 0 | 1.2.0.3: hbox 1014170 462465 0 shift 0 (7), TeX hbox 1014170 623900 267389 shift 0 (10) |
| `\begin{bmatrix}1&0\\0&1\end{bmatrix}` | display | 11 | 0 | 1.2.0.3: hbox 1014170 462465 0 shift 0 (7), TeX hbox 1014170 623900 267389 shift 0 (10) |
| `\begin{vmatrix}a&b\\c&d\end{vmatrix}` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\begin{vmatrix}a&b\\c&d\end{vmatrix}` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\binom{n}{k}` | text | 11 | 0 | 1.0: hbox 995820 609979 251172 shift 0 (3), TeX hbox 328910 609979 251172 shift 0 (1) |
| `\binom{n}{k}` | display | 11 | 0 | 1.0: hbox 1487238 1040555 681748 shift 0 (3), TeX hbox 528249 1040555 681748 shift 0 (1) |
| `\binom{2n}{n}` | text | 11 | 0 | 1.0: hbox 1274352 656305 251172 shift 0 (3), TeX hbox 328910 609979 251172 shift 0 (1) |
| `\binom{2n}{n}` | display | 11 | 0 | 1.0: hbox 1846048 1040555 681748 shift 0 (3), TeX hbox 528249 1040555 681748 shift 0 (1) |
| `\begin{cases}1 & x>0\\0 & x\le 0\end{cases}` | text | 11 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}1 & x>0\\0 & x\le 0\end{cases}` | display | 11 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `f\colon A\to B` | text | 11 | 0 | 4: kern 79734, TeX glue 79734 0 0 |
| `f\colon A\to B` | display | 11 | 0 | 4: kern 79734, TeX glue 79734 0 0 |
| `(1+x)^n=\sum_{k=0}^n \binom{n}{k}x^k` | text | 11 | 0 | 15.0: hbox 995820 609979 251172 shift 0 (3), TeX hbox 328910 609979 251172 shift 0 (1) |
| `(1+x)^n=\sum_{k=0}^n \binom{n}{k}x^k` | display | 11 | 0 | 14.0: hbox 1487238 1040555 681748 shift 0 (3), TeX hbox 528249 1040555 681748 shift 0 (1) |
| `x_{\binom{n}{k}}` | text | 11 | 0 | 2.0: hbox 279075 538214 179404 shift 1 (1), TeX hbox 279075 538213 179405 shift 0 (1) |
| `x_{\binom{n}{k}}` | display | 11 | 0 | 2.0: hbox 279075 538214 179404 shift 1 (1), TeX hbox 279075 538213 179405 shift 0 (1) |
| `x^{\sqrt{\frac12}}_{\frac{\frac12}{3}}` | text | 11 | 0 | 2.2.1.0.0: hbox 78643 0 0 shift -98304 (0), TeX hbox 397581 407675 183748 shift 0 (3) |
| `x^{\sqrt{\frac12}}_{\frac{\frac12}{3}}` | display | 11 | 0 | 2.2.1.0.0: hbox 78643 0 0 shift -98304 (0), TeX hbox 397581 407675 183748 shift 0 (3) |
| `x^{\scriptscriptstyle\sqrt2}` | text | 11 | 1218 | 2: hbox 666276 365721 47811 shift -260418 (2), TeX hbox 666276 364503 47811 shift -260418 (2) |
| `x^{\scriptscriptstyle\sqrt2}` | display | 11 | 1218 | 2: hbox 666276 365721 47811 shift -296299 (2), TeX hbox 666276 364503 47811 shift -296299 (2) |
| `\dbinom{n}{k}` | text | 11 | 0 | 1.0: hbox 1487238 1040555 681748 shift 0 (1), TeX hbox 528249 1040555 681748 shift 0 (1) |
| `\dbinom{n}{k}` | display | 11 | 0 | 1.0: hbox 1487238 1040555 681748 shift 0 (1), TeX hbox 528249 1040555 681748 shift 0 (1) |
| `\tbinom{n}{k}` | text | 11 | 0 | 1.0: hbox 995820 609979 251172 shift 0 (1), TeX hbox 328910 609979 251172 shift 0 (1) |
| `\tbinom{n}{k}` | display | 11 | 0 | 1.0: hbox 995820 609979 251172 shift 0 (1), TeX hbox 328910 609979 251172 shift 0 (1) |
| `\binom{n+1}{k-1}` | text | 11 | 0 | 1.0: hbox 1707624 656305 302080 shift 0 (3), TeX hbox 328910 609979 251172 shift 0 (1) |
| `\binom{n+1}{k-1}` | display | 11 | 0 | 1.0: hbox 2723134 1040555 681748 shift 0 (3), TeX hbox 528249 1040555 681748 shift 0 (1) |
| `\dbinom{n+1}{k-1}` | text | 11 | 0 | 1.0: hbox 2723134 1040555 681748 shift 0 (1), TeX hbox 528249 1040555 681748 shift 0 (1) |
| `\dbinom{n+1}{k-1}` | display | 11 | 0 | 1.0: hbox 2723134 1040555 681748 shift 0 (1), TeX hbox 528249 1040555 681748 shift 0 (1) |
| `\tbinom{n+1}{k-1}` | text | 11 | 0 | 1.0: hbox 1707624 656305 302080 shift 0 (1), TeX hbox 328910 609979 251172 shift 0 (1) |
| `\tbinom{n+1}{k-1}` | display | 11 | 0 | 1.0: hbox 1707624 656305 302080 shift 0 (1), TeX hbox 328910 609979 251172 shift 0 (1) |
| `\binom{\frac12}{k}` | text | 11 | 0 | 1.0: hbox 1055401 831139 292422 shift 0 (3), TeX hbox 328910 609979 251172 shift 0 (1) |
| `\binom{\frac12}{k}` | display | 11 | 0 | 1.0: hbox 1492316 1105898 681748 shift 0 (3), TeX hbox 528249 1040555 681748 shift 0 (1) |
| `\binom{n}{\frac{k}{2}}` | text | 11 | 0 | 1.0: hbox 1083164 609979 456888 shift 0 (3), TeX hbox 328910 609979 251172 shift 0 (1) |
| `\binom{n}{\frac{k}{2}}` | display | 11 | 0 | 1.0: hbox 1517802 1040555 739715 shift 0 (3), TeX hbox 528249 1040555 681748 shift 0 (1) |
| `\binom{a}{b}^2` | text | 11 | 0 | 1.0: hbox 953707 609979 251172 shift 0 (3), TeX hbox 328910 609979 251172 shift 0 (1) |
| `\binom{a}{b}^2` | display | 11 | 0 | 1.0: hbox 1435824 1040555 681748 shift 0 (3), TeX hbox 528249 1040555 681748 shift 0 (1) |
| `\binom{n}{k}_q` | text | 11 | 0 | 1.0: hbox 995820 609979 251172 shift 0 (3), TeX hbox 328910 609979 251172 shift 0 (1) |
| `\binom{n}{k}_q` | display | 11 | 0 | 1.0: hbox 1487238 1040555 681748 shift 0 (3), TeX hbox 528249 1040555 681748 shift 0 (1) |
| `\genfrac{(}{)}{0pt}{}{n}{k}` | text | 11 | 0 | 1.0: hbox 995820 609979 251172 shift 0 (3), TeX hbox 328910 609979 251172 shift 0 (1) |
| `\genfrac{(}{)}{0pt}{}{n}{k}` | display | 11 | 0 | 1.0: hbox 1487238 1040555 681748 shift 0 (3), TeX hbox 528249 1040555 681748 shift 0 (1) |
| `\genfrac{(}{)}{0.4pt}{}{n}{k}` | text | 11 | 0 | 1.0: hbox 995820 609979 251172 shift 0 (3), TeX hbox 328910 609979 251172 shift 0 (1) |
| `\genfrac{(}{)}{0.4pt}{}{n}{k}` | display | 11 | 0 | 1.0: hbox 1487238 1040555 681748 shift 0 (3), TeX hbox 528249 1040555 681748 shift 0 (1) |
| `\genfrac{[}{]}{1pt}{0}{a}{b}` | text | 11 | 0 | 1.0: hbox 1136816 1040555 681748 shift 0 (1), TeX hbox 378745 1040555 681748 shift 0 (1) |
| `\genfrac{[}{]}{1pt}{0}{a}{b}` | display | 11 | 0 | 1.0: hbox 1136816 1040555 681748 shift 0 (1), TeX hbox 378745 1040555 681748 shift 0 (1) |
| `\genfrac{\{}{\}}{0pt}{1}{a}{b}` | text | 11 | 0 | 1.0: hbox 1133111 609979 251172 shift 0 (1), TeX hbox 418612 609979 251172 shift 0 (1) |
| `\genfrac{\{}{\}}{0pt}{1}{a}{b}` | display | 11 | 0 | 1.0: hbox 1133111 609979 251172 shift 0 (1), TeX hbox 418612 609979 251172 shift 0 (1) |
| `\genfrac{\langle}{\rangle}{0pt}{2}{a}{b}` | text | 11 | 0 | 1.0: hbox 823525 538213 205608 shift 0 (1), TeX hbox 279075 538213 179405 shift 0 (1) |
| `\genfrac{\langle}{\rangle}{0pt}{2}{a}{b}` | display | 11 | 0 | 1.0: hbox 823525 538213 205608 shift 0 (1), TeX hbox 279075 538213 179405 shift 0 (1) |
| `\genfrac{\|}{\|}{0.8pt}{3}{x+1}{y}` | text | 11 | 241392 | 1: hbox 1039738 484965 245291 shift 0 (1), TeX hbox 1281130 538213 245291 shift 0 (5) |
| `\genfrac{\|}{\|}{0.8pt}{3}{x+1}{y}` | display | 11 | 241392 | 1: hbox 1039738 484965 245291 shift 0 (1), TeX hbox 1281130 538213 245291 shift 0 (5) |
| `\genfrac{(}{]}{0pt}{}{a}{b}` | text | 11 | 0 | 1.0: hbox 923806 609979 251172 shift 0 (3), TeX hbox 328910 609979 251172 shift 0 (1) |
| `\genfrac{(}{]}{0pt}{}{a}{b}` | display | 11 | 0 | 1.0: hbox 1286320 1040555 681748 shift 0 (3), TeX hbox 528249 1040555 681748 shift 0 (1) |
| `\frac{1}{\frac{1}{\frac{1}{x}}}` | text | 11 | 0 | 1.0.1.4.0: hbox 78643 0 0 shift -131072 (0), TeX hbox 589003 467751 480825 shift 0 (3) |
| `\frac{1}{\frac{1}{\frac{1}{x}}}` | display | 11 | 0 | 1.0.1.4.0: hbox 78643 0 0 shift -179404 (0), TeX hbox 589003 620424 537011 shift 0 (3) |
| `\frac{\frac{a}{b}}{\frac{c}{d}}` | text | 11 | 0 | 1.0.1.0.0: hbox 78643 0 0 shift -131072 (0), TeX hbox 422661 383646 205608 shift 0 (3) |
| `\frac{\frac{a}{b}}{\frac{c}{d}}` | display | 11 | 0 | 1.0.1.0.0: hbox 78643 0 0 shift -179404 (0), TeX hbox 453173 508284 247464 shift 0 (3) |
| `\frac{\frac{\frac{a}{b}}{c}}{d}` | text | 11 | 0 | 1.0.1.0.0: hbox 78643 0 0 shift -131072 (0), TeX hbox 579947 693442 205608 shift 0 (3) |
| `\frac{\frac{\frac{a}{b}}{c}}{d}` | display | 11 | 0 | 1.0.1.0.0: hbox 78643 0 0 shift -179404 (0), TeX hbox 579947 811714 247464 shift 0 (3) |
| `\frac{a}{\frac{b}{\frac{c}{d}}}` | text | 11 | 0 | 1.0.1.4.0: hbox 78643 0 0 shift -131072 (0), TeX hbox 567203 487413 431298 shift 0 (3) |
| `\frac{a}{\frac{b}{\frac{c}{d}}}` | display | 11 | 0 | 1.0.1.4.0: hbox 78643 0 0 shift -179404 (0), TeX hbox 567203 646638 453072 shift 0 (3) |
| `\sqrt{\frac{\frac12}{3}}` | text | 11 | 0 | 1.1.3.1.0.0: hbox 78643 0 0 shift -131072 (0), TeX hbox 397581 467751 205608 shift 0 (3) |
| `\sqrt{\frac{\frac12}{3}}` | display | 11 | 0 | 1.1.3.1.0.0: hbox 78643 0 0 shift -179404 (0), TeX hbox 435818 620424 247464 shift 0 (3) |
| `\sqrt{\binom{n}{k}}` | text | 11 | 0 | 1.1.3.0: hbox 328910 28704 832447 shift -581275 (1), TeX hbox 328910 609979 251172 shift 0 (1) |
| `\sqrt{\binom{n}{k}}` | display | 11 | 0 | 1.1.3.0: hbox 528249 28704 1693599 shift -1011851 (1), TeX hbox 528249 1040555 681748 shift 0 (1) |
| `\iint\limits_a^b` | text | 11 | 109954 | not supported by the TeX-rule layout: \iint with \limits or \nolimits |
| `\iint\limits_a^b` | display | 11 | 99193 | not supported by the TeX-rule layout: \iint with \limits or \nolimits |
| `\iint\nolimits_a^b` | text | 11 | 129640 | not supported by the TeX-rule layout: \iint with \limits or \nolimits |
| `\iint\nolimits_a^b` | display | 11 | 118880 | not supported by the TeX-rule layout: \iint with \limits or \nolimits |
| `\iiint\limits_a^b` | text | 11 | 219752 | not supported by the TeX-rule layout: \iiint with \limits or \nolimits |
| `\iiint\limits_a^b` | display | 11 | 213061 | not supported by the TeX-rule layout: \iiint with \limits or \nolimits |
| `\iiint\nolimits_a^b` | text | 11 | 239438 | not supported by the TeX-rule layout: \iiint with \limits or \nolimits |
| `\iiint\nolimits_a^b` | display | 11 | 232747 | not supported by the TeX-rule layout: \iiint with \limits or \nolimits |
| `\sum_{\substack{i<j\\ j<n}}x_{ij}` | text | 11 | 128092 | not supported by the TeX-rule layout: array cells in script style |
| `\sum_{\substack{i<j\\ j<n}}x_{ij}` | display | 11 | 110403 | not supported by the TeX-rule layout: array cells in script style |
| `\prod_{\sqrt{n}}^{\binom{n}{k}}` | text | 11 | 0 | 2.0.0: hbox 279075 538214 179404 shift 1 (1), TeX hbox 279075 538213 179405 shift 0 (1) |
| `\prod_{\sqrt{n}}^{\binom{n}{k}}` | display | 11 | 0 | 1.1.1: hbox 279075 538214 179404 shift 1 (1), TeX hbox 279075 538213 179405 shift 0 (1) |
| `\sum_{k}\binom{n}{k}` | text | 11 | 0 | 4.0: hbox 995820 609979 251172 shift 0 (3), TeX hbox 328910 609979 251172 shift 0 (1) |
| `\sum_{k}\binom{n}{k}` | display | 11 | 0 | 3.0: hbox 1487238 1040555 681748 shift 0 (3), TeX hbox 528249 1040555 681748 shift 0 (1) |
| `\det\begin{pmatrix}a&b\\c&d\end{pmatrix}` | text | 11 | 0 | 3.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\det\begin{pmatrix}a&b\\c&d\end{pmatrix}` | display | 11 | 0 | 3.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\hat{\imath}` | text | 11 | 327 | not supported by the TeX-rule layout: htmlmathml |
| `\hat{\imath}` | display | 11 | 327 | not supported by the TeX-rule layout: htmlmathml |
| `\hat{\jmath}` | text | 11 | 22 | not supported by the TeX-rule layout: htmlmathml |
| `\hat{\jmath}` | display | 11 | 22 | not supported by the TeX-rule layout: htmlmathml |
| `\check{\imath}` | text | 11 | 327 | not supported by the TeX-rule layout: htmlmathml |
| `\check{\imath}` | display | 11 | 327 | not supported by the TeX-rule layout: htmlmathml |
| `\check{\jmath}` | text | 11 | 22 | not supported by the TeX-rule layout: htmlmathml |
| `\check{\jmath}` | display | 11 | 22 | not supported by the TeX-rule layout: htmlmathml |
| `\tilde{\imath}` | text | 11 | 327 | not supported by the TeX-rule layout: htmlmathml |
| `\tilde{\imath}` | display | 11 | 327 | not supported by the TeX-rule layout: htmlmathml |
| `\tilde{\jmath}` | text | 11 | 22 | not supported by the TeX-rule layout: htmlmathml |
| `\tilde{\jmath}` | display | 11 | 22 | not supported by the TeX-rule layout: htmlmathml |
| `\acute{\imath}` | text | 11 | 327 | not supported by the TeX-rule layout: htmlmathml |
| `\acute{\imath}` | display | 11 | 327 | not supported by the TeX-rule layout: htmlmathml |
| `\acute{\jmath}` | text | 11 | 22 | not supported by the TeX-rule layout: htmlmathml |
| `\acute{\jmath}` | display | 11 | 22 | not supported by the TeX-rule layout: htmlmathml |
| `\grave{\imath}` | text | 11 | 327 | not supported by the TeX-rule layout: htmlmathml |
| `\grave{\imath}` | display | 11 | 327 | not supported by the TeX-rule layout: htmlmathml |
| `\grave{\jmath}` | text | 11 | 22 | not supported by the TeX-rule layout: htmlmathml |
| `\grave{\jmath}` | display | 11 | 22 | not supported by the TeX-rule layout: htmlmathml |
| `\dot{\imath}` | text | 11 | 327 | not supported by the TeX-rule layout: htmlmathml |
| `\dot{\imath}` | display | 11 | 327 | not supported by the TeX-rule layout: htmlmathml |
| `\dot{\jmath}` | text | 11 | 22 | not supported by the TeX-rule layout: htmlmathml |
| `\dot{\jmath}` | display | 11 | 22 | not supported by the TeX-rule layout: htmlmathml |
| `\ddot{\imath}` | text | 11 | 327 | not supported by the TeX-rule layout: htmlmathml |
| `\ddot{\imath}` | display | 11 | 327 | not supported by the TeX-rule layout: htmlmathml |
| `\ddot{\jmath}` | text | 11 | 22 | not supported by the TeX-rule layout: htmlmathml |
| `\ddot{\jmath}` | display | 11 | 22 | not supported by the TeX-rule layout: htmlmathml |
| `\breve{\imath}` | text | 11 | 327 | not supported by the TeX-rule layout: htmlmathml |
| `\breve{\imath}` | display | 11 | 327 | not supported by the TeX-rule layout: htmlmathml |
| `\breve{\jmath}` | text | 11 | 22 | not supported by the TeX-rule layout: htmlmathml |
| `\breve{\jmath}` | display | 11 | 22 | not supported by the TeX-rule layout: htmlmathml |
| `\bar{\imath}` | text | 11 | 327 | not supported by the TeX-rule layout: htmlmathml |
| `\bar{\imath}` | display | 11 | 327 | not supported by the TeX-rule layout: htmlmathml |
| `\bar{\jmath}` | text | 11 | 22 | not supported by the TeX-rule layout: htmlmathml |
| `\bar{\jmath}` | display | 11 | 22 | not supported by the TeX-rule layout: htmlmathml |
| `\vec{\imath}` | text | 11 | 327 | not supported by the TeX-rule layout: htmlmathml |
| `\vec{\imath}` | display | 11 | 327 | not supported by the TeX-rule layout: htmlmathml |
| `\vec{\jmath}` | text | 11 | 318 | not supported by the TeX-rule layout: htmlmathml |
| `\vec{\jmath}` | display | 11 | 318 | not supported by the TeX-rule layout: htmlmathml |
| `\mathring{\imath}` | text | 11 | 327 | not supported by the TeX-rule layout: htmlmathml |
| `\mathring{\imath}` | display | 11 | 327 | not supported by the TeX-rule layout: htmlmathml |
| `\mathring{\jmath}` | text | 11 | 22 | not supported by the TeX-rule layout: htmlmathml |
| `\mathring{\jmath}` | display | 11 | 22 | not supported by the TeX-rule layout: htmlmathml |
| `\dddot x` | text | 11 | 142002 | not supported by the TeX-rule layout: raisebox |
| `\dddot x` | display | 11 | 142002 | not supported by the TeX-rule layout: raisebox |
| `\dddot{x}^2` | text | 11 | 143880 | not supported by the TeX-rule layout: raisebox |
| `\dddot{x}^2` | display | 11 | 143880 | not supported by the TeX-rule layout: raisebox |
| `\widehat{\widehat{x}}` | text | 11 | 0 | 1.0: hbox 0 518281 0 shift 5732 (1), TeX hbox 0 518281 0 shift 25665 (1) |
| `\widehat{\widehat{x}}` | display | 11 | 0 | 1.0: hbox 0 518281 0 shift 5732 (1), TeX hbox 0 518281 0 shift 25665 (1) |
| `\hat{\hat{x}}` | text | 11 | 0 | 1: vbox 410139 687718 0 shift 0 (3), TeX vbox 450007 687718 0 shift 0 (3) |
| `\hat{\hat{x}}` | display | 11 | 0 | 1: vbox 410139 687718 0 shift 0 (3), TeX vbox 450007 687718 0 shift 0 (3) |
| `\hat{\tilde{x}}` | text | 11 | 0 | 1: vbox 410139 668640 0 shift 0 (3), TeX vbox 450007 668640 0 shift 0 (3) |
| `\hat{\tilde{x}}` | display | 11 | 0 | 1: vbox 410139 668640 0 shift 0 (3), TeX vbox 450007 668640 0 shift 0 (3) |
| `\tilde{\hat{x}}` | text | 11 | 0 | 1: vbox 410139 668640 0 shift 0 (3), TeX vbox 450007 668640 0 shift 0 (3) |
| `\tilde{\hat{x}}` | display | 11 | 0 | 1: vbox 410139 668640 0 shift 0 (3), TeX vbox 450007 668640 0 shift 0 (3) |
| `\bar{\bar{x}}` | text | 11 | 0 | 1: vbox 410139 505920 0 shift 0 (3), TeX vbox 450007 505920 0 shift 0 (3) |
| `\bar{\bar{x}}` | display | 11 | 0 | 1: vbox 410139 505920 0 shift 0 (3), TeX vbox 450007 505920 0 shift 0 (3) |
| `\dot{\hat{x}}` | text | 11 | 0 | 1: vbox 410139 668640 0 shift 0 (3), TeX vbox 450007 668640 0 shift 0 (3) |
| `\dot{\hat{x}}` | display | 11 | 0 | 1: vbox 410139 668640 0 shift 0 (3), TeX vbox 450007 668640 0 shift 0 (3) |
| `\ddot{\vec{x}}` | text | 11 | 0 | 1: vbox 410139 682992 0 shift 0 (3), TeX vbox 450007 682992 0 shift 0 (3) |
| `\ddot{\vec{x}}` | display | 11 | 0 | 1: vbox 410139 682992 0 shift 0 (3), TeX vbox 450007 682992 0 shift 0 (3) |
| `\vec{\dot{x}}` | text | 11 | 0 | 1: vbox 410139 682992 0 shift 0 (3), TeX vbox 450007 682992 0 shift 0 (3) |
| `\vec{\dot{x}}` | display | 11 | 0 | 1: vbox 410139 682992 0 shift 0 (3), TeX vbox 450007 682992 0 shift 0 (3) |
| `\hat{\bar{A}}` | text | 11 | 0 | 1: vbox 538215 778217 0 shift 0 (3), TeX vbox 737559 778217 0 shift 0 (3) |
| `\hat{\bar{A}}` | display | 11 | 0 | 1: vbox 538215 778217 0 shift 0 (3), TeX vbox 737559 778217 0 shift 0 (3) |
| `\acute{\grave{x}}` | text | 11 | 0 | 1: vbox 410139 687718 0 shift 0 (3), TeX vbox 450007 687718 0 shift 0 (3) |
| `\acute{\grave{x}}` | display | 11 | 0 | 1: vbox 410139 687718 0 shift 0 (3), TeX vbox 450007 687718 0 shift 0 (3) |
| `\check{\breve{y}}` | text | 11 | 0 | 1: vbox 377582 640376 139537 shift 0 (3), TeX vbox 457318 640376 139537 shift 0 (3) |
| `\check{\breve{y}}` | display | 11 | 0 | 1: vbox 377582 640376 139537 shift 0 (3), TeX vbox 457318 640376 139537 shift 0 (3) |
| `\vec{\vec{v}}` | text | 11 | 0 | 1: vbox 373594 716422 0 shift 0 (3), TeX vbox 413462 716422 0 shift 0 (3) |
| `\vec{\vec{v}}` | display | 11 | 0 | 1: vbox 373594 716422 0 shift 0 (3), TeX vbox 413462 716422 0 shift 0 (3) |
| `\dot{\dot{x}}` | text | 11 | 0 | 1: vbox 410139 649562 0 shift 0 (3), TeX vbox 450007 649562 0 shift 0 (3) |
| `\dot{\dot{x}}` | display | 11 | 0 | 1: vbox 410139 649562 0 shift 0 (3), TeX vbox 450007 649562 0 shift 0 (3) |
| `\tilde{\tilde{f}}` | text | 11 | 0 | 1: vbox 428580 838934 139537 shift 0 (3), TeX vbox 667792 838934 139537 shift 0 (3) |
| `\tilde{\tilde{f}}` | display | 11 | 0 | 1: vbox 428580 838934 139537 shift 0 (3), TeX vbox 667792 838934 139537 shift 0 (3) |
| `\overrightarrow{AB}` | text | 11 | 111320 | not supported by the TeX-rule layout: accent \overrightarrow |
| `\overrightarrow{AB}` | display | 11 | 111320 | not supported by the TeX-rule layout: accent \overrightarrow |
| `\overleftarrow{AB}` | text | 11 | 111320 | not supported by the TeX-rule layout: accent \overleftarrow |
| `\overleftarrow{AB}` | display | 11 | 111320 | not supported by the TeX-rule layout: accent \overleftarrow |
| `\overrightarrow{x}` | text | 11 | 111325 | not supported by the TeX-rule layout: accent \overrightarrow |
| `\overrightarrow{x}` | display | 11 | 111325 | not supported by the TeX-rule layout: accent \overrightarrow |
| `\underrightarrow{AB}` | text | 11 | 21088 | not supported by the TeX-rule layout: accentUnder |
| `\underrightarrow{AB}` | display | 11 | 21088 | not supported by the TeX-rule layout: accentUnder |
| `\overbrace{a+b+c}^{3}` | text | 11 | 100227 | not supported by the TeX-rule layout: horizBrace |
| `\overbrace{a+b+c}^{3}` | display | 11 | 100227 | not supported by the TeX-rule layout: horizBrace |
| `\underbrace{a+b+c}_{3}` | text | 11 | 76307 | not supported by the TeX-rule layout: horizBrace |
| `\underbrace{a+b+c}_{3}` | display | 11 | 76307 | not supported by the TeX-rule layout: horizBrace |
| `\overbrace{x}` | text | 11 | 143534 | not supported by the TeX-rule layout: horizBrace |
| `\overbrace{x}` | display | 11 | 143534 | not supported by the TeX-rule layout: horizBrace |
| `\underbrace{x}` | text | 11 | 143534 | not supported by the TeX-rule layout: horizBrace |
| `\underbrace{x}` | display | 11 | 143534 | not supported by the TeX-rule layout: horizBrace |
| `\overset{a}{=}` | text | 11 | 0 | 1.0.3.0: char cmr10 61 558150 263276 -95534, TeX kern 0 |
| `\overset{a}{=}` | display | 11 | 0 | 1.0.3.0: char cmr10 61 558150 263276 -95534, TeX kern 0 |
| `\underset{a}{=}` | text | 11 | 0 | 1.0.0.0: char cmr10 61 558150 263276 -95534, TeX kern 0 |
| `\underset{a}{=}` | display | 11 | 0 | 1.0.0.0: char cmr10 61 558150 263276 -95534, TeX kern 0 |
| `\xrightarrow{a}` | text | 11 | 325023 | not supported by the TeX-rule layout: xArrow |
| `\xrightarrow{a}` | display | 11 | 325023 | not supported by the TeX-rule layout: xArrow |
| `\xleftarrow[b]{a}` | text | 11 | 325023 | not supported by the TeX-rule layout: xArrow |
| `\xleftarrow[b]{a}` | display | 11 | 325023 | not supported by the TeX-rule layout: xArrow |
| `\left( \begin{matrix}a&b\\c&d\end{matrix}\right)` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left( \begin{matrix}a&b\\c&d\end{matrix}\right)` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left( \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right)` | text | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left( \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right)` | display | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left( \frac{\frac12}{\frac34}\right)` | text | 11 | 0 | 1.1.0.1.0.0: hbox 78643 0 0 shift -131072 (0), TeX hbox 397581 467751 205608 shift 0 (3) |
| `\left( \frac{\frac12}{\frac34}\right)` | display | 11 | 0 | 1.1.0.1.0.0: hbox 78643 0 0 shift -179404 (0), TeX hbox 435818 620424 247464 shift 0 (3) |
| `\left[ \begin{matrix}a&b\\c&d\end{matrix}\right]` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left[ \begin{matrix}a&b\\c&d\end{matrix}\right]` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left[ \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right]` | text | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left[ \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right]` | display | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left[ \frac{\frac12}{\frac34}\right]` | text | 11 | 0 | 1.1.0.1.0.0: hbox 78643 0 0 shift -131072 (0), TeX hbox 397581 467751 205608 shift 0 (3) |
| `\left[ \frac{\frac12}{\frac34}\right]` | display | 11 | 0 | 1.1.0.1.0.0: hbox 78643 0 0 shift -179404 (0), TeX hbox 435818 620424 247464 shift 0 (3) |
| `\left\{ \begin{matrix}a&b\\c&d\end{matrix}\right\}` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\{ \begin{matrix}a&b\\c&d\end{matrix}\right\}` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\{ \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\}` | text | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\{ \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\}` | display | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\langle \begin{matrix}a&b\\c&d\end{matrix}\right\rangle` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\langle \begin{matrix}a&b\\c&d\end{matrix}\right\rangle` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\langle \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rangle` | text | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\langle \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rangle` | display | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\| \begin{matrix}a&b\\c&d\end{matrix}\right\|` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\| \begin{matrix}a&b\\c&d\end{matrix}\right\|` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\| \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\|` | text | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\| \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\|` | display | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\\| \begin{matrix}a&b\\c&d\end{matrix}\right\\|` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\\| \begin{matrix}a&b\\c&d\end{matrix}\right\\|` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\\| \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\\|` | text | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\\| \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\\|` | display | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\lfloor \begin{matrix}a&b\\c&d\end{matrix}\right\rfloor` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\lfloor \begin{matrix}a&b\\c&d\end{matrix}\right\rfloor` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\lfloor \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rfloor` | text | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\lfloor \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rfloor` | display | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\lceil \begin{matrix}a&b\\c&d\end{matrix}\right\rceil` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\lceil \begin{matrix}a&b\\c&d\end{matrix}\right\rceil` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\lceil \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rceil` | text | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\lceil \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rceil` | display | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left/ \begin{matrix}a&b\\c&d\end{matrix}\right\backslash` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left/ \begin{matrix}a&b\\c&d\end{matrix}\right\backslash` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left/ \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\backslash` | text | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left/ \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\backslash` | display | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\uparrow \begin{matrix}a&b\\c&d\end{matrix}\right\downarrow` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\uparrow \begin{matrix}a&b\\c&d\end{matrix}\right\downarrow` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\uparrow \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\downarrow` | text | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\uparrow \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\downarrow` | display | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\Uparrow \begin{matrix}a&b\\c&d\end{matrix}\right\updownarrow` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\Uparrow \begin{matrix}a&b\\c&d\end{matrix}\right\updownarrow` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\Uparrow \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\updownarrow` | text | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\Uparrow \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\updownarrow` | display | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left. \begin{matrix}a&b\\c&d\end{matrix}\right)` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left. \begin{matrix}a&b\\c&d\end{matrix}\right)` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left. \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right)` | text | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left. \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right)` | display | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left( \begin{matrix}a&b\\c&d\end{matrix}\right.` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left( \begin{matrix}a&b\\c&d\end{matrix}\right.` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left( \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right.` | text | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left( \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right.` | display | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left( \frac{\frac12}{\frac34}\right.` | text | 11 | 0 | 1.1.0.1.0.0: hbox 78643 0 0 shift -131072 (0), TeX hbox 397581 467751 205608 shift 0 (3) |
| `\left( \frac{\frac12}{\frac34}\right.` | display | 11 | 0 | 1.1.0.1.0.0: hbox 78643 0 0 shift -179404 (0), TeX hbox 435818 620424 247464 shift 0 (3) |
| `\left. \begin{matrix}a&b\\c&d\end{matrix}\right.` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left. \begin{matrix}a&b\\c&d\end{matrix}\right.` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left. \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right.` | text | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left. \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right.` | display | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\Downarrow \begin{matrix}a&b\\c&d\end{matrix}\right\Updownarrow` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\Downarrow \begin{matrix}a&b\\c&d\end{matrix}\right\Updownarrow` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\Downarrow \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\Updownarrow` | text | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\Downarrow \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\Updownarrow` | display | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\backslash \begin{matrix}a&b\\c&d\end{matrix}\right/` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\backslash \begin{matrix}a&b\\c&d\end{matrix}\right/` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\backslash \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right/` | text | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\backslash \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right/` | display | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\lvert \begin{matrix}a&b\\c&d\end{matrix}\right\rvert` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\lvert \begin{matrix}a&b\\c&d\end{matrix}\right\rvert` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\lvert \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rvert` | text | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\lvert \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rvert` | display | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\lVert \begin{matrix}a&b\\c&d\end{matrix}\right\rVert` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\lVert \begin{matrix}a&b\\c&d\end{matrix}\right\rVert` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\lVert \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rVert` | text | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\lVert \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rVert` | display | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\lbrace \begin{matrix}a&b\\c&d\end{matrix}\right\rbrace` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\lbrace \begin{matrix}a&b\\c&d\end{matrix}\right\rbrace` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\lbrace \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rbrace` | text | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\lbrace \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rbrace` | display | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\lbrack \begin{matrix}a&b\\c&d\end{matrix}\right\rbrack` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\lbrack \begin{matrix}a&b\\c&d\end{matrix}\right\rbrack` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\lbrack \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rbrack` | text | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left\lbrack \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rbrack` | display | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\left(\begin{array}{cc}a&b\\c&d\end{array}\right)` | text | 11 | 0 | 1.1.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left(\begin{array}{cc}a&b\\c&d\end{array}\right)` | display | 11 | 0 | 1.1.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\left\{\begin{array}{ll}a&b\\c&d\end{array}\right.` | text | 11 | 0 | 1.1.0.3: hbox 1028871 498346 0 shift 0 (6), TeX hbox 1028871 623900 267389 shift 0 (9) |
| `\left\{\begin{array}{ll}a&b\\c&d\end{array}\right.` | display | 11 | 0 | 1.1.0.3: hbox 1028871 498346 0 shift 0 (6), TeX hbox 1028871 623900 267389 shift 0 (9) |
| `\text{\textbf{a}}` | text | 11 | 6143 | not supported by the TeX-rule layout: text that is not plain characters |
| `\text{\textbf{a}}` | display | 11 | 6143 | not supported by the TeX-rule layout: text that is not plain characters |
| `\text{a$x$b}` | text | 11 | 7894 | not supported by the TeX-rule layout: text that is not plain characters |
| `\text{a$x$b}` | display | 11 | 7894 | not supported by the TeX-rule layout: text that is not plain characters |
| `\boldsymbol{\alpha}` | text | 11 | 255 | not supported by the TeX-rule layout: \boldsymbol |
| `\boldsymbol{\alpha}` | display | 11 | 255 | not supported by the TeX-rule layout: \boldsymbol |
| `\boldsymbol{x}` | text | 11 | 19 | not supported by the TeX-rule layout: \boldsymbol |
| `\boldsymbol{x}` | display | 11 | 19 | not supported by the TeX-rule layout: \boldsymbol |
| `a\hphantom{b}c` | text | 11 | 0 | 2.0: math false, TeX nothing |
| `a\hphantom{b}c` | display | 11 | 0 | 2.0: math false, TeX nothing |
| `\smash{\frac12}` | text | 11 | 0 | 1: hbox 435818 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `\smash{\frac12}` | display | 11 | 0 | 1: hbox 516096 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\smash{b}c` | text | 11 | 0 | 2: hbox 307978 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\smash{b}c` | display | 11 | 0 | 2: hbox 307978 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `\smash{x_i}` | text | 11 | 0 | 1: hbox 632565 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `\smash{x_i}` | display | 11 | 0 | 1: hbox 632565 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `\hphantom{\frac12}` | text | 11 | 0 | 1.0: math false, TeX nothing |
| `\hphantom{\frac12}` | display | 11 | 0 | 1.0: math false, TeX nothing |
| `\smash[t]{\frac12}` | text | 11 | 0 | 1: hbox 435818 0 247464 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `\smash[t]{\frac12}` | display | 11 | 0 | 1: hbox 516096 0 492251 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `\smash[b]{\frac12}` | text | 11 | 0 | 1: hbox 435818 620424 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `\smash[b]{\frac12}` | display | 11 | 0 | 1: hbox 516096 947939 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\mkern-3mu b` | text | 11 | 0 | 2: glue -119601 0 0, TeX kern -119601 |
| `a\mkern-3mu b` | display | 11 | 0 | 2: glue -119601 0 0, TeX kern -119601 |
| `a\kern2pt b` | text | 11 | 0 | 2: glue 131072 0 0, TeX kern 131072 |
| `a\kern2pt b` | display | 11 | 0 | 2: glue 131072 0 0, TeX kern 131072 |
| `a\hskip 3pt plus 1pt b` | text | 11 | 2333660 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `a\hskip 3pt plus 1pt b` | display | 11 | 2333660 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `a\negmedspace b` | text | 11 | 0 | 2: kern -159468, TeX glue -159468 -79734 -159468 |
| `a\negmedspace b` | display | 11 | 0 | 2: kern -159468, TeX glue -159468 -79734 -159468 |
| `a\negthickspace b` | text | 11 | 0 | 2: kern -199335, TeX glue -199335 -199335 0 |
| `a\negthickspace b` | display | 11 | 0 | 2: kern -199335, TeX glue -199335 -199335 0 |
| `a\mskip 5mu b` | text | 11 | 0 | 2: glue 199335 199335 0, TeX glue 199335 0 0 |
| `a\mskip 5mu b` | display | 11 | 0 | 2: glue 199335 199335 0, TeX glue 199335 0 0 |
| `a\enspace b` | text | 11 | 0 | 2: glue 358809 0 0, TeX kern 358809 |
| `a\enspace b` | display | 11 | 0 | 2: glue 358809 0 0, TeX kern 358809 |
| `\vdots` | text | 11 | 82857 | not supported by the TeX-rule layout: symbol \varvdots |
| `\vdots` | display | 11 | 82857 | not supported by the TeX-rule layout: symbol \varvdots |
| `\ddots` | text | 11 | 402972 | not supported by the TeX-rule layout: symbol \ddots |
| `\ddots` | display | 11 | 402972 | not supported by the TeX-rule layout: symbol \ddots |
| `\vdots+x` | text | 11 | 82857 | not supported by the TeX-rule layout: symbol \varvdots |
| `\vdots+x` | display | 11 | 82857 | not supported by the TeX-rule layout: symbol \varvdots |
| `a\bmod n` | text | 11 | 0 | 2: kern 39867, TeX glue 0 0 0 |
| `a\bmod n` | display | 11 | 0 | 2: kern 39867, TeX glue 0 0 0 |
| `a\bmod{n+1}` | text | 11 | 0 | 2: kern 39867, TeX glue 0 0 0 |
| `a\bmod{n+1}` | display | 11 | 0 | 2: kern 39867, TeX glue 0 0 0 |
| `a\bmod b\bmod c` | text | 11 | 0 | 2: kern 39867, TeX glue 0 0 0 |
| `a\bmod b\bmod c` | display | 11 | 0 | 2: kern 39867, TeX glue 0 0 0 |
| `a\notin B` | text | 11 | 151348 | not supported by the TeX-rule layout: htmlmathml |
| `a\notin B` | display | 11 | 151348 | not supported by the TeX-rule layout: htmlmathml |
| `a\longrightarrow b` | text | 11 | 0 | 3.0: hbox 558150 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\longrightarrow b` | display | 11 | 0 | 3.0: hbox 558150 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\longleftarrow b` | text | 11 | 0 | 5.0: hbox 558150 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\longleftarrow b` | display | 11 | 0 | 5.0: hbox 558150 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\longmapsto b` | text | 11 | 0 | 4.0: hbox 558150 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\longmapsto b` | display | 11 | 0 | 4.0: hbox 558150 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\longleftrightarrow b` | text | 11 | 0 | 3: char cmsy10 36 717621 263276 -95534, TeX char cmsy10 32 717621 263276 -95534 |
| `a\longleftrightarrow b` | display | 11 | 0 | 3: char cmsy10 36 717621 263276 -95534, TeX char cmsy10 32 717621 263276 -95534 |
| `f\colon X\hookrightarrow Y` | text | 11 | 0 | 4: kern 79734, TeX glue 79734 0 0 |
| `f\colon X\hookrightarrow Y` | display | 11 | 0 | 4: kern 79734, TeX glue 79734 0 0 |
| `x\xrightarrow{f}y` | text | 11 | 295648 | not supported by the TeX-rule layout: xArrow |
| `x\xrightarrow{f}y` | display | 11 | 295648 | not supported by the TeX-rule layout: xArrow |
| `x\xrightarrow[g]{f}y` | text | 11 | 295648 | not supported by the TeX-rule layout: xArrow |
| `x\xrightarrow[g]{f}y` | display | 11 | 295648 | not supported by the TeX-rule layout: xArrow |
| `x\overset{f}{\longrightarrow}y` | text | 11 | 0 | 3.0.3.0: hbox 558150 0 0 shift 0 (1), TeX kern 0 |
| `x\overset{f}{\longrightarrow}y` | display | 11 | 0 | 3.0.3.0: hbox 558150 0 0 shift 0 (1), TeX kern 0 |
| `A\xleftarrow{\frac12}B` | text | 11 | 223686 | not supported by the TeX-rule layout: xArrow |
| `A\xleftarrow{\frac12}B` | display | 11 | 223686 | not supported by the TeX-rule layout: xArrow |
| `a\cong b` | text | 11 | 32768 | not supported by the TeX-rule layout: symbol \cong |
| `a\cong b` | display | 11 | 32768 | not supported by the TeX-rule layout: symbol \cong |
| `a\models b` | text | 11 | 15690 | not supported by the TeX-rule layout: symbol \models |
| `a\models b` | display | 11 | 15690 | not supported by the TeX-rule layout: symbol \models |
| `\hbar` | text | 11 | 25955 | not supported by the TeX-rule layout: symbol \hbar |
| `\hbar` | display | 11 | 25955 | not supported by the TeX-rule layout: symbol \hbar |
| `\checkmark` | text | 11 | 240 | not supported by the TeX-rule layout: symbol \checkmark |
| `\checkmark` | display | 11 | 240 | not supported by the TeX-rule layout: symbol \checkmark |
| `\begin{matrix}a&b\\c&d\end{matrix}` | text | 11 | 0 | 2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\begin{matrix}a&b\\c&d\end{matrix}` | display | 11 | 0 | 2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\begin{bmatrix}a&b\\c&d\end{bmatrix}` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\begin{bmatrix}a&b\\c&d\end{bmatrix}` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\begin{Bmatrix}a&b\\c&d\end{Bmatrix}` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\begin{Bmatrix}a&b\\c&d\end{Bmatrix}` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\begin{Vmatrix}a&b\\c&d\end{Vmatrix}` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\begin{Vmatrix}a&b\\c&d\end{Vmatrix}` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\begin{smallmatrix}a&b\\c&d\end{smallmatrix}` | text | 11 | 214955 | not supported by the TeX-rule layout: this array environment |
| `\begin{smallmatrix}a&b\\c&d\end{smallmatrix}` | display | 11 | 214955 | not supported by the TeX-rule layout: this array environment |
| `\left(\begin{smallmatrix}a&b\\c&d\end{smallmatrix}\right)` | text | 11 | 215295 | not supported by the TeX-rule layout: this array environment |
| `\left(\begin{smallmatrix}a&b\\c&d\end{smallmatrix}\right)` | display | 11 | 215295 | not supported by the TeX-rule layout: this array environment |
| `\begin{pmatrix}1&0&0\\0&1&0\\0&0&1\end{pmatrix}` | text | 11 | 0 | 1.2.0.3: hbox 1014170 462465 0 shift 0 (7), TeX hbox 1014170 623900 267389 shift 0 (7) |
| `\begin{pmatrix}1&0&0\\0&1&0\\0&0&1\end{pmatrix}` | display | 11 | 0 | 1.2.0.3: hbox 1014170 462465 0 shift 0 (7), TeX hbox 1014170 623900 267389 shift 0 (7) |
| `\begin{pmatrix}a\\b\end{pmatrix}` | text | 11 | 0 | 1.2.0.1.6: glue 0 65536 0, TeX math false |
| `\begin{pmatrix}a\\b\end{pmatrix}` | display | 11 | 0 | 1.2.0.1.6: glue 0 65536 0, TeX math false |
| `\begin{pmatrix}a&b\end{pmatrix}` | text | 11 | 0 | 1.2.0.3: hbox 963338 498346 0 shift 0 (7), TeX hbox 963338 623900 267389 shift 0 (7) |
| `\begin{pmatrix}a&b\end{pmatrix}` | display | 11 | 0 | 1.2.0.3: hbox 963338 498346 0 shift 0 (7), TeX hbox 963338 623900 267389 shift 0 (7) |
| `\begin{pmatrix}\frac12&\frac34\\x&y\end{pmatrix}` | text | 11 | 0 | 1.2.0.3: hbox 1091178 620424 247464 shift 0 (7), TeX hbox 1091178 623900 267389 shift 0 (10) |
| `\begin{pmatrix}\frac12&\frac34\\x&y\end{pmatrix}` | display | 11 | 0 | 1.2.0.3: hbox 1091178 620424 247464 shift 0 (7), TeX hbox 1091178 623900 267389 shift 0 (10) |
| `\begin{bmatrix}x^2&\sum_i y_i\\\sqrt{z}&w\end{bmatrix}` | text | 11 | 0 | 1.2.0.3: hbox 2329137 538218 212178 shift 0 (11), TeX hbox 2329137 623900 267389 shift 0 (14) |
| `\begin{bmatrix}x^2&\sum_i y_i\\\sqrt{z}&w\end{bmatrix}` | display | 11 | 0 | 1.2.0.3: hbox 2329137 538218 212178 shift 0 (11), TeX hbox 2329137 623900 267389 shift 0 (14) |
| `\begin{pmatrix}1&\cdots&n\\\vdots&\ddots&\vdots\\m&\cdots&mn\end{pmatrix}` | text | 11 | 87496 | not supported by the TeX-rule layout: symbol \varvdots |
| `\begin{pmatrix}1&\cdots&n\\\vdots&\ddots&\vdots\\m&\cdots&mn\end{pmatrix}` | display | 11 | 87496 | not supported by the TeX-rule layout: symbol \varvdots |
| `\begin{vmatrix}a&b&c\\d&e&f\\g&h&i\end{vmatrix}` | text | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\begin{vmatrix}a&b&c\\d&e&f\\g&h&i\end{vmatrix}` | display | 11 | 0 | 1.2.0.3: hbox 1068822 498346 0 shift 0 (7), TeX hbox 1068822 623900 267389 shift 0 (7) |
| `\begin{pmatrix}a&b\\c&d\end{pmatrix}^2` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\begin{pmatrix}a&b\\c&d\end{pmatrix}^2` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\begin{pmatrix}a&b\\c&d\end{pmatrix}\begin{pmatrix}x\\y\end{pmatrix}` | text | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\begin{pmatrix}a&b\\c&d\end{pmatrix}\begin{pmatrix}x\\y\end{pmatrix}` | display | 11 | 0 | 1.2.0.3: hbox 1028871 498346 0 shift 0 (7), TeX hbox 1028871 623900 267389 shift 0 (10) |
| `\begin{matrix}abc&d\\e&fghij\end{matrix}` | text | 11 | 0 | 2.0.3: hbox 2449257 498346 0 shift 0 (7), TeX hbox 2449257 623900 267389 shift 0 (10) |
| `\begin{matrix}abc&d\\e&fghij\end{matrix}` | display | 11 | 0 | 2.0.3: hbox 2449257 498346 0 shift 0 (7), TeX hbox 2449257 623900 267389 shift 0 (10) |
| `\begin{cases}a&x>0\\b&x\le0\end{cases}` | text | 11 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}a&x>0\\b&x\le0\end{cases}` | display | 11 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `f(x)=\begin{cases}1&x>0\\0&\text{otherwise}\end{cases}` | text | 11 | 0 | 9.1.0.1.1: glue 0 0 0, TeX math false |
| `f(x)=\begin{cases}1&x>0\\0&\text{otherwise}\end{cases}` | display | 11 | 0 | 9.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}\frac12&a\\\sqrt{x}&b\\c&d\end{cases}` | text | 11 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}\frac12&a\\\sqrt{x}&b\\c&d\end{cases}` | display | 11 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}a\end{cases}` | text | 11 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}a\end{cases}` | display | 11 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}x&\text{if }x\ge0,\\-x&\text{if }x<0\end{cases}` | text | 11 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}x&\text{if }x\ge0,\\-x&\text{if }x<0\end{cases}` | display | 11 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{array}{lcr}a&b&c\\dd&ee&ff\end{array}` | text | 11 | 0 | 1.0.3: hbox 1323644 498346 0 shift 0 (7), TeX hbox 1323644 623900 267389 shift 0 (7) |
| `\begin{array}{lcr}a&b&c\\dd&ee&ff\end{array}` | display | 11 | 0 | 1.0.3: hbox 1323644 498346 0 shift 0 (7), TeX hbox 1323644 623900 267389 shift 0 (7) |
| `\begin{array}{c}a\\b\end{array}` | text | 11 | 0 | 1.0.1.6: glue 0 65536 0, TeX math false |
| `\begin{array}{c}a\\b\end{array}` | display | 11 | 0 | 1.0.1.6: glue 0 65536 0, TeX math false |
| `\begin{array}{l}a\\bbb\end{array}` | text | 11 | 0 | 1.0.1.5: glue 0 65536 0, TeX math false |
| `\begin{array}{l}a\\bbb\end{array}` | display | 11 | 0 | 1.0.1.5: glue 0 65536 0, TeX math false |
| `\begin{array}{r}a\\bbb\end{array}` | text | 11 | 0 | 1.0.1.6: glue 327680 0 0, TeX math false |
| `\begin{array}{r}a\\bbb\end{array}` | display | 11 | 0 | 1.0.1.6: glue 327680 0 0, TeX math false |
| `\begin{array}{cc}a&b\end{array}` | text | 11 | 0 | 1.0.3: hbox 963338 498346 0 shift 0 (7), TeX hbox 963338 623900 267389 shift 0 (7) |
| `\begin{array}{cc}a&b\end{array}` | display | 11 | 0 | 1.0.3: hbox 963338 498346 0 shift 0 (7), TeX hbox 963338 623900 267389 shift 0 (7) |
| `\begin{array}{rl}x&=1\\yyy&=2\end{array}` | text | 11 | 0 | 1.0.3: hbox 1771655 462465 0 shift 0 (8), TeX hbox 1771655 623900 267389 shift 0 (11) |
| `\begin{array}{rl}x&=1\\yyy&=2\end{array}` | display | 11 | 0 | 1.0.3: hbox 1771655 462465 0 shift 0 (8), TeX hbox 1771655 623900 267389 shift 0 (11) |
| `\begin{array}{c\|c}a&b\\\hline c&d\end{array}` | text | 11 | 124463 | not supported by the TeX-rule layout: array rules |
| `\begin{array}{c\|c}a&b\\\hline c&d\end{array}` | display | 11 | 124463 | not supported by the TeX-rule layout: array rules |
| `\begin{array}{ccc}\frac12&x&\sum\\a&\sqrt{b}&c\end{array}` | text | 11 | 0 | 1.0.3: hbox 1561355 308974 0 shift 0 (7), TeX hbox 1561355 623900 267389 shift 0 (7) |
| `\begin{array}{ccc}\frac12&x&\sum\\a&\sqrt{b}&c\end{array}` | display | 11 | 0 | 1.0.3: hbox 1561355 308974 0 shift 0 (7), TeX hbox 1561355 623900 267389 shift 0 (7) |
| `\begin{array}{lcr}1&22&333\\4444&55&6\end{array}` | text | 11 | 0 | 1.0.3: hbox 1372980 462465 0 shift 0 (8), TeX hbox 1372980 623900 267389 shift 0 (8) |
| `\begin{array}{lcr}1&22&333\\4444&55&6\end{array}` | display | 11 | 0 | 1.0.3: hbox 1372980 462465 0 shift 0 (8), TeX hbox 1372980 623900 267389 shift 0 (8) |
| `\begin{array}[t]{c}a\\b\end{array}` | text | 11 | none | KaTeX parse error: Unknown column alignment: [ at position 14: \begin{array}[̲t]{c}a\\b\end{a… |
| `\begin{array}[t]{c}a\\b\end{array}` | display | 11 | none | KaTeX parse error: Unknown column alignment: [ at position 14: \begin{array}[̲t]{c}a\\b\end{a… |
| `\begin{array}[b]{c}a\\b\end{array}` | text | 11 | none | KaTeX parse error: Unknown column alignment: [ at position 14: \begin{array}[̲b]{c}a\\b\end{a… |
| `\begin{array}[b]{c}a\\b\end{array}` | display | 11 | none | KaTeX parse error: Unknown column alignment: [ at position 14: \begin{array}[̲b]{c}a\\b\end{a… |
| `\begin{array}{@{}c@{}}a\end{array}` | text | 11 | none | KaTeX parse error: Unknown column alignment: @ at position 15: \begin{array}{@̲{}c@{}}a\end{ar… |
| `\begin{array}{@{}c@{}}a\end{array}` | display | 11 | none | KaTeX parse error: Unknown column alignment: @ at position 15: \begin{array}{@̲{}c@{}}a\end{ar… |
| `\begin{array}{c@{\,}c}a&b\end{array}` | text | 11 | none | KaTeX parse error: Unknown column alignment: @ at position 16: \begin{array}{c@̲{\,}c}a&b\end{a… |
| `\begin{array}{c@{\,}c}a&b\end{array}` | display | 11 | none | KaTeX parse error: Unknown column alignment: @ at position 16: \begin{array}{c@̲{\,}c}a&b\end{a… |
| `\substack{a\\b}` | text | 11 | 118705 | not supported by the TeX-rule layout: array cells in script style |
| `\substack{a\\b}` | display | 11 | 118705 | not supported by the TeX-rule layout: array cells in script style |
| `\sum_{\substack{a\\b}}` | text | 11 | 74535 | not supported by the TeX-rule layout: array cells in script style |
| `\sum_{\substack{a\\b}}` | display | 11 | 74312 | not supported by the TeX-rule layout: array cells in script style |
| `\begin{aligned}a&=b\\c&=d\end{aligned}` | text | 11 | 20808 | not supported by the TeX-rule layout: this array environment |
| `\begin{aligned}a&=b\\c&=d\end{aligned}` | display | 11 | 20808 | not supported by the TeX-rule layout: this array environment |
| `\begin{gathered}a\\bb\end{gathered}` | text | 11 | 20808 | not supported by the TeX-rule layout: this array environment |
| `\begin{gathered}a\\bb\end{gathered}` | display | 11 | 20808 | not supported by the TeX-rule layout: this array environment |
| `\overset{\mathrm{def}}{=}` | text | 11 | 0 | 1.0.3.1: char cmr10 61 558150 263276 -95534, TeX kern 0 |
| `\overset{\mathrm{def}}{=}` | display | 11 | 0 | 1.0.3.1: char cmr10 61 558150 263276 -95534, TeX kern 0 |
| `\boxed{x}` | text | 11 | 21172 | not supported by the TeX-rule layout: enclose |
| `\boxed{x}` | display | 11 | 21172 | not supported by the TeX-rule layout: enclose |
| `\boxed{\frac12}` | text | 11 | 21520 | not supported by the TeX-rule layout: enclose |
| `\boxed{\frac12}` | display | 11 | 21520 | not supported by the TeX-rule layout: enclose |
| `\fbox{x}` | text | 11 | 21168 | not supported by the TeX-rule layout: enclose |
| `\fbox{x}` | display | 11 | 21168 | not supported by the TeX-rule layout: enclose |
| `\left(a\atop b\right)` | text | 11 | 15691 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `\left(a\atop b\right)` | display | 11 | 14915 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `a\over b` | text | 11 | 15210 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `a\over b` | display | 11 | 244823 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\over b}` | text | 11 | 15210 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\over b}` | display | 11 | 15236 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\choose b}` | text | 11 | 30633 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\choose b}` | display | 11 | 131 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\above 1pt b}` | text | 11 | 15210 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\above 1pt b}` | display | 11 | 21787 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\overwithdelims() b}` | text | 11 | none | KaTeX parse error: Undefined control sequence: \overwithdelims at position 3: {a\̲o̲v̲e̲r̲w̲i̲t̲h̲d̲e̲l̲i̲m̲s̲() b} |
| `{a\overwithdelims() b}` | display | 11 | none | KaTeX parse error: Undefined control sequence: \overwithdelims at position 3: {a\̲o̲v̲e̲r̲w̲i̲t̲h̲d̲e̲l̲i̲m̲s̲() b} |
| `{a\atopwithdelims[] b}` | text | 11 | none | KaTeX parse error: Undefined control sequence: \atopwithdelims at position 3: {a\̲a̲t̲o̲p̲w̲i̲t̲h̲d̲e̲l̲i̲m̲s̲[] b} |
| `{a\atopwithdelims[] b}` | display | 11 | none | KaTeX parse error: Undefined control sequence: \atopwithdelims at position 3: {a\̲a̲t̲o̲p̲w̲i̲t̲h̲d̲e̲l̲i̲m̲s̲[] b} |
| `{a\brace b}` | text | 11 | 30632 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\brace b}` | display | 11 | 292 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\brack b}` | text | 11 | 29676 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\brack b}` | display | 11 | 609 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `\mathchar"7141` | text | 11 | none | KaTeX parse error: Undefined control sequence: \mathchar at position 1: \̲m̲a̲t̲h̲c̲h̲a̲r̲"7141 |
| `\mathchar"7141` | display | 11 | none | KaTeX parse error: Undefined control sequence: \mathchar at position 1: \̲m̲a̲t̲h̲c̲h̲a̲r̲"7141 |
| `\delimiter"4266308` | text | 11 | none | KaTeX parse error: Undefined control sequence: \delimiter at position 1: \̲d̲e̲l̲i̲m̲i̲t̲e̲r̲"4266308 |
| `\delimiter"4266308` | display | 11 | none | KaTeX parse error: Undefined control sequence: \delimiter at position 1: \̲d̲e̲l̲i̲m̲i̲t̲e̲r̲"4266308 |
| `\radical"270370{x}` | text | 11 | none | KaTeX parse error: Undefined control sequence: \radical at position 1: \̲r̲a̲d̲i̲c̲a̲l̲"270370{x} |
| `\radical"270370{x}` | display | 11 | none | KaTeX parse error: Undefined control sequence: \radical at position 1: \̲r̲a̲d̲i̲c̲a̲l̲"270370{x} |
| `\skew{3}\hat{x}` | text | 11 | none | KaTeX parse error: Undefined control sequence: \skew at position 1: \̲s̲k̲e̲w̲{3}\hat{x} |
| `\skew{3}\hat{x}` | display | 11 | none | KaTeX parse error: Undefined control sequence: \skew at position 1: \̲s̲k̲e̲w̲{3}\hat{x} |
| `\vcenter{\hbox{x}}` | text | 11 | 157 | not supported by the TeX-rule layout: vcenter |
| `\vcenter{\hbox{x}}` | display | 11 | 157 | not supported by the TeX-rule layout: vcenter |
| `\raise2pt\hbox{x}` | text | 11 | none | KaTeX parse error: Undefined control sequence: \raise at position 1: \̲r̲a̲i̲s̲e̲2pt\hbox{x} |
| `\raise2pt\hbox{x}` | display | 11 | none | KaTeX parse error: Undefined control sequence: \raise at position 1: \̲r̲a̲i̲s̲e̲2pt\hbox{x} |
| `\lower2pt\hbox{x}` | text | 11 | none | KaTeX parse error: Undefined control sequence: \lower at position 1: \̲l̲o̲w̲e̲r̲2pt\hbox{x} |
| `\lower2pt\hbox{x}` | display | 11 | none | KaTeX parse error: Undefined control sequence: \lower at position 1: \̲l̲o̲w̲e̲r̲2pt\hbox{x} |
| `\mathsurround=3pt a` | text | 11 | none | KaTeX parse error: Undefined control sequence: \mathsurround at position 1: \̲m̲a̲t̲h̲s̲u̲r̲r̲o̲u̲n̲d̲=3pt a |
| `\mathsurround=3pt a` | display | 11 | none | KaTeX parse error: Undefined control sequence: \mathsurround at position 1: \̲m̲a̲t̲h̲s̲u̲r̲r̲o̲u̲n̲d̲=3pt a |
| `\rule{1pt}{1em}` | text | 11 | 6226 | not supported by the TeX-rule layout: rule |
| `\rule{1pt}{1em}` | display | 11 | 6226 | not supported by the TeX-rule layout: rule |
| `\rule[-2pt]{3pt}{2pt}` | text | 11 | 18678 | not supported by the TeX-rule layout: rule |
| `\rule[-2pt]{3pt}{2pt}` | display | 11 | 18678 | not supported by the TeX-rule layout: rule |
| `x\hbox to 10pt{\hfil a}y` | text | 11 | none | KaTeX parse error: Undefined control sequence: \hfil at position 16: x\hbox to 10pt{\̲h̲f̲i̲l̲ ̲a}y |
| `x\hbox to 10pt{\hfil a}y` | display | 11 | none | KaTeX parse error: Undefined control sequence: \hfil at position 16: x\hbox to 10pt{\̲h̲f̲i̲l̲ ̲a}y |
| `\mathchar"0161` | text | 11 | none | KaTeX parse error: Undefined control sequence: \mathchar at position 1: \̲m̲a̲t̲h̲c̲h̲a̲r̲"0161 |
| `\mathchar"0161` | display | 11 | none | KaTeX parse error: Undefined control sequence: \mathchar at position 1: \̲m̲a̲t̲h̲c̲h̲a̲r̲"0161 |
| `\fam1 a` | text | 11 | none | KaTeX parse error: Undefined control sequence: \fam at position 1: \̲f̲a̲m̲1 a |
| `\fam1 a` | display | 11 | none | KaTeX parse error: Undefined control sequence: \fam at position 1: \̲f̲a̲m̲1 a |
| `\hbox{$x^2$}` | text | 11 | 23913 | not supported by the TeX-rule layout: a box that is not plain text |
| `\hbox{$x^2$}` | display | 11 | 23913 | not supported by the TeX-rule layout: a box that is not plain text |
| `\vrule` | text | 11 | none | KaTeX parse error: Undefined control sequence: \vrule at position 1: \̲v̲r̲u̲l̲e̲ |
| `\vrule` | display | 11 | none | KaTeX parse error: Undefined control sequence: \vrule at position 1: \̲v̲r̲u̲l̲e̲ |
| `a\nonscript\mskip 4mu b` | text | 11 | none | KaTeX parse error: Undefined control sequence: \nonscript at position 2: a\̲n̲o̲n̲s̲c̲r̲i̲p̲t̲\mskip 4mu b |
| `a\nonscript\mskip 4mu b` | display | 11 | none | KaTeX parse error: Undefined control sequence: \nonscript at position 2: a\̲n̲o̲n̲s̲c̲r̲i̲p̲t̲\mskip 4mu b |
| `x_{a\nonscript\mskip4mu b}` | text | 11 | none | KaTeX parse error: Undefined control sequence: \nonscript at position 5: x_{a\̲n̲o̲n̲s̲c̲r̲i̲p̲t̲\mskip4mu b} |
| `x_{a\nonscript\mskip4mu b}` | display | 11 | none | KaTeX parse error: Undefined control sequence: \nonscript at position 5: x_{a\̲n̲o̲n̲s̲c̲r̲i̲p̲t̲\mskip4mu b} |
| `\frac{a}{\frac{b}{c}}` | text | 12 | 0 | 1.0.1.4.0: hbox 78643 0 0 shift -131072 (0), TeX hbox 377150 487413 205608 shift 0 (3) |
| `\frac{a}{\frac{b}{c}}` | display | 12 | 0 | 1.0.1.4.1: hbox 78643 0 0 shift -196608 (0), TeX hbox 398559 673732 271194 shift 0 (3) |
| `\bigl(x\bigr)` | text | 12 | 0 | 1.1: hbox 360450 31456 912271 shift -637015 (1), TeX hbox 360450 668471 275256 shift 0 (3) |
| `\bigl(x\bigr)` | display | 12 | 0 | 1.1: hbox 360450 31456 912271 shift -637015 (1), TeX hbox 360450 668471 275256 shift 0 (3) |
| `\Bigl(x\Bigr)` | text | 12 | 0 | 1.1: hbox 469676 31456 1384135 shift -872947 (1), TeX hbox 469676 904403 511188 shift 0 (3) |
| `\Bigl(x\Bigr)` | display | 12 | 0 | 1.1: hbox 469676 31456 1384135 shift -872947 (1), TeX hbox 469676 904403 511188 shift 0 (3) |
| `\begin{pmatrix}a&b\\c&d\end{pmatrix}` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\begin{pmatrix}a&b\\c&d\end{pmatrix}` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\begin{bmatrix}1&0\\0&1\end{bmatrix}` | text | 12 | 0 | 1.2.0.3: hbox 1040380 506811 0 shift 0 (7), TeX hbox 1040380 665187 285084 shift 0 (10) |
| `\begin{bmatrix}1&0\\0&1\end{bmatrix}` | display | 12 | 0 | 1.2.0.3: hbox 1040380 506811 0 shift 0 (7), TeX hbox 1040380 665187 285084 shift 0 (10) |
| `\begin{vmatrix}a&b\\c&d\end{vmatrix}` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\begin{vmatrix}a&b\\c&d\end{vmatrix}` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\binom{n}{k}` | text | 12 | 0 | 1.0: hbox 1058900 668471 275256 shift 0 (3), TeX hbox 360450 668471 275256 shift 0 (1) |
| `\binom{n}{k}` | display | 12 | 0 | 1.0: hbox 1617465 1140335 747120 shift 0 (3), TeX hbox 578904 1140335 747120 shift 0 (1) |
| `\binom{2n}{n}` | text | 12 | 0 | 1.0: hbox 1337432 686839 275256 shift 0 (3), TeX hbox 360450 668471 275256 shift 0 (1) |
| `\binom{2n}{n}` | display | 12 | 0 | 1.0: hbox 2002485 1140335 747120 shift 0 (3), TeX hbox 578904 1140335 747120 shift 0 (1) |
| `\begin{cases}1 & x>0\\0 & x\le 0\end{cases}` | text | 12 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}1 & x>0\\0 & x\le 0\end{cases}` | display | 12 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `f\colon A\to B` | text | 12 | 0 | 4: kern 87380, TeX glue 87380 0 0 |
| `f\colon A\to B` | display | 12 | 0 | 4: kern 87380, TeX glue 87380 0 0 |
| `(1+x)^n=\sum_{k=0}^n \binom{n}{k}x^k` | text | 12 | 0 | 15.0: hbox 1058900 668471 275256 shift 0 (3), TeX hbox 360450 668471 275256 shift 0 (1) |
| `(1+x)^n=\sum_{k=0}^n \binom{n}{k}x^k` | display | 12 | 0 | 14.0: hbox 1617465 1140335 747120 shift 0 (3), TeX hbox 578904 1140335 747120 shift 0 (1) |
| `x_{\binom{n}{k}}` | text | 12 | 0 | 2.0.0: char cmr12 40 299460 589824 196608, TeX hbox 299460 589824 196608 shift 0 (3) |
| `x_{\binom{n}{k}}` | display | 12 | 0 | 2.0.0: char cmr12 40 299460 589824 196608, TeX hbox 299460 589824 196608 shift 0 (3) |
| `x^{\sqrt{\frac12}}_{\frac{\frac12}{3}}` | text | 12 | 0 | 2.2.1.0.0: hbox 78643 0 0 shift -98304 (0), TeX hbox 397581 407675 183748 shift 0 (3) |
| `x^{\sqrt{\frac12}}_{\frac{\frac12}{3}}` | display | 12 | 0 | 2.2.1.0.0: hbox 78643 0 0 shift -98304 (0), TeX hbox 397581 407675 183748 shift 0 (3) |
| `x^{\scriptscriptstyle\sqrt2}` | text | 12 | 1218 | 2: hbox 666276 365721 47811 shift -285390 (2), TeX hbox 666276 364503 47811 shift -285390 (2) |
| `x^{\scriptscriptstyle\sqrt2}` | display | 12 | 1218 | 2: hbox 666276 365721 47811 shift -324711 (2), TeX hbox 666276 364503 47811 shift -324711 (2) |
| `\dbinom{n}{k}` | text | 12 | 0 | 1.0: hbox 1617465 1140335 747120 shift 0 (1), TeX hbox 578904 1140335 747120 shift 0 (1) |
| `\dbinom{n}{k}` | display | 12 | 0 | 1.0: hbox 1617465 1140335 747120 shift 0 (1), TeX hbox 578904 1140335 747120 shift 0 (1) |
| `\tbinom{n}{k}` | text | 12 | 0 | 1.0: hbox 1058900 668471 275256 shift 0 (1), TeX hbox 360450 668471 275256 shift 0 (1) |
| `\tbinom{n}{k}` | display | 12 | 0 | 1.0: hbox 1058900 668471 275256 shift 0 (1), TeX hbox 360450 668471 275256 shift 0 (1) |
| `\binom{n+1}{k-1}` | text | 12 | 0 | 1.0: hbox 1770704 686839 325810 shift 0 (3), TeX hbox 360450 668471 275256 shift 0 (1) |
| `\binom{n+1}{k-1}` | display | 12 | 0 | 1.0: hbox 2950925 1140335 747120 shift 0 (3), TeX hbox 578904 1140335 747120 shift 0 (1) |
| `\dbinom{n+1}{k-1}` | text | 12 | 0 | 1.0: hbox 2950925 1140335 747120 shift 0 (1), TeX hbox 578904 1140335 747120 shift 0 (1) |
| `\dbinom{n+1}{k-1}` | display | 12 | 0 | 1.0: hbox 2950925 1140335 747120 shift 0 (1), TeX hbox 578904 1140335 747120 shift 0 (1) |
| `\tbinom{n+1}{k-1}` | text | 12 | 0 | 1.0: hbox 1770704 686839 325810 shift 0 (1), TeX hbox 360450 668471 275256 shift 0 (1) |
| `\tbinom{n+1}{k-1}` | display | 12 | 0 | 1.0: hbox 1770704 686839 325810 shift 0 (1), TeX hbox 360450 668471 275256 shift 0 (1) |
| `\binom{\frac12}{k}` | text | 12 | 0 | 1.0: hbox 1118481 838669 293148 shift 0 (3), TeX hbox 360450 668471 275256 shift 0 (1) |
| `\binom{\frac12}{k}` | display | 12 | 0 | 1.0: hbox 1593626 1179545 747120 shift 0 (3), TeX hbox 578904 1140335 747120 shift 0 (1) |
| `\binom{n}{\frac{k}{2}}` | text | 12 | 0 | 1.0: hbox 1146244 668471 476802 shift 0 (3), TeX hbox 360450 668471 275256 shift 0 (1) |
| `\binom{n}{\frac{k}{2}}` | display | 12 | 0 | 1.0: hbox 1619112 1140335 810648 shift 0 (3), TeX hbox 578904 1140335 747120 shift 0 (1) |
| `\binom{a}{b}^2` | text | 12 | 0 | 1.0: hbox 1016787 668471 275256 shift 0 (3), TeX hbox 360450 668471 275256 shift 0 (1) |
| `\binom{a}{b}^2` | display | 12 | 0 | 1.0: hbox 1562033 1140335 747120 shift 0 (3), TeX hbox 578904 1140335 747120 shift 0 (1) |
| `\binom{n}{k}_q` | text | 12 | 0 | 1.0: hbox 1058900 668471 275256 shift 0 (3), TeX hbox 360450 668471 275256 shift 0 (1) |
| `\binom{n}{k}_q` | display | 12 | 0 | 1.0: hbox 1617465 1140335 747120 shift 0 (3), TeX hbox 578904 1140335 747120 shift 0 (1) |
| `\genfrac{(}{)}{0pt}{}{n}{k}` | text | 12 | 0 | 1.0: hbox 1058900 668471 275256 shift 0 (3), TeX hbox 360450 668471 275256 shift 0 (1) |
| `\genfrac{(}{)}{0pt}{}{n}{k}` | display | 12 | 0 | 1.0: hbox 1617465 1140335 747120 shift 0 (3), TeX hbox 578904 1140335 747120 shift 0 (1) |
| `\genfrac{(}{)}{0.4pt}{}{n}{k}` | text | 12 | 0 | 1.0: hbox 1058900 668471 275256 shift 0 (3), TeX hbox 360450 668471 275256 shift 0 (1) |
| `\genfrac{(}{)}{0.4pt}{}{n}{k}` | display | 12 | 0 | 1.0: hbox 1617465 1140335 747120 shift 0 (3), TeX hbox 578904 1140335 747120 shift 0 (1) |
| `\genfrac{[}{]}{1pt}{0}{a}{b}` | text | 12 | 0 | 1.0: hbox 1234351 1140335 747120 shift 0 (1), TeX hbox 415063 1140335 747120 shift 0 (1) |
| `\genfrac{[}{]}{1pt}{0}{a}{b}` | display | 12 | 0 | 1.0: hbox 1234351 1140335 747120 shift 0 (1), TeX hbox 415063 1140335 747120 shift 0 (1) |
| `\genfrac{\{}{\}}{0pt}{1}{a}{b}` | text | 12 | 0 | 1.0: hbox 1213395 668471 275256 shift 0 (1), TeX hbox 458754 668471 275256 shift 0 (1) |
| `\genfrac{\{}{\}}{0pt}{1}{a}{b}` | display | 12 | 0 | 1.0: hbox 1213395 668471 275256 shift 0 (1), TeX hbox 458754 668471 275256 shift 0 (1) |
| `\genfrac{\langle}{\rangle}{0pt}{2}{a}{b}` | text | 12 | 0 | 1.0: hbox 877045 589824 205608 shift 0 (1), TeX hbox 305835 589824 196608 shift 0 (1) |
| `\genfrac{\langle}{\rangle}{0pt}{2}{a}{b}` | display | 12 | 0 | 1.0: hbox 877045 589824 205608 shift 0 (1), TeX hbox 305835 589824 196608 shift 0 (1) |
| `\genfrac{\|}{\|}{0.8pt}{3}{x+1}{y}` | text | 12 | 279622 | 1: hbox 1039738 484965 245291 shift 0 (1), TeX hbox 1319360 589824 245291 shift 0 (5) |
| `\genfrac{\|}{\|}{0.8pt}{3}{x+1}{y}` | display | 12 | 279622 | 1: hbox 1039738 484965 245291 shift 0 (1), TeX hbox 1319360 589824 245291 shift 0 (5) |
| `\genfrac{(}{]}{0pt}{}{a}{b}` | text | 12 | 0 | 1.0: hbox 984018 668471 275256 shift 0 (3), TeX hbox 360450 668471 275256 shift 0 (1) |
| `\genfrac{(}{]}{0pt}{}{a}{b}` | display | 12 | 0 | 1.0: hbox 1398192 1140335 747120 shift 0 (3), TeX hbox 578904 1140335 747120 shift 0 (1) |
| `\frac{1}{\frac{1}{\frac{1}{x}}}` | text | 12 | 0 | 1.0.1.4.0: hbox 78643 0 0 shift -131072 (0), TeX hbox 589003 467751 480825 shift 0 (3) |
| `\frac{1}{\frac{1}{\frac{1}{x}}}` | display | 12 | 0 | 1.0.1.4.0: hbox 78643 0 0 shift -196608 (0), TeX hbox 589003 647518 523935 shift 0 (3) |
| `\frac{\frac{a}{b}}{\frac{c}{d}}` | text | 12 | 0 | 1.0.1.0.0: hbox 78643 0 0 shift -131072 (0), TeX hbox 422661 383646 205608 shift 0 (3) |
| `\frac{\frac{a}{b}}{\frac{c}{d}}` | display | 12 | 0 | 1.0.1.0.0: hbox 78643 0 0 shift -196608 (0), TeX hbox 453173 535378 271194 shift 0 (3) |
| `\frac{\frac{\frac{a}{b}}{c}}{d}` | text | 12 | 0 | 1.0.1.0.0: hbox 78643 0 0 shift -131072 (0), TeX hbox 579947 693442 205608 shift 0 (3) |
| `\frac{\frac{\frac{a}{b}}{c}}{d}` | display | 12 | 0 | 1.0.1.0.0: hbox 78643 0 0 shift -196608 (0), TeX hbox 579947 833046 271194 shift 0 (3) |
| `\frac{a}{\frac{b}{\frac{c}{d}}}` | text | 12 | 0 | 1.0.1.4.0: hbox 78643 0 0 shift -131072 (0), TeX hbox 567203 487413 431298 shift 0 (3) |
| `\frac{a}{\frac{b}{\frac{c}{d}}}` | display | 12 | 0 | 1.0.1.4.0: hbox 78643 0 0 shift -196608 (0), TeX hbox 567203 673732 476802 shift 0 (3) |
| `\sqrt{\frac{\frac12}{3}}` | text | 12 | 0 | 1.1.3.1.0.0: hbox 78643 0 0 shift -131072 (0), TeX hbox 397581 467751 205608 shift 0 (3) |
| `\sqrt{\frac{\frac12}{3}}` | display | 12 | 0 | 1.1.3.1.0.0: hbox 78643 0 0 shift -196608 (0), TeX hbox 435818 647518 271194 shift 0 (3) |
| `\sqrt{\binom{n}{k}}` | text | 12 | 0 | 1.1.3.0: hbox 360450 31456 912271 shift -637015 (1), TeX hbox 360450 668471 275256 shift 0 (1) |
| `\sqrt{\binom{n}{k}}` | display | 12 | 0 | 1.1.3.0: hbox 578904 31456 1855999 shift -1108879 (1), TeX hbox 578904 1140335 747120 shift 0 (1) |
| `\iint\limits_a^b` | text | 12 | 120498 | not supported by the TeX-rule layout: \iint with \limits or \nolimits |
| `\iint\limits_a^b` | display | 12 | 108706 | not supported by the TeX-rule layout: \iint with \limits or \nolimits |
| `\iint\nolimits_a^b` | text | 12 | 116080 | not supported by the TeX-rule layout: \iint with \limits or \nolimits |
| `\iint\nolimits_a^b` | display | 12 | 104288 | not supported by the TeX-rule layout: \iint with \limits or \nolimits |
| `\iiint\limits_a^b` | text | 12 | 240825 | not supported by the TeX-rule layout: \iiint with \limits or \nolimits |
| `\iiint\limits_a^b` | display | 12 | 233492 | not supported by the TeX-rule layout: \iiint with \limits or \nolimits |
| `\iiint\nolimits_a^b` | text | 12 | 236407 | not supported by the TeX-rule layout: \iiint with \limits or \nolimits |
| `\iiint\nolimits_a^b` | display | 12 | 229074 | not supported by the TeX-rule layout: \iiint with \limits or \nolimits |
| `\sum_{\substack{i<j\\ j<n}}x_{ij}` | text | 12 | 27935 | not supported by the TeX-rule layout: array cells in script style |
| `\sum_{\substack{i<j\\ j<n}}x_{ij}` | display | 12 | 28179 | not supported by the TeX-rule layout: array cells in script style |
| `\prod_{\sqrt{n}}^{\binom{n}{k}}` | text | 12 | 0 | 2.0.0.0: char cmr12 40 299460 589824 196608, TeX hbox 299460 589824 196608 shift 0 (3) |
| `\prod_{\sqrt{n}}^{\binom{n}{k}}` | display | 12 | 0 | 1.1.1.0: char cmr12 40 299460 589824 196608, TeX hbox 299460 589824 196608 shift 0 (3) |
| `\sum_{k}\binom{n}{k}` | text | 12 | 0 | 4.0: hbox 1058900 668471 275256 shift 0 (3), TeX hbox 360450 668471 275256 shift 0 (1) |
| `\sum_{k}\binom{n}{k}` | display | 12 | 0 | 3.0: hbox 1617465 1140335 747120 shift 0 (3), TeX hbox 578904 1140335 747120 shift 0 (1) |
| `\det\begin{pmatrix}a&b\\c&d\end{pmatrix}` | text | 12 | 0 | 3.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\det\begin{pmatrix}a&b\\c&d\end{pmatrix}` | display | 12 | 0 | 3.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\hat{\imath}` | text | 12 | 7474 | not supported by the TeX-rule layout: htmlmathml |
| `\hat{\imath}` | display | 12 | 7474 | not supported by the TeX-rule layout: htmlmathml |
| `\hat{\jmath}` | text | 12 | 4804 | not supported by the TeX-rule layout: htmlmathml |
| `\hat{\jmath}` | display | 12 | 4804 | not supported by the TeX-rule layout: htmlmathml |
| `\check{\imath}` | text | 12 | 7474 | not supported by the TeX-rule layout: htmlmathml |
| `\check{\imath}` | display | 12 | 7474 | not supported by the TeX-rule layout: htmlmathml |
| `\check{\jmath}` | text | 12 | 4804 | not supported by the TeX-rule layout: htmlmathml |
| `\check{\jmath}` | display | 12 | 4804 | not supported by the TeX-rule layout: htmlmathml |
| `\tilde{\imath}` | text | 12 | 7474 | not supported by the TeX-rule layout: htmlmathml |
| `\tilde{\imath}` | display | 12 | 7474 | not supported by the TeX-rule layout: htmlmathml |
| `\tilde{\jmath}` | text | 12 | 4804 | not supported by the TeX-rule layout: htmlmathml |
| `\tilde{\jmath}` | display | 12 | 4804 | not supported by the TeX-rule layout: htmlmathml |
| `\acute{\imath}` | text | 12 | 7474 | not supported by the TeX-rule layout: htmlmathml |
| `\acute{\imath}` | display | 12 | 7474 | not supported by the TeX-rule layout: htmlmathml |
| `\acute{\jmath}` | text | 12 | 4804 | not supported by the TeX-rule layout: htmlmathml |
| `\acute{\jmath}` | display | 12 | 4804 | not supported by the TeX-rule layout: htmlmathml |
| `\grave{\imath}` | text | 12 | 7474 | not supported by the TeX-rule layout: htmlmathml |
| `\grave{\imath}` | display | 12 | 7474 | not supported by the TeX-rule layout: htmlmathml |
| `\grave{\jmath}` | text | 12 | 4804 | not supported by the TeX-rule layout: htmlmathml |
| `\grave{\jmath}` | display | 12 | 4804 | not supported by the TeX-rule layout: htmlmathml |
| `\dot{\imath}` | text | 12 | 7474 | not supported by the TeX-rule layout: htmlmathml |
| `\dot{\imath}` | display | 12 | 7474 | not supported by the TeX-rule layout: htmlmathml |
| `\dot{\jmath}` | text | 12 | 4804 | not supported by the TeX-rule layout: htmlmathml |
| `\dot{\jmath}` | display | 12 | 4804 | not supported by the TeX-rule layout: htmlmathml |
| `\ddot{\imath}` | text | 12 | 7474 | not supported by the TeX-rule layout: htmlmathml |
| `\ddot{\imath}` | display | 12 | 7474 | not supported by the TeX-rule layout: htmlmathml |
| `\ddot{\jmath}` | text | 12 | 4804 | not supported by the TeX-rule layout: htmlmathml |
| `\ddot{\jmath}` | display | 12 | 4804 | not supported by the TeX-rule layout: htmlmathml |
| `\breve{\imath}` | text | 12 | 7474 | not supported by the TeX-rule layout: htmlmathml |
| `\breve{\imath}` | display | 12 | 7474 | not supported by the TeX-rule layout: htmlmathml |
| `\breve{\jmath}` | text | 12 | 4804 | not supported by the TeX-rule layout: htmlmathml |
| `\breve{\jmath}` | display | 12 | 4804 | not supported by the TeX-rule layout: htmlmathml |
| `\bar{\imath}` | text | 12 | 7474 | not supported by the TeX-rule layout: htmlmathml |
| `\bar{\imath}` | display | 12 | 7474 | not supported by the TeX-rule layout: htmlmathml |
| `\bar{\jmath}` | text | 12 | 4804 | not supported by the TeX-rule layout: htmlmathml |
| `\bar{\jmath}` | display | 12 | 4804 | not supported by the TeX-rule layout: htmlmathml |
| `\vec{\imath}` | text | 12 | 7474 | not supported by the TeX-rule layout: htmlmathml |
| `\vec{\imath}` | display | 12 | 7474 | not supported by the TeX-rule layout: htmlmathml |
| `\vec{\jmath}` | text | 12 | 4804 | not supported by the TeX-rule layout: htmlmathml |
| `\vec{\jmath}` | display | 12 | 4804 | not supported by the TeX-rule layout: htmlmathml |
| `\mathring{\imath}` | text | 12 | 7474 | not supported by the TeX-rule layout: htmlmathml |
| `\mathring{\imath}` | display | 12 | 7474 | not supported by the TeX-rule layout: htmlmathml |
| `\mathring{\jmath}` | text | 12 | 4804 | not supported by the TeX-rule layout: htmlmathml |
| `\mathring{\jmath}` | display | 12 | 4804 | not supported by the TeX-rule layout: htmlmathml |
| `\dddot x` | text | 12 | 151402 | not supported by the TeX-rule layout: raisebox |
| `\dddot x` | display | 12 | 151402 | not supported by the TeX-rule layout: raisebox |
| `\dddot{x}^2` | text | 12 | 160832 | not supported by the TeX-rule layout: raisebox |
| `\dddot{x}^2` | display | 12 | 127827 | not supported by the TeX-rule layout: raisebox |
| `\widehat{\widehat{x}}` | text | 12 | 0 | 1.0: hbox 0 567979 0 shift 340 (1), TeX hbox 0 567979 0 shift 21729 (1) |
| `\widehat{\widehat{x}}` | display | 12 | 0 | 1.0: hbox 0 567979 0 shift 340 (1), TeX hbox 0 567979 0 shift 21729 (1) |
| `\hat{\hat{x}}` | text | 12 | 0 | 1: vbox 437586 753661 0 shift 0 (3), TeX vbox 480366 753661 0 shift 0 (3) |
| `\hat{\hat{x}}` | display | 12 | 0 | 1: vbox 437586 753661 0 shift 0 (3), TeX vbox 480366 753661 0 shift 0 (3) |
| `\hat{\tilde{x}}` | text | 12 | 0 | 1: vbox 437586 729478 0 shift 0 (3), TeX vbox 480366 729478 0 shift 0 (3) |
| `\hat{\tilde{x}}` | display | 12 | 0 | 1: vbox 437586 729478 0 shift 0 (3), TeX vbox 480366 729478 0 shift 0 (3) |
| `\tilde{\hat{x}}` | text | 12 | 0 | 1: vbox 437586 729478 0 shift 0 (3), TeX vbox 480366 729478 0 shift 0 (3) |
| `\tilde{\hat{x}}` | display | 12 | 0 | 1: vbox 437586 729478 0 shift 0 (3), TeX vbox 480366 729478 0 shift 0 (3) |
| `\bar{\bar{x}}` | text | 12 | 0 | 1: vbox 437586 549769 0 shift 0 (3), TeX vbox 480366 549769 0 shift 0 (3) |
| `\bar{\bar{x}}` | display | 12 | 0 | 1: vbox 437586 549769 0 shift 0 (3), TeX vbox 480366 549769 0 shift 0 (3) |
| `\dot{\hat{x}}` | text | 12 | 0 | 1: vbox 437586 729478 0 shift 0 (3), TeX vbox 480366 729478 0 shift 0 (3) |
| `\dot{\hat{x}}` | display | 12 | 0 | 1: vbox 437586 729478 0 shift 0 (3), TeX vbox 480366 729478 0 shift 0 (3) |
| `\ddot{\vec{x}}` | text | 12 | 0 | 1: vbox 437586 743896 0 shift 0 (3), TeX vbox 480366 743896 0 shift 0 (3) |
| `\ddot{\vec{x}}` | display | 12 | 0 | 1: vbox 437586 743896 0 shift 0 (3), TeX vbox 480366 743896 0 shift 0 (3) |
| `\vec{\dot{x}}` | text | 12 | 0 | 1: vbox 437586 743896 0 shift 0 (3), TeX vbox 480366 743896 0 shift 0 (3) |
| `\vec{\dot{x}}` | display | 12 | 0 | 1: vbox 437586 743896 0 shift 0 (3), TeX vbox 480366 743896 0 shift 0 (3) |
| `\hat{\bar{A}}` | text | 12 | 0 | 1: vbox 577257 850507 0 shift 0 (3), TeX vbox 791157 850507 0 shift 0 (3) |
| `\hat{\bar{A}}` | display | 12 | 0 | 1: vbox 577257 850507 0 shift 0 (3), TeX vbox 791157 850507 0 shift 0 (3) |
| `\acute{\grave{x}}` | text | 12 | 0 | 1: vbox 437586 753661 0 shift 0 (3), TeX vbox 480366 753661 0 shift 0 (3) |
| `\acute{\grave{x}}` | display | 12 | 0 | 1: vbox 437586 753661 0 shift 0 (3), TeX vbox 480366 753661 0 shift 0 (3) |
| `\check{\breve{y}}` | text | 12 | 0 | 1: vbox 403679 701779 152916 shift 0 (3), TeX vbox 489239 701779 152916 shift 0 (3) |
| `\check{\breve{y}}` | display | 12 | 0 | 1: vbox 403679 701779 152916 shift 0 (3), TeX vbox 489239 701779 152916 shift 0 (3) |
| `\vec{\vec{v}}` | text | 12 | 0 | 1: vbox 400493 782497 0 shift 0 (3), TeX vbox 443273 782497 0 shift 0 (3) |
| `\vec{\vec{v}}` | display | 12 | 0 | 1: vbox 400493 782497 0 shift 0 (3), TeX vbox 443273 782497 0 shift 0 (3) |
| `\dot{\dot{x}}` | text | 12 | 0 | 1: vbox 437586 705295 0 shift 0 (3), TeX vbox 480366 705295 0 shift 0 (3) |
| `\dot{\dot{x}}` | display | 12 | 0 | 1: vbox 437586 705295 0 shift 0 (3), TeX vbox 480366 705295 0 shift 0 (3) |
| `\tilde{\tilde{f}}` | text | 12 | 0 | 1: vbox 463527 912824 152916 shift 0 (3), TeX vbox 720207 912824 152916 shift 0 (3) |
| `\tilde{\tilde{f}}` | display | 12 | 0 | 1: vbox 463527 912824 152916 shift 0 (3), TeX vbox 720207 912824 152916 shift 0 (3) |
| `\overrightarrow{AB}` | text | 12 | 121993 | not supported by the TeX-rule layout: accent \overrightarrow |
| `\overrightarrow{AB}` | display | 12 | 121993 | not supported by the TeX-rule layout: accent \overrightarrow |
| `\overleftarrow{AB}` | text | 12 | 121993 | not supported by the TeX-rule layout: accent \overleftarrow |
| `\overleftarrow{AB}` | display | 12 | 121993 | not supported by the TeX-rule layout: accent \overleftarrow |
| `\overrightarrow{x}` | text | 12 | 121999 | not supported by the TeX-rule layout: accent \overrightarrow |
| `\overrightarrow{x}` | display | 12 | 121999 | not supported by the TeX-rule layout: accent \overrightarrow |
| `\underrightarrow{AB}` | text | 12 | 27025 | not supported by the TeX-rule layout: accentUnder |
| `\underrightarrow{AB}` | display | 12 | 27025 | not supported by the TeX-rule layout: accentUnder |
| `\overbrace{a+b+c}^{3}` | text | 12 | 56753 | not supported by the TeX-rule layout: horizBrace |
| `\overbrace{a+b+c}^{3}` | display | 12 | 56753 | not supported by the TeX-rule layout: horizBrace |
| `\underbrace{a+b+c}_{3}` | text | 12 | 56753 | not supported by the TeX-rule layout: horizBrace |
| `\underbrace{a+b+c}_{3}` | display | 12 | 56753 | not supported by the TeX-rule layout: horizBrace |
| `\overbrace{x}` | text | 12 | 157301 | not supported by the TeX-rule layout: horizBrace |
| `\overbrace{x}` | display | 12 | 157301 | not supported by the TeX-rule layout: horizBrace |
| `\underbrace{x}` | text | 12 | 157301 | not supported by the TeX-rule layout: horizBrace |
| `\underbrace{x}` | display | 12 | 157301 | not supported by the TeX-rule layout: horizBrace |
| `\overset{a}{=}` | text | 12 | 0 | 1.0.3.0: char cmr12 61 598920 283824 -109392, TeX kern 0 |
| `\overset{a}{=}` | display | 12 | 0 | 1.0.3.0: char cmr12 61 598920 283824 -109392, TeX kern 0 |
| `\underset{a}{=}` | text | 12 | 0 | 1.0.0.0: char cmr12 61 598920 283824 -109392, TeX kern 0 |
| `\underset{a}{=}` | display | 12 | 0 | 1.0.0.0: char cmr12 61 598920 283824 -109392, TeX kern 0 |
| `\xrightarrow{a}` | text | 12 | 368824 | not supported by the TeX-rule layout: xArrow |
| `\xrightarrow{a}` | display | 12 | 368824 | not supported by the TeX-rule layout: xArrow |
| `\xleftarrow[b]{a}` | text | 12 | 368824 | not supported by the TeX-rule layout: xArrow |
| `\xleftarrow[b]{a}` | display | 12 | 368824 | not supported by the TeX-rule layout: xArrow |
| `\left( \begin{matrix}a&b\\c&d\end{matrix}\right)` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left( \begin{matrix}a&b\\c&d\end{matrix}\right)` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left( \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right)` | text | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left( \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right)` | display | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left( \frac{\frac12}{\frac34}\right)` | text | 12 | 0 | 1.1.0.1.0.0: hbox 78643 0 0 shift -131072 (0), TeX hbox 397581 467751 205608 shift 0 (3) |
| `\left( \frac{\frac12}{\frac34}\right)` | display | 12 | 0 | 1.1.0.1.0.0: hbox 78643 0 0 shift -196608 (0), TeX hbox 435818 647518 271194 shift 0 (3) |
| `\left[ \begin{matrix}a&b\\c&d\end{matrix}\right]` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left[ \begin{matrix}a&b\\c&d\end{matrix}\right]` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left[ \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right]` | text | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left[ \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right]` | display | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left[ \frac{\frac12}{\frac34}\right]` | text | 12 | 0 | 1.1.0.1.0.0: hbox 78643 0 0 shift -131072 (0), TeX hbox 397581 467751 205608 shift 0 (3) |
| `\left[ \frac{\frac12}{\frac34}\right]` | display | 12 | 0 | 1.1.0.1.0.0: hbox 78643 0 0 shift -196608 (0), TeX hbox 435818 647518 271194 shift 0 (3) |
| `\left\{ \begin{matrix}a&b\\c&d\end{matrix}\right\}` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\{ \begin{matrix}a&b\\c&d\end{matrix}\right\}` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\{ \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\}` | text | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\{ \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\}` | display | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\langle \begin{matrix}a&b\\c&d\end{matrix}\right\rangle` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\langle \begin{matrix}a&b\\c&d\end{matrix}\right\rangle` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\langle \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rangle` | text | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\langle \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rangle` | display | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\| \begin{matrix}a&b\\c&d\end{matrix}\right\|` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\| \begin{matrix}a&b\\c&d\end{matrix}\right\|` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\| \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\|` | text | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\| \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\|` | display | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\\| \begin{matrix}a&b\\c&d\end{matrix}\right\\|` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\\| \begin{matrix}a&b\\c&d\end{matrix}\right\\|` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\\| \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\\|` | text | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\\| \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\\|` | display | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\lfloor \begin{matrix}a&b\\c&d\end{matrix}\right\rfloor` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\lfloor \begin{matrix}a&b\\c&d\end{matrix}\right\rfloor` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\lfloor \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rfloor` | text | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\lfloor \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rfloor` | display | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\lceil \begin{matrix}a&b\\c&d\end{matrix}\right\rceil` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\lceil \begin{matrix}a&b\\c&d\end{matrix}\right\rceil` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\lceil \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rceil` | text | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\lceil \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rceil` | display | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left/ \begin{matrix}a&b\\c&d\end{matrix}\right\backslash` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left/ \begin{matrix}a&b\\c&d\end{matrix}\right\backslash` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left/ \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\backslash` | text | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left/ \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\backslash` | display | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\uparrow \begin{matrix}a&b\\c&d\end{matrix}\right\downarrow` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\uparrow \begin{matrix}a&b\\c&d\end{matrix}\right\downarrow` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\uparrow \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\downarrow` | text | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\uparrow \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\downarrow` | display | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\Uparrow \begin{matrix}a&b\\c&d\end{matrix}\right\updownarrow` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\Uparrow \begin{matrix}a&b\\c&d\end{matrix}\right\updownarrow` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\Uparrow \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\updownarrow` | text | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\Uparrow \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\updownarrow` | display | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left. \begin{matrix}a&b\\c&d\end{matrix}\right)` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left. \begin{matrix}a&b\\c&d\end{matrix}\right)` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left. \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right)` | text | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left. \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right)` | display | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left( \begin{matrix}a&b\\c&d\end{matrix}\right.` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left( \begin{matrix}a&b\\c&d\end{matrix}\right.` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left( \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right.` | text | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left( \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right.` | display | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left( \frac{\frac12}{\frac34}\right.` | text | 12 | 0 | 1.1.0.1.0.0: hbox 78643 0 0 shift -131072 (0), TeX hbox 397581 467751 205608 shift 0 (3) |
| `\left( \frac{\frac12}{\frac34}\right.` | display | 12 | 0 | 1.1.0.1.0.0: hbox 78643 0 0 shift -196608 (0), TeX hbox 435818 647518 271194 shift 0 (3) |
| `\left. \begin{matrix}a&b\\c&d\end{matrix}\right.` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left. \begin{matrix}a&b\\c&d\end{matrix}\right.` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left. \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right.` | text | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left. \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right.` | display | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\Downarrow \begin{matrix}a&b\\c&d\end{matrix}\right\Updownarrow` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\Downarrow \begin{matrix}a&b\\c&d\end{matrix}\right\Updownarrow` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\Downarrow \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\Updownarrow` | text | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\Downarrow \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\Updownarrow` | display | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\backslash \begin{matrix}a&b\\c&d\end{matrix}\right/` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\backslash \begin{matrix}a&b\\c&d\end{matrix}\right/` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\backslash \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right/` | text | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\backslash \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right/` | display | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\lvert \begin{matrix}a&b\\c&d\end{matrix}\right\rvert` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\lvert \begin{matrix}a&b\\c&d\end{matrix}\right\rvert` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\lvert \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rvert` | text | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\lvert \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rvert` | display | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\lVert \begin{matrix}a&b\\c&d\end{matrix}\right\rVert` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\lVert \begin{matrix}a&b\\c&d\end{matrix}\right\rVert` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\lVert \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rVert` | text | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\lVert \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rVert` | display | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\lbrace \begin{matrix}a&b\\c&d\end{matrix}\right\rbrace` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\lbrace \begin{matrix}a&b\\c&d\end{matrix}\right\rbrace` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\lbrace \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rbrace` | text | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\lbrace \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rbrace` | display | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\lbrack \begin{matrix}a&b\\c&d\end{matrix}\right\rbrack` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\lbrack \begin{matrix}a&b\\c&d\end{matrix}\right\rbrack` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\lbrack \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rbrack` | text | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left\lbrack \begin{matrix}a&b&c\\d&e&f\\g&h&i\end{matrix}\right\rbrack` | display | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\left(\begin{array}{cc}a&b\\c&d\end{array}\right)` | text | 12 | 0 | 1.1.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left(\begin{array}{cc}a&b\\c&d\end{array}\right)` | display | 12 | 0 | 1.1.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\left\{\begin{array}{ll}a&b\\c&d\end{array}\right.` | text | 12 | 0 | 1.1.0.3: hbox 1055490 546132 0 shift 0 (6), TeX hbox 1055490 665187 285084 shift 0 (9) |
| `\left\{\begin{array}{ll}a&b\\c&d\end{array}\right.` | display | 12 | 0 | 1.1.0.3: hbox 1055490 546132 0 shift 0 (6), TeX hbox 1055490 665187 285084 shift 0 (9) |
| `\text{\textbf{a}}` | text | 12 | 6732 | not supported by the TeX-rule layout: text that is not plain characters |
| `\text{\textbf{a}}` | display | 12 | 6732 | not supported by the TeX-rule layout: text that is not plain characters |
| `\text{a$x$b}` | text | 12 | 12253 | not supported by the TeX-rule layout: text that is not plain characters |
| `\text{a$x$b}` | display | 12 | 12253 | not supported by the TeX-rule layout: text that is not plain characters |
| `\boldsymbol{\alpha}` | text | 12 | 280 | not supported by the TeX-rule layout: \boldsymbol |
| `\boldsymbol{\alpha}` | display | 12 | 280 | not supported by the TeX-rule layout: \boldsymbol |
| `\boldsymbol{x}` | text | 12 | 22 | not supported by the TeX-rule layout: \boldsymbol |
| `\boldsymbol{x}` | display | 12 | 22 | not supported by the TeX-rule layout: \boldsymbol |
| `a\hphantom{b}c` | text | 12 | 0 | 2.0: math false, TeX nothing |
| `a\hphantom{b}c` | display | 12 | 0 | 2.0: math false, TeX nothing |
| `\smash{\frac12}` | text | 12 | 0 | 1: hbox 435818 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `\smash{\frac12}` | display | 12 | 0 | 1: hbox 542306 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\smash{b}c` | text | 12 | 0 | 2: hbox 327402 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\smash{b}c` | display | 12 | 0 | 2: hbox 327402 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `\smash{x_i}` | text | 12 | 0 | 1: hbox 660012 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `\smash{x_i}` | display | 12 | 0 | 1: hbox 660012 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `\hphantom{\frac12}` | text | 12 | 0 | 1.0: math false, TeX nothing |
| `\hphantom{\frac12}` | display | 12 | 0 | 1.0: math false, TeX nothing |
| `\smash[t]{\frac12}` | text | 12 | 0 | 1: hbox 435818 0 271194 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `\smash[t]{\frac12}` | display | 12 | 0 | 1: hbox 542306 0 539454 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `\smash[b]{\frac12}` | text | 12 | 0 | 1: hbox 435818 647518 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `\smash[b]{\frac12}` | display | 12 | 0 | 1: hbox 542306 1038838 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\mkern-3mu b` | text | 12 | 0 | 2: glue -131070 0 0, TeX kern -131070 |
| `a\mkern-3mu b` | display | 12 | 0 | 2: glue -131070 0 0, TeX kern -131070 |
| `a\kern2pt b` | text | 12 | 0 | 2: glue 131072 0 0, TeX kern 131072 |
| `a\kern2pt b` | display | 12 | 0 | 2: glue 131072 0 0, TeX kern 131072 |
| `a\hskip 3pt plus 1pt b` | text | 12 | 2597873 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `a\hskip 3pt plus 1pt b` | display | 12 | 2597873 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `a\negmedspace b` | text | 12 | 0 | 2: kern -174760, TeX glue -174760 -87380 -174760 |
| `a\negmedspace b` | display | 12 | 0 | 2: kern -174760, TeX glue -174760 -87380 -174760 |
| `a\negthickspace b` | text | 12 | 0 | 2: kern -218450, TeX glue -218450 -218450 0 |
| `a\negthickspace b` | display | 12 | 0 | 2: kern -218450, TeX glue -218450 -218450 0 |
| `a\mskip 5mu b` | text | 12 | 0 | 2: glue 218450 218450 0, TeX glue 218450 0 0 |
| `a\mskip 5mu b` | display | 12 | 0 | 2: glue 218450 218450 0, TeX glue 218450 0 0 |
| `a\enspace b` | text | 12 | 0 | 2: glue 393216 0 0, TeX kern 393216 |
| `a\enspace b` | display | 12 | 0 | 2: glue 393216 0 0, TeX kern 393216 |
| `\vdots` | text | 12 | 178782 | not supported by the TeX-rule layout: symbol \varvdots |
| `\vdots` | display | 12 | 178782 | not supported by the TeX-rule layout: symbol \varvdots |
| `\ddots` | text | 12 | 353633 | not supported by the TeX-rule layout: symbol \ddots |
| `\ddots` | display | 12 | 353633 | not supported by the TeX-rule layout: symbol \ddots |
| `\vdots+x` | text | 12 | 178782 | not supported by the TeX-rule layout: symbol \varvdots |
| `\vdots+x` | display | 12 | 178782 | not supported by the TeX-rule layout: symbol \varvdots |
| `a\bmod n` | text | 12 | 0 | 2: kern 43690, TeX glue 0 0 0 |
| `a\bmod n` | display | 12 | 0 | 2: kern 43690, TeX glue 0 0 0 |
| `a\bmod{n+1}` | text | 12 | 0 | 2: kern 43690, TeX glue 0 0 0 |
| `a\bmod{n+1}` | display | 12 | 0 | 2: kern 43690, TeX glue 0 0 0 |
| `a\bmod b\bmod c` | text | 12 | 0 | 2: kern 43690, TeX glue 0 0 0 |
| `a\bmod b\bmod c` | display | 12 | 0 | 2: kern 43690, TeX glue 0 0 0 |
| `a\notin B` | text | 12 | 165861 | not supported by the TeX-rule layout: htmlmathml |
| `a\notin B` | display | 12 | 165861 | not supported by the TeX-rule layout: htmlmathml |
| `a\longrightarrow b` | text | 12 | 0 | 3.0: hbox 611671 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\longrightarrow b` | display | 12 | 0 | 3.0: hbox 611671 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\longleftarrow b` | text | 12 | 0 | 5.0: hbox 611671 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\longleftarrow b` | display | 12 | 0 | 5.0: hbox 611671 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\longmapsto b` | text | 12 | 0 | 4.0: hbox 611671 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\longmapsto b` | display | 12 | 0 | 4.0: hbox 611671 0 0 shift 0 (3), TeX hbox 0 0 0 shift 0 (0) |
| `a\longleftrightarrow b` | text | 12 | 0 | 3: char cmsy10 36 786434 288522 -104694, TeX char cmsy10 32 786434 288522 -104694 |
| `a\longleftrightarrow b` | display | 12 | 0 | 3: char cmsy10 36 786434 288522 -104694, TeX char cmsy10 32 786434 288522 -104694 |
| `f\colon X\hookrightarrow Y` | text | 12 | 0 | 4: kern 87380, TeX glue 87380 0 0 |
| `f\colon X\hookrightarrow Y` | display | 12 | 0 | 4: kern 87380, TeX glue 87380 0 0 |
| `x\xrightarrow{f}y` | text | 12 | 390972 | not supported by the TeX-rule layout: xArrow |
| `x\xrightarrow{f}y` | display | 12 | 390972 | not supported by the TeX-rule layout: xArrow |
| `x\xrightarrow[g]{f}y` | text | 12 | 390972 | not supported by the TeX-rule layout: xArrow |
| `x\xrightarrow[g]{f}y` | display | 12 | 390972 | not supported by the TeX-rule layout: xArrow |
| `x\overset{f}{\longrightarrow}y` | text | 12 | 0 | 3.0.3.0: hbox 611671 0 0 shift 0 (1), TeX kern 0 |
| `x\overset{f}{\longrightarrow}y` | display | 12 | 0 | 3.0.3.0: hbox 611671 0 0 shift 0 (1), TeX kern 0 |
| `A\xleftarrow{\frac12}B` | text | 12 | 348665 | not supported by the TeX-rule layout: xArrow |
| `A\xleftarrow{\frac12}B` | display | 12 | 348665 | not supported by the TeX-rule layout: xArrow |
| `a\cong b` | text | 12 | 32768 | not supported by the TeX-rule layout: symbol \cong |
| `a\cong b` | display | 12 | 32768 | not supported by the TeX-rule layout: symbol \cong |
| `a\models b` | text | 12 | 4388 | not supported by the TeX-rule layout: symbol \models |
| `a\models b` | display | 12 | 4388 | not supported by the TeX-rule layout: symbol \models |
| `\hbar` | text | 12 | 18607 | not supported by the TeX-rule layout: symbol \hbar |
| `\hbar` | display | 12 | 18607 | not supported by the TeX-rule layout: symbol \hbar |
| `\checkmark` | text | 12 | 264 | not supported by the TeX-rule layout: symbol \checkmark |
| `\checkmark` | display | 12 | 264 | not supported by the TeX-rule layout: symbol \checkmark |
| `\begin{matrix}a&b\\c&d\end{matrix}` | text | 12 | 0 | 2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\begin{matrix}a&b\\c&d\end{matrix}` | display | 12 | 0 | 2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\begin{bmatrix}a&b\\c&d\end{bmatrix}` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\begin{bmatrix}a&b\\c&d\end{bmatrix}` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\begin{Bmatrix}a&b\\c&d\end{Bmatrix}` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\begin{Bmatrix}a&b\\c&d\end{Bmatrix}` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\begin{Vmatrix}a&b\\c&d\end{Vmatrix}` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\begin{Vmatrix}a&b\\c&d\end{Vmatrix}` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\begin{smallmatrix}a&b\\c&d\end{smallmatrix}` | text | 12 | 179711 | not supported by the TeX-rule layout: this array environment |
| `\begin{smallmatrix}a&b\\c&d\end{smallmatrix}` | display | 12 | 179711 | not supported by the TeX-rule layout: this array environment |
| `\left(\begin{smallmatrix}a&b\\c&d\end{smallmatrix}\right)` | text | 12 | 288924 | not supported by the TeX-rule layout: this array environment |
| `\left(\begin{smallmatrix}a&b\\c&d\end{smallmatrix}\right)` | display | 12 | 288924 | not supported by the TeX-rule layout: this array environment |
| `\begin{pmatrix}1&0&0\\0&1&0\\0&0&1\end{pmatrix}` | text | 12 | 0 | 1.2.0.3: hbox 1040380 506811 0 shift 0 (7), TeX hbox 1040380 665187 285084 shift 0 (7) |
| `\begin{pmatrix}1&0&0\\0&1&0\\0&0&1\end{pmatrix}` | display | 12 | 0 | 1.2.0.3: hbox 1040380 506811 0 shift 0 (7), TeX hbox 1040380 665187 285084 shift 0 (7) |
| `\begin{pmatrix}a\\b\end{pmatrix}` | text | 12 | 0 | 1.2.0.1.6: glue 0 65536 0, TeX math false |
| `\begin{pmatrix}a\\b\end{pmatrix}` | display | 12 | 0 | 1.2.0.1.6: glue 0 65536 0, TeX math false |
| `\begin{pmatrix}a&b\end{pmatrix}` | text | 12 | 0 | 1.2.0.3: hbox 982762 546132 0 shift 0 (7), TeX hbox 982762 665187 285084 shift 0 (7) |
| `\begin{pmatrix}a&b\end{pmatrix}` | display | 12 | 0 | 1.2.0.3: hbox 982762 546132 0 shift 0 (7), TeX hbox 982762 665187 285084 shift 0 (7) |
| `\begin{pmatrix}\frac12&\frac34\\x&y\end{pmatrix}` | text | 12 | 0 | 1.2.0.3: hbox 1091178 647518 271194 shift 0 (7), TeX hbox 1091178 665187 285084 shift 0 (10) |
| `\begin{pmatrix}\frac12&\frac34\\x&y\end{pmatrix}` | display | 12 | 0 | 1.2.0.3: hbox 1091178 647518 271194 shift 0 (7), TeX hbox 1091178 665187 285084 shift 0 (10) |
| `\begin{bmatrix}x^2&\sum_i y_i\\\sqrt{z}&w\end{bmatrix}` | text | 12 | 0 | 1.2.0.3: hbox 2436869 589829 229381 shift 0 (11), TeX hbox 2436869 665187 285084 shift 0 (14) |
| `\begin{bmatrix}x^2&\sum_i y_i\\\sqrt{z}&w\end{bmatrix}` | display | 12 | 0 | 1.2.0.3: hbox 2436869 589829 229381 shift 0 (11), TeX hbox 2436869 665187 285084 shift 0 (14) |
| `\begin{pmatrix}1&\cdots&n\\\vdots&\ddots&\vdots\\m&\cdots&mn\end{pmatrix}` | text | 12 | 267837 | not supported by the TeX-rule layout: symbol \varvdots |
| `\begin{pmatrix}1&\cdots&n\\\vdots&\ddots&\vdots\\m&\cdots&mn\end{pmatrix}` | display | 12 | 267837 | not supported by the TeX-rule layout: symbol \varvdots |
| `\begin{vmatrix}a&b&c\\d&e&f\\g&h&i\end{vmatrix}` | text | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\begin{vmatrix}a&b&c\\d&e&f\\g&h&i\end{vmatrix}` | display | 12 | 0 | 1.2.0.3: hbox 1098634 546132 0 shift 0 (7), TeX hbox 1098634 665187 285084 shift 0 (7) |
| `\begin{pmatrix}a&b\\c&d\end{pmatrix}^2` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\begin{pmatrix}a&b\\c&d\end{pmatrix}^2` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\begin{pmatrix}a&b\\c&d\end{pmatrix}\begin{pmatrix}x\\y\end{pmatrix}` | text | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\begin{pmatrix}a&b\\c&d\end{pmatrix}\begin{pmatrix}x\\y\end{pmatrix}` | display | 12 | 0 | 1.2.0.3: hbox 1055490 546132 0 shift 0 (7), TeX hbox 1055490 665187 285084 shift 0 (10) |
| `\begin{matrix}abc&d\\e&fghij\end{matrix}` | text | 12 | 0 | 2.0.3: hbox 2584619 546132 0 shift 0 (7), TeX hbox 2584619 665187 285084 shift 0 (10) |
| `\begin{matrix}abc&d\\e&fghij\end{matrix}` | display | 12 | 0 | 2.0.3: hbox 2584619 546132 0 shift 0 (7), TeX hbox 2584619 665187 285084 shift 0 (10) |
| `\begin{cases}a&x>0\\b&x\le0\end{cases}` | text | 12 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}a&x>0\\b&x\le0\end{cases}` | display | 12 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `f(x)=\begin{cases}1&x>0\\0&\text{otherwise}\end{cases}` | text | 12 | 0 | 9.1.0.1.1: glue 0 0 0, TeX math false |
| `f(x)=\begin{cases}1&x>0\\0&\text{otherwise}\end{cases}` | display | 12 | 0 | 9.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}\frac12&a\\\sqrt{x}&b\\c&d\end{cases}` | text | 12 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}\frac12&a\\\sqrt{x}&b\\c&d\end{cases}` | display | 12 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}a\end{cases}` | text | 12 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}a\end{cases}` | display | 12 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}x&\text{if }x\ge0,\\-x&\text{if }x<0\end{cases}` | text | 12 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{cases}x&\text{if }x\ge0,\\-x&\text{if }x<0\end{cases}` | display | 12 | 0 | 1.1.0.1.1: glue 0 0 0, TeX math false |
| `\begin{array}{lcr}a&b&c\\dd&ee&ff\end{array}` | text | 12 | 0 | 1.0.3: hbox 1369150 546132 0 shift 0 (7), TeX hbox 1369150 665187 285084 shift 0 (7) |
| `\begin{array}{lcr}a&b&c\\dd&ee&ff\end{array}` | display | 12 | 0 | 1.0.3: hbox 1369150 546132 0 shift 0 (7), TeX hbox 1369150 665187 285084 shift 0 (7) |
| `\begin{array}{c}a\\b\end{array}` | text | 12 | 0 | 1.0.1.6: glue 0 65536 0, TeX math false |
| `\begin{array}{c}a\\b\end{array}` | display | 12 | 0 | 1.0.1.6: glue 0 65536 0, TeX math false |
| `\begin{array}{l}a\\bbb\end{array}` | text | 12 | 0 | 1.0.1.5: glue 0 65536 0, TeX math false |
| `\begin{array}{l}a\\bbb\end{array}` | display | 12 | 0 | 1.0.1.5: glue 0 65536 0, TeX math false |
| `\begin{array}{r}a\\bbb\end{array}` | text | 12 | 0 | 1.0.1.6: glue 327680 0 0, TeX math false |
| `\begin{array}{r}a\\bbb\end{array}` | display | 12 | 0 | 1.0.1.6: glue 327680 0 0, TeX math false |
| `\begin{array}{cc}a&b\end{array}` | text | 12 | 0 | 1.0.3: hbox 982762 546132 0 shift 0 (7), TeX hbox 982762 665187 285084 shift 0 (7) |
| `\begin{array}{cc}a&b\end{array}` | display | 12 | 0 | 1.0.3: hbox 982762 546132 0 shift 0 (7), TeX hbox 982762 665187 285084 shift 0 (7) |
| `\begin{array}{rl}x&=1\\yyy&=2\end{array}` | text | 12 | 0 | 1.0.3: hbox 1857750 506811 0 shift 0 (8), TeX hbox 1857750 665187 285084 shift 0 (11) |
| `\begin{array}{rl}x&=1\\yyy&=2\end{array}` | display | 12 | 0 | 1.0.3: hbox 1857750 506811 0 shift 0 (8), TeX hbox 1857750 665187 285084 shift 0 (11) |
| `\begin{array}{c\|c}a&b\\\hline c&d\end{array}` | text | 12 | 282755 | not supported by the TeX-rule layout: array rules |
| `\begin{array}{c\|c}a&b\\\hline c&d\end{array}` | display | 12 | 282755 | not supported by the TeX-rule layout: array rules |
| `\begin{array}{ccc}\frac12&x&\sum\\a&\sqrt{b}&c\end{array}` | text | 12 | 0 | 1.0.3: hbox 1638124 338603 0 shift 0 (7), TeX hbox 1638124 665187 285084 shift 0 (7) |
| `\begin{array}{ccc}\frac12&x&\sum\\a&\sqrt{b}&c\end{array}` | display | 12 | 0 | 1.0.3: hbox 1638124 338603 0 shift 0 (7), TeX hbox 1638124 665187 285084 shift 0 (7) |
| `\begin{array}{lcr}1&22&333\\4444&55&6\end{array}` | text | 12 | 0 | 1.0.3: hbox 1425400 506811 0 shift 0 (8), TeX hbox 1425400 665187 285084 shift 0 (8) |
| `\begin{array}{lcr}1&22&333\\4444&55&6\end{array}` | display | 12 | 0 | 1.0.3: hbox 1425400 506811 0 shift 0 (8), TeX hbox 1425400 665187 285084 shift 0 (8) |
| `\begin{array}[t]{c}a\\b\end{array}` | text | 12 | none | KaTeX parse error: Unknown column alignment: [ at position 14: \begin{array}[̲t]{c}a\\b\end{a… |
| `\begin{array}[t]{c}a\\b\end{array}` | display | 12 | none | KaTeX parse error: Unknown column alignment: [ at position 14: \begin{array}[̲t]{c}a\\b\end{a… |
| `\begin{array}[b]{c}a\\b\end{array}` | text | 12 | none | KaTeX parse error: Unknown column alignment: [ at position 14: \begin{array}[̲b]{c}a\\b\end{a… |
| `\begin{array}[b]{c}a\\b\end{array}` | display | 12 | none | KaTeX parse error: Unknown column alignment: [ at position 14: \begin{array}[̲b]{c}a\\b\end{a… |
| `\begin{array}{@{}c@{}}a\end{array}` | text | 12 | none | KaTeX parse error: Unknown column alignment: @ at position 15: \begin{array}{@̲{}c@{}}a\end{ar… |
| `\begin{array}{@{}c@{}}a\end{array}` | display | 12 | none | KaTeX parse error: Unknown column alignment: @ at position 15: \begin{array}{@̲{}c@{}}a\end{ar… |
| `\begin{array}{c@{\,}c}a&b\end{array}` | text | 12 | none | KaTeX parse error: Unknown column alignment: @ at position 16: \begin{array}{c@̲{\,}c}a&b\end{a… |
| `\begin{array}{c@{\,}c}a&b\end{array}` | display | 12 | none | KaTeX parse error: Unknown column alignment: @ at position 16: \begin{array}{c@̲{\,}c}a&b\end{a… |
| `\substack{a\\b}` | text | 12 | 162267 | not supported by the TeX-rule layout: array cells in script style |
| `\substack{a\\b}` | display | 12 | 162267 | not supported by the TeX-rule layout: array cells in script style |
| `\sum_{\substack{a\\b}}` | text | 12 | 112440 | not supported by the TeX-rule layout: array cells in script style |
| `\sum_{\substack{a\\b}}` | display | 12 | 145798 | not supported by the TeX-rule layout: array cells in script style |
| `\begin{aligned}a&=b\\c&=d\end{aligned}` | text | 12 | 33541 | not supported by the TeX-rule layout: this array environment |
| `\begin{aligned}a&=b\\c&=d\end{aligned}` | display | 12 | 33541 | not supported by the TeX-rule layout: this array environment |
| `\begin{gathered}a\\bb\end{gathered}` | text | 12 | 19954 | not supported by the TeX-rule layout: this array environment |
| `\begin{gathered}a\\bb\end{gathered}` | display | 12 | 19954 | not supported by the TeX-rule layout: this array environment |
| `\overset{\mathrm{def}}{=}` | text | 12 | 0 | 1.0.3.1: char cmr12 61 598920 283824 -109392, TeX kern 0 |
| `\overset{\mathrm{def}}{=}` | display | 12 | 0 | 1.0.3.1: char cmr12 61 598920 283824 -109392, TeX kern 0 |
| `\boxed{x}` | text | 12 | 44568 | not supported by the TeX-rule layout: enclose |
| `\boxed{x}` | display | 12 | 44568 | not supported by the TeX-rule layout: enclose |
| `\boxed{\frac12}` | text | 12 | 65868 | not supported by the TeX-rule layout: enclose |
| `\boxed{\frac12}` | display | 12 | 65868 | not supported by the TeX-rule layout: enclose |
| `\fbox{x}` | text | 12 | 44564 | not supported by the TeX-rule layout: enclose |
| `\fbox{x}` | display | 12 | 44564 | not supported by the TeX-rule layout: enclose |
| `\left(a\atop b\right)` | text | 12 | 26258 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `\left(a\atop b\right)` | display | 12 | 42902 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `a\over b` | text | 12 | 26786 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `a\over b` | display | 12 | 268298 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\over b}` | text | 12 | 26786 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\over b}` | display | 12 | 43254 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\choose b}` | text | 12 | 5199 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\choose b}` | display | 12 | 11617 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\above 1pt b}` | text | 12 | 32454 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\above 1pt b}` | display | 12 | 45873 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\overwithdelims() b}` | text | 12 | none | KaTeX parse error: Undefined control sequence: \overwithdelims at position 3: {a\̲o̲v̲e̲r̲w̲i̲t̲h̲d̲e̲l̲i̲m̲s̲() b} |
| `{a\overwithdelims() b}` | display | 12 | none | KaTeX parse error: Undefined control sequence: \overwithdelims at position 3: {a\̲o̲v̲e̲r̲w̲i̲t̲h̲d̲e̲l̲i̲m̲s̲() b} |
| `{a\atopwithdelims[] b}` | text | 12 | none | KaTeX parse error: Undefined control sequence: \atopwithdelims at position 3: {a\̲a̲t̲o̲p̲w̲i̲t̲h̲d̲e̲l̲i̲m̲s̲[] b} |
| `{a\atopwithdelims[] b}` | display | 12 | none | KaTeX parse error: Undefined control sequence: \atopwithdelims at position 3: {a\̲a̲t̲o̲p̲w̲i̲t̲h̲d̲e̲l̲i̲m̲s̲[] b} |
| `{a\brace b}` | text | 12 | 5199 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\brace b}` | display | 12 | 11795 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\brack b}` | text | 12 | 4149 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `{a\brack b}` | display | 12 | 12143 | not supported by the TeX-rule layout: \over, \atop, \choose, \above or glue with plus or minus |
| `\mathchar"7141` | text | 12 | none | KaTeX parse error: Undefined control sequence: \mathchar at position 1: \̲m̲a̲t̲h̲c̲h̲a̲r̲"7141 |
| `\mathchar"7141` | display | 12 | none | KaTeX parse error: Undefined control sequence: \mathchar at position 1: \̲m̲a̲t̲h̲c̲h̲a̲r̲"7141 |
| `\delimiter"4266308` | text | 12 | none | KaTeX parse error: Undefined control sequence: \delimiter at position 1: \̲d̲e̲l̲i̲m̲i̲t̲e̲r̲"4266308 |
| `\delimiter"4266308` | display | 12 | none | KaTeX parse error: Undefined control sequence: \delimiter at position 1: \̲d̲e̲l̲i̲m̲i̲t̲e̲r̲"4266308 |
| `\radical"270370{x}` | text | 12 | none | KaTeX parse error: Undefined control sequence: \radical at position 1: \̲r̲a̲d̲i̲c̲a̲l̲"270370{x} |
| `\radical"270370{x}` | display | 12 | none | KaTeX parse error: Undefined control sequence: \radical at position 1: \̲r̲a̲d̲i̲c̲a̲l̲"270370{x} |
| `\skew{3}\hat{x}` | text | 12 | none | KaTeX parse error: Undefined control sequence: \skew at position 1: \̲s̲k̲e̲w̲{3}\hat{x} |
| `\skew{3}\hat{x}` | display | 12 | none | KaTeX parse error: Undefined control sequence: \skew at position 1: \̲s̲k̲e̲w̲{3}\hat{x} |
| `\vcenter{\hbox{x}}` | text | 12 | 173 | not supported by the TeX-rule layout: vcenter |
| `\vcenter{\hbox{x}}` | display | 12 | 173 | not supported by the TeX-rule layout: vcenter |
| `\raise2pt\hbox{x}` | text | 12 | none | KaTeX parse error: Undefined control sequence: \raise at position 1: \̲r̲a̲i̲s̲e̲2pt\hbox{x} |
| `\raise2pt\hbox{x}` | display | 12 | none | KaTeX parse error: Undefined control sequence: \raise at position 1: \̲r̲a̲i̲s̲e̲2pt\hbox{x} |
| `\lower2pt\hbox{x}` | text | 12 | none | KaTeX parse error: Undefined control sequence: \lower at position 1: \̲l̲o̲w̲e̲r̲2pt\hbox{x} |
| `\lower2pt\hbox{x}` | display | 12 | none | KaTeX parse error: Undefined control sequence: \lower at position 1: \̲l̲o̲w̲e̲r̲2pt\hbox{x} |
| `\mathsurround=3pt a` | text | 12 | none | KaTeX parse error: Undefined control sequence: \mathsurround at position 1: \̲m̲a̲t̲h̲s̲u̲r̲r̲o̲u̲n̲d̲=3pt a |
| `\mathsurround=3pt a` | display | 12 | none | KaTeX parse error: Undefined control sequence: \mathsurround at position 1: \̲m̲a̲t̲h̲s̲u̲r̲r̲o̲u̲n̲d̲=3pt a |
| `\rule{1pt}{1em}` | text | 12 | 13107 | not supported by the TeX-rule layout: rule |
| `\rule{1pt}{1em}` | display | 12 | 13107 | not supported by the TeX-rule layout: rule |
| `\rule[-2pt]{3pt}{2pt}` | text | 12 | 39322 | not supported by the TeX-rule layout: rule |
| `\rule[-2pt]{3pt}{2pt}` | display | 12 | 39322 | not supported by the TeX-rule layout: rule |
| `x\hbox to 10pt{\hfil a}y` | text | 12 | none | KaTeX parse error: Undefined control sequence: \hfil at position 16: x\hbox to 10pt{\̲h̲f̲i̲l̲ ̲a}y |
| `x\hbox to 10pt{\hfil a}y` | display | 12 | none | KaTeX parse error: Undefined control sequence: \hfil at position 16: x\hbox to 10pt{\̲h̲f̲i̲l̲ ̲a}y |
| `\mathchar"0161` | text | 12 | none | KaTeX parse error: Undefined control sequence: \mathchar at position 1: \̲m̲a̲t̲h̲c̲h̲a̲r̲"0161 |
| `\mathchar"0161` | display | 12 | none | KaTeX parse error: Undefined control sequence: \mathchar at position 1: \̲m̲a̲t̲h̲c̲h̲a̲r̲"0161 |
| `\fam1 a` | text | 12 | none | KaTeX parse error: Undefined control sequence: \fam at position 1: \̲f̲a̲m̲1 a |
| `\fam1 a` | display | 12 | none | KaTeX parse error: Undefined control sequence: \fam at position 1: \̲f̲a̲m̲1 a |
| `\hbox{$x^2$}` | text | 12 | 16976 | not supported by the TeX-rule layout: a box that is not plain text |
| `\hbox{$x^2$}` | display | 12 | 16976 | not supported by the TeX-rule layout: a box that is not plain text |
| `\vrule` | text | 12 | none | KaTeX parse error: Undefined control sequence: \vrule at position 1: \̲v̲r̲u̲l̲e̲ |
| `\vrule` | display | 12 | none | KaTeX parse error: Undefined control sequence: \vrule at position 1: \̲v̲r̲u̲l̲e̲ |
| `a\nonscript\mskip 4mu b` | text | 12 | none | KaTeX parse error: Undefined control sequence: \nonscript at position 2: a\̲n̲o̲n̲s̲c̲r̲i̲p̲t̲\mskip 4mu b |
| `a\nonscript\mskip 4mu b` | display | 12 | none | KaTeX parse error: Undefined control sequence: \nonscript at position 2: a\̲n̲o̲n̲s̲c̲r̲i̲p̲t̲\mskip 4mu b |
| `x_{a\nonscript\mskip4mu b}` | text | 12 | none | KaTeX parse error: Undefined control sequence: \nonscript at position 5: x_{a\̲n̲o̲n̲s̲c̲r̲i̲p̲t̲\mskip4mu b} |
| `x_{a\nonscript\mskip4mu b}` | display | 12 | none | KaTeX parse error: Undefined control sequence: \nonscript at position 5: x_{a\̲n̲o̲n̲s̲c̲r̲i̲p̲t̲\mskip4mu b} |
