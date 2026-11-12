// Released under Apache 2.0 license as described in the file LICENSE.
// Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
//
// Builds the three corpora taken from KaTeX's own repository:
//   corpus/katex-spec.jsonl         every formula KaTeX's parser and error tests hand to a
//                                   parse/build matcher (katex-spec.ts, errors-spec.ts,
//                                   unicode-spec.ts), with the settings the test passes;
//   corpus/katex-screenshots.jsonl  the screenshot test cases (test/screenshotter/ss_data.yaml);
//   corpus/katex-support-table.jsonl the "Rendered" example of every row of
//                                   docs/support_table.md.
// The spec files are run under a minimal stand-in for Jest that records the inputs of the
// matchers instead of checking them. Usage, from the repository root (KATEX = a checkout of
// KaTeX's source at the pinned tag):
//   node --experimental-strip-types --no-warnings --import ./tools/ts-register.mjs \
//        tools/harvest-katex.mjs KATEX

import {readFileSync, writeFileSync} from "node:fs";
import {join, resolve} from "node:path";
import {pathToFileURL} from "node:url";

const katexDir = resolve(process.argv[2] ?? "");
const outDir = resolve(process.argv[3] ?? ".");
const version = JSON.parse(readFileSync(join(katexDir, "package.json"), "utf8")).version;
const LICENSE = "MIT (KaTeX, see LICENSE-KaTeX)";
const SOURCE = `KaTeX ${version}, https://github.com/KaTeX/KaTeX (tag v${version})`;

// --- recording stand-in for Jest -----------------------------------------------------------

const cases = [];
const titles = [];
// The matchers whose argument is a formula, and where their settings argument sits.
const MATCHERS = {
    toParse: {settings: 0}, toBuild: {settings: 0}, toWarn: {settings: 0},
    toFailWithParseError: {settings: 1}, toParseLike: {settings: 1, other: 0},
    toBuildLike: {settings: 1, other: 0},
};

// The formula text of a matcher argument: a tagged template's raw string, or a string.
function texOf(x) {
    if (x && typeof x === "object" && "raw" in x) return x.raw[0];
    if (typeof x === "string") return x;
    if (x instanceof String) return String(x);
    return null;
}

// The settings that differ from KaTeX's defaults, as plain data, or null when a setting is a
// function (the case cannot be replayed from data).
function settingsOf(s) {
    const out = {};
    if (!s) return out;
    const defaults = {displayMode: false, throwOnError: true, strict: "warn", trust: false,
        colorIsTextColor: false, globalGroup: false, maxExpand: 1000, leqno: false,
        fleqn: false, errorColor: "#cc0000"};
    for (const [k, d] of Object.entries(defaults)) {
        if (!(k in s) || s[k] === undefined) continue;
        const v = s[k];
        if (typeof v === "function") return null;
        if (v !== d) out[k] = v;
    }
    if (s.macros && Object.keys(s.macros).length > 0) {
        const m = {};
        for (const [k, v] of Object.entries(s.macros)) {
            if (typeof v !== "string") return null;
            m[k] = v;
        }
        out.macros = m;
    }
    return out;
}

// Records one formula with its settings under the current test title.
function record(tex, settings) {
    if (tex == null) return;
    const s = settingsOf(settings);
    if (s == null) return;
    cases.push({title: titles.join(" > "), tex, settings: s});
}

// `expect(x)`: an object whose formula matchers record `x` (and a second formula for the
// `…Like` matchers) and whose other matchers do nothing.
function expect(x) {
    const handler = {
        get(_t, prop) {
            if (prop === "not" || prop === "resolves" || prop === "rejects") {
                return new Proxy({}, handler);
            }
            return (...args) => {
                const m = MATCHERS[prop];
                if (!m) return undefined;
                const tex = texOf(x);
                record(tex, args[m.settings]);
                if (m.other !== undefined) record(texOf(args[m.other]), args[m.settings]);
                return undefined;
            };
        },
    };
    return new Proxy({}, handler);
}
expect.extend = () => {};
expect.any = () => ({});
expect.anything = () => ({});
expect.stringContaining = () => ({});
expect.objectContaining = () => ({});

const pending = [];
// `describe(name, fn)`: runs `fn` with `name` on the title stack.
function describe(name, fn) {
    titles.push(String(name));
    try {
        fn();
    } catch (e) {
        void e;
    }
    titles.pop();
}
// `it(name, fn)`: runs the test body, ignoring its failures (only the recorded inputs count).
function it(name, fn) {
    titles.push(String(name));
    try {
        const r = fn?.(() => {});
        if (r && typeof r.then === "function") pending.push(r.catch(() => {}));
    } catch (e) {
        void e;
    }
    titles.pop();
}
const noop = () => {};
const mockFn = () => {
    const f = () => undefined;
    f.mockImplementation = () => f;
    f.mockRestore = noop;
    f.mockReturnValue = () => f;
    return f;
};
Object.assign(globalThis, {
    // the build-time constant KaTeX's entry module reads
    __VERSION__: version,
    expect, describe, it, test: it, beforeEach: noop, afterEach: noop, beforeAll: noop,
    afterAll: noop,
    jest: {fn: mockFn, spyOn: (obj, key) => {
        const f = mockFn();
        void obj;
        void key;
        return f;
    }},
});
describe.each = () => () => {};
it.each = () => () => {};
it.skip = noop;
describe.skip = noop;

const origWarn = console.warn;
console.warn = () => {};
for (const f of ["katex-spec.ts", "errors-spec.ts", "unicode-spec.ts"]) {
    titles.push(f.replace(/-spec\.ts$/, ""));
    await import(pathToFileURL(join(katexDir, "test", f)).href);
    titles.pop();
}
await Promise.all(pending);
console.warn = origWarn;

// Writes a corpus file: the metadata line, then the distinct cases with their counts.
function writeCorpus(name, list, generatorNote) {
    const seen = new Map();
    for (const c of list) {
        const display = Boolean(c.settings?.displayMode);
        const settings = {...(c.settings ?? {})};
        delete settings.displayMode;
        const macros = settings.macros;
        delete settings.macros;
        const key = JSON.stringify([c.tex, display, macros ?? null, settings]);
        if (seen.has(key)) {
            seen.get(key).count++;
            continue;
        }
        const row = {id: c.id, tex: c.tex, display, count: 1};
        if (macros) row.macros = macros;
        if (Object.keys(settings).length > 0) row.settings = settings;
        seen.set(key, row);
    }
    const rows = [...seen.values()];
    const sortKeys = (o) => Object.fromEntries(Object.entries(o).sort(([a], [b]) =>
        a < b ? -1 : 1));
    const meta = {meta: {corpus: name, source: SOURCE + generatorNote, license: LICENSE,
        generator: "tools/harvest-katex.mjs", count: rows.length}};
    writeFileSync(join(outDir, "corpus", name + ".jsonl"),
        [meta, ...rows].map((r) => JSON.stringify(sortKeys(r))).join("\n") + "\n");
    return rows.length;
}

// --- the spec corpus -------------------------------------------------------------------------

const perTitle = new Map();
for (const c of cases) {
    const n = (perTitle.get(c.title) ?? 0) + 1;
    perTitle.set(c.title, n);
    c.id = `katex-spec/${c.title}/${n}`;
}
const nSpec = writeCorpus("katex-spec", cases, ", test/*-spec.ts");

// --- the screenshot corpus ---------------------------------------------------------------------

// A reader for the subset of YAML that ss_data.yaml uses: top-level keys whose value is a
// plain scalar, a `|` block, or a mapping of such values (and `macros:` one level deeper).
function readSsData(text) {
    const lines = text.split("\n");
    const out = {};
    let i = 0;
    // The value starting after `key:` on line i at the given indent.
    function scalarOrBlock(rest, indent) {
        rest = rest.trim();
        if (rest === "|" || rest === "|-" || rest === ">") {
            const block = [];
            i++;
            let blockIndent = null;
            while (i < lines.length) {
                const l = lines[i];
                if (l.trim() === "") {
                    block.push("");
                    i++;
                    continue;
                }
                const ind = l.length - l.trimStart().length;
                if (blockIndent == null) blockIndent = ind;
                if (ind < blockIndent || ind <= indent) break;
                block.push(l.slice(blockIndent));
                i++;
            }
            while (block.length && block[block.length - 1] === "") block.pop();
            return rest === "|-" ? block.join("\n") : block.join("\n") + "\n";
        }
        i++;
        if (rest.startsWith("'") && rest.endsWith("'")) return rest.slice(1, -1).replace(/''/g, "'");
        if (rest.startsWith("\"") && rest.endsWith("\"")) return JSON.parse(rest);
        return rest;
    }
    // A mapping whose keys are indented by more than `indent`.
    function mapping(indent) {
        const m = {};
        while (i < lines.length) {
            const l = lines[i];
            if (l.trim() === "" || l.trim().startsWith("#")) {
                i++;
                continue;
            }
            const ind = l.length - l.trimStart().length;
            if (ind <= indent) break;
            const mm = /^\s*([^:]+):(.*)$/.exec(l);
            if (!mm) {
                i++;
                continue;
            }
            if (mm[2].trim() === "") {
                i++;
                m[mm[1].trim()] = mapping(ind);
            } else m[mm[1].trim()] = scalarOrBlock(mm[2], ind);
        }
        return m;
    }
    while (i < lines.length) {
        const l = lines[i];
        if (l.trim() === "" || l.startsWith("#")) {
            i++;
            continue;
        }
        const mm = /^([A-Za-z0-9_]+):(.*)$/.exec(l);
        if (!mm) {
            i++;
            continue;
        }
        if (mm[2].trim() === "") {
            i++;
            out[mm[1]] = mapping(0);
        } else out[mm[1]] = scalarOrBlock(mm[2], 0);
    }
    return out;
}

const ss = readSsData(readFileSync(join(katexDir, "test/screenshotter/ss_data.yaml"), "utf8"));
const ssCases = [];
for (const [key, v] of Object.entries(ss)) {
    const item = typeof v === "string" ? {tex: v} : v;
    if (typeof item.tex !== "string") continue;
    const settings = {};
    if (item.display && item.display !== "0") settings.displayMode = true;
    if (item.noThrow && item.noThrow !== "0") settings.throwOnError = false;
    if (item.macros) settings.macros = item.macros;
    ssCases.push({id: `katex-screenshots/${key}`, tex: item.tex, settings});
}
const nSs = writeCorpus("katex-screenshots", ssCases, ", test/screenshotter/ss_data.yaml");

// --- the support-table corpus ------------------------------------------------------------------

const table = readFileSync(join(katexDir, "docs/support_table.md"), "utf8");
const stCases = [];
// The page defines \VERT globally before the tables; its formulas rely on it.
const docMacros = {"\\VERT": "|"};
for (const line of table.split("\n")) {
    if (!line.startsWith("|") || line.startsWith("|:-") || line.startsWith("|Symbol")) continue;
    // Cells are separated by `|` not escaped by a backslash.
    const cells = line.slice(1).split(/(?<!\\)\|/);
    if (cells.length < 2) continue;
    const name = cells[0].replace(/\\(.)/g, "$1");
    const rendered = cells[1];
    const re = /\$\$([^$]+)\$\$|\$([^$]+)\$/g;
    let m;
    let n = 0;
    while ((m = re.exec(rendered)) !== null) {
        n++;
        const tex = (m[1] ?? m[2]).replace(/\\\|/g, "|");
        stCases.push({id: `katex-support-table/${name}/${n}`, tex,
            settings: {displayMode: m[1] !== undefined, macros: docMacros}});
    }
}
const nSt = writeCorpus("katex-support-table", stCases, ", docs/support_table.md");

console.log(`katex-spec: ${cases.length} uses, ${nSpec} cases; katex-screenshots: ${nSs}; ` +
    `katex-support-table: ${nSt}`);
