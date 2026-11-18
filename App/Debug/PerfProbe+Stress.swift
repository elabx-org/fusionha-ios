import SwiftUI
import QuartzCore

// The perf probe's stress script (FUSIONHA_PERF_SCRIPT=v2stress): on the
// iPhone Duo's flat open inner display, random opens, swaps (a title opened
// over another), seam drags and flicks, and closes, at random gaps, a third of
// them under 60 ms so actions overlap a slide, a spring or a landing. Hunts
// the owner's random hang (build 1237, 2026-11-18: "hangs and nothing works
// until I kill the app" after opening titles and adjusting the split).
//
// Prints `STRESS <n> <action>` per action; `HANG ...` (HangWatchdog, limit 1s)
// followed by the sampler's stall stacks; and `STUCK seam ...` when the seam
// stays mid-move (`DuoSeamDrag.live` set) for 3 s with no action running.
// FUSIONHA_STRESS_STEPS sets the count (default 300).

#if DEBUG
extension PerfProbe {
    private static let stressTitles = [1, 2, 8, 10]

    func runStress(warmup: Double) async {
        UserDefaults.standard.set(true, forKey: "v2.splitHandle.used")
        model.pendingAllTitles = true
        model.tab = .library
        let start = CACurrentMediaTime()
        while !(model.libraryLoaded && model.library.count > 100), CACurrentMediaTime() - start < 60 {
            try? await Task.sleep(for: .milliseconds(250))
        }
        #if arch(arm64)
        MainSampler.shared.reset()
        #endif
        HangWatchdog.onHang = {
            #if arch(arm64)
            let report = MainSampler.shared.report(limit: 30)
            for kind in ["app_stall", "self_stall", "incl_stall"] {
                for row in (report[kind] as? [[Any]]) ?? [] where row.count == 2 {
                    HangWatchdog.mark("HANG-STACK \(kind) \(row[1]) \(row[0])")
                }
            }
            #endif
        }
        HangWatchdog.start()
        try? await Task.sleep(for: .seconds(warmup))
        let steps = Int(ProcessInfo.processInfo.environment["FUSIONHA_STRESS_STEPS"] ?? "") ?? 300
        var quietSince = CACurrentMediaTime()
        for n in 1...steps {
            #if arch(arm64)
            MainSampler.shared.reset()
            #endif
            let action = stressAction()
            HangWatchdog.mark("STRESS \(n) \(action) open=\(model.presentedItem?.id ?? 0) live=\(stressLive())")
            let gap = Double.random(in: 0...1) < 0.33 ? Double.random(in: 0...0.06) : Double.random(in: 0.2...1.4)
            try? await Task.sleep(for: .seconds(gap))
            // Every 25 steps, sit still and check the seam came to rest.
            if n % 25 == 0 {
                try? await Task.sleep(for: .seconds(3))
                if let live = DuoSeamDrag.debugCurrent?.live {
                    HangWatchdog.mark("STUCK seam live=\(live) listFull=\(DuoSeamDrag.debugCurrent?.listFull ?? false) open=\(model.presentedItem?.id ?? 0) after step \(n)")
                }
                quietSince = CACurrentMediaTime()
            }
        }
        _ = quietSince
        try? await Task.sleep(for: .seconds(3))
        if let live = DuoSeamDrag.debugCurrent?.live {
            HangWatchdog.mark("STUCK seam live=\(live) at the end")
        }
        emit(["event": "done"])
        FileHandle.standardError.write(Data("PERF DONE\n".utf8))
    }

    private func stressLive() -> String {
        DuoSeamDrag.debugCurrent?.live.map { String(format: "%.0f", $0) } ?? "nil"
    }

    /// One random action; returns its name.
    private func stressAction() -> String {
        let width = 951.0
        switch Int.random(in: 0..<100) {
        case 0..<35:
            let id = Self.stressTitles.randomElement()!
            model.open(id)
            return model.presentedItem == nil ? "open \(id)" : "open-over \(id)"
        case 35..<70:
            let dx = Double.random(in: -width * 0.6...width * 0.6)
            let velocity = Double.random(in: -2200...2200)
            NotificationCenter.default.post(name: .perfSeamDrag, object: [dx, velocity])
            return String(format: "drag dx %.0f v %.0f", dx, velocity)
        case 70..<85:
            NotificationCenter.default.post(name: .perfCloseTitle, object: nil)
            return "close"
        default:
            let dx = Double.random(in: -60...60)
            NotificationCenter.default.post(name: .perfSeamDrag, object: [dx, dx < 0 ? -1800.0 : 1800.0])
            return String(format: "flick dx %.0f", dx)
        }
    }
}
#endif
