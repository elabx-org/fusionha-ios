// Builds the Library screen in its states (core, signature frames, the view
// behind the poster sheet) from one source, so the frames never drift.
(() => {
  const items = (andor) => [
    ["andor", "Andor", andor === "done" ? [["HD", "done"], ["4K", "done", "", true]] : [["HD", "done"], ["4K", "grab", andor]]],
    ["dune", "Dune: Part Two", [["HD", "done"], ["4K", "done"]]],
    ["frieren", "Frieren", [["HD", "done"]]],
    ["shogun", "Shōgun", [["HD", "done"], ["4K", "miss"]]],
    ["pastlives", "Past Lives", [["HD", "done"]]],
    ["bear", "The Bear", [["HD", "upg"]]],
    ["severance", "Severance", [["HD", "grab", 18], ["4K", "miss"]]],
    ["oppen", "Oppenheimer", [["HD", "done"], ["4K", "done"]]],
    ["arcane", "Arcane", [["HD", "done"], ["4K", "done"]]],
    ["slowhorses", "Slow Horses", [["HD", "miss"]]],
    ["silo", "Silo", [["HD", "done"], ["4K", "upg"]]],
    ["perfectdays", "Perfect Days", [["HD", "done"]]],
  ];
  const check = `<svg class="ck" viewBox="0 0 12 12" aria-hidden="true"><path d="M2.5 6.4 5 8.8l4.5-5.6" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
  const chip = ([tier, s, p, landed]) =>
    s === "grab" ? `<span class="ed ed-grab" style="--p:${p}%">${tier} <i>${p}%</i></span>`
      : `<span class="ed ed-${s}${landed ? " landed" : ""}">${tier}${landed ? check : ""}</span>`;
  const grid = (andor) => items(andor).map(([k, t, eds]) =>
    `<div class="cell${k === "andor" && andor !== 62 ? " focus" : ""}"><div class="poster" data-poster="${k}"></div><div class="t">${t}</div><div class="eds">${eds.map(chip).join("")}</div></div>`).join("");

  const coverage = `<div class="coverage" aria-label="296 complete, 23 missing, 9 upcoming, 4 downloading, 2 need attention">
      <i style="flex:296;background:var(--done)"></i><i style="flex:23;background:var(--miss)"></i><i style="flex:9;background:var(--unaired)"></i><i style="flex:4;background:var(--grab)"></i><i style="flex:2;background:var(--danger)"></i></div>`;

  const library = (andor) => {
    const landed = andor === "done";
    const downloading = landed ? 3 : 4;
    return `<div class="body">
      <div class="topbar">
        <img class="logo" src="fusionha-logo.png" alt="fusionha">
        <div class="pill glass"><span class="ic" data-icon="search"></span>Search the library</div>
        <div class="g44 glass" data-icon="plus"></div>
        <div class="avatar">E<span class="dot"></span></div>
      </div>
      <h1 class="display page-title">Library</h1>
      <p class="caption"><b>347</b> titles · <b style="color:var(--grab)">${downloading} downloading</b> · <b style="color:var(--miss)">23 missing</b></p>
      ${coverage}
      <div class="chips" data-scrolls>
        <span class="on">All <em>347</em></span>
        <span class="glass"><i class="sw" style="background:var(--grab)"></i>Downloading <em>${downloading}</em></span>
        <span class="glass"><i class="sw" style="background:var(--miss)"></i>Missing <em>23</em></span>
        <span class="glass"><i class="sw" style="background:var(--unaired)"></i>Upcoming <em>9</em></span>
      </div>
      <div class="grid" data-scrolls>${grid(andor)}</div>
    </div>
    <div class="edge" data-float></div>
    ${landed ? `<div class="toast" data-float><div class="thumb poster" data-poster="andor"></div><div class="tt"><b>Andor · 4K is on disk</b><span>S02E10 · 4.1 GB · 21 of 24 now in 4K</span></div><div class="act">Open</div><div class="timer"></div></div>` : ""}
    <div data-tabs="library" data-badges='{"activity":${downloading}}'></div>`;
  };

  for (const s of document.querySelectorAll('[data-build="library"]')) {
    const a = s.dataset.andor;
    s.innerHTML = library(a === "done" ? "done" : Number(a));
  }
  for (const b of document.querySelectorAll('[data-build="library-behind"]')) b.innerHTML = library(62);
})();
