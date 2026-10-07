import Foundation

/// Whether the title detail sheet is really on screen, as UIKit sees it.
///
/// A deep link to another title closes the open one first (`presentedItem =
/// nil`), then presents the new one. The sheet's dismissal runs on UIKit's
/// clock, not ours: on a busy device it can outlast any fixed delay, and a
/// sheet presented while the old one is still leaving is silently dropped
/// (and the late dismissal writes `nil` back over the new title). So the
/// link waits for the old sheet's `onDismiss` before presenting.
@MainActor
enum DetailSheetPresence {
    private static var onScreen = false

    /// The sheet's content appeared.
    static func shown() { onScreen = true }

    /// The sheet's `onDismiss`: it is fully gone.
    static func dismissed() { onScreen = false }

    /// Returns once no detail sheet is on screen, or after `limit` as a
    /// safety net should UIKit never report the dismissal.
    static func settle(limit: Duration = .seconds(4)) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: limit)
        while onScreen, clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }
}
