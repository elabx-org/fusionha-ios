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
                        .foregroundStyle(LinearGradient(colors: [Theme.grab.opacity(0.4), Theme.grab.opacity(0)], startPoint: .top, endPoint: .bottom))
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

struct PipelineHero: View {
    let items: [QueueItem]
    let aggregateBps: Double
    let hasPhaseWork: Bool
    /// "Last import …" for the idle line (0.4.189 `pipeline.last_import`).
    var lastImport: QueuePipeline.LastImport? = nil
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        let dist = QueueLogic.stageDistribution(items)
        let wf = QueueLogic.workingFailed(items)
        let real = items.filter(\.isByteTransferring).count
        let activeIdx = dist.indices.filter { dist[$0] > 0 }.max() ?? -1
        let current = activeIdx >= 0 ? QueueLogic.heroStages[activeIdx] : nil
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pipeline").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt)
                    (Text("\(ActFmt.plural(wf.working, "job"))\(current.map { " · \($0.lowercased())" } ?? "")")
                     + Text(real > 0 ? " · \(real) downloading · \(ActFmt.mbps(aggregateBps)) MB/s" : "").foregroundColor(Theme.grab)
                     + Text(wf.failed > 0 ? " · \(wf.failed) failed · will retry" : "").foregroundColor(Theme.miss))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.mut)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    (Text("Step \(activeIdx + 1)").foregroundColor(Theme.txt) + Text("/\(QueueLogic.heroStages.count)").foregroundColor(Theme.dim))
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                    Text(current?.lowercased() ?? "idle").font(.system(size: 11)).foregroundStyle(Theme.mut)
                }
            }
            HStack(spacing: 4) {
                ForEach(QueueLogic.heroStages.indices, id: \.self) { i in
                    let state = dist[i] > 0 ? 2 : (i < activeIdx ? 1 : 0)
                    Capsule()
                        .fill(state == 2 ? Theme.grab : (state == 1 ? Theme.indigo.opacity(0.7) : Theme.txt.opacity(0.08)))
                        .overlay { if state == 2 { ActShimmer() } }
                        .clipShape(Capsule())
                        .frame(height: 5)
                }
            }
            .animation(reduce ? nil : ActMotion.fill, value: dist)
            ActFlow(spacing: 12, lineSpacing: 6) {
                ForEach(QueueLogic.heroStages.indices, id: \.self) { i in
                    let active = dist[i] > 0
                    let state = active ? 2 : (i < activeIdx ? 1 : 0)
                    Group {
                        HStack(spacing: 5) {
                            if active {
                                ActPulseDot(color: Theme.grab, size: 6, spread: 4)
                            } else {
                                Circle().fill(state == 1 ? Theme.indigo : Theme.txt.opacity(0.15)).frame(width: 6, height: 6)
                            }
                            if active {
                                Text(QueueLogic.heroStages[i]).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.txt)
                                Text("\(dist[i])").font(.system(size: 11, weight: .bold).monospacedDigit()).foregroundStyle(Theme.bg)
                                    .padding(.horizontal, 5).background(Theme.grab, in: Capsule())
                            }
                        }
                    }
                }
            }
            if wf.working == 0, let last = lastImport {
                (Text("Pipeline idle · Last import ") + Text(last.title).foregroundColor(Theme.txt)
                 + Text(last.episodeLabel.map { " \($0)" } ?? "")
                 + Text(" · \(ActFmt.relative(last.at))"))
                    .font(.system(size: 11)).foregroundStyle(Theme.dim)
                    .lineLimit(1)
            } else {
                Text(hasPhaseWork ? "symlink jobs finish in seconds — no time ETA" : "waiting for a free download slot")
                    .font(.system(size: 11)).italic().foregroundStyle(Theme.dim)
            }
        }
        .padding(14)
        .background(
            LinearGradient(colors: [Theme.indigo.opacity(0.06), Theme.panel], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
    }
}
