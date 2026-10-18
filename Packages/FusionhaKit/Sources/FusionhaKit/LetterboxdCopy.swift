import Foundation

/// The colour family of a Letterboxd status (the app maps it to `Theme`).
public enum LbTone: Sendable {
    case done, miss, stuck, grab, dim
}

/// The Letterboxd card's rules (web `letterboxd-state.ts`, `letterboxd-copy.ts`).
public enum LetterboxdLogic {
    public enum Connection: Sendable { case none, ok, bad }

    public static func connection(_ read: LetterboxdRead) -> Connection {
        guard read.username != nil else { return .none }
        return read.profileError == nil ? .ok : .bad
    }

    /// The card shows for anyone who can request (the one-time import needs
    /// only `request`), so not for a user who lost the capability.
    public static func visible(_ read: LetterboxdRead) -> Bool { read.reason != "ineligible" }

    /// Automatic sources need the `can_link_lists` grant.
    public static func allowed(_ read: LetterboxdRead) -> Bool {
        read.reason != "not_granted" && read.canLinkLists
    }

    /// `^[A-Za-z0-9_]{2,15}$`, checked before anything is sent.
    public static func validUsername(_ text: String) -> Bool {
        text.range(of: "^[A-Za-z0-9_]{2,15}$", options: .regularExpression) != nil
    }

    /// Enables Preview; the server decides what is valid.
    public static func looksLikeListURL(_ text: String) -> Bool {
        text.range(of: "letterboxd\\.com/[^/]+/list/[^/]+", options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// A source status → its pill (the mock's `ST`); unknown reads as Checking.
    public static func status(_ status: String?) -> (label: String, tone: LbTone) {
        switch status ?? "" {
        case "OK": return ("Healthy", .done)
        case "DEGRADED": return ("Partly working", .miss)
        case "BLOCKED": return ("Blocked by Letterboxd", .stuck)
        case "PRIVATE": return ("Not public", .miss)
        case "ERROR": return ("Retrying", .stuck)
        case "INELIGIBLE": return ("Not allowed", .dim)
        default: return ("Checking", .grab)
        }
    }

    /// "Checked about every N hours": the gap between the last and next check.
    public static func scheduleHours(last: String?, next: String?) -> Int? {
        guard let a = ServerTime.parse(last), let b = ServerTime.parse(next) else { return nil }
        let hours = b.timeIntervalSince(a) / 3600
        guard hours >= 1, hours <= 170 else { return nil }
        return Int(hours.rounded())
    }

    public static func diaryHint(hours: Int?) -> String {
        let lead = hours.map { "Checked about every \($0) hours." } ?? "Checked on a schedule."
        return "\(lead) Films already in your library or already requested are skipped."
    }

    /// The profile's can't-read sentence (lead, rest), plus "Checks are paused…".
    public static func profileProblem(_ read: LetterboxdRead) -> (lead: String, rest: String) {
        let user = read.username ?? ""
        switch read.profileError {
        case "profile_not_found":
            return ("Letterboxd has no profile called @\(user).", "Check the spelling of the name in your profile address.")
        case "profile_private":
            return ("@\(user)’s profile isn’t public.", "fusionha only reads public pages. Make your diary visible on Letterboxd, then try again.")
        default:
            return ("Letterboxd didn’t answer.", "Try again in a few minutes.")
        }
    }

    /// Linked sources count: the larger of the server's and the listed rows.
    public static func linkedCount(_ read: LetterboxdRead, sources: [LbSource]) -> Int {
        max(read.linkedCount, sources.filter(\.isLinked).count)
    }

    public static func linkedOf(_ n: Int, max: Int) -> String { "\(n) of \(max) linked" }

    /// Hours until a blocked source retries (6 without a time).
    public static func hoursUntil(_ iso: String?, now: Date = Date()) -> Int {
        guard let date = ServerTime.parse(iso) else { return 6 }
        return Swift.max(1, Int((date.timeIntervalSince(now) / 3600).rounded()))
    }

    public static func blockedLine(hours: Int) -> String {
        "Letterboxd is blocking fusionha right now. It retries on its own in about \(hours) hours. Nothing already requested is affected."
    }

    public static func syncDone(_ n: Int) -> String {
        "Checked your diary, watchlist and sources · \(n) new film\(n == 1 ? "" : "s") requested"
    }

    public static func checkAgain(_ seconds: Int) -> String {
        "You can check again in \(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }

    public static func addedToast(_ n: Int, max: Int) -> String {
        "Added · \(n) of \(max) linked. First check is running."
    }

    /// The import's done line (web `ADV.done`).
    public static func importDone(_ r: CsvCommitResult, have: Int) -> String {
        "\(r.requested) requested now, \(r.wishlisted) added to your wishlist, \(have) already in the library, \(r.skipped) skipped (no match). Wishlisted films are requested oldest first as your weekly limit allows."
    }

    public static func importWishHint(_ n: Int) -> String {
        "The other \(n) go to your wishlist and are requested oldest first as your weekly limit allows. Films someone has already asked for are joined, never duplicated."
    }
}
