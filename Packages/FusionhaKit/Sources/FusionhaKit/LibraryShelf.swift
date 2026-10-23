import Foundation

// Pure rules behind the content-first Library (owner-approved layout A, 2026-10-23):
// the edition chips that replace the coverage rails on the cards, the
// Recently added shelf and its "Added today" line.

// MARK: - Edition chip (`.q2`)

/// One version's chip under a card: the tier (HD purple, 4K cyan), a status
/// dot, and a short label only while the version is moving.
public struct EditionChipLabel: Equatable, Sendable {
    /// The dot's status, coloured by `EditionStatus.color` in the app.
    public enum Tone: Equatable, Sendable {
        case done, grabbing, wanted, upgrading, upcoming, attention, deadLink
    }

    public let tier: QualityTier
    public let tone: Tone
    /// `3/5`, `30%`, `↓`, `↑`; nil once the version is complete or waiting.
    public let text: String?

    public init(tier: QualityTier, tone: Tone, text: String?) {
        self.tier = tier
        self.tone = tone
        self.text = text
    }

    /// The chip for a rail. `queue` is the version's live download (from
    /// `/api/v1/queue`) when it is in the queue.
    public init(tier: QualityTier, rail: Rail, queue: QueueProgress? = nil) {
        self.tier = tier
        if rail.attention {
            tone = rail.deadLinkOnly ? .deadLink : .attention
            text = "!"
            return
        }
        switch rail.state {
        case .owned:
            tone = .done
            text = nil
        case .downloading:
            tone = .grabbing
            // A held import reads "!"; a finished transfer still importing
            // reads ↓ (never "100%" on a version that isn't done).
            if queue?.held == true {
                text = "!"
            } else if let pct = queue?.percent, pct > 0, pct < 100 {
                text = "\(pct)%"
            } else {
                text = rail.fraction ?? "↓"
            }
        case .upgrading:
            tone = .upgrading
            text = "↑"
        case .partial, .wanted:
            tone = .wanted
            text = rail.fraction
        case .upcoming:
            tone = .upcoming
            text = nil
        }
    }

    /// Every chip of a title, HD first (the web's edition order otherwise).
    public static func chips(for item: MediaItem, queue: (Edition) -> QueueProgress? = { _ in nil }) -> [EditionChipLabel] {
        let rails = item.rails
        return zip(item.editions, rails).map { EditionChipLabel(tier: $0.tier, rail: $1, queue: queue($0)) }
    }
}

/// A version's live download as a chip needs it: its percent (bytes when
/// sizes are known, else the client's) and whether the import is held.
public struct QueueProgress: Equatable, Sendable {
    public let percent: Int
    public let held: Bool

    public init(percent: Int, held: Bool) {
        self.percent = percent
        self.held = held
    }

    public init(_ q: QueueItem) {
        let pct = q.size > 0 ? (q.size - q.sizeleft) / q.size * 100 : q.progress
        percent = min(100, max(0, Int(pct.rounded())))
        held = q.heldReason != nil || q.heldDetail != nil || q.held != nil
    }
}

// MARK: - Title page ambient wash

/// The `--bg` scrim over the title page's blurred art (top to bottom), as
/// (location, opacity) stops. Dark palettes use the web's values
/// (hero-art.module.css: 78 / 62 / 50 %), a tint you feel. On a light ground
/// the same wash reads as tan fog and drowns secondary text, so light
/// palettes keep the page near-white: 94 % at the hero edge easing to solid.
public enum AmbientWash {
    public static func stops(light: Bool) -> [(location: Double, opacity: Double)] {
        light ? [(0, 0.94), (0.3, 0.97), (1, 1)] : [(0, 0.78), (0.3, 0.62), (1, 0.5)]
    }
}

// MARK: - Recently added shelf

public enum RecentShelf {
    /// How many cards the shelf holds before "See all".
    public static let limit = 10

    /// The newest titles of what the filters left, newest first; titles with
    /// no `added_at` never join. Empty when the filters leave nothing (the
    /// shelf then hides).
    public static func pick(_ items: [MediaItem], parse: (String?) -> Date?, limit: Int = RecentShelf.limit) -> [MediaItem] {
        let dated = items.compactMap { item in parse(item.addedAt).map { (item, $0) } }
        return dated.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.id < $1.0.id }
            .prefix(limit).map(\.0)
    }

    /// "Added today", "Added yesterday", "Added 3 days ago", then the date.
    public static func addedLine(_ added: Date?, now: Date, calendar: Calendar = .current,
                                 dateText: (Date) -> String) -> String? {
        guard let added else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: added),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<1: return "Added today"
        case 1: return "Added yesterday"
        case 2...6: return "Added \(days) days ago"
        default: return "Added \(dateText(added))"
        }
    }
}

// MARK: - Kind segment make-up bar

public enum KindMix {
    /// Each kind's share of the make-up bar under the kind segments (Movies,
    /// Series, Anime in that order). Zero total: equal thirds, so the bar
    /// still reads as three kinds.
    public static func shares(_ counts: [Int]) -> [Double] {
        let total = counts.reduce(0, +)
        guard total > 0 else { return counts.map { _ in 1 / Double(max(counts.count, 1)) } }
        return counts.map { Double($0) / Double(total) }
    }
}
