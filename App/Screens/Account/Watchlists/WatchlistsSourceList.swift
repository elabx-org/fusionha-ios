import SwiftUI
import FusionhaKit

/// The grouped source list (web `SourceList`): Letterboxd, Plex, Followed
/// lists, each with its quiet meta; the Letterboxd group ends with "Follow
/// someone’s watchlist or a list" and "One-time import"; an admin also gets
/// "Remembered matches · N".
struct WatchlistsSourceList: View {
    let views: [AutoSourceView]
    let selectedId: String?
    var admin = false
    var remembered = 0
    let onOpen: (AutoSourceView) -> Void
    let onFollow: () -> Void
    let onProfile: () -> Void
    let onImport: () -> Void
    var onRemembered: () -> Void = {}

    var body: some View {
        ForEach(AutoSourceGroup.allCases, id: \.self) { group in
            let rows = views.filter { $0.source.group == group }
            if !rows.isEmpty || group == .letterboxd {
                Section {
                    ForEach(rows) { row($0) }
                    if group == .letterboxd { letterboxdTail }
                } header: {
                    header(group, rows)
                }
                .listRowBackground(AccountStyle.cell)
            }
        }
        if admin {
            Section {
                Button(action: onRemembered) {
                    HStack {
                        Label(RememberedCopy.link(remembered), systemImage: "checkmark.seal")
                            .foregroundStyle(Theme.txt)
                        Spacer(minLength: 8)
                        chevron
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } footer: {
                Text(RememberedCopy.desc)
            }
            .listRowBackground(AccountStyle.cell)
        }
    }

    private func row(_ view: AutoSourceView) -> some View {
        Button { onOpen(view) } label: {
            HStack(spacing: 8) {
                WatchlistsSourceRow(view: view, selected: view.sourceId == selectedId)
                chevron
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(view.sourceId == selectedId ? Theme.panel2 : AccountStyle.cell)
    }

    @ViewBuilder
    private var letterboxdTail: some View {
        Button(action: onFollow) {
            Label(AutomaticRequestsCopy.followRow, systemImage: "plus").foregroundStyle(Theme.accentText)
        }
        Button(action: onImport) {
            HStack {
                Label(AutomaticRequestsCopy.importRow, systemImage: "square.and.arrow.down").foregroundStyle(Theme.txt)
                Spacer(minLength: 8)
                Text("Advanced").font(.caption).foregroundStyle(Theme.dim)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func header(_ group: AutoSourceGroup, _ rows: [AutoSourceView]) -> some View {
        // One line: the group name whole, its meta truncating in a narrow column.
        HStack(spacing: 6) {
            Text(AutomaticRequestsCopy.groupTitle(group)).lineLimit(1).fixedSize()
            if let meta = AutoSourceViews.groupMeta(group, rows) {
                Text("· \(meta)").textCase(nil).foregroundStyle(Theme.dim).lineLimit(1)
            }
            Spacer(minLength: 8)
            if group == .letterboxd, rows.contains(where: { $0.owner != nil }) {
                Button("Change", action: onProfile).textCase(nil).font(.footnote).fixedSize()
            }
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.dim)
            .accessibilityHidden(true)
    }
}
