import Foundation

/// The open Duo's gestures (owner-approved 2026-10-24, mock
/// https://claude.ai/artifact/XtzaSbr8shpbedxf8H4Zmh): the rules behind each
/// swipe, kept here so they are unit-tested.
///
/// 1. Swipe right from the right page's leading edge: closes the page (inside
///    the page's own stack the system Back goes first).
/// 2. On that edge, swipe left hides the list (flat only); with the list
///    hidden, swipe right brings it back before anything closes.
/// 3. Swipe across a title's hero art: the next or previous title in the
///    Library grid's order.
/// 4. Swipe left from the trailing edge of the content: the page just closed
///    comes back, for a few minutes.
/// 5. Pull a page over the window down: it closes (unless it is busy, and
///    after asking when it holds unsaved choices).
public enum DuoSwipe {
    /// The leading-edge and trailing-edge strips' width, in points.
    public static let edgeWidth = 20.0
    /// The strip that starts a pull-down on a page over the window.
    public static let pullZone = 84.0
    /// How long a closed page can be pulled back (gesture 4).
    public static let reopenWindow: TimeInterval = 5 * 60

    /// Whether letting go commits: past `share` of the extent, or flung far
    /// enough that the predicted end is past half of it. Movement against the
    /// direction never commits.
    public static func commits(translation: Double, predicted: Double, extent: Double,
                               share: Double = 0.3) -> Bool {
        guard extent > 0, translation > 0 else { return false }
        return translation >= extent * share || predicted >= extent * 0.5
    }

    /// A drag that reads as horizontal: clearly more sideways than up or down.
    public static func isHorizontal(dx: Double, dy: Double) -> Bool {
        abs(dx) > 12 && abs(dx) > abs(dy) * 1.5
    }

    /// What a swipe from the right page's leading edge does (gestures 1 and 2).
    public enum EdgeAction: Equatable, Sendable {
        case closePage, hideList, showList, none
    }

    /// `dx`: the drag's horizontal travel (positive = right). `listHidden`
    /// and `canHideList` come from the sidebar button's state; `canClose`
    /// is false while the page's own stack has something pushed (the system
    /// Back owns the edge then).
    public static func edgeAction(dx: Double, listHidden: Bool, canHideList: Bool, canClose: Bool) -> EdgeAction {
        if dx > 0 {
            if listHidden { return .showList }
            return canClose ? .closePage : .none
        }
        if dx < 0, canHideList, !listHidden { return .hideList }
        return .none
    }

    /// The neighbour of `id` in `order`, `step` away (+1 next, -1 previous);
    /// nil at either end or when `id` isn't in `order`.
    public static func neighbor(of id: Int, in order: [Int], step: Int) -> Int? {
        guard let index = order.firstIndex(of: id) else { return nil }
        let next = index + step
        return order.indices.contains(next) ? order[next] : nil
    }

    /// Whether a page closed at `closedAt` can still be pulled back at `now`.
    public static func canReopen(closedAt: Date, now: Date) -> Bool {
        let age = now.timeIntervalSince(closedAt)
        return age >= 0 && age <= reopenWindow
    }
}
