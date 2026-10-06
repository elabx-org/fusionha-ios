import Foundation

public struct WidgetIndexerRow: Codable, Sendable, Hashable {
    public let name: String
    /// `healthy`, `backoff`, `disabled`…
    public let state: String
    /// 0–100, nil when the indexer had no queries.
    public let successPercent: Int?
    public let grabs: Int
    public let series: [Int]

    public init(name: String, state: String, successPercent: Int?, grabs: Int, series: [Int]) {
        self.name = name
        self.state = state
        self.successPercent = successPercent
        self.grabs = grabs
        self.series = series
    }

    public var healthy: Bool { state == "healthy" }
}

/// What the Indexers page lists. Each indexer appears once: a flagged one in
/// the busiest list carries its flag as a note there instead of a second row.
public struct WidgetIndexerLines: Equatable, Sendable {
    public var rows: [WidgetIndexerRow]
    /// Per row, its flag's detail (`backing off`), nil when it is fine.
    public var notes: [String?]
    public var flags: [WidgetIndexerFlag]
}

public struct WidgetIndexerFlag: Codable, Sendable, Hashable {
    public let name: String
    /// `backing off · retry in 12m`, `off`.
    public let detail: String

    public init(name: String, detail: String) {
        self.name = name
        self.detail = detail
    }
}

/// The Indexers page: health tiles, a summary line, the busiest indexers with
/// their activity, and the ones backing off or unavailable.
public struct WidgetIndexerSummary: Codable, Sendable, Hashable {
    public var healthy = 0
    public var backingOff = 0
    public var off = 0
    public var total = 0
    /// 0–100.
    public var successPercent: Int?
    public var grabs = 0
    public var queries = 0
    public var top: [WidgetIndexerRow] = []
    public var flagged: [WidgetIndexerFlag] = []

    public init() {}

    public init(stats: ActivityIndexerStats, unavailable: [UnavailableIndexer], now: Date = Date(), top limit: Int = 4) {
        let s = stats.summary
        healthy = s.healthy
        backingOff = s.backoff
        off = s.off
        total = s.indexers
        successPercent = s.avgSuccessRange.map(Self.percent)
        grabs = s.grabsRange ?? stats.indexers.reduce(0) { $0 + ($1.grabsRange ?? 0) }
        queries = s.queriesRange ?? stats.indexers.reduce(0) { $0 + ($1.queriesRange ?? 0) }
        top = stats.indexers
            .filter { $0.health?.state != "disabled" }
            .enumerated()
            .sorted { a, b in
                let x = a.element.grabsRange ?? 0, y = b.element.grabsRange ?? 0
                return x == y ? a.offset < b.offset : x > y
            }
            .prefix(limit)
            .map { row in
                WidgetIndexerRow(name: row.element.name, state: row.element.health?.state ?? "healthy",
                                 successPercent: row.element.successRateRange.map(Self.percent),
                                 grabs: row.element.grabsRange ?? 0, series: row.element.activitySeries ?? [])
            }
        var flags: [WidgetIndexerFlag] = unavailable.map {
            WidgetIndexerFlag(name: $0.name, detail: "unavailable · \($0.retryHint(now: now))")
        }
        for row in stats.indexers where !flags.contains(where: { $0.name == row.name }) {
            switch row.health?.state {
            case "backoff": flags.append(WidgetIndexerFlag(name: row.name, detail: "backing off"))
            case "disabled": flags.append(WidgetIndexerFlag(name: row.name, detail: "off"))
            default: break
            }
        }
        flagged = flags
    }

    /// The busiest `rows` indexers, then up to `flags` flagged ones not already
    /// listed. With `sharedSlots` (medium), an unlisted flag takes the last row's place.
    public func lines(rows rowLimit: Int, flags flagLimit: Int, sharedSlots: Bool) -> WidgetIndexerLines {
        var shown = Array(top.prefix(rowLimit))
        func unlisted() -> [WidgetIndexerFlag] {
            flagged.filter { flag in !shown.contains { $0.name == flag.name } }
        }
        if sharedSlots, rowLimit > 1, shown.count == rowLimit, !unlisted().isEmpty { shown.removeLast() }
        let notes = shown.map { row -> String? in
            flagged.first { $0.name == row.name }?.detail ?? (row.state == "backoff" ? "backing off" : nil)
        }
        return WidgetIndexerLines(rows: shown, notes: notes, flags: Array(unlisted().prefix(flagLimit)))
    }

    /// `70 grabs · 1.3k queries · 4 indexers`.
    public var line: String {
        "\(Self.compact(grabs)) grab\(grabs == 1 ? "" : "s") · \(Self.compact(queries)) quer\(queries == 1 ? "y" : "ies")"
            + " · \(total) indexer\(total == 1 ? "" : "s")"
    }

    /// `950`, `1.3k`, `12k`, `1.2M`: locale-free, so it fits a widget line.
    public static func compact(_ value: Int) -> String {
        func trimmed(_ v: Double) -> String {
            let s = String(format: "%.1f", v)
            return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
        }
        switch value {
        case ..<1000: return "\(value)"
        case ..<10_000: return trimmed(Double(value) / 1000) + "k"
        case ..<1_000_000: return "\(Int((Double(value) / 1000).rounded()))k"
        default: return trimmed(Double(value) / 1_000_000) + "M"
        }
    }

    static func percent(_ rate: Double) -> Int {
        // The server sends a 0–1 fraction; tolerate a 0–100 percentage too.
        Int((rate > 1 ? rate : rate * 100).rounded())
    }
}
