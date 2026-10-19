import SwiftUI
import FusionhaKit

/// The one header row every approver view shares (Final mock): the view name
/// opens the drawer, a summary sits under it, the Filter button carries the
/// number of filters set, and a view may add its one action (Inbox: Select).
struct RequestsViewHeader<Summary: View, Action: View>: View {
    @Environment(RequestsNav.self) private var nav
    @ViewBuilder var summary: () -> Summary
    @ViewBuilder var action: () -> Action

    init(@ViewBuilder summary: @escaping () -> Summary = { EmptyView() },
         @ViewBuilder action: @escaping () -> Action = { EmptyView() }) {
        self.summary = summary
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if nav.panes.count == 1 { fixedTitle } else { menuTitle }
                Spacer(minLength: 8)
                if !nav.pane.filters.isEmpty { filterButton }
                action()
            }
            RequestsFilterChips()
        }
    }

    /// One view only (a requester's My requests): a plain heading, no menu.
    private var fixedTitle: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(nav.pane == .mine ? "My requests" : nav.pane.title)
                .font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.txt)
                .accessibilityAddTraits(.isHeader)
            summary().font(.system(size: 13)).foregroundStyle(Theme.mut).lineLimit(1)
        }
        .frame(minHeight: 44, alignment: .leading)
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
        return Button { nav.filterOpen = true } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.txt)
                .frame(width: 44, height: 44)
                .glassEffect(.regular.interactive(), in: Circle())
                .overlay(alignment: .topTrailing) {
                    if n > 0 {
                        Text(verbatim: "\(n)")
                            .font(.system(size: 11, weight: .bold).monospacedDigit())
                            .foregroundStyle(Theme.onAccent)
                            .frame(minWidth: 17, minHeight: 17)
                            .background(Theme.primary, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.bg, lineWidth: 2).padding(-2))
                            .offset(x: 2, y: -2)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(n > 0 ? "Filter, \(n) on" : "Filter")
    }
}

/// A count in a summary line: the number in the text colour, the words muted.
func requestsCount(_ n: Int, _ words: String) -> Text {
    Text(verbatim: "\(n)").fontWeight(.semibold).foregroundColor(Theme.txt) + Text(" " + words)
}

/// The "Select" text button (Inbox's one action).
struct RequestsTextAction: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.txt)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .glassEffect(.regular.interactive(), in: Capsule())
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
    }
}
