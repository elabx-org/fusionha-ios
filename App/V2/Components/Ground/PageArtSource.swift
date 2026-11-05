import Foundation
import FusionhaKit

/// The v2 pages that sit on a ground.
enum V2Page: String, CaseIterable, Sendable {
    case library, title
    case queue, downloads, history, wanted, blocklist, tasks, manualImport
    case calendar, add, collection, discover, search
    case requestsMine
    case settings
}

/// Which art a page's ground comes from (mock cards-w.js `GROUND`: "every
/// page has a ground"). The page passes the chosen item's art to
/// `.v2PageGround(art:)`; a page with no art uses the palette's tint ground.
enum PageArtSource: Equatable, Sendable {
    /// No art: the soft tint built from the palette's tokens.
    case tint
    /// Settings keeps its own S1 tint as it is.
    case keepsTint
    /// The art of one item on the page.
    case art(PageArtPick)
}

/// The item whose art paints the page.
enum PageArtPick: String, Sendable {
    /// Library: the first hero card (plan S4).
    case firstHero
    /// A title page: its own backdrop (the hero's art).
    case titleBackdrop
    /// Queue: the first item in today's group; held / override states use
    /// the held item instead (`heldItem`).
    case firstQueueItem
    case heldItem
    /// Downloads: the first active download.
    case firstDownload
    /// History: the latest event's title.
    case latestEvent
    /// Wanted: the first wanted title.
    case firstWanted
    /// Calendar: today's first release.
    case todayFirstRelease
    /// Add and Search: the selected result (Search: tint until one is).
    case selectedResult
    /// A collection's own backdrop.
    case collectionBackdrop
    /// Discover: the trending hero.
    case trendingHero
    /// Requests, Mine: the first of the user's requests.
    case firstOwnRequest
}

extension V2Page {
    /// The page's ground, as in the mock.
    var groundSource: PageArtSource {
        switch self {
        case .library: return .art(.firstHero)
        case .title: return .art(.titleBackdrop)
        case .queue: return .art(.firstQueueItem)
        case .downloads: return .art(.firstDownload)
        case .history: return .art(.latestEvent)
        case .wanted: return .art(.firstWanted)
        case .blocklist, .tasks, .manualImport: return .tint
        case .calendar: return .art(.todayFirstRelease)
        case .add, .search: return .art(.selectedResult)
        case .collection: return .art(.collectionBackdrop)
        case .discover: return .art(.trendingHero)
        case .requestsMine: return .art(.firstOwnRequest)
        case .settings: return .keepsTint
        }
    }

    /// The caption inside the page's first module, where the mock names one.
    var firstModuleCaption: String? {
        switch self {
        case .queue: return "Today"
        case .history: return "Today · latest first"
        case .requestsMine: return "Your requests"
        default: return nil
        }
    }
}

extension PageArtSource {
    /// The URL a ground samples for an item's art: its textless backdrop,
    /// else its poster, at the w780 size the hero's ambient already loads.
    static func url(backdrop: String?, poster: String?) -> URL? {
        ArtPaletteExtractor.sampleURL(backdrop ?? poster)
    }
}
