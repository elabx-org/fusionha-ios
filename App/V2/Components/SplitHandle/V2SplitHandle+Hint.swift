import SwiftUI

// The handle's first-time hint: the tip and two nudges until it is touched.
extension V2SplitHandle {
    func hideHint() {
        used = true
        tipShown = false
        nudge = 0
    }

    /// Shown until the handle is first touched: the tip for about four
    /// seconds, and two nudges (none under Reduce Motion).
    func firstTimeHint() async {
        guard !used else { return }
        try? await Task.sleep(for: .milliseconds(900))
        guard !used, !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.35)) { tipShown = true }
        let clock = ContinuousClock()
        let shownAt = clock.now
        if motion {
            for _ in 0..<2 where !used {
                await nudgeOnce()
            }
        }
        try? await Task.sleep(until: shownAt + .milliseconds(4200), clock: clock)
        guard !used else { return }
        withAnimation(.easeOut(duration: 0.35)) { tipShown = false }
    }

    /// One nudge (the mock's 1.1s keyframes: left, right, home).
    func nudgeOnce() async {
        let steps: [(CGFloat, Double)] = [(-15, 0.33), (11, 0.33), (0, 0.44)]
        for (offset, duration) in steps {
            guard !used, !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: duration)) { nudge = offset }
            try? await Task.sleep(for: .seconds(duration))
        }
    }
}
