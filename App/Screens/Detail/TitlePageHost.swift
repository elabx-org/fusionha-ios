import SwiftUI

extension EnvironmentValues {
    /// A replacement for the open title's page, in the sheet and the shell's
    /// column alike. v1 never sets it, so a title shows `ItemDetailView`; v2
    /// (`V2RootView`) passes its own title page here.
    @Entry var titlePage: TitlePageOverride?
}

/// The page a product shows for an open title, and how the shell lays it
/// out beside the list.
struct TitlePageOverride {
    /// The page for the title's store; the closure closes the column (nil
    /// in a sheet, which dismisses itself).
    let make: @MainActor (DetailStore, (() -> Void)?) -> AnyView
    /// The list's share of the flat open Duo while a title is open beside
    /// it (one seamless display, no fold gutter); nil keeps the shell's split.
    var flatOpenListShare: Double?
}

/// Where the shell puts the open title: the override's page when one is
/// set, else v1's `ItemDetailView`.
struct TitlePageHost: View {
    @Environment(\.titlePage) private var override
    let store: DetailStore
    var onClose: (() -> Void)?

    var body: some View {
        if let override {
            override.make(store, onClose)
        } else {
            ItemDetailView(store: store, onClose: onClose)
        }
    }
}
