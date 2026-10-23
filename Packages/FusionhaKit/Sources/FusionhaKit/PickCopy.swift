import Foundation

/// "Pick the right title" (web `pick-copy.ts`, `use-pick.ts`, fusionha
/// 0.4.226): the unmatched review's sentences and how each refusal reads.
public enum PickCopy {
    public static let title = "Pick the right title"
    public static let request = "Request it"
    public static let ignore = "Ignore this title"
    public static let searchLabel = "Search TMDB"
    public static let kindLabel = "Kind"
    public static let why = "Why it wasn’t matched:"
    public static let noResults = "No titles found. Try a different search."
    public static let searching = "Searching…"
    public static let searchFailed = "Search didn’t work. Try again in a moment."
    public static let loading = "Loading…"
    public static let rememberRest = "so nobody has to pick it again."
    public static let handled = "This title was already handled."
    public static let failed = "That didn’t work. Try again in a moment."
    public static let queued = "Saved. fusionha will request it at the next check."
    public static let ignored = "Ignored on this source. Use Discover’s ignore to hide it everywhere."
    public static let notAllowed = "Your account can’t request from this source any more. Ask an admin to allow it."

    /// "1 title from My watchlist (Letterboxd) couldn’t be matched. Choose what it is, or ignore it."
    public static func intro(_ n: Int, source: String, provider: String) -> String {
        "\(n) \(n == 1 ? "title" : "titles") from \(source) (\(provider)) couldn’t be matched. Choose what it is, or ignore it."
    }

    /// "From your Letterboxd watchlist" / "From Best of 2026".
    public static func from(provider: String, source: String) -> String {
        source.hasPrefix("My ") ? "From your \(provider) \(source.dropFirst(3).lowercased())" : "From \(source)"
    }

    public static func position(_ n: Int, of total: Int) -> String { "\(n) of \(total)" }

    public static func remember(provider: String) -> String {
        "fusionha remembers your choice for this \(provider) \(provider == "Plex" ? "title" : "film"), for everyone on this server,"
    }

    public static func normalPath(tiers: String) -> String {
        "Requested like any watchlist title: your quota, approval rules and tiers (this source asks for \(tiers)). If someone already asked, you join their request."
    }

    /// The toast after a resolve (web `PICK.done`).
    public static func done(_ outcome: String, title: String) -> String {
        switch outcome {
        case "JOINED": return "Joined the request for \(title)"
        case "OWNED": return "Already in your library"
        case "WAITING": return "Waiting for quota room: \(title)"
        case "SKIPPED_POLICY": return "Not requested: \(title) isn’t allowed by your request rules."
        case "REQUESTED": return "Requested \(title) · remembered for everyone"
        default: return "Saved your choice for \(title)."
        }
    }

    // MARK: Why it wasn't matched

    private static let ordinals = ["second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth"]

    /// The film-address slug ending `-N`, or nil.
    public static func slug(_ url: String?) -> String? {
        let last = (url ?? "").split(separator: "?").first.map(String.init)?
            .split(separator: "/").last.map(String.init) ?? ""
        guard let dash = last.lastIndex(of: "-"), !last[last.index(after: dash)...].isEmpty,
              last[last.index(after: dash)...].allSatisfy(\.isNumber) else { return nil }
        return last
    }

    /// The sentence after "Why it wasn’t matched:", with the slug kept apart
    /// so it can be set in code.
    public static func whySentence(_ item: UnmatchedItem, provider: String) -> (before: String, slug: String?, after: String) {
        let guess = " fusionha didn’t guess."
        switch item.reason {
        case "ambiguous":
            return ("More than one title fits, so fusionha didn’t guess.", nil, "")
        case "no_tmdb_link":
            let head = "\(provider)’s page for this film has no TMDB link"
            guard let slug = slug(item.sourceUrl) else { return ("\(head).\(guess)", nil, "") }
            return ("\(head), and its address (", slug, ") is \(provider)’s \(filmCalled(slug, item)), so more than one title fits.\(guess)")
        default:
            return ("\(provider) gave no id fusionha could match.\(guess)", nil, "")
        }
    }

    private static func filmCalled(_ slug: String, _ item: UnmatchedItem) -> String {
        let n = Int(slug.split(separator: "-").last ?? "") ?? 0
        guard n >= 1, n <= ordinals.count, !item.title.isEmpty else { return "second film with that name" }
        return "\(ordinals[n - 1]) film called “\(item.title)”\(item.year.map { " from \($0)" } ?? "")"
    }

    // MARK: Refusals

    /// How a refused Request it / Ignore reads. `inline` notes stay in the
    /// sheet (Ignore is still offered); the rest are toasts.
    public enum Refusal: Equatable, Sendable {
        /// 409 `source_paused`, `reason: paused`.
        case paused
        /// 409 `source_paused`, `reason: off` (or a deleted source).
        case off
        /// 409 `needs_sign_in`.
        case signIn
        /// 409 `not_unmatched`: someone (or a check) already handled it.
        case handled
        /// 403 `not_allowed`: the grant for this kind of source is gone.
        case notAllowed
        case failed

        public init(_ error: Error) {
            let api = error as? APIError
            switch api?.code {
            case "source_paused": self = api?.detailField("reason") == "paused" ? .paused : .off
            case "needs_sign_in": self = .signIn
            case "not_unmatched": self = .handled
            case "not_allowed": self = .notAllowed
            default: self = .failed
            }
        }

        /// Kept in the sheet under the search (web `PICK.blocked`).
        public var inline: String? {
            switch self {
            case .paused: return "Resume this source to request it."
            case .off: return "Turn this source on to request it."
            case .signIn: return "Sign in with Plex again to request it."
            case .notAllowed: return PickCopy.notAllowed
            case .handled, .failed: return nil
            }
        }

        public var toast: String {
            switch self {
            case .handled: return PickCopy.handled
            default: return inline ?? PickCopy.failed
            }
        }
    }
}

extension APIError {
    /// A string field of a coded refusal's `detail` (`reason`, …).
    public func detailField(_ key: String) -> String? {
        guard case .http(_, let body) = self,
              let object = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any],
              let detail = object["detail"] as? [String: Any] else { return nil }
        return detail[key] as? String
    }
}
