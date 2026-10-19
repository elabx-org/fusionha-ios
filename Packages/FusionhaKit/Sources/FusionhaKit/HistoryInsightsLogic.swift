import Foundation

/// The History tab's Insights view (history-derive.ts): the stat cards, the
/// per-version score progression and the provenance swimlane.
public enum HistoryInsightsLogic {
    public struct Stats: Equatable, Sendable {
        public let eventsCount: Int
        public let daySpanLabel: String?
        public let upgradesCount: Int
        /// `[(tier short label, count)]`, in version order.
        public let upgradesByTier: [TierCount]
        public let netScore: Int
        public let hasAnyImport: Bool
        public let indexerNames: [String]
        public var indexersCount: Int { indexerNames.count }

        /// "HD & 4K upgraded", or nil when nothing upgraded.
        public var trendLabel: String? {
            upgradesByTier.isEmpty ? nil : "\(upgradesByTier.map(\.label).joined(separator: " & ")) upgraded"
        }
    }

    public struct TierCount: Equatable, Sendable {
        public let label: String
        public let count: Int
    }

    public struct Point: Equatable, Sendable {
        public let at: Date
        public let score: Int
    }

    public struct Series: Equatable, Sendable, Identifiable {
        public let versionId: Int
        public let label: String
        public let tier: QualityTier
        public let points: [Point]
        public var id: Int { versionId }
    }

    public struct Segment: Equatable, Sendable {
        public let title: String
        public let score: Int?
        public let start: Date
        public let end: Date
        public let isCurrent: Bool
    }

    public struct Lane: Equatable, Sendable, Identifiable {
        public let versionId: Int
        public let label: String
        public let tier: QualityTier
        public let segments: [Segment]
        public var id: Int { versionId }
    }

    static func time(_ e: HistoryEntry) -> Date? { DetailText.instant(e.createdAt) }

    static func ascending(_ events: [HistoryEntry]) -> [(HistoryEntry, Date)] {
        events.compactMap { e in time(e).map { (e, $0) } }
            .sorted { ($0.1, $0.0.id) < ($1.1, $1.0.id) }
    }

    static func imports(_ events: [HistoryEntry], version: Int) -> [(HistoryEntry, Date)] {
        ascending(events.filter { $0.editionId == version && $0.eventType == "IMPORTED" })
    }

    public static func stats(_ versions: [DetailEdition], _ events: [HistoryEntry],
                             calendar: Calendar = .current) -> Stats {
        var upgrades = 0, net = 0, any = false
        var byTier: [TierCount] = []
        for version in versions {
            let imports = imports(events, version: version.id)
            guard !imports.isEmpty else { continue }
            any = true
            let extra = imports.count - 1
            if extra > 0 {
                upgrades += extra
                let label = version.tier.tierShort
                if let i = byTier.firstIndex(where: { $0.label == label }) {
                    byTier[i] = TierCount(label: label, count: byTier[i].count + extra)
                } else {
                    byTier.append(TierCount(label: label, count: extra))
                }
            }
            let first = imports.first?.0.cfScore ?? 0
            let last = imports.last?.0.cfScore ?? 0
            net += max(0, last - first)
        }
        let indexers = Set(events.filter { $0.eventType == "GRABBED" }.compactMap(\.indexer).filter { !$0.isEmpty })
        return Stats(eventsCount: events.count, daySpanLabel: daySpan(events, calendar: calendar),
                     upgradesCount: upgrades, upgradesByTier: byTier, netScore: net, hasAnyImport: any,
                     indexerNames: indexers.sorted { $0.localizedCompare($1) == .orderedAscending })
    }

    static func daySpan(_ events: [HistoryEntry], calendar: Calendar) -> String? {
        let dates = events.compactMap(time)
        guard let lo = dates.min(), let hi = dates.max() else { return nil }
        let days = (calendar.dateComponents([.day], from: calendar.startOfDay(for: lo), to: calendar.startOfDay(for: hi)).day ?? 0) + 1
        return "over \(days) day\(days == 1 ? "" : "s")"
    }

    /// The hero sparkline: every import's score, oldest first.
    public static func sparkline(_ events: [HistoryEntry]) -> [Int] {
        ascending(events.filter { $0.eventType == "IMPORTED" && $0.cfScore != nil }).compactMap(\.0.cfScore)
    }

    public static func progression(_ versions: [DetailEdition], _ events: [HistoryEntry]) -> [Series] {
        versions.map { version in
            let points = imports(events, version: version.id).compactMap { e, at in e.cfScore.map { Point(at: at, score: $0) } }
            return Series(versionId: version.id, label: version.label, tier: version.tier, points: points)
        }
    }

    /// Which release held each version's slot: one segment per import, from it
    /// to the next import (or now).
    public static func swimlane(_ versions: [DetailEdition], _ events: [HistoryEntry],
                                now: Date = Date()) -> (lanes: [Lane], start: Date?) {
        let start = events.compactMap(time).min()
        let lanes = versions.map { version -> Lane in
            let imports = imports(events, version: version.id)
            let segments = imports.indices.map { i in
                Segment(title: imports[i].0.sourceTitle ?? "Unknown release", score: imports[i].0.cfScore,
                        start: imports[i].1, end: i + 1 < imports.count ? imports[i + 1].1 : now,
                        isCurrent: i == imports.count - 1)
            }
            return Lane(versionId: version.id, label: version.label, tier: version.tier, segments: segments)
        }
        return (lanes, start)
    }

    /// "Plex (Prowlarr)" → "Plex": the source suffix repeats on every chip.
    public static func indexerChip(_ name: String) -> String {
        name.replacingOccurrences(of: #"\s*\([^)]*\)\s*$"#, with: "", options: .regularExpression)
    }
}
