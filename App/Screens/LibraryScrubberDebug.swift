#if DEBUG
import SwiftUI
import UIKit

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

/// CI (`FUSIONHA_SCREENSHOT_SCRUB=sweep|drift`): the A–Z window's state in a
/// small label, so a screenshot shows what was rendered and why.
struct LibraryWindowDebugLabel: View {
    let window: LibraryGridWindow
    private static let enabled = ["sweep", "drift"].contains(ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_SCRUB"] ?? "")

    var body: some View {
        if Self.enabled {
            Text(window.debugLine)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.yellow)
                .padding(4)
                .background(.black.opacity(0.7))
                .padding(.bottom, 96)
                .allowsHitTesting(false)
        }
    }
}

extension ScrubberState {
    /// CI (`FUSIONHA_SCREENSHOT_SCRUB=drift`): a plain finger-like scroll (no
    /// jumps) down the page in small steps, so the window must follow it.
    static func screenshotDrift() async {
        guard let sv = libraryScrollView() else { return }
        for _ in 0..<600 {
            if Task.isCancelled { return }
            let maxY = sv.contentSize.height - sv.bounds.height + sv.adjustedContentInset.bottom
            let y = sv.contentOffset.y + 9
            sv.setContentOffset(CGPoint(x: 0, y: y > maxY ? -sv.adjustedContentInset.top : y), animated: false)
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
