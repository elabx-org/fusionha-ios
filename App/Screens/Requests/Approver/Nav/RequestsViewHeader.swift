import SwiftUI
import FusionhaKit

/// The one header every approver view shares (Final mock): the view name
/// opens the drawer and a summary sits under it. Filter, with the number of
/// filters set as its badge, is a toolbar item (D1); a view adds its own
/// action to the toolbar itself (Inbox: Select).
struct RequestsViewHeader<Summary: View>: View {
    @Environment(RequestsNav.self) private var nav
    @ViewBuilder var summary: () -> Summary

    init(@ViewBuilder summary: @escaping () -> Summary = { EmptyView() }) {
        self.summary = summary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if nav.panes.count == 1 { fixedSummary } else { menuTitle }
            RequestsFilterChips()
        }
        .toolbar {
            if !nav.pane.filters.isEmpty {
                ToolbarItem(placement: .primaryAction) { filterButton }
                    .barPriority(true)
            }
        }
    }

    /// One view only (a requester's My requests): the bar carries the title,
    /// so only the summary line shows here.
    private var fixedSummary: some View {
        summary().font(.system(size: 13)).foregroundStyle(Theme.mut).lineLimit(1)
    }

    private var menuTitle: some View {
        Button { nav.menuOpen = true } label: {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(nav.pane.title).font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.txt)
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.mut)
                }
                summary()
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
                    .lineLimit(1)
            }
            .frame(minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(nav.pane.title), change view")
    }

    private var filterButton: some View {
        let n = nav.filter.activeCount(nav.pane)
        return Button("Filter", systemImage: "line.3.horizontal.decrease") { nav.filterOpen = true }
            .badge(BadgeCount.text(n).map { Text(verbatim: $0) })
            .accessibilityLabel(n > 0 ? "Filter, \(n) on" : "Filter")
    }
}

/// A count in a summary line: the number in the text colour, the words muted.
func requestsCount(_ n: Int, _ words: String) -> Text {
    Text(verbatim: "\(n)").fontWeight(.semibold).foregroundColor(Theme.txt) + Text(" " + words)
}
