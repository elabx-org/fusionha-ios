#if DEBUG
import SwiftUI
import UIKit

extension ScrubberState {
    /// CI (`FUSIONHA_SCREENSHOT_SCRUB=jump`): one far jump, captured in-app two
    /// frames after it lands (`silhouette-0.png`, what the finger sees at once:
    /// card frames, titles and HD/4K chips on dark poster frames), then again
    /// once posters had time to fill in (`silhouette-1.png`). The PNGs go to the
    /// app's tmp folder and their paths are printed as `SCRUB-CHECK` lines.
    func screenshotJump(letters: [String], jump: (String) -> Void) async {
        guard let far = letters.last else { return }
        jump(far)
        // Two display frames: the first paint after the scroll.
        try? await Task.sleep(for: .milliseconds(34))
        Self.snapshot("silhouette-0")
        try? await Task.sleep(for: .seconds(4))
        Self.snapshot("silhouette-1")
        HangWatchdog.mark("SCRUB-CHECK DONE")
    }

    /// Renders the key window as it is on screen now and saves it as a PNG.
    private static func snapshot(_ name: String) {
        guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows).first(where: \.isKeyWindow) else { return HangWatchdog.mark("SCRUB-CHECK no window") }
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).png")
        do {
            try image.pngData()?.write(to: url)
            HangWatchdog.mark("SCRUB-CHECK snapshot \(name) \(url.path)")
        } catch {
            HangWatchdog.mark("SCRUB-CHECK snapshot \(name) failed: \(error)")
        }
    }
}
#endif
