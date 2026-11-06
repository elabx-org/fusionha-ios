import SwiftUI
import FusionhaKit

/// v2's shell chrome (plan S14, mock minimize.js): the Activity badge, our
/// own minimize of the iPhone Duo's vertical tab column, the flat open Duo's
/// sidebar and the Duo's floating downloads capsule. v1 never sets
/// `\.shellChrome`, so its shell is unchanged.
struct ShellChromeOverride {
    /// Activity's badge counts what needs you, in orange, not the whole queue.
    var activityBadgeNeedsYou = true
    /// The Duo's vertical column collapses to the current tab plus Search
    /// while scrolling down (`.tabBarMinimizeBehavior` doesn't touch it).
    var minimizesColumn = true
    /// The flat open Duo's sidebar; nil: none.
    var sidebar: (@MainActor (ShellSidebarToggle) -> AnyView)?
    /// The Duo's floating downloads bar where the system's can't show (the
    /// tabs' column crosses the fold); nil: none.
    var downloadsCapsule: (@MainActor (DownloadsBarState) -> AnyView)?
}

/// The sidebar's show / hide, remembered per device (`ShellSidebarMemory`).
/// Offered on the flat open Duo with nothing open beside the list.
struct ShellSidebarToggle {
    let hidden: Bool
    let toggle: @MainActor () -> Void
}

enum ShellSidebarMemory {
    static let storageKey = "v2.shell.sidebarHidden"
}

extension EnvironmentValues {
    @Entry var shellChrome: ShellChromeOverride?
    /// Set while the sidebar is offered (`RootView`); tab roots show its
    /// toggle in the column while it is hidden.
    @Entry var shellSidebarToggle: ShellSidebarToggle?
}
