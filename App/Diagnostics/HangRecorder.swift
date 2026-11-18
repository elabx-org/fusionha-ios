import Foundation
import QuartzCore
import UIKit
import Darwin

/// Catches a frozen app on the owner's phone (build 1237: random hangs after
/// opening titles and moving the split, ended by killing the app; MetricKit
/// can miss a hang the user ends by force-quitting). A background thread
/// pings the main thread every 250 ms; unanswered for `limit`, it samples
/// where the main thread is stuck (three stacks, 300 ms apart), adds the
/// recent trail (`note`) and writes `hang-report.txt` to Application Support.
/// If the main thread comes back, the time it took is added. The next launch
/// offers the report (`HangReportBanner`); nothing leaves the device unless
/// the owner copies it.
enum HangRecorder {
    static let limit: Double = 2.0
    private static let lock = NSLock()
    nonisolated(unsafe) private static var started = false
    nonisolated(unsafe) private static var sentAt: Double?
    nonisolated(unsafe) private static var reportedAt: Double?
    nonisolated(unsafe) private static var paused = false
    nonisolated(unsafe) private static var trail: [String] = []
    nonisolated(unsafe) private static var mainThread: thread_act_t = 0
    nonisolated(unsafe) private static var stackLow: UInt = 0
    nonisolated(unsafe) private static var stackHigh: UInt = 0
    /// Filled while the main thread is suspended: nothing may allocate then
    /// (it could hold the allocator's lock).
    private static let buffer = UnsafeMutablePointer<UInt>.allocate(capacity: 60)
    private static let addressMask: UInt = 0x0000_7FFF_FFFF_FFFF  // drops pointer-auth bits

    static var reportURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("hang-report.txt")
    }

    /// Call once, on the main thread, at launch.
    @MainActor
    static func start() {
        lock.lock()
        defer { lock.unlock() }
        guard !started else { return }
        started = true
        mainThread = mach_thread_self()
        let me = pthread_self()
        stackHigh = UInt(bitPattern: pthread_get_stackaddr_np(me))
        stackLow = stackHigh - UInt(pthread_get_stacksize_np(me))
        let center = NotificationCenter.default
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in setPaused(true) }
        center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { _ in setPaused(false) }
        let thread = Thread { watch() }
        thread.qualityOfService = .userInteractive
        thread.name = "fusionha.hang-recorder"
        thread.start()
        #if DEBUG
        // FUSIONHA_HANG_SELFTEST=1: freeze the main thread for 3.5 s after
        // launch, to prove the recorder and the banner end to end.
        if ProcessInfo.processInfo.environment["FUSIONHA_HANG_SELFTEST"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                note("self-test: blocking the main thread for 3.5 s")
                Thread.sleep(forTimeInterval: 3.5)
            }
        }
        #endif
    }

    /// One line of the trail: what the app just did (opens, closes, the seam).
    static func note(_ line: String) {
        let stamp = Self.clock.string(from: Date())
        lock.lock()
        trail.append("\(stamp) \(line)")
        if trail.count > 40 { trail.removeFirst(trail.count - 40) }
        lock.unlock()
    }

    /// A safety net rescued a stuck title (no freeze, so no stacks): keeps
    /// the trail for the next launch's banner, unless a report is waiting.
    static func stuck(_ what: String) {
        note("RESCUE: \(what)")
        guard !FileManager.default.fileExists(atPath: reportURL.path) else { return }
        lock.lock()
        let lines = trail
        lock.unlock()
        let info = Bundle.main.infoDictionary
        var text = "fusionha rescued a stuck title: \(what)\n"
        text += "app \(info?["CFBundleShortVersionString"] ?? "?") (\(info?["CFBundleVersion"] ?? "?"))\n"
        text += "at \(ISO8601DateFormatter().string(from: Date()))\n\nRecent:\n"
        text += lines.map { "  \($0)\n" }.joined()
        try? FileManager.default.createDirectory(at: reportURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? text.write(to: reportURL, atomically: true, encoding: .utf8)
    }

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private static func setPaused(_ value: Bool) {
        lock.lock()
        paused = value
        sentAt = nil
        lock.unlock()
    }

    private static func watch() {
        var last = CACurrentMediaTime()
        while true {
            usleep(250_000)
            let now = CACurrentMediaTime()
            // A long sleep means the whole process was suspended: not a hang.
            let suspended = now - last > 1.5
            last = now
            lock.lock()
            if paused || suspended { sentAt = nil }
            if let sent = sentAt {
                let stuck = now - sent
                let report = stuck > limit && reportedAt == nil
                if report { reportedAt = sent }
                let lines = report ? trail : []
                lock.unlock()
                if report { write(stuckFor: stuck, trail: lines) }
                continue
            }
            if paused { lock.unlock(); continue }
            sentAt = now
            lock.unlock()
            DispatchQueue.main.async { answered() }
        }
    }

    private static func answered() {
        lock.lock()
        let sent = sentAt, hung = reportedAt
        sentAt = nil
        reportedAt = nil
        lock.unlock()
        if let hung, sent != nil {
            append(String(format: "\nThe main thread answered again after %.1f s.\n", CACurrentMediaTime() - hung))
        }
    }

    private static func write(stuckFor seconds: Double, trail: [String]) {
        let info = Bundle.main.infoDictionary
        var machine = utsname()
        uname(&machine)
        let model = withUnsafeBytes(of: &machine.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        var text = "fusionha froze: the main thread did not answer for \(String(format: "%.1f", seconds)) s\n"
        text += "app \(info?["CFBundleShortVersionString"] ?? "?") (\(info?["CFBundleVersion"] ?? "?")) · \(model) · iOS \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
        text += "at \(ISO8601DateFormatter().string(from: Date()))\n\nRecent:\n"
        text += trail.map { "  \($0)\n" }.joined()
        for sample in 1...3 {
            text += "\nMain thread, sample \(sample) of 3:\n"
            text += stack().enumerated().map { "  \($0.offset) \($0.element)\n" }.joined()
            if sample < 3 { usleep(300_000) }
        }
        try? FileManager.default.createDirectory(at: reportURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? text.write(to: reportURL, atomically: true, encoding: .utf8)
    }

    private static func append(_ line: String) {
        guard let handle = try? FileHandle(forWritingTo: reportURL) else { return }
        handle.seekToEndOfFile()
        handle.write(Data(line.utf8))
        try? handle.close()
    }

    /// The main thread's return addresses, symbolicated: suspend it, read its
    /// pc and walk the frame pointers, resume it, then look the names up.
    private static func stack() -> [String] {
        #if arch(arm64)
        var n = 0
        guard thread_suspend(mainThread) == KERN_SUCCESS else { return ["(could not suspend the main thread)"] }
        var state = arm_thread_state64_t()
        var count = mach_msg_type_number_t(MemoryLayout<arm_thread_state64_t>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &state) {
            $0.withMemoryRebound(to: natural_t.self, capacity: Int(count)) {
                thread_get_state(mainThread, thread_state_flavor_t(ARM_THREAD_STATE64), $0, &count)
            }
        }
        if kr == KERN_SUCCESS {
            buffer[0] = UInt(state.__pc) & addressMask
            n = 1
            var fp = UInt(state.__fp)
            while n < 60, fp >= stackLow, fp + 16 <= stackHigh, fp & 7 == 0 {
                let frame = UnsafePointer<UInt>(bitPattern: fp)!
                let ret = frame[1] & addressMask
                if ret == 0 { break }
                buffer[n] = ret
                n += 1
                if frame[0] <= fp { break }
                fp = frame[0]
            }
        }
        thread_resume(mainThread)
        return UnsafeBufferPointer(start: buffer, count: n).map(symbol)
        #else
        return ["(stacks are recorded on arm64 only)"]
        #endif
    }

    private static func symbol(_ address: UInt) -> String {
        var info = Dl_info()
        guard dladdr(UnsafeRawPointer(bitPattern: address &- 1), &info) != 0 else { return String(format: "0x%lx", address) }
        let image = info.dli_fname.map { (String(cString: $0) as NSString).lastPathComponent } ?? "?"
        let offset = address - UInt(bitPattern: info.dli_fbase)
        let name = info.dli_sname.map { String(cString: $0) } ?? "?"
        return "\(image) +0x\(String(offset, radix: 16)) \(name)"
    }
}
