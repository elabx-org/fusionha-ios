// Drives the iPhone Duo simulator's poses from CI. `simctl` has no pose
// command: Xcode 27.1 exposes the poses (Closed, Book, Open, Rotate Right…)
// as buttons in the simulator UI's device window, so this presses them
// through the accessibility API (System Events UI scripting).
//
//   osascript -l JavaScript scripts/duo_pose.js dump        # print the controls
//   osascript -l JavaScript scripts/duo_pose.js press Open  # press a pose button
//
// The walk is depth- and size-limited (`entireContents` on a simulator
// window can take minutes). `press` looks for a button whose name, title or
// description equals the label, then for a menu item with that name. It exits
// 0 when it pressed something, 1 otherwise.

ObjC.import("stdlib");

const MAX_DEPTH = 7;
const MAX_ELEMENTS = 1500;

function safe(fn, fallback) {
  try { return fn(); } catch (_) { return fallback; }
}

function label(e) {
  const parts = [];
  for (const k of ["name", "title", "description"]) {
    const v = safe(() => e[k](), null);
    if (v) parts.push(String(v));
  }
  return parts.join(" | ");
}

function processes(se) {
  return safe(() => se.processes.whose({ backgroundOnly: false })(), [])
    .filter((p) => /Simulator|Device ?Hub/i.test(safe(() => p.name(), "")));
}

// Breadth-first over UI elements, calling visit(element, role, label); stops
// when visit returns true.
function walk(root, visit) {
  let queue = [[root, 0]];
  let seen = 0;
  while (queue.length && seen < MAX_ELEMENTS) {
    const [el, depth] = queue.shift();
    const kids = safe(() => el.uiElements(), []);
    for (const kid of kids) {
      seen++;
      const r = safe(() => kid.role(), "?");
      if (visit(kid, r, label(kid))) return true;
      if (depth + 1 < MAX_DEPTH) queue.push([kid, depth + 1]);
    }
  }
  return false;
}

function menus(p, visit) {
  const bars = safe(() => p.menuBars(), []);
  for (const bar of bars) {
    for (const top of safe(() => bar.menuBarItems(), [])) {
      const topName = safe(() => top.name(), "");
      if (!/Device|Features|Hardware|Window|I\/O/i.test(topName)) continue;
      for (const menu of safe(() => top.menus(), [])) {
        for (const item of safe(() => menu.menuItems(), [])) {
          const name = safe(() => item.name(), "") || "";
          if (visit(item, `${topName} > ${name}`, name)) return true;
          for (const sub of safe(() => item.menus(), [])) {
            for (const subItem of safe(() => sub.menuItems(), [])) {
              const subName = safe(() => subItem.name(), "") || "";
              if (visit(subItem, `${topName} > ${name} > ${subName}`, subName)) return true;
            }
          }
        }
      }
    }
  }
  return false;
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
    const pname = safe(() => p.name(), "?");
    for (const w of safe(() => p.windows(), [])) {
      if (mode === "dump") console.log(`[${pname}] window: ${label(w)}`);
      const hit = walk(w, (el, r, l) => {
        if (mode === "dump") {
          if (/Button|CheckBox|RadioButton|PopUp|MenuButton|Segment|Tab/.test(r)) console.log(`  ${r}: ${l}`);
          return false;
        }
        if (!/Button|RadioButton|CheckBox|Segment/.test(r)) return false;
        if (!l.toLowerCase().split(" | ").includes(want)) return false;
        const ok = safe(() => { el.actions["AXPress"].perform(); return true; }, false) || safe(() => { el.click(); return true; }, false);
        if (ok) console.log(`pressed ${r} "${l}" in ${pname}`);
        return ok;
      });
      if (hit) return;
    }
    const hit = menus(p, (item, path, name) => {
      if (mode === "dump") { console.log(`  menu: ${path}`); return false; }
      if (name.toLowerCase() !== want) return false;
      const ok = safe(() => { item.click(); return true; }, false);
      if (ok) console.log(`pressed menu ${path}`);
      return ok;
    });
    if (hit) return;
  }
  if (mode !== "dump") {
    console.log(`no control labelled "${argv[1]}"`);
    $.exit(1);
  }
}
