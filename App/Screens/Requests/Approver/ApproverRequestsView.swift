import SwiftUI
import FusionhaKit

/// The approver's Requests area (Final mock, approved 2026-10-18): one header
/// row names the view and opens the drawer (Inbox · Board · History · Threads
/// · Insights · Mine); filters live in a sheet; Rules is in Settings ›
/// Requests. Any view opens a request's thread here.
struct ApproverRequestsView: View {
    var canApprove = true
    var canIssues = false
    @Environment(AppModel.self) private var model
    @Environment(DiscoverStore.self) private var store
    @State private var nav: RequestsNav
    @State private var thread: MediaRequest?

    init(canApprove: Bool = true, canIssues: Bool = false) {
        self.canApprove = canApprove
        self.canIssues = canIssues
        let nav = RequestsNav()
        // An issue manager who can't approve opens on Issues, never the Inbox.
        if !canApprove { nav.pane = canIssues ? .issues : .mine }
        _nav = State(initialValue: nav)
    }

    var body: some View {
        @Bindable var nav = nav
        content
            .environment(nav)
            .onAppear(perform: setUp)
            .onChange(of: store.requestsPane) { openPending() }
            .animation(.snappy, value: nav.filter)
            .sheet(isPresented: $nav.menuOpen) {
                RequestsViewMenuSheet(counts: menuCounts, panes: nav.panes,
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
                .environment(nav)
            }
            .sheet(isPresented: $nav.filterOpen) {
                RequestsFilterSheet().environment(nav)
            }
            .fullScreenCover(isPresented: $nav.rulesOpen) {
                SettingsView(client: model.client, initialPanel: "requestrules")
            }
            .sheet(item: $thread) { request in
                RequestThreadSheet(request: request) { store.requestsVersion += 1 }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch nav.pane {
        case .inbox:
            TriageInboxView(onOpenThread: { thread = $0 }, onOpenBoard: { nav.open(.board) }, onOpenHistory: openHistory)
        case .board:
            RequestsBoardView(onOpenThread: { thread = $0 }, onOpenHistory: openHistory)
        case .history:
            RequestsHistoryView(onOpenThread: { thread = $0 })
        case .threads:
            plain { ThreadsPanelView(state: nav.filter[.threads].issueState,
                                     type: nav.threadTypes ? nav.filter[.threads].threadType : nil) }
        case .issues:
            RequestsIssuesView()
        case .insights:
            plain { RequestInsightsView() }
        case .mine:
            VStack(alignment: .leading, spacing: 14) {
                RequestsViewHeader {
                    if let c = nav.mineCounts, !nav.filter[.mine].mineIssues {
                        requestsCount(c.active, "active") + Text(" · ") + requestsCount(c.available, "available")
                    }
                }
                MineView(filter: nav.filter[.mine])
            }
        }
    }

    /// Views with no filters of their own: the header, then the view.
    private func plain<V: View>(@ViewBuilder _ view: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            RequestsViewHeader()
            view()
        }
    }

    /// Approvers get every view; an issue manager who can't approve gets
    /// Issues and Mine, opening on Issues (Proposal 2).
    private func setUp() {
        var panes: [RequestsPane] = canApprove ? [.inbox, .board, .history, .threads] : []
        if canIssues { panes.append(.issues) }
        if canApprove { panes.append(.insights) }
        panes.append(.mine)
        nav.panes = panes
        nav.threadTypes = canApprove && canIssues
        if !panes.contains(nav.pane) { nav.pane = panes.first ?? .mine }
        openPending()
    }

    private func openPending() {
        guard let pane = store.requestsPane else { return }
        store.requestsPane = nil
        if nav.panes.contains(pane) { nav.open(pane) }
    }

    private var menuCounts: [RequestsPane: Int] {
        [.inbox: store.pendingCount, .issues: store.issueCounts.open]
    }

    private func openHistory(_ filter: HistoryFilter) {
        nav.filter[.history].status = filter
        nav.open(.history)
    }
}
