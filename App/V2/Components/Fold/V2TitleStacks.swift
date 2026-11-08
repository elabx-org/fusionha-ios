import SwiftUI
import FusionhaKit

/// The pages pushed over each open title (a season, then an episode), one
/// per window (`V2RootView`). The sheet (folded) and the shell's column
/// (open) bind the same path (`TitlePageOverride.stackPath`), so folding or
/// unfolding on a season or an episode lands on that page, with Back to
/// the same pages under it. A title's path goes when the title closes.
/// Each pushed page's place (its scroll, the episode's tab) is kept here
/// too (`place`), dropped when its page is popped (`FoldPagePlaces`).
@MainActor
@Observable
final class V2TitleStacks {
    private var paths: [Int: NavigationPath] = [:]
    @ObservationIgnored private var places: [Int: [V2TitleRoute: V2PagePlace]] = [:]

    /// The title's path; writes count only from the host on screen
    /// (`accepts`), so the leaving host's teardown can't pop the pages.
    func path(_ itemId: Int, accepts: @escaping @MainActor () -> Bool) -> Binding<NavigationPath> {
        Binding(get: { self.paths[itemId] ?? NavigationPath() },
                set: { new in
                    guard accepts() else { return }
                    let old = self.paths[itemId]?.count ?? 0
                    self.paths[itemId] = new
                    self.dropPlaces(itemId, from: old, to: new.count)
                })
    }

    /// Pushes a page over the title (v1's episode sheet asks, `V2TitleDestinations`).
    func push(_ route: V2TitleRoute, on itemId: Int) {
        paths[itemId, default: NavigationPath()].append(route)
    }

    /// The title closed: it reopens on its own page.
    func close(_ itemId: Int) {
        paths[itemId] = nil
        places[itemId] = nil
    }

    /// The kept place of a page pushed over the title.
    func place(_ route: V2TitleRoute, on itemId: Int) -> V2PagePlace {
        if let kept = places[itemId]?[route] { return kept }
        let made = V2PagePlace()
        places[itemId, default: [:]][route] = made
        return made
    }

    private func dropPlaces(_ itemId: Int, from old: Int, to new: Int) {
        switch FoldPagePlaces.drop(from: old, to: new) {
        case .none:
            return
        case .all:
            places[itemId] = nil
        case .top:
            // Episodes are the top layer: the season under them keeps its place.
            places[itemId] = places[itemId]?.filter { entry in
                if case .season = entry.key { return true }
                return false
            }
        }
    }
}
