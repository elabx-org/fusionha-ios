import Foundation
import FusionhaKit

/// One Add result as both sources draw it (owner-approved Add results mock,
/// 2026-11-08): TMDB and TVDB share one row and one card, so the source only
/// changes what a pick does, never how the result looks.
struct AddResultCard: Identifiable, Hashable {
    let id: String
    let title: String
    let year: Int?
    /// "Movie", "Series" or "Anime" (TVDB results are always series).
    let kind: String
    let overview: String?
    let posterUrl: String?
    let inLibrary: Bool
    /// The library title it already is, resolved against the loaded library.
    let libraryItemId: Int?

    init(_ result: MediaSearchResult, libraryItemId: Int?) {
        id = "tmdb-\(result.id)"
        title = result.title
        year = result.year
        kind = kindName(result)
        overview = result.overview
        posterUrl = result.posterUrl
        inLibrary = result.inLibrary || libraryItemId != nil
        self.libraryItemId = libraryItemId
    }

    init(_ result: TvdbSearchResult) {
        id = "tvdb-\(result.tvdbId)"
        title = result.title
        year = result.year
        kind = "Series"
        overview = result.overview
        posterUrl = result.imageUrl
        inLibrary = result.inLibrary == true || result.libraryItemId != nil
        libraryItemId = result.libraryItemId
    }

    /// "2021 · Series".
    var subline: String {
        ([year.map { String($0) }, kind] as [String?]).compactMap { $0 }.joined(separator: " · ")
    }
}
