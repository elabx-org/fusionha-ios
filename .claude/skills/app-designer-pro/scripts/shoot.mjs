#!/usr/bin/env node
/**
 * App Designer Pro shoot: render every screen, icon, stage and store panel in
 * a mockup to PNG, tile the contact sheets, and run the slop scan (design and
 * copy) on the rendered DOM.
 *
 *   node shoot.mjs mockup.html                       -> ./shots next to the file
 *   node shoot.mjs mockup.html --out shots/r1
 *   node shoot.mjs mockup.html --small               small phones: iPhone 375x667, Android 360x760
 *   node shoot.mjs mockup.html --only today,paywall  just these (data-name prefixes), to iterate fast
 *   node shoot.mjs mockup.html --scale 3 --dark --no-scan
 *
 * What comes out (in --out):
 *   <name>.png           every top-level .screen at 3x, and the iOS icon at 1032px (named by
 *                        data-name, so paths stay put when screens are added)
 *   sheet.png            the flow, four to a row
 *   review/a+b.png       two screens per image at 1.5x: read these, round after round
 *   pairs/<pair>.png     screens sharing data-pair: iPhone and Android side by side
 *   icon-ios-modes.png   the iOS icon in default, dark and tinted, and at home-screen size
 *   icons/android-*.png  adaptive icon: layers, launcher masks, themed, safe zone, 512 Play icon
 *   stages/<name>.png    each .stage at 2x (1080 wide). Moving ones: record with reel.mjs
 *   panels/<store>-<name>.png      store panels at the exact size each store asks for
 *   panels.png           the store series side by side, the way a shopper meets it
 *   scan.json            every finding, per surface
 *
 * Exit code 1 if the scan finds any FAIL. Warnings never fail the run.
 *
 * Uses the installed Chrome (so SF Pro and New York render as on a Mac) via
 * playwright-core, resolved from the cwd first, then from this skill folder.
 * If neither has it:  npm i playwright-core   (in either place).
 */
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
let chromium;
for (const base of [process.cwd(), path.join(here, "..")]) {
  try { ({ chromium } = createRequire(path.join(base, "package.json"))("playwright-core")); break; } catch {}
}
if (!chromium) {
  console.error("playwright-core not found. Run once:\n  npm i playwright-core\nin your project, or in " + path.join(here, ".."));
  process.exit(2);
}

const argv = process.argv.slice(2);
const arg = (n, d) => { const i = argv.indexOf(n); return i > -1 && argv[i + 1] ? argv[i + 1] : d; };
const has = (n) => argv.includes(n);
const file = argv.find((a) => a.endsWith(".html"));
if (!file) { console.error("usage: node shoot.mjs <mockup.html> [--out dir] [--small] [--scale 3] [--dark] [--no-scan]"); process.exit(2); }

const SRC = path.resolve(file);
const OUT = path.resolve(arg("--out", path.join(path.dirname(SRC), "shots")));
const SCALE = parseFloat(arg("--scale", "3"));
const STAGE_SCALE = parseFloat(arg("--stage-scale", "2"));
const W = arg("--width"), H = arg("--height");
const SMALL = has("--small") || !!(W || H);
const ONLY = (arg("--only") || "").split(",").map((x) => x.trim().toLowerCase()).filter(Boolean);
fs.mkdirSync(OUT, { recursive: true });
// A folder this script shot before is cleared of its own outputs, so no
// stale PNG from an older round is mistaken for the current one.
if (fs.existsSync(path.join(OUT, "scan.json")) && !ONLY_EARLY()) {
  for (const f of fs.readdirSync(OUT)) {
    const p = path.join(OUT, f);
    if (f.endsWith(".png") || f === "scan.json") fs.rmSync(p, { force: true });
    else if (["pairs", "panels", "stages", "icons", "review"].includes(f)) fs.rmSync(p, { recursive: true, force: true });
  }
}
function ONLY_EARLY() { return (argv.indexOf("--only") > -1); }

const CHROME = [
  process.env.APP_DESIGNER_CHROME,
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/Applications/Chromium.app/Contents/MacOS/Chromium",
  "C:/Program Files/Google/Chrome/Application/chrome.exe",
  "/usr/bin/google-chrome",
  "/usr/bin/chromium",
].find((p) => p && fs.existsSync(p));

const browser = await chromium.launch({ executablePath: CHROME, headless: true });
const slug = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
const pngSize = (f) => { const b = fs.readFileSync(f); return [b.readUInt32BE(16), b.readUInt32BE(20)]; };
const notes = [];

// Small phones are applied before the page's own scripts run, so a layout
// that measures the screen at load sees the size it will be shot at.
const smallCss = W || H
  ? `.screen:not(.device .screen){${W ? `--screen-w:${W}px !important;` : ""}${H ? `--screen-h:${H}px !important;` : ""}}`
  : `.screen:not([data-os="android"]):not(.device .screen){--screen-w:375px !important;--screen-h:667px !important;}` +
    `.screen[data-os="android"]:not(.device .screen){--screen-w:360px !important;--screen-h:760px !important;}`;

async function open(dsf, { small = false } = {}) {
  const page = await browser.newPage({
    viewport: { width: 1400, height: 1000 },
    deviceScaleFactor: dsf,
    colorScheme: has("--dark") ? "dark" : "light",
  });
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  page.on("requestfailed", (r) => errors.push("request failed: " + r.url()));
  if (small) await page.addInitScript((css) => {
    window.__acSmall = true;
    const st = () => { const el = document.createElement("style"); el.textContent = css; (document.head || document.documentElement).appendChild(el); };
    if (document.documentElement) st();
    else new MutationObserver((_, o) => { if (document.documentElement) { o.disconnect(); st(); } }).observe(document, { childList: true });
  }, smallCss);
  await page.goto(pathToFileURL(SRC).href, { waitUntil: "networkidle" });
  await page.evaluate(async () => {
    // device.js adds font links at the end of the body: wait for those too.
    await document.fonts.ready;
    await new Promise((r) => setTimeout(r, 150));
    await document.fonts.ready;
    // Land every finite animation on its final frame. A screen marked
    // data-freeze="ms" is paused at that moment instead; a living screen
    // (data-motion) without one is paused at 0. Loops elsewhere stop where
    // they are, so every still is repeatable.
    for (const a of document.getAnimations()) {
      try {
        const target = a.effect?.target;
        const host = target?.closest?.("[data-freeze]");
        if (host) { a.pause(); a.currentTime = parseFloat(host.dataset.freeze) || 0; continue; }
        if (target?.closest?.("[data-motion]")) { a.pause(); a.currentTime = 0; continue; }
        const t = a.effect?.getComputedTiming?.();
        if (t && t.endTime !== Infinity) a.finish(); else a.pause();
      } catch {}
    }
    await new Promise((r) => setTimeout(r, 250));
  });
  // Transparent outside rounded corners, so every PNG drops onto any page.
  await page.addStyleTag({ content: "html,body{background:transparent!important}" });
  // Number the top-level things to shoot, the same way on every page.
  await page.evaluate(() => {
    [...document.querySelectorAll(".screen, .app-icon, .adaptive-icon, .stage, .panel")]
      .filter((e) => !e.parentElement.closest(".device, .mini, .stage, .panel, .screen, .app-icon, .adaptive-icon"))
      .forEach((e, i) => e.setAttribute("data-ac-i", i));
  });
  return { page, errors };
}

// ------------------------------------------------------------- inventory
const A = await open(SCALE, { small: SMALL });
const page = A.page;
const items = await page.evaluate(() => {
  const kinds = [["screen", "screen"], ["app-icon", "icon"], ["adaptive-icon", "adaptive"], ["stage", "stage"], ["panel", "panel"]];
  const els = [...document.querySelectorAll("[data-ac-i]")];
  return els.map((e, i) => {
    const r = e.getBoundingClientRect();
    return {
      i, type: kinds.find(([c]) => e.classList.contains(c))[1],
      name: e.dataset.name || "", os: e.dataset.os === "android" ? "android" : "ios",
      pair: e.dataset.pair || "", store: e.dataset.store || "", motion: e.dataset.motion || "",
      chrome: e.dataset.chrome || "", w: r.width, h: r.height,
    };
  });
});
if (!items.some((x) => x.type === "screen")) { console.error("No .screen elements found. Wrap each screen in <section class=\"screen\">."); process.exit(2); }
const unsized = items.filter((x) => x.w < 10 || x.h < 10);
if (unsized.length) {
  console.error(`${unsized.length} element(s) have no size, so device.css did not load. Link it with an absolute file:// URL to <skill>/assets/device.css.`);
  for (const e of A.errors) console.error("  " + e);
  process.exit(2);
}
const el = (pg, i) => pg.$(`[data-ac-i="${i}"]`);
// --only: keep the named surfaces, and tell the scan to skip the rest.
const picked = (x) => !ONLY.length || ONLY.some((o) => slug(x.name).startsWith(slug(o)));
if (ONLY.length) {
  const keep = items.filter(picked);
  if (!keep.length) { console.error(`--only ${ONLY.join(",")} matched nothing. Names: ${items.map((x) => x.name).filter(Boolean).join(", ")}`); process.exit(2); }
  await page.evaluate((keepIdx) => { for (const e of document.querySelectorAll("[data-ac-i]")) if (!keepIdx.includes(+e.getAttribute("data-ac-i"))) e.setAttribute("data-ac-skip", ""); }, keep.map((x) => x.i));
}

// ------------------------------------------------------- screens + iOS icon
const shots = [];
const used = new Set();
const uniqueName = (base) => { let nm = base, k = 2; while (used.has(nm)) nm = `${base}-${k++}`; if (nm !== base) notes.push(`warn  two surfaces are named "${base}"; the second was saved as "${nm}". Give every screen its own data-name.`); used.add(nm); return nm; };
let n = 0;
for (const it of items.filter((x) => (x.type === "screen" || x.type === "icon") && picked(x))) {
  n++;
  const name = uniqueName(slug(it.name) || (it.type === "icon" ? "icon" : `screen-${n}`));
  const out = path.join(OUT, `${name}.png`);
  await (await el(page, it.i)).screenshot({ path: out, omitBackground: true });
  shots.push({ ...it, name, out });
}

// Contact sheet: four to a row so a reviewer is not reading a downsampled
// strip. Detail lives in the 3x PNGs; read those too.
const sheet = async (list, outFile, { width = (s) => s.w, radius = (s) => (s.type === "icon" ? 77 : s.os === "android" ? 44 : 55), perRow = 4, bg = "#d9d9d6", caption = (s) => s.name } = {}) => {
  const cols = Math.min(perRow, list.length);
  const colW = Math.max(...list.map(width));
  const html = `<html><body style="margin:0;padding:40px;background:${bg};display:grid;grid-template-columns:repeat(${cols},${colW}px);gap:40px 32px;align-items:start;width:${cols * (colW + 32) - 32}px">${list
    .map((s) => `<figure style="margin:0;font:500 13px -apple-system,system-ui;color:#555"><img src="${pathToFileURL(s.out).href}" style="width:${width(s)}px;display:block;border-radius:${radius(s)}px"><figcaption style="padding-top:10px;text-align:center">${caption(s)}</figcaption></figure>`)
    .join("")}</body></html>`;
  const tmp = path.join(OUT, `_${path.basename(outFile, ".png")}.html`);
  fs.writeFileSync(tmp, html);
  const sp = await browser.newPage({ deviceScaleFactor: 1, viewport: { width: 80 + cols * (colW + 32), height: 800 } });
  await sp.goto(pathToFileURL(tmp).href, { waitUntil: "load" });
  await sp.screenshot({ path: outFile, fullPage: true });
  await sp.close();
  fs.unlinkSync(tmp);
};
if (shots.length) await sheet(shots, path.join(OUT, "sheet.png"));

// Review tiles: two screens at 1.5x per image. Enough to judge type,
// spacing and contrast without opening twenty 3x frames.
const reviewable = shots.filter((s) => s.type === "screen");
if (reviewable.length) {
  fs.mkdirSync(path.join(OUT, "review"), { recursive: true });
  // An --only run replaces the tiles of the screens it shot, never leaves them stale.
  if (ONLY.length) for (const f of fs.readdirSync(path.join(OUT, "review"))) if (reviewable.some((s) => f.split(/[+.]/).includes(s.name))) fs.rmSync(path.join(OUT, "review", f));
  for (let i = 0; i < reviewable.length; i += 2) {
    const pair = reviewable.slice(i, i + 2);
    const html = `<html><body style="margin:0;padding:24px;background:#d9d9d6;display:flex;gap:24px;align-items:flex-start;width:max-content">${pair
      .map((s) => `<figure style="margin:0;font:500 15px -apple-system,system-ui;color:#555"><img src="${pathToFileURL(s.out).href}" style="width:${Math.round(s.w * 1.5)}px;display:block;border-radius:${s.os === "android" ? 66 : 82}px"><figcaption style="padding-top:10px;text-align:center">${s.name}</figcaption></figure>`)
      .join("")}</body></html>`;
    const tmp = path.join(OUT, "_review.html");
    fs.writeFileSync(tmp, html);
    const rp = await browser.newPage({ deviceScaleFactor: 1, viewport: { width: 1400, height: 400 } });
    await rp.goto(pathToFileURL(tmp).href, { waitUntil: "load" });
    await rp.screenshot({ path: path.join(OUT, "review", `${pair.map((s) => s.name).join("+")}.png`), fullPage: true });
    await rp.close();
    fs.unlinkSync(tmp);
  }
}

// Pairs: the same screen on both platforms, side by side.
const pairs = new Map();
for (const s of shots.filter((s) => s.pair)) pairs.set(s.pair, [...(pairs.get(s.pair) || []), s]);
if (pairs.size) {
  fs.mkdirSync(path.join(OUT, "pairs"), { recursive: true });
  for (const [p, list] of pairs) {
    const sorted = list.sort((a, b) => (a.os === b.os ? 0 : a.os === "ios" ? -1 : 1));
    await sheet(sorted, path.join(OUT, "pairs", `${slug(p)}.png`), { perRow: 2, bg: "#e6e5e1", caption: (s) => `${s.os === "android" ? "Android" : "iPhone"} · ${s.name}` });
    const oses = new Set(list.map((s) => s.os));
    if (oses.size < 2) notes.push(`warn  pair "${p}" has no ${oses.has("ios") ? "Android" : "iPhone"} screen. A pair is the same screen on both platforms.`);
  }
}

// iOS icon: default, dark and tinted, then at home-screen size, where the
// silhouette has to survive. Style the modes with .app-icon[data-mode="dark"]
// and [data-mode="tinted"]; without them the three tiles are the same.
const iosIcon = items.find((x) => x.type === "icon" && picked(x));
if (iosIcon && !SMALL) {
  // Styled modes, judged by what renders (linked file:// stylesheets cannot
  // be read): a clone in dark mode must compute differently somewhere.
  const styled = await page.evaluate((i) => {
    const src = document.querySelector(`[data-ac-i="${i}"]`);
    const sig = (root) => [root, ...root.querySelectorAll("*")].map((n) => { const c = getComputedStyle(n); return [c.backgroundColor, c.backgroundImage, c.color, c.fill, c.opacity, c.display].join("|"); }).join(";");
    const c = src.cloneNode(true); c.removeAttribute("data-ac-i"); c.setAttribute("data-mode", "dark");
    c.style.cssText += ";position:absolute;left:-9999px;top:0";
    document.body.append(c);
    const a = sig(src), b = sig(c);
    c.remove();
    return a !== b;
  }, iosIcon.i);
  await page.evaluate((i) => {
    const src = document.querySelector(`[data-ac-i="${i}"]`);
    const box = document.createElement("div");
    box.id = "ac-icon-modes";
    box.style.cssText = "position:absolute;left:0;top:0;z-index:99999;display:flex;gap:28px;align-items:center;padding:36px;background:linear-gradient(160deg,#5d7c8c,#2e3f4a 60%,#1c2329);font:500 12px -apple-system,system-ui;color:#fff";
    for (const mode of ["", "dark", "tinted"]) {
      const f = document.createElement("figure"); f.style.cssText = "margin:0;text-align:center";
      const c = src.cloneNode(true); c.removeAttribute("data-ac-i"); if (mode) c.setAttribute("data-mode", mode); c.style.zoom = "0.5";
      const cap = document.createElement("figcaption"); cap.textContent = mode || "default"; cap.style.paddingTop = "10px";
      f.append(c, cap); box.append(f);
    }
    for (const pt of [60, 40]) {
      const w = document.createElement("div"); w.style.cssText = `width:${pt}px;height:${pt}px;position:relative;flex:none`;
      const c = src.cloneNode(true); c.removeAttribute("data-ac-i");
      c.style.cssText += `;position:absolute;left:0;top:0;transform:scale(${pt / 344});transform-origin:0 0`;
      w.append(c); box.append(w);
    }
    document.body.append(box);
  }, iosIcon.i);
  await (await page.$("#ac-icon-modes")).screenshot({ path: path.join(OUT, "icon-ios-modes.png") });
  await page.evaluate(() => document.getElementById("ac-icon-modes").remove());
  if (!styled) notes.push(`warn  the iOS icon has no dark or tinted styles (.app-icon[data-mode="dark"], [data-mode="tinted"]). iOS 26 shows all three.`);
}

// ------------------------------------------- stages, panels, adaptive icons
const extra = items.filter((x) => ["stage", "panel", "adaptive"].includes(x.type) && picked(x));
const exported = [];
if (extra.length && !SMALL) {
  const STORE = { appstore: [1320, 2868, 3], play: [1080, 1920, 3], feature: [1024, 500, 2] };
  const dsfOf = (x) => x.type === "stage" ? STAGE_SCALE : x.type === "adaptive" ? 1 : (STORE[x.store]?.[2] || 3);
  const groups = new Map();
  for (const x of extra) groups.set(dsfOf(x), [...(groups.get(dsfOf(x)) || []), x]);
  const panelCount = {};
  for (const [dsf, list] of groups) {
    const P = await open(dsf);
    for (const x of list) {
      const h = await el(P.page, x.i);
      if (x.type === "stage") {
        fs.mkdirSync(path.join(OUT, "stages"), { recursive: true });
        const out = path.join(OUT, "stages", `${slug(x.name) || "stage-" + x.i}.png`);
        await h.screenshot({ path: out });
        exported.push({ ...x, out });
      } else if (x.type === "panel") {
        fs.mkdirSync(path.join(OUT, "panels"), { recursive: true });
        const store = x.store || "panel";
        panelCount[store] = (panelCount[store] || 0) + 1;
        const out = path.join(OUT, "panels", `${uniqueName(`${store}-${slug(x.name) || `panel-${panelCount[store]}`}`)}.png`);
        await h.screenshot({ path: out });
        const want = STORE[x.store];
        const [w, hh] = pngSize(out);
        if (want && (w !== want[0] || hh !== want[1])) notes.push(`FAIL  ${path.basename(out)} is ${w} x ${hh}; ${x.store} needs ${want[0]} x ${want[1]}. Keep the panel at the size device.css gives it.`);
        exported.push({ ...x, out, store });
      } else {
        // Adaptive icon: the master, each layer, the launcher masks, themed,
        // the safe zone, and the 512px Play Store icon.
        const dir = path.join(OUT, "icons");
        fs.mkdirSync(dir, { recursive: true });
        const base = slug(x.name) || "android";
        // The layers are shown and hidden here, never left to the author's
        // CSS: a display rule on a layer must not let the mono ink cover
        // the colour icon in an export.
        const showLayers = (e, show) => {
          for (const c of e.children) {
            const on = show === "both" ? !c.classList.contains("layer-mono") : c.classList.contains(show);
            c.style.setProperty("display", on ? "block" : "none", "important");
          }
        };
        await h.evaluate((e) => { for (const c of e.children) c.style.setProperty("display", c.classList.contains("layer-mono") ? "none" : "block", "important"); });
        await h.screenshot({ path: path.join(dir, `${base}-full.png`) });
        const layer = async (show, file, transparent) => {
          await h.evaluate((e, show) => {
            for (const c of e.children) c.style.setProperty("display", c.classList.contains(show) ? "block" : "none", "important");
            if (show !== "layer-bg") e.style.setProperty("background", "transparent", "important");
          }, show);
          await h.screenshot({ path: path.join(dir, file), omitBackground: transparent });
          await h.evaluate((e) => { for (const c of e.children) c.style.setProperty("display", c.classList.contains("layer-mono") ? "none" : "block", "important"); e.style.removeProperty("background"); });
        };
        await layer("layer-bg", `${base}-layer-bg.png`, false);
        await layer("layer-fg", `${base}-layer-fg.png`, true);
        const hasMono = await h.evaluate((e) => !!e.querySelector(".layer-mono"));
        if (hasMono) await layer("layer-mono", `${base}-layer-mono.png`, true);
        else notes.push(`warn  the adaptive icon has no .layer-mono: Android 13+ themed icons fall back to a tinted square.`);
        // Each sheet is built, shot and removed on its own, so no sheet can
        // paint over another's screenshot.
        const sheetShot = async (kind, file) => {
          await P.page.evaluate(({ i, kind }) => {
            const src = document.querySelector(`[data-ac-i="${i}"]`);
            const clone = (mode) => {
              const c = src.cloneNode(true);
              c.removeAttribute("data-ac-i");
              for (const k of c.children) {
                const mono = k.classList.contains("layer-mono");
                k.style.setProperty("display", mode === "themed" ? (mono ? "block" : "none") : (mono ? "none" : "block"), "important");
              }
              if (mode) c.setAttribute("data-mode", mode);
              return c;
            };
            const win = (css, mode, z = 1) => {
              const w = document.createElement("div");
              w.style.cssText = `width:288px;height:288px;overflow:hidden;position:relative;flex:none;${css};zoom:${z}`;
              const c = clone(mode); c.style.cssText += ";position:absolute;left:-72px;top:-72px"; w.append(c); return w;
            };
            const box = document.createElement("div");
            box.id = "ac-sheet";
            box.style.cssText = "position:absolute;left:0;top:0;z-index:99999";
            if (kind === "masks") {
              box.style.cssText += ";display:flex;flex-wrap:wrap;gap:32px;align-items:flex-end;padding:40px;width:1400px;background:#e9ecef;font:500 14px system-ui;color:#3a3f45";
              for (const [label, css, mode] of [["circle", "border-radius:50%", ""], ["squircle", "border-radius:36%", ""], ["rounded square", "border-radius:22%", ""], ["themed", "border-radius:50%", "themed"]]) {
                const f = document.createElement("figure"); f.style.cssText = "margin:0;text-align:center";
                const cap = document.createElement("figcaption"); cap.textContent = label; cap.style.cssText = "padding-top:12px";
                f.append(win(css, mode), cap); box.append(f);
              }
              const row = document.createElement("div"); row.style.cssText = "display:flex;gap:22px;align-items:center;padding:24px 28px;border-radius:28px;background:linear-gradient(135deg,#3d4b5c,#1f262e)";
              for (const [css, mode] of [["border-radius:50%", ""], ["border-radius:50%", "themed"], ["border-radius:36%", ""]]) row.append(win(css, mode, 56 / 288));
              box.append(row);
            } else if (kind === "safe") {
              const g = clone(""); g.style.cssText += ";position:relative";
              const ov = document.createElement("div");
              ov.style.cssText = "position:absolute;inset:0;pointer-events:none;background:radial-gradient(circle at 50% 50%,transparent 131px,rgba(255,0,80,.9) 132px,transparent 134px),linear-gradient(rgba(0,0,0,.28),rgba(0,0,0,.28)) top/100% 72px no-repeat,linear-gradient(rgba(0,0,0,.28),rgba(0,0,0,.28)) bottom/100% 72px no-repeat,linear-gradient(rgba(0,0,0,.28),rgba(0,0,0,.28)) left/72px 100% no-repeat,linear-gradient(rgba(0,0,0,.28),rgba(0,0,0,.28)) right/72px 100% no-repeat";
              g.append(ov); box.append(g);
            } else {
              box.append(win("", "", 512 / 288));
            }
            document.body.append(box);
          }, { i: x.i, kind });
          await (await P.page.$("#ac-sheet")).screenshot({ path: path.join(dir, file) });
          await P.page.evaluate(() => document.getElementById("ac-sheet").remove());
        };
        await sheetShot("masks", `${base}-masks.png`);
        await sheetShot("safe", `${base}-safe-zone.png`);
        await sheetShot("play", "play-icon-512.png");
        const [pw, ph] = pngSize(path.join(dir, "play-icon-512.png"));
        if (pw !== 512 || ph !== 512) notes.push(`FAIL  play-icon-512.png is ${pw} x ${ph}; Google Play needs 512 x 512.`);
        exported.push({ ...x, out: path.join(dir, `${base}-masks.png`) });
      }
    }
    for (const e of P.errors) if (!A.errors.includes(e)) A.errors.push(e);
    await P.page.close();
  }
  const panels = exported.filter((x) => x.type === "panel");
  if (panels.length) {
    const byStore = (s) => panels.filter((p) => p.store === s);
    const rows = [...new Set(panels.map((p) => p.store))].map(byStore);
    const html = `<html><body style="margin:0;padding:40px;background:#f1f1ef;font:500 13px -apple-system,system-ui;color:#555">${rows
      .map((r) => `<p style="margin:0 0 12px">${r[0].store}</p><div style="display:flex;gap:16px;margin-bottom:40px;align-items:flex-start">${r
        .map((p) => `<img src="${pathToFileURL(p.out).href}" style="height:${p.store === "feature" ? 200 : 520}px;display:block;border-radius:${p.store === "feature" ? 8 : 18}px;box-shadow:0 1px 3px rgba(0,0,0,.12)">`)
        .join("")}</div>`)
      .join("")}</body></html>`;
    const tmp = path.join(OUT, "_panels.html");
    fs.writeFileSync(tmp, html);
    const sp = await browser.newPage({ deviceScaleFactor: 1, viewport: { width: 80 + Math.max(...rows.map((r) => r.reduce((a, p) => a + (p.store === "feature" ? 410 : p.store === "play" ? 309 : 255), 0))), height: 600 } });
    await sp.goto(pathToFileURL(tmp).href, { waitUntil: "load" });
    await sp.screenshot({ path: path.join(OUT, "panels.png"), fullPage: true });
    await sp.close();
    fs.unlinkSync(tmp);
  }
}

console.log(`\nShot ${shots.length} screen(s) and icon(s) at ${SCALE}x${SMALL ? " (small phones)" : ""} -> ${OUT}`);
for (const s of shots) console.log("  " + s.out);
if (shots.length) console.log("  " + path.join(OUT, "sheet.png") + "   (the flow)");
if (reviewable.length) console.log("  " + path.join(OUT, "review") + "/   (two screens per image at 1.5x: read every one; open a 3x PNG only to check a detail)");
for (const p of pairs.keys()) console.log("  " + path.join(OUT, "pairs", `${slug(p)}.png`));
if (iosIcon && !SMALL) console.log("  " + path.join(OUT, "icon-ios-modes.png"));
for (const x of exported) console.log("  " + x.out + (x.motion ? `   (moves: node <skill>/scripts/reel.mjs ${path.basename(SRC)} --only ${slug(x.name)})` : ""));
if (exported.some((x) => x.type === "panel")) console.log("  " + path.join(OUT, "panels.png") + "   (the store series)");
const motionScreens = shots.filter((s) => s.motion);
if (motionScreens.length) console.log(`\n${motionScreens.length} living screen(s) (data-motion). Record them: node <skill>/scripts/reel.mjs ${path.basename(SRC)}`);
// A script error on the page can leave art undrawn while everything else
// renders: it fails the run, so nobody judges a half-drawn design.
for (const e of [...new Set(A.errors)]) notes.push(`FAIL  page error: ${e.slice(0, 160)}`);
if (A.errors.length) { console.log("\nPage errors:"); for (const e of [...new Set(A.errors)]) console.log("  " + e); }

if (has("--no-scan")) { for (const x of notes) console.log("  " + x); await browser.close(); process.exit(0); }

// ------------------------------------------------------------------ the scan
const report = await page.evaluate(({ small }) => {
  // Copy that marks a screen as written by nobody. FAIL.
  const SLOP = [
    "effortless", "seamless", "unlock your", "unlock the", "unlock premium", "unlock all", "unlock everything", "elevate", "supercharge", "empower", "revolutioni", "reimagine",
    "game-chang", "game chang", "next-level", "next level", "next-gen", "cutting-edge", "state-of-the-art",
    "welcome back", "let's get started", "let’s get started", "your journey", "journey awaits", "embark",
    "lorem", "ipsum", "john doe", "jane doe", "user name", "ai-powered", "powered by ai",
    "all in one place", "all-in-one", "one-stop", "at your fingertips", "take control", "level up", "stay on track",
    "crush your", "smarter way", "like never before", "transform your", "unleash", "harness the", "the power of",
    "dive into", "dive in", "skyrocket", "boost your", "streamline", "say goodbye to", "say hello to",
    "look no further", "whether you're", "whether you’re", "designed to help", "in today's", "in today’s",
    "fast-paced", "ever-evolving", "tailored to you", "tailored just", "curated just", "personalized experience",
    "personalised experience", "made simple", "made easy", "like a pro", "with ease", "take it to the next",
    "experience the", "discover the power", "your ultimate", "the ultimate", "redefine", "elevating",
  ];
  // Words that are not wrong but usually mean the sentence has nothing in it. warn.
  const SOFT = ["amazing", "awesome", "incredible", "powerful", "stunning", "best-in-class", "world-class", "actionable insights",
    "optimize your", "optimise your", "maximize your", "maximise your", "oops", "uh oh", "whoops", "click here", "submit", "learn more", "get started", "simply ", "insights"];

  const parse = (c) => {
    const m = c && c.match(/rgba?\(([^)]+)\)/);
    if (!m) return null;
    const p = m[1].split(/[ ,/]+/).filter(Boolean).map(Number);
    return { r: p[0], g: p[1], b: p[2], a: p[3] ?? 1 };
  };
  const lum = ({ r, g, b }) => {
    const f = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; };
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
  };
  const contrast = (a, b) => { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); };
  const hsl = ({ r, g, b }) => {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b), l = (max + min) / 2;
    if (max === min) return { h: 0, s: 0, l };
    const d = max - min, s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    let h = max === r ? (g - b) / d + (g < b ? 6 : 0) : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
    return { h: h * 60, s, l };
  };
  const blend = (fg, bg) => ({ r: fg.r * fg.a + bg.r * (1 - fg.a), g: fg.g * fg.a + bg.g * (1 - fg.a), b: fg.b * fg.a + bg.b * (1 - fg.a), a: 1 });
  const hex = ({ r, g, b }) => "#" + [r, g, b].map((v) => Math.round(v).toString(16).padStart(2, "0")).join("").toUpperCase();
  // Material 3's baseline scheme: the purple every unthemed Compose app ships.
  const M3_BASELINE = new Set(["#6750A4", "#D0BCFF", "#EADDFF", "#21005D", "#4F378B", "#E8DEF8", "#625B71", "#CCC2DC", "#4A4458", "#7D5260", "#EFB8C8", "#FFD8E4", "#FEF7FF", "#FFFBFE", "#F3EDF7", "#ECE6F0", "#E6E0E9", "#1D1B20", "#49454F", "#79747E", "#CAC4D0", "#141218", "#211F26", "#2B2930", "#381E72"]);
  const isIconFont = (e) => e.classList.contains("ms") || /Material Symbols|Material Icons|Phosphor|SF Symbols/i.test(getComputedStyle(e).fontFamily);
  const isChrome = (e) => e.closest(".ac-status,.ac-island,.ac-camera,.ac-home,.mini,.device,.touch");

  // Hit-testing must see everything, including art drawn with
  // pointer-events: none, or a picture over text would go unnoticed.
  const hit = document.createElement("style");
  hit.textContent = ".screen *, .panel *, .stage * { pointer-events: auto !important; }";
  document.head.append(hit);
  const out = [];
  const surfaces = [...document.querySelectorAll("[data-ac-i]")].filter((s) => s.matches(".screen, .stage, .panel") && !s.hasAttribute("data-ac-skip"));
  for (const screen of surfaces) {
    const type = screen.classList.contains("screen") ? "screen" : screen.classList.contains("stage") ? "stage" : "panel";
    const isScreen = type === "screen";
    // On a small phone, only real screens are judged.
    if (small && (!isScreen || screen.dataset.chrome === "none")) continue;
    const os = screen.dataset.os === "android" ? "android" : "ios";
    const kind = screen.dataset.kind || (type === "panel" ? "panel" : type === "stage" ? "stage" : "");
    const name = screen.dataset.name || type;
    screen.scrollIntoView({ block: "start" });
    const fails = [], warns = [], facts = { os, kind: kind || undefined };
    const sr = screen.getBoundingClientRect();
    const all = [...screen.querySelectorAll("*")].filter((e) => !isChrome(e));
    // Visible means visible at this frame: a cross-fade layer whose parent is
    // at opacity 0 (or hidden) at the data-freeze time is not on screen.
    const visible = (e) => {
      const r = e.getBoundingClientRect(); const cs = getComputedStyle(e);
      if (!(r.width > 0 && r.height > 0 && cs.visibility !== "hidden" && cs.display !== "none" && r.bottom > sr.top && r.top < sr.bottom)) return false;
      for (let a = e; a && a !== screen.parentElement; a = a.parentElement) if (+getComputedStyle(a).opacity <= 0.05) return false;
      return true;
    };
    const ownText = (e) => [...e.childNodes].some((n) => n.nodeType === 3 && n.textContent.trim());

    // Text-bearing elements: own a non-empty direct text node. Icon fonts are
    // icons. Letters drawn as art (data-art: a magnet letter, a giant glyph in
    // an illustration) are graphics: no type scale, no headline, no words,
    // but still seen at 3:1.
    const textElsAll0 = all.filter((e) => ownText(e) && visible(e) && !isIconFont(e));
    // What actually shows: text under an opaque bar or sheet (a list running
    // beneath the navigation bar) is hidden on purpose and judged by nobody;
    // text under a picture is a collision.
    const covered = new Set(), coveredBy = [];
    for (const e of textElsAll0) {
      const rg = document.createRange(); rg.selectNodeContents(e);
      const rects = [...rg.getClientRects()].filter((r) => r.width > 2 && r.height > 2);
      if (!rects.length) continue;
      let hidden = 0, art = null;
      for (const r of rects) {
        const pts = [[r.left + r.width * 0.25, r.top + r.height / 2], [r.left + r.width * 0.75, r.top + r.height / 2]];
        for (const [x, y] of pts) {
          if (x < sr.left || x > sr.right || y < sr.top || y > sr.bottom) continue;
          const shown = (n) => { for (let a = n; a && a !== screen; a = a.parentElement) { const cs = getComputedStyle(a); if (+cs.opacity < 0.05 || cs.visibility === "hidden") return false; } return true; };
          const top = document.elementsFromPoint(x, y).find((n) => !isChrome(n) && screen.contains(n) && shown(n));
          if (!top || top === e || e.contains(top) || top.contains(e)) continue;
          // Under the floating layer (a tab bar, a toolbar, glass) is
          // content scrolling beneath it: hidden on purpose.
          if (top.closest("[data-float],[data-system],.glass,.glass-dark") && !e.closest("[data-float],[data-system],.glass,.glass-dark")) { hidden++; continue; }
          if (e.closest("[data-behind]")) { hidden++; continue; }
          if (top.matches("img,svg,canvas,video,picture") || top.closest("svg")) { art = top; continue; }
          // Anything else on top of text (a button, a card) is a collision.
          art = top;
        }
      }
      if (hidden >= rects.length * 2) covered.add(e);
      else if (art && !e.closest("[data-behind]")) coveredBy.push(`"${e.textContent.trim().slice(0, 26)}" under ${art.closest("svg") ? "an SVG" : (art.matches("img,canvas,video,picture") ? art.tagName.toLowerCase() : `a ${art.tagName.toLowerCase()}${art.className && typeof art.className === "string" ? "." + art.className.split(" ")[0] : ""}`)}`);
    }
    const textElsAll = textElsAll0.filter((e) => !covered.has(e));
    const artEls = textElsAll.filter((e) => e.closest("[data-art]"));
    const textEls = textElsAll.filter((e) => !e.closest("[data-system],[data-art]"));
    const text = textEls.map((e) => [...e.childNodes].filter((n) => n.nodeType === 3).map((n) => n.textContent).join(" ")).join(" \n ");

    // Effective solid background behind an element (null if an image/gradient is in the way).
    const bgOf = (el) => {
      let layers = [];
      for (let n = el; n; n = n.parentElement) {
        const cs = getComputedStyle(n);
        if (cs.backgroundImage && cs.backgroundImage !== "none") return null;
        const c = parse(cs.backgroundColor);
        if (c && c.a > 0) { layers.push(c); if (c.a >= 0.99) break; }
        if (n === screen) break;
      }
      let base = { r: 255, g: 255, b: 255, a: 1 };
      for (let i = layers.length - 1; i >= 0; i--) base = blend(layers[i], base);
      return base;
    };

    // ---------------------------------------------------------- Typography
    const fams = new Map(), sizes = new Map(), weights = new Set();
    let tiny = [], lowContrast = [], centered = 0, blocks = 0, edge = [], overImage = [];
    const pxJobs = [], pxBase = out.length * 1000;
    for (const e of [...textEls, ...artEls]) {
      const cs = getComputedStyle(e);
      const isArt = artEls.includes(e);
      const fam = cs.fontFamily.split(",")[0].replace(/["']/g, "").trim();
      const px = parseFloat(cs.fontSize);
      if (!isArt) {
        fams.set(fam, (fams.get(fam) || 0) + 1);
        if (!e.closest("sup,sub")) sizes.set(px, (sizes.get(px) || 0) + 1);
        weights.add(cs.fontWeight);
      }
      const t = e.textContent.trim().slice(0, 40);
      if (px < 11 && !isArt && !e.closest("[data-system]")) tiny.push(`${px}px "${t}"`);
      // SVG text is painted by fill, not color.
      const fg = e instanceof SVGElement && parse(cs.fill) ? parse(cs.fill) : parse(cs.color);
      let bg = bgOf(e);
      // An image, an SVG or a gradient between this text and its solid
      // ground: then the solid ground is not what the eye sees.
      if (bg) {
        const r0 = e.getBoundingClientRect();
        const stack = document.elementsFromPoint(r0.left + Math.min(r0.width / 2, 40), r0.top + r0.height / 2);
        const at = stack.indexOf(e);
        for (const n of stack.slice(at + 1)) {
          // An ancestor is the ground only if it paints one: a transparent
          // wrapper over a sibling picture must not end the search.
          if (n.contains(e)) {
            if (getComputedStyle(n).backgroundImage !== "none") { bg = null; overImage.push(`"${t}"`); const id = String(pxJobs.length + pxBase); e.setAttribute("data-ac-px", id); if (fg) pxJobs.push({ id, t, fg, need: isArt ? 3 : px >= 24 || (px >= 18.6 && +cs.fontWeight >= 600) ? 3 : 4.5 }); break; }
            if ((parse(getComputedStyle(n).backgroundColor)?.a || 0) > 0.95) break;
            continue;
          }
          if (n.matches("img,svg,canvas,video,picture") || n.closest("svg") || getComputedStyle(n).backgroundImage !== "none") {
            bg = null; overImage.push(`"${t}"`);
            const id = String(pxJobs.length + pxBase);
            e.setAttribute("data-ac-px", id);
            const large = isArt || px >= 24 || (px >= 18.6 && +cs.fontWeight >= 600);
            if (fg) pxJobs.push({ id, t, fg, need: large ? 3 : 4.5 });
            break;
          }
          if ((parse(getComputedStyle(n).backgroundColor)?.a || 0) > 0.95) break;
        }
      }
      if (fg && bg) {
        const ratio = contrast(blend(fg, bg), bg);
        const large = isArt || px >= 24 || (px >= 18.6 && +cs.fontWeight >= 600);
        if (ratio < (large ? 3 : 4.5)) lowContrast.push(`${ratio.toFixed(2)}:1 ${px}px "${t}"${isArt ? " (art, 3:1)" : ""}`);
      }
      if (isArt) continue;
      if (e.textContent.trim().length > 24) { blocks++; if (cs.textAlign === "center") centered++; }
      if (isScreen && !e.closest("[data-bleed]")) {
        const rg = document.createRange(); rg.selectNodeContents(e);
        for (const r of rg.getClientRects()) {
          if (r.width < 1) continue;
          const inset = Math.min(r.left - sr.left, sr.right - r.right);
          if (inset >= 0 && inset < 12) { edge.push(`${Math.round(inset)}px "${t}"`); break; }
        }
      }
    }
    facts.fonts = Object.fromEntries(fams);
    facts.sizes = [...sizes.keys()].sort((a, b) => b - a);
    facts.weights = [...weights].sort();
    const platformFace = os === "android" ? /^(Roboto Flex|Google Sans Flex|Google Sans|-apple-system|system-ui)/i : /^(-apple-system|system-ui|SF Pro)/i;
    const famList = [...fams.keys()].filter((f) => !platformFace.test(f) && !/^(SF Pro|-apple-system|system-ui)$/i.test(f));
    if (famList.length > 2) fails.push(`More than two type families in content: ${famList.join(", ")}`);
    const reach = [...fams.keys()].filter((f) => /^(Inter|Poppins|Montserrat|Manrope|Plus Jakarta Sans|DM Sans|Nunito|Outfit)$/i.test(f));
    if (reach.length) warns.push(`Default-reach font in use (${reach.join(", ")}). Defend it or replace it.`);
    if (os === "android" && fams.has("Roboto")) warns.push("Plain Roboto: Android's Inter. Roboto Flex with a chosen width and grade, Google Sans Flex, or a face with a reason.");
    if (sizes.size > 8) warns.push(`${sizes.size} distinct text sizes. A type scale has 5 to 7 steps: ${facts.sizes.join(", ")}`);
    if (isScreen && sizes.size <= 3 && textEls.length > 8) warns.push(`Only ${sizes.size} text sizes across ${textEls.length} text elements. Hierarchy is flat.`);
    const maxPx = Math.max(0, ...sizes.keys());
    if (isScreen && textEls.length > 6 && maxPx < 26 && !screen.hasAttribute("data-dense")) warns.push(`Largest text is ${maxPx}px. No element owns the screen. (Mark data-dense if this is deliberate.)`);
    if (tiny.length) fails.push(`Text below 11pt (the floor on both platforms): ${tiny.slice(0, 4).join("; ")}`);
    if (coveredBy.length) fails.push(`Something sits on top of text: ${coveredBy.slice(0, 3).join("; ")}. Move one; mark a floating bar data-float, or the view under a sheet data-behind.`);
    // The kit must have run, and icon fonts must have loaded.
    if (isScreen && screen.dataset.chrome !== "none" && !screen.querySelector(":scope > .ac-status")) fails.push("No status bar: device.js did not run on this page (check its <script> tag, and the page errors above).");
    const rawIcons = [...screen.querySelectorAll(".ms")].filter((m) => visible(m) && m.getBoundingClientRect().width > parseFloat(getComputedStyle(m).fontSize) * 1.6);
    if (rawIcons.length) fails.push(`Material Symbols showing as words (${rawIcons.slice(0, 3).map((m) => `"${m.textContent.trim()}"`).join(", ")}): the icon font did not load. Use the .ms classes (device.css), not your own font-family.`);
    if (lowContrast.length) fails.push(`Contrast below WCAG on solid ground: ${lowContrast.slice(0, 5).join("; ")}`);
    if (isScreen && screen.dataset.chrome !== "none") {
      const top = os === "android" ? 44 : 52, bottom = os === "android" ? 12 : 16;
      const under = [];
      for (const e of textEls) {
        if (e.closest("[data-bleed]")) continue;
        const r = e.getBoundingClientRect();
        if (r.top < sr.top + top && r.bottom > sr.top + 8) under.push(`"${e.textContent.trim().slice(0, 24)}" (status bar)`);
        if (r.bottom > sr.bottom - bottom) under.push(`"${e.textContent.trim().slice(0, 24)}" (${os === "android" ? "gesture handle" : "home indicator"})`);
      }
      if (under.length) warns.push(`Text inside the system's safe areas: ${under.slice(0, 3).join("; ")}`);
    }
    if (blocks >= 4 && centered / blocks > 0.6 && type !== "panel") warns.push(`${centered}/${blocks} text blocks centred. Centred everything reads as a template.`);
    if (edge.length) warns.push(`Text within 12pt of the screen edge: ${edge.slice(0, 3).join("; ")}`);

    // ------------------------------------- Clipping and collisions
    const clipped = [], overlaps = [], offscreen = [], crowded = [], stacked = [];
    const boxes = [];
    const lineCount = new Map();
    for (const e of textElsAll) {
      const cs = getComputedStyle(e);
      const t = e.textContent.trim().slice(0, 30);
      if ((cs.overflow !== "visible" || cs.overflowX !== "visible") && !e.closest("[data-roll],[data-art]")) {
        if (e.scrollWidth > e.clientWidth + 1 && cs.textOverflow !== "ellipsis") clipped.push(`"${t}"`);
        if (e.scrollHeight > e.clientHeight + 2 && !cs.webkitLineClamp?.match(/\d/)) clipped.push(`"${t}" (height)`);
      }
      const tops = new Set();
      for (const nd of e.childNodes) {
        if (nd.nodeType !== 3 || !nd.textContent.trim()) continue;
        const rg = document.createRange(); rg.selectNodeContents(nd);
        const fs = parseFloat(cs.fontSize);
        for (const lr of rg.getClientRects()) {
          if (lr.width < 1) continue;
          tops.add(Math.round(lr.top));
          // The ink, not the line box: caps and figures sit about 0.98em
          // above the line box's bottom edge, descenders end near it.
          // The ink, not the line box, measured from the baseline (about
          // 0.21em above the box's bottom): caps and figures rise ~0.72em,
          // descenders drop ~0.2em, and only text that has them gets them.
          const str = nd.textContent;
          const base = lr.bottom - 0.21 * fs;
          const inkTop = Math.max(lr.top, base - (/[A-Z0-9bdfhklt'"°!?\/\\[\](){}#%&@$€£]/.test(str) ? 0.74 : 0.53) * fs);
          const inkBottom = Math.min(lr.bottom, base + (/[gjpqyQ,;(){}\[\]|\/]/.test(str) ? 0.2 : 0.02) * fs);
          const r = { left: lr.left, right: lr.right, top: inkTop, bottom: inkBottom, width: lr.width, height: inkBottom - inkTop };
          // A line scrolled out of its own scroll view, or cut off by a
          // container on purpose, is not on the screen: skip it.
          let out = false;
          for (let a = e.parentElement; a && a !== screen; a = a.parentElement) {
            const acs = getComputedStyle(a);
            if (acs.overflow === "visible" && acs.overflowX === "visible") continue;
            const ar = a.getBoundingClientRect();
            if (r.right <= ar.left + 1 || r.left >= ar.right - 1 || r.bottom <= ar.top + 1 || r.top >= ar.bottom - 1) out = true;
            break;
          }
          if (out) continue;
          boxes.push({ e, r, t });
          if ((r.left < sr.left - 1 || r.right > sr.right + 1) && !e.closest("[data-bleed],[data-scrolls]")) offscreen.push(`"${t}"`);
        }
      }
      lineCount.set(e, tops.size);
    }
    for (const b of boxes) {
      for (let nd = b.e.parentElement; nd && nd !== screen; nd = nd.parentElement) {
        const cs = getComputedStyle(nd);
        if (cs.overflow === "visible" && cs.overflowX === "visible") continue;
        if (nd.hasAttribute("data-scrolls") || nd.hasAttribute("data-roll") || nd.closest("[data-art]")) break; // a scroll view, a rolling number, art: cut on purpose
        const pr = nd.getBoundingClientRect();
        if (b.r.right > pr.right + 1 || b.r.left < pr.left - 1 || b.r.bottom > pr.bottom + 2) clipped.push(`"${b.t}" cut by its container`);
        break;
      }
    }
    for (let i = 0; i < boxes.length; i++) for (let j = i + 1; j < boxes.length; j++) {
      const a = boxes[i], b = boxes[j];
      if (a.e === b.e || a.e.contains(b.e) || b.e.contains(a.e)) continue;
      // Content scrolling under the floating layer is the platform, not a collision.
      const floats = (x) => x.e.closest(".glass,.glass-dark,[data-system],[data-float]");
      if (!floats(a) !== !floats(b)) continue;
      if (a.e.closest("[data-behind]") || b.e.closest("[data-behind]")) continue;
      const ox = Math.min(a.r.right, b.r.right) - Math.max(a.r.left, b.r.left);
      const oy = Math.min(a.r.bottom, b.r.bottom) - Math.max(a.r.top, b.r.top);
      if (ox > 2 && oy > Math.min(a.r.height, b.r.height) * 0.35) overlaps.push(`"${a.t}" / "${b.t}"`);
      else if (oy > Math.min(a.r.height, b.r.height) * 0.6 && ox > -3 && ox <= 2) crowded.push(`"${a.t}" / "${b.t}"`);
      else if (ox > 4 && oy > -2 && oy <= Math.min(a.r.height, b.r.height) * 0.35) stacked.push(`"${a.t}" / "${b.t}"`);
    }
    if (clipped.length) fails.push(`Text clipped: ${[...new Set(clipped)].slice(0, 4).join("; ")}`);
    if (overlaps.length) fails.push(`Text overlapping text: ${[...new Set(overlaps)].slice(0, 4).join("; ")}`);
    if (stacked.length) warns.push(`Lines of text touching vertically (ink under 2pt apart): ${[...new Set(stacked)].slice(0, 3).join("; ")}`);
    if (crowded.length) fails.push(`Text touching text (under 3pt apart): ${[...new Set(crowded)].slice(0, 4).join("; ")}`);
    if (offscreen.length) fails.push(`Text running off the ${type} (mark data-bleed if deliberate): ${[...new Set(offscreen)].slice(0, 3).join("; ")}`);
    if (isScreen) {
      const lefts = new Set(textEls.filter((e) => e.textContent.trim().length > 2 && !getComputedStyle(e).display.startsWith("inline")).map((e) => Math.round((e.getBoundingClientRect().left - sr.left) / 3) * 3).filter((x) => x > 0 && x < 140));
      facts.leftEdges = lefts.size;
      if (lefts.size > 5 && !screen.hasAttribute("data-dense")) warns.push(`${lefts.size} distinct left edges in the left third. Align to fewer verticals.`);
    }

    // ---------------------------------------------------------------- Copy
    // The words a person reads, in order: no chrome, no icon ligatures, no
    // user content. Legal small print is counted apart.
    const skip = (p) => isChrome(p) || isIconFont(p) || p.closest("[data-ugc],script,style");
    const nodes = [];
    for (const w = document.createTreeWalker(screen, NodeFilter.SHOW_TEXT); w.nextNode();) {
      const nd = w.currentNode, p = nd.parentElement;
      if (!nd.textContent.trim() || !p || skip(p) || !visible(p)) continue;
      nodes.push(nd);
    }
    const flowOf = (list) => list.map((nd) => nd.textContent).join(" ").replace(/\s+/g, " ").trim();
    const flowAll = flowOf(nodes);
    const flow = flowOf(nodes.filter((nd) => !nd.parentElement.closest("[data-legal]")));
    const words = (s) => s.split(/\s+/).filter((w) => /[\p{L}\p{N}]/u.test(w)).length;
    facts.words = words(flow);
    const lower = flow.toLowerCase();
    const emoji = text.match(/\p{Extended_Pictographic}/gu);
    if (emoji) fails.push(`Emoji in UI copy or as icons: ${[...new Set(emoji)].join(" ")}`);
    const hits = SLOP.filter((w) => lower.includes(w));
    if (hits.length) fails.push(`Slop copy: ${hits.map((h) => `"${h}"`).join(", ")}. Say the specific thing (copy.md).`);
    const soft = SOFT.filter((w) => lower.includes(w));
    if (soft.length) warns.push(`Empty words: ${soft.map((h) => `"${h.trim()}"`).join(", ")}. Replace each with the fact it stands for.`);
    if (/\bnot (just|only|simply) (a|an|another|your)\b[^.]{0,60}\b(it'?s|it’s|it is|but)\b/i.test(flow) || /\bmore than (just )?(a|an) \w+/i.test(flow))
      fails.push(`"Not just X, it's Y": the most recognisable AI sentence. Say what it is.`);
    if (/\u2014/.test(flow)) fails.push("Em dash in visible copy. It is the punctuation people now read as AI. Use a full stop, a colon or a comma.");
    if (/\s\u2013\s/.test(flow)) warns.push("Spaced en dash used as a dash. A full stop or a colon reads cleaner.");
    const bangs = (flow.match(/!/g) || []).length;
    if (bangs > 1) fails.push(`${bangs} exclamation marks. The UI is shouting.`);
    else if (bangs === 1) warns.push("An exclamation mark. Is this the one moment that earns it?");
    const greet = textEls.find((e) => /^(good (morning|afternoon|evening|night)|hi|hey|hello|welcome)\b/i.test(e.textContent.trim()) && e.getBoundingClientRect().top - sr.top < 260);
    if (isScreen && greet) fails.push(`Greeting at the top of the screen: "${greet.textContent.trim().slice(0, 40)}". Spend that space on the thing itself.`);
    // Title Case and long sentences, per block of text.
    const copyBlocks = textEls.filter((e) => !skip(e) && !e.closest("[data-legal]"));
    const titleCase = [], longSentences = [], walls = [];
    for (const e of copyBlocks) {
      const t = (e.innerText ?? e.textContent).replace(/\s+/g, " ").trim();
      const caps = getComputedStyle(e).textTransform === "uppercase" || t === t.toUpperCase();
      const long = t.split(" ").filter((w) => /^[\p{L}]{4,}/u.test(w));
      if (!caps && long.length >= 3 && long.every((w) => /^\p{Lu}/u.test(w)) && !e.closest("[data-proper]") && !e.querySelector("[data-proper]")) titleCase.push(`"${t.slice(0, 36)}"`);
      for (const s of t.split(/(?<=[.?!])\s+/)) if (words(s) > 24) longSentences.push(`"${s.slice(0, 40)}..." (${words(s)} words)`);
      const lines = lineCount.get(e) || 0;
      if (lines >= (["onboarding", "paywall", "panel", "stage"].includes(kind) ? 4 : 6) && !screen.hasAttribute("data-dense")) walls.push(`"${t.slice(0, 30)}" (${lines} lines)`);
    }
    if (titleCase.length) warns.push(`Title Case: ${titleCase.slice(0, 3).join("; ")}. Sentence case reads as a person (mark data-proper on real names).`);
    if (longSentences.length) warns.push(`Sentences over 24 words: ${longSentences.slice(0, 2).join("; ")}. Nobody reads them on a phone.`);
    if (walls.length) warns.push(`Paragraphs too long for this ${kind || type}: ${walls.slice(0, 2).join("; ")}.`);
    const proof = flowAll.match(/(#1\b|number one|\b\d[\d,.]*\s?(k|m|million|thousand)?\+?\s+(happy )?(users|people|customers|downloads|reviews|members)\b|rated \d|\b4\.\d\s?(stars?|★)|★{3,})/i);
    if (proof) warns.push(`Proof claim "${proof[0]}". Only if it is true and you can show where it comes from; never invented (copy.md).`);

    // The headline: the biggest words on the surface.
    const headEl = copyBlocks.slice().sort((a, b) => parseFloat(getComputedStyle(b).fontSize) - parseFloat(getComputedStyle(a).fontSize))[0];
    const head = headEl ? (headEl.innerText ?? headEl.textContent).replace(/\s+/g, " ").trim() : "";
    const headPx = headEl ? parseFloat(getComputedStyle(headEl).fontSize) : 0;
    const headLines = headEl ? lineCount.get(headEl) || 1 : 0;
    if (headEl) facts.headline = `${headPx}px, ${words(head)} words, ${headLines} line(s)`;
    if (/^[^,.]{2,30}, [^,.]{2,30},? (and|&|or) [^,.]{2,30}\.?$/i.test(head)) warns.push(`The headline is a list of three ("${head.slice(0, 50)}"). A three-beat list is the rhythm people now hear as AI. Say one thing.`);

    // Budgets by job. Onboarding and paywalls convert on few words, big.
    const budget = { onboarding: [45, 70, 10], paywall: [90, 130, 10], panel: [16, 26, 9], stage: [24, 40, 10] }[kind];
    if (budget) {
      const [soft2, hard, headMax] = budget;
      if (facts.words > hard) fails.push(`${facts.words} words on a ${kind} (budget ${soft2}, hard limit ${hard}, legal print not counted). Cut until every line earns its place.`);
      else if (facts.words > soft2) warns.push(`${facts.words} words on a ${kind} (budget ${soft2}). Cut a line.`);
      if (words(head) > headMax) warns.push(`Headline is ${words(head)} words ("${head.slice(0, 40)}"). ${headMax} at most; 3 to 7 is where headlines land.`);
      if (headLines > 3) warns.push(`Headline runs ${headLines} lines. Two, three at most: cut words, never shrink the type.`);
    }
    if (kind === "onboarding" || kind === "paywall") {
      if (headPx && headPx < 26) warns.push(`Headline is ${headPx}px on a ${kind}. The promise is the hero: 28px and up.`);
      // Text coverage: how much of the screen is words.
      let ink = 0;
      for (const b of boxes) if (!b.e.closest("[data-legal]") && !skip(b.e)) ink += b.r.width * b.r.height;
      const cover = ink / (sr.width * sr.height);
      facts.textCoverage = +cover.toFixed(2);
      if (cover > 0.2) warns.push(`Words cover ${Math.round(cover * 100)}% of the screen. A ${kind} that converts is mostly one promise and one button.`);
      // The primary action.
      const ctas = [...screen.querySelectorAll("[data-cta], button, [role=button], a")].filter((e) => !isChrome(e) && visible(e));
      const filled = (e) => { const c = parse(getComputedStyle(e).backgroundColor); return c && c.a > 0.8; };
      const cta = screen.querySelector("[data-cta]") || ctas.filter(filled).sort((a, b) => { const x = a.getBoundingClientRect(), y = b.getBoundingClientRect(); return y.width * y.height - x.width * x.height; })[0];
      if (!cta) warns.push(`No primary button found on the ${kind}. Mark it data-cta.`);
      else {
        const r = cta.getBoundingClientRect();
        const label = (cta.innerText ?? cta.textContent).replace(/\s+/g, " ").trim();
        facts.cta = `"${label}" ${Math.round(r.height)}pt`;
        if (r.height < 44) fails.push(`Primary button is ${Math.round(r.height)}pt tall. 50 to 56 on a ${kind}.`);
        if (r.top - sr.top < sr.height * 0.55) warns.push(`Primary button sits in the top half. Put it where the thumb is: the bottom third.`);
        if (words(label) > 5) warns.push(`Button label is ${words(label)} words ("${label}"). Two to four.`);
        if (/^(submit|ok|okay|click here|next)$/i.test(label)) warns.push(`Button says "${label}". Say what happens: "Start my plan", "Try 7 days free".`);
      }
    }
    if (kind === "paywall") {
      const price = /([$€£¥₹]\s?\d|\d[\d.,]*\s?(€|\$|£|kr|zł|CHF|USD|EUR|GBP))/i.test(flowAll);
      const period = /\b(year|yearly|annual|annually|month|monthly|week|weekly|lifetime|one-time|once)\b|\/\s?(yr|mo|wk|y|m)\b/i.test(flowAll);
      if (!price || !period) fails.push(`The price and its period are not both on the paywall (${price ? "no period" : "no price"}). Apple 3.1.2 and Play both want the full price, the period, and what happens after a trial, right by the button.`);
      if (/\b(free|trial)\b/i.test(flowAll) && !/\b(then|after|afterwards|renews|billed)\b/i.test(flowAll)) fails.push("A free trial without what it costs after. Write \"Free for 7 days, then €39.99 a year\".");
      if (os === "ios" && !/restore/i.test(flowAll)) fails.push("No Restore Purchases on an iOS paywall. App Review asks for it.");
      if (!/terms|privacy/i.test(flowAll)) warns.push("No Terms or Privacy link on the paywall. Both stores expect them.");
      const close = screen.querySelector("[data-close],[aria-label*='lose' i],[aria-label*='ismiss' i]") || /\b(not now|maybe later|skip|continue with free|use the free)\b/i.test(flowAll);
      if (!close) warns.push("No way out of the paywall (data-close on the X, or \"Not now\"). A hard paywall is a decision: write it in DIRECTION.md.");
      const urgency = flowAll.match(/(offer ends|ends in|only \d+ (left|spots|places)|last chance|limited time|hurry|expires in|\b\d{1,2}:\d{2}:\d{2}\b)/i);
      if (urgency && !screen.querySelector("[data-real]")) fails.push(`Fake urgency: "${urgency[0]}". If the deadline is real, mark it data-real and say where it comes from.`);
      const save = flowAll.match(/save\s+(\d{1,2})\s?%/i);
      if (save) facts.saveClaim = save[0];
    }
    if (type === "panel" && headEl) {
      const ratio = headPx / sr.width;
      if (screen.dataset.store !== "feature" && ratio < 0.046) warns.push(`Caption is ${headPx}px on a ${Math.round(sr.width)}px panel: it will not read in search results. ${Math.ceil(sr.width * 0.05)}px and up.`);
    }

    // ------------------------------------- Colour, gradients, shadows, cards
    const accents = new Map(), baseline = new Set();
    const gradStyles = new Set(), shadowStyles = new Set();
    let gradients = 0, purpleGrad = 0, aura = 0, glows = 0, shadows = 0, cards = [], chips = 0, blurBlobs = 0, glass = 0;
    for (const e of all) {
      if (!visible(e)) continue;
      const cs = getComputedStyle(e);
      if (e.closest("[data-system]")) continue;
      // Colours inside a drawing (an SVG larger than an icon, or data-art)
      // belong to the picture, not to the UI's accent budget.
      const inArt = e instanceof SVGElement && (e.closest("[data-art]") || (() => { const sv = e.closest("svg"); const rr = sv && sv.getBoundingClientRect(); return rr && rr.width > 64 && rr.height > 64; })());
      for (const prop of ["color", "backgroundColor", "borderTopColor", "fill", "stroke"]) {
        if ((prop === "fill" || prop === "stroke") && !(e instanceof SVGElement)) continue;
        if (inArt) continue;
        const c = parse(cs[prop]);
        if (!c || c.a < 0.5) continue;
        if (prop === "borderTopColor" && parseFloat(cs.borderTopWidth) === 0) continue;
        if (prop === "color" && !ownText(e) && !isIconFont(e) && !(e instanceof SVGElement)) continue;
        if (M3_BASELINE.has(hex(c))) baseline.add(hex(c));
        const { h, s, l } = hsl(c);
        if (s > 0.38 && l > 0.15 && l < 0.85) { const k = Math.round(h / 24) * 24 % 360; accents.set(k, (accents.get(k) || 0) + 1); }
      }
      const bi = cs.backgroundImage;
      const r0g = e.getBoundingClientRect();
      if (bi && bi.includes("gradient")) {
        gradients++;
        // The AI gradient is blue-indigo-violet. A warm-to-violet "aura" on
        // one hero object is a designer's move; on every card it is slop again.
        const sat = [...bi.matchAll(/rgba?\([^)]+\)/g)].map((m) => parse(m[0])).filter(Boolean).map(hsl).filter((x) => x.s > 0.35 && x.l > 0.12 && x.l < 0.9);
        gradStyles.add(bi);
        const big = r0g.width * r0g.height > 120 * 80 || e.matches("button,[role=button],[data-cta]");
        if (sat.some((x) => x.h >= 235 && x.h <= 295) && big) {
          if (sat.every((x) => x.h >= 195 && x.h <= 305)) purpleGrad++;
          else aura++;
        }
      }
      const r = e.getBoundingClientRect();
      if (/blur\((\d{2,})/.test(cs.filter) && r.width > 80) blurBlobs++;
      if (cs.backdropFilter && cs.backdropFilter !== "none") glass++;
      if (cs.boxShadow !== "none") {
        if (cs.boxShadow.split(/,(?![^(]*\))/).some((sh) => !/inset/.test(sh))) { shadows++; shadowStyles.add(cs.boxShadow.replace(/rgba?\([^)]+\)/g, "c")); }
        for (const sh of cs.boxShadow.split(/,(?![^(]*\))/)) {
          const c = parse(sh); const nums = sh.replace(/rgba?\([^)]+\)/, "").trim().split(/\s+/).map(parseFloat);
          if (c && !/inset/.test(sh) && Math.abs(nums[0]) < 1 && Math.abs(nums[1]) < 1 && (nums[2] || 0) > 8 && hsl(c).s > 0.4) glows++;
        }
      }
      const radius = parseFloat(cs.borderTopLeftRadius);
      const filled = (parse(cs.backgroundColor)?.a || 0) > 0.05 || cs.boxShadow !== "none" || parseFloat(cs.borderTopWidth) > 0;
      if (radius >= 10 && filled && r.width > 120 && r.height > 56) cards.push(e);
      if (r.width >= 26 && r.width <= 48 && Math.abs(r.width - r.height) < 2 && radius >= 6 && radius < r.width / 2 - 1 && filled && e.querySelector("svg,img,i,span"))
        chips++;
    }
    const hues = [...accents.keys()];
    facts.accentHues = hues;
    if (screen.dataset.palette === "identity") {
      // An identity palette: each hue owned by one thing (a habit, a mode),
      // listed in DIRECTION.md. More than seven is no longer a system.
      if (hues.length > 7) fails.push(`${hues.length} saturated hue families even for an identity palette. Six owners at most on one screen.`);
      else if (hues.length > 3) facts.identity = hues.length;
    } else if (hues.length > 3) fails.push(`${hues.length} saturated hue families (${hues.join("°, ")}°). One accent, maybe one semantic colour. This is confetti. (If each hue belongs to one item, mark the screen data-palette="identity" and list the owners in DIRECTION.md.)`);
    else if (hues.length === 3) warns.push(`Three saturated hue families (${hues.join("°, ")}°). Is each one earning its place?`);
    if (baseline.size >= 3) fails.push(`Material 3 baseline colours (${[...baseline].slice(0, 4).join(" ")}): the unthemed Compose purple, Android's indigo gradient. Build the scheme from your own seed.`);
    if (purpleGrad) fails.push(`Blue/indigo/violet gradient x${purpleGrad}. The single most recognisable AI tell.`);
    if (aura > 1) fails.push(`${aura} warm-to-violet gradients. One hero object may glow like that; several is the purple gradient again.`);
    else if (aura === 1) warns.push("A warm-to-violet gradient. Fine on one hero object (a trophy, a milestone); never on buttons or chrome.");
    if (gradStyles.size > 5) warns.push(`${gradStyles.size} different gradients. A crafted gradient has an owner and a role (finish.md §2); this many reads as decoration.`);
    if (glows) fails.push(`Coloured zero-offset glow shadow x${glows}.`);
    if (blurBlobs) fails.push(`Large blurred blob x${blurBlobs}. Ambient orbs behind content are a slop signature.`);
    if (isScreen && os === "android" && glass) warns.push(`Frosted glass x${glass} on an Android screen. Android's navigation layer is tonal surfaces, not Liquid Glass (android.md §3).`);
    if (isScreen && chips >= 3) warns.push(`${chips} icon-in-tinted-square chips. If every row has one, none of them mean anything.`);

    // Icons speak the platform.
    if (isScreen) {
      const sets = new Set();
      for (const e of all) {
        if (!visible(e)) continue;
        if (e.classList.contains("ms") || /Material Symbols|Material Icons/i.test(getComputedStyle(e).fontFamily)) sets.add("material");
        else if (/Phosphor/i.test(getComputedStyle(e).fontFamily) || /^ph(-|$)/.test(e.classList[0] || "")) sets.add("phosphor");
      }
      if (os === "ios" && sets.has("material")) warns.push("Material Symbols on an iPhone screen. iOS speaks SF Symbols: draw SF-style glyphs (imagery.md §1).");
      if (os === "android" && sets.has("phosphor") && !sets.has("material")) warns.push("Phosphor icons on Android. Material Symbols is the native set, with weight and fill that follow the text.");
      if (os === "android" && textEls.some((e) => /^(‹|<)?\s?back$/i.test(e.textContent.trim()))) warns.push(`A "Back" text button on Android. Android goes back with the arrow and the system gesture.`);
    }

    // The floating "+" in the middle of the bottom bar: wrong on both
    // platforms. A FAB at the bottom right is native Android and fine.
    if (isScreen) for (const e of all) {
      if (!visible(e)) continue;
      const r = e.getBoundingClientRect(), cs = getComputedStyle(e);
      const bg = parse(cs.backgroundColor);
      if (r.width >= 44 && r.width <= 72 && Math.abs(r.width - r.height) < 2 && parseFloat(cs.borderTopLeftRadius) >= r.width / 2 - 1
        && bg && bg.a > 0.8 && hsl(bg).s > 0.35 && sr.bottom - r.bottom < 140 && Math.abs((r.left + r.right) / 2 - (sr.left + sr.right) / 2) < 30) {
        fails.push("Centred floating action button over the tab bar. Put the primary action where the content is."); break;
      }
    }
    let nested = 0;
    for (const c of cards) if (cards.some((o) => o !== c && o.contains(c))) nested++;
    facts.cards = cards.length;
    if (nested >= 2) fails.push(`Cards nested inside cards x${nested}. Group with space, not boxes.`);
    if (isScreen && cards.length >= 8 && !screen.hasAttribute("data-dense")) warns.push(`${cards.length} card containers on one screen. Fine if they are one collection of objects; sections should be space and hairlines (finish.md §3).`);
    if (shadowStyles.size > 4) warns.push(`${shadowStyles.size} different shadow styles. Depth has three levels with one shadow style each (finish.md §4).`);

    // Touch targets: 44pt on iOS, 48dp on Android.
    if (isScreen) {
      const min = os === "android" ? 48 : 44;
      const smallTargets = [];
      for (const e of screen.querySelectorAll("button,a,[role=button],[data-tap],input,select")) {
        if (isChrome(e) || !visible(e)) continue;
        const r = e.getBoundingClientRect();
        if (r.width < min && r.height < min && !e.hasAttribute("data-hit-expanded")) smallTargets.push(`${Math.round(r.width)}x${Math.round(r.height)} "${(e.getAttribute("aria-label") || e.textContent).trim().slice(0, 20)}"`);
      }
      if (smallTargets.length) warns.push(`Tap targets under ${min}${os === "android" ? "dp" : "pt"} (add padding, or data-hit-expanded if the hit area is larger than the drawing): ${smallTargets.slice(0, 4).join("; ")}`);
      if (screen.dataset.motion && !screen.dataset.freeze) warns.push("A living screen without data-freeze: the still shows frame 0. Freeze it on the moment that sells it.");
    }

    out.push({ name, type, fails, warns, facts, pxJobs, chrome: isScreen && screen.dataset.chrome !== "none", idx: screen.getAttribute("data-ac-i") });
  }
  hit.remove();
  return out;
}, { small: SMALL });

// ------------------------------------------------- pixel contrast pass
// Text over an image or an SVG, and the status bar and home indicator over
// whatever the design put under them: hide the ink, photograph what is
// really behind it, and measure against every pixel of that ground.
const measure = async (handle, fg) => {
  const buf = await handle.screenshot({ scale: "css", animations: "allow" });
  return page.evaluate(async ({ b64, fg }) => {
    const img = new Image(); img.src = "data:image/png;base64," + b64; await img.decode();
    const c = document.createElement("canvas"); c.width = img.width; c.height = img.height;
    const x = c.getContext("2d"); x.drawImage(img, 0, 0);
    const d = x.getImageData(0, 0, c.width, c.height).data;
    const L = (r, g, b) => { const f = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; }; return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b); };
    const lf = L(fg.r, fg.g, fg.b), ratios = [];
    for (let i = 0; i < d.length; i += 4) { const lb = L(d[i], d[i + 1], d[i + 2]); ratios.push((Math.max(lf, lb) + 0.05) / (Math.min(lf, lb) + 0.05)); }
    ratios.sort((a, b) => a - b);
    return ratios[Math.floor(ratios.length * 0.12)] || 21;
  }, { b64: buf.toString("base64"), fg });
};
for (const s of report) {
  for (const j of s.pxJobs) {
    const h = await page.$(`[data-ac-px="${j.id}"]`); if (!h) continue;
    await h.evaluate((e) => { e.style.setProperty("color", "transparent", "important"); e.style.setProperty("text-shadow", "none", "important"); });
    const ratio = await measure(h, j.fg);
    await h.evaluate((e) => { e.style.removeProperty("color"); e.style.removeProperty("text-shadow"); });
    if (ratio < j.need) s.fails.push(`Text on an image/illustration fails contrast over part of its ground (${ratio.toFixed(2)}:1, needs ${j.need}): "${j.t}". Add a scrim, move it, or change the ink.`);
  }
  if (!s.chrome) continue;
  const scr = await el(page, s.idx); if (!scr) continue;
  for (const [q, label] of [[".ac-status > span:first-child", "status-bar clock"], [".ac-status .ac-right", "status-bar icons"], [".ac-home", "home indicator / gesture handle"]]) {
    const h = await scr.$(`:scope > ${q}`); if (!h) continue;
    const fg = await h.evaluate((e) => { const c = getComputedStyle(e)[e.classList.contains("ac-home") ? "backgroundColor" : "color"]; const p = c.match(/[\d.]+/g).map(Number); return { r: p[0], g: p[1], b: p[2] }; });
    await h.evaluate((e) => { e.style.setProperty("opacity", "0", "important"); });
    const ratio = await measure(h, fg);
    await h.evaluate((e) => e.style.removeProperty("opacity"));
    if (ratio < 2.2) s.fails.push(`The ${label} is lost on what sits under it (${ratio.toFixed(2)}:1). Use data-chrome="light" / data-home, or change the art under it.`);
  }
}

const ident = report.filter((s) => s.facts.identity);
if (ident.length) notes.push(`warn  identity palette on ${ident.map((s) => s.name).join(", ")}: check every hue belongs to one thing, the same thing on every screen, with neutral chrome (color.md §9).`);
const scaleOf = (os) => [...new Set(report.filter((s) => s.type === "screen" && s.facts.os === os).flatMap((s) => s.facts.sizes || []))].sort((a, b) => b - a);
let failed = 0;
for (const s of report) {
  console.log(`\n── ${s.name}${s.type !== "screen" ? ` (${s.type})` : ""}${s.facts.os === "android" && s.type === "screen" ? " · android" : ""} ─────────────────────────────`);
  const f = s.facts;
  console.log(`  fonts ${JSON.stringify(f.fonts)}  sizes [${f.sizes.join(", ")}]  weights [${f.weights.join(", ")}]  hues [${f.accentHues.join(", ")}]  cards ${f.cards}  words ${f.words}${f.headline ? `  headline ${f.headline}` : ""}${f.cta ? `  cta ${f.cta}` : ""}`);
  for (const x of s.fails) console.log("  FAIL  " + x);
  for (const w of s.warns) console.log("  warn  " + w);
  if (!s.fails.length && !s.warns.length) console.log("  clean");
  failed += s.fails.length;
}
if (notes.length) { console.log("\n── exports ─────────────────────────────"); for (const x of notes) console.log("  " + x); failed += notes.filter((x) => x.startsWith("FAIL")).length; }
for (const os of ["ios", "android"]) {
  const sz = scaleOf(os);
  if (sz.length) console.log(`\n${os === "ios" ? "iPhone" : "Android"} type scale: ${sz.length} sizes [${sz.join(", ")}]${sz.length > 10 ? "  warn: a scale this long is not a scale. Merge sizes a step apart." : ""}`);
}
fs.writeFileSync(path.join(OUT, "scan.json"), JSON.stringify({ surfaces: report.map(({ pxJobs, chrome, idx, ...r }) => r), exports: notes }, null, 2));
console.log(`\n${failed ? failed + " FAIL(s)." : "No FAILs."} The scan only catches mechanical tells. Now read sheet.png, and every 3x PNG, with your own eyes.`);
await browser.close();
process.exit(failed ? 1 : 0);
