// Builds the Library screen in its states (core, signature frames, the view
// behind the poster sheet) from one source, so the frames never drift.
// Cells follow the web's LibraryCard: poster, title, year · kind, then one
// rail per version: tier chip · bar · have/total with ✓ / ↓ / ↑.
(() => {
  // [tier, state, have, total, inflight%]. total 0 = a movie (no counts).
  const items = (sig) => [
    ["andor", "Andor", 2022, "tv", [["HD", "done", 24, 24], sig === "landed" ? ["4K", "grab", 22, 24, 0, "landed"] : ["4K", "grab", 21, 24, sig]]],
    ["dune", "Dune: Part Two", 2024, "film", [["HD", "done", 1, 0], ["4K", "done", 1, 0]]],
    ["frieren", "Frieren", 2023, "anime", [["HD", "done", 28, 28]]],
    ["shogun", "Shōgun", 2024, "tv", [["HD", "done", 10, 10], ["4K", "miss", 0, 10]]],
    ["pastlives", "Past Lives", 2023, "film", [["HD", "done", 1, 0]]],
    ["bear", "The Bear", 2022, "tv", [["HD", "upg", 38, 38]]],
    ["severance", "Severance", 2022, "tv", [["HD", "grab", 9, 10, 18], ["4K", "miss", 0, 10]]],
    ["oppen", "Oppenheimer", 2023, "film", [["HD", "done", 1, 0], ["4K", "done", 1, 0]]],
    ["arcane", "Arcane", 2021, "tv", [["HD", "done", 18, 18], ["4K", "done", 18, 18]]],
  ];
  const kindGlyph = {
    tv: `<svg viewBox="0 0 16 16" aria-label="Series"><rect x="2" y="4.5" width="12" height="9" rx="1.5" fill="none" stroke="currentColor" stroke-width="1.4"/><path d="M5.5 1.8 8 4.3l2.5-2.5" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/></svg>`,
    anime: `<svg viewBox="0 0 16 16" aria-label="Anime"><path d="M2 4.5h12M3.5 4.5 3 2.5M12.5 4.5l.5-2M4.5 4.5V14M11.5 4.5V14M4.5 8h7" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/></svg>`,
    film: `<svg viewBox="0 0 16 16" aria-label="Movie"><rect x="2.5" y="2" width="11" height="12" rx="1.5" fill="none" stroke="currentColor" stroke-width="1.4"/><path d="M5.5 2v12M10.5 2v12M2.5 6h3M2.5 10h3M10.5 6h3M10.5 10h3" stroke="currentColor" stroke-width="1.2"/></svg>`,
  };
  const bmOn = `<svg viewBox="0 0 16 16" aria-label="Monitored"><path d="M4 2h8v12l-4-2.7L4 14Z" fill="currentColor"/></svg>`;
  const bmOff = `<svg viewBox="0 0 16 16" aria-label="Not monitored"><path d="M4 2h8v12l-4-2.7L4 14Z" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"/></svg>`;
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
    return `<div class="rail-row"><span class="ed ed-${t}${cls}"${cls === " fill" ? ` style="--p:${inflight}%"` : ""}>${tier}${cls === " fill" ? ` ${inflight}%` : ""}</span><span class="rbar">${bar}</span><span class="rc rc-${st}${landed ? " rolled" : ""}">${s === "grab" && !landed ? "↓ " : ""}${count}${s !== "grab" || landed ? (mark[st] ? ` ${mark[st]}` : (s === "miss" ? " Wanted" : "")) : ""}</span></div>`;
  };
  const grid = (sig) => items(sig).map(([k, t, y, kind, vs]) =>
    `<div class="cell"><div class="poster" data-poster="${k}"></div><div class="t">${t}</div><div class="y">${y} · ${kind === "anime" ? `<span class="anime">Anime</span>` : kindGlyph[kind]}<span class="mon${k === "pastlives" ? "" : " on"}">${k === "pastlives" ? bmOff : bmOn}</span></div><div class="rails">${vs.map(rail).join("")}</div></div>`).join("");

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
      <p class="caption"><b>347</b> titles · 512 versions<br><b style="color:var(--grab)">${downloading} downloading</b> · <span class="attn">2 need attention</span></p>
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

  // Scrolled Library: content runs under the Liquid Glass layer; the tab bar
  // minimises to the current tab and the downloads accessory sits beside it.
  for (const s of document.querySelectorAll('[data-build="library-scrolled"]')) {
    s.innerHTML = `<div class="under" data-behind><div class="grid">${grid(62)}${grid(62)}</div></div>
      <div class="float-top">
        <div class="topbar">
          <img class="logo" src="fusionha-logo.png" alt="fusionha">
          <div class="pill glass lg"><span class="ic" data-icon="search"></span>Search the library</div>
          <div class="g44 glass lg" data-icon="plus"></div>
          <div class="avatar">E<span class="dot"></span></div>
        </div>
        <div class="inline-title glass lg">Library</div>
      </div>
      <div class="mini-tabs" data-float data-system>
        <div class="tabdot glass lg">${window.KIT_ICONS_LIBRARY || ""}</div>
        <div class="accessory glass lg">
          <div class="acc-thumb poster" data-poster="andor"></div>
          <div class="acc-t"><b>Andor · S2E10</b><span>4K · 28.4 MB/s · 3 min left</span></div>
          <div class="acc-ring" style="--p:64"><b>64</b></div>
        </div>
      </div>`;
  }

  // iPhone Duo (HIG, Designing for iPhone Duo, 2026-09-09). Bars go
  // vertical on the outer display and in inner landscape; in a split, only
  // the detail column (the container on the display edge) gets the vertical
  // bar. The title column follows ShellSplitRule: clamp(56% of the width, 360,
  // 620). Half open, the two columns meet at the fold, which stays empty.
  const tabIcons = ["library", "discover", "calendar", "activity", "wanted"];
  const vbar = (tools, active = "library") => `<div class="vbar" data-float data-system>
      <div class="vstatus"><b>22:21</b><span class="vs-i"></span></div>
      <div class="vtools glass lg">${tools.map((t) => `<span data-icon="${t}"></span>`).join("")}</div>
      <div class="vtabs glass lg">${tabIcons.map((t) => `<span class="${t === active ? "on" : ""}" data-icon="${t}">${t === "activity" ? `<b class="badge">4</b>` : ""}</span>`).join("")}</div>
    </div>`;
  const libPane = () => {
    const d = document.createElement("div");
    d.innerHTML = library(62);
    d.querySelector(".topbar")?.remove();
    d.querySelector("[data-tabs]")?.remove();
    return d.innerHTML;
  };
  const detailPane = () => {
    const src = document.querySelector('.screen[data-name="detail"] .sheet');
    const d = document.createElement("div");
    d.innerHTML = src ? src.innerHTML : "";
    d.querySelector(".sheet-bar")?.remove();
    return d.innerHTML;
  };
  const hstatus = `<div class="hstatus" data-float data-system><b>22:21</b><span class="vs-i"></span></div>`;
  for (const s of document.querySelectorAll("[data-build^='duo-']")) {
    const kind = s.dataset.build;
    const w = parseFloat(s.style.getPropertyValue("--screen-w"));
    const col = Math.min(Math.max(w * 0.56, 360), 620);
    if (kind === "duo-outer") {
      // Outer display: compact width, bars vertical on the trailing edge.
      s.innerHTML = `<div class="pane lib" style="left:0;right:76px">${libPane()}</div>${vbar(["search", "plus", "person"])}`;
    } else if (kind === "duo-open") {
      // Inner landscape: split; only the title column (on the display edge) gets the vertical bar.
      s.innerHTML = `<div class="pane lib" style="left:0;width:${w - col}px">${libPane()}</div>
        <div class="pane detail" style="left:${w - col}px;right:76px"><div class="sheet flat">${detailPane()}</div></div>${vbar(["close", "refresh", "tray"])}`;
    } else if (kind === "duo-portrait") {
      // Inner portrait: split, horizontal bars (tab bar along the bottom).
      s.innerHTML = `${hstatus}<div class="pane lib" style="left:0;width:${w - col}px;bottom:96px">${libPane()}</div>
        <div class="pane detail" style="left:${w - col}px;right:0;bottom:96px"><div class="sheet flat">${detailPane()}</div>
          <div class="htools" data-float><div class="g44 glass lg" data-icon="close"></div><div class="tb glass lg"><span data-icon="refresh"></span><span data-icon="tray"></span></div></div></div>
        <div data-tabs="library" data-badges='{"activity":4}'></div>`;
    } else if (kind === "duo-book") {
      // Half open: the fold is a reserved region; the columns meet at it and it stays empty.
      const half = w / 2, fold = 30;
      s.innerHTML = `<div class="pane lib" style="left:0;width:${half - fold / 2}px">${libPane()}</div>
        <div class="fold" style="left:${half - fold / 2}px;width:${fold}px"></div>
        <div class="pane detail" style="left:${half + fold / 2}px;right:76px"><div class="sheet flat">${detailPane()}</div></div>${vbar(["close", "refresh", "tray"])}`;
    }
    const sel = s.querySelector(".pane.lib .cell");
    if (kind !== "duo-outer" && sel) sel.classList.add("selected");
  }
})();
