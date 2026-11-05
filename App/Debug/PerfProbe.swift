import SwiftUI
import UIKit
import Darwin

// A DEBUG-only performance harness for CI (the "perf" job). When the app is
// launched with FUSIONHA_PERF set, it drives a fixed script: by default open
// Activity → History, sit idle, scroll through several pages, switch through
// the other tabs and Wanted; with FUSIONHA_PERF_SCRIPT=library, the Library
// grid (PerfProbe+Library.swift); v2open and v2session, the v2 Duo (PerfProbe+Open.swift,
// PerfProbe+Session.swift). Each phase prints one `PERF {json}` line to stderr with the
// frame pacing (hitches), main-thread and process CPU, memory and a few view
// counters. scripts/perf_report.py turns those lines (and an optional
// Time Profiler trace) into the job summary. Release builds compile none of it.

#if DEBUG
@MainActor
final class PerfProbe: NSObject {
    private static var shared: PerfProbe?

    static func startIfRequested(model: AppModel) {
        guard PerfCount.enabled, shared == nil else { return }
        let probe = PerfProbe(model: model)
        shared = probe
        probe.start()
    }

    private struct FrameStats {
        var frames = 0
        var hitches = 0
        var hitchTime: Double = 0
        var maxDelta: Double = 0
        var stalls = 0
        var hangTime: Double = 0
        /// Frames longer than 25, 50 and 100 ms, and the time spent in > 25 ms frames.
        var over25 = 0
        var over50 = 0
        var over100 = 0
        var longTime: Double = 0
    }

    let model: AppModel
    private let mainThread: thread_act_t = mach_thread_self()
    private var link: CADisplayLink?
    private var stats = FrameStats()
    private var lastTimestamp: CFTimeInterval = 0
    private var scrolling = false
    /// Points per second; negative scrolls up.
    var scrollSpeed: CGFloat = 1800
    private weak var scrollView: UIScrollView?
    /// The Library script: drive the scroll view with the tallest content (the
    /// grid, not the title page beside it on a Spread).
    var prefersTallest = false
    /// The v2 open script (PerfProbe+Open.swift): every frame's timestamp and
    /// length while set, and a check run on each frame.
    var frameLog: [(t: Double, delta: Double)]?
    var frameWatch: (() -> Void)?

    private var phaseName = ""
    private var phaseWall: CFTimeInterval = 0
    private var phaseEpoch: Double = 0
    private var phaseMainCPU: Double = 0
    private var phaseProcCPU: Double = 0
    private var phaseCounts: [String: Int] = [:]
    private var phaseTimes: [String: Double] = [:]

    private init(model: AppModel) {
        self.model = model
    }

    /// A background thread that sleeps 10 ms at a time and records how late it
    /// wakes. If it is late too, the whole process (or the simulator host) was
    /// stalled; if only frames are late, the main thread was blocked or busy.
    nonisolated private static let stallLock = NSLock()
    nonisolated(unsafe) private static var bgStallTime: Double = 0
    nonisolated(unsafe) private static var bgStalls = 0

    nonisolated private static func startStallWatch() {
        let thread = Thread {
            while true {
                let start = CACurrentMediaTime()
                usleep(10_000)
                let late = CACurrentMediaTime() - start - 0.010
                if late > 0.25 {
                    stallLock.lock(); bgStalls += 1; bgStallTime += late; stallLock.unlock()
                }
            }
        }
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    nonisolated private static func stallSnapshot() -> (Int, Double) {
        stallLock.lock(); defer { stallLock.unlock() }
        return (bgStalls, bgStallTime)
    }
    private var phaseBgStalls = 0
    private var phaseBgStallTime: Double = 0

    private func start() {
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
        Self.startStallWatch()
        #if arch(arm64)
        MainSampler.shared.start()
        #endif
        emit(["event": "start", "epoch": Date().timeIntervalSince1970])
        Task { await run() }
    }

    // MARK: Script

    private func run() async {
        let env = ProcessInfo.processInfo.environment
        let warmup = Double(env["FUSIONHA_PERF_DELAY"] ?? "") ?? 8
        if env["FUSIONHA_PERF_SCRIPT"] == "library" { return await runLibrary(warmup: warmup) }
        if env["FUSIONHA_PERF_SCRIPT"] == "v2open" { return await runOpen(warmup: warmup) }
        if env["FUSIONHA_PERF_SCRIPT"] == "v2session" { return await runSession(warmup: warmup) }
        if env["FUSIONHA_PERF_SCRIPT"] == "v2frames" { return await runFrames(warmup: warmup) }
        await phase("warmup", warmup)

        model.tab = .activity
        await phase("history.load", 6)
        await phase("history.idle", 6)
        await phase("history.scroll", 25, scroll: true)
        await phase("history.idle-after-scroll", 6)

        for tab in ["queue", "blocklist", "tasks", "audit", "indexers"] {
            await switchActivityTab(tab)
            await phase("\(tab).load", 4)
            await phase("\(tab).idle", 5)
            await phase("\(tab).scroll", 8, scroll: true)
        }
        await switchActivityTab("history")
        await phase("history.return", 5)

        await switchActivityTab("wanted")
        await phase("wanted.load", 4)
        await phase("wanted.idle", 5)
        await phase("wanted.scroll", 8, scroll: true)

        emit(["event": "done"])
        FileHandle.standardError.write(Data("PERF DONE\n".utf8))
    }

    private func switchActivityTab(_ raw: String) async {
        NotificationCenter.default.post(name: .perfActivityTab, object: raw)
        try? await Task.sleep(for: .milliseconds(50))
        // Start every tab at the top, like a user switching tabs would see it.
        if let sv = findScrollView() {
            sv.setContentOffset(CGPoint(x: sv.contentOffset.x, y: -sv.adjustedContentInset.top), animated: false)
        }
    }

    /// `action` runs once the phase has begun (the open script's tap).
    func phase(_ name: String, _ seconds: Double, scroll: Bool = false, action: (() -> Void)? = nil) async {
        // Lets CI start a `sample` of the process for exactly this phase.
        FileHandle.standardError.write(Data("PERF-BEGIN \(name) \(Int(seconds.rounded()))\n".utf8))
        begin(name)
        scrollView = scroll ? findScrollView() : nil
        scrolling = scroll
        action?()
        try? await Task.sleep(for: .seconds(seconds))
        scrolling = false
        end()
    }

    private func begin(_ name: String) {
        phaseName = name
        phaseWall = CACurrentMediaTime()
        phaseEpoch = Date().timeIntervalSince1970
        phaseMainCPU = mainCPU()
        phaseProcCPU = processCPU()
        let snap = PerfCount.snapshot()
        phaseCounts = snap.counts
        phaseTimes = snap.times
        stats = FrameStats()
        (phaseBgStalls, phaseBgStallTime) = Self.stallSnapshot()
        #if arch(arm64)
        MainSampler.shared.reset()
        #endif
    }

    private func end() {
        let wall = CACurrentMediaTime() - phaseWall
        let main = mainCPU() - phaseMainCPU
        let proc = processCPU() - phaseProcCPU
        let snap = PerfCount.snapshot()
        var counts: [String: Int] = [:]
        for (key, value) in snap.counts where value - (phaseCounts[key] ?? 0) > 0 { counts[key] = value - (phaseCounts[key] ?? 0) }
        var times: [String: Double] = [:]
        for (key, value) in snap.times where value - (phaseTimes[key] ?? 0) > 0 {
            times[key] = ((value - (phaseTimes[key] ?? 0)) * 1000 * 10).rounded() / 10
        }
        let sv = findScrollView()
        let (bgStalls, bgTime) = Self.stallSnapshot()
        emit([
            "bg_stalls": bgStalls - phaseBgStalls,
            "bg_stall_ms": Int((bgTime - phaseBgStallTime) * 1000),
            "event": "phase",
            "phase": phaseName,
            "epoch": phaseEpoch,
            "wall_s": round3(wall),
            "frames": stats.frames,
            "fps": round1(Double(stats.frames) / max(wall, 0.001)),
            "hitches": stats.hitches,
            "hitch_ms_per_s": round1(stats.hitchTime * 1000 / max(wall, 0.001)),
            "max_frame_ms": round1(stats.maxDelta * 1000),
            "stalls_250ms": stats.stalls,
            "hang_ms": Int(stats.hangTime * 1000),
            "long_25": stats.over25,
            "long_50": stats.over50,
            "long_100": stats.over100,
            "long_ms": Int(stats.longTime * 1000),
            "main_ms": Int(main * 1000),
            "main_cpu_pct": round1(main / max(wall, 0.001) * 100),
            "proc_cpu_pct": round1(proc / max(wall, 0.001) * 100),
            "mem_mb": round1(footprintMB()),
            "scroll_y": Int(sv?.contentOffset.y ?? 0),
            "content_h": Int(sv?.contentSize.height ?? 0),
            "counts": counts,
            "times_ms": times,
        ])
        #if arch(arm64)
        var stacks = MainSampler.shared.report()
        stacks["event"] = "stacks"
        stacks["phase"] = phaseName
        emit(stacks)
        #endif
    }

    // MARK: Frames + scroll driver

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        let delta = lastTimestamp > 0 ? now - lastTimestamp : 0
        lastTimestamp = now
        guard delta > 0 else { return }
        let expected = link.duration > 0 ? link.duration : 1.0 / 60
        stats.frames += 1
        if delta > expected * 1.5 {
            stats.hitches += 1
            stats.hitchTime += delta - expected
        }
        if delta > 0.25 { stats.stalls += 1; stats.hangTime += delta }
        if delta > 0.025 { stats.over25 += 1; stats.longTime += delta }
        if delta > 0.05 { stats.over50 += 1 }
        if delta > 0.1 { stats.over100 += 1 }
        stats.maxDelta = max(stats.maxDelta, delta)
        frameLog?.append((now, delta))
        frameWatch?()

        guard scrolling else { return }
        if scrollView?.window == nil { scrollView = findScrollView() }
        guard let sv = scrollView else { return }
        // A steady fling; a stalled main thread jumps further, as a real fling would.
        let step = scrollSpeed * CGFloat(min(delta, 0.1))
        let minY = -sv.adjustedContentInset.top
        let maxY = max(minY, sv.contentSize.height - sv.bounds.height + sv.adjustedContentInset.bottom)
        let y = min(max(sv.contentOffset.y + step, minY), maxY)
        sv.setContentOffset(CGPoint(x: sv.contentOffset.x, y: y), animated: false)
    }

    // MARK: Readings

    private func mainCPU() -> Double {
        var info = thread_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<thread_basic_info>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                thread_info(mainThread, thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }
        return Double(info.user_time.seconds) + Double(info.user_time.microseconds) / 1e6
            + Double(info.system_time.seconds) + Double(info.system_time.microseconds) / 1e6
    }

    private func processCPU() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        return Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1e6
            + Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1e6
    }

    private func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return kr == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
    }

    private func round1(_ v: Double) -> Double { (v * 10).rounded() / 10 }
    private func round3(_ v: Double) -> Double { (v * 1000).rounded() / 1000 }

    func emit(_ object: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return }
        FileHandle.standardError.write(Data("PERF ".utf8) + data + Data("\n".utf8))
    }
}
#else
@MainActor
enum PerfProbe {
    static func startIfRequested(model: AppModel) {}
}
#endif
