import SwiftUI
import Charts
import FusionhaKit

// MARK: Drawing

/// A stacked horizontal bar of proportional segments that grow in on appear.
struct IndexerSplitBar: View {
    let parts: [(Double, Color)]
    var gap: CGFloat = 2
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var shown = false

    var body: some View {
        GeometryReader { geo in
            let total = max(parts.reduce(0) { $0 + max($1.0, 0) }, 0.0001)
            let usable = geo.size.width - gap * CGFloat(max(parts.count - 1, 0))
            HStack(spacing: gap) {
                ForEach(parts.indices, id: \.self) { i in
                    Capsule()
                        .fill(parts[i].1)
                        .frame(width: max(0, usable * CGFloat(max(parts[i].0, 0) / total)))
                        .scaleEffect(x: motionOff || shown ? 1 : 0, anchor: .leading)
                        .animation(motionOff ? nil : .easeOut(duration: 0.5).delay(Double(i) * 0.06), value: shown)
                }
            }
        }
        .background(Capsule().fill(Theme.txt.opacity(0.06)))
        .clipShape(Capsule())
        .onAppear { shown = true }
    }
}

/// The small draw-in sparkline: a gradient area under a line with an end dot.
struct IndexerSparkline: View {
    let values: [Int]
    var color: Color = Theme.cyan
    var delay: Double = 0
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            ZStack {
                if pts.count > 0 {
                    area(pts, size: geo.size)
                        .fill(LinearGradient(colors: [color.opacity(0.45), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .opacity(Double(progress))
                    line(pts)
                        .trim(from: 0, to: progress)
                        .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    if let end = pts.last {
                        Circle().fill(color).frame(width: 4.4, height: 4.4).position(end).opacity(Double(progress))
                    }
                }
            }
        }
        .onAppear {
            if motionOff { progress = 1 } else {
                withAnimation(.easeOut(duration: 0.9).delay(delay)) { progress = 1 }
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let maxV = Double(max(values.max() ?? 1, 1))
        return values.enumerated().map { i, v in
            let x = values.count > 1 ? CGFloat(i) / CGFloat(values.count - 1) * size.width : size.width / 2
            let y = size.height - CGFloat(Double(v) / maxV) * (size.height - 4) - 2
            return CGPoint(x: x, y: y)
        }
    }

    private func line(_ pts: [CGPoint]) -> Path {
        Path { p in
            p.move(to: pts[0])
            for pt in pts.dropFirst() { p.addLine(to: pt) }
        }
    }

    private func area(_ pts: [CGPoint], size: CGSize) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: size.height))
            for pt in pts { p.addLine(to: pt) }
            p.addLine(to: CGPoint(x: size.width, y: size.height))
            p.closeSubpath()
        }
    }
}

/// The wide fleet activity chart (Swift Charts): queries per bucket over the range.
struct IndexerActivityChart: View {
    let values: [Int]
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var shown = false

    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { i, v in
            AreaMark(x: .value("Bucket", i), y: .value("Queries", shown || motionOff ? v : 0))
                .interpolationMethod(.monotone)
                .foregroundStyle(LinearGradient(colors: [Theme.cyan.opacity(0.45), Theme.cyan.opacity(0)],
                                                startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Bucket", i), y: .value("Queries", shown || motionOff ? v : 0))
                .interpolationMethod(.monotone)
                .foregroundStyle(Theme.cyan)
                .lineStyle(StrokeStyle(lineWidth: 1.8))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...max(1, values.max() ?? 1))
        .onAppear {
            if !motionOff { withAnimation(.easeOut(duration: 0.8)) { shown = true } }
        }
        .accessibilityLabel("Query activity, peak \(values.max() ?? 0) per bucket")
    }
}

/// The avg-success ring in the KPI corner: green ≥ 90 %, amber below.
struct IndexerRing: View {
    let value: Int?
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var shown = false

    var body: some View {
        let v = Double(value ?? 0) / 100
        ZStack {
            Circle().stroke(Theme.txt.opacity(0.08), lineWidth: 4)
            Circle()
                .trim(from: 0, to: motionOff || shown ? v : 0)
                .stroke((value ?? 0) < 90 ? Theme.miss : Theme.done, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(2)
        .onAppear {
            if !motionOff { withAnimation(.easeOut(duration: 0.9)) { shown = true } }
        }
    }
}
