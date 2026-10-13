// Builds the Library screen in its states (core, signature frames, the view
// behind the poster sheet) from one source, so the frames never drift.
// Cells follow the web's LibraryCard: poster, title, year · kind, then one
// rail per version: tier chip · bar · have/total with ✓ / ↓ / ↑.
(() => {
  // [tier, state, have, total, inflight%]. total 0 = a movie (no counts).
  const items = (sig) => [
    ["andor", "Andor", 2022, "tv", [["HD", "done", 24, 24], sig === "landed" ? ["4K", "grab", 22, 24, 0, "landed"] : ["4K", "grab", 21, 24, sig]]],
    ["dune", "Dune: Part Two", 2024, "film", [["HD", "done", 1, 0], ["4K", "done", 1, 0]]],
    ["frieren", "Frieren", 2023, "tv", [["HD", "done", 28, 28]]],
    ["shogun", "Shōgun", 2024, "tv", [["HD", "done", 10, 10], ["4K", "miss", 0, 10]]],
    ["pastlives", "Past Lives", 2023, "film", [["HD", "done", 1, 0]]],
    ["bear", "The Bear", 2022, "tv", [["HD", "upg", 38, 38]]],
    ["severance", "Severance", 2022, "tv", [["HD", "grab", 9, 10, 18], ["4K", "miss", 0, 10]]],
    ["oppen", "Oppenheimer", 2023, "film", [["HD", "done", 1, 0], ["4K", "done", 1, 0]]],
    ["arcane", "Arcane", 2021, "tv", [["HD", "done", 18, 18], ["4K", "done", 18, 18]]],
  ];
  const kindGlyph = {
    tv: `<svg viewBox="0 0 16 16" aria-label="Series"><rect x="2" y="4.5" width="12" height="9" rx="1.5" fill="none" stroke="currentColor" stroke-width="1.4"/><path d="M5.5 1.8 8 4.3l2.5-2.5" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/></svg>`,
    film: `<svg viewBox="0 0 16 16" aria-label="Movie"><rect x="2.5" y="2" width="11" height="12" rx="1.5" fill="none" stroke="currentColor" stroke-width="1.4"/><path d="M5.5 2v12M10.5 2v12M2.5 6h3M2.5 10h3M10.5 6h3M10.5 10h3" stroke="currentColor" stroke-width="1.2"/></svg>`,
  };
  const mark = { done: "✓", grab: "↓", miss: "", upg: "↑" };
  const rail = ([tier, s, have, total, inflight, landed]) => {
    const t = tier === "4K" ? "uhd" : "hd";
    const pct = total ? (have / total) * 100 : 100;
    const live = s === "grab" && inflight ? (100 / Math.max(total, 1)) * (inflight / 100) : 0;
    const bar = s === "miss"
      ? `<i style="width:100%;background:color-mix(in srgb,var(--miss) 30%,transparent)"></i>`
      : `<i class="have" style="width:${pct}%;background:var(--${s === "grab" ? "done" : s})"></i>${live ? `<i class="live" style="width:${live}%"></i>` : ""}${landed ? `<i class="new" style="width:${100 / total}%"></i>` : ""}`;
    const count = total ? `${have}/${total}` : "";
    const st = landed ? "done" : s;
    const cls = s === "grab" && inflight ? " fill" : landed ? " landed" : "";
    return `<div class="rail-row"><span class="ed ed-${t}${cls}"${cls === " fill" ? ` style="--p:${inflight}%"` : ""}>${tier}${cls === " fill" ? ` ${inflight}%` : ""}</span><span class="rbar">${bar}</span><span class="rc rc-${st}${landed ? " rolled" : ""}">${s === "grab" && !landed ? "↓ " : ""}${count}${s !== "grab" || landed ? (mark[st] ? ` ${mark[st]}` : (s === "miss" ? "missing" : "")) : ""}</span></div>`;
  };
  const grid = (sig) => items(sig).map(([k, t, y, kind, vs]) =>
    `<div class="cell"><div class="poster" data-poster="${k}"></div><div class="t">${t}</div><div class="y">${y} · ${kindGlyph[kind]}</div><div class="rails">${vs.map(rail).join("")}</div></div>`).join("");

  const library = (sig) => {
    const landed = sig === "landed";
    const downloading = landed ? 3 : 4;
    return `<div class="body">
      <div class="topbar">
        <img class="logo" src="fusionha-logo.png" alt="fusionha">
        <div class="pill glass"><span class="ic" data-icon="search"></span>Search the library</div>
        <div class="g44 glass" data-icon="plus"></div>
        <div class="avatar">E<span class="dot"></span></div>
      </div>
      <div class="title-row"><h1 class="display page-title">Library</h1><div class="g36 glass" data-icon="chart"><b class="adot"></b></div></div>
      <p class="caption"><b>347</b> titles · 512 versions · <b style="color:var(--grab)">${downloading} downloading</b></p>
      <div class="tools">
        <div class="tier glass" data-system><span class="on">All</span><span>HD</span><span>4K</span></div>
        <div class="kmenu glass"><span class="full">All kinds</span><span class="short">Kinds</span><span data-icon="down"></span></div>
        <div class="g36 glass" data-icon="filter"></div>
        <div class="g36 glass" data-icon="grid"></div>
        <div class="g36 glass" data-icon="select"></div>
      </div>
      <div class="grid" data-scrolls>${grid(sig)}</div>
    </div>
    <div class="edge" data-float></div>
    ${landed ? `<div class="toast" data-float><div class="thumb poster" data-poster="andor"></div><div class="tt"><b><span class="ed ed-uhd landed">4K</span> Andor · S2E10 is on disk</b><span>4.1 GB · 22 of 24 now in 4K</span></div><div class="act">Open</div></div>` : ""}
    <div data-tabs="library" data-badges='{"activity":${downloading}}'></div>`;
  };

  for (const s of document.querySelectorAll('[data-build="library"]')) {
    const a = s.dataset.andor;
    s.innerHTML = library(a === "landed" ? "landed" : Number(a));
  }
  for (const b of document.querySelectorAll('[data-build="library-behind"]')) b.innerHTML = library(62);
})();
