import SwiftUI
import FusionhaKit

/// The tabletop hologram's switch (tabletop plan, slice 2): off, Home half
/// folded on a table is the flat carousel (`V2HomeTabletop`); on, Coming up
/// stands on the bottom half as the hologram scene (`V2HologramPage`). Kept
/// on this device under `key`, off by default; the switch itself (the glass
/// capsule, the menu, Settings) comes with the next slice.
enum V2TabletopHologram {
    static let key = "v2.home.tabletopHologram"

    /// The stored switch. CI screenshots:
    /// `FUSIONHA_SCREENSHOT_TABLETOP_HOLOGRAM=1` forces it on.
    static func isOn(stored: Bool) -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_TABLETOP_HOLOGRAM"] == "1" { return true }
        #endif
        return stored
    }

    /// CI screenshots: `FUSIONHA_SCREENSHOT_TABLETOP_HINGE=<degrees>` draws
    /// the scene for that hinge angle instead of the device's.
    static var fixedHinge: Double? {
        #if DEBUG
        return ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_TABLETOP_HINGE"]
            .flatMap { Double($0) }
            .map { TabletopProjection.heldHinge($0) }
        #else
        return nil
        #endif
    }
}
