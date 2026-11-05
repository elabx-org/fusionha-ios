import SwiftUI
import FusionhaKit

/// The title filling the flat open Duo (mock browse-title.js `tabWide`,
/// slice S7): the header band across the display, then two columns, the
/// summary (`V2TitleSummary`: overview, version cards, actions, Needs you,
/// Next up, the release timeline) on the left and the tabs on the right.
/// One scroll, so the band scrolls away under the compact bar.
struct V2TitleWidePage: View {
    @Environment(\.pagePalette) private var page
    @Environment(\.v2TitleBarInset) private var barInset
    let detail: ItemDetail
    /// The page's width (the whole display).
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            V2TitleBand(detail: detail, height: V2TitleWide.bandHeight(barInset: barInset))
                .duoTitleSwipe(id: detail.id)
            HStack(alignment: .top, spacing: V2TitleWide.columnGap) {
                VStack(alignment: .leading, spacing: 0) {
                    V2TitleSummary(detail: detail, small: true, stacksActions: true)
                    if detail.isSeries {
                        V2TitleCredit(detail: detail).font(.system(size: 13)).padding(.top, 28)
                    }
                }
                .frame(width: V2TitleWide.leftWidth(width))
                V2TitleTabs(detail: detail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, V2TitleWide.gutter)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
        .foregroundStyle(page?.ink ?? Theme.txt)
    }
}
