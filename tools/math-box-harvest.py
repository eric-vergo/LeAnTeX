#!/usr/bin/env python3
# Released under Apache 2.0 license as described in the file LICENSE.
# Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
#
# Prints the formulas of the reference documents, corpus/doc/*.tex, as `doc<TAB>formula` lines
# for corpus/math-box/formulas.tsv: the inline math ($…$ and \(…\)) and the content of \[…\],
# equation and equation* of each document, deduplicated, in order of appearance. Alignment
# environments and formulas with \label, \tag, a row break, a top-level & or a macro the
# document defines itself are skipped. Run from the repository root:
#     python3 -I tools/math-box-harvest.py

import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOCS = ROOT / "corpus" / "doc"

# Formula delimiters: inline $…$, \(…\), display \[…\], equation and equation*.
PATTERN = re.compile(
    r"(?<!\\)\$\$(?P<dd>.+?)(?<!\\)\$\$"
    r"|(?<!\\)\$(?P<i>[^$]+?)(?<!\\)\$"
    r"|\\\((?P<p>.+?)\\\)"
    r"|\\\[(?P<d>.+?)\\\]"
    r"|\\begin\{equation\*?\}(?P<e>.+?)\\end\{equation\*?\}",
    re.S,
)

# Commands whose presence rules a formula out.
FORBIDDEN = re.compile(r"\\(label|tag|notag|ref|eqref|cite|\\)(?![A-Za-z])")


def strip_comments(text):
    """Removes the % comments of a document (an escaped \\% stays)."""
    return re.sub(r"(?<!\\)%.*", "", text)


def user_macros(text):
    """The control sequences the document defines itself."""
    names = re.findall(r"\\(?:re)?newcommand\*?\{?\\([A-Za-z]+)", text)
    names += re.findall(r"\\(?:e|g|x)?def\\([A-Za-z]+)", text)
    names += re.findall(r"\\DeclareMathOperator\*?\{\\([A-Za-z]+)\}", text)
    names += re.findall(r"\\newtheorem\{([A-Za-z]+)\}", text)
    return set(names)


def top_level_ampersand(formula):
    """Whether the formula has an & outside every brace group and environment."""
    depth = 0
    env = 0
    i = 0
    while i < len(formula):
        if formula.startswith("\\begin{", i):
            env += 1
        elif formula.startswith("\\end{", i):
            env -= 1
        elif formula[i] == "\\":
            i += 1
        elif formula[i] == "{":
            depth += 1
        elif formula[i] == "}":
            depth -= 1
        elif formula[i] == "&" and depth == 0 and env == 0:
            return True
        i += 1
    return False


def formulas(path):
    """The usable formulas of one document, in order."""
    text = strip_comments(path.read_text(encoding="utf-8"))
    body = text.split("\\begin{document}", 1)[-1]
    macros = user_macros(text)
    out = []
    for m in PATTERN.finditer(body):
        f = " ".join(next(v for v in m.groupdict().values() if v is not None).split())
        if not f or FORBIDDEN.search(f) or top_level_ampersand(f):
            continue
        if re.search(r"\\begin\{(align|gather|multline|split|eqnarray|flalign)", f):
            continue
        if any(re.search(r"\\" + re.escape(n) + r"(?![A-Za-z])", f) for n in macros):
            continue
        if "\t" in f or "\\verb" in f or "\\text{" in f and "$" in f:
            continue
        out.append(f)
    return out


def main():
    """Prints the deduplicated `doc<TAB>formula` lines of every reference document."""
    seen = set()
    for path in sorted(DOCS.glob("*.tex")):
        for f in formulas(path):
            if f not in seen:
                seen.add(f)
                print("doc\t" + f)


if __name__ == "__main__":
    main()
