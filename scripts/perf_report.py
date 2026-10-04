#!/usr/bin/env python3
"""Summarise an Activity perf run (the CI "Activity perf" job).

    perf_report.py APP_LOG [--json OUT]

APP_LOG holds the `PERF {json}` lines App/Debug/PerfProbe.swift prints per phase
(frame pacing, main-thread hangs, CPU, memory, view counters) and, per phase, the in-app main-thread
sampler's heaviest symbols, overall and while the main run loop was stuck.
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


# MARK: in-app main-thread samples

def load_stacks(path):
    out = []
    with open(path, errors="replace") as fh:
        for line in fh:
            idx = line.find("PERF {")
            if idx < 0:
                continue
            try:
                obj = json.loads(line[idx + 5:])
            except json.JSONDecodeError:
                continue
            if obj.get("event") == "stacks":
                out.append(obj)
    return out


def stacks_report(stacks, rows=10):
    out = []
    for st in stacks:
        n, stall = st.get("samples", 0), st.get("stall_samples", 0)
        if n == 0:
            continue
        out.append(f"\n  {st['phase']}: {n} samples (5 ms), {stall} while the main run loop was stuck > 100 ms")
        for key, label, total in (("self", "self", n), ("app", "app ", n), ("incl", "incl", n),
                                  ("self_stall", "STALL self", stall), ("app_stall", "STALL app ", stall),
                                  ("incl_stall", "STALL incl", stall)):
            if total == 0:
                continue
            for name, count in st.get(key, [])[:rows]:
                out.append(f"      {label} {count:5d} {100 * count / total:5.1f}%  {name}")
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
    print("(hitch/s = ms of late frames per second; hangs = main-thread stalls > 250 ms; hang_ms = their total;\n bgStall = ms a background thread was also stalled: the whole process/host, not the main thread)\n")
    print(phase_table(phases))
    t = totals(phases)
    print("\nTotals:")
    for k, v in t.items():
        print(f"  {k:7s} " + "  ".join(f"{a}={b}" for a, b in v.items()))
    print("\nView counters per phase (count, total ms where timed):")
    print(counters(phases))
    stacks = load_stacks(argv[1])
    if stacks:
        print("\nMain-thread samples per phase (self = leaf frame; app/incl = anywhere on the stack;")
        print("STALL = samples taken while one run-loop pass had lasted > 100 ms):")
        print(stacks_report(stacks))
    if out_json:
        with open(out_json, "w") as fh:
            json.dump({"phases": phases, "totals": t}, fh, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
