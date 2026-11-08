import SwiftUI
import FusionhaKit

/// A titled W1 card on the indexer detail (mock `.ixv-card`).
struct V2IndexerCard<Content: View>: View {
    let title: String
    var trailing: String?
    @ViewBuilder var content: Content
    @Environment(\.pagePalette) private var page

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title).foregroundStyle(page?.inkMuted ?? Theme.mut)
                Spacer(minLength: 8)
                if let trailing { Text(trailing).monospacedDigit().foregroundStyle(page?.ink ?? Theme.txt) }
            }
            .font(.system(size: 13, weight: .semibold))
            .accessibilityElement(children: .combine)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2CardStyle(padding: 14)
    }
}

/// The detail's four stats (mock `.ixv-grid`): grabs, grab share, yield and
/// success, each with its second line.
struct V2IndexerStatGrid: View {
    let metric: IndexerMetric

    var body: some View {
        let stat = metric.stat
        let exclusive = stat?.exclusive?.total ?? 0
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                V2IndexerStatCell(title: "Grabs", value: FetchFormat.grouped(metric.grabsRange),
                                  up: metric.grabs24h > 0 ? "▲\(metric.grabs24h) today" : nil,
                                  note: stat?.grabsTotal.map { "\(FetchFormat.grouped($0)) all time" } ?? "in this range")
                V2IndexerStatCell(title: "Grab share", value: String(format: "%.1f", metric.share), unit: "%",
                                  note: exclusive > 0 ? "\(exclusive) release\(exclusive == 1 ? "" : "s") only here" : "nothing only here")
            }
            GridRow {
                V2IndexerStatCell(title: "Yield", value: String(format: "%.1f", metric.yieldValue), unit: "/100 q",
                                  note: "grabs per 100 queries")
                V2IndexerStatCell(title: "Success", value: metric.successPct.map(String.init) ?? "—",
                                  unit: metric.successPct == nil ? nil : "%",
                                  note: stat?.queriesToday.map { "\(FetchFormat.grouped($0)) queries today" } ?? "no queries today")
            }
        }
    }
}

struct V2IndexerStatCell: View {
    let title: String
    let value: String
    var unit: String?
    var up: String?
    let note: String
    @Environment(\.pagePalette) private var page

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 24, weight: .bold).monospacedDigit()).foregroundStyle(page?.ink ?? Theme.txt)
                if let unit {
                    Text(unit).font(.system(size: 13, weight: .semibold)).foregroundStyle(page?.inkMuted ?? Theme.mut)
                }
                if let up {
                    Text(up).font(.system(size: 12.5, weight: .bold)).foregroundStyle(Theme.done).padding(.leading, 4)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Text(note)
                .font(.system(size: 11.5))
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2CardStyle(padding: 13)
        .accessibilityElement(children: .combine)
    }
}

/// Queries per bucket across the range (mock "Queries · last 7 days"): one
/// column per bucket in the indexer's colour, the latest at full strength.
struct V2IndexerActivityCard: View {
    let metric: IndexerMetric
    let color: Color
    let range: IndexerRange

    var body: some View {
        let values = metric.activity
        let peak = max(values.max() ?? 0, 1)
        V2IndexerCard(title: "Queries · \(range.phrase)",
                      trailing: values.isEmpty ? nil : FetchFormat.grouped(values.reduce(0, +))) {
            if values.isEmpty {
                Text("No activity in this range.").font(.footnote).foregroundStyle(Theme.mut)
            } else {
                HStack(alignment: .bottom, spacing: values.count > 14 ? 2 : 6) {
                    ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                        RoundedRectangle(cornerRadius: values.count > 14 ? 2 : 4, style: .continuous)
                            .fill(index == values.count - 1 ? color : color.opacity(0.45))
                            .frame(height: max(4, CGFloat(value) / CGFloat(peak) * 48))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 50, alignment: .bottom)
                .accessibilityElement()
                .accessibilityLabel("Query activity, peak \(FetchFormat.grouped(values.max() ?? 0)) per bucket")
            }
        }
    }
}
