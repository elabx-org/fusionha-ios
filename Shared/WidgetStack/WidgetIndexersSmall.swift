import SwiftUI
import WidgetKit
import FusionhaKit

/// Indexers, small: `8/9 healthy` big, and the first one needing attention
/// (`NZBPlanet backing off`) or `All healthy`.
struct WidgetIndexersSmall: View {
    let summary: WidgetIndexerSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetTopBar(title: "Indexers")
            Spacer(minLength: 4)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(summary.healthy)").font(WidgetStyle.numeral(44)).widgetAccentable()
                Text("/\(summary.total)").font(WidgetStyle.numeral(22)).foregroundStyle(.secondary)
            }
            Text("healthy").font(WidgetStyle.caption).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            status
        }
    }

    @ViewBuilder
    private var status: some View {
        if let flag = summary.flagged.first {
            WidgetDotLine(color: Theme.stuck, text: "\(flag.name) \(flag.detail)")
        } else if let rate = summary.successPercent {
            WidgetDotLine(color: Theme.done, text: "All healthy · \(rate)% success")
        } else {
            WidgetDotLine(color: Theme.done, text: "All healthy")
        }
    }
}
