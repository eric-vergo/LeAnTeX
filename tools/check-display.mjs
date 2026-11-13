// Released under Apache 2.0 license as described in the file LICENSE.
// Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
//
// Checks LeAnTeX's display lists against what a browser does with KaTeX's own rendering: each
// formula of a dump written by `lake exe leantex-display` is rendered with KaTeX (its CSS and
// fonts) in headless Chromium, and for every character the browser's position (left end of its
// advance, baseline), face and size, and for every fraction bar its rectangle, are compared
// with the display list's items, in order. Positions are in em of the formula's font size.
// Formulas with a character KaTeX has no metrics of its own for are left out (the display list
// advances by KaTeX's stand-in; the browser draws it with a fallback font's own advance), and in
// display mode the equation tag (KaTeX puts it at the right end of the line).
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
            const m0 = marker();
            base.insertBefore(m0, base.firstChild);
            const r0 = m0.getBoundingClientRect();
            const x0 = r0.left;
            const y0 = r0.bottom;
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
                        glyphs.push([face, ch, (rect.left - x0) / em, (baseline - y0) / em, size]);
                    }
                    i += len;
                }
                mk.remove();
            }
            const rules = [];
            for (const el of html.querySelectorAll(".frac-line")) {
                const rect = el.getBoundingClientRect();
                const bw = parseFloat(getComputedStyle(el).borderBottomWidth);
                rules.push([(rect.left - x0) / em, (rect.bottom - bw - y0) / em,
                    rect.width / em, bw / em]);
            }
            // the parts side by side (in display mode `katex-html` is as wide as the page)
            let width = 0;
            for (const part of html.children) {
                if (part !== tag) width += part.getBoundingClientRect().width / em;
            }
            out.push({glyphs, rules, width});
            d.remove();
        }
        return out;
    }, [batch, sizePx]);
}

const stats = {noMetrics: 0, formulas: 0, glyphs: 0, rules: 0, countMismatch: 0, faceMismatch: 0,
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
        // KaTeX lays out a character without metrics as zero-width, the browser does not
        if (c.noMetrics) {
            stats.noMetrics++;
            return;
        }
        stats.formulas++;
        const inTag = (it) => c.display && c.tagX !== null && it[3] >= c.tagX - 1e-9;
        const ours = c.items.filter((it) => it[0] === "g" && !inTag(it));
        const ourRules = c.items.filter((it) => it[0] === "r");
        if (ours.length !== m.glyphs.length || ourRules.length < m.rules.length) {
            stats.countMismatch++;
            deviations.push({id: c.id, tex: c.tex, what: `glyphs ${ours.length} vs ` +
                `${m.glyphs.length}, rules ${ourRules.length} vs ${m.rules.length}`, d: Infinity});
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
        // the browser's rules are a subset of ours (ours also has overlines and the like)
        m.rules.forEach((r, i) => {
            const o = ourRules[i];
            stats.rules++;
            const d = Math.max(...r.map((v, j) => Math.abs(v - o[j + 1])));
            stats.worstRule = Math.max(stats.worstRule, d);
            worst = Math.max(worst, d);
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
    `${stats.rules} fraction bars`);
console.log(`left out: ${stats.noMetrics} formulas with a character KaTeX has no metrics of ` +
    `its own for (the browser draws it with a fallback font)`);
console.log(`glyph count differs: ${stats.countMismatch}; face or character differs: ` +
    `${stats.faceMismatch}`);
console.log(`worst |dx| ${stats.worstX.toFixed(5)} em (median ${pct(0.5).toFixed(5)}, 99% ` +
    `${pct(0.99).toFixed(5)}), worst |dy| ${stats.worstY.toFixed(5)} em, worst size ` +
    `${stats.worstSize.toFixed(5)}, worst bar ${stats.worstRule.toFixed(5)} em, worst width ` +
    `${stats.worstWidth.toFixed(5)} em`);
for (const d of deviations.slice(0, show)) {
    console.log(`  ${d.d === Infinity ? "count" : d.d.toFixed(5)}  ${d.id}: ${d.what}  ` +
        `[${d.tex.replace(/\s+/g, " ").slice(0, 60)}]`);
}
