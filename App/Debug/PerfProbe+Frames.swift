import SwiftUI
import UIKit

// The perf probe's frame-capture script (FUSIONHA_PERF_SCRIPT=v2frames): on
// the iPhone Duo harness's flat open inner display, open and close titles
// from the v2 Library with the list shown and with it remembered hidden (the
// sidebar button), capturing the window at fixed times after each tap and
// each Close (`perfshots/<mode>-<step>-<ms>.jpg` in the app's tmp folder,
// copied out by scripts/perf_v2_session.sh). Owner, build 791: with the list
// hidden, closing slid the Library in over a black gap, and the next title
// opened with its own toolbar in the page for a second and a half.

#if DEBUG
extension PerfProbe {
    /// Capture times after each action, in ms.
    private static let shotTimes = [60, 160, 300, 500, 800, 1200, 1800, 2600]

    func runFrames(warmup: Double) async {
        UserDefaults.standard.set(true, forKey: "v2.splitHandle.used")
        model.tab = .library
        let start = CACurrentMediaTime()
        while !(model.libraryLoaded && model.library.count > 100), CACurrentMediaTime() - start < 60 {
            try? await Task.sleep(for: .milliseconds(250))
        }
        await phase("frames.settle", warmup)
        for hidden in [false, true] {
            let mode = hidden ? "hidden" : "shown"
            UserDefaults.standard.set(hidden ? "library,discover,search,calendar,activity,requests,you" : "",
                                      forKey: DuoListMemory.storageKey)
            try? await Task.sleep(for: .seconds(1.5))
            await capture("\(mode)-0rest", [0])
            await framesStep("\(mode)-1open") { [model] in model.open(1) }
            await framesStep("\(mode)-2close") { NotificationCenter.default.post(name: .perfCloseTitle, object: nil) }
            await framesStep("\(mode)-3open") { [model] in model.open(8) }
            await framesStep("\(mode)-4close") { NotificationCenter.default.post(name: .perfCloseTitle, object: nil) }
        }
        UserDefaults.standard.set("", forKey: DuoListMemory.storageKey)
        emit(["event": "done"])
        FileHandle.standardError.write(Data("PERF DONE\n".utf8))
    }

    /// One action, captured along the way, then a rest.
    private func framesStep(_ name: String, _ action: @escaping () -> Void) async {
        await phase(name, 0.05, action: action)
        await capture(name, Self.shotTimes)
        try? await Task.sleep(for: .seconds(1))
    }

    /// The window at each of `times` (ms from now).
    private func capture(_ name: String, _ times: [Int]) async {
        let begun = CACurrentMediaTime()
        for ms in times {
            let wait = Double(ms) / 1000 - (CACurrentMediaTime() - begun)
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            let at = Int((CACurrentMediaTime() - begun) * 1000)
            shot(String(format: "%@-%04d", name, at))
        }
    }

    private func shot(_ name: String) {
        let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first { $0.isKeyWindow }
        guard let window else { return }
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("perfshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? image.jpegData(compressionQuality: 0.6)?.write(to: dir.appendingPathComponent("\(name).jpg"))
        emit(["event": "shot", "name": name, "tab": "\(model.tab)", "open": model.presentedItem?.id ?? 0])
    }
}
#endif
