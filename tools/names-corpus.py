# Released under Apache 2.0 license as described in the file LICENSE.
# Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
#
# Writes corpus/katex-names.jsonl: a few formulas for every name KaTeX defines
# (parity/names.tsv), so that each function, environment, macro and symbol is parsed at least
# once by the differential test, whether KaTeX accepts the formula or rejects it.
#
# Usage, from the repository root: python3 -I tools/names-corpus.py

import json


def unescape(s):
    """Undo the escaping of parity/names.tsv (backslash, tab, newline)."""
    out, esc = [], False
    for c in s:
        if esc:
            out.append({"t": "\t", "n": "\n"}.get(c, c))
            esc = False
        elif c == "\\":
            esc = True
        else:
            out.append(c)
    return "".join(out)


def formulas(kind, name):
    """The formulas (tex, display) that exercise one name."""
    if kind == "environment":
        body = "a & b \\\\ c & d"
        arg = "{cc}" if name in ("array", "darray", "alignat", "alignat*", "alignedat") else ""
        if name == "subarray":
            arg = "{c}"
        tex = "\\begin{%s}%s %s \\end{%s}" % (name, arg, body, name)
        return [(tex, False), (tex, True)]
    if kind == "symbol-text":
        return [("\\text{%s}" % name, False), ("\\text{a%s b}" % name, False)]
    out = [(name, False), (name + "{a}{b}{c}", False), ("x" + name + " y", True)]
    if kind == "function":
        out.append(("\\text{" + name + "{a}}", False))
    return out


def main():
    """Read the name list and write the corpus."""
    rows = []
    with open("parity/names.tsv", encoding="utf-8") as f:
        lines = f.read().split("\n")
    seen = set()
    for line in lines[2:]:
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        kind, name = parts[0], unescape(parts[1])
        for i, (tex, display) in enumerate(formulas(kind, name)):
            if (tex, display) in seen:
                continue
            seen.add((tex, display))
            rows.append({"id": "katex-names/%s/%s/%d" % (kind, name, i + 1), "tex": tex,
                         "display": display, "count": 1})
    meta = {"meta": {"corpus": "katex-names", "count": len(rows),
                     "source": "generated from KaTeX 0.19.1's name list (parity/names.tsv)",
                     "license": "Apache-2.0 (generated)",
                     "generator": "tools/names-corpus.py"}}
    with open("corpus/katex-names.jsonl", "w", encoding="utf-8") as f:
        for r in [meta] + rows:
            f.write(json.dumps(r, ensure_ascii=False, sort_keys=True) + "\n")
    print("katex-names: %d cases" % len(rows))


main()
