import SwiftUI

/// The title filling the flat open Duo (slice S7, mock browse-title.js
/// `tabWide`): the sidebar button or the split handle hid the list, so the
/// title has the whole display. The art becomes one header band across it
/// and the body two columns: the summary on the left, the tabs on the
/// right. Beside the list (two thirds) and in book pose the title keeps its
/// one column; book pose never hides the list (`DuoPosture.canHideList`),
/// so nothing here runs across the fold.
enum V2TitleWide {
    /// Whether the open title fills the flat open display. Reads the shell's
    /// environment (`RootView`), which pushed pages see too.
    static func fills(duoOpen: Bool, bookPose: Bool, toggle: DuoListToggle?) -> Bool {
        duoOpen && !bookPose && toggle?.hidden == true
    }

    /// The page's side gutter (mock 24).
    static let gutter: CGFloat = 24
    /// Between the two columns (mock 348 - 324).
    static let columnGap: CGFloat = 24

    /// The summary column: a third of the display (mock 300 of 897), never
    /// narrower than two small version cards.
    static func leftWidth(_ total: CGFloat) -> CGFloat {
        min(380, max(296, (total * 0.34).rounded()))
    }

    /// The header band (mock 132): the bar's reach plus the heading.
    static func bandHeight(barInset: CGFloat) -> CGFloat {
        max(140, barInset + 96)
    }
}

extension EnvironmentValues {
    /// A season or episode page laid out as the wide child's right pane
    /// (`V2TitleWideChild`): the child paints the ground and the header
    /// band, so the page skips its own ground and hero.
    @Entry var v2WideChild = false
}

extension View {
    /// The page's ground, unless it is the wide child's right pane, whose
    /// ground (and palette) comes from the child.
    func v2PageGroundUnlessWideChild(art: URL?, showsArt: Bool = true) -> some View {
        modifier(V2GroundUnlessWideChild(art: art, showsArt: showsArt))
    }
}

private struct V2GroundUnlessWideChild: ViewModifier {
    @Environment(\.v2WideChild) private var wideChild
    let art: URL?
    let showsArt: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if wideChild {
            content
        } else {
            content.v2PageGround(art: art, showsArt: showsArt)
        }
    }
}
