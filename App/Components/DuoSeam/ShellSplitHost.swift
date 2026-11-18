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
    /// The open title, for the parked-title release below.
    let openId: Int?
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
        // A title parked for its slide-in whose handle never came (the owner's
        // "opens only partly, stuck at the right", builds 1239-1241): after
        // 1.2 s the shell stops waiting and shows it at rest.
        .task(id: slidePending ? openId : nil) {
            guard slidePending, let openId else { return }
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled, drag.live == nil, !drag.handleShown else { return }
            HangRecorder.stuck("title \(openId) parked for its slide-in with no handle; shown at rest")
            drag.parkedReleased = openId
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
