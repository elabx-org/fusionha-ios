import SwiftUI
import UIKit
import Darwin

#if DEBUG && arch(arm64)
/// An in-process sampler of the main thread (the CI runner's `sample` and
/// xctrace both stall or never finish against simulator apps). A background
/// thread suspends the main thread every 5 ms, reads its pc and walks the frame
/// pointers into a preallocated buffer (nothing that could take a lock the
/// suspended thread holds), resumes it, then records the stack. Samples taken
/// while the main run loop has been inside one iteration for > 100 ms are also
/// counted as "stall" samples, so hangs get their own profile.
final class MainSampler: @unchecked Sendable {
    static let shared = MainSampler()

    private var mainThread: thread_act_t = 0
    private var stackLow: UInt = 0
    private var stackHigh: UInt = 0
    private let buffer = UnsafeMutablePointer<UInt>.allocate(capacity: 160)
    private let lock = NSLock()
    private var stacks: [[UInt]: (all: Int, stall: Int)] = [:]
    private var total = 0
    private var stallTotal = 0
    private var symbols: [UInt: (name: String, image: String)] = [:]

    // Written by the main run loop observer, read by the sampler (benign races).
    nonisolated(unsafe) private static var lastActivity: Double = 0
    nonisolated(unsafe) private static var waiting = true

    /// Call on the main thread.
    func start() {
        mainThread = mach_thread_self()
        let me = pthread_self()
        stackHigh = UInt(bitPattern: pthread_get_stackaddr_np(me))
        stackLow = stackHigh - UInt(pthread_get_stacksize_np(me))
        let observer = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.allActivities.rawValue, true, 0) { _, activity in
            MainSampler.lastActivity = CACurrentMediaTime()
            MainSampler.waiting = activity == .beforeWaiting
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        let thread = Thread { [self] in loop() }
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    private func loop() {
        while true {
            usleep(5_000)
            let stalled = !Self.waiting && CACurrentMediaTime() - Self.lastActivity > 0.1
            guard thread_suspend(mainThread) == KERN_SUCCESS else { continue }
            var state = arm_thread_state64_t()
            var count = mach_msg_type_number_t(MemoryLayout<arm_thread_state64_t>.size / MemoryLayout<natural_t>.size)
            let kr = withUnsafeMutablePointer(to: &state) {
                $0.withMemoryRebound(to: natural_t.self, capacity: Int(count)) {
                    thread_get_state(mainThread, thread_state_flavor_t(ARM_THREAD_STATE64), $0, &count)
                }
            }
            var n = 0
            if kr == KERN_SUCCESS {
                buffer[0] = UInt(state.__pc); n = 1
                var fp = UInt(state.__fp)
                while n < 160, fp >= stackLow, fp + 16 <= stackHigh, fp & 7 == 0 {
                    let frame = UnsafePointer<UInt>(bitPattern: fp)!
                    let next = frame[0]
                    let ret = frame[1]
                    if ret == 0 { break }
                    buffer[n] = ret; n += 1
                    if next <= fp { break }
                    fp = next
                }
            }
            thread_resume(mainThread)
            guard n > 0 else { continue }
            let stack = Array(UnsafeBufferPointer(start: buffer, count: n))
            lock.lock()
            let old = stacks[stack] ?? (0, 0)
            stacks[stack] = (old.all + 1, old.stall + (stalled ? 1 : 0))
            total += 1
            if stalled { stallTotal += 1 }
            lock.unlock()
        }
    }

    /// Clears the samples (phase start).
    func reset() {
        lock.lock(); stacks.removeAll(keepingCapacity: true); total = 0; stallTotal = 0; lock.unlock()
    }

    private func symbol(_ address: UInt) -> (name: String, image: String) {
        if let hit = symbols[address] { return hit }
        var info = Dl_info()
        var result = (name: String(format: "0x%lx", address), image: "?")
        // A return address points after the call; look up the call itself.
        if dladdr(UnsafeRawPointer(bitPattern: address &- 1), &info) != 0 {
            let image = info.dli_fname.map { String(cString: $0) }.map { ($0 as NSString).lastPathComponent } ?? "?"
            if let name = info.dli_sname {
                result = (String(cString: name), image)
            } else if let base = info.dli_fbase {
                result = (String(format: "%@+0x%lx", image, address - UInt(bitPattern: base)), image)
            }
        }
        symbols[address] = result
        return result
    }

    /// Top self and inclusive symbols since the last reset, for the perf report.
    func report(limit: Int = 45) -> [String: Any] {
        lock.lock()
        let snapshot = stacks
        let all = total
        let stall = stallTotal
        lock.unlock()
        let appImage = (Bundle.main.executablePath as NSString?)?.lastPathComponent ?? "Fusionha"
        var selfAll: [String: Int] = [:], selfStall: [String: Int] = [:]
        var inclAll: [String: Int] = [:], inclStall: [String: Int] = [:]
        var appAll: [String: Int] = [:], appStall: [String: Int] = [:]
        for (stack, counts) in snapshot {
            let syms = stack.map(symbol)
            let leaf = "\(syms[0].name) [\(syms[0].image)]"
            selfAll[leaf, default: 0] += counts.all
            if counts.stall > 0 { selfStall[leaf, default: 0] += counts.stall }
            var seen = Set<String>()
            for s in syms where seen.insert(s.name).inserted {
                let key = "\(s.name) [\(s.image)]"
                inclAll[key, default: 0] += counts.all
                if counts.stall > 0 { inclStall[key, default: 0] += counts.stall }
                if s.image == appImage || s.image.hasPrefix("Fusionha") {
                    appAll[s.name, default: 0] += counts.all
                    if counts.stall > 0 { appStall[s.name, default: 0] += counts.stall }
                }
            }
        }
        func top(_ d: [String: Int], cap: Int) -> [[Any]] {
            d.filter { $0.value < cap }.sorted { $0.value > $1.value }.prefix(limit).map { [$0.key, $0.value] }
        }
        // Inclusive frames present in (nearly) every sample are the run loop
        // scaffolding; leave them out.
        return [
            "samples": all, "stall_samples": stall,
            "self": top(selfAll, cap: Int.max), "self_stall": top(selfStall, cap: Int.max),
            "app": top(appAll, cap: Int(Double(all) * 0.97) + 1), "app_stall": top(appStall, cap: Int(Double(stall) * 0.97) + 1),
            "incl": top(inclAll, cap: Int(Double(all) * 0.6)), "incl_stall": top(inclStall, cap: Int(Double(stall) * 0.6)),
        ]
    }
}
#endif
