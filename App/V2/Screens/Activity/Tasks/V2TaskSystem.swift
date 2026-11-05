import SwiftUI
import FusionhaKit

/// Tasks › System on v2 (mock `sys`): RSS sync, Media enrichment with v1's
/// "Needs attention" groups and per-import controls, v1's Watchlists & lists
/// and Import lists cards, and Scheduled. On the open Duo this fills the right
/// page while no run is picked (RSS stays on the left page, `includeRss`).
struct V2TaskSystem: View {
    let store: TasksStore
    var includeRss = true
    @Environment(AppModel.self) private var model

    /// Whether any system module has something to show.
    static func hasContent(_ store: TasksStore, includeRss: Bool = true) -> Bool {
        let parts = Parts(store)
        return (includeRss && parts.rss != nil) || parts.showsEnrichment || !parts.issues.isEmpty
            || !parts.subtasks.isEmpty || parts.watchlists != nil || parts.importLists != nil || !parts.scheduled.isEmpty
    }

    var body: some View {
        let parts = Parts(store)
        VStack(alignment: .leading, spacing: 12) {
            if includeRss, let rss = parts.rss {
                V2RssModule(task: rss, latest: parts.latestRss)
            }
            if parts.showsEnrichment, let status = store.enrichment {
                V2EnrichmentModule(status: status)
            }
            if !parts.subtasks.isEmpty {
                EnrichmentSubtasksView(subtasks: parts.subtasks) { await store.refresh(model.client) }
            }
            if !parts.issues.isEmpty {
                V2ScopeSectionHead(title: "Needs attention", systemImage: "exclamationmark.triangle")
                EnrichmentAttentionView(issues: parts.issues) { await store.refresh(model.client) }
            }
            if let watchlists = parts.watchlists { WatchlistsTaskCard(summary: watchlists) }
            if let importLists = parts.importLists { ImportListsTaskCard(summary: importLists) }
            if !parts.scheduled.isEmpty {
                V2ScheduledModule(tasks: parts.scheduled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// v1's rules for what the System section shows (`ActivityTasksTab.loadedView`).
    struct Parts {
        let rss: ActivitySystemTask?
        let latestRss: ActivityRun?
        let showsEnrichment: Bool
        let issues: [EnrichmentIssue]
        let subtasks: [EnrichmentSubtask]
        let watchlists: RequestSourcesSummary?
        let importLists: ImportListsSummary?
        let scheduled: [ActivitySystemTask]

        @MainActor
        init(_ store: TasksStore) {
            let enrich = store.enrichment
            rss = store.tasks.first { TasksLogic.isRss($0.name) }
            latestRss = store.feed.items.first { $0.trigger == "rss" && $0.status != "running" }
            let shows = (enrich?.pendingFiles ?? 0) > 0 || (enrich?.issueFiles ?? 0) > 0
            showsEnrichment = shows
            issues = enrich?.issues ?? []
            // v1 shows the per-import controls with the enrichment card only.
            subtasks = shows ? (enrich?.subtasks ?? []) : []
            watchlists = store.watchlists.flatMap { $0.sources.isEmpty ? nil : $0 }
            importLists = store.importLists.flatMap { $0.total > 0 ? $0 : nil }
            // Every scheduled job, not v1's two (the mock lists them all).
            scheduled = TasksLogic.scheduledTasks(store.tasks, limit: 12)
        }
    }
}
