#!/usr/bin/env python3
"""Summarise an Activity perf run (the CI "Activity perf" job).

    perf_report.py APP_LOG [TOC_XML TIME_PROFILE_XML] [--json OUT]

APP_LOG holds the `PERF {json}` lines App/Debug/PerfProbe.swift prints per phase
(frame pacing, main-thread hangs, CPU, memory, view counters). The optional
xctrace exports add the heaviest main-thread symbols, overall and per phase.
Prints a plain-text report (also valid Markdown inside a code fence).
"""
import collections
import datetime as dt
import json
import re
import sys
import xml.etree.ElementTree as ET


def load_phases(path):
    phases = []
    with open(path, errors="replace") as fh:
        for line in fh:
            idx = line.find("PERF {")
            if idx < 0:
                continue
            try:
                obj = json.loads(line[idx + 5:])
            except json.JSONDecodeError:
                continue
            if obj.get("event") == "phase":
                phases.append(obj)
    return phases


def phase_table(phases):
    cols = [("phase", 26), ("wall_s", 7), ("fps", 6), ("hitch_ms_per_s", 8), ("hang_ms", 8), ("stalls_250ms", 7),
            ("max_frame_ms", 9), ("main_cpu_pct", 9), ("proc_cpu_pct", 9), ("mem_mb", 7), ("scroll_y", 8), ("content_h", 9)]
    heads = {"hitch_ms_per_s": "hitch/s", "stalls_250ms": "hangs", "max_frame_ms": "maxframe", "main_cpu_pct": "main%",
             "proc_cpu_pct": "proc%", "mem_mb": "memMB", "scroll_y": "scrollY", "content_h": "contentH"}
    out = ["  ".join(heads.get(c, c).rjust(w) if i else heads.get(c, c).ljust(w) for i, (c, w) in enumerate(cols))]
    for p in phases:
        out.append("  ".join(str(p.get(c, "")).rjust(w) if i else str(p.get(c, "")).ljust(w)
                             for i, (c, w) in enumerate(cols)))
    return "\n".join(out)


def counters(phases):
    out = []
    for p in phases:
        counts = p.get("counts") or {}
        times = p.get("times_ms") or {}
        if not counts:
            continue
        parts = []
        for key in sorted(counts, key=lambda k: -counts[k]):
            t = f" ({times[key]:.0f} ms)" if key in times else ""
            parts.append(f"{key}={counts[key]}{t}")
        out.append(f"  {p['phase']}: " + ", ".join(parts))
    return "\n".join(out)


def totals(phases):
    def agg(filter_fn):
        sel = [p for p in phases if filter_fn(p["phase"])]
        wall = sum(p["wall_s"] for p in sel) or 1
        return {
            "hang_ms": sum(p.get("hang_ms", 0) for p in sel),
            "hangs": sum(p.get("stalls_250ms", 0) for p in sel),
            "hitch_ms_per_s": round(sum(p["hitch_ms_per_s"] * p["wall_s"] for p in sel) / wall, 1),
            "main_cpu_pct": round(sum(p["main_cpu_pct"] * p["wall_s"] for p in sel) / wall, 1),
            "max_frame_ms": max((p["max_frame_ms"] for p in sel), default=0),
        }
    return {
        "scroll": agg(lambda n: n.endswith(".scroll")),
        "idle": agg(lambda n: ".idle" in n),
        "load": agg(lambda n: n.endswith(".load") or n.endswith(".return")),
    }


# MARK: xctrace time profile

def parse_start(toc_path):
    try:
        root = ET.parse(toc_path).getroot()
    except Exception:
        return None
    node = root.find(".//run/info/summary/start-date")
    if node is None or not node.text:
        return None
    text = node.text.strip()
    text = re.sub(r"([+-]\d\d)(\d\d)$", r"\1:\2", text).replace("Z", "+00:00")
    try:
        return dt.datetime.fromisoformat(text).timestamp()
    except ValueError:
        return None


def parse_samples(path):
    """Yields (time_s, is_main, weight_ms, [frame names leaf first], [binary names])."""
    ids = {}

    def resolve(el):
        ref = el.get("ref")
        return ids.get(ref, el) if ref else el

    def remember(el):
        for sub in el.iter():
            if sub.get("id"):
                ids[sub.get("id")] = sub

    frames_cache = {}
    for _, el in ET.iterparse(path, events=("end",)):
        if el.tag != "row":
            continue
        remember(el)
        t = w = None
        thread = bt = None
        bt_key = None
        for child in el:
            c = resolve(child)
            if child.tag == "sample-time":
                t = int(c.text or 0) / 1e9
            elif child.tag == "weight":
                w = int(c.text or 0) / 1e6
            elif child.tag == "thread":
                thread = c
            elif child.tag in ("backtrace", "tagged-backtrace"):
                bt = c
                bt_key = child.get("ref") or child.get("id")
        if t is None or bt is None:
            continue
        key = bt_key
        if key in frames_cache:
            names, bins = frames_cache[key]
        else:
            names, bins = [], []
            for f in bt.iter("frame"):
                f = resolve(f)
                names.append(f.get("name") or f.get("addr") or "?")
                b = f.find("binary")
                b = resolve(b) if b is not None else None
                bins.append(b.get("name") if b is not None else "")
            if key:
                frames_cache[key] = (names, bins)
        tname = thread.get("fmt", "") if thread is not None else ""
        # Recorded with --all-processes: keep the app's samples only.
        if "Fusionha" not in tname:
            proc = thread.find("process") if thread is not None else None
            proc = resolve(proc) if proc is not None else None
            if proc is None or "Fusionha" not in (proc.get("fmt") or ""):
                continue
        yield t, tname.startswith("Main Thread"), w or 1.0, names, bins


def short(name, width=110):
    name = re.sub(r"\s+", " ", name)
    return name if len(name) <= width else name[: width - 1] + "…"


def profile_report(toc, tp, phases):
    start = parse_start(toc)
    windows = []
    if start:
        for p in phases:
            off = p["epoch"] - start
            windows.append((p["phase"], off, off + p["wall_s"]))
    self_main = collections.Counter()
    incl_app = collections.Counter()
    main_ms = 0.0
    all_ms = 0.0
    per_phase = collections.defaultdict(collections.Counter)
    per_phase_main = collections.Counter()
    per_phase_app = collections.defaultdict(collections.Counter)
    for t, is_main, w, names, bins in parse_samples(tp):
        all_ms += w
        if not is_main or not names:
            continue
        main_ms += w
        self_main[names[0]] += w
        seen = set()
        app_frames = []
        for n, b in zip(names, bins):
            if b.startswith("Fusionha") and n not in seen:
                seen.add(n)
                app_frames.append(n)
        for n in app_frames:
            incl_app[n] += w
        for name, a, b in windows:
            if a <= t < b:
                per_phase[name][names[0]] += w
                per_phase_main[name] += w
                for n in app_frames:
                    per_phase_app[name][n] += w
                break
    out = [f"Time Profiler: {all_ms / 1000:.1f}s of samples, main thread {main_ms / 1000:.1f}s"]
    out.append("\nHeaviest main-thread symbols (self time):")
    for n, ms in self_main.most_common(25):
        out.append(f"  {ms:8.0f} ms  {100 * ms / max(main_ms, 1):5.1f}%  {short(n)}")
    out.append("\nHeaviest app frames on the main thread (inclusive):")
    for n, ms in incl_app.most_common(25):
        out.append(f"  {ms:8.0f} ms  {100 * ms / max(main_ms, 1):5.1f}%  {short(n)}")
    if windows:
        out.append("\nPer phase (main-thread samples, top self symbols, top app frames):")
        for name, a, b in windows:
            ms = per_phase_main[name]
            if ms <= 0:
                continue
            out.append(f"  {name}: main busy {ms:.0f} ms over {b - a:.1f}s ({100 * ms / 1000 / max(b - a, 0.001):.0f}%)")
            for n, v in per_phase[name].most_common(5):
                out.append(f"      self {v:7.0f} ms  {short(n, 100)}")
            for n, v in per_phase_app[name].most_common(6):
                out.append(f"      app  {v:7.0f} ms  {short(n, 100)}")
    return "\n".join(out)


def main(argv):
    out_json = None
    if "--json" in argv:
        i = argv.index("--json")
        out_json = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    phases = load_phases(argv[1])
    if not phases:
        print("No PERF phases found in", argv[1])
        return 1
    print("Activity perf — per phase")
    print("(hitch/s = ms of late frames per second; hangs = main-thread stalls > 250 ms; hang_ms = their total)\n")
    print(phase_table(phases))
    t = totals(phases)
    print("\nTotals:")
    for k, v in t.items():
        print(f"  {k:7s} " + "  ".join(f"{a}={b}" for a, b in v.items()))
    print("\nView counters per phase (count, total ms where timed):")
    print(counters(phases))
    if len(argv) >= 4:
        try:
            print("\n" + profile_report(argv[2], argv[3], phases))
        except Exception as exc:  # the probe numbers stand on their own
            print(f"\n(Time Profiler export could not be parsed: {exc})")
    if out_json:
        with open(out_json, "w") as fh:
            json.dump({"phases": phases, "totals": t}, fh, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
