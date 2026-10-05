// Drives the iPhone Duo simulator's poses from CI. `simctl` has no pose
// command: Xcode 27.1 exposes the poses (Closed, Book, Open, Rotate Right…)
// only as buttons in the Simulator's Device Hub window, so this presses them
// through the accessibility API (System Events UI scripting).
//
//   osascript -l JavaScript scripts/duo_pose.js dump        # print the UI tree
//   osascript -l JavaScript scripts/duo_pose.js press Open  # press a pose button
//
// `press` looks for a button (or menu item) whose name, title or description
// matches the label, first in the windows, then in the menu bar. It exits 0
// when it pressed something and prints what it pressed, 1 otherwise.

ObjC.import("stdlib");

function label(e) {
  const parts = [];
  for (const k of ["name", "title", "description"]) {
    try {
      const v = e[k]();
      if (v) parts.push(String(v));
    } catch (_) {}
  }
  return parts.join(" | ");
}

function role(e) {
  try { return e.role(); } catch (_) { return "?"; }
}

function processes(se) {
  return se.processes.whose({ backgroundOnly: false })().filter((p) => /Simulator|Device Hub/i.test(p.name()));
}

function walkMenus(p, fn) {
  try {
    for (const bar of p.menuBars()) {
      for (const top of bar.menuBarItems()) {
        for (const menu of top.menus()) {
          const visit = (m, path) => {
            for (const item of m.menuItems()) {
              const name = (() => { try { return item.name() || ""; } catch (_) { return ""; } })();
              fn(item, path + " > " + name);
              try { for (const sub of item.menus()) visit(sub, path + " > " + name); } catch (_) {}
            }
          };
          visit(menu, top.name());
        }
      }
    }
  } catch (_) {}
}

function run(argv) {
  const mode = argv[0] || "dump";
  const want = (argv[1] || "").toLowerCase();
  const se = Application("System Events");
  const procs = processes(se);
  if (procs.length === 0) {
    console.log("no Simulator / Device Hub process");
    $.exit(1);
  }
  for (const p of procs) {
    const windows = (() => { try { return p.windows(); } catch (_) { return []; } })();
    for (const w of windows) {
      const all = (() => { try { return w.entireContents(); } catch (_) { return []; } })();
      if (mode === "dump") console.log(`[${p.name()}] window: ${label(w)} (${all.length} elements)`);
      for (const e of all) {
        const r = role(e);
        const l = label(e);
        if (mode === "dump") {
          if (/Button|CheckBox|RadioButton|PopUp|MenuButton|Segment|StaticText|Slider/.test(r)) console.log(`  ${r}: ${l}`);
          continue;
        }
        if (!/Button|RadioButton|CheckBox|Segment/.test(r)) continue;
        if (l.toLowerCase().split(" | ").some((s) => s === want)) {
          try { e.actions["AXPress"].perform(); } catch (_) { try { e.click(); } catch (_) { continue; } }
          console.log(`pressed ${r} "${l}" in ${p.name()}`);
          return;
        }
      }
    }
    let done = false;
    walkMenus(p, (item, path) => {
      if (done) return;
      if (mode === "dump") { console.log(`  menu: ${path}`); return; }
      const leaf = path.split(" > ").pop().toLowerCase();
      if (leaf === want) {
        try { item.click(); done = true; console.log(`pressed menu ${path}`); } catch (_) {}
      }
    });
    if (done) return;
  }
  if (mode !== "dump") {
    console.log(`no control labelled "${argv[1]}"`);
    $.exit(1);
  }
}
