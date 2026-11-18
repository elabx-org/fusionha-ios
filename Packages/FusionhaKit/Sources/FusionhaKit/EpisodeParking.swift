import Foundation

/// Episodes the server holds for review (fusionha A4, `episode_parking.py`):
/// a row a numbering plan couldn't place keeps its files but moves to
/// `100_000 × (k + 1) + its original number`, so it never collides with a
/// real slot. Shown as its original number, held for review; the raw number
/// ("E100004") read as a broken list (owner, 2026-11-18, Cunk on Cinema).
public extension Episode {
    static let parkBase = 100_000

    /// Held for review: never wanted or searched until a plan places it. The
    /// server's flag when it sends one (it also covers a stamped row that
    /// isn't parked), else read from a parked number.
    var isHeldForReview: Bool { heldForReview ?? (episodeNumber >= Self.parkBase) }

    /// The number to show: a parked row's original number (the server's
    /// `parked_origin`, else read from the number), else its own.
    var shownNumber: Int {
        parkedOrigin ?? (episodeNumber >= Self.parkBase ? episodeNumber % Self.parkBase : episodeNumber)
    }
}
