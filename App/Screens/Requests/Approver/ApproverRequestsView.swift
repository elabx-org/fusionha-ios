import SwiftUI
import FusionhaKit

/// The approver's Requests area (web `ApproverRequests`): Inbox N · Board ·
/// History · Threads · Rules · Insights, plus Mine (their own requests). Any view opens a request's thread here.
struct ApproverRequestsView: View {
    enum Lane: Hashable { case inbox, board, history, threads, rules, insights, mine }

    @Environment(DiscoverStore.self) private var store
    @State private var lane: Lane = .inbox
    @State private var historyFilter: HistoryFilter = .all
    @State private var thread: MediaRequest?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
            DiscoverSegmented(options: [
                (Lane.inbox, store.pendingCount > 0 ? "Inbox \(store.pendingCount)" : "Inbox"),
                (Lane.board, "Board"),
                (Lane.history, "History"),
                (Lane.threads, "Threads"),
                (Lane.rules, "Rules"),
                (Lane.insights, "Insights"),
                (Lane.mine, "Mine"),
            ], selection: $lane)
            }
            switch lane {
            case .inbox:
                TriageInboxView(onOpenThread: { thread = $0 }, onOpenBoard: { lane = .board }, onOpenHistory: openHistory)
            case .board:
                RequestsBoardView(onOpenThread: { thread = $0 }, onOpenHistory: openHistory)
            case .history:
                RequestsHistoryView(initialFilter: historyFilter, onOpenThread: { thread = $0 })
                    .id(historyFilter)
            case .threads:
                ThreadsPanelView()
            case .rules:
                RequestRulesView()
            case .insights:
                RequestInsightsView()
            case .mine:
                MineView()
            }
        }
        .sheet(item: $thread) { request in
            RequestThreadSheet(request: request) { store.requestsVersion += 1 }
        }
    }

    private func openHistory(_ filter: HistoryFilter) {
        historyFilter = filter
        lane = .history
    }
}
