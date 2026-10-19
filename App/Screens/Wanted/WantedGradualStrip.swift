import SwiftUI
import FusionhaKit

struct WantedGradualStrip: View {
    let itemId: Int
    let runId: Int
    let fallbackTotal: Int
    let interval: Int
    let onDone: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.actReduceMotion) private var reduce
    @State private var run: CommandRunDetail?
    @State private var stopping = false
    @State private var tickStamp = Date()

    var body: some View {
        let searching = run?.phase == "searching"
        let total = run?.progressTotal ?? fallbackTotal
        let current: Int? = searching ? run?.progressCurrent.map { $0 + 1 } : nil
        let detailText = run?.detail ?? ""
        let tail: String? = searching ? detailText.split(separator: "·").dropFirst().joined(separator: "·").trimmingCharacters(in: .whitespaces) : nil
        let pct = current.map { total > 0 ? min(1, Double($0) / Double(total)) : 0 } ?? 0
        HStack(spacing: 12) {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Theme.i2, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .background(Circle().stroke(Theme.i2.opacity(0.3), lineWidth: 2))
                .frame(width: 15, height: 15)
                .actSpin(true, duration: 0.8)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, interval - Int(context.date.timeIntervalSince(tickStamp)))
                let hasNext = current.map { $0 < total } ?? false
                (Text(current.map { "Searching episode \($0) of \(total)" } ?? "Starting gradual search…").foregroundColor(Theme.i2).fontWeight(.semibold)
                 + Text((tail.flatMap { $0.isEmpty ? nil : " · \($0)" } ?? "") + (hasNext && remaining > 0 ? " · next in \(remaining)s" : ""))
                    .foregroundColor(Theme.mut))
                    .font(.system(size: 12.5))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ActProgressBar(fraction: pct, height: 5, fill: AnyShapeStyle(Theme.i2), shimmer: false)
                .frame(width: 80)
            Button {
                stopping = true
                Task { try? await model.client?.cancelGradualSearch(itemId: itemId); stopping = false }
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.danger)
                    .frame(width: 28, height: 28)
                    .background(Theme.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Theme.danger.opacity(0.3)))
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .padding(.horizontal, -2).padding(.vertical, -2)
            }
            .buttonStyle(.plain)
            .disabled(stopping)
            .accessibilityLabel(stopping ? "Stopping gradual search" : "Stop gradual search")
        }
        .padding(.leading, 15)
        .padding(.trailing, 6)
        .padding(.vertical, 3)
        .background(Theme.i2.opacity(0.07))
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        .task(id: runId) {
            while !Task.isCancelled {
                do {
                    let detail = try await model.client?.systemRun(id: runId)
                    if detail?.progressCurrent != run?.progressCurrent || detail?.detail != run?.detail { tickStamp = Date() }
                    run = detail
                    if let status = detail?.status, status != "running" { onDone(); return }
                } catch {
                    onDone()
                    return
                }
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }
}

/// A 1pt dashed separator (`border-bottom: 1px dashed var(--line)`).
struct WantedDashedLine: View {
    var body: some View {
        Line()
            .stroke(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(height: 1)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return p
        }
    }
}
