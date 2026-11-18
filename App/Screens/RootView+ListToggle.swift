import SwiftUI
import FusionhaKit

extension RootView {
    /// The sidebar button's action for the detail column: offered flat open
    /// with a title or preview beside the list (`DuoSplit.hidesList`).
    func listToggle(_ split: ShellSplit) -> DuoListToggle? {
        guard split.shown, split.axis == .horizontal, fold.posture?.canHideList == true,
              model.rightPageHasItem,
              !episodeBeside(split, spread: spreadContext(fold, hasItem: true)) else { return nil }
        let key = model.tab.listMemoryKey
        let showing = split.primaryHidden
        return DuoListToggle(hidden: split.primaryHidden, key: key) {
            // The list slides in and out at its split width: un-park it first,
            // unanimated (off screen). It is parked again only when the right
            // page empties (below): parking it after each hide re-flowed the
            // grid once more than before (perf runs 42810163466 / 42810167912,
            // seam.full hang 449 -> 979 ms).
            var instant = Transaction()
            instant.disablesAnimations = true
            let wasParked = listParked
            withTransaction(instant) { listParked = false }
            // The title swaps layouts (one column, or the band over two): it
            // blurs through rather than crossfading two layouts (`ShellCover`;
            // the seam's landing comes through here too).
            let motion = !reduceMotion && model.animationsEnabled
            let flip = {
                ShellCover.blurThrough(motion: motion) {
                    var memory = DuoListMemory(raw: hiddenLists)
                    memory.toggle(key)
                    hiddenLists = memory.raw
                }
            }
            // The handle's own commit lands in one frame; the button waits a
            // frame for the un-parked list to lay out before it slides in.
            guard showing, wasParked, seam.live == nil else {
                flip()
                return
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(40))
                flip()
            }
        }
    }
}
