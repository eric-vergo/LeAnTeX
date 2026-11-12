# Released under Apache 2.0 license as described in the file LICENSE.
# Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
#
# Extracts the TeX formulas of a built Verso blueprint site into a JSON Lines corpus.
#
# The site renders math in the browser: elements with class `bp_math inline|display`
# are handed to `katex.render(prelude + "\n" + text, el, {throwOnError: false,
# displayMode})` (preview-runtime-hydration.mjs, `renderBlueprintMath`), where the
# prelude is looked up per element from `window.bpTexPreludeTable[data-bp-tex-prelude-id]`
# (or the `data-bp-tex-prelude` attribute) and trimmed; Verso's own `math inline|display`
# elements are rendered by katex/math.js with the bare element text. This script
# reproduces exactly that input: the prelude is part of `tex`, and no `macros` are passed.
#
# Usage: python3 -I tools/extract-blueprint.py SITE_DIR CORPUS_NAME OUT_FILE [LICENSE_TEXT]
#   SITE_DIR is the `html-multi` directory of the site (all `index.html` pages below it are
#   read, except the search pages `search/` and `find/` and the `-verso-*` data folders).

import json
import os
import re
import subprocess
import sys
from html.parser import HTMLParser

VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta",
        "param", "source", "track", "wbr"}
TABLE_RE = re.compile(r"window\.bpTexPreludeTable\s*\|\|\s*\{\}\s*,\s*")


class MathParser(HTMLParser):
    """Collects (kind, display, prelude_id, prelude_attr, text) for each math element,
    and the prelude tables assigned in the page's scripts."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.found = []
        self.table = {}
        self.cur = None  # [display, prelude_id, prelude_attr, text parts, depth, kind]
        self.in_script = False
        self.script = []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "script":
            self.in_script = True
            self.script = []
        if self.cur is not None:
            if tag not in VOID:
                self.cur[4] += 1
            return
        classes = (a.get("class") or "").split()
        kind = None
        if "bp_math" in classes:
            kind = "bp"
        elif "math" in classes:
            kind = "verso"
        if kind and ("inline" in classes or "display" in classes):
            self.cur = [("display" in classes), (a.get("data-bp-tex-prelude-id") or "").strip(),
                        a.get("data-bp-tex-prelude"), [], 1, kind]

    def handle_endtag(self, tag):
        if tag == "script" and self.in_script:
            self.in_script = False
            self.read_table("".join(self.script))
        if self.cur is not None:
            self.cur[4] -= 1
            if self.cur[4] == 0:
                c = self.cur
                self.found.append((c[5], c[0], c[1], c[2], "".join(c[3])))
                self.cur = None

    def handle_data(self, data):
        if self.in_script:
            self.script.append(data)
        elif self.cur is not None:
            self.cur[3].append(data)

    def read_table(self, code):
        """Merges the JSON object of a `bpTexPreludeTable = Object.assign(...)` call."""
        for m in TABLE_RE.finditer(code):
            try:
                obj, _ = json.JSONDecoder().raw_decode(code[m.end():])
            except ValueError:
                continue
            if isinstance(obj, dict):
                self.table.update(obj)


def resolve_prelude(table, pid, attr):
    """The prelude KaTeX input gets, as the page's `resolvePrelude` computes it."""
    if pid and isinstance(table.get(pid), str):
        return table[pid].strip()
    return attr.strip() if isinstance(attr, str) else ""


def pages(site):
    """Yields every content `index.html` below the site directory, in sorted order."""
    for root, dirs, files in os.walk(site):
        dirs[:] = sorted(d for d in dirs if not d.startswith("-verso")
                         and not (root == site and d in ("search", "find")))
        if "index.html" in files:
            yield os.path.join(root, "index.html")


def upstream(site):
    """Describes the upstream project from the git remote of the enclosing checkout."""
    d = os.path.abspath(site)
    while d != os.path.dirname(d) and not os.path.exists(os.path.join(d, ".git")):
        d = os.path.dirname(d)
    try:
        run = lambda *a: subprocess.run(["git", "-C", d, *a], capture_output=True,
                                        text=True, check=True).stdout.strip()
        return run("remote", "get-url", "origin"), run("rev-parse", "HEAD")
    except Exception:
        return None, None


def main():
    """Reads the site, deduplicates the cases and writes the corpus."""
    site, name, out = sys.argv[1:4]
    cases, order, raw = {}, [], 0
    for page in pages(site):
        rel = os.path.relpath(page, site)
        p = MathParser()
        with open(page, encoding="utf-8") as f:
            p.feed(f.read())
        p.close()
        for kind, display, pid, attr, text in p.found:
            raw += 1
            prelude = resolve_prelude(p.table, pid, attr) if kind == "bp" else ""
            tex = prelude + "\n" + text if prelude else text
            key = (tex, display)
            if key not in cases:
                idx = sum(1 for k in order if k[2] == os.path.dirname(rel)) + 1
                cases[key] = {"id": f"{name}/{os.path.dirname(rel) or 'index'}/{idx}",
                              "tex": tex, "display": display, "count": 0}
                order.append((tex, display, os.path.dirname(rel)))
            cases[key]["count"] += 1
    url, rev = upstream(site)
    lic = sys.argv[4] if len(sys.argv) > 4 else "see the upstream repository"
    src = (f"Verso blueprint site built from {url} at commit {rev}" if url
           else "Verso blueprint site")
    meta = {"corpus": name, "source": src, "license": lic,
            "generator": "tools/extract-blueprint.py", "count": len(cases)}
    with open(out, "w", encoding="utf-8") as f:
        f.write(json.dumps({"meta": meta}, ensure_ascii=False, sort_keys=True) + "\n")
        for c in cases.values():
            f.write(json.dumps(c, ensure_ascii=False, sort_keys=True) + "\n")
    print(f"{raw} elements, {len(cases)} distinct cases")


main()
