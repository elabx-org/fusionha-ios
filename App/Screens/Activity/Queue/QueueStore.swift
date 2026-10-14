import SwiftUI
import FusionhaKit

// MARK: - Store (feed + live telemetry)

/// Each job's furthest live phase, so an errored job holds at the stage it
/// reached (QueueRules.state). Updated on every poll.
@MainActor
enum QueuePhaseMemory {
    static var last: [Int: String] = [:]
}

@MainActor
@Observable
final class QueueStore {
    private(set) var items: [QueueItem] = []
    private(set) var total = 0
    private(set) var justFinished: [QueueItem] = []
    /// The idle pipeline line (0.4.189; page 1 only, so later pages keep it).
    private(set) var lastImport: QueuePipeline.LastImport?
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
        if let pipeline = page.pipeline, lastImport != pipeline.lastImport { lastImport = pipeline.lastImport }
        QueuePhaseMemory.last = QueueRules.remember(QueuePhaseMemory.last, items: page.items.map { (id: $0.id, phase: $0.phase) })
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
