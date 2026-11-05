import SwiftUI

extension EnvironmentValues {
    /// A replacement for Activity's Queue tab. v1 never sets it, so the tab
    /// shows `ActivityQueueTab`; v2 (`V2RootView`) passes its own queue here
    /// and keeps the other Activity tabs as they are.
    @Entry var activityQueueTab: ActivityQueueTabOverride?
}

/// The view a product puts in Activity's Queue tab, given the debounced
/// title search.
struct ActivityQueueTabOverride {
    let make: @MainActor (_ search: String) -> AnyView
}

/// Activity's Queue tab: the override when one is set, else v1's tab.
struct ActivityQueueRoot: View {
    let search: String
    @Environment(\.activityQueueTab) private var override

    var body: some View {
        if let override {
            override.make(search)
        } else {
            ActivityQueueTab(search: search)
        }
    }
}
