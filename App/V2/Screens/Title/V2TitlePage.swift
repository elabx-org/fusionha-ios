import SwiftUI
import FusionhaKit

/// The v2 title page's body (mocks browse.js `titlePhone`, browse-title.js
/// `moviePhone`): the hero, then on the art-palette ground the summary
/// (`V2TitleSummary`: overview, version cards, actions, Needs you, Next up,
/// the release timeline) and the tabs. The title filling the flat open Duo
/// lays the same parts out in two columns (`V2TitleWidePage`).
struct V2TitlePage: View {
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail
    /// The column's width: narrow columns use the smaller cards.
    var width: CGFloat = 0

    private var gutter: CGFloat { width >= 560 ? 24 : 20 }

    var body: some View {
        let _ = PerfCount.hit("V2TitlePage.body")
        let _ = PerfCount.mark("title.page")
        VStack(alignment: .leading, spacing: 0) {
            V2TitleHero(detail: detail)
            VStack(alignment: .leading, spacing: 0) {
                V2TitleSummary(detail: detail, small: width < 400)
                V2TitleTabs(detail: detail)
                    .padding(.top, detail.isSeries ? 22 : 20)
                if detail.isSeries {
                    V2TitleCredit(detail: detail).font(.system(size: 13)).padding(.top, 32)
                }
            }
            .padding(.horizontal, gutter)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
        .foregroundStyle(page?.ink ?? Theme.txt)
    }
}
