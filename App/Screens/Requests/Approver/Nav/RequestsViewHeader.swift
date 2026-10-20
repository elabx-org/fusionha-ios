import SwiftUI
import FusionhaKit

/// The one header every approver view shares (Final mock): the view name
/// opens the drawer and a summary sits under it. Filter, with the number of
/// filters set as its badge, is a toolbar item (D1); a view adds its own
/// action to the toolbar itself (Inbox: Select). The drawer and the filter
/// open from their controls: popovers when wide, sheets on a phone (DC21).
/// Wide (DU1), the view name is the web's desktop pill (icon, name, chevron)
/// with the summary beside it on the same row.
struct RequestsViewHeader<Summary: View>: View {
    @Environment(RequestsNav.self) private var nav
    @Environment(\.requestsWide) private var wide
    @ViewBuilder var summary: () -> Summary

    init(@ViewBuilder summary: @escaping () -> Summary = { EmptyView() }) {
        self.summary = summary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if nav.panes.count == 1 { fixedSummary } else if wide { pillRow } else { menuTitle }
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
        .sheetPopover(isPresented: Bindable(nav).menuOpen, width: 320) {
            RequestsDrawer().environment(nav)
        }
    }

    /// The desktop `ViewHeader` pill: a glass control, the summary beside it.
    private var pillRow: some View {
        HStack(spacing: 12) {
            Button { nav.menuOpen = true } label: {
                HStack(spacing: 7) {
                    Image(systemName: nav.pane.icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.mut)
                    Text(nav.pane.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.txt)
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.mut)
                }
                .frame(minHeight: 32)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("\(nav.pane.title), change view")
            .sheetPopover(isPresented: Bindable(nav).menuOpen, width: 280) {
                RequestsDrawer().environment(nav)
            }
            summary()
                .font(.system(size: 13))
                .foregroundStyle(Theme.mut)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
    }

    private var filterButton: some View {
        let n = nav.filter.activeCount(nav.pane)
        return Button("Filter", systemImage: "line.3.horizontal.decrease") { nav.filterOpen = true }
            .sheetPopover(isPresented: Bindable(nav).filterOpen, width: 380, height: 560) {
                RequestsFilterSheet().environment(nav).environment(\.requestsWide, wide)
            }
            .badge(BadgeCount.text(n).map { Text(verbatim: $0) })
            .accessibilityLabel(n > 0 ? "Filter, \(n) on" : "Filter")
    }
}

/// A count in a summary line: the number in the text colour, the words muted.
func requestsCount(_ n: Int, _ words: String) -> Text {
    Text(verbatim: "\(n)").fontWeight(.semibold).foregroundColor(Theme.txt) + Text(" " + words)
}
