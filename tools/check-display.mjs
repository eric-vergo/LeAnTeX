// Released under Apache 2.0 license as described in the file LICENSE.
// Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
//
// Checks LeAnTeX's display lists against what a browser does with KaTeX's own rendering: each
// formula of a dump written by `lake exe leantex-display` is rendered with KaTeX (its CSS and
// fonts) in headless Chromium, and for every character the browser's position (left end of its
// advance, baseline), face and size, for every rule its rectangle and for every SVG image its
// viewport, are compared
// with the display list's items, in order. Positions are in em of the formula's font size.
// Display-mode formulas are rendered in a line as wide as the dump says (`lineWidth`), so their
// centring and the place of their tag are compared too; KaTeX's automatic equation numbers are
// written into their spans, numbered from 1 in each formula, as the display list numbers them.
// Rules are the fraction bars, overlines and underlines, `\rule`, the horizontal and vertical
// rules of arrays, the strike of `\sout`, and the backgrounds and borders of boxes; a dashed
// rule is compared as the dashes the display list draws for its rectangle. A mirrored glyph
// (`\reflectbox`) is compared by the right end of its advance. Formulas with a character KaTeX
// has no metrics of its own for are left out (the display list advances by KaTeX's stand-in;
// the browser draws it with a fallback font's own advance), and so are formulas with a colour
// the browser does not know (KaTeX accepts any word as a colour name; the browser ignores it).
// Prints the worst deviations and a summary.
//
// Usage, from the repository root:
//   lake exe leantex-display CORPUS… > dump.jsonl
//   node tools/check-display.mjs KATEX_DIST dump.jsonl [--size PX] [--show N] [--detail ID]
// (`--detail` prints every glyph's two positions for the cases whose id starts with ID)
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
const detail = opt("--detail", null);
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
        // the dashes of a dashed rule, as `dashRules` of `LeAnTeX/Layout/Display.lean` draws
        // them: three times the thickness long, gaps of at least twice, ends on a dash
        const dashes = (x, y, w, h, horizontal) => {
            const along = horizontal ? w : h;
            const t = horizontal ? h : w;
            const dash = 3 * t;
            const gap = 2 * t;
            if (dash + gap <= 0 || along < 2 * dash + gap) return [[x, y, w, h]];
            const n = Math.floor((along + gap) / (dash + gap));
            const space = (along - n * dash) / (n - 1);
            const out = [];
            for (let i = 0; i < n; i++) {
                const a = i * (dash + space);
                out.push(horizontal ? [x + a, y, dash, h] : [x, y + a, w, dash]);
            }
            return out;
        };
        function* ancestors(el) {
            for (let p = el; p; p = p.parentElement) yield p;
        }
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
            if (c.display) d.style.width = (c.lineWidth * sizePx) + "px";
            document.body.appendChild(d);
            const s = {...(c.settings ?? {}), displayMode: c.display, output: "html",
                throwOnError: false, strict: "ignore", macros: {...(c.macros ?? {})}};
            katex.render(c.tex, d, s);
            // the automatic equation numbers as text, numbered from 1 in each formula
            let eqn = 1;
            for (const e of d.querySelectorAll(".eqn-num")) {
                e.classList.remove("eqn-num");
                e.textContent = `(${eqn++})`;
            }
            hosts.push(d);
        }
        await document.fonts.ready;
        const out = [];
        for (const d of hosts) {
            const html = d.querySelector(".katex-html");
            const base = html && html.querySelector(".katex-base");
            if (!base) { out.push(null); continue; }
            // a colour the browser does not know leaves a box without its background
            if (batch[hosts.indexOf(d)].colors.some((x) => !CSS.supports("color", x))) {
                out.push({unknownColor: true});
                continue;
            }
            const display = d.querySelector(".katex-display") !== null;
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
                // in display mode, x is measured from the left end of the line
                if (lineX === null) lineX = display ? html.getBoundingClientRect().left : r.left;
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
            for (const t of texts) {
                const parent = t.parentElement;
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
                    if (ch !== "\u200b" && ch !== " ") {
                        const r = document.createRange();
                        r.setStart(t, i);
                        r.setEnd(t, i + len);
                        const rect = r.getBoundingClientRect();
                        const [x0, y0] = originOf(parent);
                        // inside an odd number of `\reflectbox`es the glyph is mirrored
                        const mirrored = [...ancestors(parent)].filter((a) =>
                            a.classList.contains("reflectbox")).length % 2 === 1;
                        glyphs.push([face, ch, ((mirrored ? rect.right : rect.left) - x0) / em,
                            (baseline - y0) / em, size]);
                    }
                    i += len;
                }
                mk.remove();
            }
            const rules = [];
            const ruleSel = ".frac-line, .overline-line, .underline-line, .katex-rule, " +
                ".katex-hline, .katex-hdashline, .vertical-separator, .katex-sout, .fbox, " +
                ".fcolorbox, .colorbox, .angl";
            // a rule, or the dashes the display list draws for a dashed one
            const push = (x, y, w, h, dashed, horizontal) => {
                const r = [x / em, y / em, w / em, h / em];
                if (!dashed) { rules.push(r); return; }
                for (const q of dashes(...r, horizontal)) rules.push(q);
            };
            for (const el of html.querySelectorAll(ruleSel)) {
                const rect = el.getBoundingClientRect();
                const cs = getComputedStyle(el);
                if (cs.color === "rgba(0, 0, 0, 0)" && !el.matches(".fbox, .fcolorbox, " +
                    ".colorbox, .angl")) continue;
                const [x0, y0] = originOf(el);
                const x = rect.left - x0;
                const y = rect.top - y0;
                if (el.classList.contains("katex-rule")) {
                    push(x, y, rect.width, rect.height, false);
                } else if (el.classList.contains("vertical-separator")) {
                    const bw = parseFloat(cs.borderRightWidth);
                    push(rect.right - bw - x0, y, bw, rect.height,
                        cs.borderRightStyle === "dashed", false);
                } else if (el.matches(".fbox, .fcolorbox, .colorbox, .angl")) {
                    // the background, then the top, bottom, left and right borders
                    if (cs.backgroundColor !== "rgba(0, 0, 0, 0)") {
                        push(x, y, rect.width, rect.height, false);
                    }
                    if (cs.borderTopColor === "rgba(0, 0, 0, 0)") continue;
                    const [t, r, b, l] = ["Top", "Right", "Bottom", "Left"].map((k) =>
                        cs["border" + k + "Style"] === "none" ? 0 :
                            parseFloat(cs["border" + k + "Width"]));
                    if (t > 0) push(x, y, rect.width, t, false);
                    if (b > 0) push(x, rect.bottom - b - y0, rect.width, b, false);
                    if (l > 0) push(x, y, l, rect.height, false);
                    if (r > 0) push(rect.right - r - x0, y, r, rect.height, false);
                } else {
                    const bw = parseFloat(cs.borderBottomWidth);
                    push(x, rect.bottom - bw - y0, rect.width, bw,
                        cs.borderBottomStyle === "dashed", true);
                }
            }
            const svgs = [];
            for (const el of html.querySelectorAll("svg")) {
                const rect = el.getBoundingClientRect();
                const [x0, y0] = originOf(el);
                for (let k = 0; k < el.querySelectorAll("path, line").length; k++) {
                    svgs.push([(rect.left - x0) / em, (rect.top - y0) / em, rect.width / em,
                        rect.height / em]);
                }
            }
            // the widest line (in display mode `katex-html` is as wide as the line)
            let width = 0;
            let line = 0;
            for (const part of html.children) {
                if (part.classList.contains("katex-newline")) {
                    width = Math.max(width, line);
                    line = 0;
                } else line += part.getBoundingClientRect().width / em;
            }
            width = Math.max(width, line);
            if (display) width = Math.max(width, html.getBoundingClientRect().width / em);
            out.push({glyphs, rules, svgs, width});
            d.remove();
        }
        return out;
    }, [batch, sizePx]);
}

const stats = {noMetrics: 0, unknownColor: 0, svgs: 0, worstSvg: 0, formulas: 0, glyphs: 0, rules: 0, countMismatch: 0, faceMismatch: 0,
    worstX: 0, worstY: 0, worstSize: 0, worstRule: 0, worstWidth: 0};
const deviations = [];
const faceMismatches = [];
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
        if (m.unknownColor) {
            stats.unknownColor++;
            return;
        }
        stats.formulas++;
        const ours = c.items.filter((it) => it[0] === "g");
        const ourRules = c.items.filter((it) => it[0] === "r");
        const ourSvgs = c.items.filter((it) => it[0] === "p");
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
                faceMismatches.push(`${c.id}: glyph ${i}: ${g[1]} ${g[2]} vs ${face} ${ch}`);
                if (what === "") what = `glyph ${i}: ${g[1]} ${g[2]} vs ${face} ${ch}`;
            }
            const dx = Math.abs(x - g[3]);
            const dy = Math.abs(y - g[4]);
            if (detail !== null && c.id.startsWith(detail)) {
                console.log(`  ${c.id} glyph ${i} ${g[2]}: ours ${g[3].toFixed(4)} ` +
                    `${g[4].toFixed(4)}, browser ${x.toFixed(4)} ${y.toFixed(4)}`);
            }
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
                    `${o.slice(1, 5).map((v) => v.toFixed(4))}`;
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
                    `${o.slice(1, 5).map((v) => v.toFixed(4))}`;
            }
        });
        const dw = Math.abs(m.width - c.width);
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
    `its own for (the browser draws it with a fallback font), ${stats.unknownColor} with a ` +
    `colour the browser does not know`);
console.log(`glyph count differs: ${stats.countMismatch}; face or character differs: ` +
    `${stats.faceMismatch}`);
console.log(`worst |dx| ${stats.worstX.toFixed(5)} em (median ${pct(0.5).toFixed(5)}, 99% ` +
    `${pct(0.99).toFixed(5)}), worst |dy| ${stats.worstY.toFixed(5)} em, worst size ` +
    `${stats.worstSize.toFixed(5)}, worst rule ${stats.worstRule.toFixed(5)} em, worst SVG ` +
    `rectangle ${stats.worstSvg.toFixed(5)} em, worst width ` +
    `${stats.worstWidth.toFixed(5)} em`);
for (const f of faceMismatches.slice(0, show)) console.log(`  face  ${f}`);
for (const d of deviations.slice(0, show)) {
    console.log(`  ${d.d === Infinity ? "count" : d.d.toFixed(5)}  ${d.id}: ${d.what}  ` +
        `[${d.tex.replace(/\s+/g, " ").slice(0, 60)}]`);
}
