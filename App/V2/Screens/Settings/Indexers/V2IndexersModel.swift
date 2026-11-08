import SwiftUI
import FusionhaKit

/// The S1 Indexers page's state, shared by the list and each indexer's
/// detail so a test or a switch shows in both. The calls are v1's
/// `IndexersPanel` (list, stats per range, enable, test, Test all, delete).
@MainActor
@Observable
final class V2IndexersModel {
    private(set) var indexers: [SearchIndexerInfo] = []
    private(set) var stats: IndexerStatsResponse?
    /// The first stats answer (or failure) is in: the fleet card waits for it.
    private(set) var statsLoaded = false
    private(set) var loaded = false
    private(set) var error: String?
    private(set) var results: [Int: ConnectionTestResult] = [:]
    private(set) var testing: Set<Int> = []
    private(set) var testingAll = false
    var range: IndexerRange = .week
    let toaster = FetchToaster()
    var confirm: FetchConfirm?

    var metrics: [IndexerMetric] { IndexerMetric.build(indexers, stats: stats) }

    func metric(_ id: Int) -> IndexerMetric? { metrics.first { $0.id == id } }

    // MARK: Loading

    func load(_ client: APIClient?) async {
        guard let client else { return }
        do {
            indexers = try await client.configList(.searchIndexers)
            error = nil
        } catch {
            self.error = error.settingsMessage
        }
        loaded = true
        await loadStats(client)
    }

    func loadStats(_ client: APIClient?) async {
        guard let client else { return }
        stats = try? await client.indexerStats(range: range.rawValue)
        statsLoaded = true
    }

    // MARK: Actions

    /// The row's switch: search and RSS together, as v1.
    func toggle(_ indexer: SearchIndexerInfo, _ on: Bool, client: APIClient?) {
        update(indexer, ["enabled_search": .bool(on), "enabled_rss": .bool(on)], client: client)
    }

    /// One flag on the detail page (`enabled_rss` or `enabled_search`).
    func setFlag(_ indexer: SearchIndexerInfo, _ key: String, _ on: Bool, client: APIClient?) {
        update(indexer, [key: .bool(on)], client: client)
    }

    private func update(_ indexer: SearchIndexerInfo, _ body: SettingsJSON, client: APIClient?) {
        guard let client else { return }
        Task {
            do {
                try await client.configUpdate(.searchIndexers, id: indexer.id, body)
                await load(client)
            } catch {
                toaster.error(error, title: "Could not update \(indexer.displayName)")
            }
        }
    }

    func test(_ indexer: SearchIndexerInfo, client: APIClient?) {
        guard let client else { return }
        testing.insert(indexer.id)
        Task {
            do {
                let r = try await client.configTest(.searchIndexers, id: indexer.id)
                results[indexer.id] = r
                if r.ok { await loadStats(client) }
            } catch {
                results[indexer.id] = ConnectionTestResult(ok: false, message: error.settingsMessage)
            }
            testing.remove(indexer.id)
        }
    }

    /// arr's "Test All Indexers": every enabled indexer at once, one roll-up toast.
    func testAll(client: APIClient?) {
        guard let client else { return }
        testingAll = true
        Task {
            do {
                let res = try await client.testAllIndexers()
                for r in res.results { results[r.id] = ConnectionTestResult(ok: r.ok, message: r.message) }
                if res.results.contains(where: \.ok) { await loadStats(client) }
                let passed = res.results.filter(\.ok).count
                toaster.show("\(passed) of \(res.results.count) passed", title: "Indexers tested",
                             tone: passed == res.results.count ? .success : .warning)
            } catch {
                toaster.show(error.settingsMessage, tone: .error)
            }
            testingAll = false
        }
    }

    /// The delete confirm for `indexer` (v1's wording); `then` runs after
    /// the delete, before the reload.
    func deleteConfirm(_ indexer: SearchIndexerInfo, client: APIClient?,
                       then: @escaping () -> Void = {}) -> FetchConfirm {
        FetchConfirm(title: "Delete \(indexer.displayName)?",
                     message: indexer.source == "prowlarr"
                        ? "Prowlarr may sync it back on its next run."
                        : "fusionha stops searching this indexer.") { [weak self] in
            Task {
                guard let self, let client else { return }
                do {
                    try await client.configDelete(.searchIndexers, id: indexer.id)
                    then()
                    await self.load(client)
                } catch { self.toaster.error(error, title: "Could not delete the indexer") }
            }
        }
    }
}
