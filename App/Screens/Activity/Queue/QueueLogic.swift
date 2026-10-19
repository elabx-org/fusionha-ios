import SwiftUI
import FusionhaKit

// MARK: - Logic (pure, mirrors the web helpers)

enum QueueCockpitState { case held, stuck, stalled, importing, awaiting, queued, downloading }
enum QueueLane { case working, retrying, byte }

struct QueueTelemetry: Equatable {
    var bps: Double
    var eta: Double?
}

struct PhaseMeta {
    let label: String
    let tone: Color
    let indeterminate: Bool
    let note: String
    let statBig: String
    let statSub: String
}

extension QueueItem {
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

    /// The server's plan decides (0.4.189); older servers fall back to the phase.
    var isPhaseMode: Bool {
        if let stages { return stages.isPhaseMode }
        return phase != nil && phase != "downloading"
    }

    /// `Linking (n/total)`: the server's parsed count, else the step text.
    var linkingCount: QueueRules.Linking? {
        guard phase == "linking" else { return nil }
        return stages?.linking ?? QueueRules.linking(step: step)
    }

    /// Where the job stands on its rail: the server's plan when it sends one,
    /// else the client rules with this device's memory of the last phase.
    @MainActor
    var stageState: QueueRules.StageState {
        if let stages, !(stages.steps ?? []).isEmpty { return QueueRules.state(stages: stages) }
        return QueueRules.state(protocol: self.protocol, phase: phase, phaseTerminal: phaseTerminal,
                                lastSeenPhase: lastPhase ?? QueuePhaseMemory.last[id])
    }

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

enum QueueLogic {
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

    static func noteLine(_ item: QueueItem) -> String {
        let meta = item.phaseMeta
        if item.phase == "error" { return item.nextStep ?? item.warning ?? item.step ?? meta.note }
        if let linking = item.linkingCount {
            return "Linking files into the library (\(linking.label))…"
        }
        return meta.note
    }

    /// Several downloads on one card (fusionha 0.4.194, `queue-groups.ts`):
    /// a pair is one title + episode in two or more versions (4K + HD), a lane
    /// each; a group is separate downloads of one title + version, collapsed by
    /// default. `section` keys the remembered open state.
    struct Group: Identifiable {
        let mediaItemId: Int
        let isPair: Bool
        let section: String
        var downloads: [QueueItem]
        var id: String {
            isPair ? "pair:\(QueueLogic.pairKey(downloads[0]))"
                : "group:\(section):\(mediaItemId):\(downloads[0].editionId)"
        }
    }

    /// Same title, same episode (a movie's is nil) and the same season or pack.
    static func pairKey(_ i: QueueItem) -> String {
        [String(i.mediaItemId), i.episodeId.map(String.init) ?? "m", i.episodeLabel ?? "",
         i.parsed?.season.map(String.init) ?? ""].joined(separator: ":")
    }

    /// `foldVersionPairs` then `foldDownloadGroups`; a lone download stays solo.
    static func group(_ items: [QueueItem], section: String = "downloading", pairs: Bool = true) -> [Group] {
        var out: [Group] = []
        // Pairs: one title + episode in distinct versions.
        let pairBuckets = Dictionary(grouping: items, by: pairKey)
        var emitted = Set<String>()
        var solos: [QueueItem] = []
        var slots: [Either] = []
        for item in items {
            let key = pairKey(item)
            let list = pairBuckets[key] ?? [item]
            if pairs, list.count > 1, Set(list.map(\.editionId)).count == list.count {
                if emitted.insert(key).inserted {
                    slots.append(.pair(Group(mediaItemId: item.mediaItemId, isPair: true, section: section, downloads: list)))
                }
            } else {
                solos.append(item)
                slots.append(.solo(item))
            }
        }
        // Groups: the remaining downloads of one title + version.
        let versionKey = { (i: QueueItem) in "\(i.mediaItemId):\(i.editionId)" }
        let groupBuckets = Dictionary(grouping: solos, by: versionKey)
        var emittedGroups = Set<String>()
        for slot in slots {
            switch slot {
            case .pair(let pair): out.append(pair)
            case .solo(let item):
                let key = versionKey(item)
                let list = groupBuckets[key] ?? [item]
                if emittedGroups.insert(key).inserted {
                    out.append(Group(mediaItemId: item.mediaItemId, isPair: false, section: section, downloads: list))
                }
            }
        }
        return out
    }

    private enum Either { case solo(QueueItem), pair(Group) }

    enum Entry: Identifiable {
        case solo(QueueItem, eta: Double?)
        case group(Group, eta: Double?)
        var id: String {
            switch self {
            case .solo(let item, _): return "solo:\(item.id)"
            case .group(let g, _): return "group:\(g.id)"
            }
        }
        var eta: Double? {
            switch self {
            case .solo(_, let eta), .group(_, let eta): return eta
            }
        }
        /// Downloads, not cards: a group or a 4K + HD pair holds several (0.4.196).
        var downloadCount: Int {
            switch self {
            case .solo: return 1
            case .group(let g, _): return g.downloads.count
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
}
