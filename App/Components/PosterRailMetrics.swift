import SwiftUI

/// How a title page's poster rails (More like this, the collection) size
/// their cards. v1 keeps the web `SimilarRail` sizes; v2 sets its Library
/// grid's (`V2LibraryColumns`) so a rail's posters match the Library's
/// (owner, build 805: More like this was ~190pt beside ~138pt Library cards).
struct PosterRailMetrics {
    /// A card's width in a rail this wide.
    var cardWidth: (CGFloat) -> CGFloat
    var spacing: CGFloat
    var radius: CGFloat

    static let web = PosterRailMetrics(cardWidth: { rail in
        // Web SimilarRail: 3-up on a phone (≤540: (100% - 32px) / 3),
        // 128pt up to 720, 158pt wider.
        if rail <= 540 { return (rail - 32) / 3 }
        return rail <= 720 ? 128 : 158
    }, spacing: 16, radius: 8)
}

extension EnvironmentValues {
    @Entry var posterRail = PosterRailMetrics.web
}
