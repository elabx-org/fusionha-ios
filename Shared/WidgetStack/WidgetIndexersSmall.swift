import SwiftUI
import WidgetKit
import FusionhaKit

/// Indexers, small: the 7-day success ring, and how many are healthy or
/// backing off.
struct WidgetIndexersSmall: View {
    let summary: WidgetIndexerSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetTopBar(title: "Indexers", figure: figure, tint: tint)
            Spacer(minLength: 6)
            HStack(spacing: 10) {
                WidgetRing(fraction: Double(summary.successPercent ?? 0) / 100, tint: Theme.done, lineWidth: 7) {
                    WidgetRingLabel(percent: summary.successPercent, size: 16)
                }
                .frame(width: 66, height: 66)
                Text("7-day\nsuccess").font(WidgetStyle.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 6)
            status
        }
    }

    @ViewBuilder
    private var status: some View {
        let flagged = summary.flagged.count
        if flagged > 0 {
            WidgetDotLine(color: Theme.stuck, text: "\(flagged) need\(flagged == 1 ? "s" : "") attention")
        } else {
            WidgetDotLine(color: Theme.done, text: "All healthy")
        }
    }

    private var figure: String? { summary.total > 0 ? "\(summary.healthy)/\(summary.total)" : nil }
    private var tint: Color { summary.healthy < summary.total ? Theme.stuck : Theme.done }
}
