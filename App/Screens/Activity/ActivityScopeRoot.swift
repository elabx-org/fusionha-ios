import SwiftUI

extension EnvironmentValues {
    /// A replacement for Activity's other scopes (History, Wanted, Blocklist,
    /// Tasks, Audit, Indexers). v1 never sets it, so each tab shows v1's own
    /// view; v2 (`V2RootView`) passes its scopes here. A nil answer for a tab
    /// keeps v1's view for that tab.
    @Entry var activityScopeTab: ActivityScopeTabOverride?

    /// A replacement for the header at the top of an `ActivityPage` (v1's
    /// caption, search and tab strip). v1 never sets it; v2 sets it on the
    /// v1 tabs it keeps (Audit, Indexers) so they carry v2's scope chips.
    @Entry var activityPageHeader: ActivityPageHeaderOverride?
}

/// The view a product puts in one of Activity's scopes, given the tab, the
/// debounced title search and History's `?item_id=` filter.
struct ActivityScopeTabOverride {
    let make: @MainActor (_ tab: ActivityTab, _ search: String, _ itemId: Int?) -> AnyView?
}

/// The header an `ActivityPage` draws above its tab's rows.
struct ActivityPageHeaderOverride {
    let make: @MainActor () -> AnyView
}

/// Activity's scopes other than the queue: the override when one answers
/// for the tab, else v1's tab.
struct ActivityScopeRoot: View {
    let tab: ActivityTab
    let search: String
    let itemId: Int?
    @Environment(\.activityScopeTab) private var override

    var body: some View {
        if let view = override?.make(tab, search, itemId) {
            view.id(tab)
        } else {
            switch tab {
            case .queue: ActivityQueueRoot(search: search)
            case .wanted: WantedView(embedded: true)
            case .history: ActivityHistoryTab(search: search, itemId: itemId)
            case .blocklist: ActivityBlocklistTab(search: search)
            case .tasks: ActivityTasksTab()
            case .audit: ActivityAuditTab(search: search)
            case .indexers: ActivityIndexersTab()
            }
        }
    }
}
