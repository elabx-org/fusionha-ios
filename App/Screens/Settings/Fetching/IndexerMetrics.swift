import SwiftUI
import FusionhaKit

/// One indexer joined with its range-scoped stats (`buildIndexerMetrics`).
struct IndexerMetric: Identifiable {
    let indexer: SearchIndexerInfo
    let stat: IndexerStatRow?
    let grabsRange: Int
    let grabs24h: Int
    let share: Double
    let yieldValue: Double
    let successPct: Int?
    let activity: [Int]
    let state: String
    let isNew: Bool
    var id: Int { indexer.id }

    static func build(_ indexers: [SearchIndexerInfo], stats: IndexerStatsResponse?) -> [IndexerMetric] {
        let byId = Dictionary((stats?.indexers ?? []).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let clientFleet = indexers.reduce(0) { $0 + (byId[$1.id]?.grabsRange ?? 0) }
        let fleet = stats?.summary?.grabsRange ?? clientFleet
        return indexers.map { indexer in
            let stat = byId[indexer.id]
            let grabs = stat?.grabsRange ?? 0
            let created = FetchFormat.date(stat?.createdAt)
            return IndexerMetric(
                indexer: indexer,
                stat: stat,
                grabsRange: grabs,
                grabs24h: stat?.grabs24h ?? 0,
                share: fleet > 0 ? Double(grabs) / Double(fleet) * 100 : 0,
                yieldValue: stat?.yieldRange ?? 0,
                successPct: stat?.successRateRange.map { Int(($0 * 100).rounded()) },
                activity: stat?.activitySeries ?? [],
                state: stat?.health.state ?? (indexer.isEnabled ? "healthy" : "disabled"),
                isNew: created.map { Date.now.timeIntervalSince($0) <= 7 * 86_400 } ?? false)
        }
    }

    var daysSinceCreated: Int? {
        FetchFormat.date(stat?.createdAt).map { max(0, Int(Date.now.timeIntervalSince($0) / 86_400)) }
    }
}

enum IndexerRange: String, CaseIterable, Identifiable {
    case day = "24h", week = "7d", month = "30d", all = "all"
    var id: String { rawValue }
    var label: String { self == .all ? "All-time" : rawValue }
    var phrase: String {
        switch self {
        case .day: return "last 24h"
        case .week: return "last 7 days"
        case .month: return "last 30 days"
        case .all: return "all-time"
        }
    }
}

/// The leaderboard colour ramp (`SHARE_PALETTE`).
var indexerSharePalette: [Color] { [Theme.indigo, Theme.cyan, Theme.done, Theme.edition, Theme.miss] }
