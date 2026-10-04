import Charts
import SwiftUI
import FusionhaKit

// The web's Queue tab (`routes/activity/QueueTab.tsx`): toolbar, bandwidth /
// pipeline hero, Working · Downloading · Retrying · Up next · Just finished
// sections, cockpit rows, held/stuck attention cards, select mode and the
// remove / clear dialogs.

// MARK: - Logic (pure, mirrors the web helpers)

fileprivate enum QueueCockpitState { case held, stuck, stalled, importing, awaiting, queued, downloading }
fileprivate enum QueueLane { case working, retrying, byte }

fileprivate struct QueueTelemetry: Equatable {
    var bps: Double
    var eta: Double?
}

fileprivate struct PhaseMeta {
    let label: String
    let tone: Color
    let indeterminate: Bool
    let note: String
    let statBig: String
    let statSub: String
}

fileprivate extension QueueItem {
    var cockpitState: QueueCockpitState {
        let s = status.lowercased()
        if s == "held" { return .held }
        if needsAttention == true { return .stuck }
        if stalled { return .stalled }
        if s == "completed" { return .importing }
        if warning != nil { return .awaiting }
        if ["queued", "delay", "pending", "paused"].contains(s) { return .queued }
        return .downloading
    }

    var isPhaseMode: Bool { phase != nil && phase != "downloading" }

    var lane: QueueLane {
        guard isPhaseMode, let phase else { return .byte }
        if phase == "error" || (phaseTerminal == true && phase != "complete") { return .retrying }
        if phase == "queued" { return .byte }
        return .working
    }

    var pct: Int {
        let value: Double
        if size > 0 { value = (1 - sizeleft / size) * 100 } else { value = progress <= 1 ? progress * 100 : progress }
        guard value.isFinite else { return 0 }
        return Int(min(100, max(0, value.rounded())))
    }

    var bytesDone: Double { size > 0 ? max(0, size - sizeleft) : 0 }

    var isByteTransferring: Bool {
        guard !isPhaseMode else { return false }
        let st = cockpitState
        guard st == .downloading || st == .stalled else { return false }
        return progress > 0 || sizeleft < size
    }

    var isBytePreparing: Bool {
        guard !isPhaseMode, !isByteTransferring else { return false }
        return [.queued, .awaiting, .downloading, .stalled].contains(cockpitState)
    }

    var phaseMeta: PhaseMeta { QueueLogic.phaseMeta(phase) }

    var queuedAgo: String {
        let secs = max(0, Int((ageSeconds ?? 0).rounded()))
        if secs < 60 { return "just queued" }
        let mins = secs / 60
        if mins < 60 { return "queued \(mins)m ago" }
        let hours = mins / 60
        if hours < 24 { return "queued \(hours)h ago" }
        return "queued \(hours / 24)d ago"
    }

    var protocolLabel: String? { ActFmt.protocolLabel(self.protocol) }
}

fileprivate enum QueueLogic {
    static func phaseMeta(_ phase: String?) -> PhaseMeta {
        switch phase {
        case "parsing": return PhaseMeta(label: "PARSING", tone: Theme.indigo, indeterminate: true, note: "Reading release metadata…", statBig: "Parsing", statSub: "no transfer")
        case "processed": return PhaseMeta(label: "PROCESSED", tone: Theme.indigo, indeterminate: true, note: "Processing release…", statBig: "Processing", statSub: "no transfer")
        case "probing": return PhaseMeta(label: "PROBING", tone: Theme.indigo, indeterminate: true, note: "Checking article availability & health…", statBig: "Probing", statSub: "checking")
        case "caching": return PhaseMeta(label: "CACHING", tone: Theme.indigo, indeterminate: true, note: "Warming the cache…", statBig: "Caching", statSub: "no transfer")
        case "validating": return PhaseMeta(label: "VALIDATING", tone: Theme.indigo, indeterminate: true, note: "Validating linked files…", statBig: "Validating", statSub: "checking")
        case "linking": return PhaseMeta(label: "LINKING", tone: Theme.grab, indeterminate: false, note: "Linking files into the library…", statBig: "Linking", statSub: "linking files")
        case "complete": return PhaseMeta(label: "IMPORTING", tone: Theme.grab, indeterminate: true, note: "Symlinked — importing into library…", statBig: "Importing", statSub: "linked")
        case "importing": return PhaseMeta(label: "IMPORTING", tone: Theme.grab, indeterminate: true, note: "Importing into your library…", statBig: "Importing", statSub: "writing library entry")
        case "error": return PhaseMeta(label: "RETRYING", tone: Theme.miss, indeterminate: true, note: "Transient error — will retry", statBig: "Retry", statSub: "will retry")
        case "queued": return PhaseMeta(label: "QUEUED", tone: Theme.mut, indeterminate: true, note: "Waiting to start…", statBig: "Queued", statSub: "up next")
        default: return PhaseMeta(label: (phase ?? "working").uppercased(), tone: Theme.indigo, indeterminate: true, note: "Working…", statBig: "Working", statSub: "no transfer")
        }
    }

    /// The per-job rail: torrent Downloading → Linking → Caching → Importing;
    /// usenet Parsing → Processed → Linking → Caching → [Probing] → [Validating] → Importing.
    static func rail(for item: QueueItem) -> [String] {
        if item.protocol?.uppercased() == "TORRENT" { return ["Downloading", "Linking", "Caching", "Importing"] }
        var rail = ["Parsing", "Processed", "Linking", "Caching"]
        if item.phase == "probing" { rail.append("Probing") }
        if item.phase == "validating" { rail.append("Validating") }
        rail.append("Importing")
        return rail
    }

    static func railIndex(for item: QueueItem, rail: [String]) -> Int {
        let label: String
        switch item.phase {
        case "downloading": label = rail.first ?? "Parsing"
        case "parsing": label = "Parsing"
        case "processed": label = "Processed"
        case "linking": label = "Linking"
        case "caching": label = "Caching"
        case "probing": label = "Probing"
        case "validating": label = "Validating"
        case "complete", "importing": label = "Importing"
        default: label = rail.first ?? ""
        }
        return rail.firstIndex(of: label) ?? 0
    }

    static func stepFraction(_ step: String?) -> String? {
        guard let step, let match = step.range(of: #"(\d+)\s*(?:/|of)\s*(\d+)"#, options: .regularExpression) else { return nil }
        let nums = step[match].split(whereSeparator: { !$0.isNumber })
        guard nums.count == 2 else { return nil }
        return "\(nums[0]) / \(nums[1])"
    }

    static func noteLine(_ item: QueueItem) -> String {
        let meta = item.phaseMeta
        if item.phase == "error" { return item.nextStep ?? item.warning ?? item.step ?? meta.note }
        if item.phase == "linking", let frac = stepFraction(item.step) { return "Linking files into the library (\(frac))…" }
        return meta.note
    }

    // The hero's stage buckets.
    static let heroStages = ["Queued", "Parsing", "Processed", "Linking", "Caching", "Importing"]

    static func heroBucket(_ phase: String) -> Int {
        switch phase {
        case "queued": return 0
        case "parsing", "downloading": return 1
        case "processed": return 2
        case "linking": return 3
        case "caching", "probing", "validating": return 4
        default: return 5
        }
    }

    static func stageDistribution(_ items: [QueueItem]) -> [Int] {
        var d = Array(repeating: 0, count: heroStages.count)
        for item in items where item.lane != .retrying {
            if item.isPhaseMode, let phase = item.phase { d[heroBucket(phase)] += 1 } else if item.isBytePreparing { d[0] += 1 }
        }
        return d
    }

    static func workingFailed(_ items: [QueueItem]) -> (working: Int, failed: Int) {
        var working = 0, failed = 0
        for item in items {
            if item.lane == .retrying { failed += 1; continue }
            if item.isPhaseMode || item.isBytePreparing { working += 1 }
        }
        return (working, failed)
    }

    struct Group: Identifiable {
        let mediaItemId: Int
        var downloads: [QueueItem]
        var id: Int { mediaItemId }
    }

    static func group(_ items: [QueueItem]) -> [Group] {
        var order: [Int] = []
        var map: [Int: Group] = [:]
        for item in items {
            if map[item.mediaItemId] == nil {
                map[item.mediaItemId] = Group(mediaItemId: item.mediaItemId, downloads: [])
                order.append(item.mediaItemId)
            }
            map[item.mediaItemId]?.downloads.append(item)
        }
        return order.compactMap { map[$0] }
    }

    enum Entry: Identifiable {
        case solo(QueueItem, eta: Double?)
        case group(Group, eta: Double?)
        var id: String {
            switch self {
            case .solo(let item, _): return "solo:\(item.id)"
            case .group(let g, _): return "group:\(g.mediaItemId)"
            }
        }
        var eta: Double? {
            switch self {
            case .solo(_, let eta), .group(_, let eta): return eta
            }
        }
    }

    static func split(_ groups: [Group], telemetry: [Int: QueueTelemetry]) -> (active: [Entry], upNext: [QueueItem]) {
        var active: [Entry] = []
        var upNext: [QueueItem] = []
        for group in groups {
            let activeMembers = group.downloads.filter { $0.cockpitState != .queued }
            if activeMembers.isEmpty { upNext += group.downloads; continue }
            let etas = activeMembers.compactMap { telemetry[$0.id]?.eta }
            let eta = etas.min()
            active.append(group.downloads.count == 1 ? .solo(group.downloads[0], eta: eta) : .group(group, eta: eta))
        }
        let sorted = active.enumerated().sorted { a, b in
            switch (a.element.eta, b.element.eta) {
            case (nil, nil): return a.offset < b.offset
            case (nil, _): return false
            case (_, nil): return true
            case let (x?, y?): return x == y ? a.offset < b.offset : x < y
            }
        }.map(\.element)
        return (sorted, upNext)
    }

    struct Finished: Identifiable {
        let key: String
        let failed: Bool
        var item: QueueItem
        var count: Int
        let season: Int?
        var finishedAt: Date
        var id: String { key }
    }

    static let finishedWindow: Double = 20

    static func justFinished(_ rows: [QueueItem], now: Date = Date()) -> (rows: [Finished], overflow: Int) {
        var order: [String] = []
        var map: [String: Finished] = [:]
        for item in rows {
            guard let outcome = item.outcome, outcome == "imported" || outcome == "failed",
                  let at = ActFmt.date(item.finishedAt) else { continue }
            if now.timeIntervalSince(at) > finishedWindow { continue }
            let season = item.episodeLabel.flatMap { label -> Int? in
                guard let r = label.range(of: #"S(\d{1,3})"#, options: [.regularExpression, .caseInsensitive]) else { return nil }
                return Int(label[r].dropFirst())
            }
            let key = "\(item.mediaItemId) \(outcome) \(season.map(String.init) ?? "m")"
            if var existing = map[key] {
                existing.count += 1
                if at > existing.finishedAt { existing.item = item; existing.finishedAt = at }
                map[key] = existing
            } else {
                map[key] = Finished(key: key, failed: outcome == "failed", item: item, count: 1, season: season, finishedAt: at)
                order.append(key)
            }
        }
        let groups = order.compactMap { map[$0] }
        let failed = groups.filter(\.failed).sorted { $0.finishedAt > $1.finishedAt }
        let imported = groups.filter { !$0.failed }.sorted { $0.finishedAt > $1.finishedAt }
        let shownFailed = Array(failed.prefix(5))
        let shown = shownFailed + Array(imported.prefix(max(0, 5 - shownFailed.count)))
        return (shown, groups.count - shown.count)
    }

    /// `queueWashStatus`.
    static func wash(_ item: QueueItem) -> Color {
        switch item.cockpitState {
        case .held: return Theme.stuck
        case .stuck: return Theme.danger
        case .stalled: return Theme.stuck
        case .importing: return Theme.grab
        case .queued: return Theme.dim
        default:
            if item.phase == "error" || (item.phaseTerminal == true && item.phase != "complete") { return Theme.stuck }
            if item.phase == "queued" { return Theme.dim }
            return Theme.grab
        }
    }
}

// MARK: - Store (feed + live telemetry)

@MainActor
@Observable
fileprivate final class QueueStore {
    private(set) var items: [QueueItem] = []
    private(set) var total = 0
    private(set) var justFinished: [QueueItem] = []
    private(set) var loaded = false
    private(set) var error: String?
    private(set) var loadingMore = false
    private(set) var pages = 1
    private(set) var telemetry: [Int: QueueTelemetry] = [:]
    private(set) var bandwidth: [Double] = []
    private var samples: [Int: (done: Double, t: Date)] = [:]
    private var query = ""
    private var generation = 0

    var hasMore: Bool { items.count < total }
    var hasActiveWork: Bool {
        items.contains { !["completed", "imported", "failed"].contains($0.status.lowercased()) }
    }

    func reload(_ client: APIClient?, query: String) async {
        guard let client else { return }
        generation += 1
        let gen = generation
        if query != self.query { loaded = false; items = []; total = 0 }
        self.query = query
        pages = 1
        do {
            let page = try await client.queuePage(page: 1, pageSize: 50, query: query)
            guard gen == generation else { return }
            apply(page)
            error = nil
        } catch is CancellationError {
            return
        } catch {
            guard gen == generation else { return }
            if (error as? URLError)?.code == .cancelled { return }
            self.error = error.localizedDescription
        }
        loaded = true
    }

    func refresh(_ client: APIClient?) async {
        guard let client else { return }
        let gen = generation
        guard let page = try? await client.queuePage(page: 1, pageSize: min(50 * pages, 500), query: query),
              gen == generation else { return }
        apply(page)
        error = nil
        loaded = true
    }

    func loadMore(_ client: APIClient?) async {
        guard let client, hasMore, !loadingMore else { return }
        loadingMore = true
        defer { loadingMore = false }
        guard let page = try? await client.queuePage(page: pages + 1, pageSize: 50, query: query) else { return }
        let seen = Set(items.map(\.id))
        items += page.items.filter { !seen.contains($0.id) }
        total = page.total
        pages += 1
    }

    func dropLocally(_ ids: Set<Int>) {
        let before = items.count
        items.removeAll { ids.contains($0.id) }
        total = max(0, total - (before - items.count))
    }

    private func apply(_ page: QueuePage) {
        // Polled every 1.5s: only touch what changed so unchanged sections don't re-render.
        if items != page.items { items = page.items }
        if total != page.total { total = page.total }
        let finished = page.justFinished ?? []
        if justFinished != finished { justFinished = finished }
        sample(page.items)
    }

    /// Client-derived rate/ETA: bytes moved between polls (the web's `deriveQueueTelemetry`).
    private func sample(_ items: [QueueItem]) {
        let now = Date()
        var nextSamples: [Int: (done: Double, t: Date)] = [:]
        var next: [Int: QueueTelemetry] = [:]
        var aggregate = 0.0
        for item in items {
            let done = item.bytesDone
            nextSamples[item.id] = (done, now)
            var tel = QueueTelemetry(bps: 0, eta: nil)
            if let prev = samples[item.id], now > prev.t {
                let dt = now.timeIntervalSince(prev.t)
                let bps = dt > 0 ? max(0, (done - prev.done) / dt) : 0
                tel = QueueTelemetry(bps: bps, eta: bps > 0 ? (item.sizeleft > 0 ? item.sizeleft / bps : 0) : nil)
            } else if let old = telemetry[item.id] {
                tel = old
            }
            next[item.id] = tel
            if !item.isPhaseMode, [.downloading, .stalled, .awaiting].contains(item.cockpitState) { aggregate += tel.bps }
        }
        samples = nextSamples
        if telemetry != next { telemetry = next }
        bandwidth.append(aggregate)
        if bandwidth.count > 70 { bandwidth.removeFirst(bandwidth.count - 70) }
    }
}

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
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(store.hasActiveWork ? 1500 : 4000))
                    guard !Task.isCancelled else { break }
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
            ActEmpty(message: "Nothing is downloading right now. Grabbed releases appear here while they transfer.")
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
            PipelineHero(items: items, aggregateBps: realBps, hasPhaseWork: hasPhase)
        }
    }

    @ViewBuilder
    private var sections: some View {
        let items = store.items
        let working = items.filter { $0.lane == .working }.sorted { ($0.phasePercent ?? -1) > ($1.phasePercent ?? -1) }
        let retrying = items.filter { $0.lane == .retrying }
        let split = QueueLogic.split(QueueLogic.group(items.filter { $0.lane == .byte }), telemetry: store.telemetry)
        let soonest = split.active.first { $0.eta != nil }?.id
        let finished = self.finished
        let firstSection = !working.isEmpty ? "Working" : !split.active.isEmpty ? "Downloading"
            : !retrying.isEmpty ? "Retrying" : !split.upNext.isEmpty ? "Up next" : "Just finished"
        Group {
            if !working.isEmpty {
                section("Working", working.count, "symlink & checks · live phase", first: firstSection) {
                    ForEach(Array(working.enumerated()), id: \.element.id) { index, item in
                        selectable(item) { PhaseCard(item: item, lane: .working, actions: actions(for: item)) }
                            .actReveal(index).actRowTransition(reduce)
                    }
                }
            }
            if !split.active.isEmpty {
                section("Downloading", split.active.count, "finishing soonest", first: firstSection) {
                    ForEach(Array(split.active.enumerated()), id: \.element.id) { index, entry in
                        Group {
                            switch entry {
                            case .solo(let item, _):
                                if item.cockpitState == .held || item.cockpitState == .stuck {
                                    selectable(item) { AttentionCard(item: item, actions: actions(for: item)) }
                                } else {
                                    selectable(item) {
                                        QueueRowCard(item: item, telemetry: store.telemetry[item.id], soonest: soonest == entry.id,
                                                     actions: actions(for: item))
                                    }
                                }
                            case .group(let group, let eta):
                                QueueGroupCard(group: group, telemetry: store.telemetry, eta: eta, soonest: soonest == entry.id,
                                               selecting: selecting, selected: $selected,
                                               actionsFor: { actions(for: $0) },
                                               removeMany: { ids, blocklist in
                                                   let chosen = store.items.filter { ids.contains($0.id) }
                                                   Task { await remove(chosen, deleteData: false, blocklist: blocklist, search: false, single: false) }
                                               },
                                               pick: { selecting = true })
                            }
                        }
                        .actReveal(index).actRowTransition(reduce)
                    }
                }
            }
            if !retrying.isEmpty {
                section("Retrying", retrying.count, "transient — will retry", first: firstSection) {
                    ForEach(Array(retrying.enumerated()), id: \.element.id) { index, item in
                        selectable(item) { PhaseCard(item: item, lane: .retrying, actions: actions(for: item)) }
                            .actReveal(index).actRowTransition(reduce)
                    }
                }
            }
            if let onDeck = split.upNext.first {
                let rest = Array(split.upNext.dropFirst())
                let visible = upNextOpen ? rest : Array(rest.prefix(4))
                section("Up next", split.upNext.count, "next to grab", first: firstSection) {
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
                section("Just finished", finished.rows.count, "clears to History in ~20s", first: firstSection) {
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

    /// A section as flat children: its header, then each card (10pt apart; sections 24pt apart).
    @ViewBuilder
    private func section<C: View>(_ title: String, _ count: Int, _ hint: String, first: String,
                                  @ViewBuilder content: () -> C) -> some View {
        ActSection(title: title, count: count).padding(.top, title == first ? 0 : 24)
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
            copy: { ActActions.copy(item.releaseTitle, toaster) })
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

fileprivate struct QueuePrimary {
    let icon: String
    let label: String
    let run: () -> Void
}

fileprivate struct QueueRowActions {
    var remove: (_ offerSearch: Bool) -> Void
    var manualImport: () -> Void
    var search: () -> Void
    var interactive: () -> Void
    var blocklist: (_ search: Bool) -> Void
    var copy: () -> Void
}

// MARK: - Shared row bits

private struct QueueMetaLine: View {
    let item: QueueItem
    var showStatus = true

    var body: some View {
        ActFlow(spacing: 0, lineSpacing: 3) {
            part {
                HStack(spacing: 3) {
                    Image(systemName: "internaldrive").font(.system(size: 9))
                    Text(ActFmt.bytes(item.size))
                }
            }
            sep
                part { Text(item.downloadClient ?? "Unknown client") }
            if let indexer = item.indexer { sep
                part { Text(indexer) } }
            if let proto = item.protocolLabel { sep
                part { Text(proto) } }
            if let trigger = item.grabTrigger, ActProvenance.meta(trigger) != nil {
                sep
                ActProvenance(trigger: trigger)
            }
            if showStatus && item.stalled {
                sep
                part { Text("no status from client — will fail soon").fontWeight(.semibold).foregroundStyle(Theme.miss) }
            } else if showStatus, let warning = item.warning {
                sep
                part { Text(warning).foregroundStyle(Theme.grab) }
            }
            if item.ageSeconds != nil { sep
                part { Text(item.queuedAgo) } }
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.mut)
    }

    private var sep: some View { Text(" · ").font(.system(size: 11)).foregroundStyle(Theme.dim) }
    private func part<C: View>(@ViewBuilder _ c: () -> C) -> some View { c().lineLimit(1) }
}

private struct QueueHead: View {
    let item: QueueItem
    var chip: (String, Color)?

    var body: some View {
        ActFlow(spacing: 6, lineSpacing: 3) {
            Text(item.title).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1)
            if let ep = item.episodeLabel {
                Text(ep).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.mut).lineLimit(1)
            }
            ActTierChip(tier: item.tier)
            if let chip {
                Text(chip.0)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(chip.1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(chip.1.opacity(0.12), in: Capsule())
                    .overlay(Capsule().strokeBorder(chip.1.opacity(0.35)))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

private struct ReleaseLine: View {
    let text: String?
    var body: some View {
        if let text {
            Text(text)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Theme.dim)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

private struct QueueActionsView: View {
    let item: QueueItem
    let actions: QueueRowActions
    var primary: QueuePrimary?
    var stuck = false
    var trashLabel = "Remove from queue"
    var offerSearch = false

    var body: some View {
        HStack(spacing: -10) {
            if let primary {
                ActIconButton(systemImage: primary.icon, label: primary.label, tint: Theme.indigo, action: primary.run)
            }
            ActIconButton(systemImage: "trash", label: trashLabel) { actions.remove(offerSearch) }
            ActMoreMenu {
                Button("Interactive search", systemImage: "person", action: actions.interactive)
                if stuck {
                    Button("Blocklist & search", systemImage: "nosign") { actions.blocklist(true) }
                } else {
                    Button("Blocklist without removing", systemImage: "nosign") { actions.blocklist(false) }
                }
                Button("Copy release name", systemImage: "doc.on.doc", action: actions.copy)
            }
        }
        .padding(.horizontal, -6)
    }
}

/// The lg poster with a 24pt conic progress ring on its top-right corner.
private struct PosterRing: View {
    let item: QueueItem
    let pct: Int
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        ActPoster(url: item.posterUrl, title: item.title, size: .lg)
            .overlay(alignment: .topTrailing) {
                ZStack {
                    Circle().fill(Theme.bg)
                    Circle().stroke(Theme.txt.opacity(0.12), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: CGFloat(pct) / 100)
                        .stroke(Theme.grab, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(reduce ? nil : ActMotion.fill, value: pct)
                    Text("\(pct)").font(.system(size: 8, weight: .bold).monospacedDigit()).foregroundStyle(Theme.txt)
                }
                .frame(width: 24, height: 24)
                .offset(x: 8, y: -8)
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
    }
}

// MARK: - Cockpit row (solo download)

private struct QueueRowCard: View {
    let item: QueueItem
    let telemetry: QueueTelemetry?
    let soonest: Bool
    let actions: QueueRowActions
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        let state = item.cockpitState
        let pct = item.pct
        let fill: Color = state == .importing ? Theme.indigo : (state == .stalled ? Theme.miss : Theme.grab)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                PosterRing(item: item, pct: pct)
                VStack(alignment: .leading, spacing: 4) {
                    QueueHead(item: item, chip: state == .stalled ? ("Stalled", Theme.miss) : nil)
                    ReleaseLine(text: item.releaseTitle)
                    QueueMetaLine(item: item)
                    if let next = item.nextStep {
                        Text(next).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.mut)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            ActProgressBar(fraction: Double(pct) / 100, fill: state == .stalled ? AnyShapeStyle(Theme.miss)
                           : AnyShapeStyle(LinearGradient(colors: [Theme.grab.opacity(0.7), Theme.indigo, Theme.grab], startPoint: .leading, endPoint: .trailing)),
                           shimmer: state == .downloading)
            HStack(alignment: .lastTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(statBig(state))
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(state == .stalled ? Theme.miss : Theme.grab)
                        .contentTransition(.numericText())
                    Text("\(ActFmt.bytes(item.bytesDone)) / \(ActFmt.bytes(item.size)) · \(pct)%")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(Theme.mut)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(ActFmt.etaShort(telemetry?.eta))
                        .font(.system(size: 15, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.txt)
                    Text(etaKey(state).uppercased())
                        .font(.system(size: 9.5, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(Theme.dim)
                }
                Spacer(minLength: 0)
                QueueActionsView(item: item, actions: actions)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(alignment: .leading) {
            // `.cardfill`: the progress fill behind the content.
            GeometryReader { geo in
                LinearGradient(colors: [fill.opacity(0.05), fill.opacity(0.15)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: geo.size.width * CGFloat(pct) / 100)
                    .animation(reduce ? nil : ActMotion.fill, value: pct)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .actWash(QueueLogic.wash(item), border: soonest ? Theme.grab.opacity(0.45) : Theme.line)
        .shadow(color: soonest ? Theme.grab.opacity(0.18) : .clear, radius: 10)
        .accessibilityElement(children: .contain)
    }

    private func statBig(_ state: QueueCockpitState) -> String {
        switch state {
        case .stalled: return "Stalled"
        case .importing: return "Importing"
        default: return ActFmt.rate(telemetry?.bps ?? 0)
        }
    }

    private func etaKey(_ state: QueueCockpitState) -> String {
        if state == .importing { return "soon" }
        if (telemetry?.bps ?? 0) <= 0 { return "idle" }
        return "eta"
    }
}

// MARK: - Attention card (held / stuck)

private struct AttentionCard: View {
    let item: QueueItem
    let actions: QueueRowActions
    @State private var showWhy = false

    var body: some View {
        let held = item.cockpitState == .held
        HStack(alignment: .top, spacing: 12) {
            ActPoster(url: item.posterUrl, title: item.title, size: .sm)
            VStack(alignment: .leading, spacing: 5) {
                QueueHead(item: item, chip: held ? ("Manual import required", Theme.miss) : ("Needs attention", Theme.danger))
                ReleaseLine(text: item.releaseTitle)
                HStack(alignment: .top, spacing: 6) {
                    if held {
                        ActPulseDot(color: Theme.miss, size: 6, spread: 5, duration: 2).padding(.top, 4)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11)).foregroundStyle(Theme.danger)
                    }
                    Text(reason(held))
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(held ? Theme.miss : Theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                    if held, item.heldDetail != nil {
                        Button { showWhy.toggle() } label: {
                            Image(systemName: "info.circle").font(.system(size: 12)).foregroundStyle(Theme.mut)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Why it was held")
                    }
                }
                if showWhy, let detail = item.heldDetail { HeldWhy(detail: detail) }
                if held {
                    ActFlow(spacing: 0, lineSpacing: 3) {
                        Text("✓ On disk").foregroundStyle(Theme.done)
                        Text(" · \(ActFmt.bytes(item.size)) · 100%")
                        Text(" · " + [item.downloadClient ?? "Unknown client", item.indexer, item.protocolLabel].compactMap { $0 }.joined(separator: " · "))
                        if item.ageSeconds != nil { Text(" · \(item.queuedAgo)") }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.mut)
                } else {
                    QueueMetaLine(item: item, showStatus: false)
                }
                HStack {
                    Spacer(minLength: 0)
                    QueueActionsView(item: item, actions: actions,
                                     primary: held ? QueuePrimary(icon: "square.and.arrow.down", label: "Manual import", run: actions.manualImport)
                                                   : QueuePrimary(icon: "magnifyingglass", label: "Search", run: actions.search),
                                     stuck: !held, trashLabel: held ? "Reject" : "Remove from queue", offerSearch: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .actWash(QueueLogic.wash(item))
    }

    private func reason(_ held: Bool) -> String {
        if held { return item.heldReason ?? "Not an upgrade — manual import required" }
        return item.nextStep ?? "No eligible release left — needs attention"
    }
}

/// `HeldWhyDetail`: claimed vs probed quality, what's on disk, the verdict.
private struct HeldWhy: View {
    let detail: HeldDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let claimed = detail.claimedQuality ?? detail.probedQuality {
                if detail.mislabeled == true, let probed = detail.probedQuality {
                    let res = detail.probedResolution.map { " (\($0.w)×\($0.h))" } ?? ""
                    line("Release claimed:", "\(ActFmt.quality(claimed)) mislabeled — actually \(ActFmt.quality(probed))\(res)")
                } else {
                    line("Release claimed:", ActFmt.quality(claimed))
                }
            }
            if let current = detail.currentQuality {
                let extra = [detail.currentGroup, detail.currentCf.map { "CF \($0)" }].compactMap { $0 }.joined(separator: ", ")
                line("On disk:", ActFmt.quality(current) + (extra.isEmpty ? "" : " (\(extra))"))
            }
            if let verdict = detail.verdict {
                line("Verdict:", "not an upgrade (\(verdictText(verdict)))")
            }
        }
        .padding(8)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 8))
    }

    private func line(_ k: String, _ v: String) -> some View {
        (Text(k + " ").foregroundColor(Theme.dim) + Text(v).foregroundColor(Theme.txt))
            .font(.system(size: 11))
    }

    private func verdictText(_ v: String) -> String {
        switch v {
        case "quality_downgrade", "downgrade": return "quality downgrade"
        case "same_quality", "no_score_gain": return "same quality, no score gain"
        case "meets_cutoff", "cutoff_met": return "already meets cutoff"
        default: return v.replacingOccurrences(of: "_", with: " ")
        }
    }
}

// MARK: - Phase card (Working / Retrying)

private struct PhaseCard: View {
    let item: QueueItem
    let lane: QueueLane
    let actions: QueueRowActions

    var body: some View {
        let meta = item.phaseMeta
        HStack(alignment: .top, spacing: 12) {
            ActPoster(url: item.posterUrl, title: item.title, size: .sm)
            VStack(alignment: .leading, spacing: 6) {
                QueueHead(item: item)
                ReleaseLine(text: item.releaseTitle)
                PhaseReadout(item: item)
                HStack(spacing: 6) {
                    Image(systemName: "sparkle").font(.system(size: 10)).foregroundStyle(meta.tone)
                        .actSpin(meta.indeterminate && lane == .working, duration: 0.9)
                    Text(QueueLogic.noteLine(item)).font(.system(size: 11.5)).foregroundStyle(Theme.mut).lineLimit(2)
                }
                if item.phase == "linking", let frac = QueueLogic.stepFraction(item.step) {
                    let parts = frac.split(separator: "/").map { Double($0.trimmingCharacters(in: .whitespaces)) ?? 0 }
                    HStack(spacing: 8) {
                        ActProgressBar(fraction: parts.count == 2 && parts[1] > 0 ? parts[0] / parts[1] : 0, height: 4,
                                       fill: AnyShapeStyle(Theme.grab))
                        Text("\(frac) files").font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Theme.mut)
                    }
                } else {
                    HStack(spacing: 8) {
                        ActIndeterminateBar(color: meta.tone, height: 4)
                        Text("working · no ETA").font(.system(size: 10.5)).foregroundStyle(Theme.dim).fixedSize()
                    }
                }
                if lane == .retrying, let reason = item.terminalReason ?? item.warning {
                    Text("Failed at \(meta.statBig) — \(reason)")
                        .font(.system(size: 11.5)).foregroundStyle(Theme.danger)
                }
                HStack {
                    Text("\(ActFmt.bytes(item.size))").font(.system(size: 11)).foregroundStyle(Theme.mut)
                    Spacer(minLength: 0)
                    QueueActionsView(item: item, actions: actions,
                                     primary: lane == .retrying ? QueuePrimary(icon: "magnifyingglass", label: "Retry", run: actions.search) : nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .actWash(QueueLogic.wash(item))
    }
}

/// The mobile `PhaseReadout`: phase name in its tone, "step N of M", a climb rail.
private struct PhaseReadout: View {
    let item: QueueItem
    var ghost = false
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        let rail = QueueLogic.rail(for: item)
        let index = ghost ? -1 : QueueLogic.railIndex(for: item, rail: rail)
        let meta = item.phaseMeta
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                if ghost {
                    Text("Waiting").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.mut)
                } else {
                    Text(rail[max(index, 0)]).font(.system(size: 12, weight: .bold)).foregroundStyle(meta.tone)
                    Text("step \(index + 1) of \(rail.count)").font(.system(size: 11)).foregroundStyle(Theme.dim)
                }
            }
            HStack(spacing: 3) {
                ForEach(rail.indices, id: \.self) { i in
                    Capsule()
                        .fill(i < index ? meta.tone.opacity(0.85) : (i == index ? meta.tone : Theme.txt.opacity(0.09)))
                        .overlay { if i == index && !ghost { ActShimmer() } }
                        .clipShape(Capsule())
                        .frame(height: 4)
                }
            }
            .animation(reduce ? nil : ActMotion.fill, value: index)
        }
    }
}

// MARK: - Up next

private struct OnDeckCard: View {
    let item: QueueItem
    let actions: QueueRowActions

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("1").font(.system(size: 13, weight: .heavy, design: .monospaced)).foregroundStyle(Theme.dim).frame(width: 14)
            ActPoster(url: item.posterUrl, title: item.title, size: .sm)
            VStack(alignment: .leading, spacing: 5) {
                QueueHead(item: item, chip: item.phase != nil && item.phase != "queued"
                          ? (item.phaseMeta.label, item.phaseMeta.tone) : ("ON DECK", Theme.cyan))
                ReleaseLine(text: item.releaseTitle)
                PhaseReadout(item: item, ghost: true)
                HStack {
                    Text((["Waiting to start", ActFmt.bytes(item.size), item.downloadClient ?? "Unknown client"] + [item.indexer].compactMap { $0 })
                        .joined(separator: " · "))
                        .font(.system(size: 11)).foregroundStyle(Theme.mut).lineLimit(2)
                    Spacer(minLength: 0)
                    ActIconButton(systemImage: "trash", label: "Remove from queue") { actions.remove(false) }
                        .padding(.trailing, -8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .actWash(Theme.dim)
    }
}

private struct CompactUpNextRow: View {
    let item: QueueItem
    let position: Int
    let actions: QueueRowActions
    @State private var expanded = false
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("\(position)").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Theme.dim).frame(width: 18)
                ActPoster(url: item.posterUrl, title: item.title, size: .sm)
                VStack(alignment: .leading, spacing: 3) {
                    QueueHead(item: item, chip: ("QUEUED", Theme.mut))
                    Text([ActFmt.bytes(item.size), item.indexer].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 11)).foregroundStyle(Theme.mut)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    if reduce { expanded.toggle() } else { withAnimation(.easeOut(duration: 0.2)) { expanded.toggle() } }
                } label: {
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.dim)
                        .rotationEffect(.degrees(expanded ? 90 : 0)).frame(width: 30, height: 30).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(expanded ? "Collapse" : "Expand")
                ActIconButton(systemImage: "trash", label: "Remove from queue") { actions.remove(false) }
                    .padding(.horizontal, -8)
            }
            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    ReleaseLine(text: item.releaseTitle)
                    PhaseReadout(item: item, ghost: true)
                    Text((["Position \(position) in line", ActFmt.bytes(item.size), item.downloadClient ?? "Unknown client"] + [item.indexer].compactMap { $0 })
                        .joined(separator: " · "))
                        .font(.system(size: 11)).foregroundStyle(Theme.mut)
                }
                .padding(.leading, 28)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .actWash(Theme.dim)
    }
}

// MARK: - Just finished

private struct JustFinishedRow: View {
    let entry: QueueLogic.Finished
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        let item = entry.item
        let failed = entry.failed
        let epLabel = entry.count > 1 ? entry.season.map { String(format: "S%02d", $0) } : item.episodeLabel
        let root = item.step
        let note: String = failed
            ? (item.terminalReason ?? "Import failed")
            : entry.count > 1
                ? "\(entry.count) \(entry.season != nil ? "episodes" : "files") imported\(root.map { " into \($0)" } ?? "")"
                : "Imported\(root.map { " into \($0)" } ?? " into your library") · added to your library"
        HStack(alignment: .top, spacing: 12) {
            ActPoster(url: item.posterUrl, title: item.title, size: .sm)
            VStack(alignment: .leading, spacing: 5) {
                ActFlow(spacing: 6, lineSpacing: 3) {
                    Text(item.title).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1)
                    if let epLabel { Text(epLabel).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.mut) }
                    ActTierChip(tier: item.tier)
                    Text(failed ? "✕ FAILED" : "✓ \(entry.count > 1 ? "\(entry.count) " : "")IMPORTED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(failed ? Theme.danger : Theme.done)
                        .padding(.horizontal, 7).padding(.vertical, 1)
                        .background((failed ? Theme.danger : Theme.done).opacity(0.12), in: Capsule())
                }
                Text("via \(item.downloadClient ?? "decypharr")").font(.system(size: 11)).foregroundStyle(Theme.mut)
                Text(note).font(.system(size: 11.5)).foregroundStyle(failed ? Theme.danger : Theme.mut)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = max(0, QueueLogic.finishedWindow - context.date.timeIntervalSince(entry.finishedAt))
                    HStack(spacing: 8) {
                        Text(failed ? "Failed" : "Done").font(.system(size: 11, weight: .bold)).foregroundStyle(failed ? Theme.danger : Theme.done)
                        Text("clears in \(Int(left.rounded()))s").font(.system(size: 11).monospacedDigit()).foregroundStyle(Theme.dim)
                        // `queue-grace`: the draining bar.
                        GeometryReader { geo in
                            Capsule().fill((failed ? Theme.danger : Theme.done).opacity(0.5))
                                .frame(width: geo.size.width * CGFloat(left / QueueLogic.finishedWindow))
                                .animation(reduce ? nil : .linear(duration: 1), value: left)
                        }
                        .frame(height: 3)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if failed {
                ActIconButton(systemImage: "magnifyingglass", label: "Search again", tint: Theme.indigo) {
                    Task { await ActActions.search(model.client, toaster, itemId: item.mediaItemId, editionId: item.editionId,
                                                   message: "Searching again for \(item.title)") }
                }
            } else {
                ActIconButton(systemImage: "arrow.up.right.square", label: "Open in library") { model.open(item.mediaItemId) }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .actWash(failed ? Theme.danger : Theme.done)
        .contentShape(Rectangle())
        .onTapGesture { model.open(item.mediaItemId) }
    }
}

// MARK: - Group card (several downloads of one title)

private struct QueueGroupCard: View {
    let group: QueueLogic.Group
    let telemetry: [Int: QueueTelemetry]
    let eta: Double?
    let soonest: Bool
    let selecting: Bool
    @Binding var selected: Set<Int>
    let actionsFor: (QueueItem) -> QueueRowActions
    let removeMany: (_ ids: [Int], _ blocklist: Bool) -> Void
    let pick: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        let downloads = group.downloads
        let lead = downloads[0]
        let size = downloads.reduce(0) { $0 + $1.size }
        let done = downloads.reduce(0) { $0 + $1.bytesDone }
        let pct = size > 0 ? Int((done / size * 100).rounded()) : 0
        let rate = downloads.reduce(0) { $0 + (telemetry[$1.id]?.bps ?? 0) }
        let counts = (dl: downloads.filter { [.downloading, .awaiting, .importing].contains($0.cockpitState) }.count,
                      st: downloads.filter { $0.cockpitState == .stalled }.count,
                      q: downloads.filter { $0.cockpitState == .queued }.count)
        let seasons = Dictionary(grouping: downloads) { season($0) }
        let isSeries = downloads.contains { $0.episodeLabel != nil }
        ActGroupCard(wash: Theme.grab, base: Theme.panel) {
            ZStack(alignment: .bottomTrailing) {
                ActPoster(url: lead.posterUrl, title: lead.title, size: .md)
                    .rotationEffect(.degrees(-6)).offset(x: 6, y: -2).opacity(0.5)
                ActPoster(url: lead.posterUrl, title: lead.title, size: .md)
                Text("×\(downloads.count)").font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Theme.txt).padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Theme.bg.opacity(0.85), in: Capsule()).offset(x: 6, y: 4)
            }
            .frame(width: 48)
        } title: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(lead.title).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1)
                        .onTapGesture { model.open(group.mediaItemId) }
                    Text(isSeries ? "\(downloads.count) downloads" : "\(downloads.count) editions")
                        .font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Theme.mut)
                        .padding(.horizontal, 7).padding(.vertical, 1).background(Theme.panel2, in: Capsule())
                }
                Text([counts.dl > 0 ? "\(counts.dl) downloading" : nil, counts.st > 0 ? "\(counts.st) stalled" : nil,
                      counts.q > 0 ? "\(counts.q) queued" : nil].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                HStack(spacing: 8) {
                    ActProgressBar(fraction: Double(pct) / 100, shimmer: counts.dl > 0)
                    Text("\(pct)% overall").font(.system(size: 11, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.mut).fixedSize()
                }
            }
        } trailing: {
            HStack(spacing: 14) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(ActFmt.rate(rate)).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(Theme.grab)
                    Text("\(ActFmt.bytes(done)) / \(ActFmt.bytes(size))").font(.system(size: 10.5)).foregroundStyle(Theme.mut)
                }
                VStack(alignment: .trailing, spacing: 1) {
                    Text(ActFmt.etaShort(eta)).font(.system(size: 13, weight: .bold).monospacedDigit()).foregroundStyle(Theme.txt)
                    Text("NEXT DONE").font(.system(size: 9.5, weight: .bold)).foregroundStyle(Theme.dim)
                }
                Menu {
                    Button("Remove all (\(downloads.count))") { removeMany(downloads.map(\.id), false) }
                    if seasons.keys.compactMap({ $0 }).count >= 2 {
                        ForEach(seasons.keys.compactMap { $0 }.sorted(), id: \.self) { s in
                            Button("Remove Season \(s) (\(seasons[s]?.count ?? 0))") { removeMany((seasons[s] ?? []).map(\.id), false) }
                        }
                    }
                    Divider()
                    Button("Remove + blocklist all", role: .destructive) { removeMany(downloads.map(\.id), true) }
                    Divider()
                    Button("Pick downloads…", action: pick)
                } label: {
                    Image(systemName: "trash").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.mut)
                        .frame(width: 26, height: 26).frame(width: 36, height: 36).contentShape(Rectangle())
                }
                .accessibilityLabel("Remove downloads for \(lead.title)")
            }
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                let keys = isSeries ? seasons.keys.sorted { ($0 ?? 0) < ($1 ?? 0) } : [nil]
                ForEach(keys, id: \.self) { key in
                    if isSeries, let key {
                        Text("SEASON \(key)").font(.system(size: 9.5, weight: .heavy)).tracking(0.6).foregroundStyle(Theme.dim)
                            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 2)
                    }
                    ForEach(isSeries ? (seasons[key] ?? []) : downloads) { item in
                        nestedRow(item)
                    }
                }
            }
            .padding(.bottom, 6)
        }
        .overlay {
            if soonest { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.grab.opacity(0.45)) }
        }
    }

    private func season(_ item: QueueItem) -> Int? {
        guard let label = item.episodeLabel, let r = label.range(of: #"S(\d{1,3})"#, options: .regularExpression) else { return nil }
        return Int(label[r].dropFirst())
    }

    @ViewBuilder
    private func nestedRow(_ item: QueueItem) -> some View {
        let state = item.cockpitState
        let stripe: Color = state == .stalled ? Theme.miss : (state == .queued ? Theme.dim : (state == .held ? Theme.stuck : Theme.grab))
        HStack(spacing: 10) {
            if selecting { ActCheckbox(checked: selected.contains(item.id)) }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.episodeLabel ?? item.tier.chipLabel).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                    if item.episodeLabel != nil { ActTierChip(tier: item.tier) }
                    Spacer(minLength: 0)
                    Text(state == .queued ? "queued" : (state == .stalled ? "stalled" : ActFmt.rate(telemetry[item.id]?.bps ?? 0)))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(state == .stalled ? Theme.miss : Theme.mut)
                    Text("\(item.pct)%").font(.system(size: 11, weight: .bold).monospacedDigit()).foregroundStyle(Theme.txt).frame(width: 36, alignment: .trailing)
                }
                ActProgressBar(fraction: Double(item.pct) / 100, height: 4, shimmer: state == .downloading)
            }
            if !selecting {
                let actions = actionsFor(item)
                ActIconButton(systemImage: "trash", label: "Remove from queue") { actions.remove(false) }
                    .padding(.horizontal, -8)
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
        .overlay(alignment: .leading) {
            Capsule().fill(stripe).frame(width: 3).padding(.vertical, 8).offset(x: 5)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if selecting {
                if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) }
            } else {
                model.open(item.mediaItemId)
            }
        }
    }
}

// MARK: - Heroes

private struct BandwidthPulseHero: View {
    let items: [QueueItem]
    let history: [Double]

    var body: some View {
        let current = history.last ?? 0
        let downloading = items.filter { [.downloading, .awaiting, .importing].contains($0.cockpitState) }.count
        let stalled = items.filter { $0.cockpitState == .stalled }.count
        let queued = items.filter { $0.cockpitState == .queued }.count
        let remaining = items.filter { [.downloading, .stalled, .awaiting].contains($0.cockpitState) && $0.size > 0 }
            .reduce(0) { $0 + max(0, $1.sizeleft) }
        let clears = remaining <= 0 ? "now" : (current > 0 ? "~\(ActFmt.etaApprox(remaining / current))" : "—")
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(ActFmt.mbps(current))
                    .font(.system(size: 38, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Theme.grab)
                    .contentTransition(.numericText(value: current))
                Text("MB/s").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.mut)
            }
            ActFlow(spacing: 12, lineSpacing: 4) {
                if downloading > 0 || stalled > 0 {
                    HStack(spacing: 5) {
                        ActPulseDot(color: Theme.grab, size: 6, spread: 5)
                        Text("LIVE").font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.grab)
                    }
                }
                stat(downloading, "downloading")
                if stalled > 0 { stat(stalled, "stalled") }
                stat(queued, "queued")
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("QUEUE CLEARS IN").font(.system(size: 10, weight: .bold)).tracking(0.8).foregroundStyle(Theme.dim)
                Text(clears).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.txt)
            }
            Chart {
                ForEach(Array(history.enumerated()), id: \.offset) { index, bps in
                    AreaMark(x: .value("t", index), y: .value("bps", bps))
                        .foregroundStyle(LinearGradient(colors: [Theme.grab.opacity(0.4), Theme.grab.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("t", index), y: .value("bps", bps))
                        .foregroundStyle(Theme.grab)
                        .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.monotone)
                }
                if let last = history.indices.last {
                    PointMark(x: .value("t", last), y: .value("bps", history[last]))
                        .foregroundStyle(Theme.grab).symbolSize(30)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartXScale(domain: 0...max(history.count - 1, 1))
            .frame(height: 90)
            .padding(.horizontal, -14)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .background(
            LinearGradient(colors: [Theme.grab.opacity(0.05), Theme.panel], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
    }

    private func stat(_ n: Int, _ label: String) -> some View {
        (Text("\(n)").bold().foregroundColor(Theme.txt) + Text(" \(label)"))
            .font(.system(size: 12))
            .foregroundStyle(Theme.mut)
    }
}

private struct PipelineHero: View {
    let items: [QueueItem]
    let aggregateBps: Double
    let hasPhaseWork: Bool
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        let dist = QueueLogic.stageDistribution(items)
        let wf = QueueLogic.workingFailed(items)
        let real = items.filter(\.isByteTransferring).count
        let activeIdx = dist.indices.filter { dist[$0] > 0 }.max() ?? -1
        let current = activeIdx >= 0 ? QueueLogic.heroStages[activeIdx] : nil
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pipeline").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt)
                    (Text("\(ActFmt.plural(wf.working, "job"))\(current.map { " · \($0.lowercased())" } ?? "")")
                     + Text(real > 0 ? " · \(real) downloading · \(ActFmt.mbps(aggregateBps)) MB/s" : "").foregroundColor(Theme.grab)
                     + Text(wf.failed > 0 ? " · \(wf.failed) failed · will retry" : "").foregroundColor(Theme.miss))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.mut)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    (Text("Step \(activeIdx + 1)").foregroundColor(Theme.txt) + Text("/\(QueueLogic.heroStages.count)").foregroundColor(Theme.dim))
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                    Text(current?.lowercased() ?? "idle").font(.system(size: 11)).foregroundStyle(Theme.mut)
                }
            }
            HStack(spacing: 4) {
                ForEach(QueueLogic.heroStages.indices, id: \.self) { i in
                    let state = dist[i] > 0 ? 2 : (i < activeIdx ? 1 : 0)
                    Capsule()
                        .fill(state == 2 ? Theme.grab : (state == 1 ? Theme.indigo.opacity(0.7) : Theme.txt.opacity(0.08)))
                        .overlay { if state == 2 { ActShimmer() } }
                        .clipShape(Capsule())
                        .frame(height: 5)
                }
            }
            .animation(reduce ? nil : ActMotion.fill, value: dist)
            ActFlow(spacing: 12, lineSpacing: 6) {
                ForEach(QueueLogic.heroStages.indices, id: \.self) { i in
                    let active = dist[i] > 0
                    let state = active ? 2 : (i < activeIdx ? 1 : 0)
                    Group {
                        HStack(spacing: 5) {
                            if active {
                                ActPulseDot(color: Theme.grab, size: 6, spread: 4)
                            } else {
                                Circle().fill(state == 1 ? Theme.indigo : Theme.txt.opacity(0.15)).frame(width: 6, height: 6)
                            }
                            if active {
                                Text(QueueLogic.heroStages[i]).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.txt)
                                Text("\(dist[i])").font(.system(size: 10, weight: .bold).monospacedDigit()).foregroundStyle(Theme.bg)
                                    .padding(.horizontal, 5).background(Theme.grab, in: Capsule())
                            }
                        }
                    }
                }
            }
            Text(hasPhaseWork ? "symlink jobs finish in seconds — no time ETA" : "waiting for a free download slot")
                .font(.system(size: 11)).italic().foregroundStyle(Theme.dim)
        }
        .padding(14)
        .background(
            LinearGradient(colors: [Theme.indigo.opacity(0.06), Theme.panel], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
    }
}

// MARK: - Dialogs (components/activity)

private struct RemoveQueueDialog: View {
    let item: QueueItem
    let offerSearch: Bool
    let onConfirm: (_ deleteData: Bool, _ blocklist: Bool, _ search: Bool) -> Void
    let onCancel: () -> Void
    @State private var deleteFile = true
    @State private var blocklist = false
    @State private var search = false

    var body: some View {
        let hasFile = item.hasDownloadedFile == true
        let parts = [hasFile && deleteFile ? "delete file" : nil, blocklist ? "blocklist" : nil,
                     (offerSearch || blocklist) && search ? "search" : nil].compactMap { $0 }
        ActDialog(title: "Remove from queue?",
                  message: "\(item.title) will be removed from the download queue.",
                  confirmLabel: parts.isEmpty ? "Remove" : "Remove and " + parts.joined(separator: " and "),
                  onCancel: onCancel,
                  onConfirm: { onConfirm(hasFile && deleteFile, blocklist, (offerSearch || blocklist) && search) }) {
            if hasFile {
                ActOption(label: "Also delete the downloaded file from disk", isOn: $deleteFile)
            }
            ActOption(label: "Also blocklist this release", hint: "Off by default — it permanently disqualifies the release.",
                      isOn: $blocklist)
                .onChange(of: blocklist) { if blocklist { search = true } }
            if offerSearch || blocklist {
                ActOption(label: "Also search for a replacement", hint: "Kicks a fresh search once this download is gone.", isOn: $search)
            }
        }
    }
}

private struct BulkRemoveDialog: View {
    let count: Int
    let fileCount: Int
    let defaultBlocklist: Bool
    let busy: Bool
    let onConfirm: (_ deleteFiles: Bool, _ blocklist: Bool) -> Void
    let onCancel: () -> Void
    @State private var deleteFiles = false
    @State private var blocklist = false

    var body: some View {
        let parts = [deleteFiles && fileCount > 0 ? "delete files" : nil, blocklist ? "blocklist" : nil].compactMap { $0 }
        ActDialog(title: "Remove \(ActFmt.plural(count, "download")) from queue?",
                  message: "The selected download\(count == 1 ? "" : "s") will be removed from the download queue.",
                  confirmLabel: parts.isEmpty ? "Remove \(count)" : "Remove and " + parts.joined(separator: " and "),
                  busy: busy, onCancel: onCancel,
                  onConfirm: { onConfirm(deleteFiles && fileCount > 0, blocklist) }) {
            if fileCount > 0 {
                ActOption(label: "Also delete the downloaded file\(count == 1 ? "" : "s") from disk (\(fileCount) of \(count) on disk)",
                          isOn: $deleteFiles)
            }
            ActOption(label: "Also blocklist these releases", hint: "Off by default — it permanently disqualifies the releases.",
                      isOn: $blocklist)
        }
        .onAppear { blocklist = defaultBlocklist; deleteFiles = fileCount > 0 }
    }
}
