import SwiftUI
import UIKit

/// The folded iPhone Duo: the app is on the outer display (466 x 678 pt),
/// where iOS 27.1 moves the bar into the vertical column on its trailing edge.
/// No API names the display, so it is read from the screen's size: no other
/// iPhone or iPad has a screen whose short side is 450–560 pt and long side
/// under 800 pt (iPhones are at most 440 wide, the inner display is 669, the
/// iPad mini 744). The size class gates it, so a view that reads
/// `horizontalSizeClass` re-evaluates it on a fold (regular → compact).
enum OuterDisplay {
    @MainActor
    static func isFoldedDuo(sizeClass: UserInterfaceSizeClass?) -> Bool {
        guard sizeClass == .compact else { return false }
        #if DEBUG
        // CI's Duo harness renders on an iPad: its folded frame stands in.
        if let frame = DuoHarness.frame { return frame == .folded }
        #endif
        let scene = UIApplication.shared.connectedScenes.lazy.compactMap { $0 as? UIWindowScene }.first
        guard let size = scene?.screen.bounds.size else { return false }
        return isOuterDisplay(size)
    }

    /// The outer display's screen, in either orientation.
    static func isOuterDisplay(_ size: CGSize) -> Bool {
        let short = min(size.width, size.height), long = max(size.width, size.height)
        return short >= 450 && short < 560 && long < 800
    }
}
