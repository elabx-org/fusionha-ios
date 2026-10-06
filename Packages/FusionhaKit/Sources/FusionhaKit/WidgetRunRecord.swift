import Foundation

/// One widget timeline (or snapshot) call as the extension saw it: which
/// widget and size, how far it got, how it ended, and whether its entry was
/// then drawn. Written at every stage to the shared keychain, so the app can
/// show the owner the last few runs, including ones the system killed (left
/// `running`) and ones whose entry never rendered.
public struct WidgetRunRecord: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    /// `Downloads`, `UpNext`, `RecentlyAdded`.
    public var kind: String
    /// `small`, `medium`, `large`, …
    public var family: String
    /// `timeline` or `snapshot`.
    public var call: String
    public var log: WidgetRunLog
    /// The entry view drew this run's entry.
    public var rendered: Bool

    public init(id: String = String(UUID().uuidString.prefix(8)), kind: String, family: String,
                call: String = "timeline", log: WidgetRunLog, rendered: Bool = false) {
        self.id = id
        self.kind = kind
        self.family = family
        self.call = call
        self.log = log
        self.rendered = rendered
    }

    /// A run still `running` this long after it started was killed or hung:
    /// its own watchdog ends every reload well before this.
    public static let abandonedAfter: TimeInterval = 20

    public func abandoned(now: Date = Date()) -> Bool {
        log.outcome == .running && now.timeIntervalSince(log.started) > Self.abandonedAfter
    }

    /// `never finished`, `ok`, `timeout`, `failed`, or `running`.
    public func status(now: Date = Date()) -> String {
        if abandoned(now: now) { return "never finished" }
        return log.outcome.rawValue
    }

    /// `Downloads medium timeline · ok @page upnext 1.4s · drawn`.
    public func line(now: Date = Date()) -> String {
        let error = log.error.map { " · \($0)" } ?? ""
        let drawn = rendered ? " · drawn" : (log.outcome == .running ? "" : " · not drawn")
        let seconds = String(format: "%.1f", log.seconds)
        return "\(kind) \(family) \(call) · \(status(now: now)) @\(log.stage) \(log.page) \(seconds)s\(error)\(drawn)"
    }
}

/// The last few runs, newest first.
public enum WidgetRunJournal {
    public static let keep = 16

    /// `records` with `record` replacing its earlier copy (or added first),
    /// trimmed to `keep`.
    public static func upserting(_ record: WidgetRunRecord, into records: [WidgetRunRecord],
                                 keep: Int = WidgetRunJournal.keep) -> [WidgetRunRecord] {
        var out = records
        if let index = out.firstIndex(where: { $0.id == record.id }) {
            out[index] = record
        } else {
            out.insert(record, at: 0)
        }
        return Array(out.prefix(keep))
    }

    /// The newest earlier timeline run of the same widget and size, skipping
    /// one still in flight (a second widget of that size reloading alongside).
    public static func previous(kind: String, family: String, before id: String,
                                in records: [WidgetRunRecord], now: Date = Date()) -> WidgetRunRecord? {
        records.first { record in
            record.kind == kind && record.family == family && record.id != id && record.call == "timeline"
                && (record.log.outcome != .running || record.abandoned(now: now))
        }
    }

    public static func decode(_ data: Data?) -> [WidgetRunRecord] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([WidgetRunRecord].self, from: data)) ?? []
    }

    public static func encode(_ records: [WidgetRunRecord]) -> Data? {
        try? JSONEncoder().encode(records)
    }
}
