#if DEBUG
import Foundation
import QuartzCore
import Darwin

/// A DEBUG-only main-thread hang check for CI (the A–Z scrub sweep in the
/// screenshot job). A background thread pings the main queue every 50ms; a
/// ping the main thread has not answered within `limit` prints a `HANG` line
/// to stderr, and its recovery prints how long it took. If the watchdog's own
/// sleep overshoots, the whole process (or the simulator host) was paused, so
/// that stretch is not blamed on the main thread. CI fails the job on any
/// `HANG` line, or when the scripted check never prints its DONE marker.
enum HangWatchdog {
    /// The longest the main thread may go without answering a ping.
    static let limit: Double = 1.0
    /// The share of one core the main thread may use on an idle page. Loops
    /// on screen must be render-loop animations (`RepeatForever`), not timelines.
    static let idleLimit: Double = 0.25

    private static let lock = NSLock()
    nonisolated(unsafe) private static var started = false
    nonisolated(unsafe) private static var sentAt: Double?
    nonisolated(unsafe) private static var reported = false

    /// Starts the watchdog thread (once).
    static func start() {
        lock.lock()
        let first = !started
        started = true
        lock.unlock()
        guard first else { return }
        let thread = Thread { watch() }
        thread.qualityOfService = .userInteractive
        thread.start()
        mark("SCRUB-CHECK watchdog on (limit \(limit)s)")
    }

    /// One line on stderr (unbuffered), for CI to grep.
    static func mark(_ line: String) {
        FileHandle.standardError.write(Data("\(line)\n".utf8))
    }

    private static func watch() {
        var last = CACurrentMediaTime()
        while true {
            usleep(50_000)
            let now = CACurrentMediaTime()
            let paused = now - last > 0.5
            last = now
            lock.lock()
            if paused, sentAt != nil, !reported { sentAt = now }
            if let sent = sentAt {
                if !reported, now - sent > limit {
                    reported = true
                    mark(String(format: "HANG main thread has not answered for %.1fs", now - sent))
                }
                lock.unlock()
                continue
            }
            sentAt = now
            lock.unlock()
            DispatchQueue.main.async { answered() }
        }
    }

    private static func answered() {
        lock.lock()
        let sent = sentAt, wasReported = reported
        sentAt = nil
        reported = false
        lock.unlock()
        if wasReported, let sent {
            mark(String(format: "HANG main thread answered again after %.1fs", CACurrentMediaTime() - sent))
        }
    }

    /// CI (`FUSIONHA_SCREENSHOT_SCRUB=hang-selftest`): blocks the main thread
    /// for 2.5s, so the job can prove the watchdog catches a stall.
    @MainActor
    static func selfTest() async {
        start()
        try? await Task.sleep(for: .milliseconds(500))
        mark("SCRUB-CHECK self-test: blocking the main thread for 2.5s")
        Thread.sleep(forTimeInterval: 2.5)
        try? await Task.sleep(for: .milliseconds(500))
        mark("SCRUB-CHECK DONE")
    }

    /// After the scripted scroll stops: the main thread must go quiet. A
    /// layout feedback loop that never blocks for a whole second, or views
    /// re-rendering every frame, still keep it busy, so a main thread busier
    /// than `idleLimit` while idle is reported as a hang.
    @MainActor
    static func checkIdle(seconds: Double) async {
        let thread = mach_thread_self()
        startSampler()
        let before = cpuTime(thread)
        try? await Task.sleep(for: .seconds(seconds))
        let busy = (cpuTime(thread) - before) / seconds
        mark(String(format: "SCRUB-CHECK idle main-thread cpu %.0f%%", busy * 100))
        if busy > idleLimit {
            mark("HANG main thread stayed busy while the page was idle")
            reportSamples()
        }
    }

    // MARK: Where the idle main thread went (PerfProbe's MainSampler)

    @MainActor private static var sampling = false

    @MainActor
    private static func startSampler() {
        #if arch(arm64)
        if !sampling { sampling = true; MainSampler.shared.start() }
        MainSampler.shared.reset()
        #endif
    }

    /// The busiest app frames and inclusive frames of the idle window, as
    /// `SCRUB-CHECK sample` lines (mangled; CI demangles them).
    private static func reportSamples() {
        #if arch(arm64)
        let report = MainSampler.shared.report(limit: 25)
        mark("SCRUB-CHECK sample total \(report["samples"] ?? 0)")
        for kind in ["app", "incl"] {
            for row in (report[kind] as? [[Any]]) ?? [] where row.count == 2 {
                mark("SCRUB-CHECK sample \(kind) \(row[1]) \(row[0])")
            }
        }
        #endif
    }

    private static func cpuTime(_ thread: thread_act_t) -> Double {
        var info = thread_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<thread_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                thread_info(thread, thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }
        return Double(info.user_time.seconds) + Double(info.user_time.microseconds) / 1e6
            + Double(info.system_time.seconds) + Double(info.system_time.microseconds) / 1e6
    }
}
#endif
