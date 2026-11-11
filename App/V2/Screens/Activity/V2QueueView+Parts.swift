import SwiftUI
import FusionhaKit

// The v2 queue's columns and actions: the list, the open Duo's right page,
// the row actions, the `?focus=` link and select mode.

extension V2QueueView {
    /// The scrolling list: caption and scopes, then the state's content.
    var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    V2QueueHeader(counts: counts, loaded: store.loaded)
                        .padding(.trailing, splits ? 0 : columnReserve)
                        .id(FoldAnchorTop.header)
                        .foldAnchor(FoldAnchorTop.header)
                    content
                }
                .padding(.horizontal, gutter)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.immediately)
            .keepsFoldAnchor(anchor, proxy: proxy, active: dragShare == nil)
            .onChange(of: model.pendingQueueScroll, initial: true) { consumeFocus(proxy) }
            .onChange(of: store.items.map(\.id)) { consumeFocus(proxy) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !store.loaded && store.error == nil {
            ProgressView("Loading the download queue…").frame(maxWidth: .infinity).padding(.top, 40)
        } else if store.error != nil && store.items.isEmpty {
            ContentUnavailableView("The queue could not be loaded", systemImage: "exclamationmark.icloud",
                                   description: Text("Check the server and try again."))
        } else if store.items.isEmpty && !search.isEmpty {
            ContentUnavailableView.search(text: search)
        } else if store.items.isEmpty {
            V2QueueIdleView(feed: feed, lastImport: store.lastImport, attentionOnRight: splits,
                            openHistory: { chrome.tab = .history })
        } else {
            SixCountPipelineStrip(counts: counts, today: feed.summary?.history.today, items: store.items,
                                  showsHeld: splits)
            V2QueueSections(store: store, summary: feed.summary, selecting: selecting, selected: $selected,
                            openHeld: splits ? openHeld?.id : nil, review: openDecision,
                            reviewAll: { router.manualImport(rescue: $0) }, actions: rowActions,
                            openHistory: { chrome.tab = .history }, runsInOverview: splits)
            if store.hasMore {
                Button(store.loadingMore ? "Loading…" : "Load \(store.total - store.items.count) more") {
                    Task { await store.loadMore(model.client) }
                }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity)
                .disabled(store.loadingMore)
            }
        }
    }

    /// The open Duo's right page: the bulk remove panel while selecting,
    /// else the open (or first) held download's decision, else the idle page.
    @ViewBuilder
    var rightPage: some View {
        if selecting, !selected.isEmpty {
            QueueBulkRemovePanel(items: selectedItems, telemetry: store.telemetry,
                                 remove: { await ops.bulkRemove(selectedItems, option: $0) },
                                 done: endSelecting)
        } else if let item = openHeld {
            HeldDecisionPage(item: item, siblings: V2QueueSiblings.of(item, in: store.items), canDecide: canDecide,
                             dense: true, gutter: 24, draft: heldDraft,
                             review: { router.manualImport(rescue: item.id) },
                             perform: { await ops.perform($0, on: item) },
                             done: { withAnimation(motion ? .snappy(duration: 0.25) : nil) { decision = nil } })
                .id(item.id)
                .transition(motion ? .opacity.combined(with: .offset(x: 12)) : .opacity)
        } else {
            QueueIdleRightPage(tasks: feed.summary?.tasks)
                .transition(.opacity)
        }
    }

    /// The decision on the right page: the held download tapped (none is
    /// preselected: with nothing picked the queue is the wide side and the
    /// overview the narrow one, owner on build 805).
    var openHeld: QueueItem? {
        guard let decision else { return nil }
        return store.items.first { $0.id == decision && $0.cockpitState == .held }
    }

    func openDecision(_ item: QueueItem) {
        if splits {
            withAnimation(motion ? .snappy(duration: 0.25) : nil) { decision = item.id }
        } else {
            sheetDecision = V2HeldRef(id: item.id)
        }
    }

    var rowActions: V2QueueRowActions {
        V2QueueRowActions(
            openTitle: { model.open($0.mediaItemId) },
            remove: { removing = $0 },
            regrab: { item in
                guard let id = item.grabHistoryId else { return }
                Task { await ActActions.regrab(model.client, toaster, historyId: id) { Task { await store.refresh(model.client) } } }
            },
            interactive: { model.open($0.mediaItemId) },
            blocklist: { item in
                Task { await ActActions.blocklist(model.client, toaster, BlocklistCreate(downloadId: item.id, search: false)) }
            },
            copy: { ActActions.copy($0.releaseTitle, toaster) },
            manualImport: { router.manualImport(rescue: $0.id) })
    }

    /// `?focus=<download>` (the bar's Review, a push, the title's Needs you):
    /// a held download opens its decision; any other scrolls into view.
    func consumeFocus(_ proxy: ScrollViewProxy) {
        guard let id = model.pendingQueueScroll, store.loaded else { return }
        model.pendingQueueScroll = nil
        // v2 has no block-release-group prompt yet, so a `block=1` focus is consumed too (not left stale).
        if model.pendingQueueFocus?.downloadId == id { model.pendingQueueFocus = nil }
        guard let item = store.items.first(where: { $0.id == id }) else { return }
        if item.cockpitState == .held { openDecision(item) }
        withAnimation(motion ? .snappy(duration: 0.4) : nil) { proxy.scrollTo(id, anchor: .center) }
    }

    func processNow() {
        processing = true
        Task {
            await ops.processNow()
            processing = false
        }
    }

    func toggleSelect() {
        if selecting { endSelecting() } else { selecting = true }
    }

    func endSelecting() {
        selecting = false
        selected = []
    }

    func regrabSelected() {
        let items = selectedItems
        busy = true
        Task {
            await ops.regrab(items)
            busy = false
        }
    }
}
