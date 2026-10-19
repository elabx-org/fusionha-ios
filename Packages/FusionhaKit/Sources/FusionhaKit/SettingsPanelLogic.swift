import Foundation

/// Download clients' decypharr import-rules note (web `ImportRulesNote`).
public enum ImportRulesNote {
    /// The newest "import rules fired" stamp across every client, or nil.
    public static func latest(_ clients: [DownloadClientInfo]) -> String? {
        latest(stamps: clients.map { $0.capabilities?.importRulesSeenAt })
    }

    public static func latest(stamps: [String?]) -> String? {
        stamps.compactMap { stamp -> (String, Date)? in
            guard let stamp, let date = ServerTime.parse(stamp) else { return nil }
            return (stamp, date)
        }
        .max { $0.1 < $1.1 }?.0
    }

    /// The web's `seenAgo`: just now · N min ago · N h ago · 1 day ago · N days ago.
    public static func seenAgo(_ stamp: String?, now: Date = Date()) -> String {
        guard let then = ServerTime.parse(stamp) else { return "" }
        let secs = max(0, Int(now.timeIntervalSince(then).rounded()))
        if secs < 60 { return "just now" }
        let mins = secs / 60
        if mins < 60 { return "\(mins) min ago" }
        let hrs = mins / 60
        if hrs < 24 { return "\(hrs) h ago" }
        let days = hrs / 24
        return days == 1 ? "1 day ago" : "\(days) days ago"
    }
}

extension NamingFormat {
    /// Puts `token` over the selection (character offsets, clamped to the
    /// text) or, with no selection, at the end. Returns the new text and the
    /// caret just after the token.
    public static func insert(_ token: String, into text: String, range: Range<Int>?) -> (text: String, caret: Int) {
        let count = text.count
        guard let range else { return (text + token, count + token.count) }
        let lower = min(max(range.lowerBound, 0), count)
        let upper = min(max(range.upperBound, lower), count)
        let start = text.index(text.startIndex, offsetBy: lower)
        let end = text.index(text.startIndex, offsetBy: upper)
        var out = text
        out.replaceSubrange(start..<end, with: token)
        return (out, lower + token.count)
    }
}
