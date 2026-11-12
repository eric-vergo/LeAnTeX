// Released under Apache 2.0 license as described in the file LICENSE.
// Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
//
// Records KaTeX's answers for every corpus case into fixtures/<corpus>.jsonl, so that LeAnTeX's
// test suite compares against them without running KaTeX. For each case it calls KaTeX's
// `__parse` (the parse tree), catching the error if KaTeX rejects the formula, and the
// strict-mode warnings KaTeX prints. Layout numbers are added here when the layout stages
// need them. Usage, from the repository root, with the built KaTeX of the pinned version:
//   node tools/record.mjs path/to/katex.min.js [corpus-name …]
// Without corpus names it records every corpus/*.jsonl.

import {createRequire} from "node:module";
import {readFileSync, readdirSync, writeFileSync, mkdirSync} from "node:fs";
import {resolve, join, basename} from "node:path";

const require = createRequire(import.meta.url);
const katexPath = resolve(process.argv[2] ?? "");
const katex = require(katexPath);
const wanted = process.argv.slice(3);
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

const corpusDir = join(root, "corpus");
const names = wanted.length ? wanted :
    readdirSync(corpusDir).filter((f) => f.endsWith(".jsonl")).map((f) => basename(f, ".jsonl"));
mkdirSync(join(root, "fixtures"), {recursive: true});
for (const name of names) {
    const lines = readFileSync(join(corpusDir, name + ".jsonl"), "utf8").split("\n")
        .filter((l) => l.trim() !== "");
    const out = [JSON.stringify({meta: {corpus: name, katex: katex.version,
        recorder: "tools/record.mjs"}})];
    let accepted = 0;
    let rejected = 0;
    for (const line of lines.slice(1)) {
        const c = JSON.parse(line);
        if (!c.tex.isWellFormed()) {
            // A lone surrogate cannot occur in a Lean string, so the case cannot be replayed.
            out.push(JSON.stringify({id: c.id, unrepresentable: true}));
            continue;
        }
        const a = answer(c);
        if (a.tree) accepted++; else rejected++;
        out.push(JSON.stringify({id: c.id, ...a}));
    }
    writeFileSync(join(root, "fixtures", name + ".jsonl"), out.join("\n") + "\n");
    console.log(`${name}: ${accepted} accepted, ${rejected} rejected by KaTeX ${katex.version}`);
}
