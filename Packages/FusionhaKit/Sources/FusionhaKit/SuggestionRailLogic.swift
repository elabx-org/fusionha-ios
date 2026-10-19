import Foundation

/// Discover › Browse "From your Letterboxd" (web `SuggestionsRail` /
/// `SuggestionCard` / `QuotaPip` / `RequestTierMenu`): the rail's copy and the
/// state → button / label mapping, kept out of the views so it is tested.
public enum SuggestionRail {
    // MARK: Copy (`RAIL_COPY`)

    public static let heading = "From your Letterboxd"
    public static let hint = "Titles from your watchlist and linked lists that aren’t in the library yet."
    public static let empty = "Nothing new from your Letterboxd right now. Everything on your watchlist and lists is already in the library or requested."
    public static let manage = "Manage Letterboxd"
    public static let staleNote = "from the last good check"
    public static let meTooHint = "Join the existing request. It doesn’t use your limit."
    public static let uhdUnavailable = "UHD·4K isn’t available for your account."
    public static let moreOptions = "More options…"

    /// The web gate (`useLetterboxd`): a connected profile or a linked source.
    public static func gated(_ read: LetterboxdRead?) -> Bool {
        guard let read else { return false }
        return read.username != nil || read.linkedCount > 0
    }

    // MARK: Hint line

    /// Distinct sources with a failed last check among `items`.
    public static func staleSources(_ items: [Suggestion]) -> Int {
        Set(items.filter(\.stale).map { $0.sourceId ?? -1 }).count
    }

    public static func staleSentence(_ n: Int) -> String {
        n == 1
            ? " 1 source couldn’t be checked and shows its last good check."
            : " \(n) sources couldn’t be checked and show their last good check."
    }

    /// The hint above "Manage Letterboxd": only while the track has items.
    public static func hintText(itemCount: Int, staleSources: Int) -> String? {
        guard itemCount > 0 else { return nil }
        return hint + (staleSources > 0 ? staleSentence(staleSources) : "")
    }

    // MARK: Source chips

    public struct Chip: Hashable, Sendable {
        public let sourceId: Int?
        public let label: String
        public let count: Int
        public var text: String { "\(label) \(count)" }
    }

    /// "All N" then one chip per source, from the unfiltered read; none when
    /// there is no source at all.
    public static func chips(_ read: SuggestionsRead) -> [Chip] {
        guard !read.sources.isEmpty else { return [] }
        return [Chip(sourceId: nil, label: "All", count: read.items.count)]
            + read.sources.map { Chip(sourceId: $0.sourceId, label: $0.label, count: $0.count) }
    }

    // MARK: Card actions

    public enum Done: Equatable, Sendable {
        case requested, wishlist

        public var label: String { self == .wishlist ? "On your wishlist" : "Requested" }
    }

    public enum Action: Equatable, Sendable {
        /// The request went through: a check and its word.
        case done(Done)
        /// Someone already asked: Me too, then "N asked already".
        case meToo(asked: Int)
        /// Request (or Add to wishlist over the limit) and the tier caret.
        case request(overLimit: Bool)
    }

    public static func action(askedCount: Int, done: Done?, overLimit: Bool) -> Action {
        if let done { return .done(done) }
        if askedCount > 0 { return .meToo(asked: askedCount) }
        return .request(overLimit: overLimit)
    }

    public static func primaryLabel(overLimit: Bool) -> String { overLimit ? "Add to wishlist" : "Request" }

    public static func askedLine(_ n: Int) -> String { "\(n) asked already" }

    public static func requestedToast(_ title: String, wishlist: Bool) -> String {
        wishlist ? "\(title) added to your wishlist" : "\(title) requested"
    }

    public static func joinedToast(_ title: String) -> String { "Joined · \(title)" }

    /// The done state a successful request leaves.
    public static func done(afterRequest wishlist: Bool) -> Done { wishlist ? .wishlist : .requested }

    // MARK: Tier menu (`RequestTierMenu`)

    public struct TierOption: Hashable, Sendable {
        public let label: String
        public let tiers: [QualityTier]
    }

    /// HD·1080p, plus HD + UHD when the account may ask for 4K.
    public static func tierOptions(uhdAllowed: Bool) -> [TierOption] {
        var options = [TierOption(label: "HD·1080p", tiers: [.hd])]
        if uhdAllowed { options.append(TierOption(label: "HD·1080p + UHD·4K", tiers: [.hd, .uhd])) }
        return options
    }

    // MARK: Quota pip (`QuotaPip`, `useOverLimit`)

    /// True once the weekly limit is used up (the rail then wishlists).
    public static func overLimit(_ quota: RequestQuota?) -> Bool {
        guard let quota, let limit = quota.limit else { return false }
        return quota.used >= limit
    }

    public struct Pip: Equatable, Sendable {
        /// The bold part ("Unlimited", "3 of 5").
        public let strong: String
        /// The rest (" requests", " left this week", " left this week · over limit").
        public let rest: String
        /// The ring's filled share, nil for unlimited (no ring).
        public let fraction: Double?
        public let low: Bool
        public let help: String
    }

    public static func pip(_ quota: RequestQuota) -> Pip {
        guard let limit = quota.limit else {
            return Pip(strong: "Unlimited", rest: " requests", fraction: nil, low: false,
                       help: "Your request limit. Unlimited today.")
        }
        let left = max(0, limit - quota.used)
        let fraction = limit > 0 ? min(1, max(0, Double(left) / Double(limit))) : 0
        return Pip(strong: "\(left) of \(limit)", rest: " left this week" + (left == 0 ? " · over limit" : ""),
                   fraction: fraction, low: left == 0, help: "Weekly request limit. Auto-requests count too.")
    }
}
