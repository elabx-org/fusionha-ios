import Foundation

/// The Living logo's moves, named as on the web (`living/moves.ts`).
public enum LivingMoveName: String, CaseIterable, Sendable {
    case arrivals, fusion, quality, pride, fusionQuality
    case kinds2, movie, tv, anime, dragon, fusionMedia

    /// The neutral moves, in their idle order (media off). Pride sits between the
    /// two quality visuals so HD × 4K never follows Quality tiers.
    public static let neutral: [LivingMoveName] = [.arrivals, .fusion, .quality, .pride, .fusionQuality]
    /// The media-themed set (`login_living_media`).
    public static let media: [LivingMoveName] = [.kinds2, .movie, .tv, .anime, .dragon, .fusionMedia]

    /// Media on: the media morphs interleaved between the neutral moves. No fusion
    /// move sits next to a move showing the same object, the loop's wrap included
    /// (Movies × Series goes last, away from Movie, TV and Three kinds; HD × 4K
    /// away from Quality tiers).
    static let mediaOrder: [LivingMoveName] = [
        .arrivals, .kinds2, .fusion, .movie, .pride, .tv, .quality, .anime, .fusionQuality, .dragon, .fusionMedia,
    ]

    /// `buildMoveOrder`: neutral only by default; the media morphs join only
    /// when `login_living_media` is on.
    public static func order(media: Bool) -> [LivingMoveName] { media ? mediaOrder : neutral }

    /// The objects a fusion move shows that another move also shows: the two
    /// must never play back to back.
    public static let sameObject: [LivingMoveName: Set<LivingMoveName>] = [
        .fusionMedia: [.movie, .tv, .kinds2],
        .fusionQuality: [.quality],
    ]

    /// `order` without the moves a client hasn't ported (the web's order
    /// otherwise, so the rotation stays the web's).
    public static func order(media: Bool, playable: Set<LivingMoveName>) -> [LivingMoveName] {
        order(media: media).filter(playable.contains)
    }

    /// True when no fusion move sits next to a move showing the same object,
    /// the loop's wrap-around included.
    public static func keepsFusionApart(_ order: [LivingMoveName]) -> Bool {
        for (i, m) in order.enumerated() {
            let next = order[(i + 1) % order.count]
            if sameObject[m]?.contains(next) == true || sameObject[next]?.contains(m) == true { return false }
        }
        return true
    }
}
