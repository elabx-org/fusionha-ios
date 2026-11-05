import SwiftUI

extension EnvironmentValues {
    /// A replacement for the Library tab's root view. v1 never sets it, so
    /// the tab shows `LibraryView`; v2 (`V2RootView`) passes its own Library
    /// here and keeps every other tab as it is.
    @Entry var libraryTabRoot: LibraryTabRootOverride?
}

/// The view a product puts at the Library tab's root.
struct LibraryTabRootOverride {
    let make: @MainActor () -> AnyView
}

/// The Library tab's root: the override when one is set, else v1's page.
struct LibraryTabRoot: View {
    @Environment(\.libraryTabRoot) private var override

    var body: some View {
        if let override {
            override.make()
        } else {
            LibraryView()
        }
    }
}
