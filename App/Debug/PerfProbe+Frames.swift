import SwiftUI
import UIKit
import FusionhaKit

// The perf probe's frame-capture script (FUSIONHA_PERF_SCRIPT=v2frames): on
// the iPhone Duo harness's flat open inner display, open and close titles
// from the v2 Library with the list shown and with it remembered hidden (the
// sidebar button), marking each tap and Close for the simulator's screen
// recording, from which scripts/perf_v2_session.sh pulls the frames
// (in-app captures missed the moving title). Owner, build 791: with the list
// hidden, closing slid the Library in over a black gap, and the next title
// opened with its own toolbar in the page for a second and a half.

#if DEBUG
extension PerfProbe {
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
            mark("\(mode)-0rest")
            try? await Task.sleep(for: .seconds(1))
            await framesStep("\(mode)-1open") { [model] in model.open(1) }
            await framesStep("\(mode)-2close") { NotificationCenter.default.post(name: .perfCloseTitle, object: nil) }
            await framesStep("\(mode)-3open") { [model] in model.open(8) }
            await framesStep("\(mode)-4close") { NotificationCenter.default.post(name: .perfCloseTitle, object: nil) }
        }
        UserDefaults.standard.set("", forKey: DuoListMemory.storageKey)
        emit(["event": "done"])
        FileHandle.standardError.write(Data("PERF DONE\n".utf8))
    }

    /// One action, marked for the screen recording (the script pulls the
    /// frames around each mark out of it), then a rest.
    private func framesStep(_ name: String, _ action: @escaping () -> Void) async {
        mark(name)
        action()
        try? await Task.sleep(for: .seconds(4))
    }

    /// `PERF-MARK <name> <unix time>` on stderr: scripts/perf_v2_session.sh
    /// takes the recording's frames from that moment on.
    private func mark(_ name: String) {
        let line = String(format: "PERF-MARK %@ %.3f\n", name, Date().timeIntervalSince1970)
        FileHandle.standardError.write(Data(line.utf8))
        emit(["event": "mark", "name": name, "tab": "\(model.tab)", "open": model.presentedItem?.id ?? 0])
    }
}
#endif
