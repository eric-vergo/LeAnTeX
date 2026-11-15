# Released under Apache 2.0 license as described in the file LICENSE.
# Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
#
# Writes the hyphenation data modules from a TeX Live tree, the patterns and exceptions copied
# verbatim with each source file's notice:
#   * LeAnTeX/Data/HyphenEnglish.lean from tex/generic/hyphen/hyphen.tex, Knuth's plain TeX
#     patterns: TeX Live's language `english` (language 0, LaTeX's default). Its terms allow
#     unlimited copying and redistribution, and modified copies under another name.
#   * LeAnTeX/Data/HyphenEnUs.lean from the hyph-utf8 package's hyph-en-us (`usenglishmax`):
#     Knuth's patterns with Gerard Kuiken's additions. Its licence permits copying and
#     distribution with or without modification, the copyright notice and licence preserved.
#
# Usage, from the repository root:
#   python3 -I tools/gen-hyphen.py [TEXMF-DIST]
# (default: the first /usr/local/texlive/*/texmf-dist that has the files)

import glob
import os
import sys

SUB = "tex/generic/hyph-utf8/patterns"


def find_root():
    """The texmf-dist directory given on the command line, or the first TeX Live one found."""
    if len(sys.argv) > 1:
        return sys.argv[1]
    for d in sorted(glob.glob("/usr/local/texlive/*/texmf-dist")):
        if os.path.exists(os.path.join(d, SUB, "txt", "hyph-en-us.pat.txt")):
            return d
    sys.exit("gen-hyphen: no TeX Live tree with hyph-en-us found")


def notice(tex):
    """The header of hyph-en-us.tex up to its `changes:` field: title, copyright, notice,
    licence and hyphen minima, without TeX's comment signs."""
    out = []
    for line in tex.splitlines():
        if not line.startswith("%"):
            break
        body = line[1:].rstrip()
        if body.strip().startswith("changes:") or body.lstrip().startswith("\\"):
            break
        out.append(body)
    return "\n".join(out)


def chunks(s, width=90):
    """A long literal written over several lines with Lean's string gaps (a backslash at the
    end of a line skips the newline and the next line's indentation)."""
    lines = s.split("\n")
    pieces, cur = [], ""
    for ln in lines:
        add = ln + "\n"
        if len(cur) + len(add) > width - 10 and cur:
            pieces.append(cur)
            cur = ""
        cur += add
    if cur:
        pieces.append(cur)
    body = "\\\n    ".join(p.replace("\n", "\\n") for p in pieces)
    assert all(c.isalnum() or c in ".-\n\\ " for c in body), "unexpected character"
    return '"' + body + '"'


def module(name, title, doc, note, pats, hyps):
    """The text of one data module: `name` its Lean suffix, `doc` the paragraph on its
    source, `note` the source's notice."""
    return f"""/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/

/-!
# {title}

{doc}
Copied by `tools/gen-hyphen.py`: {len(pats)} patterns and {len(hyps)} exceptions.

The source file's notice, kept with the copy as its terms ask:

```
{note}
```
-/

namespace LeAnTeX.Data

/-- The patterns, one per line, as in the source. -/
def hyphen{name}Patterns : String :=
  {chunks(chr(10).join(pats))}

/-- The exceptions, one per line, hyphens at the allowed points, as in the source. -/
def hyphen{name}Exceptions : String :=
  {chunks(chr(10).join(hyps))}

end LeAnTeX.Data
"""


def tex_lists(tex):
    """The words of a TeX file's \\patterns{{…}} and \\hyphenation{{…}}, comments removed."""
    def words(key):
        body = tex.split("\\" + key + "{", 1)[1].split("}", 1)[0]
        return [w for ln in body.splitlines() for w in ln.split("%", 1)[0].split()]
    return words("patterns"), words("hyphenation")


def write(path, text):
    """Writes one module."""
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def main():
    """Reads the sources and writes the two modules."""
    root = find_root()
    base = os.path.join(root, SUB)
    pat = open(os.path.join(base, "txt", "hyph-en-us.pat.txt"), encoding="utf-8").read().split()
    hyp = open(os.path.join(base, "txt", "hyph-en-us.hyp.txt"), encoding="utf-8").read().split()
    tex = open(os.path.join(base, "tex", "hyph-en-us.tex"), encoding="utf-8").read()
    write("LeAnTeX/Data/HyphenEnUs.lean", module(
        "EnUs", "US English hyphenation patterns (`usenglishmax`)",
        "The hyphenation patterns and exceptions for American English of the hyph-utf8 package, "
        "as TeX Live ships them\n(`tex/generic/hyph-utf8/patterns/txt/hyph-en-us.pat.txt` and "
        "`hyph-en-us.hyp.txt`, the data of\n`hyph-en-us.tex`): Knuth's patterns with Gerard "
        "Kuiken's additions (`ushyphmax.tex`), TeX Live's\nlanguage `usenglishmax`.",
        notice(tex), pat, hyp))
    knuth_path = os.path.join(root, "tex/generic/hyphen/hyphen.tex")
    knuth = open(knuth_path, encoding="utf-8").read()
    kp, kh = tex_lists(knuth)
    write("LeAnTeX/Data/HyphenEnglish.lean", module(
        "English", "English hyphenation patterns (plain TeX's)",
        "Knuth's hyphenation patterns and exceptions for English from plain TeX's `hyphen.tex`, "
        "as TeX\nLive ships it (`tex/generic/hyphen/hyphen.tex`): TeX Live's language "
        "`english`, the language 0\nof LaTeX's formats and so the hyphenation LaTeX uses by "
        "default.",
        notice(knuth), kp, kh))
    print(f"gen-hyphen: usenglishmax {len(pat)}/{len(hyp)}, english {len(kp)}/{len(kh)}")


if __name__ == "__main__":
    main()
