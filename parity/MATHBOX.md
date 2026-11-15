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
| accent (text) | 30 | 30 | 30 | 30 | 30 | 27 | 0 |
| accent (display) | 30 | 30 | 30 | 30 | 30 | 27 | 0 |
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
| **all** | 1254 | 1254 | 1254 | 1254 | 1254 | 1182 | 0 |

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
| `\widehat{xy}` | text | 10 | 0 | 1.0: hbox 0 491520 0 shift 32010 (1), TeX hbox 0 491520 0 shift 32011 (1) |
| `\widehat{xy}` | display | 10 | 0 | 1.0: hbox 0 491520 0 shift 32010 (1), TeX hbox 0 491520 0 shift 32011 (1) |
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
| `\frac{a}{\frac{b}{c}}` | text | 11 | 0 | 1.0.1.4.0: hbox 78643 0 0 shift -131072 (0), TeX hbox 377150 487413 205608 shift 0 (3) |
| `\frac{a}{\frac{b}{c}}` | display | 11 | 0 | 1.0.1.4.0: hbox 78643 0 0 shift -179404 (0), TeX hbox 398559 646638 247464 shift 0 (3) |
| `\bigl(x\bigr)` | text | 11 | 0 | 1.1: hbox 328910 28704 832447 shift -581275 (1), TeX hbox 328910 609979 251172 shift 0 (3) |
| `\bigl(x\bigr)` | display | 11 | 0 | 1.1: hbox 328910 28704 832447 shift -581275 (1), TeX hbox 328910 609979 251172 shift 0 (3) |
| `\Bigl(x\Bigr)` | text | 11 | 0 | 1.1: hbox 428579 28704 1263023 shift -796563 (1), TeX hbox 428579 825267 466460 shift 0 (3) |
| `\Bigl(x\Bigr)` | display | 11 | 0 | 1.1: hbox 428579 28704 1263023 shift -796563 (1), TeX hbox 428579 825267 466460 shift 0 (3) |
| `\widehat{xy}` | text | 11 | 0 | 1.0: hbox 0 538214 0 shift 35050 (1), TeX hbox 0 538214 0 shift 35051 (1) |
| `\widehat{xy}` | display | 11 | 0 | 1.0: hbox 0 538214 0 shift 35050 (1), TeX hbox 0 538214 0 shift 35051 (1) |
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
| `\frac{a}{\frac{b}{c}}` | text | 12 | 0 | 1.0.1.4.0: hbox 78643 0 0 shift -131072 (0), TeX hbox 377150 487413 205608 shift 0 (3) |
| `\frac{a}{\frac{b}{c}}` | display | 12 | 0 | 1.0.1.4.1: hbox 78643 0 0 shift -196608 (0), TeX hbox 398559 673732 271194 shift 0 (3) |
| `\bigl(x\bigr)` | text | 12 | 0 | 1.1: hbox 360450 31456 912271 shift -637015 (1), TeX hbox 360450 668471 275256 shift 0 (3) |
| `\bigl(x\bigr)` | display | 12 | 0 | 1.1: hbox 360450 31456 912271 shift -637015 (1), TeX hbox 360450 668471 275256 shift 0 (3) |
| `\Bigl(x\Bigr)` | text | 12 | 0 | 1.1: hbox 469676 31456 1384135 shift -872947 (1), TeX hbox 469676 904403 511188 shift 0 (3) |
| `\Bigl(x\Bigr)` | display | 12 | 0 | 1.1: hbox 469676 31456 1384135 shift -872947 (1), TeX hbox 469676 904403 511188 shift 0 (3) |
| `\widehat{xy}` | text | 12 | 0 | 1.0: hbox 0 589824 0 shift 27416 (1), TeX hbox 0 589824 0 shift 27417 (1) |
| `\widehat{xy}` | display | 12 | 0 | 1.0: hbox 0 589824 0 shift 27416 (1), TeX hbox 0 589824 0 shift 27417 (1) |
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
