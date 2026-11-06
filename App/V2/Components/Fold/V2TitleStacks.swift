import SwiftUI
import FusionhaKit

/// The pages pushed over each open title (a season, then an episode), one
/// per window (`V2RootView`). The sheet (folded) and the shell's column
/// (open) bind the same path (`TitlePageOverride.stackPath`), so folding or
/// unfolding on a season or an episode lands on that page, with Back to
/// the same pages under it. A title's path goes when the title closes.
@MainActor
@Observable
final class V2TitleStacks {
    private var paths: [Int: NavigationPath] = [:]

    /// The title's path; writes count only from the host on screen
    /// (`accepts`), so the leaving host's teardown can't pop the pages.
    func path(_ itemId: Int, accepts: @escaping @MainActor () -> Bool) -> Binding<NavigationPath> {
        Binding(get: { self.paths[itemId] ?? NavigationPath() },
                set: { if accepts() { self.paths[itemId] = $0 } })
    }

    /// Pushes a page over the title (v1's episode sheet asks, `V2TitleDestinations`).
    func push(_ route: V2TitleRoute, on itemId: Int) {
        paths[itemId, default: NavigationPath()].append(route)
    }

    /// The title closed: it reopens on its own page.
    func close(_ itemId: Int) {
        paths[itemId] = nil
    }
}
