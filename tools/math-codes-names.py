# Released under Apache 2.0 license as described in the file LICENSE.
# Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
#
# Lists the control sequences of LeAnTeX's parser tables: the names of `mathSymbolList`
# (LeAnTeX/Data/Symbols.lean), `functionList` (Functions.lean), `stringMacroList` and
# `nativeMacroNames` (Macros.lean) that start with a backslash, deduplicated and sorted, one per
# line. Names are read as Lean string literals (escapes undone) and are later handed to TeX
# through Lua, never written into TeX source, so no name needs skipping: control symbols such
# as `\ `, `\,` and `\{` and names with `@` are all kept. Names that do not start with a
# backslash (single characters, active characters, Unicode) are not control sequences; the
# recorder covers the ASCII characters separately.
#
# Usage, from the repository root:  python3 -I tools/math-codes-names.py > corpus/math-codes/names.txt
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
ESC = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"', "'": "'"}


def unescape(s):
    """Lean string literal body to its value."""
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c != "\\":
            out.append(c)
            i += 1
        elif s[i + 1] == "x":
            out.append(chr(int(s[i + 2:i + 4], 16)))
            i += 4
        elif s[i + 1] == "u":
            out.append(chr(int(s[i + 2:i + 6], 16)))
            i += 6
        else:
            out.append(ESC[s[i + 1]])
            i += 2
    return "".join(out)


STRING = r'"((?:[^"\\]|\\.)*)"'
# An entry opens a line as `  ("name", ` (tuple lists) or `  "name"` (name array).
ENTRY = re.compile(r'^  \(?' + STRING)


def first_strings(path, start, end):
    """First string of each entry between the line containing `start` and the next `end`."""
    names, on = [], False
    for line in (root / path).read_text(encoding="utf-8").splitlines():
        if start in line:
            on = True
            continue
        if on and line.startswith(end):
            break
        m = ENTRY.match(line) if on else None
        if m:
            names.append(unescape(m.group(1)))
    return names


names = set()
names.update(first_strings("LeAnTeX/Data/Symbols.lean", "def mathSymbolList", "]"))
names.update(first_strings("LeAnTeX/Data/Functions.lean", "def functionList", "]"))
names.update(first_strings("LeAnTeX/Data/Macros.lean", "def stringMacroList", "]"))
names.update(first_strings("LeAnTeX/Data/Macros.lean", "def nativeMacroNames", "]"))
for n in sorted(n for n in names if n.startswith("\\") and len(n) > 1 and "\n" not in n):
    sys.stdout.write(n + "\n")
