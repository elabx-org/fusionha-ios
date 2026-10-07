import SwiftUI
import WidgetKit
import FusionhaKit

/// Library, small: the title count big, the movies/series/anime bar, and
/// `4K on 312 · 24%`.
struct WidgetLibrarySmall: View {
    let summary: WidgetLibrarySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetTopBar(title: "Library")
            Spacer(minLength: 4)
            WidgetNumber(value: summary.titles.formatted(), caption: summary.titles == 1 ? "title" : "titles", size: 42)
            Spacer(minLength: 8)
            WidgetKindBar(summary: summary, showsLegend: false)
            Text("4K on \(summary.fourKTitles.formatted()) · \(summary.fourKPercent)%")
                .font(WidgetStyle.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.top, 8)
        }
    }
}
