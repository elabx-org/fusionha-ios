import SwiftUI
import FusionhaKit

/// DetailTabs: the underlined tab row with the "showing {scope}" echo, then
/// the active pane (D5, owner-approved with the web session). Series:
/// Seasons · Files · History · Searches · Overview. Movie: Files · History ·
/// Searches · Overview · Collection (when it has one). The page lands on the
/// first. Overview holds the trailer, collection, more like this and cast.
/// On the folded Duo / phone (`detailCompact`) the row is a segmented control
/// without Overview (its rails follow in the page; Collection stays a tab, the
/// collection rail links into it) and the echo is the version menu
/// (`DetailCompactTabBar`).
struct DetailTabsView: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.detailReduceMotion) private var reduce
    @Environment(\.detailCompact) private var compact
    let detail: ItemDetail
    let openWeb: () -> Void
    @Namespace private var underline

    private var tabs: [(DetailTab, String)] {
        compact ? allTabs.filter { $0.0 != .overview } : allTabs
    }

    private var allTabs: [(DetailTab, String)] {
        if detail.isSeries {
            return [(.seasons, "Seasons"), (.files, "Files"), (.history, "History"), (.searches, "Searches"),
                    (.overview, "Overview")]
        }
        var tabs: [(DetailTab, String)] = [(.files, "Files"), (.history, "History"), (.searches, "Searches"),
                                           (.overview, "Overview")]
        if detail.collection != nil { tabs.append((.collection, "Collection")) }
        return tabs
    }

    /// A movie has no Seasons tab: it opens on Files.
    private var current: DetailTab {
        tabs.contains { $0.0 == store.tab } ? store.tab : tabs[0].0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if compact {
                DetailCompactTabBar(detail: detail, tabs: tabs, current: current, select: select)
                    .sensoryFeedback(.selection, trigger: store.tab)
            } else {
                tabRow
                showingEcho
            }

            pane
                .padding(.top, compact ? 16 : 20)
                .id(current)
                .transition(.opacity)
        }
        .padding(.top, 22)
        .detailAnimation(.easeInOut(duration: 0.3), value: current)
    }

    private func select(_ tab: DetailTab) {
        if reduce { store.tab = tab } else {
            withAnimation(.timingCurve(0.52, 0.01, 0.16, 1, duration: 0.32)) { store.tab = tab }
        }
    }

    private var tabRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(tabs.indices, id: \.self) { index in
                    tabButton(tabs[index].0, label: tabs[index].1)
                }
            }
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: store.tab)
    }

    private func tabButton(_ tab: DetailTab, label: String) -> some View {
        Button { select(tab) } label: {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(current == tab ? Theme.txt : Theme.dim)
                .padding(.horizontal, 11)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .overlay(alignment: .bottom) {
                    if current == tab {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.txt)
                            .frame(height: 2)
                            .matchedGeometryEffect(id: "underline", in: underline)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(current == tab ? .isSelected : [])
    }

    private var showingEcho: some View {
        HStack {
            Spacer()
            (Text("showing ").foregroundColor(Theme.dim)
                + Text(store.showingLabel).font(.system(size: 11.5, weight: .semibold, design: .monospaced)).foregroundColor(Theme.txt))
                .font(.system(size: 12))
        }
        .padding(.top, 6)
        .padding(.bottom, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    @ViewBuilder
    private var pane: some View {
        switch current {
        case .seasons: SeasonsTab(detail: detail)
        case .files:
            if detail.isSeries { SeriesFilesTab(detail: detail) } else { MovieEditionsTab(detail: detail) }
        case .history: HistoryTab(detail: detail)
        case .searches: SearchesTab()
        case .overview: DetailOverviewTab(detail: detail)
        case .collection: CollectionTab(detail: detail)
        }
    }
}
