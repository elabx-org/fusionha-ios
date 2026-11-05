import Foundation

// The v2 edition badge (A1 monochrome, T5 tickets; owner 2026-11-04). One
// state per version: the badge is filled in the label colour when the
// version is on disk, an outline when it is missing, an outline plus the
// accent ring while it downloads, and an orange outline with "!" when it is
// held. A partly owned season stays filled and adds a quiet "n/m".

/// One version's badge state.
public enum EditionBadgeState: Equatable, Sendable {
    case onDisk
    /// Some episodes on disk: filled, with an "n/m" count.
    case partial(have: Int, of: Int)
    case missing
    /// In the queue (or upgrading): outline plus the ring. `progress` is
    /// 0...1, nil until the client reports any.
    case downloading(progress: Double?)
    /// Needs the owner: a held import, a not-found or dead-link file.
    case held

    /// From a coverage rail and the version's live download, if any.
    /// Held wins (attention, dead links, a held import), then the rail's
    /// state: upgrading reads as downloading.
    public init(rail: Rail, queue: QueueProgress? = nil) {
        if rail.attention || queue?.held == true {
            self = .held
            return
        }
        switch rail.state {
        case .owned:
            self = .onDisk
        case .downloading, .upgrading:
            self = .downloading(progress: queue.map { Double($0.percent) / 100 })
        case .partial:
            if let c = Self.counts(rail.fraction), c.have > 0, c.have < c.total {
                self = .partial(have: c.have, of: c.total)
            } else {
                self = .onDisk
            }
        case .wanted, .upcoming:
            self = .missing
        }
    }

    /// From an edition, through the same rail the v1 cards use.
    public init(edition: Edition, isSeries: Bool, queue: QueueProgress? = nil) {
        self.init(rail: edition.rail(isSeries: isSeries), queue: queue)
    }

    /// From a bare wire status (calendar rows, episode states).
    public init(status: EditionStatus) {
        switch status {
        case .downloaded: self = .onDisk
        case .downloading, .upgrading: self = .downloading(progress: nil)
        case .stuck, .deadlink: self = .held
        case .missing, .unaired, .upcoming, .unmonitored, .onair, .premiere, .available, .other:
            self = .missing
        }
    }

    /// Filled in the label colour (on disk, or partly).
    public var isFilled: Bool {
        switch self {
        case .onDisk, .partial: return true
        default: return false
        }
    }

    public var isHeld: Bool { self == .held }

    /// The accent ring beside the badge.
    public var showsRing: Bool {
        if case .downloading = self { return true }
        return false
    }

    /// The quiet count beside a partly owned version.
    public var count: String? {
        if case let .partial(have, total) = self { return "\(have)/\(total)" }
        return nil
    }

    /// Two versions plug together into one ticket only when they say the same
    /// thing and carry nothing beside them: both on disk, or both missing.
    public static func joins(_ a: EditionBadgeState, _ b: EditionBadgeState) -> Bool {
        (a == .onDisk && b == .onDisk) || (a == .missing && b == .missing)
    }

    /// The state in words, for VoiceOver: "on disk", "3 of 5 on disk",
    /// "downloading 40%".
    public var spoken: String {
        switch self {
        case .onDisk: return "on disk"
        case let .partial(have, total): return "\(have) of \(total) on disk"
        case .missing: return "missing"
        case let .downloading(progress?):
            return "downloading \(Int((min(1, max(0, progress)) * 100).rounded()))%"
        case .downloading: return "downloading"
        case .held: return "held"
        }
    }

    /// `"3/5"` → (3, 5).
    static func counts(_ fraction: String?) -> (have: Int, total: Int)? {
        guard let parts = fraction?.split(separator: "/"), parts.count == 2,
              let have = Int(parts[0]), let total = Int(parts[1]) else { return nil }
        return (have: have, total: total)
    }
}

extension QualityTier {
    /// The letters on a badge: `HD` / `4K`. They name the version, never a hue.
    public var badgeLetters: String { self == .hd ? "HD" : "4K" }
}

/// What VoiceOver reads for a title's badges.
public enum EditionBadgeSpeech {
    /// "HD on disk", "HD and 4K on disk", "HD on disk, 4K downloading 40%".
    public static func label(hd: EditionBadgeState?, uhd: EditionBadgeState?) -> String {
        switch (hd, uhd) {
        case let (a?, b?) where EditionBadgeState.joins(a, b):
            return "HD and 4K \(a.spoken)"
        case let (a?, b?):
            return "HD \(a.spoken), 4K \(b.spoken)"
        case let (a?, nil):
            return "HD \(a.spoken)"
        case let (nil, b?):
            return "4K \(b.spoken)"
        case (nil, nil):
            return ""
        }
    }
}
