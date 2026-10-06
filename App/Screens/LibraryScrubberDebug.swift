#if DEBUG
import SwiftUI

extension ScrubberState {
    /// CI (`FUSIONHA_SCREENSHOT_SCRUB=sweep`): a fast scrub that keeps jumping
    /// between far letters through the real drag path (engage, then scrub),
    /// the jump gap and the art gate included, so screenshots taken mid-sweep
    /// catch any blank or light frame a far jump paints. Runs ~30s, grabbed.
    func screenshotSweep(letters: [String], jump: (String) -> Void) async {
        let height: CGFloat = 600
        func y(_ ratio: CGFloat) -> CGFloat { Self.thumbHeight / 2 + ratio * (height - Self.thumbHeight) }
        engage(at: y(0), height: height, letters: letters)
        let stops: [CGFloat] = [0.97, 0.03, 0.6, 0.1, 0.9, 0.35, 0.99, 0.0, 0.75, 0.2]
        for step in 0..<230 {
            if Task.isCancelled { return }
            scrub(to: y(stops[step % stops.count]), height: height, letters: letters, jump: jump)
            try? await Task.sleep(for: .milliseconds(130))
        }
    }
}
#endif
