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

    /// The chip for a rail. `queuePercent` is the live download's progress
    /// (from `/api/v1/queue`) when the version is in the queue.
    public init(tier: QualityTier, rail: Rail, queuePercent: Int? = nil) {
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
            if let pct = queuePercent, pct > 0 { text = "\(min(pct, 100))%" } else { text = rail.fraction ?? "↓" }
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
    public static func chips(for item: MediaItem, queuePercent: (Edition) -> Int? = { _ in nil }) -> [EditionChipLabel] {
        let rails = item.rails
        return zip(item.editions, rails).map { EditionChipLabel(tier: $0.tier, rail: $1, queuePercent: queuePercent($0)) }
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
