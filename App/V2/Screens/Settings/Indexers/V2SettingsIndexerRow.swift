import SwiftUI
import FusionhaKit

/// One indexer in its priority group (mock `.ixv-row`): the tile with the
/// state dot, the name with its protocol and what only it found, and one
/// line of facts: grabs in the range (▲ in 24 h), success and queries
/// today, or why it is backing off. A test in flight or its result shows
/// on the line. The trailing switch is v1's (search and RSS together); on
/// the open Duo's list the row is selected instead and shows a chevron.
struct V2SettingsIndexerRow: View {
    let metric: IndexerMetric
    let color: Color
    let result: ConnectionTestResult?
    let testing: Bool
    var selected = false
    /// The open Duo's list: a chevron and no switch (the detail has it).
    var chevron = false
    /// Room for the "n only here" tag.
    var roomy = false
    let onToggle: (Bool) -> Void
    let open: () -> Void
    @Environment(\.pagePalette) private var page

    private var indexer: SearchIndexerInfo { metric.indexer }
    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }
    private var exclusive: Int { metric.stat?.exclusive?.total ?? 0 }

    var body: some View {
        HStack(spacing: 6) {
            // The row opens the detail; the switch beside it stays its own
            // control (a switch inside a button's label takes no taps).
            Button(action: open) {
                HStack(spacing: 12) {
                    V2IndexerTile(name: indexer.displayName, color: color, state: metric.state)
                    VStack(alignment: .leading, spacing: 3) {
                        nameLine
                        factLine
                    }
                    Spacer(minLength: 0)
                    if chevron {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.dim)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows what it found, what it can search and its settings")
            if !chevron {
                Toggle("Enable \(indexer.displayName)", isOn: Binding(get: { indexer.isEnabled }, set: onToggle))
                    .labelsHidden()
                    .tint(Theme.indigo)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .background(ink.opacity(selected ? 0.08 : 0))
        .opacity(metric.state == "disabled" ? 0.55 : 1)
    }

    private var nameLine: some View {
        HStack(spacing: 6) {
            Text(indexer.displayName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ink)
                .lineLimit(1)
            V2IndexerProtocolTag(isTorrent: indexer.isTorrent)
            if metric.isNew { tag("NEW", Theme.done) }
            if roomy && exclusive > 0 { tag("\(exclusive) only here", Theme.accentText) }
        }
    }

    @ViewBuilder
    private var factLine: some View {
        Group {
            if testing {
                Text("Testing…").foregroundStyle(muted)
            } else if let result, !result.ok {
                Text("Test failed · \(result.message)").foregroundStyle(Theme.danger)
            } else if metric.state == "backoff" {
                Text("Backing off" + (metric.stat?.health.lastFailureReason.map { " · \($0)" } ?? ""))
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.stuck)
            } else {
                facts
            }
        }
        .font(.system(size: 12.5).monospacedDigit())
        .lineLimit(1)
    }

    /// "173 grabs ▲26 · 99.9% · 1,060 q" (and "Connected" after a test).
    private var facts: Text {
        var line = Text(FetchFormat.grouped(metric.grabsRange)).fontWeight(.semibold).foregroundColor(ink)
            + Text(" grabs").foregroundColor(muted)
        if metric.grabs24h > 0 {
            line = line + Text(" ▲\(metric.grabs24h)").fontWeight(.semibold).foregroundColor(Theme.done)
        }
        if let success = metric.stat?.successRateRange {
            line = line + Text(" · " + String(format: "%.1f%%", success * 100)).foregroundColor(muted)
        }
        if let today = metric.stat?.queriesToday {
            line = line + Text(" · \(FetchFormat.grouped(today)) q").foregroundColor(muted)
        }
        if result?.ok == true {
            line = line + Text(" · Connected").fontWeight(.semibold).foregroundColor(Theme.done)
        }
        return line
    }

    private func tag(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .lineLimit(1)
            .fixedSize()
    }
}
