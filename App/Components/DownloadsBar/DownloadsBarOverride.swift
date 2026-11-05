import SwiftUI

extension EnvironmentValues {
    /// A replacement for the downloads bar's content. v1 never sets it, so
    /// the accessory shows `DownloadsBarAccessory`; v2 (`V2RootView`) passes
    /// its own. The slot, its visibility and the pill space stay the shell's.
    @Entry var downloadsBarContent: DownloadsBarContentOverride?
}

/// The view a product puts in the downloads bar.
struct DownloadsBarContentOverride {
    let make: @MainActor (DownloadsBarState) -> AnyView
}
