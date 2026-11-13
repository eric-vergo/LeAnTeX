// Released under Apache 2.0 license as described in the file LICENSE.
// Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
//
// Checks LeAnTeX's display lists against what a browser does with KaTeX's own rendering: each
// formula of a dump written by `lake exe leantex-display` is rendered with KaTeX (its CSS and
// fonts) in headless Chromium, and for every character the browser's position (left end of its
// advance, baseline), face and size, for every rule its rectangle and for every SVG image its
// viewport, are compared
// with the display list's items, in order. Positions are in em of the formula's font size.
// Formulas with a character KaTeX has no metrics of its own for are left out (the display list
// advances by KaTeX's stand-in; the browser draws it with a fallback font's own advance), and in
// display mode the equation tag (KaTeX puts it at the right end of the line), and formulas
// with `\reflectbox` (the display list does not mirror glyphs).
// Prints the worst deviations and a summary.
//
// Usage, from the repository root:
//   lake exe leantex-display CORPUS… > dump.jsonl
//   node tools/check-display.mjs KATEX_DIST dump.jsonl [--size PX] [--show N]
// KATEX_DIST is a directory with KaTeX's built katex.min.js, katex.min.css and fonts/ (of the
// pinned version). Playwright is loaded from $PLAYWRIGHT_MODULE (a path to the `playwright`
// package) or else resolved as the package `playwright`; it needs its Chromium.

import {createRequire} from "node:module";
import {readFileSync} from "node:fs";
import {join, resolve} from "node:path";

const args = process.argv.slice(2);
const opt = (name, dflt) => {
    const i = args.indexOf(name);
    if (i < 0) return dflt;
    const v = args[i + 1];
    args.splice(i, 2);
    return v;
};
const sizePx = Number(opt("--size", "400"));
const show = Number(opt("--show", "15"));
const [katexDir, dumpPath] = args.map((a) => resolve(a));
const require = createRequire(import.meta.url);
const {chromium} = require(process.env.PLAYWRIGHT_MODULE ?? "playwright");

const cases = readFileSync(dumpPath, "utf8").split("\n").filter((l) => l.trim())
    .map((l) => JSON.parse(l));

const browser = await chromium.launch();
const page = await browser.newPage();
// The page and KaTeX's files are served from a made-up origin, so the page is a standards-mode
// document that can load the fonts.
const ORIGIN = "http://katex.invalid/";
await page.route(ORIGIN + "**", (route) => {
    const rel = decodeURIComponent(new URL(route.request().url()).pathname.slice(1));
    if (rel === "index.html") {
        return route.fulfill({contentType: "text/html", body: "<!DOCTYPE html><html><head>" +
            "<link rel=\"stylesheet\" href=\"katex.min.css\"><script src=\"katex.min.js\">" +
            "</script></head><body></body></html>"});
    }
    return route.fulfill({path: join(katexDir, rel)});
});
await page.goto(ORIGIN + "index.html");
await page.waitForFunction(() => typeof katex !== "undefined");

// Renders a batch of formulas and measures them in the page: per formula the characters
// (face, character, x, baseline y, size) and the fraction bars (x, y, width, height), relative
// to the left end of the formula's baseline, in em of the formula's font size.
async function measure(batch) {
    return page.evaluate(async ([batch, sizePx]) => {
        const faceOf = (el) => {
            const cs = getComputedStyle(el);
            const family = cs.fontFamily.split(",")[0].trim().replace(/^"|"$/g, "")
                .replace(/^KaTeX_/, "");
            const bold = Number(cs.fontWeight) >= 600;
            const italic = cs.fontStyle === "italic";
            const styles = {Main: ["Regular", "Bold", "Italic", "BoldItalic"],
                Math: ["Italic", "BoldItalic"], Caligraphic: ["Regular", "Bold"],
                Fraktur: ["Regular", "Bold"], SansSerif: ["Regular", "Bold", "Italic"]}[family] ??
                ["Regular"];
            const want = bold && italic ? "BoldItalic" : bold ? "Bold" : italic ? "Italic" :
                "Regular";
            let pick = styles.includes(want) ? want :
                bold && styles.includes("Bold") ? "Bold" :
                bold && styles.includes("BoldItalic") ? "BoldItalic" :
                italic && styles.includes("Italic") ? "Italic" : styles[0];
            return family + "-" + pick;
        };
        const marker = () => {
            const m = document.createElement("span");
            m.style.cssText = "display:inline-block;width:0;height:0;";
            return m;
        };
        const hosts = [];
        for (const c of batch) {
            const d = document.createElement("div");
            d.style.fontSize = (sizePx / 1.21) + "px";
            d.style.whiteSpace = "nowrap";
            document.body.appendChild(d);
            const s = {...(c.settings ?? {}), displayMode: c.display, output: "html",
                throwOnError: false, strict: "ignore", macros: {...(c.macros ?? {})}};
            katex.render(c.tex, d, s);
            hosts.push(d);
        }
        await document.fonts.ready;
        const out = [];
        for (const d of hosts) {
            const html = d.querySelector(".katex-html");
            const base = html && html.querySelector(".katex-base");
            if (!base) { out.push(null); continue; }
            // each line's origin: the left end of its first part and its baseline (a line is
            // broken by a `katex-newline`; the display list's items are relative to their line)
            const origin = new Map();
            let lineX = null;
            for (const part of html.children) {
                if (part.classList.contains("katex-newline")) {
                    lineX = null;
                    continue;
                }
                const m = marker();
                part.insertBefore(m, part.firstChild);
                const r = m.getBoundingClientRect();
                if (lineX === null) lineX = r.left;
                origin.set(part, [lineX, r.bottom]);
            }
            const originOf = (el) => {
                let p = el;
                while (p && !origin.has(p)) p = p.parentElement;
                return p ? origin.get(p) : [0, 0];
            };
            const em = sizePx;
            const glyphs = [];
            const walker = document.createTreeWalker(html, NodeFilter.SHOW_TEXT);
            const texts = [];
            for (let n = walker.nextNode(); n; n = walker.nextNode()) texts.push(n);
            const tag = d.querySelector(".katex-display .katex-tag");
            for (const t of texts) {
                const parent = t.parentElement;
                if (tag && tag.contains(t)) continue;
                const mk = marker();
                parent.insertBefore(mk, t);
                const baseline = mk.getBoundingClientRect().bottom;
                // a phantom's text is drawn transparent: the display list has no items for it
                if (getComputedStyle(parent).color === "rgba(0, 0, 0, 0)") {
                    mk.remove();
                    continue;
                }
                const face = faceOf(parent);
                const size = parseFloat(getComputedStyle(parent).fontSize) / em;
                let i = 0;
                for (const ch of t.data) {
                    const len = ch.length;
                    if (ch !== "​") {
                        const r = document.createRange();
                        r.setStart(t, i);
                        r.setEnd(t, i + len);
                        const rect = r.getBoundingClientRect();
                        const [x0, y0] = originOf(parent);
                        glyphs.push([face, ch, (rect.left - x0) / em, (baseline - y0) / em, size]);
                    }
                    i += len;
                }
                mk.remove();
            }
            const rules = [];
            const ruleSel = ".frac-line, .overline-line, .underline-line, .katex-rule";
            for (const el of html.querySelectorAll(ruleSel)) {
                if (tag && tag.contains(el)) continue;
                const rect = el.getBoundingClientRect();
                const cs = getComputedStyle(el);
                const [x0, y0] = originOf(el);
                if (el.classList.contains("katex-rule")) {
                    rules.push([(rect.left - x0) / em, (rect.top - y0) / em, rect.width / em,
                        rect.height / em]);
                } else {
                    const bw = parseFloat(cs.borderBottomWidth);
                    rules.push([(rect.left - x0) / em, (rect.bottom - bw - y0) / em,
                        rect.width / em, bw / em]);
                }
            }
            const svgs = [];
            for (const el of html.querySelectorAll("svg")) {
                if (tag && tag.contains(el)) continue;
                const rect = el.getBoundingClientRect();
                const [x0, y0] = originOf(el);
                for (let k = 0; k < el.querySelectorAll("path").length; k++) {
                    svgs.push([(rect.left - x0) / em, (rect.top - y0) / em, rect.width / em,
                        rect.height / em]);
                }
            }
            // the widest line (in display mode `katex-html` is as wide as the page)
            let width = 0;
            let line = 0;
            for (const part of html.children) {
                if (part.classList.contains("katex-newline")) {
                    width = Math.max(width, line);
                    line = 0;
                } else if (part !== tag) line += part.getBoundingClientRect().width / em;
            }
            width = Math.max(width, line);
            out.push({glyphs, rules, svgs, width});
            d.remove();
        }
        return out;
    }, [batch, sizePx]);
}

const stats = {noMetrics: 0, svgs: 0, worstSvg: 0, formulas: 0, glyphs: 0, rules: 0, countMismatch: 0, faceMismatch: 0,
    worstX: 0, worstY: 0, worstSize: 0, worstRule: 0, worstWidth: 0};
const deviations = [];
const xs = [];
const BATCH = 50;
for (let b = 0; b < cases.length; b += BATCH) {
    const batch = cases.slice(b, b + BATCH);
    const measured = await measure(batch);
    batch.forEach((c, k) => {
        const m = measured[k];
        if (!m) return;
        // KaTeX lays out a character without metrics as zero-width, the browser does not; the
        // display list does not mirror the material of `\reflectbox`
        if (c.noMetrics || /reflectbox/.test(c.tex)) {
            stats.noMetrics++;
            return;
        }
        stats.formulas++;
        const inTag = (it) => c.display && c.tagX !== null && it[3] >= c.tagX - 1e-9;
        const ours = c.items.filter((it) => it[0] === "g" && !inTag(it));
        const ourRules = c.items.filter((it) => it[0] === "r" && !inTag(it));
        const ourSvgs = c.items.filter((it) => it[0] === "p" && !inTag(it));
        if (ours.length !== m.glyphs.length || ourRules.length !== m.rules.length ||
            ourSvgs.length !== m.svgs.length) {
            stats.countMismatch++;
            deviations.push({id: c.id, tex: c.tex, what: `glyphs ${ours.length} vs ` +
                `${m.glyphs.length}, rules ${ourRules.length} vs ${m.rules.length}, svgs ` +
                `${ourSvgs.length} vs ${m.svgs.length}`, d: Infinity});
            return;
        }
        let worst = 0;
        let what = "";
        ours.forEach((g, i) => {
            const [face, ch, x, y, size] = m.glyphs[i];
            stats.glyphs++;
            if (face !== g[1] || ch !== g[2]) {
                stats.faceMismatch++;
                if (what === "") what = `glyph ${i}: ${g[1]} ${g[2]} vs ${face} ${ch}`;
            }
            const dx = Math.abs(x - g[3]);
            const dy = Math.abs(y - g[4]);
            xs.push(dx);
            stats.worstX = Math.max(stats.worstX, dx);
            stats.worstY = Math.max(stats.worstY, dy);
            stats.worstSize = Math.max(stats.worstSize, Math.abs(size - g[5]));
            if (Math.max(dx, dy) > worst) {
                worst = Math.max(dx, dy);
                if (!what.startsWith("glyph")) what = `glyph ${i} '${ch}': dx ${dx.toFixed(5)}` +
                    ` dy ${dy.toFixed(5)}`;
            }
        });
        m.svgs.forEach((r, i) => {
            const o = ourSvgs[i];
            stats.svgs++;
            const d = Math.max(...r.map((v, j) => Math.abs(v - o[j + 1])));
            stats.worstSvg = Math.max(stats.worstSvg, d);
            if (d > worst) {
                worst = d;
                what = `svg ${i}: ${r.map((v) => v.toFixed(4))} vs ` +
                    `${o.slice(1).map((v) => v.toFixed(4))}`;
            }
        });
        m.rules.forEach((r, i) => {
            const o = ourRules[i];
            stats.rules++;
            const d = Math.max(...r.map((v, j) => Math.abs(v - o[j + 1])));
            stats.worstRule = Math.max(stats.worstRule, d);
            if (d > worst) {
                worst = d;
                what = `rule ${i}: ${r.map((v) => v.toFixed(4))} vs ` +
                    `${o.slice(1).map((v) => v.toFixed(4))}`;
            }
        });
        const dw = Math.abs(m.width - (c.display && c.tagX !== null ? c.tagX : c.width));
        stats.worstWidth = Math.max(stats.worstWidth, dw);
        deviations.push({id: c.id, tex: c.tex, what: what + ` width ${dw.toFixed(5)}`,
            d: Math.max(worst, dw)});
    });
}
await browser.close();

xs.sort((a, b) => a - b);
const pct = (p) => xs.length ? xs[Math.min(xs.length - 1, Math.floor(p * xs.length))] : 0;
deviations.sort((a, b) => b.d - a.d);
console.log(`font size ${sizePx}px; ${stats.formulas} formulas, ${stats.glyphs} glyphs, ` +
    `${stats.rules} rules, ${stats.svgs} SVG images`);
console.log(`left out: ${stats.noMetrics} formulas with a character KaTeX has no metrics of ` +
    `its own for (the browser draws it with a fallback font)`);
console.log(`glyph count differs: ${stats.countMismatch}; face or character differs: ` +
    `${stats.faceMismatch}`);
console.log(`worst |dx| ${stats.worstX.toFixed(5)} em (median ${pct(0.5).toFixed(5)}, 99% ` +
    `${pct(0.99).toFixed(5)}), worst |dy| ${stats.worstY.toFixed(5)} em, worst size ` +
    `${stats.worstSize.toFixed(5)}, worst rule ${stats.worstRule.toFixed(5)} em, worst SVG ` +
    `rectangle ${stats.worstSvg.toFixed(5)} em, worst width ` +
    `${stats.worstWidth.toFixed(5)} em`);
for (const d of deviations.slice(0, show)) {
    console.log(`  ${d.d === Infinity ? "count" : d.d.toFixed(5)}  ${d.id}: ${d.what}  ` +
        `[${d.tex.replace(/\s+/g, " ").slice(0, 60)}]`);
}
