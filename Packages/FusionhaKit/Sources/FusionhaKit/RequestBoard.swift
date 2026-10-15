import Foundation

/// The approver's board and history (web `board-columns.ts`, `board-merge.ts`,
/// `board-lifecycle.ts`, `RequestsHistory.tsx`).
public enum RequestBoard {
    public enum Column: String, CaseIterable, Sendable, Hashable {
        case pending, approved, downloading, available, declined

        public var label: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

        public var tone: RequestLifecycle.Tone {
            switch self {
            case .pending: return .dim
            case .approved: return .accent
            case .downloading: return .grab
            case .available: return .done
            case .declined: return .danger
            }
        }

        /// The server bucket this column reads.
        public var bucket: Bucket {
            switch self {
            case .pending: return .pending
            case .approved, .downloading: return .active
            case .available: return .available
            case .declined: return .declined
            }
        }

        /// Available and Declined show the last week and hand off to History.
        public var history: HistoryFilter? {
            switch self {
            case .available: return .available
            case .declined: return .declined
            default: return nil
            }
        }
    }

    public enum Bucket: String, CaseIterable, Sendable, Hashable {
        case pending, active, available, declined

        /// The `GET /requests` query for this bucket under the toolbar's filters.
        public func query(search: String?, userId: Int?) -> (filter: String, extra: [URLQueryItem]) {
            var extra: [URLQueryItem] = []
            let filter: String
            switch self {
            case .pending: filter = "queued"
            case .active: filter = "in_flight"
            case .available: filter = "available"
            case .declined: filter = "declined"
            }
            if self == .available || self == .declined {
                extra.append(URLQueryItem(name: "since_days", value: String(RequestBoard.terminalDays)))
            }
            extra += RequestBoard.filterItems(search: search, userId: userId)
            return (filter, extra)
        }
    }

    public static let page = 30
    public static let terminalDays = 7
    public static let maxPages = 5

    static func filterItems(search: String?, userId: Int?) -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let search, !search.isEmpty { items.append(URLQueryItem(name: "q", value: search)) }
        if let userId { items.append(URLQueryItem(name: "user_id", value: String(userId))) }
        return items
    }

    /// The column a request belongs in; withdrawn rows leave the board.
    public static func column(_ r: MediaRequest) -> Column? {
        switch r.status {
        case "pending", "waiting": return .pending
        case "rejected", "deferred": return .declined
        case "fulfilled": return .available
        case "approved": return (r.lifecycle ?? []).contains { $0.step == .downloading } ? .downloading : .approved
        default: return nil
        }
    }

    public static func lastEvent(_ r: MediaRequest) -> String {
        r.thread?.lastEventAt ?? r.requestedAt ?? ""
    }

    public static func withinTerminalWindow(_ r: MediaRequest, now: Date = Date()) -> Bool {
        guard let at = ServerTime.parse(r.thread?.lastEventAt ?? r.requestedAt) else { return false }
        return now.timeIntervalSince(at) <= Double(terminalDays) * 86_400
    }

    /// One row per request across the buckets, newest event first; a fulfilled
    /// row from the in-flight bucket counts only inside the 7-day window.
    public static func merge(_ buckets: [Bucket: [MediaRequest]], now: Date = Date()) -> [MediaRequest] {
        var byId: [Int: MediaRequest] = [:]
        for bucket in Bucket.allCases {
            for r in buckets[bucket] ?? [] {
                if bucket == .active && column(r) == .available && !withinTerminalWindow(r, now: now) { continue }
                if let had = byId[r.id], lastEvent(r) <= lastEvent(had) { continue }
                byId[r.id] = r
            }
        }
        return byId.values.sorted { lastEvent($0) > lastEvent($1) }
    }

    /// Rows per column; quota-waiting rows sort after the pending ones.
    public static func group(_ items: [MediaRequest]) -> [Column: [MediaRequest]] {
        var out: [Column: [MediaRequest]] = [:]
        for r in items { if let c = column(r) { out[c, default: []].append(r) } }
        let pending = out[.pending] ?? []
        out[.pending] = pending.filter { $0.status != "waiting" } + pending.filter { $0.status == "waiting" }
        return out
    }

    /// The Available header: the server's 7-day total corrected for rows whose
    /// stored stamp and derived status disagree.
    public static func availableCount(serverTotal: Int, buckets: [Bucket: [MediaRequest]], availableLoaded: Bool,
                                      activeLoaded: Bool, now: Date = Date()) -> (count: Int, exact: Bool) {
        let available = buckets[.available] ?? []
        let inAvailable = Set(available.map(\.id))
        let notFulfilled = available.filter { column($0) != .available }.count
        let crossIn = (buckets[.active] ?? []).filter {
            !inAvailable.contains($0.id) && column($0) == .available && withinTerminalWindow($0, now: now)
        }.count
        let none = notFulfilled == 0 && crossIn == 0
        return (max(0, serverTotal - notFulfilled + crossIn), none || (availableLoaded && activeLoaded))
    }

    /// "12", or "30+" while the figure is only a bound.
    public static func countLabel(_ count: Int, exact: Bool) -> String { exact ? String(count) : "\(count)+" }

    // MARK: Cards and rows

    /// The most advanced version not yet available (a partly-available request).
    public static func pendingEntry(_ r: MediaRequest, lead: RequestLifecycleEntry?) -> RequestLifecycleEntry? {
        guard lead?.step == .available else { return lead }
        return RequestLifecycle.lead((r.lifecycle ?? []).filter { $0.step != .available })
    }

    public static func pendingTone(_ e: RequestLifecycleEntry?) -> RequestLifecycle.Tone {
        switch e?.step {
        case .unreleased: return .unaired
        case .searching, .downloading: return .grab
        case .approved: return .accent
        default: return .dim
        }
    }

    public static func statusLabel(_ status: String) -> String {
        switch status {
        case "pending": return "Pending"
        case "approved": return "Approved"
        case "rejected": return "Declined"
        case "deferred": return "Not available yet"
        case "waiting": return "Waiting for quota"
        case "withdrawn": return "Withdrawn"
        case "fulfilled": return "Available"
        default: return status.capitalized
        }
    }

    public static func statusTone(_ status: String) -> RequestLifecycle.Tone {
        switch status {
        case "approved": return .grab
        case "rejected": return .danger
        case "deferred": return .attention
        case "fulfilled": return .done
        default: return .dim
        }
    }

    /// A history row's pill: an approved row in flight reads its pending version's step.
    public static func historyPill(_ r: MediaRequest) -> (label: String, tone: RequestLifecycle.Tone) {
        if r.status == "approved", let pending = pendingEntry(r, lead: RequestLifecycle.lead(r.lifecycle ?? [])) {
            let word = RequestLifecycle.stepWord(pending)
            return (word.prefix(1).uppercased() + word.dropFirst(), pendingTone(pending))
        }
        return (statusLabel(r.status), statusTone(r.status))
    }

    /// "2h 05m" from requested to available, or "—".
    public static func timeToAvailable(_ r: MediaRequest) -> String {
        guard let a = ServerTime.parse(r.availableAt), let q = ServerTime.parse(r.requestedAt) else { return "—" }
        let ms = a.timeIntervalSince(q)
        guard ms >= 0 else { return "—" }
        let mins = Int((ms / 60).rounded())
        let h = mins / 60, m = mins % 60
        return h > 0 ? "\(h)h \(m < 10 ? "0" : "")\(m)m" : "\(m)m"
    }

    /// Everyone seen on the board, A→Z (masked people can't be filtered on).
    public static func people(_ items: [MediaRequest]) -> [RequestPerson] {
        var seen: [Int: RequestPerson] = [:]
        for r in items { for p in TriageFacts.people(r) { if let id = p.id, seen[id] == nil { seen[id] = p } } }
        return seen.values.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}

/// The History filter (`RequestsHistory.tsx`).
public enum HistoryFilter: String, CaseIterable, Sendable, Hashable {
    case all, approved, available, declined, auto

    public var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    /// `filter` and extra query for this segment.
    public func query(search: String?) -> (filter: String?, extra: [URLQueryItem]) {
        var extra = RequestBoard.filterItems(search: search, userId: nil)
        switch self {
        case .all: return ("all", extra)
        case .approved:
            extra.append(URLQueryItem(name: "status", value: "approved"))
            return (nil, extra)
        case .available: return ("available", extra)
        case .declined: return ("declined", extra)
        case .auto:
            extra.append(URLQueryItem(name: "decided_via", value: "auto"))
            return (nil, extra)
        }
    }
}
