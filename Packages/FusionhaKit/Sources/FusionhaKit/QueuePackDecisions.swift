import Foundation

// A held season pack's stored per-file decisions (fusionha 0.4.196,
// `pack_summary` / `pack_outcome_ranges` / `pack_mixed` and the episode
// `outcome`), worded as the web's `pack-decisions.ts`: the line "9
// import-ready · 3 held · 1 already owned", the runs "E01–E09 import-ready",
// and the amber "1080p · Mixed" chip with "E03–E05 probe 1280×720, the other
// 10 probe 1920×1080".

/// One file's decision. `missing`: the pack has no file for the episode.
public enum QueuePackOutcome: String, Sendable, Hashable, CaseIterable, Decodable {
    case imported, ready, held, owned, unmatched, missing

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = QueuePackOutcome(rawValue: raw) ?? .unmatched
    }

    /// Lower-case, as the web's line and runs read.
    public var label: String {
        switch self {
        case .imported: return "imported"
        case .ready: return "import-ready"
        case .held: return "held"
        case .owned: return "already owned"
        case .unmatched: return "unmatched"
        case .missing: return "no file"
        }
    }

    public enum Style: Sendable { case ok, hold, skip }

    /// ok (green), hold (amber), skip (dim).
    public var style: Style {
        switch self {
        case .imported, .ready: return .ok
        case .held: return .hold
        case .owned, .unmatched, .missing: return .skip
        }
    }
}

/// How a held pack's member files were decided.
public struct QueuePackSummary: Decodable, Sendable, Hashable {
    public let imported: Int
    public let ready: Int
    public let held: Int
    public let owned: Int
    public let unmatched: Int

    public init(imported: Int, ready: Int, held: Int, owned: Int, unmatched: Int) {
        self.imported = imported
        self.ready = ready
        self.held = held
        self.owned = owned
        self.unmatched = unmatched
    }

    /// "4 imported · 6 import-ready · 3 held · 1 already owned"; zero parts left out.
    public var text: String? {
        let parts: [(Int, QueuePackOutcome)] = [(imported, .imported), (ready, .ready), (held, .held),
                                                (owned, .owned), (unmatched, .unmatched)]
        let shown = parts.filter { $0.0 > 0 }.map { "\($0.0) \($0.1.label)" }
        return shown.isEmpty ? nil : shown.joined(separator: " · ")
    }
}

/// A run of consecutive covered episodes with the same decision.
public struct QueuePackOutcomeRange: Decodable, Sendable, Hashable {
    public let outcome: QueuePackOutcome
    public let startLabel: String
    public let endLabel: String
    public let count: Int

    public init(outcome: QueuePackOutcome, startLabel: String, endLabel: String, count: Int) {
        self.outcome = outcome
        self.startLabel = startLabel
        self.endLabel = endLabel
        self.count = count
    }

    /// "E01–E09 import-ready".
    public var text: String { "\(PackDecisions.runLabel(startLabel, endLabel)) \(outcome.label)" }
}

/// One value of a mixed fact and the episodes whose files carry it.
public struct QueuePackMixedPart: Decodable, Sendable, Hashable {
    public let fact: String
    public let value: String
    public let count: Int
    public let episodes: [QueuePackRange]
    /// What the probe measured (`1280×720`); nil for name-only values.
    public let probe: String?

    public init(fact: String, value: String, count: Int, episodes: [QueuePackRange], probe: String?) {
        self.fact = fact
        self.value = value
        self.count = count
        self.episodes = episodes
        self.probe = probe
    }
}

/// The values that differ across a pack's files (nil = uniform or unknown).
public struct QueuePackMixed: Decodable, Sendable, Hashable {
    public let resolution: [String]?
    public let codec: [String]?
    public let hdr: [String]?
    public let breakdown: [QueuePackMixedPart]?

    public init(resolution: [String]?, codec: [String]?, hdr: [String]?, breakdown: [QueuePackMixedPart]?) {
        self.resolution = resolution
        self.codec = codec
        self.hdr = hdr
        self.breakdown = breakdown
    }
}

public enum PackDecisions {
    /// `S02E03` → `E03` inside one season's pack; batches keep `001`.
    public static func shortLabel(_ label: String) -> String {
        guard label.hasPrefix("S"), let e = label.firstIndex(of: "E"),
              label[label.index(after: label.startIndex)..<e].allSatisfy(\.isNumber),
              e > label.index(after: label.startIndex) else { return label }
        return String(label[e...])
    }

    /// "E01–E09", or one label for a single episode.
    public static func runLabel(_ start: String, _ end: String) -> String {
        start == end ? shortLabel(start) : "\(shortLabel(start))–\(shortLabel(end))"
    }

    /// One fact that differs across a pack's files: "1080p · Mixed".
    public struct MixedFact: Sendable, Hashable {
        public let key: String
        public let text: String
        /// "Mixed inside this pack: E03–E05 probe 1280×720, the other 10 probe 1920×1080".
        public let detail: String
        /// "Mixed inside this pack (720p, 1080p)".
        public let accessibilityLabel: String
    }

    /// One marker per fact that differs (none when uniform). The name's own
    /// value leads when it is one of them, else the largest.
    public static func mixedFacts(_ mixed: QueuePackMixed?, parsed: ReleaseFacts?) -> [MixedFact] {
        guard let mixed else { return [] }
        let facts: [(String, [String]?)] = [("resolution", mixed.resolution), ("codec", mixed.codec), ("hdr", mixed.hdr)]
        return facts.compactMap { key, values in
            guard let values, values.count >= 2 else { return nil }
            let name = named(key, parsed)
            let base = name.flatMap { values.contains($0) ? $0 : nil } ?? values[values.count - 1]
            let parts = (mixed.breakdown ?? []).filter { $0.fact == key }
            let detail = breakdownText(parts) ?? values.joined(separator: ", ")
            return MixedFact(key: key, text: "\(base) · Mixed",
                             detail: "Mixed inside this pack: \(detail)",
                             accessibilityLabel: "Mixed inside this pack (\(values.joined(separator: ", ")))")
        }
    }

    /// "E03–E05 probe 1280×720, the other 10 probe 1920×1080" (largest group last).
    static func breakdownText(_ parts: [QueuePackMixedPart]) -> String? {
        guard parts.count >= 2 else { return nil }
        let sorted = parts.enumerated().sorted { a, b in
            a.element.count != b.element.count ? a.element.count > b.element.count : a.offset < b.offset
        }.map(\.element)
        let most = sorted[0]
        let describe = { (p: QueuePackMixedPart) in p.probe.map { "probe \($0)" } ?? p.value }
        let named = sorted.dropFirst().map { p in
            "\(p.episodes.map { runLabel($0.startLabel, $0.endLabel) }.joined(separator: " + ")) \(describe(p))"
        }
        return (named + ["the other \(most.count) \(describe(most))"]).joined(separator: ", ")
    }

    private static let nameCodec = ["HEVC": "H.265", "AVC": "H.264"]

    /// What the release name says for one fact, labelled as the server labels it.
    static func named(_ key: String, _ parsed: ReleaseFacts?) -> String? {
        guard let parsed else { return nil }
        switch key {
        case "resolution": return parsed.resolution.map { "\($0)p" }
        case "codec": return parsed.videoCodec.map { nameCodec[$0] ?? $0 }
        default:
            let dr = Set(parsed.dynamicRange ?? [])
            if dr.contains("DV") { return "DV" }
            if dr.contains("HDR10PLUS") { return "HDR10+" }
            if dr.contains("HDR10") || dr.contains("HDR") { return "HDR10" }
            return dr.contains("SDR") ? "SDR" : nil
        }
    }
}

extension QueueItem {
    /// The card shows the decisions instead of the linking progress.
    public var hasPackDecisions: Bool {
        packSummary != nil && !(packOutcomeRanges ?? []).isEmpty
    }
}
