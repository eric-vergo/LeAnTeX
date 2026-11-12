# Released under Apache 2.0 license as described in the file LICENSE.
# Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
#
# Extracts the TeX formulas of Mathlib's doc comments into a JSON Lines corpus.
#
# Every `.lean` file under MATHLIB_DIR/Mathlib is scanned for doc comments (`/-- ... -/`)
# and module docs (`/-! ... -/`), with nested `/- -/` comments, string literals and `--`
# line comments handled. In their text, math spans are found as doc-gen4 / Markdown does:
# `$$...$$` is display math, `$...$` is inline math, backtick code spans and fenced code
# blocks are skipped, `\$` is a literal dollar and an unmatched `$` is not math. A span
# does not cross a blank line.
#
# Usage: python3 -I tools/extract-mathlib.py MATHLIB_DIR OUT_FILE

import json
import os
import re
import subprocess
import sys

FENCE = re.compile(r"^\s*(```|~~~)")


def doc_comments(src):
    """Yields (start_offset, text) of each doc comment or module doc in Lean source `src`,
    where text excludes the opening `/--` or `/-!` and the closing `-/`."""
    i, n = 0, len(src)
    while i < n:
        two = src[i:i + 2]
        if two == "--":
            j = src.find("\n", i)
            i = n if j < 0 else j
        elif src[i] == '"':
            i += 1
            while i < n and src[i] != '"':
                i += 2 if src[i] == "\\" else 1
            i += 1
        elif two == "/-":
            is_doc = src[i + 2:i + 3] in ("-", "!")
            start, depth = i + 3 if is_doc else i + 2, 1
            i = start
            while i < n and depth > 0:
                t = src[i:i + 2]
                if t == "/-":
                    depth, i = depth + 1, i + 2
                elif t == "-/":
                    depth, i = depth - 1, i + 2
                else:
                    i += 1
            if is_doc:
                yield start, src[start:i - 2]
        else:
            i += 1


def mask_fences(text):
    """Blanks out fenced code blocks (keeping line structure, so offsets stay valid)."""
    out, fenced = [], False
    for line in text.split("\n"):
        if FENCE.match(line):
            fenced = not fenced
            out.append(" " * len(line))
        else:
            out.append(" " * len(line) if fenced else line)
    return "\n".join(out)


def para_end(text, i):
    """Offset of the end of the paragraph (next blank line) containing offset `i`."""
    m = re.compile(r"\n[ \t]*\n").search(text, i)
    return m.start() if m else len(text)


def find_close(text, i, delim, limit):
    """Offset of the closing `delim` after `i` (before `limit`), skipping `\\x` escapes."""
    while i < limit:
        if text[i] == "\\":
            i += 2
        elif text.startswith(delim, i):
            if delim == "$" and text.startswith("$$", i):
                return -1
            return i
        else:
            i += 1
    return -1


def math_spans(text):
    """Yields (offset, display, tex) for the math spans of one doc comment's text."""
    text_m = mask_fences(text)
    i, n = 0, len(text_m)
    while i < n:
        c = text_m[i]
        if c == "\\":
            i += 2
        elif c == "`":
            j = i
            while j < n and text_m[j] == "`":
                j += 1
            run = text_m[i:j]
            k = text_m.find(run, j)
            while k >= 0 and text_m[k + len(run):k + len(run) + 1] == "`":
                k = text_m.find(run, k + len(run) + 1)
            i = j if k < 0 else k + len(run)
        elif c == "$":
            display = text_m.startswith("$$", i)
            delim = "$$" if display else "$"
            body = i + len(delim)
            end = find_close(text_m, body, delim, para_end(text_m, i))
            if end < 0:
                i = body
                continue
            yield i, display, text[body:end]
            i = end + len(delim)
        else:
            i += 1


def git(d, *args):
    """Runs a read-only git command in `d`; returns its output or None."""
    try:
        return subprocess.run(["git", "-C", d, *args], capture_output=True, text=True,
                              check=True).stdout.strip()
    except Exception:
        return None


def main():
    """Scans Mathlib and writes the corpus."""
    root, out = sys.argv[1:3]
    cases, inline, display = {}, 0, 0
    base = os.path.join(root, "Mathlib")
    files = []
    for d, dirs, names in os.walk(base):
        dirs.sort()
        files += [os.path.join(d, f) for f in sorted(names) if f.endswith(".lean")]
    for path in sorted(files):
        with open(path, encoding="utf-8") as f:
            src = f.read()
        rel = os.path.relpath(path, root)
        for start, text in doc_comments(src):
            for off, disp, tex in math_spans(text):
                if disp:
                    display += 1
                else:
                    inline += 1
                key = (tex, disp)
                if key not in cases:
                    line = src.count("\n", 0, start + off) + 1
                    # Several formulas may start on one line: number them after the first.
                    ident = f"mathlib/{rel}:{line}"
                    n = per_line.get(ident, 0) + 1
                    per_line[ident] = n
                    if n > 1:
                        ident += f"#{n}"
                    cases[key] = {"id": ident, "tex": tex, "display": disp, "count": 0}
                cases[key]["count"] += 1
    rev = git(root, "rev-parse", "HEAD")
    url = (git(root, "remote", "get-url", "origin")
           or "https://github.com/leanprover-community/mathlib4")
    meta = {"corpus": "mathlib", "source": f"Mathlib doc comments from {url}"
            + (f" at commit {rev}" if rev else ""),
            "license": "Apache-2.0 (LICENSE file at the root of the upstream repository)",
            "generator": "tools/extract-mathlib.py", "count": len(cases)}
    with open(out, "w", encoding="utf-8") as f:
        f.write(json.dumps({"meta": meta}, ensure_ascii=False, sort_keys=True) + "\n")
        for c in cases.values():
            f.write(json.dumps(c, ensure_ascii=False, sort_keys=True) + "\n")
    print(f"{inline} inline, {display} display, {len(cases)} distinct cases, {len(files)} files")


main()
