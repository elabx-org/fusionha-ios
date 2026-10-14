import SwiftUI
import FusionhaKit

// MARK: - Cockpit row (solo download)

struct QueueRowCard: View {
    let item: QueueItem
    let telemetry: QueueTelemetry?
    let soonest: Bool
    let actions: QueueRowActions
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        let state = item.cockpitState
        let pct = item.pct
        let fill: Color = state == .importing ? Theme.indigo : (state == .stalled ? Theme.miss : Theme.grab)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                PosterRing(item: item, pct: pct)
                VStack(alignment: .leading, spacing: 4) {
                    QueueHead(item: item, chip: state == .stalled ? ("Stalled", Theme.miss) : nil)
                    ReleaseLine(text: item.releaseTitle)
                    QueueMetaLine(item: item)
                    if let next = item.nextStep {
                        Text(next).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.mut)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            ActProgressBar(fraction: Double(pct) / 100, fill: state == .stalled ? AnyShapeStyle(Theme.miss)
                           : AnyShapeStyle(LinearGradient(colors: [Theme.grab.opacity(0.7), Theme.indigo, Theme.grab], startPoint: .leading, endPoint: .trailing)),
                           shimmer: state == .downloading)
            HStack(alignment: .lastTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(statBig(state))
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(state == .stalled ? Theme.miss : Theme.grab)
                        .contentTransition(.numericText())
                    Text("\(ActFmt.bytes(item.bytesDone)) / \(ActFmt.bytes(item.size)) · \(pct)%")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(Theme.mut)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(ActFmt.etaShort(telemetry?.eta))
                        .font(.system(size: 15, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.txt)
                    Text(etaKey(state).uppercased())
                        .font(.system(size: 9.5, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(Theme.dim)
                }
                Spacer(minLength: 0)
                QueueActionsView(item: item, actions: actions)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(alignment: .leading) {
            // `.cardfill`: the progress fill behind the content.
            GeometryReader { geo in
                LinearGradient(colors: [fill.opacity(0.05), fill.opacity(0.15)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: geo.size.width * CGFloat(pct) / 100)
                    .animation(reduce ? nil : ActMotion.fill, value: pct)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .actWash(QueueLogic.wash(item), border: soonest ? Theme.grab.opacity(0.45) : Theme.line)
        .shadow(color: soonest ? Theme.grab.opacity(0.18) : .clear, radius: 10)
        .accessibilityElement(children: .contain)
    }

    private func statBig(_ state: QueueCockpitState) -> String {
        switch state {
        case .stalled: return "Stalled"
        case .importing: return "Importing"
        default: return ActFmt.rate(telemetry?.bps ?? 0)
        }
    }

    private func etaKey(_ state: QueueCockpitState) -> String {
        if state == .importing { return "soon" }
        if (telemetry?.bps ?? 0) <= 0 { return "idle" }
        return "eta"
    }
}
