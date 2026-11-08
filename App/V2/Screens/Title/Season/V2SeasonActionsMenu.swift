import SwiftUI
import FusionhaKit

/// The season page's ⋯ (mock browse-sheets.js `seasonMenu`): Search (the
/// season, the missing episodes, each episode, interactive), State
/// (Monitored, Refresh and scan, Sort) and View (Season history, Rename
/// preview). Every item is v1's season action (`SeasonActionsSheet`), for
/// all versions. The mock's "Columns…" is a desktop table option and has
/// no iOS counterpart. Look Pass family 2: Sort is an inline picker, and the
/// v1 sheet's hints are the items' subtitles.
struct V2SeasonActionsMenu: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let detail: ItemDetail
    let season: Season
    let missing: Int

    private var canEdit: Bool { model.me?.can("edit") ?? true }
    private var canSearch: Bool { canEdit && (model.me?.can("search") ?? true) }

    var body: some View {
        let n = season.seasonNumber
        let label = "\(detail.title) \(season.title)"
        let monitored = store.seasonMonitored(season)
        let oldest = store.oldestFirst.contains(n)
        Menu {
            if canSearch {
                Section("Search") {
                    let seasonRun = store.activity(.season(n))
                    let missingRun = store.activity(.seasonMissing(n))
                    // Menu items show only text and a symbol: the season header shows the spinner.
                    hinted(seasonRun?.label ?? "Search season", hint: "One decision — prefers a season pack",
                           symbol: seasonRun?.symbol ?? "magnifyingglass") {
                        store.v2Search(.season(n), label: label, season: n)
                    }
                    .disabled(seasonRun?.isSearching == true)
                    Button(missingRun?.label ?? (missing > 0 ? "Search missing (\(missing))" : "Search missing"),
                           systemImage: "text.magnifyingglass") {
                        store.v2GradualSearch(.seasonMissing(n), label: label, season: n, missingOnly: true)
                    }
                    .disabled(missing == 0 || missingRun?.isSearching == true)
                    hinted("Search each episode", hint: "One at a time, ~\(store.seasonInterval)s apart",
                           symbol: "list.bullet.indent") {
                        store.v2GradualSearch(.season(n), label: label, season: n, missingOnly: false)
                    }
                    .disabled(seasonRun?.isSearching == true)
                    Button("Interactive search", systemImage: "person") {
                        store.interactive = InteractiveTarget(editionIds: detail.orderedEditions.map(\.id),
                                                              seasonNumber: n, subtitle: season.title)
                    }
                }
            }
            Section("State") {
                if canEdit {
                    Button(monitored ? "Monitored" : "Not monitored",
                           systemImage: monitored ? "bookmark.fill" : "bookmark") {
                        Task { await store.setSeasonMonitored(n, !monitored) }
                    }
                    Button("Refresh and scan", systemImage: "arrow.clockwise") {
                        Task { await store.refreshSeason(n) }
                    }
                }
                // Look Pass family 2: Sort is an inline picker with its two choices.
                Picker(selection: Binding(get: { oldest }, set: { on in
                    if on { store.oldestFirst.insert(n) } else { store.oldestFirst.remove(n) }
                })) {
                    Text("Newest first").tag(false)
                    Text("Oldest first").tag(true)
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .pickerStyle(.menu)
            }
            Section("View") {
                Button("Season history", systemImage: "clock.arrow.circlepath") {
                    store.tab = .history
                    dismiss()
                }
                if canEdit {
                    Button("Rename preview", systemImage: "doc.text") {
                        store.renameScope = RenameScope(season: n)
                    }
                }
            }
        } label: {
            Label("Season actions", systemImage: "ellipsis")
        }
        .accessibilityLabel("\(season.title) actions")
    }

    /// A menu item with its hint as the item's subtitle (v1's sheet showed it under the row).
    private func hinted(_ title: String, hint: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label {
                Text(title)
                Text(hint)
            } icon: {
                Image(systemName: symbol)
            }
        }
    }
}
