import SwiftUI
import FusionhaKit

// The web's Queue tab (`routes/activity/QueueTab.tsx`): toolbar, bandwidth /
// pipeline hero, the card sections, Up next, Just finished, select mode and
// the remove / clear dialogs. The sections are in `QueueTabSections.swift`,
// the actions in `QueueTabActions.swift`, the `?focus=` link in `QueueFocus.swift`.

struct ActivityQueueTab: View {
    let search: String
    @Environment(AppModel.self) var model
    @Environment(ActToaster.self) var toaster
    @Environment(ActBulk.self) var bulk
    @Environment(ActRouter.self) var router
    @Environment(ActChrome.self) var chrome
    @Environment(\.actReduceMotion) var reduce
    @State var store = QueueStore()
    @State var selecting = false
    @State var selected: Set<Int> = []
    @State var processing = false
    @State var removing: QueueItem?
    @State var removingOfferSearch = false
    @State var bulkRemove: Bool?
    @State var clearing = false
    @State var busy = false
    @State var upNextOpen = false
    /// The one compact Up next row opened in place.
    @State var upNextOpenId: Int?
    /// A `?focus=` download: its card is flashed and its group opened.
    @State var focusId: Int?

    var body: some View {
        let _ = PerfCount.hit("ActivityQueueTab.body")
        ScrollViewReader { proxy in
            ActivityPage { content }
                .onChange(of: model.pendingQueueScroll, initial: true) { bringFocusForward(proxy) }
                .onChange(of: store.items.map(\.id)) { bringFocusForward(proxy) }
        }
        .animation(reduce ? nil : ActMotion.rows, value: store.items.map(\.id))
        .task(id: search) {
            await store.reload(model.client, query: search)
            while await ActivityPoll.next(after: .milliseconds(store.hasActiveWork ? 1500 : 4000), model: model) {
                await store.refresh(model.client)
            }
        }
        .onChange(of: selecting) { publishBulk() }
        .onChange(of: selected) { publishBulk() }
        .onChange(of: store.items.map(\.id)) {
            selected.formIntersection(Set(store.items.map(\.id)))
            publishBulk()
        }
        .onDisappear { bulk.config = nil }
        .sheet(item: $removing) { item in
            RemoveQueueDialog(item: item, offerSearch: removingOfferSearch) { removeData, blocklist, search in
                removing = nil
                Task { await remove([item], deleteData: removeData, blocklist: blocklist, search: search, single: true) }
            } onCancel: { removing = nil }
        }
        .sheet(isPresented: Binding(get: { bulkRemove != nil }, set: { if !$0 { bulkRemove = nil } })) {
            let chosen = store.items.filter { selected.contains($0.id) }
            BulkRemoveDialog(count: chosen.count, fileCount: chosen.filter { $0.hasDownloadedFile == true }.count,
                             defaultBlocklist: bulkRemove ?? false, busy: busy) { deleteFiles, blocklist in
                bulkRemove = nil
                Task {
                    await remove(chosen, deleteData: deleteFiles, blocklist: blocklist, search: false, single: false)
                    selected = []
                }
            } onCancel: { bulkRemove = nil }
        }
        .sheet(isPresented: $clearing) {
            ActDialog(title: "Clear the whole queue?",
                      message: "All \(ActFmt.plural(store.total, "download")) will be removed from the download queue. Downloaded files are left on disk and releases are not blocklisted, so anything still wanted can be searched again.",
                      confirmLabel: busy ? "Clearing…" : "Clear queue", busy: busy,
                      onCancel: { clearing = false },
                      onConfirm: { Task { await clearAll() } }) { EmptyView() }
        }
    }

    // MARK: Layout

    @ViewBuilder
    private var content: some View {
        if !store.loaded && store.error == nil {
            ActEmpty(message: "Loading the download queue…")
        } else if store.error != nil && store.items.isEmpty {
            ActEmpty(message: "The download queue could not be loaded. Check the backend and try again.")
        } else if store.items.isEmpty && !search.isEmpty {
            ActEmpty(message: "No downloads match “\(search)”.")
        } else if store.items.isEmpty && finished.rows.isEmpty {
            // Nothing downloading: system status instead of a blank list (0.4.156).
            QueueClearView(celebrate: store.sawWork).transition(reduce ? .opacity : .opacity.combined(with: .offset(y: 10)))
        } else {
            // Flat children of the page's lazy stack: each section header and card is its own child.
            QueueToolbar(total: store.total, selecting: $selecting, selected: $selected, processing: processing,
                         canClear: search.isEmpty && !store.hasMore,
                         process: { Task { await processNow() } }, clear: { clearing = true })
                .padding(.bottom, 12)
            if !store.items.isEmpty { hero.padding(.bottom, 18) }
            sections
            ActFooter(total: store.total, loaded: store.items.count, hasMore: store.hasMore, loading: store.loadingMore,
                      noun: "downloads", query: search) { Task { await store.loadMore(model.client) } }
        }
    }

    var finished: (rows: [QueueLogic.Finished], overflow: Int) { QueueLogic.justFinished(store.justFinished) }

    /// The web's pipeline strip, the only hero it has (Q8).
    private var hero: some View {
        let items = store.items
        let realBps = items.filter { !$0.isPhaseMode && [.downloading, .stalled, .awaiting].contains($0.cockpitState) }
            .reduce(0) { $0 + (store.telemetry[$1.id]?.bps ?? 0) }
        return PipelineHero(items: items, aggregateBps: realBps, hasPhaseWork: items.contains { $0.isPhaseMode },
                            lastImport: store.lastImport)
    }
}

/// The tab's toolbar: the count, Process queue now, Clear queue, Select.
struct QueueToolbar: View {
    let total: Int
    @Binding var selecting: Bool
    @Binding var selected: Set<Int>
    let processing: Bool
    let canClear: Bool
    let process: () -> Void
    let clear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(ActFmt.plural(total, "download"))
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.txt)
            Spacer(minLength: 0)
            if !selecting {
                toolButton("arrow.clockwise", processing ? "Processing…" : "Process queue now", spinning: processing, action: process)
                    .disabled(processing)
                toolButton("trash", "Clear queue", tint: Theme.miss, border: Theme.miss.opacity(0.45), action: clear)
                    .disabled(!canClear)
            }
            toolButton(selecting ? "checkmark" : "checklist", selecting ? "Done" : "Select") {
                selecting.toggle()
                if !selecting { selected = [] }
            }
        }
    }

    private func toolButton(_ icon: String, _ label: String, tint: Color = Theme.mut, border: Color? = nil,
                            spinning: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .actSpin(spinning)
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .overlay { if let border { RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(border) } }
                .contentShape(Rectangle())
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .padding(.horizontal, -7).padding(.vertical, -7)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
