import SwiftUI
import WidgetKit
import FusionhaKit

/// Indexers: healthy / backing off / 7d success tiles, a summary line, the
/// busiest indexers with their activity, and the ones backing off or unavailable.
struct WidgetIndexersPage: View {
    let summary: WidgetIndexerSummary?
    let large: Bool

    var body: some View {
        if let s = summary {
            VStack(alignment: .leading, spacing: large ? 8 : 5) {
                HStack(spacing: 6) {
                    WidgetStatTile(value: "\(s.healthy)", label: "Healthy", color: Theme.done)
                    WidgetStatTile(value: "\(s.backingOff)", label: "Backing off", color: Theme.stuck)
                    WidgetStatTile(value: s.successPercent.map { "\($0)%" } ?? "–", label: "7d success", color: Theme.grab)
                }
                Text(s.line)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                ForEach(Array(rows(s).enumerated()), id: \.offset) { _, row in
                    WidgetIndexerLine(row: row)
                }
                ForEach(Array(flags(s).enumerated()), id: \.offset) { _, flag in
                    WidgetIndexerFlagLine(flag: flag)
                }
            }
        } else {
            WidgetEmptyText("Indexer stats unavailable")
        }
    }

    /// Medium keeps one row for a flagged indexer when there is one.
    private func rows(_ s: WidgetIndexerSummary) -> [WidgetIndexerRow] {
        Array(s.top.prefix(large ? 4 : (s.flagged.isEmpty ? 2 : 1)))
    }

    private func flags(_ s: WidgetIndexerSummary) -> [WidgetIndexerFlag] {
        Array(s.flagged.prefix(large ? 2 : 1))
    }
}

struct WidgetIndexerLine: View {
    let row: WidgetIndexerRow

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(row.healthy ? Theme.done : Theme.stuck).frame(width: 6, height: 6)
            Text(row.name).font(.system(size: 11, weight: .semibold)).lineLimit(1)
            Spacer(minLength: 4)
            WidgetSparkBars(values: row.series, color: Theme.grab)
                .frame(width: 44, height: 14)
            Text(row.successPercent.map { "\($0)%" } ?? "–")
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

struct WidgetIndexerFlagLine: View {
    let flag: WidgetIndexerFlag

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9))
                .foregroundStyle(Theme.stuck)
            Text(flag.name).font(.system(size: 11, weight: .semibold)).lineLimit(1)
            Text(flag.detail).font(.system(size: 10)).foregroundStyle(Theme.stuck).lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}
