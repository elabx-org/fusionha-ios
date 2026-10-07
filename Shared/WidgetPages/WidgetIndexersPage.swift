import SwiftUI
import WidgetKit
import FusionhaKit

/// Indexers, medium and large: the 7-day success ring beside the busiest
/// indexers (each with its activity sparkline and success rate); flagged ones
/// (backing off, unavailable) take a row. Large adds the health tiles and the
/// grabs · queries line.
struct WidgetIndexersPage: View {
    let summary: WidgetIndexerSummary?
    let large: Bool

    var body: some View {
        if let s = summary {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 16) {
                    WidgetSuccessRing(percent: s.successPercent)
                        .frame(width: large ? 92 : 84, height: large ? 92 : 84)
                    if large { tiles(s) } else { list(s, rows: 3, flags: 1) }
                }
                if large {
                    Text(s.line).font(WidgetStyle.caption.monospacedDigit()).foregroundStyle(.secondary).lineLimit(1)
                    list(s, rows: 4, flags: 2)
                }
            }
        } else {
            WidgetStatusMessage(icon: "antenna.radiowaves.left.and.right", text: "Indexer stats unavailable")
        }
    }

    private func tiles(_ s: WidgetIndexerSummary) -> some View {
        VStack(spacing: 8) {
            WidgetStatTile(value: "\(s.healthy)", label: "Healthy", color: Theme.done)
            WidgetStatTile(value: "\(s.backingOff)", label: "Backing off", color: Theme.stuck)
        }
    }

    private func list(_ s: WidgetIndexerSummary, rows: Int, flags: Int) -> some View {
        let lines = s.lines(rows: rows, flags: flags, sharedSlots: !large)
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(zip(lines.rows, lines.notes).enumerated()), id: \.offset) { _, line in
                WidgetIndexerLine(row: line.0, note: line.1)
            }
            ForEach(Array(lines.flags.enumerated()), id: \.offset) { _, flag in
                WidgetIndexerFlagLine(flag: flag)
            }
        }
    }
}

/// The 7-day success rate as a ring.
struct WidgetSuccessRing: View {
    let percent: Int?

    var body: some View {
        WidgetRing(fraction: Double(percent ?? 0) / 100, tint: Theme.done, lineWidth: 7) {
            WidgetRingLabel(percent: percent, caption: "7d success")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("7-day success \(percent.map { "\($0) percent" } ?? "unknown")")
    }
}

/// One indexer: health dot, name (or its flag), the activity sparkline and its success rate.
struct WidgetIndexerLine: View {
    let row: WidgetIndexerRow
    var note: String?

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(row.healthy && note == nil ? Theme.done : Theme.stuck)
                .frame(width: 7, height: 7)
                .widgetAccentable()
            Text(row.name).font(WidgetStyle.title).lineLimit(1)
            if let note {
                Text(note).font(WidgetStyle.caption).foregroundStyle(Theme.stuck).lineLimit(1)
            }
            Spacer(minLength: 4)
            WidgetSparkBars(values: row.series, color: Theme.grab)
                .frame(width: 40, height: 14)
            Text(row.successPercent.map { "\($0)%" } ?? "–")
                .font(WidgetStyle.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}

struct WidgetIndexerFlagLine: View {
    let flag: WidgetIndexerFlag

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(Theme.stuck)
                .widgetAccentable()
            Text(flag.name).font(WidgetStyle.title).lineLimit(1)
            Text(flag.detail).font(WidgetStyle.caption).foregroundStyle(Theme.stuck).lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}
