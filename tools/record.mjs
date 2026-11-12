// Released under Apache 2.0 license as described in the file LICENSE.
// Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
//
// Records KaTeX's answers for every corpus case into fixtures/<corpus>.jsonl, so that LeAnTeX's
// test suite compares against them without running KaTeX. For each case it calls KaTeX's
// `__parse` (the parse tree), catching the error if KaTeX rejects the formula, and the
// strict-mode warnings KaTeX prints. With `--layout` it records KaTeX's HTML box tree instead
// (`__renderToHTMLTree`) into fixtures/layout/<corpus>.jsonl: every span, symbol and SVG node
// with its classes, height, depth, maxFontSize, italic, skew, width, CSS style and attributes,
// numbers rounded to 1e-6 em, so the layout tests compare LeAnTeX's boxes without a browser.
// Usage, from the repository root, with the built KaTeX of the pinned version:
//   node tools/record.mjs [--layout] path/to/katex.min.js [corpus-name …]
// Without corpus names it records every corpus/*.jsonl.

import {createRequire} from "node:module";
import {readFileSync, readdirSync, writeFileSync, mkdirSync} from "node:fs";
import {resolve, join, basename} from "node:path";

const require = createRequire(import.meta.url);
const argv = process.argv.slice(2);
const layout = argv[0] === "--layout";
if (layout) argv.shift();
const katexPath = resolve(argv[0] ?? "");
const katex = require(katexPath);
const wanted = argv.slice(1);
const root = resolve(".");

// The KaTeX settings of a corpus case: KaTeX's defaults, the case's display flag, macros
// (copied, since KaTeX writes global definitions into the object) and other settings.
function settingsOf(c) {
    const s = {displayMode: Boolean(c.display), throwOnError: true, strict: "warn",
        trust: false, ...(c.settings ?? {})};
    s.macros = {...(c.macros ?? {})};
    return s;
}

// A parse tree as plain JSON: every `loc` becomes `[start, end]` (or null), tokens keep only
// their text and location, lone surrogates become U+FFFD, undefined fields are dropped.
function normalize(value) {
    return JSON.parse(JSON.stringify(value, (key, v) => {
        if (key === "loc") return v ? [v.start, v.end] : v;
        if (v && typeof v === "object" && v.constructor && v.constructor.name === "Token") {
            return {text: v.text, loc: v.loc ? [v.loc.start, v.loc.end] : v.loc};
        }
        if (typeof v === "string") return v.toWellFormed();
        return v;
    }));
}

// KaTeX's answer for one case: the tree or the error, and the warnings.
function answer(c) {
    const warnings = [];
    const origWarn = console.warn;
    console.warn = (...args) => warnings.push(args.map(String).join(" ").toWellFormed());
    let out;
    try {
        out = {tree: normalize(katex.__parse(c.tex, settingsOf(c)))};
    } catch (e) {
        if (e instanceof katex.ParseError) {
            out = {error: {kind: "ParseError", rawMessage: e.rawMessage.toWellFormed(),
                position: e.position ?? null, length: e.length ?? null,
                message: e.message.toWellFormed()}};
        } else {
            out = {error: {kind: e?.name ?? "Error", message: String(e?.message ?? e)}};
        }
    } finally {
        console.warn = origWarn;
    }
    out.warnings = warnings;
    return out;
}

// A number rounded to 1e-6 (KaTeX's own CSS keeps 1e-4), without a negative zero.
function num(x) {
    const r = Math.round(x * 1e6) / 1e6;
    return r === 0 ? 0 : r;
}

// Sets `out[key]` to the rounded number unless it is zero (an absent number reads as zero).
function put(out, key, x) {
    const r = num(x);
    if (r !== 0) out[key] = r;
}

// The fields every HTML node has, in the compact form: classes without the empty ones (KaTeX
// drops them in its markup), height, depth, maxFontSize, the style object in key order and the
// attributes; empty lists and zero numbers are left out.
function common(n, out) {
    const cls = n.classes.filter((c) => c);
    if (cls.length) out.c = cls;
    put(out, "h", n.height);
    put(out, "d", n.depth);
    put(out, "m", n.maxFontSize);
    const st = Object.entries(n.style).filter(([, v]) => v !== undefined);
    if (st.length) out.st = st;
    const at = Object.entries(n.attributes ?? {});
    if (at.length) out.at = at;
    return out;
}

// KaTeX's HTML box tree as plain JSON. Kinds: `span`, `a` (anchor), `sym` (symbol node), `frag`
// (document fragment), `svg` with `path` and `line` children, `img`.
function boxJson(n) {
    const T = katex.__domTree;
    if (n instanceof T.SymbolNode) {
        const out = {k: "sym", t: n.text.toWellFormed()};
        common(n, out);
        put(out, "i", n.italic);
        put(out, "sk", n.skew);
        put(out, "w", n.width);
        return out;
    }
    if (n instanceof T.SvgNode) {
        return {k: "svg", at: Object.entries(n.attributes), ch: n.children.map(boxJson)};
    }
    if (n instanceof T.PathNode) {
        const out = {k: "path", name: n.pathName};
        if (n.alternate) out.alt = n.alternate;
        return out;
    }
    if (n instanceof T.LineNode) return {k: "line", at: Object.entries(n.attributes)};
    if (n instanceof T.Span || n instanceof T.Anchor) {
        const out = common(n, {k: n instanceof T.Anchor ? "a" : "span"});
        // `width` and `italic` are set on some spans only; a set zero is kept
        if (n.width != null) out.w = num(n.width);
        if (n.italic != null) out.i = num(n.italic);
        if (n.children.length) out.ch = n.children.map(boxJson);
        return out;
    }
    if (n.src !== undefined && n.alt !== undefined) {
        const out = common(n, {k: "img", src: n.src, alt: n.alt});
        return out;
    }
    // a document fragment: children and sizes, no classes of its own
    const out = {k: "frag"};
    put(out, "h", n.height);
    put(out, "d", n.depth);
    put(out, "m", n.maxFontSize);
    out.ch = n.children.map(boxJson);
    return out;
}

// KaTeX's box tree for one case, or its error, and the warnings of parsing and building.
function layoutAnswer(c) {
    const warnings = [];
    const origWarn = console.warn;
    const origLog = console.log;
    console.warn = (...args) => warnings.push(args.map(String).join(" ").toWellFormed());
    // `\show` and friends print to the console; their output is not part of the layout
    console.log = () => {};
    let out;
    try {
        const s = settingsOf(c);
        s.throwOnError = true;
        out = {box: boxJson(katex.__renderToHTMLTree(c.tex, s))};
    } catch (e) {
        out = {error: {kind: e instanceof katex.ParseError ? "ParseError" : (e?.name ?? "Error"),
            message: String(e?.message ?? e).toWellFormed()}};
    } finally {
        console.warn = origWarn;
        console.log = origLog;
    }
    out.warnings = warnings;
    return out;
}

const corpusDir = join(root, "corpus");
const names = wanted.length ? wanted :
    readdirSync(corpusDir).filter((f) => f.endsWith(".jsonl")).map((f) => basename(f, ".jsonl"));
const outDir = layout ? join(root, "fixtures", "layout") : join(root, "fixtures");
mkdirSync(outDir, {recursive: true});
for (const name of names) {
    const lines = readFileSync(join(corpusDir, name + ".jsonl"), "utf8").split("\n")
        .filter((l) => l.trim() !== "");
    const out = [JSON.stringify({meta: {corpus: name, katex: katex.version,
        recorder: layout ? "tools/record.mjs --layout" : "tools/record.mjs"}})];
    let accepted = 0;
    let rejected = 0;
    for (const line of lines.slice(1)) {
        const c = JSON.parse(line);
        if (!c.tex.isWellFormed()) {
            // A lone surrogate cannot occur in a Lean string, so the case cannot be replayed.
            out.push(JSON.stringify({id: c.id, unrepresentable: true}));
            continue;
        }
        const a = layout ? layoutAnswer(c) : answer(c);
        if (a.tree || a.box) accepted++; else rejected++;
        out.push(JSON.stringify({id: c.id, ...a}));
    }
    writeFileSync(join(outDir, name + ".jsonl"), out.join("\n") + "\n");
    console.log(`${name}: ${accepted} accepted, ${rejected} rejected by KaTeX ${katex.version}`);
}
