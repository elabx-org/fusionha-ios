import SwiftUI
import FusionhaKit

// The web's Queue tab (`routes/activity/QueueTab.tsx`): toolbar, bandwidth /
// pipeline hero, Working · Downloading · Retrying · Up next · Just finished
// sections, cockpit rows, held/stuck attention cards, select mode and the
// remove / clear dialogs. Pieces live beside this file in Activity/Queue/.

// MARK: - Tab

struct ActivityQueueTab: View {
    let search: String
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(ActBulk.self) private var bulk
    @Environment(ActRouter.self) private var router
    @Environment(\.actReduceMotion) private var reduce
    @State private var store = QueueStore()
    @State private var selecting = false
    @State private var selected: Set<Int> = []
    @State private var processing = false
    @State private var removing: QueueItem?
    @State private var removingOfferSearch = false
    @State private var bulkRemove: Bool?
    @State private var clearing = false
    @State private var busy = false
    @State private var upNextOpen = false

    var body: some View {
        let _ = PerfCount.hit("ActivityQueueTab.body")
        ActivityPage { content }
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
            toolbar.padding(.bottom, 12)
            if !store.items.isEmpty { hero.padding(.bottom, 18) }
            sections
            ActFooter(total: store.total, loaded: store.items.count, hasMore: store.hasMore, loading: store.loadingMore,
                      noun: "downloads", query: search) { Task { await store.loadMore(model.client) } }
        }
    }

    private var finished: (rows: [QueueLogic.Finished], overflow: Int) { QueueLogic.justFinished(store.justFinished) }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Text(ActFmt.plural(store.total, "download"))
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.txt)
            Spacer(minLength: 0)
            if !selecting {
                toolButton("arrow.clockwise", processing ? "Processing…" : "Process queue now", spinning: processing) {
                    Task { await processNow() }
                }
                .disabled(processing)
                toolButton("trash", "Clear queue", tint: Theme.miss, border: Theme.miss.opacity(0.45)) { clearing = true }
                    .disabled(!search.isEmpty || store.hasMore)
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

    @ViewBuilder
    private var hero: some View {
        let items = store.items
        let hasPhase = items.contains { $0.isPhaseMode }
        let realBps = items.filter { !$0.isPhaseMode && [.downloading, .stalled, .awaiting].contains($0.cockpitState) }
            .reduce(0) { $0 + (store.telemetry[$1.id]?.bps ?? 0) }
        if !hasPhase && (items.contains { $0.isByteTransferring } || realBps > 0) {
            BandwidthPulseHero(items: items, history: store.bandwidth)
        } else {
            PipelineHero(items: items, aggregateBps: realBps, hasPhaseWork: hasPhase, lastImport: store.lastImport)
        }
    }

    @ViewBuilder
    private var sections: some View {
        let items = store.items
        let routed = Dictionary(grouping: items, by: QueueSection.of)
        let cards = QueueSection.cardSections.compactMap { key -> (QueueSection, [QueueLogic.Entry])? in
            let list = routed[key] ?? []
            return list.isEmpty ? nil : (key, QueueLogic.entries(list, section: key, telemetry: store.telemetry))
        }
        let upNext = routed[.upnext] ?? []
        let soonest = cards.first { $0.0 == .downloading }?.1.first { $0.eta != nil }?.id
        let finished = self.finished
        let first = cards.first?.0.label ?? (upNext.isEmpty ? "Just finished" : "Up next")
        Group {
            ForEach(cards, id: \.0) { key, entries in
                section(key.label, entries.reduce(0) { $0 + $1.downloadCount }, key.hint ?? "", first: first,
                        trailing: key == .needs ? reviewAll(items) : nil) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        card(entry, soonest: soonest == entry.id)
                            .actReveal(index).actRowTransition(reduce)
                    }
                }
            }
            if let onDeck = upNext.first {
                let rest = Array(upNext.dropFirst())
                let visible = upNextOpen ? rest : Array(rest.prefix(4))
                section("Up next", upNext.count, "next to grab", first: first) {
                    selectable(onDeck) { OnDeckCard(item: onDeck, actions: actions(for: onDeck)) }
                        .actReveal(0)
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
                        selectable(item) { CompactUpNextRow(item: item, position: index + 2, actions: actions(for: item)) }
                            .actReveal(index + 1, stagger: 0.03).actRowTransition(reduce)
                    }
                    if rest.count > visible.count {
                        Button("+ \(rest.count - visible.count) more queued") { upNextOpen = true }
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Theme.mut)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                            .buttonStyle(.plain)
                    }
                }
            }
            if !finished.rows.isEmpty {
                section("Just finished", finished.rows.count, "clears to History in ~20s", first: first) {
                    ForEach(Array(finished.rows.enumerated()), id: \.element.id) { index, entry in
                        JustFinishedRow(entry: entry).actReveal(index).actRowTransition(reduce)
                    }
                    if finished.overflow > 0 {
                        Text("+\(finished.overflow) more · view in History")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Theme.mut)
                    }
                }
            }
        }
    }

    /// One card: a held or other single download, or a group / pair card.
    @ViewBuilder
    private func card(_ entry: QueueLogic.Entry, soonest: Bool) -> some View {
        switch entry {
        case .solo(let item, _):
            if item.cockpitState == .held {
                selectable(item) { QueueHeldCard(item: item, actions: actions(for: item)) }
            } else {
                selectable(item) {
                    QueueStateCard(item: item, telemetry: store.telemetry[item.id], actions: actions(for: item), soonest: soonest)
                }
            }
        case .group(let group, let eta):
            QueueGroupCard(group: group, telemetry: store.telemetry, eta: eta, soonest: soonest,
                           selecting: selecting, selected: $selected,
                           actionsFor: { actions(for: $0) },
                           removeMany: { ids, blocklist, deleteData in
                               let chosen = store.items.filter { ids.contains($0.id) }
                               Task { await remove(chosen, deleteData: deleteData, blocklist: blocklist, search: false, single: false) }
                           },
                           pick: { selecting = true })
        }
    }

    /// Needs you's "Review all N": an outline capsule, right-aligned (0.4.198).
    private func reviewAll(_ items: [QueueItem]) -> AnyView? {
        let held = items.filter { $0.cockpitState == .held }.map(\.id)
        guard held.count > 1 else { return nil }
        return AnyView(
            Button("Review all \(held.count)") { router.manualImport(rescue: held) }
                .buttonStyle(ActButtonStyle(kind: .subtle))
                .accessibilityLabel("Review all \(held.count) in Manual Import")
        )
    }

    /// A section as flat children: its header, then each card (10pt apart; sections 24pt apart).
    @ViewBuilder
    private func section<C: View>(_ title: String, _ count: Int, _ hint: String, first: String,
                                  trailing: AnyView? = nil, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                ActSection(title: title, count: count)
                if let trailing { trailing }
            }
            if !hint.isEmpty {
                Text(hint).font(.system(size: 13)).foregroundStyle(Theme.dim)
            }
        }
        .padding(.top, title == first ? 0 : 24)
        Group { content() }.padding(.top, 10)
    }

    @ViewBuilder
    private func selectable<C: View>(_ item: QueueItem, @ViewBuilder _ card: () -> C) -> some View {
        if selecting {
            HStack(alignment: .center, spacing: 10) {
                ActCheckbox(checked: selected.contains(item.id))
                card().allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) }
            }
            .actSelected(selected.contains(item.id))
        } else {
            card()
                .contentShape(Rectangle())
                .onTapGesture { model.open(item.mediaItemId) }
        }
    }

    // MARK: Actions

    private func actions(for item: QueueItem) -> QueueRowActions {
        QueueRowActions(
            remove: { offerSearch in removingOfferSearch = offerSearch; removing = item },
            manualImport: { router.manualImport(rescue: item.id) },
            search: {
                Task { await ActActions.search(model.client, toaster, itemId: item.mediaItemId, editionId: item.editionId,
                                               message: "Searching again for \(item.title)") }
            },
            interactive: { model.open(item.mediaItemId) },
            blocklist: { search in
                Task { await ActActions.blocklist(model.client, toaster, BlocklistCreate(downloadId: item.id, search: search)) {
                    Task { await store.refresh(model.client) }
                } }
            },
            copy: { ActActions.copy(item.releaseTitle, toaster) },
            regrab: item.grabHistoryId.map { historyId -> () -> Void in
                return {
                    Task { await ActActions.regrab(model.client, toaster, historyId: historyId) {
                        Task { await store.refresh(model.client) }
                    } }
                }
            })
    }

    private func processNow() async {
        guard let client = model.client else { return }
        processing = true
        defer { processing = false }
        do {
            let r = try await client.processQueueNow()
            if r.skipped {
                switch r.skipReason {
                case "busy": toaster.show("A queue pass is already running — try again in a moment")
                case "removed_mid_pass": toaster.show("The queue changed while processing — refreshed")
                default: toaster.show("Real integrations are off — nothing to process")
                }
            } else {
                toaster.show("Queue processed — \(r.imported) imported, \(r.resolved) reconciled, \(r.left) left", tone: .success)
            }
            await store.refresh(client)
            await model.refreshQueue()
        } catch {
            toaster.error(error)
        }
    }

    private func remove(_ items: [QueueItem], deleteData: Bool, blocklist: Bool, search: Bool, single: Bool) async {
        guard let client = model.client, !items.isEmpty else { return }
        busy = true
        defer { busy = false }
        var firstError: Error?
        await withTaskGroup(of: Error?.self) { group in
            for item in items {
                group.addTask {
                    do {
                        try await client.removeQueueItem(id: item.id, deleteData: deleteData && item.hasDownloadedFile == true,
                                                         blocklist: blocklist, search: search)
                        return nil
                    } catch { return error }
                }
            }
            for await result in group where firstError == nil { firstError = result }
        }
        if reduce { store.dropLocally(Set(items.map(\.id))) } else {
            withAnimation(ActMotion.rows) { store.dropLocally(Set(items.map(\.id))) }
        }
        if let firstError {
            toaster.error(firstError)
        } else if !single {
            let n = items.count
            toaster.show(blocklist ? "Blocklisted & removed \(ActFmt.plural(n, "download"))"
                                   : "Removed \(ActFmt.plural(n, "download")) from the queue", tone: .success)
        }
        // The server only searches with a blocklist; without one, search the
        // version here, as the web's card does (`use-search-again`).
        if firstError == nil, search, !blocklist {
            for item in items {
                await ActActions.search(client, toaster, itemId: item.mediaItemId, editionId: item.editionId,
                                        message: "Searching again for \(item.title)")
            }
        }
        await store.refresh(client)
        await model.refreshQueue()
    }

    private func clearAll() async {
        guard let client = model.client else { return }
        let ids = store.items
        busy = true
        var failure: Error?
        for item in ids {
            do { try await client.removeQueueItem(id: item.id) } catch { failure = failure ?? error }
        }
        busy = false
        clearing = false
        if let failure { toaster.error(failure) } else {
            toaster.show("Cleared \(ActFmt.plural(ids.count, "download")) from the queue", tone: .success)
        }
        selected = []
        await store.refresh(client)
        await model.refreshQueue()
    }

    private func publishBulk() {
        guard selecting else { bulk.config = nil; return }
        let count = selected.count
        bulk.config = ActBulk.Config(
            count: count,
            hint: store.hasMore ? "Select all covers the \(store.items.count) loaded — scroll to load the rest" : nil,
            onSelectAll: { selected = Set(store.items.map(\.id)) },
            actions: [
                ActBulk.Action(label: "Blocklist & remove", icon: "nosign", kind: .warn, disabled: count == 0 || busy) { bulkRemove = true },
                ActBulk.Action(label: "Remove from queue", kind: .danger, disabled: count == 0 || busy) { bulkRemove = false },
            ])
    }
}

struct QueuePrimary {
    let icon: String
    let label: String
    let run: () -> Void
}

struct QueueRowActions {
    var remove: (_ offerSearch: Bool) -> Void
    var manualImport: () -> Void
    var search: () -> Void
    var interactive: () -> Void
    var blocklist: (_ search: Bool) -> Void
    var copy: () -> Void
    /// Re-grab this release (0.4.189); nil when no grab record survives.
    var regrab: (() -> Void)? = nil
}
