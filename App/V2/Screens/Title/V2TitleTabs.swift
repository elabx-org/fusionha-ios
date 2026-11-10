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
    /// The pane on screen. It follows the picker a frame later, so a tap
    /// moves the picker at once even when the new pane is slow to build
    /// (History's charts, a long Files list): built in the same frame, the
    /// picker sat still until the pane was ready and the tap read as missed.
    @State private var shown: DetailTab?

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
                .id(paneTab)
                .transition(.opacity)
        }
        .animation(reduce ? nil : .easeInOut(duration: 0.25), value: paneTab)
        .task(id: current) {
            guard shown != current else { return }
            try? await Task.sleep(for: .milliseconds(30))
            if !Task.isCancelled { shown = current }
        }
    }

    /// The pane's tab: the picker's, once it has had its frame.
    private var paneTab: DetailTab {
        guard let shown, tabs.contains(where: { $0.0 == shown }) else { return current }
        return shown
    }

    private var selection: Binding<DetailTab> {
        Binding(get: { current }, set: { store.tab = $0 })
    }

    @ViewBuilder
    private var pane: some View {
        switch paneTab {
        case .seasons: V2SeasonsTab(detail: detail)
        case .files:
            if detail.isSeries { V2SeriesFilesTab(detail: detail) } else { V2MovieFilesTab(detail: detail) }
        case .history: V2HistoryTab(detail: detail)
        case .searches: V2SearchesTab(detail: detail)
        case .overview: V2TitleOverviewTab(detail: detail)
        case .collection: V2CollectionTab(detail: detail)
        }
    }
}
