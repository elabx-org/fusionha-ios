import SwiftUI
import FusionhaKit

/// v2's shell chrome (plan S14): the Activity badge and the Duo's floating
/// downloads capsule. v1 never sets `\.shellChrome`, so its shell is
/// unchanged. S14's open Duo sidebar and its own minimize of the Duo's tab
/// column were removed by the owner (2026-11-06, build 893): the column
/// always shows every tab and each screen's buttons.
struct ShellChromeOverride {
    /// Activity's badge counts what needs you, in orange, not the whole queue.
    var activityBadgeNeedsYou = true
    /// The Duo's floating downloads bar where the system's can't show (the
    /// tabs' column crosses the fold); nil: none.
    var downloadsCapsule: (@MainActor (DownloadsBarState) -> AnyView)?
}

extension EnvironmentValues {
    @Entry var shellChrome: ShellChromeOverride?
}
