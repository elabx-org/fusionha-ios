import SwiftUI
import UIKit

// The perf probe's Library script (FUSIONHA_PERF_SCRIPT=library): the poster
// grid at volume (the mock's 3,785-title library, 20 live downloads), sat idle
// and scrolled down, back up and in a fast fling. CI runs it once per layout
// (FUSIONHA_PERF_LABEL names the phases), e.g. on the iPhone Duo harness's open
// inner display as a Spread span, a Spread with a title open, and the Web layout.

#if DEBUG
extension PerfProbe {
    func runLibrary(warmup: Double) async {
        let label = ProcessInfo.processInfo.environment["FUSIONHA_PERF_LABEL"] ?? "library"
        prefersTallest = true
        model.pendingAllTitles = true  // v2: the grid is All titles, over Home
        model.tab = .library
        // The library first: a cold mock takes a few seconds to serve 3,785 titles.
        let start = CACurrentMediaTime()
        while !(model.libraryLoaded && model.library.count > 100), CACurrentMediaTime() - start < 60 {
            try? await Task.sleep(for: .milliseconds(250))
        }
        emit(["event": "library", "label": label, "titles": model.library.count,
              "wait_s": ((CACurrentMediaTime() - start) * 10).rounded() / 10])
        await phase("\(label).settle", warmup)
        await phase("\(label).idle", 6)
        scrollSpeed = 1800
        await phase("\(label).scroll", 20, scroll: true)
        await phase("\(label).idle-after-scroll", 4)
        scrollSpeed = -1800
        await phase("\(label).up.scroll", 10, scroll: true)
        scrollSpeed = 4000
        await phase("\(label).fast.scroll", 8, scroll: true)
        await phase("\(label).idle-end", 4)
        emit(["event": "done"])
        FileHandle.standardError.write(Data("PERF DONE\n".utf8))
    }

    /// The visible vertical scroll view the script drives: the largest on
    /// screen (the tab's page), or with `prefersTallest` the one with the
    /// most content (the Library grid beside a title page on a Spread).
    func findScrollView() -> UIScrollView? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .filter(\.isKeyWindow)
        var best: UIScrollView?
        var bestScore: CGFloat = 0
        let tallest = prefersTallest
        func visit(_ view: UIView) {
            if view.isHidden || view.alpha < 0.01 { return }
            if let sv = view as? UIScrollView, !(sv is UITextView), let window = sv.window,
               sv.bounds.width > 200, sv.bounds.height > 300 {
                let visible = sv.convert(sv.bounds, to: nil).intersection(window.bounds)
                let area = visible.isNull ? 0 : visible.width * visible.height
                let score = tallest ? sv.contentSize.height : area
                if area > 0, score >= bestScore { best = sv; bestScore = score }
            }
            for sub in view.subviews { visit(sub) }
        }
        windows.forEach(visit)
        return best
    }
}
#endif
