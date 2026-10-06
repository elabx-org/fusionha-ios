import SwiftUI
import WidgetKit
import FusionhaKit

/// Library, small: the title count big, versions, the kind bar and 4K coverage.
struct WidgetLibrarySmall: View {
    let summary: WidgetLibrarySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetTopBar(title: "Library")
            Spacer(minLength: 6)
            WidgetNumber(value: "\(summary.titles)", caption: summary.totalsCaption, size: 40)
            Spacer(minLength: 8)
            WidgetKindBar(summary: summary, showsLegend: false)
            WidgetDotLine(color: QualityTier.uhd.color, text: "\(summary.fourKPercent)% in 4K")
                .padding(.top, 8)
        }
    }
}
