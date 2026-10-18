import SwiftUI
import FusionhaKit

/// Settings → Indexers (`IndexersPanel.tsx`): the range-driven fleet overview,
/// then every indexer as a performance card (enable switch, Test, edit, delete,
/// capability chips, share / yield / success / activity) with sort + protocol
/// filters, Test all, the rich add/edit sheet with the validate-on-save gate,
/// and the Cloudflare solver (FlareSolverr) for Letterboxd.
struct IndexersPanel: View {
    @Environment(AppModel.self) private var model
    @State private var indexers: [SearchIndexerInfo] = []
    @State private var stats: IndexerStatsResponse?
    @State private var range: IndexerRange = .week
    @State private var loaded = false
    @State private var error: String?
    @State private var results: [Int: ConnectionTestResult] = [:]
    @State private var testing: Set<Int> = []
    @State private var testingAll = false
    @State private var sort: SortKey = .share
    @State private var protocolFilter = "ALL"
    @State private var editing: SearchIndexerInfo?
    @State private var adding = false
    @State private var toaster = FetchToaster()
    @State private var confirm: FetchConfirm?

    enum SortKey: String, CaseIterable, Identifiable {
        case share = "Share", byYield = "Yield", grabs = "Grabs", success = "Success", name = "Name"
        var id: String { rawValue }
    }

    private var metrics: [IndexerMetric] { IndexerMetric.build(indexers, stats: stats) }

    private var rows: [IndexerMetric] {
        let filtered = protocolFilter == "ALL" ? metrics : metrics.filter { $0.indexer.protocol == protocolFilter }
        return filtered.sorted { a, b in
            switch sort {
            case .byYield: return a.yieldValue > b.yieldValue
            case .grabs: return a.grabsRange > b.grabsRange
            case .success: return (a.successPct ?? -1) > (b.successPct ?? -1)
            case .name: return a.indexer.name.localizedCompare(b.indexer.name) == .orderedAscending
            case .share: return a.share > b.share
            }
        }
    }

    var body: some View {
        let all = metrics
        let maxShare = max(1, all.map(\.share).max() ?? 1)
        let maxYield = max(1, all.map(\.yieldValue).max() ?? 1)
        FetchingPage(slug: "indexers", toaster: toaster, confirm: $confirm, refresh: load) {
            IndexerFleetOverview(summary: stats?.summary, metrics: all, range: $range)
                .padding(.bottom, 22)

            toolbar.padding(.bottom, 12)

            if !loaded || error != nil { FetchLoading(error: error) }
            if loaded, indexers.isEmpty, error == nil {
                FetchEmpty(text: "No indexers yet — add a Newznab or Torznab indexer, or let Prowlarr sync them in.")
            }
            VStack(spacing: 12) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, metric in
                    IndexerCard(metric: metric, index: index, maxShare: maxShare, maxYield: maxYield,
                                result: results[metric.id], testing: testing.contains(metric.id),
                                onToggle: { toggle(metric.indexer, $0) },
                                onTest: { runTest(metric.indexer) },
                                onEdit: { editing = metric.indexer },
                                onDelete: { askDelete(metric.indexer) })
                        .fetchReveal(index)
                }
            }
            FlareSolverrCard().padding(.top, 22)
        }
        .task { await load() }
        .task(id: range) { await loadStats() }
        .sheet(isPresented: $adding) {
            IndexerSheet(indexer: nil) { await load() }
        }
        .sheet(item: $editing) { indexer in
            IndexerSheet(indexer: indexer) { await load() }
        }
    }

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("All indexers").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
                Spacer()
                Button(testingAll ? "Testing…" : "Test all") { runTestAll() }
                    .buttonStyle(.web(.ghost))
                    .disabled(indexers.isEmpty || testingAll)
                Button("+ Add indexer") { adding = true }.buttonStyle(.web())
            }
            HStack(spacing: 8) {
                Picker("Protocol", selection: $protocolFilter) {
                    Text("All").tag("ALL")
                    Text("Usenet").tag("USENET")
                    Text("Torrent").tag("TORRENT")
                }
                .pickerStyle(.segmented)
                Menu {
                    Picker("Sort by", selection: $sort) {
                        ForEach(SortKey.allCases) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    Label(sort.rawValue, systemImage: "arrow.up.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .glassEffect(.regular.interactive(), in: Capsule())
                }
                .tint(Theme.txt)
                .accessibilityLabel("Sort by \(sort.rawValue)")
            }
        }
    }

    // MARK: Actions

    private func load() async {
        guard let client = model.client else { return }
        do {
            indexers = try await client.configList(.searchIndexers)
            error = nil
        } catch {
            self.error = error.settingsMessage
        }
        loaded = true
        await loadStats()
    }

    private func loadStats() async {
        guard let client = model.client else { return }
        stats = try? await client.indexerStats(range: range.rawValue)
    }

    private func toggle(_ indexer: SearchIndexerInfo, _ on: Bool) {
        guard let client = model.client else { return }
        Task {
            do {
                try await client.configUpdate(.searchIndexers, id: indexer.id,
                                              ["enabled_search": .bool(on), "enabled_rss": .bool(on)])
                await load()
            } catch {
                toaster.error(error, title: "Could not update \(indexer.displayName)")
            }
        }
    }

    private func runTest(_ indexer: SearchIndexerInfo) {
        guard let client = model.client else { return }
        testing.insert(indexer.id)
        Task {
            do {
                let r = try await client.configTest(.searchIndexers, id: indexer.id)
                results[indexer.id] = r
                if r.ok { await loadStats() }
            } catch {
                results[indexer.id] = ConnectionTestResult(ok: false, message: error.settingsMessage)
            }
            testing.remove(indexer.id)
        }
    }

    /// arr's "Test All Indexers": every enabled indexer at once, one roll-up toast.
    private func runTestAll() {
        guard let client = model.client else { return }
        testingAll = true
        Task {
            do {
                let res = try await client.testAllIndexers()
                for r in res.results { results[r.id] = ConnectionTestResult(ok: r.ok, message: r.message) }
                if res.results.contains(where: \.ok) { await loadStats() }
                let passed = res.results.filter(\.ok).count
                toaster.show("\(passed) of \(res.results.count) passed", title: "Indexers tested",
                             tone: passed == res.results.count ? .success : .warning)
            } catch {
                toaster.show(error.settingsMessage, tone: .error)
            }
            testingAll = false
        }
    }

    private func askDelete(_ indexer: SearchIndexerInfo) {
        confirm = FetchConfirm(title: "Delete \(indexer.displayName)?",
                               message: indexer.source == "prowlarr"
                                ? "Prowlarr may sync it back on its next run."
                                : "fusionha stops searching this indexer.") {
            Task {
                guard let client = model.client else { return }
                do {
                    try await client.configDelete(.searchIndexers, id: indexer.id)
                    await load()
                } catch { toaster.error(error, title: "Could not delete the indexer") }
            }
        }
    }
}
