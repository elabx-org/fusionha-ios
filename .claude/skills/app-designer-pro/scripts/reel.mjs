#!/usr/bin/env node
/**
 * App Designer Pro reel: record every living screen and moving stage in a
 * mockup to video.
 *
 *   node reel.mjs mockup.html                  every [data-motion] element -> reels/<name>.mp4
 *   node reel.mjs mockup.html --only hero      one of them (its data-name)
 *   node reel.mjs mockup.html --fps 60         smoother, twice the frames (default 30)
 *   node reel.mjs mockup.html --gif            a light GIF beside each MP4
 *   node reel.mjs mockup.html --scale 2 --out reels --keep-frames
 *
 * What comes out (in --out, default ./reels next to the file):
 *   <name>.mp4          H.264, yuv420p, loops cleanly, plays everywhere
 *   <name>.gif          with --gif
 *   <name>-strip.png    six frames across the loop (or the frames listed in data-beats="ms,ms,...")
 *
 * Time is stepped, not played. Every CSS animation, transition and Web
 * Animation is paused and set to the frame's time, and the page clock
 * (timers, requestAnimationFrame) advances in step, so the video is exactly
 * the choreography you wrote, at any frame rate, however heavy the page.
 * Write the loop so its last frame flows into its first: every animation's
 * duration divides data-motion (motion.md §8). The script checks the seam
 * and the dead air.
 *
 * Needs ffmpeg for the MP4 (brew install ffmpeg). Without it the frames are
 * kept as PNGs and the command to encode them is printed.
 */
import fs from "node:fs";
import path from "node:path";
import { execFileSync, spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
let chromium;
for (const base of [process.cwd(), path.join(here, "..")]) {
  try { ({ chromium } = createRequire(path.join(base, "package.json"))("playwright-core")); break; } catch {}
}
if (!chromium) { console.error("playwright-core not found. Run once:\n  npm i playwright-core\nin " + path.join(here, "..")); process.exit(2); }

const argv = process.argv.slice(2);
const arg = (n, d) => { const i = argv.indexOf(n); return i > -1 && argv[i + 1] ? argv[i + 1] : d; };
const has = (n) => argv.includes(n);
const file = argv.find((a) => a.endsWith(".html"));
if (!file) { console.error("usage: node reel.mjs <mockup.html> [--only name] [--fps 30] [--gif] [--scale 2] [--out dir]"); process.exit(2); }
const SRC = path.resolve(file);
const OUT = path.resolve(arg("--out", path.join(path.dirname(SRC), "reels")));
const FPS = parseFloat(arg("--fps", "30"));
const SCALE = parseFloat(arg("--scale", "2"));
const ONLY = arg("--only");
fs.mkdirSync(OUT, { recursive: true });

let ffmpeg = null;
for (const p of [process.env.FFMPEG, "ffmpeg", "/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]) {
  if (!p) continue;
  try { execFileSync(p, ["-version"], { stdio: "ignore" }); ffmpeg = p; break; } catch {}
}

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

// Find the moving things.
const probe = await browser.newPage();
await probe.goto(pathToFileURL(SRC).href, { waitUntil: "load" });
const targets = await probe.evaluate(() =>
  [...document.querySelectorAll("[data-motion]")]
    .filter((e) => e.matches(".screen, .stage, .panel") && !e.parentElement.closest(".device, .mini, .stage, .panel, .screen"))
    .map((e, i) => ({ i, name: e.dataset.name || `motion-${i + 1}`, ms: parseFloat(e.dataset.motion) || 0, type: e.classList.contains("screen") ? "screen" : "stage", beats: (e.dataset.beats || "").split(",").map((x) => x.trim()).filter(Boolean).map(Number).filter((n) => n >= 0) }))
);
await probe.close();
const list = targets.filter((t) => !ONLY || slug(t.name) === slug(ONLY));
if (!list.length) { console.error(ONLY ? `Nothing named "${ONLY}" has data-motion.` : 'Nothing to record. Mark a living screen or a stage with data-motion="<loop length in ms>".'); process.exit(2); }

const results = [];
for (const t of list) {
  if (t.ms < 500 || t.ms > 60000) { console.log(`skip ${t.name}: data-motion="${t.ms}" (a loop is 0.5 to 60 seconds)`); continue; }
  const page = await browser.newPage({ viewport: { width: 1400, height: 1000 }, deviceScaleFactor: SCALE });
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  // Fake timers from the first line of script, so JS-driven motion is
  // stepped with the frames too.
  await page.clock.install({ time: new Date("2026-01-01T09:41:00") });
  await page.goto(pathToFileURL(SRC).href, { waitUntil: "load" });
  await page.waitForLoadState("networkidle");
  await page.evaluate(async () => { await document.fonts.ready; });
  await page.clock.pauseAt(new Date("2026-01-01T09:41:05"));
  const handle = (await page.evaluateHandle((i) =>
    [...document.querySelectorAll("[data-motion]")]
      .filter((e) => e.matches(".screen, .stage, .panel") && !e.parentElement.closest(".device, .mini, .stage, .panel, .screen"))[i] || null, t.i)).asElement();
  if (!handle) { console.log(`skip ${t.name}: not found on reload`); await page.close(); continue; }
  // A recorded screen is a screen recording: square corners, no transparency.
  await handle.evaluate((e) => { if (e.classList.contains("screen")) e.style.setProperty("border-radius", "0", "important"); });
  // Restart every animation at zero.
  await page.evaluate(() => {
    window.__acBorn = new WeakMap();
    for (const a of document.getAnimations()) { a.pause(); a.currentTime = 0; window.__acBorn.set(a, 0); }
  });

  const name = slug(t.name);
  const dir = path.join(OUT, `.frames-${name}`);
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });
  const dt = 1000 / FPS;
  const frames = Math.round(t.ms / dt);
  const t0 = Date.now();
  // One frame past the end, to check the seam against frame 0.
  for (let f = 0; f <= frames; f++) {
    const time = f * dt;
    if (f > 0) await page.clock.runFor(dt);
    await page.evaluate((time) => {
      for (const a of document.getAnimations()) {
        if (!window.__acBorn.has(a)) window.__acBorn.set(a, time - (a.currentTime || 0));
        a.pause();
        a.currentTime = Math.max(0, time - window.__acBorn.get(a));
      }
    }, time);
    await handle.screenshot({ path: path.join(dir, f === frames ? "seam.png" : `${String(f).padStart(5, "0")}.png`) });
    if (f % Math.round(FPS) === 0) process.stdout.write(`\r${t.name}: ${Math.round(time / 1000)}s of ${t.ms / 1000}s`);
  }
  process.stdout.write(`\r${t.name}: ${frames} frames in ${((Date.now() - t0) / 1000).toFixed(1)}s            \n`);

  // The seam is checked by ffmpeg further down, frame 0 against the frame
  // after the last.
  const frameUrl = (f) => pathToFileURL(path.join(dir, `${String(f).padStart(5, "0")}.png`)).href;

  const strip = path.join(OUT, `${name}-strip.png`);
  // The strip shows the beats when the element lists them (data-beats="0,800,1600,3200"),
  // so a short signature moment cannot fall between two evenly spaced frames.
  const picks = t.beats.length
    ? t.beats.slice(0, 8).map((ms) => Math.min(frames - 1, Math.round(ms / dt)))
    : Array.from({ length: 6 }, (_, k) => Math.min(frames - 1, Math.round((k * frames) / 6)));
  const sp = await browser.newPage({ deviceScaleFactor: 1, viewport: { width: 1400, height: 120 } });
  const cellW = t.type === "screen" ? 300 : 360;
  const stripHtml = path.join(OUT, `_${name}-strip.html`);
  fs.writeFileSync(stripHtml, `<!doctype html><body style="margin:0;padding:28px;background:#1b1b1d;display:flex;gap:16px;width:max-content;font:500 12px -apple-system,system-ui;color:#aaa">${picks
    .map((f) => `<figure style="margin:0"><img src="${frameUrl(f)}" style="width:${cellW}px;display:block;border-radius:${t.type === "screen" ? 18 : 6}px"><figcaption style="padding-top:8px;text-align:center">${(f * dt / 1000).toFixed(2)}s</figcaption></figure>`)
    .join("")}</body>`);
  await sp.goto(pathToFileURL(stripHtml).href, { waitUntil: "load" });
  await sp.evaluate(async () => { await Promise.all([...document.images].map((i) => i.decode().catch(() => {}))); });
  await sp.screenshot({ path: strip, fullPage: true });
  await sp.close();
  fs.rmSync(stripHtml, { force: true });

  let mp4 = null, gif = null, check = {};
  if (ffmpeg) {
    // The seam: frame 0 against the frame after the last (SSIM, 1 = identical).
    const ssim = spawnSync(ffmpeg, ["-hide_banner", "-i", path.join(dir, "00000.png"), "-i", path.join(dir, "seam.png"), "-lavfi", "ssim", "-f", "null", "-"], { encoding: "utf8" }).stderr.match(/All:([\d.]+)/);
    check.seam = ssim ? parseFloat(ssim[1]) : null;
    mp4 = path.join(OUT, `${name}.mp4`);
    execFileSync(ffmpeg, ["-y", "-loglevel", "error", "-framerate", String(FPS), "-i", path.join(dir, "%05d.png"),
      "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2", "-c:v", "libx264", "-preset", "slow", "-crf", "16", "-pix_fmt", "yuv420p", "-movflags", "+faststart", mp4]);
    // Dead air: stretches where nothing on screen changes.
    // Read on the lossless frames: any change at all is real motion.
    const fr = spawnSync(ffmpeg, ["-hide_banner", "-framerate", String(FPS), "-i", path.join(dir, "%05d.png"), "-vf", "freezedetect=n=-90dB:d=0.4", "-f", "null", "-"], { encoding: "utf8" }).stderr;
    const stills = [...fr.matchAll(/freeze_duration: ([\d.]+)/g)].map((m) => parseFloat(m[1]));
    const open = fr.match(/freeze_start: ([\d.]+)(?![\s\S]*freeze_end)/);
    if (open) stills.push(t.ms / 1000 - parseFloat(open[1]));
    check.longestStill = Math.max(0, ...stills);
    check.moving = 1 - stills.reduce((a, b) => a + b, 0) / (t.ms / 1000);
    if (has("--gif")) {
      gif = path.join(OUT, `${name}.gif`);
      const gw = t.type === "screen" ? 360 : 540;
      execFileSync(ffmpeg, ["-y", "-loglevel", "error", "-i", mp4, "-vf",
        `fps=${Math.min(FPS, 24)},scale=${gw}:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=200:stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle`, "-loop", "0", gif]);
    }
    if (!has("--keep-frames")) fs.rmSync(dir, { recursive: true, force: true });
  }
  fs.rmSync(path.join(dir, "seam.png"), { force: true });
  results.push({ ...t, mp4, gif, strip, dir, ...check, errors });
  await page.close();
}
await browser.close();

console.log("");
let bad = 0;
for (const r of results) {
  console.log(`── ${r.name} (${r.ms / 1000}s loop, ${FPS}fps) ─────────────`);
  if (r.mp4) console.log(`  ${r.mp4}`); else console.log(`  frames: ${r.dir}\n  ffmpeg not found. brew install ffmpeg, then:\n  ffmpeg -framerate ${FPS} -i "${path.join(r.dir, "%05d.png")}" -c:v libx264 -pix_fmt yuv420p -crf 16 "${path.join(OUT, slug(r.name) + ".mp4")}"`);
  if (r.gif) console.log(`  ${r.gif}`);
  console.log(`  ${r.strip}   (six moments: review motion here)`);
  if (r.seam != null) {
    console.log(`  moving ${Math.round(r.moving * 100)}% of the loop, longest still ${r.longestStill.toFixed(1)}s, seam SSIM ${r.seam.toFixed(4)}`);
    if (r.seam < 0.97) { bad++; console.log(`  FAIL  the loop jumps: the frame after the last is not the first (SSIM ${r.seam.toFixed(3)}). Make every animation's duration divide ${r.ms}ms and end where it began.`); }
    else if (r.seam < 0.993) console.log(`  warn  the seam shows (SSIM ${r.seam.toFixed(3)}). Check the last beat lands on the first frame.`);
    if (r.longestStill > 2.5) console.log(`  warn  ${r.longestStill.toFixed(1)}s with nothing moving. Dead air in a reel reads as a freeze; tighten the loop or add a beat.`);
  }
  if (r.moving != null && r.moving < 0.25) console.log("  warn  almost nothing moves. A living screen shows the app doing its job.");
  for (const e of r.errors) console.log("  page error: " + e);
}
process.exit(bad ? 1 : 0);
