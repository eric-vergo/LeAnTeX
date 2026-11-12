// Released under Apache 2.0 license as described in the file LICENSE.
// Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
//
// Generates LeAnTeX's tables from KaTeX's own sources: it imports KaTeX's TypeScript modules
// (through ts-hook.mjs), reads the registries they fill (functions, environments, macros,
// symbols, the Unicode tables) and writes them as Lean source under LeAnTeX/Data/, plus the
// list of every KaTeX name with its kind (parity/names.tsv) that the parity report is built on.
//
// Usage (from the repository root, KATEX = a checkout of KaTeX's source at the pinned tag):
//   node --experimental-strip-types --no-warnings --import ./tools/ts-register.mjs \
//        tools/gen-tables.mjs KATEX
// Re-run after upgrading KaTeX; `git diff` of the output then shows what changed.

import {writeFileSync, mkdirSync, readFileSync} from "node:fs";
import {join, resolve} from "node:path";
import {pathToFileURL} from "node:url";

const katexDir = resolve(process.argv[2] ?? "");
const outDir = resolve(process.argv[3] ?? ".");
const src = (p) => pathToFileURL(join(katexDir, "src", p)).href;

const pkg = JSON.parse(readFileSync(join(katexDir, "package.json"), "utf8"));
const KATEX_VERSION = pkg.version;

const {_functions} = await import(src("defineFunction.ts"));
await import(src("functions.ts"));
const environments = (await import(src("environments.ts"))).default;
const macros = (await import(src("macros.ts"))).default;
const symbolsModule = await import(src("symbols.ts"));
const symbols = symbolsModule.default;
const {uSubsAndSups, unicodeSubRegEx} = await import(src("unicodeSupOrSub.ts"));
const unicodeAccents = (await import(src("unicodeAccents.js"))).default;
const unicodeSymbols = (await import(src("unicodeSymbols.js"))).default;
const {supportedCodepoint} = await import(src("unicodeScripts.ts"));

const HEADER = "/-\nReleased under Apache 2.0 license as described in the file LICENSE.\n" +
    "Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)\n-/\n";

// A Lean string literal for `s`: backslash, quote and the characters a reader could not see
// (controls, combining marks, format characters, private use) are escaped.
function lit(s) {
    let out = "\"";
    for (const ch of s) {
        const cp = ch.codePointAt(0);
        if (ch === "\\") out += "\\\\";
        else if (ch === "\"") out += "\\\"";
        else if (ch === "\n") out += "\\n";
        else if (ch === "\t") out += "\\t";
        else if (ch === "\r") out += "\\r";
        else if (cp < 0x20 || (cp >= 0x7f && cp < 0xa0) || (cp >= 0x300 && cp < 0x370) ||
                 (cp >= 0x2000 && cp < 0x2010) || (cp >= 0x2028 && cp < 0x2030) ||
                 (cp >= 0x205f && cp < 0x2070) || cp === 0xfeff || cp === 0xa0 ||
                 (cp >= 0xe000 && cp < 0xf900) || (cp >= 0xfe00 && cp < 0xfe10)) {
            out += "\\u" + cp.toString(16).padStart(4, "0");
        } else out += ch;
    }
    return out + "\"";
}

// The number of code points in `s` (Lean's column count).
function cols(s) {
    return [...s].length;
}

// Splits one too-long line that ends in a string literal into several with Lean string gaps
// (`\` at a line end continues the literal; the next line's leading spaces are dropped, so a
// break never comes right before a space or inside an escape).
function wrap(line, indent) {
    // 99: a list separator `,` may follow the line.
    if (cols(line) <= 99) return line;
    const chars = [...line];
    const pieces = [];
    let start = 0;
    while (true) {
        const width = (pieces.length === 0 ? 0 : indent.length) + chars.length - start;
        if (width <= 99) break;
        // Leave one column for the gap's backslash.
        let cut = start + 99 - (pieces.length === 0 ? 0 : indent.length);
        while (cut > start + 1 &&
               (!inLiteral(chars, cut) || chars[cut] === " " || endsInEscape(chars, cut))) {
            cut--;
        }
        if (cut <= start + 1) throw new Error("cannot wrap: " + line);
        pieces.push((pieces.length === 0 ? "" : indent) + chars.slice(start, cut).join("") + "\\");
        start = cut;
    }
    pieces.push(indent + chars.slice(start).join(""));
    return pieces.join("\n");
}

// Whether position `cut` of `chars` lies inside a string literal (after an unescaped quote that
// is not yet closed).
function inLiteral(chars, cut) {
    let inside = false;
    for (let i = 0; i < cut; i++) {
        if (chars[i] === "\\" && inside) {
            i++;
        } else if (chars[i] === "\"") {
            inside = !inside;
        }
    }
    return inside;
}

// Whether a cut before position `cut` would split a backslash escape (`\\`, `\"`, `\u{…}`).
function endsInEscape(chars, cut) {
    let i = cut - 1;
    let n = 0;
    while (i >= 0 && chars[i] === "\\") {
        n++;
        i--;
    }
    if (n % 2 === 1) return true;
    return /\\u[0-9a-f]{0,3}$/.test(chars.slice(Math.max(0, cut - 6), cut).join(""));
}

// `text` broken into lines of at most 100 columns at spaces.
function paragraph(text) {
    const lines = [];
    let cur = "";
    for (const word of text.split(" ")) {
        if (cur && cols(cur + " " + word) > 100) {
            lines.push(cur);
            cur = word;
        } else cur = cur ? cur + " " + word : word;
    }
    lines.push(cur);
    return lines.join("\n");
}

// Writes a generated Lean module with the header, the imports, a module docstring and the body.
function writeLean(rel, title, summary, body, imports = "") {
    const text = HEADER + imports + "\n/-!\n# " + title + "\n\n" + paragraph(summary + " Generated by " +
        "`tools/gen-tables.mjs` from KaTeX " + KATEX_VERSION + "; do not edit by hand.") +
        "\n\n## References\n\n" +
        "* KaTeX (MIT licence, see `LICENSE-KaTeX`): <https://github.com/KaTeX/KaTeX>.\n-/\n\n" +
        body;
    const path = join(outDir, rel);
    mkdirSync(join(path, ".."), {recursive: true});
    writeFileSync(path, text.replace(/\n+$/, "\n"));
}

const ARG_TYPES = new Set(["color", "size", "url", "raw", "original", "hbox", "primitive",
    "math", "text"]);

// The Lean spelling of an argument type.
function argType(t) {
    if (!ARG_TYPES.has(t)) throw new Error("unknown arg type " + t);
    return "." + t;
}

// --- functions -----------------------------------------------------------------------------

// Every defineFunction call stores one spec object under each of its names; the first name of
// that object is the key that the Lean side dispatches handlers on.
const keyOf = new Map();
for (const [name, spec] of Object.entries(_functions)) {
    if (!keyOf.has(spec)) keyOf.set(spec, name);
}

// One `FunctionSpec` literal line for function `name`.
function functionLine(name, spec) {
    const fields = [`type := ${lit(spec.type)}`, `numArgs := ${spec.numArgs}`];
    if (spec.numOptionalArgs) fields.push(`numOptionalArgs := ${spec.numOptionalArgs}`);
    if (spec.argTypes) fields.push(`argTypes := #[${spec.argTypes.map(argType).join(", ")}]`);
    if (spec.allowedInArgument) fields.push("allowedInArgument := true");
    if (spec.allowedInText) fields.push("allowedInText := true");
    if (spec.allowedInMath === false) fields.push("allowedInMath := false");
    if (spec.infix) fields.push("isInfix := true");
    if (spec.primitive) fields.push("isPrimitive := true");
    if (!spec.handler) fields.push("hasHandler := false");
    fields.push(`handler := ${lit(keyOf.get(spec))}`);
    return `  (${lit(name)}, { ${fields.join(", ")} })`;
}

{
    const names = Object.keys(_functions);
    const lines = names.map((n) => functionLine(n, _functions[n]));
    const body = "namespace LeAnTeX.Data\n\n" +
        "/-- KaTeX's functions (`defineFunction`), by name, with the properties that drive " +
        "parsing. -/\n" +
        "def functionList : Array (String × FunctionSpec) := #[\n" +
        lines.map((l) => breakSpec(l)).join(",\n") + "\n]\n\nend LeAnTeX.Data\n";
    writeLean("LeAnTeX/Data/Functions.lean", "KaTeX's function table",
        "Every function KaTeX " + KATEX_VERSION + " defines (" + names.length + " names), " +
        "with its argument count, argument types, the modes it is allowed in and the key of " +
        "its handler (the first name of the `defineFunction` call that defines it).",
        body, "import LeAnTeX.Spec\n");
}

// Breaks a long `(name, { … })` line after a comma between fields.
function breakSpec(line) {
    if (cols(line) <= 99) return line;
    const parts = line.split(", ");
    const out = [];
    let cur = "";
    // Continuation fields line up with the first field: Lean wants them at least that far in.
    const fieldCol = " ".repeat(cols(line.slice(0, line.indexOf("{ ") + 2)));
    for (const p of parts) {
        const next = cur ? cur + ", " + p : p;
        // 98: the list separator `,` follows the last piece.
        if (cols(next) > 98 && cur) {
            out.push(cur + ",");
            cur = fieldCol + p;
        } else cur = next;
    }
    out.push(cur);
    return out.join("\n");
}

// --- environments --------------------------------------------------------------------------

{
    const envKey = new Map();
    for (const [name, spec] of Object.entries(environments)) {
        if (!envKey.has(spec)) envKey.set(spec, name);
    }
    const lines = Object.entries(environments).map(([name, spec]) => {
        const fields = [`type := ${lit(spec.type)}`, `numArgs := ${spec.numArgs}`];
        if (spec.numOptionalArgs) fields.push(`numOptionalArgs := ${spec.numOptionalArgs}`);
        if (spec.argTypes) fields.push(`argTypes := #[${spec.argTypes.map(argType).join(", ")}]`);
        if (spec.allowedInText) fields.push("allowedInText := true");
        fields.push(`handler := ${lit(envKey.get(spec))}`);
        return breakSpec(`  (${lit(name)}, { ${fields.join(", ")} })`);
    });
    writeLean("LeAnTeX/Data/Environments.lean", "KaTeX's environment table",
        "Every environment KaTeX " + KATEX_VERSION + " defines (`defineEnvironment`), with its " +
        "argument count and the key of its handler (the first name of its definition).",
        "namespace LeAnTeX.Data\n\n" +
        "/-- KaTeX's environments, by name. -/\n" +
        "def environmentList : Array (String × EnvSpec) := #[\n" + lines.join(",\n") +
        "\n]\n\nend LeAnTeX.Data\n", "import LeAnTeX.Spec\n");
}

// --- macros --------------------------------------------------------------------------------

const stringMacros = [];
const nativeMacros = [];
for (const [name, def] of Object.entries(macros)) {
    if (typeof def === "string") stringMacros.push([name, def]);
    else if (typeof def === "function") nativeMacros.push(name);
    else throw new Error("macro of unexpected kind: " + name);
}
{
    const lines = stringMacros.map(([n, d]) => wrap(`  (${lit(n)}, ${lit(d)})`, "    "));
    writeLean("LeAnTeX/Data/Macros.lean", "KaTeX's built-in macros",
        "The built-in macros of KaTeX " + KATEX_VERSION + " (`defineMacro`): the " +
        stringMacros.length + " whose definition is a string, verbatim, and the names of the " +
        nativeMacros.length + " that KaTeX defines as functions (implemented by hand in " +
        "`LeAnTeX.Parse.NativeMacros`).",
        "namespace LeAnTeX.Data\n\n" +
        "/-- KaTeX's built-in macros whose definition is a string: name and body. -/\n" +
        "def stringMacroList : Array (String × String) := #[\n" + lines.join(",\n") + "\n]\n\n" +
        "/-- KaTeX's built-in macros that are defined by a function. -/\n" +
        "def nativeMacroNames : Array String := #[\n" +
        nativeMacros.map((n) => "  " + lit(n)).join(",\n") + "\n]\n\nend LeAnTeX.Data\n");
}

// --- symbols -------------------------------------------------------------------------------

const GROUPS = {
    "bin": "bin", "close": "close", "inner": "inner", "open": "«open»", "punct": "punct",
    "rel": "rel", "accent-token": "accentToken", "mathord": "mathord", "op-token": "opToken",
    "spacing": "spacing", "textord": "textord",
};

// One `(name, info)` line for a symbol table.
function symbolLine(name, info) {
    if (!(info.group in GROUPS)) throw new Error("unknown group " + info.group);
    if (info.font !== "main" && info.font !== "ams") throw new Error("font " + info.font);
    const rep = info.replace == null ? "none" : `some ${lit(info.replace)}`;
    return wrap(`  (${lit(name)}, ⟨.${info.font}, .${GROUPS[info.group]}, ${rep}⟩)`, "    ");
}

{
    const math = Object.entries(symbols.math).map(([n, i]) => symbolLine(n, i));
    const text = Object.entries(symbols.text).map(([n, i]) => symbolLine(n, i));
    writeLean("LeAnTeX/Data/Symbols.lean", "KaTeX's symbol table",
        "Every symbol of KaTeX " + KATEX_VERSION + " (`defineSymbol` in `symbols.ts`), in math " +
        "mode (" + math.length + ") and text mode (" + text.length + "): its font, its group " +
        "(atom class or ordinary kind) and the character it is drawn with.",
        "namespace LeAnTeX.Data\n\n" +
        "/-- KaTeX's math-mode symbols, by name. -/\n" +
        "def mathSymbolList : Array (String × SymbolInfo) := #[\n" + math.join(",\n") +
        "\n]\n\n" +
        "/-- KaTeX's text-mode symbols, by name. -/\n" +
        "def textSymbolList : Array (String × SymbolInfo) := #[\n" + text.join(",\n") +
        "\n]\n\n" +
        "/-- The Latin-1 letters that KaTeX accepts in math mode with a strict-mode warning. -/\n" +
        `def extraLatin : String := ${lit(symbolsModule.extraLatin)}\n\nend LeAnTeX.Data\n`,
        "import LeAnTeX.Spec\n");
}

// --- Unicode -------------------------------------------------------------------------------

{
    const usym = Object.entries(unicodeSymbols)
        .map(([c, d]) => wrap(`  (${lit(c)}, ${lit(d)})`, "    "));
    const uacc = Object.entries(unicodeAccents).map(([c, d]) =>
        `  (${lit(c)}, ${lit(d.text)}, ${d.math == null ? "none" : "some " + lit(d.math)})`);
    const subsup = Object.entries(uSubsAndSups).map(([c, d]) =>
        `  (${lit(c)}, ${lit(d)}, ${unicodeSubRegEx.test(c)})`);
    // The supported-script blocks, recovered by scanning the BMP with KaTeX's own predicate.
    const blocks = [];
    let open = -1;
    for (let cp = 0; cp <= 0x10000; cp++) {
        const ok = cp < 0x10000 && supportedCodepoint(cp);
        if (ok && open < 0) open = cp;
        if (!ok && open >= 0) {
            blocks.push([open, cp - 1]);
            open = -1;
        }
    }
    const hex = (n) => "0x" + n.toString(16).toUpperCase();
    writeLean("LeAnTeX/Data/Unicode.lean", "KaTeX's Unicode tables",
        "The Unicode data KaTeX " + KATEX_VERSION + "'s parser consults: precomposed accented " +
        "letters and their decomposition (`unicodeSymbols.js`), combining accents and the " +
        "commands they stand for (`unicodeAccents.js`), Unicode sub- and superscript " +
        "characters (`unicodeSupOrSub.ts`) and the script blocks it supports in text " +
        "(`unicodeScripts.ts`).",
        "namespace LeAnTeX.Data\n\n" +
        "/-- Precomposed letters and their base letter followed by combining accents. -/\n" +
        "def unicodeSymbolList : Array (String × String) := #[\n" + usym.join(",\n") +
        "\n]\n\n" +
        "/-- Combining accents: the text-mode command and, where there is one, the math-mode " +
        "command. -/\n" +
        "def unicodeAccentList : Array (String × String × Option String) := #[\n" +
        uacc.join(",\n") + "\n]\n\n" +
        "/-- Unicode sub- and superscript characters: the character they stand for, and " +
        "whether\nit is a subscript. -/\n" +
        "def subSupList : Array (String × String × Bool) := #[\n" + subsup.join(",\n") +
        "\n]\n\n" +
        "/-- The code point blocks (inclusive) of the scripts KaTeX supports in text. -/\n" +
        "def supportedBlocks : Array (Nat × Nat) := #[\n" +
        blocks.map(([a, b]) => `  (${hex(a)}, ${hex(b)})`).join(",\n") +
        "\n]\n\nend LeAnTeX.Data\n");
}

// --- the parity name list ------------------------------------------------------------------

{
    const rows = [["kind", "name", "detail"]];
    for (const [name, spec] of Object.entries(_functions)) rows.push(["function", name, spec.type]);
    for (const [name, spec] of Object.entries(environments)) {
        rows.push(["environment", name, spec.type]);
    }
    for (const [name] of stringMacros) rows.push(["macro", name, "string"]);
    for (const name of nativeMacros) rows.push(["macro", name, "native"]);
    for (const [name, info] of Object.entries(symbols.math)) rows.push(["symbol-math", name, info.group]);
    for (const [name, info] of Object.entries(symbols.text)) rows.push(["symbol-text", name, info.group]);
    const esc = (s) => s.replace(/\\/g, "\\\\").replace(/\t/g, "\\t").replace(/\n/g, "\\n");
    mkdirSync(join(outDir, "parity"), {recursive: true});
    writeFileSync(join(outDir, "parity", "names.tsv"),
        "# Every name KaTeX " + KATEX_VERSION + " defines, generated by tools/gen-tables.mjs. " +
        "Backslashes, tabs and newlines in names are escaped as \\\\, \\t, \\n.\n" +
        rows.map((r) => r.map(esc).join("\t")).join("\n") + "\n");
}

console.log(`KaTeX ${KATEX_VERSION}: ${Object.keys(_functions).length} functions, ` +
    `${Object.keys(environments).length} environments, ${stringMacros.length} string macros, ` +
    `${nativeMacros.length} native macros, ${Object.keys(symbols.math).length} math symbols, ` +
    `${Object.keys(symbols.text).length} text symbols`);
