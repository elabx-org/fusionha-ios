import SwiftUI
import FusionhaKit

/// Today / 7 days and the history pills (web `IdlePills`, mock `.segmini` +
/// `.pills`). The range switch is a native segmented picker; each pill opens
/// History. A missing summary shows quiet dashes so the strip keeps its height.
struct IdleRangePicker: View {
    @Binding var range: IdleRange

    var body: some View {
        Picker("Range", selection: $range) {
            ForEach(IdleRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .fixedSize()
    }
}

enum IdleRange: String, CaseIterable { case today = "Today", week = "7 days" }

struct IdlePillRow: View {
    let history: IdleSummary.History?
    let range: IdleRange
    var compact = false
    let openHistory: () -> Void
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        let counts = history.map { range == .today ? $0.today : $0.week }
        HStack(spacing: compact ? 5 : 6) {
            pill(counts?.grabbed, "grabbed", Theme.grab)
            pill(counts?.imported, "imported", Theme.done)
            pill(counts?.failed, "failed", Theme.danger)
        }
    }

    private func pill(_ value: Int?, _ label: String, _ tone: Color) -> some View {
        Button(action: openHistory) {
            HStack(spacing: 5) {
                Text(value.map { $0.formatted() } ?? "—")
                    .font(.system(size: compact ? 11.5 : 12.5, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .contentTransition(reduce ? .identity : .numericText())
                    .animation(reduce ? nil : .snappy, value: value)
                Text(label).font(.system(size: compact ? 11.5 : 12, weight: .semibold))
            }
            .foregroundStyle(tone)
            .lineLimit(1)
            .padding(.horizontal, compact ? 9 : 11)
            .padding(.vertical, compact ? 4 : 5)
            .background(Capsule().fill(Theme.panel2).overlay(Capsule().fill(tone.opacity(0.14))))
            .overlay(Capsule().strokeBorder(tone.opacity(0.3)))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .fixedSize()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(value.map(String.init) ?? "No") \(label), open History")
    }
}
