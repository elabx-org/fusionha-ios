import Foundation

/// Episodes the server holds for review (fusionha A4, `episode_parking.py`):
/// a row a numbering plan couldn't place keeps its files but moves to
/// `100_000 × (k + 1) + its original number`, so it never collides with a
/// real slot. Shown as its original number, held for review; the raw number
/// ("E100004") read as a broken list (owner, 2026-11-18, Cunk on Cinema).
public extension Episode {
    static let parkBase = 100_000

    /// Held for review: never wanted or searched until a plan places it.
    var isHeldForReview: Bool { episodeNumber >= Self.parkBase }

    /// The number to show: a held row's original number, else its own.
    var shownNumber: Int { isHeldForReview ? episodeNumber % Self.parkBase : episodeNumber }
}
