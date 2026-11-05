import SwiftUI
import FusionhaKit

/// The title's tabs as one segmented control (mock `seg`). Series: Seasons ·
/// Files · History · Searches · Overview. Movie: Overview · Files · History ·
/// Searches · Collection (when it has one), landing on Overview. Seasons,
/// Files, History, Searches and Overview are v2's (`Title/Tabs/`); the
/// Collection pane is still v1's. The control fades out as it slides under
/// the compact bar (`v2FadesUnderTitleBar`).
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
            .v2FadesUnderTitleBar()
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
            if detail.isSeries { V2SeriesFilesTab(detail: detail) } else { V2MovieFilesTab(detail: detail) }
        case .history: V2HistoryTab(detail: detail)
        case .searches: V2SearchesTab(detail: detail)
        case .overview: V2TitleOverviewTab(detail: detail)
        case .collection: CollectionTab(detail: detail)
        }
    }
}
