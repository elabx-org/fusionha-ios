import SwiftUI
import FusionhaKit

/// The Indexers insight module (History's `insight` anatomy): how many are
/// healthy and what is not, the fleet's query sparkline (one ink, the
/// latest bucket at full strength), then the window's key figures.
struct V2IndexerInsight: View {
    let summary: ActivityIndexerSummary
    let phrase: String
    @Environment(\.pagePalette) private var page

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(summary.healthy) of \(summary.indexers) healthy")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(page?.ink ?? Theme.txt)
                    Text(V2IndexerInsight.problems(summary))
                        .font(.system(size: 12))
                        .foregroundStyle(summary.backoff > 0 ? Theme.dangerText : (page?.inkMuted ?? Theme.mut))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let series = summary.activitySeries, !series.isEmpty {
                    V2InkSpark(values: series).frame(maxWidth: 170)
                }
            }
            HStack(alignment: .top) {
                V2KeyFigure(value: (summary.grabsRange ?? 0).formatted(), label: "grabs · \(phrase)")
                Spacer(minLength: 6)
                V2KeyFigure(value: (summary.queriesRange ?? 0).formatted(), label: "queries")
                Spacer(minLength: 6)
                V2KeyFigure(value: summary.avgSuccessRange.map { "\(Int(($0 * 100).rounded()))%" } ?? "–",
                            label: "avg success")
            }
        }
        .v2CardStyle(padding: 14)
        .accessibilityElement(children: .combine)
    }

    /// "none backing off" · "2 backing off · 1 off".
    static func problems(_ s: ActivityIndexerSummary) -> String {
        var parts = [s.backoff > 0 ? "\(s.backoff) backing off" : "none backing off"]
        if s.off > 0 { parts.append("\(s.off) off") }
        return parts.joined(separator: " · ")
    }
}

/// A one-ink bar sparkline: the last bar at full strength, the rest muted.
struct V2InkSpark: View {
    let values: [Int]
    var height: CGFloat = 40
    @Environment(\.badgeInk) private var inkOverride

    var body: some View {
        let ink = inkOverride ?? .page
        let peak = max(values.max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: values.count > 30 ? 1 : 3) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 1, bottomTrailingRadius: 1,
                                       topTrailingRadius: 2, style: .continuous)
                    .fill(index == values.count - 1 ? ink.fill : ink.fill.opacity(0.38))
                    .frame(height: max(3, height * CGFloat(value) / CGFloat(peak)))
            }
        }
        .frame(height: height, alignment: .bottom)
        .accessibilityHidden(true)
    }
}
