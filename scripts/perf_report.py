#!/usr/bin/env python3
"""Summarise an Activity perf run (the CI "Activity perf" job).

    perf_report.py APP_LOG [SAMPLE_TXT ...] [--json OUT]

APP_LOG holds the `PERF {json}` lines App/Debug/PerfProbe.swift prints per phase
(frame pacing, main-thread hangs, CPU, memory, view counters). Optional `sample` reports (one per
phase) add the heaviest main-thread symbols and app frames.
Prints a plain-text report (also valid Markdown inside a code fence).
"""
import collections
import json
import re
import sys


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
    cols = [("phase", 26), ("wall_s", 7), ("fps", 6), ("hitch_ms_per_s", 8), ("hang_ms", 8), ("stalls_250ms", 7), ("bg_stall_ms", 8),
            ("max_frame_ms", 9), ("main_cpu_pct", 9), ("proc_cpu_pct", 9), ("mem_mb", 7), ("scroll_y", 8), ("content_h", 9)]
    heads = {"hitch_ms_per_s": "hitch/s", "stalls_250ms": "hangs", "bg_stall_ms": "bgStall", "max_frame_ms": "maxframe", "main_cpu_pct": "main%",
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


# MARK: `sample` call graphs

IDLE = {"mach_msg2_trap", "mach_msg_trap", "__psynch_cvwait", "semaphore_wait_trap", "__semwait_signal",
        "__workq_kernreturn", "kevent_id", "__ulock_wait", "__ulock_wait2"}
LINE = re.compile(r"^(?P<prefix>[\s+!:|]*)(?P<count>\d+)\s+(?P<sym>.*?)(?:\s+\(in (?P<lib>[^)]+)\))?(?:\s+\+\s+\S+)?(?:\s+\[[^\]]*\])?(?:\s+\S+:\d+)?\s*$")


def short(name, width=110):
    name = re.sub(r"\s+", " ", name)
    return name if len(name) <= width else name[: width - 1] + "…"


def parse_sample(path):
    """Main-thread nodes of a `sample` report: [(depth, count, symbol, lib)]."""
    nodes = []
    with open(path, errors="replace") as fh:
        lines = fh.read().splitlines()
    start = None
    for i, line in enumerate(lines):
        if "com.apple.main-thread" in line:
            start = i
            break
    if start is None:
        return nodes
    head = LINE.match(lines[start])
    base = len(head.group("prefix")) if head else 0
    for line in lines[start + 1:]:
        if not line.strip():
            break
        m = LINE.match(line)
        if not m:
            break
        depth = len(m.group("prefix"))
        if depth <= base:
            break
        nodes.append((depth, int(m.group("count")), m.group("sym").strip(), m.group("lib") or ""))
    return nodes, (int(head.group("count")) if head else 0)


def summarise_sample(path):
    parsed = parse_sample(path)
    if not parsed or not parsed[0]:
        return f"  {path}: no main-thread call graph"
    nodes, total = parsed
    self_counts = collections.Counter()
    incl_app = collections.Counter()
    incl_ui = collections.Counter()
    stack = []  # [depth, symbol, lib, own samples]
    def close(entry):
        if entry[3] > 0:
            self_counts[entry[1]] += entry[3]
    for depth, count, sym, lib in nodes:
        while stack and stack[-1][0] >= depth:
            close(stack.pop())
        if stack:
            stack[-1][3] -= count
        if sym not in {e[1] for e in stack}:
            if lib.startswith("Fusionha"):
                incl_app[sym] += count
            elif lib in ("SwiftUI", "SwiftUICore", "AttributeGraph", "UIKitCore", "QuartzCore"):
                incl_ui[sym] += count
        stack.append([depth, sym, lib, count])
    while stack:
        close(stack.pop())
    idle = sum(v for k, v in self_counts.items() if k in IDLE)
    busy = max(total - idle, 0)
    name = path.rsplit("sample-", 1)[-1].removesuffix(".txt")
    out = [f"  {name}: {total} main-thread samples, busy {busy} ({100 * busy / max(total, 1):.0f}%)"]
    for k, v in [kv for kv in self_counts.most_common(40) if kv[0] not in IDLE][:12]:
        out.append(f"      self {v:6d} {100 * v / max(total, 1):5.1f}%  {short(k, 100)}")
    for k, v in [kv for kv in incl_app.most_common(20) if kv[1] < total * 0.97][:14]:
        out.append(f"      app  {v:6d} {100 * v / max(total, 1):5.1f}%  {short(k, 100)}")
    for k, v in incl_ui.most_common(40):
        if v < total * 0.97 and v > total * 0.05:
            out.append(f"      ui   {v:6d} {100 * v / max(total, 1):5.1f}%  {short(k, 100)}")
    return "\n".join(out[:40])


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
    print("(hitch/s = ms of late frames per second; hangs = main-thread stalls > 250 ms; hang_ms = their total;\n bgStall = ms a background thread was also stalled: the whole process/host, not the main thread)\n")
    print(phase_table(phases))
    t = totals(phases)
    print("\nTotals:")
    for k, v in t.items():
        print(f"  {k:7s} " + "  ".join(f"{a}={b}" for a, b in v.items()))
    print("\nView counters per phase (count, total ms where timed):")
    print(counters(phases))
    samples = argv[2:]
    if samples:
        print("\nMain-thread samples per phase (macOS `sample`, 1 ms):")
        for path in samples:
            try:
                print(summarise_sample(path))
            except Exception as exc:  # the probe numbers stand on their own
                print(f"  {path}: could not be parsed ({exc})")
    if out_json:
        with open(out_json, "w") as fh:
            json.dump({"phases": phases, "totals": t}, fh, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
