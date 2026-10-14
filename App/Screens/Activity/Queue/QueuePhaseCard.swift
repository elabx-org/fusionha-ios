import SwiftUI
import FusionhaKit

// MARK: - Phase card (Working / Retrying)

struct PhaseCard: View {
    let item: QueueItem
    let lane: QueueLane
    let actions: QueueRowActions

    var body: some View {
        let meta = item.phaseMeta
        HStack(alignment: .top, spacing: 12) {
            ActPoster(url: item.posterUrl, title: item.title, size: .sm)
            VStack(alignment: .leading, spacing: 6) {
                QueueHead(item: item)
                ReleaseLine(text: item.releaseTitle)
                PhaseReadout(item: item)
                HStack(spacing: 6) {
                    Image(systemName: "sparkle").font(.system(size: 10)).foregroundStyle(meta.tone)
                        .actSpin(meta.indeterminate && lane == .working, duration: 0.9)
                    Text(QueueLogic.noteLine(item)).font(.system(size: 11.5)).foregroundStyle(Theme.mut).lineLimit(2)
                }
                if item.phase == "linking", let linking = QueueRules.linking(step: item.step) {
                    HStack(spacing: 8) {
                        ActProgressBar(fraction: linking.fraction, height: 4, fill: AnyShapeStyle(Theme.grab))
                        Text("\(linking.label) files").font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Theme.mut)
                    }
                } else {
                    HStack(spacing: 8) {
                        ActIndeterminateBar(color: meta.tone, height: 4)
                        Text("working · no ETA").font(.system(size: 10.5)).foregroundStyle(Theme.dim).fixedSize()
                    }
                }
                if lane == .retrying, let reason = item.terminalReason ?? item.warning {
                    Text("Failed at \(meta.statBig) — \(reason)")
                        .font(.system(size: 11.5)).foregroundStyle(Theme.danger)
                }
                HStack {
                    Text("\(ActFmt.bytes(item.size))").font(.system(size: 11)).foregroundStyle(Theme.mut)
                    Spacer(minLength: 0)
                    QueueActionsView(item: item, actions: actions,
                                     primary: lane == .retrying ? QueuePrimary(icon: "magnifyingglass", label: "Retry", run: actions.search) : nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .actWash(QueueLogic.wash(item))
    }
}

/// The mobile `PhaseReadout`: phase name in its tone, "step N of M", a climb rail.
struct PhaseReadout: View {
    let item: QueueItem
    var ghost = false
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        let state = QueueRules.state(protocol: item.protocol, phase: item.phase, phaseTerminal: item.phaseTerminal,
                                     lastSeenPhase: QueuePhaseMemory.last[item.id])
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
                    Text("step \(index + 1) of \(rail.count)").font(.system(size: 11)).foregroundStyle(Theme.dim)
                }
            }
            HStack(spacing: 3) {
                ForEach(rail.indices, id: \.self) { i in
                    Capsule()
                        .fill(i < index ? meta.tone.opacity(0.85) : (i == index ? meta.tone : Theme.txt.opacity(0.09)))
                        .overlay { if i == index && !ghost { ActShimmer() } }
                        .clipShape(Capsule())
                        .frame(height: 4)
                }
            }
            .animation(reduce ? nil : ActMotion.fill, value: index)
        }
    }
}
