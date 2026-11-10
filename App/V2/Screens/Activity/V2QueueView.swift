import SwiftUI
import FusionhaKit

/// v2's Activity › Queue (plan S8, mock activity.js queue on the W1 ground).
/// It sits in v1's Activity page (`ActivityQueueRoot`; the other tabs, the
/// bar's Manual import and Pause, the toaster and Manual Import's router
/// stay v1's) and reuses v1's `QueueStore`, sections, idle feed and API
/// calls. The caption, glass scopes, pipeline strip, then one W1 module per
/// section; a held row opens its decision (a sheet on the phone, the right
/// page on the open Duo). Flat open the live queue is the wide side and the
/// overview (needs attention, this week, up next) the narrow one, with a
/// grip on the hairline to resize it (owner on build 805); a decision
/// takes the wide side while it is open.
/// Title search is the bar's pull-down field; More holds Process queue,
/// Select and Clear.
struct V2QueueView: View {
    let search: String
    @Environment(AppModel.self) var model
    @Environment(\.collapsedTabs) var tabs
    @Environment(ActToaster.self) var toaster
    @Environment(ActRouter.self) var router
    @Environment(ActChrome.self) var chrome
    @Environment(\.paneSize) var pane
    @Environment(\.duoOpen) var duoOpen
    @Environment(\.bookPose) var bookPose
    @Environment(\.motionEnabled) var motion
    @State var store = QueueStore()
    @State var feed = QueueIdleFeed()
    @State var selecting = false
    @State var selected: Set<Int> = []
    /// The held download open on the right page (open Duo); nil = the first.
    @State var decision: Int?
    /// The held download open in the phone's sheet.
    @State var sheetDecision: V2HeldRef?
    @State var bulkSheet = false
    @State var removing: QueueItem?
    @State var clearing = false
    @State var processing = false
    @State var busy = false
    /// The live queue's share of the flat open Duo, kept per device.
    @AppStorage("v2.activity.queueShare") var queueShare = QueueDuoRuleV2.queueShare
    /// The share while the grip is being dragged.
    @State var dragShare: Double?
    /// The row at the list's top, kept across a fold (`FoldAnchor`).
    @State var anchor = FoldAnchorTracker()
    /// The open decision's choice and scroll, for its page and its sheet alike.
    @State var heldDraft = HeldDecisionDraft()

    var ops: V2QueueOps { V2QueueOps(model: model, toaster: toaster, store: store) }
    var splits: Bool { QueueDuoRuleV2.splits(width: Double(pane.width), duoOpen: duoOpen) }
    var gutter: CGFloat { pane.width >= 700 ? 24 : 20 }
    var canDecide: Bool { model.me?.can("integrations.manage") == true }
    var counts: V2QueueCounts { V2QueueCounts(items: store.items, total: store.total) }
    var selectedItems: [QueueItem] { store.items.filter { selected.contains($0.id) } }

    /// Process, Select and Clear: in the bar, or under the tabs' arrow.
    private var moreMenu: some View {
        V2QueueMoreMenu(processing: processing, selecting: selecting,
                        canClear: search.isEmpty && !store.hasMore, isEmpty: store.items.isEmpty,
                        process: processNow, toggleSelect: toggleSelect, clear: { clearing = true })
    }

    var body: some View {
        @Bindable var chrome = chrome
        HStack(spacing: 0) {
            list.frame(width: splits ? listWidth : nil)
            if splits {
                if bookPose {
                    Color.clear.frame(width: CGFloat(QueueDuoRuleV2.gap(bookPose: true)))
                } else {
                    Rectangle().fill(Theme.txt.opacity(0.12)).frame(width: 0.5).ignoresSafeArea()
                        .overlay {
                            if !deciding {
                                V2QueueSplitHandle(width: pane.width, queueWidth: listWidth, dragShare: $dragShare) { share in
                                    withAnimation(motion ? .snappy(duration: 0.25) : nil) { queueShare = share }
                                }
                            }
                        }
                }
                rightPage.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .v2PageGround(art: groundArt)
        .searchable(text: $chrome.searchInput, placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: "Search titles")
        .toolbar {
            if !tabs.on {
                ToolbarItem(placement: .primaryAction) { moreMenu }
            }
        }
        .columnActions(tabs.on, [
            .control("Queue", stamp: "\(processing)|\(selecting)|\(store.items.isEmpty)|\(search.isEmpty && !store.hasMore)") {
                moreMenu
            },
        ])
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if selecting {
                V2QueueBulkBar(count: selected.count, busy: busy,
                               selectAll: { selected = Set(store.items.map(\.id)) },
                               regrab: regrabSelected,
                               remove: { if !splits { bulkSheet = true } })
            }
        }
        .toolbarVisibility(selecting ? .hidden : .automatic, for: .tabBar)
        .animation(motion ? .snappy(duration: 0.28) : nil, value: selecting)
        .animation(motion ? .snappy(duration: 0.28) : nil, value: splits)
        .task(id: search) { await poll() }
        .task { await feed.run(model.client) }
        .onChange(of: store.items.map(\.id)) { selected.formIntersection(Set(store.items.map(\.id))) }
        // Fold continuity: the picked held download moves between the right page and its sheet.
        .foldPick(splits: splits, picked: $decision, sheet: $sheetDecision, id: \.id) { [store] id in
            store.items.contains { $0.id == id && $0.cockpitState == .held } ? V2HeldRef(id: id) : nil
        }
        .sheet(item: $sheetDecision) { ref in
            HeldDecisionSheet(ref: ref, store: store, canDecide: canDecide, draft: heldDraft,
                              review: { item in
                                  // Manual Import is Activity's sheet: open it once this one has gone.
                                  Task { @MainActor in
                                      try? await Task.sleep(for: .milliseconds(450))
                                      router.manualImport(rescue: item.id)
                                  }
                              },
                              perform: { await ops.perform($0, on: $1) })
                .environment(model)
        }
        .sheet(isPresented: $bulkSheet) { bulkRemoveSheet }
        .sheet(item: $removing) { item in
            RemoveQueueDialog(item: item, offerSearch: item.cockpitState == .held) { deleteData, blocklist, search in
                removing = nil
                Task {
                    // The server searches only alongside a blocklist; otherwise search here (as v1).
                    let ok = await ops.remove([item], deleteData: deleteData, blocklist: blocklist, search: search && blocklist)
                    if ok, search, !blocklist {
                        await ActActions.search(model.client, toaster, itemId: item.mediaItemId, editionId: item.editionId,
                                                message: "Searching again for \(item.title)")
                    }
                }
            } onCancel: { removing = nil }
        }
        .confirmationDialog("Clear the whole queue?", isPresented: $clearing, titleVisibility: .visible) {
            Button("Clear queue", role: .destructive) { Task { await ops.clearAll() } }
        } message: {
            Text("All \(ActFmt.plural(store.total, "download")) leave the download queue. Downloaded files stay on disk and nothing is blocklisted, so anything still wanted can be searched again.")
        }
    }

    /// A decision or the bulk remove panel is on the right page: it gets the
    /// wide side and the queue the mock's third.
    var deciding: Bool { openHeld != nil || (selecting && !selected.isEmpty) }

    /// The queue column's width in the split: the remembered (or dragged)
    /// share while live, the third while deciding, equal pages in book pose.
    var listWidth: CGFloat {
        let width = Double(pane.width)
        if deciding { return CGFloat(QueueDuoRuleV2.listWidth(width: width, bookPose: bookPose)) }
        return CGFloat(QueueDuoRuleV2.queueWidth(width: width, share: dragShare ?? queueShare, bookPose: bookPose))
    }

    /// The ground's art: the open decision's title, else the first download's.
    private var groundArt: URL? {
        let lead = splits ? (openHeld ?? store.items.first) : store.items.first
        return V2QueueGround.art(for: lead, library: model.library)
    }

    private func poll() async {
        await store.reload(model.client, query: search)
        while await ActivityPoll.next(after: .milliseconds(store.hasActiveWork ? 1500 : 4000), model: model) {
            await store.refresh(model.client)
        }
    }

    private var bulkRemoveSheet: some View {
        NavigationStack {
            QueueBulkRemovePanel(items: selectedItems, telemetry: store.telemetry,
                                 remove: { await ops.bulkRemove(selectedItems, option: $0) },
                                 done: { bulkSheet = false; endSelecting() })
                .navigationTitle("Remove")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") { bulkSheet = false }
                    }
                }
                .v2PageGround(art: nil)
        }
        .presentationDetents([.large])
    }
}
