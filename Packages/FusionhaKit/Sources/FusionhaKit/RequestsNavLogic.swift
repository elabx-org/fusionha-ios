import Foundation

/// Where a request came from, as the approver's filter sheet offers it
/// (Manual · Plex · Letterboxd). `GET /api/v1/requests` and `/requests/counts`
/// take `source` as a comma list: `MANUAL`, plus the aliases `plex` and
/// `letterboxd` for every kind of that provider (fusionha 0.4.215).
public enum RequestOrigin: String, CaseIterable, Sendable, Hashable {
    case manual, plex, letterboxd

    public var title: String {
        switch self {
        case .manual: return "Manual"
        case .plex: return "Plex"
        case .letterboxd: return "Letterboxd"
        }
    }

    /// The value inside `source=`.
    public var param: String { self == .manual ? "MANUAL" : rawValue }

    /// The origin of a request's source kind; a missing source is manual.
    public static func of(_ kind: String?) -> RequestOrigin? {
        guard let kind, kind != "MANUAL" else { return .manual }
        if RequestSourceWords.plexKinds.contains(kind) { return .plex }
        if RequestSourceWords.letterboxdKinds.contains(kind) { return .letterboxd }
        return nil
    }

    /// The `source` item for a set, in a stable order; none for an empty set.
    public static func query(_ set: Set<RequestOrigin>) -> [URLQueryItem] {
        let values = allCases.filter(set.contains).map(\.param)
        return values.isEmpty ? [] : [URLQueryItem(name: "source", value: values.joined(separator: ","))]
    }

    /// The one word a row shows for its source ("Letterboxd", "Plex", "Manual").
    public static func word(_ source: RequestSource?) -> String {
        of(source?.kind)?.title ?? (source.map { RequestSourceWords.labels[$0.kind] ?? $0.kind } ?? "Manual")
    }
}

/// History grouped by the day it was decided (web `RequestsHistory`, phone):
/// Today, Yesterday, Earlier this month, then one group per month.
public enum RequestHistoryDays {
    public struct Group: Sendable, Equatable {
        public let title: String
        public let ids: [Int]
    }

    /// The instant a row is filed under: decided, else available, else asked.
    public static func instant(_ r: MediaRequest) -> Date? {
        ServerTime.parse(r.decidedAt) ?? ServerTime.parse(r.availableAt) ?? ServerTime.parse(r.requestedAt)
    }

    /// Groups in the order the rows arrive (newest first from the server).
    public static func group(_ rows: [MediaRequest], now: Date = Date(), calendar: Calendar = .current) -> [Group] {
        var order: [String] = []
        var ids: [String: [Int]] = [:]
        for r in rows {
            let key = title(instant(r), now: now, calendar: calendar)
            if ids[key] == nil { order.append(key) }
            ids[key, default: []].append(r.id)
        }
        return order.map { Group(title: $0, ids: ids[$0] ?? []) }
    }

    public static func title(_ date: Date?, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let date else { return "Earlier" }
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let y = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: y) { return "Yesterday" }
        if calendar.isDate(date, equalTo: now, toGranularity: .month) { return "Earlier this month" }
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = calendar.isDate(date, equalTo: now, toGranularity: .year) ? "MMMM" : "MMMM yyyy"
        return f.string(from: date)
    }

    /// The right-hand time: "2h" today, "18:40" yesterday, "Oct 9" before.
    public static func time(_ date: Date?, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let date else { return "" }
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        if calendar.isDate(date, inSameDayAs: now) {
            let minutes = max(0, Int(now.timeIntervalSince(date) / 60))
            return minutes < 60 ? "\(max(1, minutes))m" : "\(minutes / 60)h"
        }
        if let y = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: y) {
            f.dateFormat = "HH:mm"
        } else {
            f.dateFormat = calendar.isDate(date, equalTo: now, toGranularity: .year) ? "MMM d" : "MMM d, yyyy"
        }
        return f.string(from: date)
    }
}

/// The phone Board's line under its name (joint rule, 2026-10-18): only the
/// stages that need the approver, each a jump to its section; never blank.
public enum RequestBoardSummary {
    public struct Part: Sendable, Equatable {
        public let count: Int?
        public let text: String
        public let column: RequestBoard.Column?
    }

    public static func parts(pending: Int, downloading: Int, available: Int) -> [Part] {
        var out: [Part] = []
        if pending > 0 { out.append(Part(count: pending, text: "pending", column: .pending)) }
        if downloading > 0 { out.append(Part(count: downloading, text: "downloading", column: .downloading)) }
        if !out.isEmpty { return out }
        if available > 0 {
            return [Part(count: nil, text: "Nothing waiting", column: nil),
                    Part(count: available, text: "available", column: .available)]
        }
        return [Part(count: nil, text: "No requests yet", column: nil)]
    }
}

/// "about 12 min left" from the server's `eta_seconds` (0.4.216); nil hides it.
public enum DownloadTimeLeft {
    public static func text(_ seconds: Int?) -> String? {
        guard let seconds, seconds >= 0 else { return nil }
        if seconds < 60 { return "less than a minute left" }
        let minutes = Int((Double(seconds) / 60).rounded())
        if minutes < 60 { return "about \(minutes) min left" }
        let hours = Double(seconds) / 3600
        return hours < 10 ? "about \(String(format: "%.1f", hours).replacingOccurrences(of: ".0", with: "")) h left" : "about \(Int(hours.rounded())) h left"
    }
}

/// The phone Board's per-stage facts (Final mock): "all by eafx" when every
/// row in a stage shares a requester, and how many rows a stage shows before
/// "Show all N".
public enum RequestStageFacts {
    public static let preview = 5

    /// The one requester every row shares, or nil.
    public static func sharedRequester(_ rows: [MediaRequest]) -> String? {
        let names = Set(rows.map { $0.requester?.displayName ?? "" })
        guard rows.count > 1, names.count == 1, let only = names.first, !only.isEmpty else { return nil }
        return only
    }
}

/// Issues in the Requests menu (Proposal 2, approved 2026-10-19): how many
/// are open, and how many need an admin. The badge counts only the second.
public struct IssueCounts: Sendable, Equatable {
    public let open: Int
    public let needYou: Int

    public init(open: Int = 0, needYou: Int = 0) {
        self.open = open
        self.needYou = needYou
    }

    /// From issue threads: open is anything not resolved; an issue needs you
    /// when the checks have handed it to an admin (`NEEDS_ADMIN`).
    public static func of(_ items: [ThreadItem]) -> IssueCounts {
        let issues = items.compactMap { $0.type == "issue" ? $0.issue : nil }
        let open = issues.filter { ($0.state ?? "OPEN") != "RESOLVED" }
        return IssueCounts(open: open.count, needYou: open.filter { $0.state == "NEEDS_ADMIN" }.count)
    }
}

/// The drawer's breakdown line: "11 need you · 9 pending requests · 2 issues".
public enum RequestsNeedYou {
    public static func line(pending: Int?, issues: Int?) -> String? {
        let parts = [pending.map { "\($0) pending \($0 == 1 ? "request" : "requests")" },
                     issues.map { "\($0) \($0 == 1 ? "issue" : "issues")" }].compactMap { $0 }
        let total = (pending ?? 0) + (issues ?? 0)
        guard !parts.isEmpty else { return nil }
        if parts.count == 1 {
            return pending != nil ? parts[0] : "\(total) \(total == 1 ? "issue needs" : "issues need") you"
        }
        return "\(total) need you · " + parts.joined(separator: " · ")
    }
}
