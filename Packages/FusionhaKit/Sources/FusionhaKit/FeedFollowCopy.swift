import Foundation

/// The site behind a followed source or an import list (web `SourceProvider`,
/// fusionha 0.4.237): its tile and the word in the owner line.
public enum SourceProvider: String, Sendable, Hashable, CaseIterable {
    case letterboxd, plex, mdblist, trakt

    /// A server `provider` (`MDBLIST`, `TRAKT`, `LETTERBOXD`, `PLEX`), any case.
    /// Unknown or nil reads as Letterboxd, like the web's `providerOf`.
    public init(feed raw: String?) {
        self = SourceProvider(rawValue: (raw ?? "").lowercased()) ?? .letterboxd
    }

    /// "MDBList", "Trakt", "Letterboxd", "Plex" (web `PROVIDER_WORD`).
    public var word: String {
        switch self {
        case .letterboxd: return "Letterboxd"
        case .plex: return "Plex"
        case .mdblist: return "MDBList"
        case .trakt: return "Trakt"
        }
    }
}

/// "Follow a list" by address (web `feed-copy.ts`, phase 10b slice 2): any
/// public MDBList, Trakt or Letterboxd list.
public enum FeedCopy {
    public static let label = "List address"
    public static let placeholder = "Paste a public list address"
    public static let worksWith = "Works with"
    public static let plexLater = "Plex · coming later"
    /// Typed a Plex list address (web `PLEX_LATER`).
    public static let plexLaterHint = "Plex lists from other people are coming later."
    public static let preview = "Preview"
    public static let reading = "Reading…"
    public static let recognised = "Recognised"
    public static let titles = "titles"
    public static let movies = "movies"
    public static let series = "series"
    public static let inLibrary = "already in your library"
    public static let sample = "Showing a sample of 25. fusionha reads the full list once you follow it."
    public static let versions = "Versions"
    public static let hd = "HD·1080p"
    public static let hdAlways = "always"
    public static let uhd = "UHD·4K"
    public static let uhdSwitch = "Also request UHD·4K"
    public static let uhdYes = "Each tier is its own request. You can request 4K."
    public static let uhdNo = "Your account can request HD·1080p only."
    public static let lbVersions = "Letterboxd lists use your diary’s UHD·4K setting."
    public static let now = "What’s on it now"
    public static let newOnly = "Only new additions"
    public static let existing = "Also request what’s already on it"
    public static let normalLead = "Requests go your normal way:"
    public static let normalRest = "your weekly quota, approval rules and joins. Titles already in the library are never requested."
    public static let imdbTip = "Tip: MDBList can import an IMDb list; paste its MDBList address instead."
    public static let traktOff = "Trakt isn’t set up on this server yet. Ask an admin to add a Trakt app id."
    public static let unreadable = "Couldn’t read that list. Check the address, and that the list is public."
    public static let notAllowed = "An admin hasn’t allowed you to follow lists."
    public static let watchInstead = "Someone’s Letterboxd watchlist instead"
    public static let addressInstead = "Paste a list address instead"
    /// The web's `LS.previewMdb`, added to a blocked Letterboxd preview.
    public static let previewMdb = "or use an MDBList list instead"
    /// The detail's own switch for a followed feed (web `DETAIL.autoFeed`).
    public static let autoFeed = "Auto-request from this list"

    /// "public list", "watchlist", "collection".
    public static func kindWord(_ kind: String?) -> String {
        switch kind {
        case "watchlist": return "watchlist"
        case "collection": return "collection"
        default: return "public list"
        }
    }

    public static func by(_ owner: String) -> String { "by @\(owner)" }
    public static func openOn(_ site: String) -> String { "Open on \(site)" }
    public static func mixLabel(_ m: Int, _ s: Int) -> String { "\(m) movies, \(s) series" }

    public static func newOnlyDesc(_ n: Int?) -> String {
        guard let n, n > 0 else { return "What’s on it now is noted and left alone." }
        return "The \(n) titles on it now are noted and left alone."
    }

    public static func existingDesc(_ n: Int?) -> String {
        guard let n, n > 0 else { return "A few at a time, within your weekly limit." }
        return "\(n) titles, a few at a time within your weekly limit."
    }

    public static func unsupported(_ host: String?) -> String {
        "fusionha can’t follow \(host.map { "lists from \($0)" } ?? "that address"). Paste a public list from MDBList, Trakt or Letterboxd."
    }

    public static func siteDown(_ site: String) -> String { "\(site) didn’t answer. Try again in a few minutes." }
}

/// The address box's rules and its refusals (web `feed-errors.ts`,
/// `plex-address.ts`, `FeedFollowPanel`).
public enum FeedFollowLogic {
    /// Something with a dot and no spaces: worth a preview.
    public static func looksLikeAddress(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !t.contains(where: \.isWhitespace) else { return false }
        guard let dot = t.firstIndex(of: "."), dot != t.startIndex else { return false }
        return t.index(after: dot) < t.endIndex
    }

    /// `watch.plex.tv` / `app.plex.tv`: not followable yet, never sent.
    public static func isPlexAddress(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return false }
        let full = t.range(of: "^[a-z]+://", options: [.regularExpression, .caseInsensitive]) == nil ? "https://\(t)" : t
        guard let host = URL(string: full)?.host?.lowercased() else { return false }
        return host == "watch.plex.tv" || host == "app.plex.tv"
    }

    /// The site a typed address points at, before any preview (messages only).
    public static func guessProvider(_ url: String) -> SourceProvider {
        let u = url.lowercased()
        if u.contains("mdblist.com") { return .mdblist }
        if u.contains("trakt.tv") { return .trakt }
        return .letterboxd
    }

    /// Ready for Preview: an address that isn't a Plex one.
    public static func ready(_ text: String) -> Bool { looksLikeAddress(text) && !isPlexAddress(text) }

    /// A refused preview or follow as the sheet's sentence (never the server
    /// prose) and, for an IMDb address, the MDBList tip.
    public static func message(for error: Error, guess: SourceProvider) -> (text: String, tip: String?) {
        let api = error as? APIError
        let detail = api?.detailObject ?? [:]
        switch api?.code {
        case "unsupported_site":
            let host = detail["host"] as? String
            return (FeedCopy.unsupported(host), host?.contains("imdb") == true ? FeedCopy.imdbTip : nil)
        case "coming_later": return (FeedCopy.plexLaterHint, nil)
        case "provider_unavailable": return (FeedCopy.traktOff, nil)
        case "source_unreadable": return (FeedCopy.unreadable, nil)
        case "not_allowed": return (FeedCopy.notAllowed, nil)
        case "unavailable":
            let site = SourceProvider(rawValue: ((detail["provider"] as? String) ?? guess.rawValue).lowercased())
            let word = site.flatMap { [.mdblist, .trakt].contains($0) ? $0.word : nil } ?? "The list site"
            return (FeedCopy.siteDown(word), nil)
        default:
            return (WatchlistErrorCopy.letterboxdMessage(for: error), nil)
        }
    }

    /// A refused someone's-watchlist preview: a block points at MDBList (web `AddSourcePanel`).
    public static func watchlistMessage(for error: Error) -> String {
        let text = WatchlistErrorCopy.letterboxdMessage(for: error, watchlist: true)
        guard (error as? APIError)?.code == "blocked", text.hasSuffix(".") else { return text }
        return "\(text.dropLast()), \(FeedCopy.previewMdb)."
    }
}

extension APIError {
    /// The `detail` object of a coded refusal (`{"detail": {...}}`), else nil.
    public var detailObject: [String: Any]? {
        guard case .http(_, let body) = self,
              let object = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any] else { return nil }
        return object["detail"] as? [String: Any]
    }
}
