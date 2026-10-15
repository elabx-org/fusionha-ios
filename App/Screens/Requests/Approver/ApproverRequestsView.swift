import SwiftUI
import FusionhaKit

/// The approver's Requests area (web `ApproverRequests`): Inbox N · Board ·
/// History, plus Mine (their own requests). Threads, Rules and Insights come
/// with the issues and settings steps. Any view opens a request's thread here.
struct ApproverRequestsView: View {
    enum Lane: Hashable { case inbox, board, history, mine }

    @Environment(DiscoverStore.self) private var store
    @State private var lane: Lane = .inbox
    @State private var historyFilter: HistoryFilter = .all
    @State private var thread: MediaRequest?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DiscoverSegmented(options: [
                (Lane.inbox, store.pendingCount > 0 ? "Inbox \(store.pendingCount)" : "Inbox"),
                (Lane.board, "Board"),
                (Lane.history, "History"),
                (Lane.mine, "Mine"),
            ], selection: $lane, fullTrack: true)
            switch lane {
            case .inbox:
                TriageInboxView(onOpenThread: { thread = $0 }, onOpenBoard: { lane = .board }, onOpenHistory: openHistory)
            case .board:
                RequestsBoardView(onOpenThread: { thread = $0 }, onOpenHistory: openHistory)
            case .history:
                RequestsHistoryView(initialFilter: historyFilter, onOpenThread: { thread = $0 })
                    .id(historyFilter)
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
