import Foundation
import FusionhaKit

/// Builds the redesigned Live Activity's state from the polled queue (the
/// approved mock): what is moving and how fast, what waits on you grouped
/// like the queue, a stalled or failed download first, and one symlink job's
/// steps. Only the downloads chosen in Account › Live Activity count.
@MainActor
enum LiveActivityStateBuilder {
    typealias State = DownloadsActivityAttributes.ContentState

    /// Bytes done per download at the last poll, for speed and time left.
    private static var samples: [Int: (done: Double, at: Date)] = [:]
    private static var rates: [Int: Double] = [:]

    /// nil when nothing counted is in the queue.
    static func build(_ counted: [QueueItem], now: Date = .now) -> State? {
        guard !counted.isEmpty else { return nil }
        measure(counted, now: now)
        let waiting = counted.filter { $0.cockpitState == .held || $0.cockpitState == .stuck }
        let moving = counted.filter { $0.cockpitState != .held && $0.cockpitState != .stuck }
        let bps = moving.reduce(0) { $0 + (rates[$1.id] ?? 0) }
        let etas = moving.compactMap { item -> Int? in
            guard let rate = rates[item.id], rate > 0, item.sizeleft > 0 else { return nil }
            return Int(item.sizeleft / rate)
        }
        var state = State(mode: .downloading, downloading: moving.count, needYou: waiting.count,
                          bps: moving.contains { !$0.isPhaseMode } ? bps : nil, etaSeconds: etas.min(),
                          rows: rows(moving), held: held(waiting), steps: nil, event: nil,
                          updatedAt: now.timeIntervalSince1970)
        if let problem = moving.first(where: \.stalled) ?? counted.first(where: { $0.cockpitState == .stuck }) {
            state.mode = .problem
            state.event = problemEvent(problem)
        } else if moving.isEmpty {
            state.mode = .held
        } else if moving.count == 1, moving[0].isPhaseMode, let stages = moving[0].stages {
            let nodes = QueueRail.phaseNodes(stages).filter { $0.state != .off }
            if !nodes.isEmpty {
                state.mode = .steps
                state.steps = State.Steps(labels: nodes.map(\.label), done: nodes.filter { $0.state == .done }.count,
                                          current: nodes.first { $0.state == .active }?.label)
            }
        }
        return state
    }

    /// The moment after the last download leaves: what landed.
    static func finished(_ last: QueueItem?, now: Date = .now) -> State {
        samples = [:]
        rates = [:]
        let upgraded = last?.grabTrigger?.lowercased() == "upgrade"
        let event = last.map {
            State.Event(mediaItemId: $0.mediaItemId, downloadId: nil, title: $0.title, version: QueueCardText.versionLabel($0),
                        detail: [$0.parsed?.quality.map(DetailText.quality), $0.size > 0 ? ActFmt.bytes($0.size) : nil]
                            .compactMap { $0 }.joined(separator: " · "),
                        line2: $0.episodeLabel)
        }
        return State(mode: last == nil ? .done : (upgraded ? .upgraded : .imported), downloading: 0, needYou: 0,
                     bps: nil, etaSeconds: nil, rows: [], held: [], steps: nil, event: event,
                     updatedAt: now.timeIntervalSince1970)
    }

    private static func measure(_ items: [QueueItem], now: Date) {
        var nextSamples: [Int: (done: Double, at: Date)] = [:]
        for item in items {
            let done = item.bytesDone
            if let prev = samples[item.id] {
                let dt = now.timeIntervalSince(prev.at)
                if dt >= 0.5 {
                    let rate = max(0, (done - prev.done) / dt)
                    rates[item.id] = rates[item.id].map { $0 * 0.5 + rate * 0.5 } ?? rate
                    nextSamples[item.id] = (done, now)
                } else {
                    nextSamples[item.id] = prev
                }
            } else {
                nextSamples[item.id] = (done, now)
            }
        }
        samples = nextSamples
        rates = rates.filter { nextSamples[$0.key] != nil }
    }

    /// The two nearest to done.
    private static func rows(_ moving: [QueueItem]) -> [State.Row] {
        moving
            .sorted { ($0.isPhaseMode ? -1 : Double($0.pct)) > ($1.isPhaseMode ? -1 : Double($1.pct)) }
            .prefix(2)
            .map { item in
                State.Row(downloadId: item.id, mediaItemId: item.mediaItemId, title: item.title,
                          sub: QueueCardText.subtitle(item), version: QueueCardText.versionLabel(item),
                          fraction: item.isPhaseMode ? nil : Double(item.pct) / 100,
                          posterUrl: TMDBImage.resized(item.posterUrl, to: "w154"))
            }
    }

    /// Held downloads grouped like the queue: one line per title (three, for
    /// the poster fan; the Lock Screen writes out two).
    private static func held(_ waiting: [QueueItem]) -> [State.Held] {
        var order: [Int] = []
        var byTitle: [Int: [QueueItem]] = [:]
        for item in waiting where item.cockpitState == .held {
            if byTitle[item.mediaItemId] == nil { order.append(item.mediaItemId) }
            byTitle[item.mediaItemId, default: []].append(item)
        }
        return order.prefix(3).compactMap { id in
            guard let items = byTitle[id], let first = items.first else { return nil }
            return State.Held(mediaItemId: id, title: first.title, count: items.count,
                              reason: QueueCardText.heldTag(first), downloadIds: items.map(\.id),
                              version: QueueCardText.versionLabel(first),
                              posterUrl: TMDBImage.resized(first.posterUrl, to: "w154"))
        }
    }

    private static func problemEvent(_ item: QueueItem) -> State.Event {
        let detail = item.stalled ? "Stalled at \(item.pct)%" : "No release left to try"
        return State.Event(mediaItemId: item.mediaItemId, downloadId: item.id, title: item.title,
                           version: [item.episodeLabel, QueueCardText.versionLabel(item)].compactMap { $0 }.joined(separator: " · "),
                           detail: detail, line2: item.nextStep ?? item.warning)
    }
}
