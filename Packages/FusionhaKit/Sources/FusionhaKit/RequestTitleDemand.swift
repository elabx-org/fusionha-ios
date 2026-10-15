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

    /// "Me too on HD·1080p · free · New request for UHD·4K · uses 1 of your quota".
    public static func summary(_ picks: [(tier: QualityTier, act: Act)], limited: Bool) -> String {
        [Act.join, .watch, .new].compactMap { act -> String? in
            let tiers = picks.filter { $0.act == act }.map(\.tier.chipLabel)
            guard !tiers.isEmpty else { return nil }
            switch act {
            case .new: return "New request for \(tiers.joined(separator: " + "))\(limited ? " · uses \(tiers.count) of your quota" : "")"
            case .join: return "Me too on \(tiers.joined(separator: " + ")) · free"
            case .watch: return "Watch on \(tiers.joined(separator: " + ")) · free"
            }
        }.joined(separator: " · ")
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
