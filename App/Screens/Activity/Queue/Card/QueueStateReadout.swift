import SwiftUI
import FusionhaKit

/// The state's readout or primary action, left of the icon actions (web
/// `bodyAndReadout`): % · time left · speed for a real transfer, the stage
/// ring for a phase job, retry and failure rings, and Search again for a
/// stuck or failed download.
struct QueueStateReadout: View {
    let item: QueueItem
    let mode: QueueCardMode
    let telemetry: QueueTelemetry?
    let search: () -> Void

    var body: some View {
        switch mode {
        case .bytes:
            big("\(item.pct)%", item.stalled ? "stalled"
                : "\(telemetry?.eta.map { "\(ActFmt.etaShort($0)) left" } ?? "time left unknown") · \(ActFmt.rate(telemetry?.bps ?? 0))")
        case .phase:
            if let ring = QueueRail.ring(item.stages) {
                ringRow(ring, tone: nil, title: QueueRail.stageLabel(item.stages?.current),
                        sub: item.stages?.current == "linking" && item.stages?.linkingTotal != nil
                            ? "stage \(ring.done + 1) of \(ring.total)" : "working…")
            }
        case .retrying:
            ringRow(QueueRail.ring(item.stages), tone: nil, title: "Retrying",
                    sub: item.stages?.current.map { "at \(QueueRail.stageLabel($0).lowercased())" } ?? "decypharr will try again")
        case .failed:
            HStack(spacing: 12) {
                if let ring = QueueRail.ring(item.stages) {
                    ringRow(ring, tone: Theme.danger,
                            title: item.stages?.current.map { "Failed at \(QueueRail.stageLabel($0).lowercased())" } ?? "Failed",
                            sub: "stopped at \(ring.done) of \(ring.total)")
                }
                searchAgain(primary: false)
            }
        case .stuck:
            searchAgain(primary: true)
        case .importing:
            big("Importing", "Usually under a minute", small: true)
        case .waiting:
            big("Waiting", "for the download client", small: true)
        case .other, .held:
            EmptyView()
        }
    }

    private func big(_ value: String, _ sub: String, small: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: small ? 17 : 22, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.txt)
                .contentTransition(.numericText())
            Text(sub).font(.system(size: 13)).foregroundStyle(Theme.mut).lineLimit(1)
        }
    }

    @ViewBuilder
    private func ringRow(_ ring: (done: Int, total: Int)?, tone: Color?, title: String, sub: String) -> some View {
        HStack(spacing: 10) {
            if let ring { QueueStageRing(done: ring.done, total: ring.total, tone: tone ?? Theme.grab) }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(tone ?? Theme.txt)
                Text(sub).font(.system(size: 13)).foregroundStyle(Theme.mut)
            }
        }
    }

    private func searchAgain(primary: Bool) -> some View {
        Button(action: search) {
            Label("Search again", systemImage: "magnifyingglass").frame(maxWidth: primary ? .infinity : nil)
        }
        .buttonStyle(ActButtonStyle(kind: primary ? .primary : .subtle, small: !primary))
    }
}

/// Finished stages out of those that run, as a ring with "3/6" inside.
struct QueueStageRing: View {
    let done: Int
    let total: Int
    var tone: Color = Theme.grab
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        let frac = total > 0 ? min(1, Double(done) / Double(total)) : 0
        ZStack {
            Circle().stroke(Theme.txt.opacity(0.12), lineWidth: 4)
            Circle()
                .trim(from: 0, to: frac)
                .stroke(tone, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduce ? nil : ActMotion.fill, value: frac)
            Text("\(done)/\(total)").font(.system(size: 11, weight: .bold).monospacedDigit()).foregroundStyle(Theme.txt)
        }
        .frame(width: 44, height: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) of \(total) stages done")
    }
}
