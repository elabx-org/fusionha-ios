import SwiftUI
import FusionhaKit

/// The approver's Inbox (web `TriageInbox`, phone layout): the swipe deck, or
/// "Select several" as a list with bulk actions; Details opens the full
/// decision card in a sheet. Every decision waits out the 5 s Undo, and
/// leaving the inbox sends the one still waiting.
struct TriageInboxView: View {
    let onOpenThread: (MediaRequest) -> Void
    let onOpenBoard: () -> Void
    let onOpenHistory: (HistoryFilter) -> Void
    @Environment(AppModel.self) private var model
    @Environment(DiscoverStore.self) private var store
    @Environment(RequestsNav.self) private var nav
    @State private var inbox = InboxModel()
    @State private var details: MediaRequest?
    @State private var adjusting: MediaRequest?
    @State private var noting: MediaRequest?

    private var viewerId: Int? { model.me?.id }

    var body: some View {
        content
            .task {
                inbox.bind(model.client) { message, title, variant in model.toast(message, title: title, variant: variant) }
                inbox.viewerIsAdmin = model.me?.isAdmin == true
                inbox.filterItems = nav.filter.listQuery(.inbox)
                await inbox.poll()
            }
            .task(id: nav.filter.listQuery(.inbox)) {
                let items = nav.filter.listQuery(.inbox)
                guard items != inbox.filterItems else { return }
                // A settled keystroke, not every one (web: 300 ms).
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                inbox.filterItems = items
                await inbox.refresh()
            }
            .onChange(of: inbox.items) { nav.remember(inbox.items) }
            .onChange(of: "\(inbox.total ?? -1)-\(inbox.queue.count)-\(inbox.more)", initial: true) {
                nav.resultLabel = RequestsResultLabel.text(inbox.total, loaded: inbox.queue.count, more: inbox.more,
                                                           noun: ("request", "requests"))
            }
            .onDisappear { inbox.flush() }
            .onChange(of: store.requestsVersion) { Task { await inbox.refresh() } }
            .onChange(of: model.me?.isAdmin) { inbox.viewerIsAdmin = model.me?.isAdmin == true }
            .inboxUndoHost(inbox, viewerId: viewerId, declining: $noting)
            .sheet(item: $details) { request in detailsSheet(request) }
            .sheet(item: $adjusting) { request in
                ApproveDialog(request: request) { Task { await inbox.refresh() } }
            }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if !inbox.loaded {
                DiscoverEmptyState(message: "Loading requests…")
            } else if inbox.failed && inbox.items.isEmpty {
                DiscoverEmptyState(message: "Could not load requests.")
            } else {
                if inbox.failed {
                    Text("Couldn’t refresh. Showing the last list.").font(.system(size: 12)).foregroundStyle(Theme.miss)
                }
                if inbox.queue.isEmpty && nav.filter.activeCount(.inbox) > 0 {
                    // A filter emptied the inbox: say so, no celebration (0.4.217).
                    VStack(spacing: 10) {
                        Text("No requests match.").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.txt)
                        Button("Clear") { nav.filter.reset(.inbox) }.font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 36)
                } else if nav.inboxList && nav.selecting && !inbox.queue.isEmpty {
                    InboxListView(inbox: inbox, viewerId: viewerId, onOpen: { details = $0 },
                                  onBackToCards: { nav.selecting = false; inbox.selected = [] })
                } else if nav.inboxList && !inbox.queue.isEmpty {
                    InboxRowsView(inbox: inbox, viewerId: viewerId, onOpen: { details = $0 }, onDeclineWithReason: { noting = $0 })
                } else {
                    SwipeDeckView(inbox: inbox, viewerId: viewerId, onDetails: { details = $0 },
                                  onSelectMode: { nav.selecting = true }, onOpenThread: onOpenThread,
                                  onOpenBoard: onOpenBoard, onOpenHistory: onOpenHistory)
                }
            }
        }
    }

    /// "9 waiting · oldest 5d" under the view name; Select switches to the list.
    private var header: some View {
        let queue = inbox.queue
        let oldest = TriageFacts.oldestAge(queue)
        return RequestsViewHeader {
            if inbox.loaded {
                requestsCount(queue.count, "waiting" + (oldest.isEmpty ? "" : " · oldest \(oldest)"))
            }
        }
        .toolbar {
            // Select belongs to the list (Proposal 2): cards decide one at a time.
            // Like the system Edit button, its words swap, so it stays horizontal.
            if nav.inboxList && !queue.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(nav.selecting ? "Done" : "Select") {
                        nav.selecting.toggle()
                        if !nav.selecting { inbox.selected = [] }
                    }
                }
                .horizontalOnly()
            }
        }
    }

    private func detailsSheet(_ request: MediaRequest) -> some View {
        NavigationStack {
            ScrollView {
                DecisionCardView(
                    request: request, triage: inbox.triage[request.id], own: inbox.isLocked(request, viewerId: viewerId),
                    armed: inbox.armedId == request.id,
                    onApprove: { if inbox.approve(request, viewerId: viewerId) { details = nil } },
                    onDecline: { if inbox.decline(request, viewerId: viewerId) { details = nil } },
                    onSkip: { details = next(after: request) },
                    onAdjust: { details = nil; adjusting = request },
                    onDeclineWithNote: { details = nil; noting = request },
                    onMessage: { details = nil; onOpenThread(request) },
                    onOpenTitle: { details = nil; openTitle(request) })
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle("Decide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { SheetDoneButton { details = nil } } }
            .closeOnlyBars()
        }
        .presentationDetents([.large])
    }

    /// Skip: the next waiting request, if any.
    private func next(after request: MediaRequest) -> MediaRequest? {
        let queue = inbox.queue
        guard let i = queue.firstIndex(where: { $0.id == request.id }), i + 1 < queue.count else { return nil }
        return queue[i + 1]
    }

    private func openTitle(_ r: MediaRequest) {
        if let id = inbox.triage[r.id]?.itemId ?? r.mediaItemId {
            model.open(id)
        } else {
            let anime = inbox.triage[r.id]?.isAnime == true && r.kind == .series
            store.preview = PreviewRoute(kind: anime ? .anime : r.previewKind, tmdbId: r.tmdbId)
        }
    }
}
