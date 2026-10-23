import SwiftUI
import FusionhaKit

/// The page's kind filter, All · Movies · Series · Anime (from the web's Add
/// item search): a native segmented picker, remembered on this device. It
/// narrows the library lane, the provider lane and Trending.
struct SearchKindPicker: View {
    @AppStorage(SearchKindPicker.storageKey) private var kindRaw = SearchKind.all.rawValue

    static let storageKey = "unifiedSearch.kind"

    var body: some View {
        Picker("Kind", selection: Binding {
            SearchKind(rawValue: kindRaw) ?? .all
        } set: { kindRaw = $0.rawValue }) {
            ForEach(SearchKind.allCases, id: \.self) { kind in
                Text(kind.title).tag(kind)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: .infinity)
    }
}

extension SearchKind {
    /// "series" in "No series in your library for “dune”".
    var noun: String? {
        switch self {
        case .all: return nil
        case .movie: return "movies"
        case .series: return "series"
        case .anime: return "anime"
        }
    }

    /// The library's bucket for this filter (`nil` = every kind).
    var bucket: KindBucket? {
        switch self {
        case .all: return nil
        case .movie: return .movie
        case .series: return .series
        case .anime: return .anime
        }
    }

    /// A TMDB row's kind matches the filter.
    func matches(_ result: MediaSearchResult) -> Bool {
        switch self {
        case .all: return true
        case .movie: return result.kind == .movie
        case .series: return result.kind == .series && !result.isAnime
        case .anime: return result.isAnime
        }
    }
}
