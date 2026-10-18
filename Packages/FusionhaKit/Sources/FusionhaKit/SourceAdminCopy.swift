import Foundation

/// The words of the admin source status (the web's `watchlist-chip-meta.ts`,
/// `letterboxd-chip-meta.ts`, `letterboxd-copy.ts` `ST` and
/// `watchlist-copy.ts` `VISIBILITY_LABEL`). Tones name the app's status
/// colours; the app maps them.
public enum SourceAdminCopy {
    public enum Tone: Sendable, Hashable { case done, grab, stuck, miss, dim, i1, danger, unaired, unmonitored }

    // MARK: Plex

    /// The Users-list chip for a Plex summary state, and whether it opens the status.
    public static func plexChip(_ state: String) -> (label: String, tone: Tone, opens: Bool) {
        switch state {
        case "healthy": return ("Healthy", .done, true)
        case "checking": return ("Checking", .grab, true)
        case "needs_sign_in": return ("Needs sign-in", .stuck, true)
        case "token_invalid": return ("Sign-in expired", .stuck, true)
        case "error": return ("Retrying", .stuck, true)
        case "paused": return ("Paused by admin", .dim, true)
        case "allowed_off": return ("Allowed · off", .dim, true)
        case "plex_only": return ("Plex users only", .dim, false)
        default: return ("Not allowed", .dim, false)
        }
    }

    /// "Healthy · 3 sources".
    public static func plexChipLabel(_ row: PlexWatchlistSummaryRow) -> String {
        let base = plexChip(row.state).label
        return row.state == "healthy" && row.sourceCount > 1 ? "\(base) · \(row.sourceCount) sources" : base
    }

    /// The status sheet's one-line description.
    public static func plexDescription(_ state: String) -> String {
        if state == "plex_only" { return "Password-only account. The watchlist is for Plex sign-in users." }
        if !plexChip(state).opens { return "The watchlist grant is not on for this user, so there is no watchlist source." }
        return "What the watchlist source has done for this user. Read-only: they control on/off and Sync now themselves."
    }

    /// "Sign-in expired" / "Not connected yet" / "Retrying", or nil when nothing is failing.
    public static func plexErrorTitle(_ read: PlexWatchlistAdmin) -> String? {
        let failing = (read.consecutiveFailures ?? 0) > 0 || read.reason == "token_invalid" || read.reason == "needs_sign_in"
        guard failing else { return nil }
        switch read.reason {
        case "token_invalid": return "Sign-in expired"
        case "needs_sign_in": return "Not connected yet"
        default: return "Retrying"
        }
    }

    /// "Next check" when it isn't a time: paused or waiting for sign-in.
    public static func plexNextCheckWord(_ read: PlexWatchlistAdmin) -> String? {
        if read.paused == true || read.reason == "token_invalid" || read.reason == "disabled" { return "paused" }
        if read.reason == "needs_sign_in" { return "waiting for sign-in" }
        return nil
    }

    public static func visibility(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let labels = ["PUBLIC": "Public", "PLEX_USERS": "Anyone signed into Plex", "FRIENDS_OF_FRIENDS": "Friends of Friends",
                      "FRIENDS": "Friends only", "PRIVATE": "Private"]
        return labels[raw] ?? raw
    }

    // MARK: Outcomes

    public static let outcomeOrder = ["REQUESTED", "JOINED", "WAITING", "OWNED", "BASELINE", "SKIPPED_POLICY",
                                      "UNMATCHED", "WITHDRAWN", "DECLINED", "WISHLISTED"]

    public static func outcomeLabel(_ key: String) -> String {
        let labels = ["REQUESTED": "Requested", "JOINED": "Joined", "WAITING": "Waiting", "OWNED": "Already owned",
                      "BASELINE": "Left alone (baseline)", "SKIPPED_POLICY": "Skipped by policy", "UNMATCHED": "No match",
                      "WITHDRAWN": "Withdrawn", "DECLINED": "Declined", "RETRY": "Retrying", "WISHLISTED": "Wishlisted"]
        return labels[key] ?? key
    }

    public static func outcomeTone(_ key: String) -> Tone {
        switch key {
        case "REQUESTED": return .done
        case "JOINED": return .i1
        case "WAITING": return .miss
        case "OWNED": return .unaired
        case "SKIPPED_POLICY", "DECLINED": return .stuck
        case "UNMATCHED": return .danger
        case "WITHDRAWN": return .unmonitored
        case "RETRY": return .grab
        default: return .dim
        }
    }

    /// The non-zero outcomes in display order.
    public static func outcomeRows(_ o: SourceOutcomes?) -> [(key: String, count: Int)] {
        guard let o else { return [] }
        return outcomeOrder.map { (key: $0, count: o[$0]) }.filter { $0.count > 0 }
    }

    // MARK: Letterboxd

    public static func letterboxdTone(_ state: String) -> Tone {
        switch state {
        case "healthy": return .done
        case "attention", "cant_read": return .stuck
        default: return .dim
        }
    }

    /// Opens the status sheet (a person with something connected).
    public static func letterboxdOpens(_ state: String) -> Bool {
        state == "healthy" || state == "attention" || state == "cant_read"
    }

    public static func letterboxdChipLabel(_ row: LetterboxdSummaryRow) -> String {
        switch row.state {
        case "healthy": return row.diaryEnabled ? "Healthy · diary" : "Healthy"
        case "attention":
            return row.blockedCount > 0 ? "Needs attention · \(row.blockedCount) blocked" : "Needs attention · \(row.degradedCount) partly working"
        case "cant_read": return "Can’t read profile"
        case "not_allowed": return "Not allowed"
        default: return "Not connected"
        }
    }

    /// The status sheet's overall pill.
    public static func letterboxdOverall(_ row: LetterboxdSummaryRow) -> String {
        guard row.state == "attention" else { return row.state == "healthy" ? "Healthy" : letterboxdChipLabel(row) }
        let parts = [row.blockedCount > 0 ? "\(row.blockedCount) blocked" : nil,
                     row.degradedCount > 0 ? "\(row.degradedCount) partly working" : nil].compactMap { $0 }
        return parts.isEmpty ? "Needs attention" : parts.joined(separator: " · ")
    }

    /// A source's status: label and tone.
    public static func letterboxdStatus(_ status: String?) -> (label: String, tone: Tone) {
        switch status {
        case "OK": return ("Healthy", .done)
        case "DEGRADED": return ("Partly working", .miss)
        case "BLOCKED": return ("Blocked by Letterboxd", .stuck)
        case "PRIVATE": return ("Not public", .miss)
        case "ERROR": return ("Retrying", .stuck)
        case "INELIGIBLE": return ("Not allowed", .dim)
        default: return ("Checking", .grab)
        }
    }

    /// "Diary", "My watchlist", "@critic · watchlist", "@critic · Best of 2026".
    public static func letterboxdSourceName(_ s: LetterboxdAdmin.Source) -> String {
        if s.kind == "LETTERBOXD_RSS" { return "Diary" }
        if s.kind == "LETTERBOXD_CSV" || (s.kind == "LETTERBOXD_WATCHLIST" && s.isSelf == true) { return "My watchlist" }
        if s.kind == "LETTERBOXD_WATCHLIST" { return "@\(s.owner ?? "someone") · watchlist" }
        if let owner = s.owner { return "@\(owner) · \(s.label ?? "list")" }
        return s.label ?? "List"
    }

    public static func letterboxdKindWord(_ kind: String) -> String {
        ["LETTERBOXD_RSS": "RSS", "LETTERBOXD_CSV": "CSV import", "LETTERBOXD_LIST": "LIST", "LETTERBOXD_WATCHLIST": "WATCHLIST"][kind] ?? kind
    }

    public static func profileErrorText(_ code: String?, username: String) -> String {
        switch code {
        case "profile_not_found": return "Letterboxd has no profile called @\(username). Checks are paused until they change the username."
        case "profile_private": return "@\(username)’s profile is private. Checks are paused until it is public again."
        default: return "Letterboxd didn’t answer. It retries on its own."
        }
    }

    public static func solverLine(configured: Bool) -> String {
        configured ? "FlareSolverr is configured, so the next retry goes through it."
            : "No FlareSolverr is configured (Settings → Indexers), so it retries on its own backoff."
    }
}
