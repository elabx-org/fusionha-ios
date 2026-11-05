import SwiftUI
import UIKit

// The perf probe's title-open script (FUSIONHA_PERF_SCRIPT=v2open): on the
// iPhone Duo harness's flat open inner display, open titles from the Library
// the way a poster tap does (`AppModel.open`), let each settle, then close it
// the way its Close button does (`ShellDetailColumn.closePage`, through
// `perfCloseTitleHook`). Each open and close is a phase (frame pacing, hangs,
// counters, the main-thread sampler) plus one `open` event: when each step
// happened after the tap (`PerfCount.mark`), the first frame after the title
// view was built and the first full frame (detail laid out, the seam's slide
// in settled), and every long frame on the way.

#if DEBUG
extension PerfProbe {
    func runOpen(warmup: Double) async {
        prefersTallest = true
        // The first-time tip and nudges would animate over the first open.
        UserDefaults.standard.set(true, forKey: "v2.splitHandle.used")
        model.tab = .library
        let start = CACurrentMediaTime()
        while !(model.libraryLoaded && model.library.count > 100), CACurrentMediaTime() - start < 60 {
            try? await Task.sleep(for: .milliseconds(250))
        }
        emit(["event": "library", "label": "v2open", "titles": model.library.count,
              "error": model.libraryError ?? "", "wait_s": ((CACurrentMediaTime() - start) * 10).rounded() / 10])
        // A failed first load (seen once on CI): one retry before measuring.
        if model.library.isEmpty {
            await model.loadLibrary()
            emit(["event": "library", "label": "v2open.retry", "titles": model.library.count,
                  "error": model.libraryError ?? ""])
        }
        await phase("v2open.settle", warmup)
        await phase("v2open.idle", 4)
        // Movies and series from the fixtures (their detail pages exist), then
        // two again warm, then two with the grid scrolled down.
        var round = 0
        for id in [1, 8, 2, 10, 4, 11, 1, 8, 3, 9] {
            round += 1
            if round == 9, let sv = findScrollView() {
                sv.setContentOffset(CGPoint(x: sv.contentOffset.x, y: 4000), animated: false)
                await phase("v2open.scrolled.idle", 3)
            }
            let kind = model.library.first { $0.id == id }.map { String(describing: $0.kind) } ?? "?"
            await measureOpen(id, label: "open.\(round).\(kind)")
            await phase("opened.\(round).idle", 2)
            await measureClose(label: "close.\(round).\(kind)")
            await phase("closed.\(round).idle", 2)
        }
        emit(["event": "done"])
        FileHandle.standardError.write(Data("PERF DONE\n".utf8))
    }

    func measureOpen(_ id: Int, label: String) async {
        _ = PerfCount.takeMarks()
        frameLog = []
        var t0: Double = 0
        await phase(label, 3) { [model] in
            t0 = CACurrentMediaTime()
            model.open(id)
        }
        let marks = PerfCount.takeMarks()
        let built = marks["title.body"]
        let full = [marks["title.page"], marks["seam.commit"]].compactMap { $0 }.max()
        report(kind: "open", label: label, id: id, t0: t0, marks: marks, first: built,
               full: marks["title.page"] == nil ? nil : full)
    }

    func measureClose(label: String) async {
        _ = PerfCount.takeMarks()
        frameLog = []
        frameWatch = { [model] in if model.presentedItem == nil { PerfCount.mark("closed") } }
        var t0: Double = 0
        await phase(label, 2.5) {
            t0 = CACurrentMediaTime()
            NotificationCenter.default.post(name: .perfCloseTitle, object: nil)
        }
        frameWatch = nil
        let marks = PerfCount.takeMarks()
        report(kind: "close", label: label, id: nil, t0: t0, marks: marks, first: marks["seam.slideOut"],
               full: marks["closed"])
    }

    /// One `open` event: the marks, the first frame after `first` and after
    /// `full` (ms after the tap), and the long frames up to 0.5 s past full.
    private func report(kind: String, label: String, id: Int?, t0: Double, marks: [String: Double],
                        first: Double?, full: Double?) {
        let frames = frameLog ?? []
        frameLog = nil
        func ms(_ t: Double) -> Double { ((t - t0) * 1000 * 10).rounded() / 10 }
        func frame(after t: Double?) -> Double? { t.flatMap { t in frames.first { $0.t > t }.map { ms($0.t) } } }
        let fullFrame = frame(after: full)
        let horizon = (full ?? t0 + 2) + 0.5
        let long = frames.filter { $0.t > t0 && $0.t <= horizon && $0.delta > 0.025 }
        var event: [String: Any] = [
            "event": "open", "kind": kind, "label": label,
            "marks_ms": marks.mapValues(ms),
            "long_frames": long.map { [ms($0.t), (($0.delta * 1000) * 10).rounded() / 10] },
            "long_ms": Int(long.reduce(0) { $0 + $1.delta } * 1000),
        ]
        if let id { event["id"] = id }
        if let first = frame(after: first) { event["first_frame_ms"] = first }
        if let fullFrame { event["full_frame_ms"] = fullFrame }
        emit(event)
    }
}
#endif
