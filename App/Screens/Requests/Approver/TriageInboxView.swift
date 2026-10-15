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
    @State private var inbox = InboxModel()
    @State private var listMode = false
    @State private var details: MediaRequest?
    @State private var adjusting: MediaRequest?
    @State private var noting: MediaRequest?

    private var viewerId: Int? { model.me?.id }

    var body: some View {
        content
            .task {
                inbox.bind(model.client) { message, title, variant in model.toast(message, title: title, variant: variant) }
                await inbox.poll()
            }
            .onDisappear { inbox.flush() }
            .onChange(of: store.requestsVersion) { Task { await inbox.refresh() } }
            .overlay(alignment: .bottom) {
                if let decision = inbox.pending {
                    InboxUndoToast(decision: decision, onUndo: inbox.undo, onReason: inbox.setReason)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 8)
                }
            }
            .animation(.snappy, value: inbox.pending)
            .sheet(item: $details) { request in detailsSheet(request) }
            .sheet(item: $adjusting) { request in
                ApproveDialog(request: request) { Task { await inbox.refresh() } }
            }
            .sheet(item: $noting) { request in
                RejectDialog(request: request) { Task { await inbox.refresh() } }
            }
    }

    @ViewBuilder
    private var content: some View {
        if !inbox.loaded {
            DiscoverEmptyState(message: "Loading requests…")
        } else if inbox.failed && inbox.items.isEmpty {
            DiscoverEmptyState(message: "Could not load requests.")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if inbox.failed {
                    Text("Couldn’t refresh. Showing the last list.").font(.system(size: 12)).foregroundStyle(Theme.miss)
                }
                if listMode && !inbox.queue.isEmpty {
                    InboxListView(inbox: inbox, viewerId: viewerId, onOpen: { details = $0 },
                                  onBackToCards: { listMode = false; inbox.selected = [] })
                } else {
                    SwipeDeckView(inbox: inbox, viewerId: viewerId, onDetails: { details = $0 }, onAdjust: { adjusting = $0 },
                                  onSelectMode: { listMode = true }, onOpenThread: onOpenThread,
                                  onOpenBoard: onOpenBoard, onOpenHistory: onOpenHistory)
                }
            }
        }
    }

    private func detailsSheet(_ request: MediaRequest) -> some View {
        NavigationStack {
            ScrollView {
                DecisionCardView(
                    request: request, triage: inbox.triage[request.id], own: inbox.isOwn(request, viewerId: viewerId),
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
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { details = nil } } }
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
