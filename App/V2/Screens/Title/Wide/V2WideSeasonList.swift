import SwiftUI
import FusionhaKit

/// The wide season child's left column (mock browse.js season on the inner
/// display): the title's version cards, every season as a compact card with
/// the open one ringed (a tap swaps the season beside it), then Next up.
struct V2WideSeasonList: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.detailReduceMotion) private var reduce
    let detail: ItemDetail
    @Binding var selected: Int

    var body: some View {
        let versions = V2TitleVersion.all(store, detail: detail)
        let editions = detail.orderedEditions
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if !versions.isEmpty {
                    V2TitleVersionStrip(versions: versions, small: true)
                        .padding(.bottom, 6)
                }
                ForEach(detail.seasonsNewestFirst) { season in
                    let isOpen = season.seasonNumber == selected
                    Button {
                        withAnimation(reduce ? nil : .easeInOut(duration: 0.2)) { selected = season.seasonNumber }
                    } label: {
                        V2SeasonCard(detail: detail, season: season,
                                     facts: V2SeasonFacts(season: season, editions: editions),
                                     compact: true, selected: isOpen)
                    }
                    .buttonStyle(PressScaleStyle(scale: 0.98))
                    .accessibilityAddTraits(isOpen ? .isSelected : [])
                }
                if let next = V2TitleNextUp(detail: detail, store: store) {
                    V2TitleNextUpCard(detail: detail, next: next, stillWidth: 84)
                        .padding(.top, 14)
                }
            }
            .padding(.leading, V2TitleWide.gutter)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: selected)
    }
}
