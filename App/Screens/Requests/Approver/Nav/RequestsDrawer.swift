import SwiftUI
import FusionhaKit

/// The view drawer with its live figures, opened from the header's view name
/// (`RequestsViewHeader`): a short sheet on a phone, the web's popover when
/// wide (DC21). Rules closes it, then opens Settings › Requests.
struct RequestsDrawer: View {
    @Environment(RequestsNav.self) private var nav
    @Environment(DiscoverStore.self) private var store

    private var canApprove: Bool { nav.panes.contains(.inbox) }
    private var canIssues: Bool { nav.panes.contains(.issues) }

    var body: some View {
        RequestsViewMenuSheet(counts: counts, panes: nav.panes,
                              needYou: canIssues ? store.issueCounts.needYou : nil,
                              breakdown: RequestsNeedYou.line(pending: canApprove ? store.pendingCount : nil,
                                                              issues: canIssues ? store.issueCounts.needYou : nil),
                              showsRules: canApprove) {
            nav.menuOpen = false
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                nav.rulesOpen = true
            }
        }
    }

    /// The drawer's figures (web `useMenuCounts`): Inbox waiting, Threads
    /// unread open threads ("4+"), Issues open, Mine my open requests.
    private var counts: [RequestsPane: String] {
        var out: [RequestsPane: String] = [:]
        if store.pendingCount > 0 { out[.inbox] = String(store.pendingCount) }
        if let label = ThreadUnread.label(nav.unreadThreads, more: nav.unreadMore) { out[.threads] = label }
        if store.issueCounts.open > 0 { out[.issues] = String(store.issueCounts.open) }
        if let mine = MineHeader.openCount(nav.mineCounts), mine > 0 { out[.mine] = String(mine) }
        return out
    }
}
