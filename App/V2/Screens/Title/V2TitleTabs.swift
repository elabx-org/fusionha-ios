import SwiftUI
import FusionhaKit

/// The title's tabs as one segmented control (mock `seg`). Series: Seasons ·
/// Files · History · Searches · Overview. Movie: Overview · Files · History ·
/// Searches · Collection (when it has one), landing on Overview. The panes
/// are v1's (`DetailTabsView`'s) apart from Overview (v2's cards) and
/// Seasons (v2's season cards, which push the season page, slice S6).
struct V2TitleTabs: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.detailReduceMotion) private var reduce
    let detail: ItemDetail

    private var tabs: [(DetailTab, String)] {
        if detail.isSeries {
            return [(.seasons, "Seasons"), (.files, "Files"), (.history, "History"), (.searches, "Searches"),
                    (.overview, "Overview")]
        }
        var tabs: [(DetailTab, String)] = [(.overview, "Overview"), (.files, "Files"), (.history, "History"),
                                           (.searches, "Searches")]
        if detail.collection != nil { tabs.append((.collection, "Collection")) }
        return tabs
    }

    private var current: DetailTab {
        tabs.contains { $0.0 == store.tab } ? store.tab : tabs[0].0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Section", selection: selection) {
                let tabs = tabs
                ForEach(tabs.indices, id: \.self) { i in
                    Text(tabs[i].1).tag(tabs[i].0)
                }
            }
            .pickerStyle(.segmented)
            .sensoryFeedback(.selection, trigger: store.tab)
            pane
                .id(current)
                .transition(.opacity)
        }
        .animation(reduce ? nil : .easeInOut(duration: 0.25), value: current)
    }

    private var selection: Binding<DetailTab> {
        Binding(get: { current }, set: { store.tab = $0 })
    }

    @ViewBuilder
    private var pane: some View {
        switch current {
        case .seasons: V2SeasonsTab(detail: detail)
        case .files:
            if detail.isSeries { SeriesFilesTab(detail: detail) } else { MovieEditionsTab(detail: detail) }
        case .history: HistoryTab(detail: detail)
        case .searches: SearchesTab()
        case .overview: V2TitleOverviewTab(detail: detail)
        case .collection: CollectionTab(detail: detail)
        }
    }
}
