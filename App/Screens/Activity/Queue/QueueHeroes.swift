import Charts
import SwiftUI
import FusionhaKit

// MARK: - Heroes

struct BandwidthPulseHero: View {
    let items: [QueueItem]
    let history: [Double]

    var body: some View {
        let current = history.last ?? 0
        let downloading = items.filter { [.downloading, .awaiting, .importing].contains($0.cockpitState) }.count
        let stalled = items.filter { $0.cockpitState == .stalled }.count
        let queued = items.filter { $0.cockpitState == .queued }.count
        let remaining = items.filter { [.downloading, .stalled, .awaiting].contains($0.cockpitState) && $0.size > 0 }
            .reduce(0) { $0 + max(0, $1.sizeleft) }
        let clears = remaining <= 0 ? "now" : (current > 0 ? "~\(ActFmt.etaApprox(remaining / current))" : "—")
        VStack(alignment: .leading, spacing: 8) {
            // The speed is the hero, in the display face; what's left sits beside it.
            HStack(alignment: .lastTextBaseline, spacing: 14) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(ActFmt.mbps(current))
                        .font(Theme.display(64))
                        .tracking(Theme.displayTracking(64))
                        .foregroundStyle(Theme.grab)
                        .contentTransition(.numericText(value: current))
                    Text("MB/s").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.mut)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(remaining > 0 ? "\(ActFmt.bytes(remaining)) left" : "Nothing left")
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.txt)
                    Text("clears \(clears)")
                        .font(.system(size: 13)).foregroundStyle(Theme.mut)
                }
                .lineLimit(1)
                .layoutPriority(-1)
            }
            ActFlow(spacing: 12, lineSpacing: 4) {
                if downloading > 0 || stalled > 0 {
                    HStack(spacing: 5) {
                        ActPulseDot(color: Theme.grab, size: 6, spread: 5)
                        Text("Live").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.grab)
                    }
                }
                stat(downloading, "downloading")
                if stalled > 0 { stat(stalled, "stalled") }
                stat(queued, "queued")
            }
            Chart {
                ForEach(Array(history.enumerated()), id: \.offset) { index, bps in
                    AreaMark(x: .value("t", index), y: .value("bps", bps))
                        .foregroundStyle(Theme.grab.opacity(0.18))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("t", index), y: .value("bps", bps))
                        .foregroundStyle(Theme.grab)
                        .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.monotone)
                }
                if let last = history.indices.last {
                    PointMark(x: .value("t", last), y: .value("bps", history[last]))
                        .foregroundStyle(Theme.grab).symbolSize(30)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartXScale(domain: 0...max(history.count - 1, 1))
            .frame(height: 64)
            // The trace runs to the screen edges, on the ground: content, not a card.
            .padding(.horizontal, -Theme.pageGutter)
        }
    }

    private func stat(_ n: Int, _ label: String) -> some View {
        (Text("\(n)").bold().foregroundColor(Theme.txt) + Text(" \(label)"))
            .font(.system(size: 13))
            .foregroundStyle(Theme.mut)
    }
}
