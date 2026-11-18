import SwiftUI

/// The shell's two columns in `FoldSplitLayout`, with v2's moving seam
/// (`DuoSeamDrag.live`) read here and nowhere above.
///
/// While the split handle is dragged or springing, `live` changes on every
/// frame. `RootView` used to read it while building its split, so each change
/// re-ran the whole shell: `RootView`, `ShellDetailColumn`, the title page, and
/// everything that reads the environment values `RootView` sets with fresh
/// closures (`duoListToggle`, `titleSpread`), the Library's posters among them
/// (perf v2session, local run 2026-11-18: `RootView.body` 17, `V2TitleView.body`
/// 21 and `PosterImage.body` up to 60 per drag). Here a moving seam re-runs
/// only this view and the layout's placement; the columns it places are built
/// by `RootView` and are left alone.
struct ShellSplitHost<Tabs: View, Detail: View>: View {
    /// The split at rest: without the moving seam.
    let split: ShellSplit
    /// v2's handle context, where the handle is offered; nil in v1.
    let context: DuoSeamContext?
    /// A title just opened that the handle will slide in (`RootView.slidePending`).
    let slidePending: Bool
    let drag: DuoSeamDrag
    /// Close slides the title out with the handle (`DuoSeamCloseEffect`).
    let closeWithHandle: Bool
    let detailTransition: AnyTransition
    @ViewBuilder let tabs: Tabs
    @ViewBuilder let detail: Detail

    var body: some View {
        let seam = seam
        FoldSplitLayout(axis: split.axis, primary: split.primary, gap: split.gap, primaryHidden: split.primaryHidden,
                        primaryParked: split.primaryParked, seam: seam) {
            tabs
            if split.shown {
                detail
                    .modifier(DuoSeamCloseEffect(enabled: closeWithHandle, progress: seam?.closeProgress ?? 0))
                    .transition(detailTransition)
            }
        }
    }

    /// The seam the layout places the columns around: under the finger or the
    /// spring, else where a pending slide-in starts, else none (at rest).
    private var seam: FoldSeam? {
        guard let context else { return nil }
        if let live = drag.live { return context.seam(live: live) }
        return slidePending ? context.slideInStart() : nil
    }
}
