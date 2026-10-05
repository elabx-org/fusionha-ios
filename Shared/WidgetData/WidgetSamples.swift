import Foundation
import WidgetKit
import FusionhaKit

/// Gallery placeholders (WidgetKit `placeholder(in:)` renders them redacted).
enum WidgetSamples {
    static let upNext: [UpNextRow] = [
        UpNextRow(item: UpNextItem(itemId: 0, title: "Shōgun", code: "S1·E5", episodeTitle: "Broken to the Fist",
                                   airDate: .now.addingTimeInterval(3 * 3600), hasTime: true, isMovie: false,
                                   isAnime: false, posterUrl: nil,
                                   editions: [UpNextEdition(tier: .hd, status: .unaired),
                                              UpNextEdition(tier: .uhd, status: .unaired)]),
                  poster: nil),
        UpNextRow(item: UpNextItem(itemId: 0, title: "Dune: Part Two", code: "Digital", episodeTitle: nil,
                                   airDate: .now.addingTimeInterval(2 * 86_400), hasTime: false, isMovie: true,
                                   isAnime: false, posterUrl: nil,
                                   editions: [UpNextEdition(tier: .uhd, status: .unaired)]),
                  poster: nil),
        UpNextRow(item: UpNextItem(itemId: 0, title: "Frieren", code: "#29", episodeTitle: nil,
                                   airDate: .now.addingTimeInterval(4 * 86_400), hasTime: true, isMovie: false,
                                   isAnime: true, posterUrl: nil,
                                   editions: [UpNextEdition(tier: .hd, status: .unaired)]),
                  poster: nil),
    ]

    static let recent: [RecentImportRow] = ["The Matrix", "Inception", "Breaking Bad", "Cowboy Bebop", "Arrival"]
        .map { RecentImportRow(item: RecentImport(itemId: nil, title: $0, tiers: [.hd], importedAt: .now, posterUrl: nil, count: 1),
                         poster: nil) }
}
