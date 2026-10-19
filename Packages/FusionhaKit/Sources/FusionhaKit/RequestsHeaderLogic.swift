import Foundation

// The Requests header row's words (web `nav/filters.ts`, `mine-header.ts`,
// `threads-unread.ts`, `RequestsIssues.tsx`, `RequestsInsightsView.tsx`).

/// The filter sheet's button: "Show 9 requests". An unknown total falls back
/// to the loaded rows ("50+ requests" while more pages exist); a view with no
/// figure at all reads "Done".
public enum RequestsResultLabel {
    public static let fallback = "Done"

    public static func text(_ n: Int?, loaded: Int, more: Bool, noun: (one: String, many: String)) -> String {
        let count = n ?? loaded
        let open = n == nil && more
        let shown = open ? "\(count)+" : String(count)
        return "Show \(shown) \(open ? noun.many : (count == 1 ? noun.one : noun.many))"
    }
}

/// Mine and My requests' subtitle (web `mine-header.ts`).
public enum MineHeader {
    public enum Subtitle: Sendable, Equatable {
        /// "Issues you reported".
        case issues
        /// "Nothing open".
        case nothingOpen
        /// "3 open · 6 available".
        case counts(open: Int, available: Int)

        public var text: String {
            switch self {
            case .issues: return "Issues you reported"
            case .nothingOpen: return "Nothing open"
            case .counts(let open, let available): return "\(open) open · \(available) available"
            }
        }
    }

    /// Open requests: pending, waiting, and approved but not yet available
    /// (the server's `active` also counts declined and deferred).
    public static func openCount(_ c: RequestCounts?) -> Int? {
        c.map { max(0, $0.active - $0.declined) }
    }

    /// Nil until the counts arrive (Issues needs none).
    public static func subtitle(_ c: RequestCounts?, issues: Bool) -> Subtitle? {
        if issues { return .issues }
        guard let c, let open = openCount(c) else { return nil }
        return open == 0 ? .nothingOpen : .counts(open: open, available: c.available)
    }
}

/// History's figures from `GET /requests/counts` (web `historyCount`).
public enum RequestHistoryCount {
    /// The row total for a status; nil when the server has no figure for it (Auto).
    public static func count(_ c: RequestCounts?, status: HistoryFilter) -> Int? {
        guard let c else { return nil }
        let decided = c.all - c.inbox - c.waiting
        switch status {
        case .all: return decided
        case .available: return c.available
        case .declined: return c.declined
        case .approved: return decided - c.declined
        case .auto: return nil
        }
    }

    /// "N decided this month": the server counts whole days, so the window is
    /// the local day of the month (today back N days).
    public static func monthWindow(now: Date = Date(), calendar: Calendar = .current) -> Int {
        calendar.component(.day, from: now)
    }
}

/// A History row's coloured status word (web `history-status.ts`): a word,
/// never a pill. An approved row reads its in-flight step only while that
/// version is searching, downloading or unreleased.
public enum RequestHistoryStatus {
    public enum Tone: Sendable, Equatable {
        case accent, done, danger
        case step(RequestLifecycle.Tone)
        case quiet(RequestLifecycle.Tone)
    }

    public static func word(_ r: MediaRequest) -> (label: String, tone: Tone) {
        switch r.status {
        case "rejected": return ("Declined", .danger)
        case "fulfilled": return ("Available", .done)
        case "approved":
            let pending = RequestBoard.pendingEntry(r, lead: RequestLifecycle.lead(r.lifecycle ?? []))
            if let pending, [.searching, .downloading, .unreleased].contains(pending.step) {
                let word = RequestLifecycle.stepWord(pending)
                return (word.prefix(1).uppercased() + word.dropFirst(), .step(RequestBoard.pendingTone(pending)))
            }
            return (r.approvedBy?.kind == "auto" ? "Auto-approved" : "Approved", .accent)
        default:
            return (RequestBoard.statusLabel(r.status), .quiet(quietTone(r.status)))
        }
    }

    /// The web's `STATUS_COLOR` for the remaining statuses.
    static func quietTone(_ status: String) -> RequestLifecycle.Tone {
        switch status {
        case "approved": return .grab
        case "rejected": return .danger
        case "deferred": return .attention
        case "fulfilled": return .done
        default: return .dim
        }
    }
}

/// Open threads with something unread (web `useUnreadThreadCount`).
public enum ThreadUnread {
    public static func count(_ items: [ThreadItem]) -> Int { items.filter(ThreadMeta.hasUnread).count }

    /// The drawer's figure: "4", or "4+" while more open threads exist; nil at 0.
    public static func label(_ count: Int, more: Bool) -> String? {
        count > 0 ? "\(count)\(more ? "+" : "")" : nil
    }
}

/// The Issues view's problem filter: a client-side narrowing of the loaded threads.
public enum IssueProblemFilter {
    public static func matches(_ item: ThreadItem, problem: String) -> Bool {
        problem == "all" || (item.issue?.reports ?? []).contains { $0.problem == problem }
    }

    /// The chip and option word for a problem ("Won’t play").
    public static func label(_ problem: String) -> String { IssueFormat.problemLabel(problem) }
}

/// Insights' Range (4 · 12 · 26 weeks; 12 is the default and shows no chip).
public enum InsightsRange {
    public static let options = [4, 12, 26]
    public static let standard = 12

    public static func label(_ weeks: Int) -> String { "Last \(weeks) weeks" }
}

extension RequestSourceFilter {
    /// The chip a set source shows: the provider, or the one source picked.
    public var chipLabel: String {
        guard let sub else { return provider.title }
        return Self.subLabel(RequestSourceCount(kind: sub.kind, label: sub.label, sourceId: sub.sourceId, count: 0))
    }
}
