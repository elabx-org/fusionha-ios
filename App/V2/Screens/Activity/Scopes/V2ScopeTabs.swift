import SwiftUI

/// v2's Activity scopes (plan S10), handed to v1's Activity page through
/// `\.activityScopeTab` (`ActivityScopeRoot`). Every scope but the queue is
/// rebuilt here; the queue is S8's (`\.activityQueueTab`).
enum V2ScopeTabs {
    @MainActor
    static let override = ActivityScopeTabOverride { tab, search, itemId in
        switch tab {
        case .queue: return nil
        case .history: return AnyView(V2HistoryScope(search: search, itemId: itemId))
        case .wanted: return AnyView(V2WantedScope())
        case .blocklist: return AnyView(V2BlocklistScope(search: search))
        case .tasks: return AnyView(V2TasksScope())
        case .audit: return AnyView(V2AuditScope(search: search))
        case .indexers: return AnyView(V2IndexersScope())
        }
    }
}
