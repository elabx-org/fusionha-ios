import SwiftUI

/// v2's Activity scopes (plan S10), handed to v1's Activity page through
/// `\.activityScopeTab` (`ActivityScopeRoot`). History, Wanted, Blocklist
/// and Tasks are rebuilt; Audit and Indexers keep v1's rows on v2's ground
/// and chips. The queue is S8's (`\.activityQueueTab`).
enum V2ScopeTabs {
    @MainActor
    static let override = ActivityScopeTabOverride { tab, search, itemId in
        switch tab {
        case .queue: return nil
        case .history: return AnyView(V2HistoryScope(search: search, itemId: itemId))
        case .wanted: return AnyView(V2WantedScope())
        case .blocklist: return AnyView(V2BlocklistScope(search: search))
        case .tasks: return AnyView(V2TasksScope())
        case .audit:
            return AnyView(V2KeptScope(caption: "Every change, newest first", searchable: true) {
                ActivityAuditTab(search: search)
            })
        case .indexers:
            return AnyView(V2KeptScope(caption: "How each indexer is doing") { ActivityIndexersTab() })
        }
    }
}
