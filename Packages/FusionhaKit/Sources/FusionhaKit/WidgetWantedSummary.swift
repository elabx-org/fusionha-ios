import Foundation

public struct WidgetWantedRow: Codable, Sendable, Hashable {
    public let itemId: Int
    public let title: String
    public let posterUrl: String?
    public let tiers: [QualityTier]
    /// `3 episodes`, `Movie`, `Anime`.
    public let detail: String

    public init(itemId: Int, title: String, posterUrl: String?, tiers: [QualityTier], detail: String) {
        self.itemId = itemId
        self.title = title
        self.posterUrl = posterUrl
        self.tiers = tiers
        self.detail = detail
    }
}

/// The Wanted page: missing, 4K available and cutoff-unmet counts, and the
/// latest missing titles.
public struct WidgetWantedSummary: Codable, Sendable, Hashable {
    public var missing = 0
    public var cutoffUnmet: Int?
    public var fourKAvailable: Int?
    public var rows: [WidgetWantedRow] = []

    public init() {}

    public init(missing page: WantedPage, fourK: FourKAvailablePage?, limit: Int = 3) {
        missing = page.missingTitles ?? page.missingCount ?? page.total
        cutoffUnmet = page.cutoffUnmetTitles ?? page.cutoffUnmetCount
        fourKAvailable = fourK.map { $0.fourkAvailableCount ?? $0.total }
        rows = page.items.prefix(limit).map { item in
            var tiers: [QualityTier] = []
            for edition in item.editions where !tiers.contains(edition.tier) { tiers.append(edition.tier) }
            let episodes = item.editions.map { $0.missingEpisodeCount ?? $0.missingEpisodes?.count ?? 0 }.max() ?? 0
            let detail: String
            if item.kind == .movie {
                detail = item.isAnime ? "Anime movie" : "Movie"
            } else {
                detail = episodes > 0 ? "\(episodes) episode\(episodes == 1 ? "" : "s") missing" : (item.isAnime ? "Anime" : "Series")
            }
            return WidgetWantedRow(itemId: item.id, title: item.title, posterUrl: item.posterUrl,
                                   tiers: tiers.sorted { $0 == .hd && $1 == .uhd }, detail: detail)
        }
    }
}
