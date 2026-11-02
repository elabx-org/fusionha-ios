import SwiftUI

extension EnvironmentValues {
    /// The title page's folded-Duo / phone layout: a sheet in a compact-width
    /// window (never the shell's column). It moves the item actions into the
    /// bar's More menu, makes the tabs a segmented control with Overview folded
    /// into the page, and puts one version menu by the tabs (`docs/ui-plan.md`).
    /// The open Duo, the iPad and the web keep the rail and the five tabs.
    @Entry var detailCompact = false
}
