import SwiftUI
import FusionhaKit

/// The split handle's hand-over to the shell once the seam's spring stops
/// (`V2SplitHandle.settle`).
@MainActor
enum V2SeamCommit {
    /// The seam is at `stop`: the shell takes over at rest, in one frame.
    ///
    /// A title that slid in over the Library at its full width lands first:
    /// the shell's rest re-flows the whole Library grid to its split width
    /// (about 100 ms on the open Duo), and done in the landing frame that
    /// stall ended the slide in a lurch (local Duo run, 2026-11-18). So the
    /// seam holds where it landed, the Library still full width under the
    /// title, for two frames; then the shell takes over with nothing moving.
    /// A drag begun in between takes the seam and the hand-over is dropped.
    static func commit(_ stop: DuoSeam.Stop, context: DuoSeamContext, share: Double? = nil, at landed: CGFloat) {
        PerfCount.mark("seam.commit")
        guard context.drag.listFull, stop != .closed else { return restAt(stop, context: context, share: share) }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(34))
            guard context.drag.live == landed, context.drag.listFull else { return }
            restAt(stop, context: context, share: share)
        }
    }

    private static func restAt(_ stop: DuoSeam.Stop, context: DuoSeamContext, share: Double?) {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            if let share { context.setShare(share) }
            switch stop {
            case .fullWidth: context.setFullWidth(true)
            case .split: context.setFullWidth(false)
            case .closed: context.close()
            }
            context.drag.live = nil
            context.drag.listFull = false
        }
    }
}
