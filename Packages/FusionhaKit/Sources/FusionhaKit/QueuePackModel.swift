import Foundation

/// A season pack / anime batch on a queue card (the web's `pack-model.ts`):
/// one "Linking n of N" line, a thin bar and a range summary, the same at 13,
/// 52 or 112+ files. A held pack with stored decisions swaps the linking
/// summary and ranges for its outcome line and outcome runs.
public struct QueuePackModel: Sendable, Equatable {
    public enum RangeKind: Sendable, Hashable {
        case done, current, waiting
        case outcome(QueuePackOutcome)

        /// "Linked", "Linking", "Waiting", or the outcome capitalised.
        public var label: String {
            switch self {
            case .done: return "Linked"
            case .current: return "Linking"
            case .waiting: return "Waiting"
            case .outcome(let o): return o.label.prefix(1).uppercased() + o.label.dropFirst()
            }
        }

        /// done / ok: check · current / hold: dot · waiting / skip: ring.
        public var style: QueuePackOutcome.Style {
            switch self {
            case .done: return .ok
            case .current: return .hold
            case .waiting: return .skip
            case .outcome(let o): return o.style
            }
        }
    }

    public struct Range: Sendable, Hashable {
        public let kind: RangeKind
        public let startLabel: String
        public let endLabel: String
        public let count: Int

        /// "S03E01–S03E04", or one label for a single episode (web `rangeLabel`).
        public var label: String { startLabel == endLabel ? startLabel : "\(startLabel)–\(endLabel)" }
    }

    /// Episodes shown per range before "Show all".
    public static let rangeCap = 8

    public let total: Int
    public let done: Int
    public let headline: String
    public let summary: String
    /// "then caching and validating" while linking; nil otherwise.
    public let then: String?
    /// The ranges are a held pack's outcome runs, not the linking progress.
    public let decided: Bool
    /// 0–1 for the thin bar.
    public let fraction: Double
    public let ranges: [Range]

    /// Whether this download is a pack the card draws with the pack line.
    public static func isPack(_ item: QueueItem) -> Bool {
        item.fileCount != nil && item.packRanges != nil
    }

    public init(item: QueueItem) {
        self.init(fileCount: item.fileCount, ranges: item.packRanges, stages: item.stages,
                  summary: item.hasPackDecisions ? item.packSummary : nil,
                  outcomeRanges: item.hasPackDecisions ? item.packOutcomeRanges : nil)
    }

    public init(fileCount: Int?, ranges: QueuePackRanges?, stages: QueueStages?,
                summary: QueuePackSummary? = nil, outcomeRanges: [QueuePackOutcomeRange]? = nil) {
        let total = fileCount ?? 0
        let linking = stages?.linkingDone != nil && stages?.linkingTotal != nil
        let done = linking ? (stages?.linkingDone ?? 0) : (ranges?.done?.count ?? 0)
        self.total = total
        self.done = done
        if linking, let linkTotal = stages?.linkingTotal {
            headline = "Linking \(done) of \(linkTotal)"
        } else if done >= total {
            headline = "\(total) files linked"
        } else if done == 0 {
            headline = "\(total) files waiting"
        } else {
            headline = "\(done) of \(total) files linked"
        }
        fraction = total > 0 ? min(1, Double(done) / Double(total)) : 0
        if let outcomeRanges, !outcomeRanges.isEmpty, summary != nil {
            self.summary = summary?.text ?? ""
            then = nil
            decided = true
            self.ranges = outcomeRanges.map {
                Range(kind: .outcome($0.outcome), startLabel: $0.startLabel, endLabel: $0.endLabel, count: $0.count)
            }
            return
        }
        decided = false
        var parts: [String] = []
        var out: [Range] = []
        let progress: [(RangeKind, QueuePackRange?)] = [(.done, ranges?.done), (.current, ranges?.current), (.waiting, ranges?.waiting)]
        for (kind, r) in progress {
            guard let r else { continue }
            let range = Range(kind: kind, startLabel: r.startLabel, endLabel: r.endLabel, count: r.count)
            parts.append(kind == .done ? "\(range.label) ✓" : range.label)
            out.append(range)
        }
        self.summary = parts.joined(separator: " · ")
        self.ranges = out
        then = Self.thenLine(stages)
    }

    /// "then caching and validating": the running stages after linking.
    static func thenLine(_ stages: QueueStages?) -> String? {
        guard let stages, stages.current == "linking", let steps = stages.steps else { return nil }
        let runs = steps.filter(\.runs).map(\.key)
        guard let at = runs.firstIndex(of: "linking") else { return nil }
        let after = Array(runs[(at + 1)...])
        let named = after.filter { $0 != "complete" }
        let list = (named.isEmpty ? after : named).map { QueueStageLabel.label($0).lowercased() }
        return list.isEmpty ? nil : "then \(andList(list))"
    }

    static func andList(_ xs: [String]) -> String {
        guard xs.count > 1 else { return xs.first ?? "" }
        return xs.dropLast().joined(separator: ", ") + " and " + xs[xs.count - 1]
    }

    /// The episodes of each range, cut from the pack's ordered list.
    public func split(_ episodes: [QueuePackEpisode]) -> [[QueuePackEpisode]] {
        var at = 0
        return ranges.map { range in
            let start = min(at, episodes.count)
            let end = min(at + range.count, episodes.count)
            at += range.count
            return Array(episodes[start..<end])
        }
    }

    /// A batch labels by absolute number when its range labels are bare digits.
    public var absoluteWidth: Int? {
        guard let first = ranges.first?.startLabel, !first.isEmpty, first.allSatisfy(\.isNumber) else { return nil }
        return first.count
    }

    /// `S03E01`, or `001` in a batch.
    public static func episodeLabel(_ e: QueuePackEpisode, absoluteWidth: Int?) -> String {
        if let width = absoluteWidth, let abs = e.absolute {
            let digits = String(abs)
            return String(repeating: "0", count: max(0, width - digits.count)) + digits
        }
        return String(format: "S%02dE%02d", e.season, e.episode)
    }
}

/// decypharr stage names as the web words them (`stage-rail.ts` `stageLabel`).
public enum QueueStageLabel {
    private static let labels = [
        "queued": "Queued", "parsing": "Parsing", "downloading": "Downloading", "processed": "Processed",
        "linking": "Linking", "caching": "Caching", "probing": "Probing", "validating": "Validating",
        "complete": "Complete", "importing": "Importing",
    ]

    public static func label(_ key: String?) -> String {
        guard let key, !key.isEmpty else { return "Working" }
        return labels[key] ?? key.prefix(1).uppercased() + key.dropFirst()
    }
}
