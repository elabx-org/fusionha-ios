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
            .task(id: nav.panes) { await pollMenuCounts() }
            .animation(.snappy, value: nav.filter)
            // The drawer and the filter are presented from their controls in
            // `RequestsViewHeader`: popovers when wide, sheets on a phone (DC21).
            .fullScreenCover(isPresented: $nav.rulesOpen) {
                SettingsView(client: model.client, initialPanel: "request-rules")
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
            RequestsThreadsView()
        case .issues:
            RequestsIssuesView()
        case .insights:
            VStack(alignment: .leading, spacing: 14) {
                RequestsViewHeader { Text(InsightsRange.label(nav.filter[.insights].weeks)) }
                RequestInsightsView(weeks: nav.filter[.insights].weeks)
            }
        case .mine:
            MineView()
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


    /// Unread open threads and my counts, every 30 s while Requests is open.
    private func pollMenuCounts() async {
        while !Task.isCancelled {
            if let client = model.client {
                if nav.panes.contains(.threads), let page = try? await client.adminThreads(state: "OPEN") {
                    nav.unreadThreads = ThreadUnread.count(page.items)
                    nav.unreadMore = page.nextCursor != nil
                    nav.openThreads = page.items.count
                }
                if let mine = try? await client.requestCounts(view: "mine") { nav.mineCounts = mine }
            }
            try? await Task.sleep(for: .seconds(30))
        }
    }

    private func openHistory(_ filter: HistoryFilter) {
        nav.filter[.history].status = filter
        nav.open(.history)
    }
}
