import SwiftUI
import FusionhaKit

// MARK: - The seam between the list and the title (v2's split handle)
//
// v2 puts a handle on the seam of the flat open Duo's seamless split
// (`TitlePageOverride.seamHandle`, `V2SplitHandle`). While it is dragged or
// springing to a stop, `DuoSeamDrag.live` holds the seam's place and the
// shell lays its two columns out around it (`FoldSeam`); at rest it is nil
// and the shell's split is the usual one. v1 never offers the handle, so
// none of this is ever active there.

/// The seam under the finger (or the snap's spring), shared by the shell
/// and the handle. Owned by `RootView`.
@MainActor
@Observable
final class DuoSeamDrag {
    /// The seam's distance from the leading edge while dragged or
    /// springing; nil at rest.
    var live: CGFloat?
    /// The title v2's handle last slid in on opening, so it slides once.
    @ObservationIgnored var slidIn: Int?
    /// The seam is carrying a title in as it opens, or out as Close closes
    /// it (`V2SplitHandle`): the list is laid out at the full width it has
    /// with no title.
    var listFull = false
    /// Close on a title with the handle (`ShellDetailColumn`): the handle
    /// slides it off the trailing edge, then closes it.
    var closeRequests = 0
    /// The handle is on screen to take `closeRequests`.
    @ObservationIgnored var handleShown = false
}

/// What the shell hands v2's handle: where the seam rests and what each stop does.
struct DuoSeamContext {
    let drag: DuoSeamDrag
    /// The display's width.
    let width: CGFloat
    /// The seam's place in the split (the list's share of the width).
    let rest: CGFloat
    /// The list is hidden (the sidebar button, or the handle at full width).
    let fullWidth: Bool
    /// Hide (true) or show (false) the list, as the sidebar button does.
    let setFullWidth: @MainActor (Bool) -> Void
    /// Close the title, as Close does.
    let close: @MainActor () -> Void

    /// Offered only with v2's handle, on the flat open Duo's seamless split
    /// with a title open (the list hidden or not), where the list can hide.
    @MainActor
    init?(titlePage: TitlePageOverride?, fold: FoldInfo, split: ShellSplit, toggle: DuoListToggle?,
          drag: DuoSeamDrag, model: AppModel) {
        guard titlePage?.seamHandle != nil, let share = titlePage?.flatOpenListShare,
              fold.vertical == nil, fold.flatVertical != nil, split.shown, split.axis == .horizontal,
              model.presentedItem != nil, let toggle, fold.size.width > 0 else { return nil }
        self.drag = drag
        width = fold.size.width
        rest = (fold.size.width * CGFloat(share)).rounded()
        fullWidth = toggle.hidden
        setFullWidth = { hidden in if hidden != toggle.hidden { toggle.toggle() } }
        close = { [model] in
            model.presentedItem = nil
            model.spreadPreview = nil
        }
    }

    /// The split as the seam moves: both columns laid out around `live`.
    func seam(live: CGFloat) -> FoldSeam {
        FoldSeam(x: live, listFloor: rest, titleFloor: width - rest, fromFull: fullWidth, listFull: drag.listFull)
    }
}

/// The two columns around a moving seam (`FoldSplitLayout.seam`).
///
/// Smoothness (builds 757 and 760): no column is re-laid out while the seam
/// moves, since a new size re-lays out the whole Library grid or title page.
/// Each column keeps the size it had when the drag began, and the seam only
/// moves them:
/// - from the split, toward full width: the list keeps its width and slides
///   under the shade; the title stays where it is, and v2's handle paints
///   the ground it will fill (`V2SeamGround`). It takes the full width once,
///   when it lands there.
/// - toward close: the title slides off the trailing edge at its width; the
///   list keeps its split width (the handle paints the list's ground beside
///   it) and takes the full width once the title is gone (build 765's
///   full-width list re-flowed the whole Library grid as the drag began).
/// - a title opening: it slides in the same way over the list, which keeps
///   the full width it had until the title lands.
/// - from full width: the title stays at the full width and slides.
struct FoldSeam: Equatable {
    var x: CGFloat
    /// The list's width in the split.
    var listFloor: CGFloat
    /// The title's width in the split.
    var titleFloor: CGFloat
    /// The drag began at full width (the list hidden).
    var fromFull = false
    /// A title opening or closed by Close: the list is at the full width it
    /// has with no title (else it keeps its split width while dragged, and
    /// re-lays out once the title is gone).
    var listFull = false

    /// How far into its closing look the title is (`DuoSeam.closeProgress`).
    var closeProgress: CGFloat {
        CGFloat(DuoSeam.closeProgress(x: Double(x), width: Double(listFloor + titleFloor), split: Double(listFloor)))
    }
}

extension FoldSplitLayout {
    /// Places the list and the title around `seam` (horizontal only): two
    /// sizes per column, so moving the seam only moves them.
    func placeSeam(_ seam: FoldSeam, in bounds: CGRect, subviews: LayoutSubviews) {
        let x = min(max(seam.x, 0), bounds.width)
        let towardClose = x > seam.listFloor
        let listWidth = seam.listFull ? bounds.width : seam.listFloor
        // Squeezed, the list slides a little under the title.
        let slide = towardClose || seam.listFull ? 0 : (seam.listFloor - x) * CGFloat(DuoSeam.listSlide)
        let titleX = towardClose || seam.fromFull ? x : seam.listFloor
        let titleWidth = seam.fromFull ? bounds.width : seam.titleFloor
        subviews[0].place(at: CGPoint(x: bounds.minX - slide, y: bounds.minY),
                          proposal: ProposedViewSize(width: listWidth, height: bounds.height))
        subviews[1].place(at: CGPoint(x: bounds.minX + titleX, y: bounds.minY),
                          proposal: ProposedViewSize(width: titleWidth, height: bounds.height))
    }
}
