import SwiftUI
import FusionhaKit

/// The queue's pipeline line (web `PipelineStrip`): idle in one line, running
/// as a summed strip of the nine stages (decypharr's eight plus Importing). A
/// stage this install skips reads "off"; failures read "1 failed at parsing".
/// A solid panel; on a narrow pane the stage names give way to their counts.
struct PipelineHero: View {
    let items: [QueueItem]
    /// Live MB/s summed over genuine byte transfers.
    let aggregateBps: Double
    let hasPhaseWork: Bool
    /// "Last import …" for the idle line (0.4.189 `pipeline.last_import`).
    var lastImport: QueuePipeline.LastImport? = nil
    @State private var width: CGFloat = 0

    var body: some View {
        let m = QueuePipelineModel(items)
        let last = QueuePipelineModel.lastImportLine(lastImport)
        let narrow = width > 0 && width < 720
        VStack(alignment: .leading, spacing: 10) {
            header(m, last: last, narrow: narrow)
            if m.running {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(m.columns) { column($0, narrow: narrow) }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Jobs per stage")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.line))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pipeline")
    }

    private func header(_ m: QueuePipelineModel, last: String?, narrow: Bool) -> some View {
        let right: String? = m.fullDownloads > 0
            ? "Full downloads: \(m.fullDownloads) · \(ActFmt.rate(aggregateBps))"
            : (narrow ? nil : last)
        return ActFlow(spacing: 8, lineSpacing: 4) {
            HStack(spacing: 8) {
                if m.running {
                    ActPulseDot(color: Theme.grab, size: 8, spread: 6)
                } else {
                    Circle().fill(Theme.dim).frame(width: 8, height: 8).accessibilityHidden(true)
                }
                Text(m.running ? "Pipeline" : "Pipeline idle").fontWeight(.semibold).foregroundStyle(Theme.txt)
            }
            Text("· \(m.jobs) job\(m.jobs == 1 ? "" : "s")\(m.failed.map { " · \($0)" } ?? "")")
                .monospacedDigit()
                .foregroundStyle(Theme.mut)
            if let right {
                Text(right).font(.system(size: 12.5).monospacedDigit()).foregroundStyle(Theme.dim)
            }
        }
        .font(.system(size: 13))
    }

    private func column(_ c: QueuePipelineModel.Column, narrow: Bool) -> some View {
        let active = c.count > 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                if !narrow {
                    Text(c.label.uppercased())
                        .font(.system(size: 11))
                        .tracking(0.6)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(active ? Theme.txt : Theme.dim)
                        .layoutPriority(-1)
                }
                if active {
                    Text("\(c.count)")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Theme.grab)
                        .padding(.horizontal, 6)
                        .background(Theme.grab.opacity(0.2), in: Capsule())
                }
            }
            .frame(minHeight: 16)
            bar(active: active, off: c.off)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(c.off ? 0.5 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(c.label): \(c.off ? "turned off in decypharr" : "\(c.count) job\(c.count == 1 ? "" : "s")")")
    }

    @ViewBuilder
    private func bar(active: Bool, off: Bool) -> some View {
        if off {
            PipelineDash()
                .stroke(Theme.txt.opacity(0.14), style: StrokeStyle(lineWidth: 4, dash: [4, 3]))
                .frame(height: 4)
        } else {
            Capsule()
                .fill(active ? Theme.i1 : Theme.txt.opacity(0.14))
                .frame(height: 4)
        }
    }
}

/// A skipped stage: a dashed hairline instead of a bar.
private struct PipelineDash: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
