import SwiftUI
import FusionhaKit

// MARK: - The open title's own pages (owner-approved episode mock, 2026-11-02)
//
// In a Spread the open title sits on the right page beside the tab's list.
// When the title fills the whole open display it splits at the fold itself
// (`DetailSpreadBody`): halves at the fold with the 40 pt gutter, even when
// the Duo lies flat (a flat third is narrower than the phone layout).
//
// - An episode opened from the title is the right page, not a cover: the
//   list hides for as long as it is open, the title's tabs move to the left
//   page with the episode's row marked, and the episode fills the right.
// - The list hidden with the sidebar button: the art, versions and overview
//   on the left page, the tabs on the right, each scrolling on its own.
//
// The Web layout, the folded Duo, phones and iPads are unchanged.

/// The halves of the open display, handed to the title's column as
/// `\.titleSpread` while the shell is a Spread with a title open.
struct TitleSpread: Equatable {
    /// The halves at the fold, in the shell's coordinates (the column's too
    /// while it fills the display).
    var pages: SpreadGeometry.Pages
    /// The list is hidden and the title fills the display, so it splits.
    var fillsDisplay: Bool

    /// The halves for this geometry: only in a Spread's pages mode, with a
    /// top-to-bottom fold (active or flat), and both halves wide enough.
    static func pages(fold: FoldInfo, spread: SpreadContext) -> SpreadGeometry.Pages? {
        guard case .pages = spread.mode, let x = fold.vertical ?? fold.flatVertical else { return nil }
        return SpreadGeometry.pages(width: Double(fold.size.width),
                                    fold: Double(x.lowerBound)...Double(x.upperBound))
    }
}

extension EnvironmentValues {
    /// The title's halves while it is the right page of a Spread (nil otherwise).
    @Entry var titleSpread: TitleSpread? = nil
    /// The title's tabs leave out Overview: its rails are on the left page.
    @Entry var detailTabsOmitOverview = false
}
