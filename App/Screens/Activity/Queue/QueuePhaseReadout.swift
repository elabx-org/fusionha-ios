import SwiftUI
import FusionhaKit

/// The mobile `PhaseReadout`: phase name in its tone, "step N of M", a climb rail.
struct PhaseReadout: View {
    let item: QueueItem
    var ghost = false
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        let state = item.stageState
        let rail = state.stages
        let index = ghost ? -1 : (state.current ?? -1)
        let meta = item.phaseMeta
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                if ghost {
                    Text("Waiting").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.mut)
                } else if index < 0 {
                    // A cold poll that is already errored: no stage position.
                    Text("Failed").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.danger)
                } else {
                    Text(state.failed ? "Failed at \(rail[index])" : rail[index])
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(state.failed ? Theme.danger : meta.tone)
                    Text("step \(min(state.completed + 1, state.runningTotal)) of \(state.runningTotal)")
                        .font(.system(size: 11)).foregroundStyle(Theme.dim)
                }
            }
            HStack(spacing: 3) {
                ForEach(rail.indices, id: \.self) { i in
                    // A stage this install skips stays greyed and dashed (the web's `runs: false`).
                    Capsule()
                        .fill(state.skipped.contains(i) ? Theme.txt.opacity(0.04)
                              : (i < index ? meta.tone.opacity(0.85) : (i == index ? meta.tone : Theme.txt.opacity(0.09))))
                        .overlay {
                            if state.skipped.contains(i) {
                                Capsule().strokeBorder(Theme.txt.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                            } else if i == index && !ghost { ActShimmer() }
                        }
                        .clipShape(Capsule())
                        .frame(height: 4)
                }
            }
            .animation(reduce ? nil : ActMotion.fill, value: index)
        }
    }
}
