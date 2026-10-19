import Foundation

/// One title's demand for the viewer (`GET /requests/demand`): counts only,
/// never names. `state` is request · me_too · joined · mine · watch · in_library.
public struct RequestTitleDemand: Decodable, Sendable, Hashable {
    public let tmdbId: Int
    public let state: String
    public let asked: Int
    public let joinableTiers: [QualityTier]
    public let requestId: Int?
    public let watchTiers: [QualityTier]
    public let watching: Bool
    public let requestableTiers: [QualityTier]
    public let libraryTiers: [QualityTier]

    public init(tmdbId: Int, state: String, asked: Int = 0, joinableTiers: [QualityTier] = [], requestId: Int? = nil,
                watchTiers: [QualityTier] = [], watching: Bool = false, requestableTiers: [QualityTier] = [],
                libraryTiers: [QualityTier] = []) {
        self.tmdbId = tmdbId
        self.state = state
        self.asked = asked
        self.joinableTiers = joinableTiers
        self.requestId = requestId
        self.watchTiers = watchTiers
        self.watching = watching
        self.requestableTiers = requestableTiers
        self.libraryTiers = libraryTiers
    }

    enum CodingKeys: String, CodingKey {
        case tmdbId, state, asked, joinableTiers, requestId, watchTiers, watching, requestableTiers, libraryTiers
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tmdbId = try c.decode(Int.self, forKey: .tmdbId)
        state = try c.decode(String.self, forKey: .state)
        asked = try c.decodeIfPresent(Int.self, forKey: .asked) ?? 0
        joinableTiers = try c.decodeIfPresent([QualityTier].self, forKey: .joinableTiers) ?? []
        requestId = try c.decodeIfPresent(Int.self, forKey: .requestId)
        watchTiers = try c.decodeIfPresent([QualityTier].self, forKey: .watchTiers) ?? []
        watching = try c.decodeIfPresent(Bool.self, forKey: .watching) ?? false
        requestableTiers = try c.decodeIfPresent([QualityTier].self, forKey: .requestableTiers) ?? []
        libraryTiers = try c.decodeIfPresent([QualityTier].self, forKey: .libraryTiers) ?? []
    }
}

/// What the request sheet offers and says (web `request-modal-offer.ts`,
/// `RequestModalDemand.tsx`, `request-modal-submit.ts`).
public enum RequestOffer {
    /// What ticking a version does: join someone's request, Watch, or a new ask.
    public enum Act: String, Sendable { case join, watch, new }

    public static func act(_ demand: RequestTitleDemand?, tier: QualityTier) -> Act {
        if demand?.joinableTiers.contains(tier) == true { return .join }
        if demand?.watchTiers.contains(tier) == true { return .watch }
        return .new
    }

    /// Per-version tags show only when some version joins or watches.
    public static func tagged(_ demand: RequestTitleDemand?) -> Bool {
        guard let demand else { return false }
        return !demand.joinableTiers.isEmpty || !demand.watchTiers.isEmpty
    }

    /// The versions to show: the server's per-viewer list when demand answered,
    /// else the offerable set.
    public static func tiers(demand: RequestTitleDemand?, fallback: [QualityTier]) -> [QualityTier] {
        demand?.requestableTiers ?? fallback
    }

    /// Request as soon as any version is a new (charged) ask; a join leads a
    /// free mix ("Me too"); a pure Watch reads "Watch".
    public static func submitLabel(_ acts: [Act]) -> String {
        if acts.isEmpty || acts.contains(.new) { return "Request" }
        return acts.contains(.join) ? "Me too" : "Watch"
    }

    /// The tag on a version row.
    public static func tag(_ act: Act, asked: Int) -> String {
        switch act {
        case .join: return "Me too · \(asked) asked"
        case .watch: return "Already being searched"
        case .new: return "New request"
        }
    }

    /// One clause of the demand summary: the act words (bold on screen) and the rest.
    public struct SummaryPart: Equatable, Sendable {
        public let lead: String
        public let rest: String
    }

    /// "**Me too** on HD·1080p · free", "**New request** for UHD·4K · uses 1 of
    /// your quota", in join, watch, new order (web `ActSummary`).
    public static func summaryParts(_ picks: [(tier: QualityTier, act: Act)], limited: Bool) -> [SummaryPart] {
        [Act.join, .watch, .new].compactMap { act -> SummaryPart? in
            let tiers = picks.filter { $0.act == act }.map(\.tier.chipLabel)
            guard !tiers.isEmpty else { return nil }
            let list = tiers.joined(separator: " + ")
            switch act {
            case .new:
                return SummaryPart(lead: "New request", rest: " for \(list)\(limited ? " · uses \(tiers.count) of your quota" : "")")
            case .join: return SummaryPart(lead: "Me too", rest: " on \(list) · free")
            case .watch: return SummaryPart(lead: "Watch", rest: " on \(list) · free")
            }
        }
    }

    /// "Me too on HD·1080p · free · New request for UHD·4K · uses 1 of your quota".
    public static func summary(_ picks: [(tier: QualityTier, act: Act)], limited: Bool) -> String {
        summaryParts(picks, limited: limited).map { $0.lead + $0.rest }.joined(separator: " · ")
    }

    /// The art pane's facts line (web `RequestModalArt`): the year, then a
    /// movie's runtime or a series' season count (Specials included).
    public static func artFacts(year: Int?, isSeries: Bool, runtime: Int?, seasonCount: Int?) -> String? {
        var parts: [String] = []
        if let year { parts.append(String(year)) }
        if isSeries {
            if let seasonCount { parts.append("\(seasonCount) season\(seasonCount == 1 ? "" : "s")") }
        } else if let runtime, runtime > 0 {
            parts.append("\(runtime) min")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    public static let joinedToast = "Joined · everyone is notified when it lands"
    public static let watchingToast = "Watching · you’ll hear when it lands"
    public static let wishlistToast = "Added to your wishlist"

    /// The success toast for what the server did.
    public static func successCopy(_ result: MediaRequest?, title: String) -> String {
        guard let result else { return "\(title) requested" }
        if result.status == "waiting" { return wishlistToast }
        if result.watch == true { return watchingToast }
        if result.joined == true, result.joinedRequestId == result.id { return joinedToast }
        return "\(title) requested"
    }

    /// "You've used your 3 requests this week."
    public static func quotaHeadline(limit: Int?) -> String {
        limit.map { "You've used your \($0) requests this week." } ?? "You’ve used all your requests for this week."
    }

    public static func quotaBody(resetsAt: String?) -> String {
        let day = RequestLifecycle.resetWeekday(resetsAt)
        return "Add it to your wishlist and it's requested automatically when your quota resets\(day.map { " on \($0)" } ?? "")."
    }
}

extension APIClient {
    /// Demand for up to 100 titles of one kind.
    public func requestDemand(kind: MediaKind, tmdbIds: [Int]) async throws -> [RequestTitleDemand] {
        guard !tmdbIds.isEmpty else { return [] }
        return try await get("/api/v1/requests/demand", query: [
            URLQueryItem(name: "kind", value: kind.rawValue),
            URLQueryItem(name: "tmdb_ids", value: tmdbIds.prefix(100).map(String.init).joined(separator: ",")),
        ])
    }

    /// `POST /requests`, returning the row the server made or joined (nil
    /// when the reply doesn't decode: the request still went through).
    @discardableResult
    public func submitRequest(_ body: RequestCreateBody) async throws -> MediaRequest? {
        let reply: Lenient<MediaRequest> = try await send("POST", "/api/v1/requests", body: body)
        return reply.value
    }
}

/// Decodes to nil instead of failing.
struct Lenient<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

/// What a Discover card shows for the viewer's demand (web
/// `discover-card-demand.ts`). Every per-viewer rule is the server's; this
/// only picks the row.
public struct DiscoverCardDemand: Equatable, Sendable {
    public enum Row: Equatable, Sendable { case meToo, watch, requestTiers }

    /// The In library mark, for this viewer.
    public let inLibrary: Bool
    /// The demand row under the title.
    public let row: Row?
    /// The viewer's own row is a Watch row.
    public let watching: Bool
    /// Hide the Requested / Approved chip (joined or watching).
    public let hideRequested: Bool

    public static func view(_ demand: RequestTitleDemand?, requestMode: Bool, titleInLibrary: Bool) -> DiscoverCardDemand {
        guard requestMode, let demand else {
            return DiscoverCardDemand(inLibrary: titleInLibrary, row: nil, watching: false, hideRequested: false)
        }
        let inLibrary = !demand.libraryTiers.isEmpty
        let watching = demand.state == "mine" && demand.watching
        var row: Row?
        if demand.state == "me_too" || demand.state == "joined" {
            row = .meToo
        } else if demand.state == "watch" {
            row = .watch
        } else if titleInLibrary && !inLibrary && !demand.requestableTiers.isEmpty {
            // In the library only in versions this viewer can't hold: "Request HD".
            row = .requestTiers
        }
        return DiscoverCardDemand(inLibrary: inLibrary, row: row, watching: watching,
                                  hideRequested: demand.state == "joined" || watching)
    }

    /// "Request HD", "Request 4K", "Request HD + 4K".
    public static func requestTiersLabel(_ tiers: [QualityTier]) -> String {
        tiers.isEmpty ? "Request" : "Request " + tiers.map { $0 == .uhd ? "4K" : "HD" }.joined(separator: " + ")
    }
}
