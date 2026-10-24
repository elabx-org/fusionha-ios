import Foundation
import Observation
import FusionhaKit

/// What the open Duo's gestures remember (`DuoSwipe`): the page last closed
/// (gesture 4 pulls it back), the Library grid's order (gesture 3 walks it)
/// and whether the trailing edge is taken (the Library's A–Z thumb is up).
@MainActor
@Observable
final class DuoGestureMemory {
    enum ClosedPage: Equatable {
        case title(ItemRef)
        case preview(PreviewRoute)
    }

    struct Closed: Equatable {
        var page: ClosedPage
        var tab: AppTab
        var at: Date
    }

    private(set) var lastClosed: Closed?
    /// True while something of the page's own sits on the trailing edge.
    var edgeBusy = false
    /// The title a swipe across the art just opened: the Library scrolls to it.
    private(set) var swipedTo: Int?

    /// The Library grid's titles in display order (its current kind, filters and sort).
    @ObservationIgnored var libraryOrder: [Int] = []

    func recordClosed(_ page: ClosedPage, tab: AppTab) {
        lastClosed = Closed(page: page, tab: tab, at: Date())
    }

    /// The page to pull back on `tab`, while it is recent enough.
    func reopenable(on tab: AppTab, now: Date = Date()) -> ClosedPage? {
        guard let lastClosed, lastClosed.tab == tab,
              DuoSwipe.canReopen(closedAt: lastClosed.at, now: now) else { return nil }
        return lastClosed.page
    }

    func forgetClosed() { lastClosed = nil }

    func neighbor(of id: Int, step: Int) -> Int? {
        DuoSwipe.neighbor(of: id, in: libraryOrder, step: step)
    }

    func swiped(to id: Int) { swipedTo = id }
}
