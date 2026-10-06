#if DEBUG
import SwiftUI
import UIKit

extension ScrubberState {
    /// CI (`FUSIONHA_SCREENSHOT_SCRUB=sweep`): a fast scrub that keeps jumping
    /// between far letters through the real drag path (engage, scrub, lift),
    /// so screenshots taken mid-sweep catch any blank or light frame a far
    /// jump paints. Then the finger lifts and the page is scrolled like a
    /// finger would (`screenshotDrift`): the hang check (`HangWatchdog`) must
    /// see the main thread answer throughout. Prints `SCRUB-CHECK` markers.
    func screenshotSweep(letters: [String], jump: (String) -> Void) async {
        let height: CGFloat = 600
        func y(_ ratio: CGFloat) -> CGFloat { Self.thumbHeight / 2 + ratio * (height - Self.thumbHeight) }
        HangWatchdog.start()
        HangWatchdog.mark("SCRUB-CHECK sweep")
        engage(at: y(0), height: height, letters: letters)
        let stops: [CGFloat] = [0.97, 0.03, 0.6, 0.1, 0.9, 0.35, 0.99, 0.0, 0.75, 0.2]
        for step in 0..<180 {
            if Task.isCancelled { return }
            scrub(to: y(stops[step % stops.count]), height: height, letters: letters, jump: jump)
            try? await Task.sleep(for: .milliseconds(130))
        }
        end(jump: jump)
        try? await Task.sleep(for: .milliseconds(300))
        HangWatchdog.mark("SCRUB-CHECK scroll")
        await Self.screenshotDrift(steps: 500)
        HangWatchdog.mark("SCRUB-CHECK idle")
        await HangWatchdog.checkIdle(seconds: 3)
        HangWatchdog.mark("SCRUB-CHECK DONE")
    }

    /// CI (`FUSIONHA_SCREENSHOT_SCRUB=drift`, and the end of `sweep`): a plain
    /// finger-like scroll (no jumps) down the page in small steps, flinging
    /// back up now and then, so lazy rows keep realizing under a moving page.
    static func screenshotDrift(steps: Int = 600) async {
        guard let sv = libraryScrollView() else { return HangWatchdog.mark("SCRUB-CHECK no scroll view") }
        for step in 0..<steps {
            if Task.isCancelled { return }
            let top = -sv.adjustedContentInset.top
            let maxY = sv.contentSize.height - sv.bounds.height + sv.adjustedContentInset.bottom
            if step % 150 == 149 {
                // A fling back up, animated like momentum.
                sv.setContentOffset(CGPoint(x: 0, y: max(top, sv.contentOffset.y - 2400)), animated: true)
                try? await Task.sleep(for: .milliseconds(400))
                continue
            }
            let y = sv.contentOffset.y + 14
            sv.setContentOffset(CGPoint(x: 0, y: y > maxY ? top : y), animated: false)
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    /// The tallest visible vertical scroll view in the key window.
    private static func libraryScrollView() -> UIScrollView? {
        let roots = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).filter(\.isKeyWindow)
        var best: UIScrollView?
        func visit(_ view: UIView) {
            if let sv = view as? UIScrollView, !(sv is UITextView), sv.window != nil,
               sv.bounds.height > (best?.bounds.height ?? 300) { best = sv }
            view.subviews.forEach(visit)
        }
        roots.forEach(visit)
        return best
    }
}
#endif
