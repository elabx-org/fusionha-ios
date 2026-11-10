import SwiftUI
import FusionhaKit

/// The poster-led title page in one column (a phone, the folded Duo, or
/// beside the list on the open Duo): the poster as the hero, then today's
/// summary (overview, version cards, actions, Needs you, Next up, the
/// release timeline) and tabs, unchanged. Behind `TitleLook.posterKey`.
struct V2PosterTitlePage: View {
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail
    var width: CGFloat = 0

    private var gutter: CGFloat { width >= 560 ? 24 : 20 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            V2PosterHero(detail: detail, width: width)
            VStack(alignment: .leading, spacing: 0) {
                V2TitleSummary(detail: detail, small: width < 400)
                V2TitleTabs(detail: detail)
                    .padding(.top, detail.isSeries ? 22 : 20)
                if detail.isSeries {
                    V2TitleCredit(detail: detail).font(.system(size: 13)).padding(.top, 32)
                }
            }
            .padding(.horizontal, gutter)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .foregroundStyle(page?.ink ?? Theme.txt)
    }
}
