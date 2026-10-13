// Shared mockup kit: drawn posters (stand-ins for TMDB art, never text on
// art), the app's own tab glyphs, edition chips and the glass tab bar.
// Runs before device.js so the chrome lands on top of what it builds.
(() => {
  const P = {
    andor: `<rect width="200" height="300" fill="#3a1f17"/><rect width="200" height="300" fill="url(#gA)"/><circle cx="142" cy="92" r="34" fill="#e2522b"/><rect x="58" y="70" width="34" height="230" fill="#e9dccb"/><rect x="58" y="70" width="34" height="230" fill="#000" opacity=".18" transform="translate(34 0) scale(.3 1)"/><rect x="0" y="236" width="200" height="64" fill="#1b0f0b"/>
      <defs><linearGradient id="gA" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6b2f1d"/><stop offset="1" stop-color="#22120d"/></linearGradient></defs>`,
    dune: `<defs><linearGradient id="gD" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f3b25a"/><stop offset=".55" stop-color="#d9732f"/><stop offset="1" stop-color="#8a3a17"/></linearGradient></defs><rect width="200" height="300" fill="url(#gD)"/><circle cx="64" cy="88" r="22" fill="#fff1d6"/><path d="M0 210 Q70 150 130 200 T200 180 V300 H0Z" fill="#7a3214"/><path d="M0 250 Q90 200 200 246 V300 H0Z" fill="#4e1e0c"/><rect x="128" y="190" width="3" height="16" fill="#1a0a04"/>`,
    frieren: `<defs><linearGradient id="gF" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#bfe3f2"/><stop offset="1" stop-color="#e9f3ea"/></linearGradient></defs><rect width="200" height="300" fill="url(#gF)"/><path d="M0 214 Q100 190 200 214 V300 H0Z" fill="#9fcf9a"/><g fill="#fff">${Array.from({ length: 34 }, (_, i) => `<circle cx="${(i * 47) % 200}" cy="${222 + ((i * 29) % 74)}" r="${2 + (i % 3)}"/>`).join("")}</g><g fill="#c9a6e8">${Array.from({ length: 12 }, (_, i) => `<circle cx="${(i * 61 + 13) % 200}" cy="${232 + ((i * 37) % 62)}" r="2.4"/>`).join("")}</g><rect x="96" y="150" width="8" height="66" rx="4" fill="#f6f2ea"/><circle cx="100" cy="146" r="7" fill="#f6f2ea"/>`,
    shogun: `<rect width="200" height="300" fill="#121010"/><circle cx="100" cy="120" r="58" fill="#b8221b"/><path d="M20 230 C70 214 130 250 182 222" stroke="#e9e1d2" stroke-width="10" fill="none" stroke-linecap="round"/><path d="M30 252 C80 240 120 262 170 248" stroke="#e9e1d2" stroke-width="4" fill="none" stroke-linecap="round" opacity=".6"/>`,
    pastlives: `<defs><linearGradient id="gP" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2c3e63"/><stop offset="1" stop-color="#b9876f"/></linearGradient></defs><rect width="200" height="300" fill="url(#gP)"/><rect x="0" y="236" width="200" height="64" fill="#2a2430"/><rect x="72" y="196" width="7" height="42" rx="3.5" fill="#f2e3d6"/><rect x="120" y="190" width="7" height="48" rx="3.5" fill="#f2e3d6"/><circle cx="75.5" cy="190" r="5" fill="#f2e3d6"/><circle cx="123.5" cy="184" r="5" fill="#f2e3d6"/>`,
    bear: `<rect width="200" height="300" fill="#1f4f7a"/><g stroke="#2f6696" stroke-width="2">${Array.from({ length: 10 }, (_, i) => `<line x1="0" y1="${i * 30}" x2="200" y2="${i * 30}"/><line x1="${i * 25}" y1="0" x2="${i * 25}" y2="300"/>`).join("")}</g><rect x="40" y="150" width="120" height="150" fill="#f1ede4"/><rect x="40" y="150" width="120" height="14" fill="#d23c2a"/><circle cx="100" cy="112" r="22" fill="#f1ede4"/>`,
    arcane: `<rect width="200" height="300" fill="#16303b"/><path d="M0 300 L200 40 V300Z" fill="#c2306b"/><path d="M0 300 L200 120 V300Z" fill="#7b1a45"/><circle cx="62" cy="86" r="16" fill="#3fd0c9"/><circle cx="62" cy="86" r="7" fill="#16303b"/>`,
    oppen: `<rect width="200" height="300" fill="#0d0a08"/><g fill="none" stroke="#f28b2a">${[70, 54, 40, 28].map((r, i) => `<circle cx="100" cy="128" r="${r}" stroke-width="${2 + i * 2}" opacity="${0.35 + i * 0.2}"/>`).join("")}</g><circle cx="100" cy="128" r="16" fill="#ffd27a"/><rect x="0" y="246" width="200" height="54" fill="#1d1712"/>`,
    severance: `<rect width="200" height="300" fill="#f2f3ef"/><path d="M0 300 L82 150 H118 L200 300Z" fill="#1e7a6a"/><path d="M0 0 L82 150 H118 L200 0Z" fill="#dfe3dc"/><rect x="82" y="112" width="36" height="38" fill="#cfd6cd"/><rect x="96" y="124" width="8" height="26" fill="#21332e"/>`,
    slowhorses: `<rect width="200" height="300" fill="#4a5446"/><rect x="0" y="210" width="200" height="90" fill="#2c3329"/><rect x="34" y="60" width="132" height="112" fill="#3b4438"/><g fill="#e9c24a">${[0, 1, 2].map((r) => [0, 1, 2, 3].map((c) => `<rect x="${46 + c * 30}" y="${72 + r * 32}" width="18" height="22" opacity="${(r * 4 + c) % 5 === 1 ? 1 : 0.18}"/>`).join("")).join("")}</g>`,
    silo: `<rect width="200" height="300" fill="#2b2b2a"/><g fill="none" stroke="#8f8b80">${[90, 72, 54, 36, 18].map((r, i) => `<ellipse cx="100" cy="160" rx="${r}" ry="${r * 1.35}" stroke-width="${6 - i}" opacity="${0.3 + i * 0.15}"/>`).join("")}</g><circle cx="100" cy="160" r="8" fill="#e7d9a8"/>`,
    perfectdays: `<rect width="200" height="300" fill="#2f5a34"/><g fill="#cfe6a4">${Array.from({ length: 40 }, (_, i) => `<circle cx="${(i * 53) % 200}" cy="${(i * 71) % 220}" r="${3 + (i % 5) * 2}" opacity="${0.25 + (i % 4) * 0.18}"/>`).join("")}</g><rect x="0" y="230" width="200" height="70" fill="#1d3420"/>`,
    fallout: `<defs><linearGradient id="gFo" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#9ec8d4"/><stop offset="1" stop-color="#e8c77d"/></linearGradient></defs><rect width="200" height="300" fill="url(#gFo)"/><path d="M0 230 L40 200 70 220 110 180 150 214 200 196 V300 H0Z" fill="#8a6a3c"/><circle cx="100" cy="110" r="30" fill="#2a5aa6"/><circle cx="100" cy="110" r="18" fill="#f2c94c"/>`,
    spyfamily: `<rect width="200" height="300" fill="#f2c5c9"/><circle cx="66" cy="120" r="30" fill="#2c2a35"/><circle cx="134" cy="120" r="30" fill="#e8e0d3"/><circle cx="100" cy="196" r="22" fill="#e86a8e"/><rect x="0" y="252" width="200" height="48" fill="#2c2a35"/>`,
  };
  const poster = (k) => `<svg class="poster-art" viewBox="0 0 200 300" preserveAspectRatio="xMidYMid slice" aria-hidden="true">${P[k] || ""}</svg>`;

  // The app's own tab glyphs (App/Assets.xcassets/nav-*.svg), stroke = currentColor.
  const wrap = (d) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${d}</svg>`;
  const I = {
    library: wrap(`<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/>`),
    discover: wrap(`<circle cx="12" cy="12" r="9"/><path d="m15.6 8.4-2.1 5.1-5.1 2.1 2.1-5.1 5.1-2.1Z"/>`),
    calendar: wrap(`<rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>`),
    activity: wrap(`<path d="M22 12h-4l-3 9L9 3l-3 9H2"/>`),
    wanted: wrap(`<path d="M6 3h12a1 1 0 0 1 1 1v17l-7-4-7 4V4a1 1 0 0 1 1-1Z"/>`),
    // SF Symbol stand-ins, drawn at the same weight.
    search: wrap(`<circle cx="11" cy="11" r="6.5"/><path d="m16 16 4.5 4.5"/>`),
    plus: wrap(`<path d="M12 5v14M5 12h14"/>`),
    filter: wrap(`<path d="M4 7h16M7 12h10M10 17h4"/>`),
    bell: wrap(`<path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15Z"/><path d="M10 21h4"/>`),
    close: wrap(`<path d="M6 6l12 12M18 6 6 18"/>`),
    refresh: wrap(`<path d="M20 12a8 8 0 1 1-2.4-5.7"/><path d="M20 4v5h-5"/>`),
    person: wrap(`<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4.4 3.6-7 8-7s8 2.6 8 7"/>`),
    magnifier: wrap(`<circle cx="11" cy="11" r="6.5"/><path d="m16 16 4.5 4.5"/>`),
    bookmark: wrap(`<path d="M6 3h12v18l-6-4-6 4Z" fill="currentColor"/>`),
    bookmarkOpen: wrap(`<path d="M6 3h12v18l-6-4-6 4Z"/>`),
    pencil: wrap(`<path d="M4 20h4L19 9l-4-4L4 16Z"/><path d="m13 7 4 4"/>`),
    trash: wrap(`<path d="M4 7h16M9 7V4h6v3M6 7l1 14h10l1-14"/>`),
    chevron: wrap(`<path d="m9 6 6 6-6 6"/>`),
    down: wrap(`<path d="m6 9 6 6 6-6"/>`),
    pause: wrap(`<path d="M8 5v14M16 5v14"/>`),
    tray: wrap(`<path d="M4 14h4l1.5 3h5L16 14h4"/><path d="M4 14 6.5 5h11L20 14v6H4Z"/><path d="M12 6v6m-2.5-2.5L12 12l2.5-2.5"/>`),
    play: wrap(`<path d="M7 4.5v15l13-7.5Z" fill="currentColor"/>`),
    flag: wrap(`<path d="M5 21V4h11l-2 4 2 4H5"/>`),
    folder: wrap(`<path d="M3 6h6l2 2h10v11H3Z"/>`),
    chart: wrap(`<path d="M4 4v16h16"/><path d="M8 16v-4M12 16V8M16 16v-6"/>`),
    grid: wrap(`<rect x="4" y="4" width="6.5" height="6.5" rx="1.5"/><rect x="13.5" y="4" width="6.5" height="6.5" rx="1.5"/><rect x="4" y="13.5" width="6.5" height="6.5" rx="1.5"/><rect x="13.5" y="13.5" width="6.5" height="6.5" rx="1.5"/>`),
    select: wrap(`<circle cx="12" cy="12" r="8.5"/><path d="m8.3 12.2 2.5 2.5 5-5.3"/>`),
    textformat: wrap(`<path d="M5 6h14M12 6v13"/>`),
    feed: wrap(`<path d="M5 19a1 1 0 1 0 0-.01M5 12a7 7 0 0 1 7 7M5 5a14 14 0 0 1 14 14"/>`),
    left: wrap(`<path d="m15 6-6 6 6 6"/>`),
    chat: wrap(`<path d="M5 18.5 4 21l3.2-1.4A8.5 8.5 0 1 0 5 18.5Z"/>`),
    bolt: wrap(`<path d="M13 3 5 13.5h6L10 21l8-10.5h-6Z" fill="currentColor"/>`),
    info: wrap(`<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5.5M12 7.8v.2"/>`),
    check: wrap(`<path d="m5 12.5 4.5 4.5L19 7.5"/>`),
    ellipsis: wrap(`<circle cx="6" cy="12" r="1.2" fill="currentColor"/><circle cx="12" cy="12" r="1.2" fill="currentColor"/><circle cx="18" cy="12" r="1.2" fill="currentColor"/>`),
  };

  // Edition chip, tinted by status exactly like EditionChip / status.ts.
  const chip = (tier, status, extra = "") => `<span class="ed ed-${status}">${tier}${extra ? `<i>${extra}</i>` : ""}</span>`;

  const tabs = (active, badge = {}) => `<nav class="tabbar glass" data-system data-float>
    ${[["library", "Library"], ["discover", "Discover"], ["calendar", "Calendar"], ["activity", "Activity"], ["wanted", "Wanted"]]
      .map(([k, l]) => `<div class="tab${k === active ? " on" : ""}">${I[k]}${badge[k] ? `<b class="badge">${badge[k]}</b>` : ""}<span>${l}</span></div>`).join("")}
  </nav>`;

  window.KIT = { poster, I, chip, tabs };
  for (const el of document.querySelectorAll(".tabdot")) el.innerHTML = I.library;
  for (const el of document.querySelectorAll("[data-poster]")) el.insertAdjacentHTML("afterbegin", poster(el.dataset.poster));
  for (const el of document.querySelectorAll("[data-icon]")) el.insertAdjacentHTML("afterbegin", I[el.dataset.icon] || "");
  for (const el of document.querySelectorAll("[data-tabs]")) el.outerHTML = tabs(el.dataset.tabs, JSON.parse(el.dataset.badges || "{}"));
})();
