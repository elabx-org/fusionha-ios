import SwiftUI
import FusionhaKit

/// DetailTabs: the underlined tab row with the "showing {scope}" echo, then
/// the active pane. Series: Seasons · Files · History · Searches. Movie:
/// Versions · History · Searches · Collection (when it has one).
struct DetailTabsView: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.detailReduceMotion) private var reduce
    let detail: ItemDetail
    let openWeb: () -> Void
    @Namespace private var underline

    private var tabs: [(DetailTab, String)] {
        if detail.isSeries {
            return [(.seasons, "Seasons"), (.files, "Files"), (.history, "History"), (.searches, "Searches")]
        }
        var tabs: [(DetailTab, String)] = [(.files, "Versions"), (.history, "History"), (.searches, "Searches")]
        if detail.collection != nil { tabs.append((.collection, "Collection")) }
        return tabs
    }

    /// A movie has no Seasons tab: it opens on Versions.
    private var current: DetailTab {
        tabs.contains { $0.0 == store.tab } ? store.tab : tabs[0].0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(tabs.indices, id: \.self) { index in
                        let tab = tabs[index].0, label = tabs[index].1
                        Button {
                            if reduce { store.tab = tab } else {
                                withAnimation(.timingCurve(0.52, 0.01, 0.16, 1, duration: 0.32)) { store.tab = tab }
                            }
                        } label: {
                            Text(label)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(current == tab ? Theme.txt : Theme.mut)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .frame(minHeight: 44)
                                .overlay(alignment: .bottom) {
                                    if current == tab {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Theme.cyan)
                                            .frame(height: 2)
                                            .matchedGeometryEffect(id: "underline", in: underline)
                                    }
                                }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(current == tab ? .isSelected : [])
                    }
                }
            }
            .scrollIndicators(.hidden)
            .sensoryFeedback(.selection, trigger: store.tab)

            HStack {
                Spacer()
                (Text("showing ").foregroundColor(Theme.dim)
                    + Text(store.showingLabel).font(.system(size: 11.5, weight: .semibold, design: .monospaced)).foregroundColor(Theme.txt))
                    .font(.system(size: 11.5))
            }
            .padding(.top, 6)
            .padding(.bottom, 6)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }

            pane
                .padding(.top, 20)
                .id(current)
                .transition(.opacity)
        }
        .padding(.top, 22)
        .detailAnimation(.easeInOut(duration: 0.3), value: current)
        .task(id: current) {
            if current == .searches && !store.runsLoaded { await store.loadRuns() }
        }
    }

    @ViewBuilder
    private var pane: some View {
        switch current {
        case .seasons: SeasonsTab(detail: detail, openWeb: openWeb)
        case .files:
            if detail.isSeries { SeriesFilesTab(detail: detail) } else { MovieEditionsTab(detail: detail) }
        case .history: HistoryTab(detail: detail)
        case .searches: SearchesTab()
        case .collection: CollectionTab(detail: detail, openWeb: openWeb)
        }
    }
}
