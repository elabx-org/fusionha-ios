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
        FoldSeam(x: live, listFloor: rest, titleFloor: width - rest)
    }
}

/// The two columns around a moving seam (`FoldSplitLayout.seam`).
///
/// Smoothness (build 757 lagged): a column's size is never changed per
/// frame, since a new size re-lays out the whole Library grid or title page.
/// Each column has two sizes only, its split size and the size of the stop
/// the drag is heading to, and the seam just moves them:
/// - seam left of the split (toward full width): the title is laid out at
///   the full width once, its trailing part off the edge until it arrives;
///   the list keeps its width and slides under it.
/// - seam right of the split (toward close): the list is laid out at the full
///   width once (the Library it closes back to), under the title; the title
///   keeps its width and slides off the trailing edge.
/// Letting go at the stop it was heading to then lays nothing out again.
struct FoldSeam: Equatable {
    var x: CGFloat
    /// The list's width in the split.
    var listFloor: CGFloat
    /// The title's width in the split.
    var titleFloor: CGFloat

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
        let listWidth = towardClose ? bounds.width : seam.listFloor
        let titleWidth = towardClose ? seam.titleFloor : bounds.width
        // Squeezed, the list slides a little under the title.
        let slide = towardClose ? 0 : (seam.listFloor - x) * CGFloat(DuoSeam.listSlide)
        subviews[0].place(at: CGPoint(x: bounds.minX - slide, y: bounds.minY),
                          proposal: ProposedViewSize(width: listWidth, height: bounds.height))
        subviews[1].place(at: CGPoint(x: bounds.minX + x, y: bounds.minY),
                          proposal: ProposedViewSize(width: titleWidth, height: bounds.height))
    }
}
