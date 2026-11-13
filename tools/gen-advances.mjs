// Released under Apache 2.0 license as described in the file LICENSE.
// Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
//
// Generates LeAnTeX/Data/FontAdvances.lean: the advance width of every character of KaTeX's
// fonts that LeAnTeX can draw, as the fonts themselves give it. KaTeX's metric tables give the
// widths TeX's font metric files give, which differ from the fonts' advances by up to 5e-4 em
// (and for a few glyphs, such as the double and triple integrals, by much more); a browser
// places KaTeX's glyphs by the fonts' advances, so the display list does too.
//
// The advances are measured in headless Chromium with the canvas `measureText` of each face,
// at 1000 px (KaTeX's fonts have 1000 units to the em, so the result is exact), for the
// characters of each face's metric table; a character counts as the face's own when it measures
// the same with two different fallback fonts.
//
// Usage, from the repository root:
//   node tools/gen-advances.mjs KATEX_DIST
// KATEX_DIST is a directory with KaTeX's built katex.min.css and fonts/ (of the pinned version).
// Playwright is loaded from $PLAYWRIGHT_MODULE (a path to the `playwright` package) or else
// resolved as the package `playwright`; it needs its Chromium.

import {createRequire} from "node:module";
import {readFileSync, writeFileSync} from "node:fs";
import {join, resolve} from "node:path";

const katexDir = resolve(process.argv[2] ?? "");
const require = createRequire(import.meta.url);
const {chromium} = require(process.env.PLAYWRIGHT_MODULE ?? "playwright");

// KaTeX's twenty faces: file name, CSS family, weight, style.
const FACES = [
    ["AMS-Regular", "KaTeX_AMS", "normal", "normal"],
    ["Caligraphic-Bold", "KaTeX_Caligraphic", "bold", "normal"],
    ["Caligraphic-Regular", "KaTeX_Caligraphic", "normal", "normal"],
    ["Fraktur-Bold", "KaTeX_Fraktur", "bold", "normal"],
    ["Fraktur-Regular", "KaTeX_Fraktur", "normal", "normal"],
    ["Main-Bold", "KaTeX_Main", "bold", "normal"],
    ["Main-BoldItalic", "KaTeX_Main", "bold", "italic"],
    ["Main-Italic", "KaTeX_Main", "normal", "italic"],
    ["Main-Regular", "KaTeX_Main", "normal", "normal"],
    ["Math-BoldItalic", "KaTeX_Math", "bold", "italic"],
    ["Math-Italic", "KaTeX_Math", "normal", "italic"],
    ["SansSerif-Bold", "KaTeX_SansSerif", "bold", "normal"],
    ["SansSerif-Italic", "KaTeX_SansSerif", "normal", "italic"],
    ["SansSerif-Regular", "KaTeX_SansSerif", "normal", "normal"],
    ["Script-Regular", "KaTeX_Script", "normal", "normal"],
    ["Size1-Regular", "KaTeX_Size1", "normal", "normal"],
    ["Size2-Regular", "KaTeX_Size2", "normal", "normal"],
    ["Size3-Regular", "KaTeX_Size3", "normal", "normal"],
    ["Size4-Regular", "KaTeX_Size4", "normal", "normal"],
    ["Typewriter-Regular", "KaTeX_Typewriter", "normal", "normal"],
];

// The characters to measure in each face: those of its metric table (Caligraphic-Bold and
// Fraktur-Bold, which have none, take their regular face's); a character outside the table has
// no metrics in KaTeX, and the display list marks it as not exact.
const tables = {};
const text = readFileSync("LeAnTeX/Data/FontMetrics.lean", "utf8");
for (const m of text.matchAll(/The metrics of `([A-Za-z0-9-]+)`[^]*?:= #\[\n([^\]]*)\]/g)) {
    tables[m[1]] = [...m[2].matchAll(/^ {2}(\d+),/gm)].map((r) => Number(r[1]))
        .filter((cp) => cp < 0xd800 || cp > 0xdfff).map((cp) => String.fromCodePoint(cp));
}
tables["Caligraphic-Bold"] = tables["Caligraphic-Regular"];
tables["Fraktur-Bold"] = tables["Fraktur-Regular"];

const browser = await chromium.launch();
const page = await browser.newPage();
const ORIGIN = "http://katex.invalid/";
await page.route(ORIGIN + "**", (route) => {
    const rel = decodeURIComponent(new URL(route.request().url()).pathname.slice(1));
    if (rel === "index.html") {
        return route.fulfill({contentType: "text/html", body: "<!DOCTYPE html><html><head>" +
            "<link rel=\"stylesheet\" href=\"katex.min.css\"></head><body></body></html>"});
    }
    return route.fulfill({path: join(katexDir, rel)});
});
await page.goto(ORIGIN + "index.html");
const result = await page.evaluate(async ([faces, tables]) => {
    const out = {};
    const ctx = document.createElement("canvas").getContext("2d");
    for (const [name, family, weight, style] of faces) {
        const spec = `${style} ${weight} 1000px ${family}`;
        const list = tables[name];
        await document.fonts.load(spec, list.join(""));
        const rows = [];
        for (const ch of list) {
            ctx.font = `${style} ${weight} 1000px ${family}, serif`;
            const a = ctx.measureText(ch).width;
            ctx.font = `${style} ${weight} 1000px ${family}, monospace`;
            const b = ctx.measureText(ch).width;
            if (a === b) rows.push([ch.codePointAt(0), Math.round(a)]);
        }
        out[name] = rows;
    }
    return out;
}, [FACES, tables]);
await browser.close();

const HEADER = "/-\nReleased under Apache 2.0 license as described in the file LICENSE.\n" +
    "Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)\n-/\n";
let body = "namespace LeAnTeX.Data\n\n";
let total = 0;
FACES.forEach(([name], i) => {
    const rows = result[name];
    total += rows.length;
    body += `/-- The advances of \`${name}\`: code point and advance in 1/1000 em, in pairs. -/\n` +
        `def advances${i} : Array Nat := #[\n`;
    const pieces = rows.map(([cp, w]) => `${cp}, ${w}`);
    const lines = [];
    for (let k = 0; k < pieces.length; k += 6) lines.push("  " + pieces.slice(k, k + 6).join(", "));
    body += lines.join(",\n") + "\n]\n\n";
});
body += "/-- KaTeX's faces with their advance tables. -/\n" +
    "def fontAdvanceTables : Array (String × Array Nat) := #[\n" +
    FACES.map(([name], i) => `  ("${name}", advances${i})`).join(",\n") + "\n]\n\n" +
    "end LeAnTeX.Data\n";
writeFileSync("LeAnTeX/Data/FontAdvances.lean", HEADER + "\n/-!\n# The advances of KaTeX's fonts\n\n" +
    `The advance width of ${total} characters of KaTeX's twenty font faces, as the fonts give ` +
    "them\n(KaTeX's metric tables give TeX's widths, which differ slightly). Measured from " +
    "KaTeX's fonts by\n`tools/gen-advances.mjs`; do not edit by hand.\n\n## References\n\n" +
    "* KaTeX's fonts (MIT licence, see `LICENSE-KaTeX`): <https://github.com/KaTeX/KaTeX>.\n-/\n\n" +
    body);
console.log(`advances of ${total} characters in ${FACES.length} faces written`);
