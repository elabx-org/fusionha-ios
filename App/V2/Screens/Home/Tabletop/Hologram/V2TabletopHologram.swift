import SwiftUI
import FusionhaKit

/// The tabletop hologram's switch (tabletop plan, slices 2 and 3): off, Home
/// half folded on a table is the flat carousel; on, Coming up stands on the
/// bottom half as the hologram scene (`V2HomeTabletop` lifts one into the
/// other). Kept on this device under `key`, off by default. Three controls
/// write it: the glass capsule on the tabletop's bottom half
/// (`V2HologramSwitch`), the Coming up menu while on a table
/// (`V2ComingUpMenu`) and Settings › Appearance (`V2TabletopHologramSection`).
enum V2TabletopHologram {
    static let key = "v2.home.tabletopHologram"

    /// The stored switch. CI screenshots:
    /// `FUSIONHA_SCREENSHOT_TABLETOP_HOLOGRAM=1` forces it on, and so does a
    /// frozen lift.
    static func isOn(stored: Bool) -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_TABLETOP_HOLOGRAM"] == "1" { return true }
        if frozenLift != nil { return true }
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

    /// CI screenshots: `FUSIONHA_SCREENSHOT_TABLETOP_LIFT=<0…1>` holds the
    /// lift at that progress (0 the flat carousel drawn by the scene, 1 the
    /// hologram).
    static let frozenLift: Double? = {
        #if DEBUG
        return ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_TABLETOP_LIFT"]
            .flatMap { Double($0) }
            .map { min(max($0, 0), 1) }
        #else
        return nil
        #endif
    }()

    /// CI's Duo harness: the picture holds still (no print-in, sway, bob or
    /// spin), so every shot is the same.
    static let holdsStill: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_DUO_FRAME"] != nil || frozenLift != nil
        #else
        return false
        #endif
    }()

    /// Where the lift rests as the tabletop appears: 1 with the switch on.
    static var restingLift: Double {
        frozenLift ?? (isOn(stored: UserDefaults.standard.bool(forKey: key)) ? 1 : 0)
    }
}

/// Settings › Appearance (v2 only): the same switch as the capsule on the
/// tabletop and the Coming up menu's "On a table" toggle.
struct V2TabletopHologramSection: View {
    @AppStorage(V2TabletopHologram.key) private var stored = false

    var body: some View {
        SettingsSection("Home half folded on a table",
                        footer: "Only this iPhone. It applies only while the iPhone Duo stands half folded on a table: Coming up then stands on the lower half as a hologram, lit in the title's own colour, instead of a row of posters. Folded and fully open nothing changes.") {
            Toggle("Hologram", isOn: $stored)
        }
        .settingsField("Home half folded on a table")
    }
}
