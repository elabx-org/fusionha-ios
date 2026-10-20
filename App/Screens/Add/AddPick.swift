import SwiftUI
import FusionhaKit

/// A pick on the Find step: a TMDB-identified title, or a TVDB-only series.
enum AddPick: Hashable {
    case tmdb(MediaSearchResult)
    case tvdb(TvdbSearchResult)

    var title: String {
        switch self {
        case .tmdb(let r): return r.title
        case .tvdb(let r): return r.title
        }
    }

    var year: Int? {
        switch self {
        case .tmdb(let r): return r.year
        case .tvdb(let r): return r.year
        }
    }

    /// A TVDB-only pick is always a series (TVDB search is series-only).
    var kind: MediaKind {
        switch self {
        case .tmdb(let r): return r.kind
        case .tvdb: return .series
        }
    }

    var tmdbAnime: Bool {
        if case .tmdb(let r) = self { return r.isAnime }
        return false
    }

    /// `tmdb:<kind>:<id>` / `tvdb:<id>`: the pick identity.
    var key: String {
        switch self {
        case .tmdb(let r): return "tmdb:\(r.kind.rawValue):\(r.tmdbId)"
        case .tvdb(let r): return "tvdb:\(r.tvdbId)"
        }
    }

    var posterUrl: String? {
        switch self {
        case .tmdb(let r): return r.posterUrl
        case .tvdb(let r): return r.imageUrl
        }
    }

    var backdropUrl: String? {
        if case .tmdb(let r) = self { return r.backdropUrl }
        return nil
    }

    var tmdbResult: MediaSearchResult? {
        if case .tmdb(let r) = self { return r }
        return nil
    }
}
