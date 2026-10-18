import Foundation

// Where a request came from, in words (fusionha 0.4.209 Plex watchlist & lists,
// 0.4.213 Letterboxd; the web's `labels.ts` `sourcePhrase` and
// `source-words.ts`). Labels and owners come from the server's
// privacy-filtered projection only: a joiner gets the kind alone.

public enum RequestSourceWords {
    public static let plexKinds: Set<String> = ["PLEX_WATCHLIST", "PLEX_LIST"]
    public static let letterboxdKinds: Set<String> = ["LETTERBOXD_RSS", "LETTERBOXD_WATCHLIST", "LETTERBOXD_LIST", "LETTERBOXD_CSV"]

    /// The kinds a person never asked for by hand (the "From source" filter,
    /// the withdrawn wording, "Request again").
    public static func isAutomatic(_ kind: String?) -> Bool {
        guard let kind else { return false }
        return plexKinds.contains(kind) || letterboxdKinds.contains(kind)
    }

    /// The web's `SOURCE_LABEL`; unknown kinds read as their raw name.
    public static let labels: [String: String] = [
        "MANUAL": "fusionha", "PLEX_WATCHLIST": "Plex watchlist", "PLEX_LIST": "Plex list", "LIST_FEED": "List",
        "LETTERBOXD_LIST": "Letterboxd list", "LETTERBOXD_RSS": "Letterboxd diary",
        "LETTERBOXD_CSV": "Letterboxd watchlist", "LETTERBOXD_WATCHLIST": "Letterboxd watchlist",
    ]

    /// The badge phrase: "From your Plex list · Kids movies" to its owner,
    /// "Plex list · Kids movies" to an approver, "Requested in fusionha" for a
    /// manual request.
    public static func phrase(_ source: RequestSource?, mine: Bool) -> String {
        guard let source, source.kind != "MANUAL" else { return "Requested in fusionha" }
        if let lb = letterboxdPhrase(source, mine: mine) { return lb }
        let base = labels[source.kind] ?? source.kind
        let text = source.label.map { "\(base) · \($0)" } ?? base
        return mine && plexKinds.contains(source.kind) ? "From your \(text)" : text
    }

    static func letterboxdPhrase(_ s: RequestSource, mine: Bool) -> String? {
        switch s.kind {
        case "LETTERBOXD_RSS":
            return mine ? "From your Letterboxd diary" : "Letterboxd diary"
        case "LETTERBOXD_CSV":
            return mine ? "From your Letterboxd watchlist" : "Letterboxd watchlist"
        case "LETTERBOXD_WATCHLIST":
            if let owner = s.owner { return "\(mine ? "From " : "")@\(owner)’s Letterboxd watchlist" }
            return mine ? "From your Letterboxd watchlist" : "Letterboxd watchlist"
        case "LETTERBOXD_LIST":
            let base = s.label.map { "Letterboxd list · \($0)" } ?? "Letterboxd list"
            return mine ? "From \(base)" : base
        default:
            return nil
        }
    }

    /// "It stays on {where} but won’t be requested again on its own."
    public static func withdrawnWhere(_ s: RequestSource?) -> String {
        switch s?.kind {
        case "PLEX_LIST": return "your Plex list"
        case "PLEX_WATCHLIST": return "your Plex watchlist"
        case "LETTERBOXD_RSS": return "your Letterboxd diary"
        case "LETTERBOXD_LIST": return "that Letterboxd list"
        case "LETTERBOXD_WATCHLIST": return s?.owner != nil ? "that watchlist" : "your Letterboxd watchlist"
        case "LETTERBOXD_CSV": return "your Letterboxd watchlist"
        default: return "that source"
        }
    }

    /// The withdraw button's label for an automatic source.
    public static func withdrawLabel(_ s: RequestSource?) -> String {
        let where_: String?
        switch s?.kind {
        case "PLEX_LIST", "LETTERBOXD_LIST": where_ = "this list"
        case "PLEX_WATCHLIST": where_ = "your watchlist"
        case "LETTERBOXD_RSS": where_ = "your Letterboxd diary"
        case "LETTERBOXD_WATCHLIST": where_ = s?.owner != nil ? "that watchlist" : "your watchlist"
        default: where_ = nil
        }
        return where_.map { "Withdraw request. It won’t be requested again from \($0)." } ?? "Withdraw request"
    }

    /// The toast after a withdraw.
    public static func withdrawnToast(_ s: RequestSource?) -> String {
        let kind = s?.kind ?? ""
        if plexKinds.contains(kind) { return "Request withdrawn. It stays on Plex and won’t be requested again." }
        if letterboxdKinds.contains(kind) { return "Request withdrawn. It stays on Letterboxd and won’t be requested again." }
        return "Request withdrawn"
    }

    /// The toast after "Request again", by the new row's status.
    public static func againToast(status: String?) -> String {
        switch status {
        case "pending": return "Requested again. It will wait for an approver."
        case "waiting": return "Requested again. It waits for your weekly limit."
        default: return "Requested again."
        }
    }

    /// The card offers "Request again" on the viewer's own withdrawn automatic request.
    public static func canRequestAgain(_ r: MediaRequest, viewerId: Int?) -> Bool {
        r.status == "withdrawn" && isAutomatic(r.source?.kind) && viewerId != nil && r.userId == viewerId
    }
}

/// `POST /api/v1/requests` for "Request again" (`again_of`): a manual
/// re-request of the caller's own withdrawn automatic request that keeps its
/// source badge, going through the normal quota and rules.
public struct RequestAgainBody: Encodable, Sendable {
    public let tmdbId: Int
    public let kind: MediaKind
    public let editions: [QualityTier]
    public let seasons: [Int]
    public let episodes: [EpisodeRef]
    public let againOf: Int

    public init(_ r: MediaRequest) {
        tmdbId = r.tmdbId
        kind = r.kind
        editions = r.tiers
        seasons = r.seasons ?? []
        episodes = r.episodes ?? []
        againOf = r.id
    }
}

extension APIClient {
    /// "Request again" (409 `quota`, 409 `not_withdrawn`, 404 `not_found`).
    @discardableResult
    public func requestAgain(_ r: MediaRequest) async throws -> MediaRequest? {
        let reply: Lenient<MediaRequest> = try await send("POST", "/api/v1/requests", body: RequestAgainBody(r))
        return reply.value
    }
}
