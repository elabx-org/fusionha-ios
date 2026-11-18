#if DEBUG
import SwiftUI
import FusionhaKit

// The owner's stuck-title repro (2026-11-18), step by step:
// open a title beside the list, drag it to full width, close it, open
// another. FUSIONHA_STRESS_SCRIPT=fullclose runs it on a loop and marks the
// seam's state 1.5 s after each second open; the last title stays open.
extension PerfProbe {
    func runFullCloseScript() async {
        UserDefaults.standard.set(true, forKey: "v2.splitHandle.used")
        UserDefaults.standard.set("", forKey: DuoListMemory.storageKey)
        model.tab = .library
        let start = CACurrentMediaTime()
        while !(model.libraryLoaded && !model.library.isEmpty), CACurrentMediaTime() - start < 60 {
            try? await Task.sleep(for: .milliseconds(250))
        }
        try? await Task.sleep(for: .seconds(3))
        let ids = model.library.prefix(6).map(\.id)
        let cycles = Int(ProcessInfo.processInfo.environment["FUSIONHA_STRESS_STEPS"] ?? "") ?? 4
        for n in 0..<cycles {
            let a = ids[(2 * n) % ids.count], b = ids[(2 * n + 1) % ids.count]
            step(n, "open \(a)") { model.open(a) }
            try? await Task.sleep(for: .seconds(2.5))
            step(n, "full width") { NotificationCenter.default.post(name: .perfSeamDrag, object: [-900.0, -2000.0]) }
            try? await Task.sleep(for: .seconds(2.5))
            step(n, "close") { NotificationCenter.default.post(name: .perfCloseTitle, object: nil) }
            try? await Task.sleep(for: .seconds(2.5))
            step(n, "open \(b)") { model.open(b) }
            try? await Task.sleep(for: .seconds(1.5))
            HangWatchdog.mark("SCRIPT \(n) after open \(b): \(seamState())")
            if n < cycles - 1 {
                NotificationCenter.default.post(name: .perfCloseTitle, object: nil)
                try? await Task.sleep(for: .seconds(2.5))
            }
        }
        HangWatchdog.mark("SCRIPT done: \(seamState())")
        FileHandle.standardError.write(Data("PERF DONE\n".utf8))
    }

    private func step(_ n: Int, _ name: String, _ action: () -> Void) {
        HangWatchdog.mark("SCRIPT \(n) \(name) before: \(seamState())")
        action()
    }

    private func seamState() -> String {
        let s = DuoSeamDrag.debugCurrent
        return "open=\(model.presentedItem?.id ?? 0) live=\(s?.live.map { String(format: "%.0f", $0) } ?? "nil")"
            + " handle=\(s?.handleShown ?? false) slidIn=\(s?.slidIn ?? 0) listFull=\(s?.listFull ?? false)"
            + " released=\(s?.parkedReleased ?? 0) share=\(String(format: "%.3f", UserDefaults.standard.double(forKey: "v2.duo.listShare")))"
            + " hidden=\(UserDefaults.standard.string(forKey: DuoListMemory.storageKey) ?? "")"
    }
}
#endif
