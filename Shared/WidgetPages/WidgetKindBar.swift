import SwiftUI
import WidgetKit
import FusionhaKit

/// The web stats card's composition bar: movies, series and anime by title
/// count, in the kind colours, with an optional legend.
struct WidgetKindBar: View {
    let summary: WidgetLibrarySummary
    var showsLegend = true

    private var kinds: [(LibraryKind, Int)] {
        [(.movie, summary.movies), (.series, summary.series), (.anime, summary.anime)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            bar
            if showsLegend { legend }
        }
    }

    private var bar: some View {
        GeometryReader { geo in
            let total = max(CGFloat(kinds.reduce(0) { $0 + $1.1 }), 1)
            let free = max(geo.size.width - 4, 0)
            HStack(spacing: 2) {
                ForEach(kinds.indices, id: \.self) { index in
                    let pair = kinds[index]
                    if pair.1 > 0 {
                        Rectangle()
                            .fill(Theme.kind(pair.0))
                            .frame(width: free * CGFloat(pair.1) / total)
                    }
                }
            }
        }
        .frame(height: 8)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
        .widgetAccentable()
    }

    private var legend: some View {
        HStack(spacing: 10) {
            ForEach(kinds.indices, id: \.self) { index in
                let pair = kinds[index]
                HStack(spacing: 4) {
                    Circle().fill(Theme.kind(pair.0)).frame(width: 6, height: 6)
                    Text("\(pair.0.plural) \(pair.1)")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// 4K coverage: the edition→cyan gradient meter and `12 / 48 titles · 25%`.
struct WidgetCoverageMeter: View {
    let summary: WidgetLibrarySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("4K coverage").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("\(summary.fourKTitles) / \(summary.titles) titles · \(summary.fourKPercent)%")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                Capsule()
                    .fill(LinearGradient(colors: [Theme.edition, Theme.grab], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * CGFloat(summary.fourKPercent) / 100)
            }
            .frame(height: 6)
            .background(Color.white.opacity(0.07), in: Capsule())
        }
    }
}
