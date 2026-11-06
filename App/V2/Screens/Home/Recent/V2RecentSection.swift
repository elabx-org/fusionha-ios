import SwiftUI
import FusionhaKit

/// Home's "Recently added": the heading with "See all N" (All titles,
/// added in the last 30 days, newest first), then the timeline: four
/// compact rows on the phone and the folded Duo, the six-tile zipper wide.
struct V2RecentSection: View {
    let data: V2HomeData
    let width: CGFloat
    let gutter: CGFloat
    let wide: Bool
    let seeAll: () -> Void

    var body: some View {
        if !data.recent.isEmpty {
            VStack(alignment: .leading, spacing: wide ? 14 : 4) {
                V2HomeSectionHead(title: "Recently added",
                                  action: data.recentCount > 0 ? "See all \(data.recentCount.formatted())" : nil,
                                  accessibilityAction: "See all recently added", tap: seeAll)
                    .padding(.horizontal, wide ? 0 : gutter)
                if wide {
                    V2RecentZipper(items: Array(data.recent.prefix(6)))
                } else {
                    V2RecentRows(items: Array(data.recent.prefix(4)), width: width)
                }
            }
        }
    }
}
