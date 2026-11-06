import SwiftUI
import FusionhaKit

/// v2 Manage episodes (owner-approved mock, 2026-11-06): the series' files
/// one card per season on the title's own wash, quick chips that select
/// whole seasons, a glass bulk bar with Edit and Delete, and a clear-out
/// confirmation that frees space without forgetting the episodes. Reuses
/// v1's `ManageFilesModel` (load, edit, replace, delete) and keeps the
/// Import loose files tab as it was.
struct V2ManageEpisodesSheet: View {
    @State private var model: ManageFilesModel
    @Environment(AppModel.self) private var app
    @Environment(DetailStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0
    @State private var groups: [ManageSeasonGroup] = []
    /// nil until the first load decides (only a lone season starts open).
    @State private var expanded: Set<Int>?
    @State private var editing: ManageFilesEditTarget?
    @State private var deleting: V2ManageDeleteTarget?
    @State private var confirm: ManageFilesConfirm?

    init(detail: ItemDetail, target: ManageFilesTarget) {
        _model = State(initialValue: ManageFilesModel(detail: detail, scopeVersionIds: target.versionIds, season: target.season))
    }

    private var art: URL? { PageArtSource.url(backdrop: model.detail.backdropUrl, poster: model.detail.posterUrl) }

    var body: some View {
        NavigationStack {
            Group {
                if tab == 0 { filesTab } else { ManageLooseFilesView(detail: model.detail) }
            }
            .safeAreaInset(edge: .top, spacing: 0) { tabPicker }
            .safeAreaInset(edge: .bottom, spacing: 0) { if tab == 0 { bulkBar } }
            .navigationTitle("Manage episodes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { V2ManageToolbar(model: model, enabled: tab == 0, close: { dismiss() }) }
            .v2PageGround(art: art)
            .sheet(item: $editing) { t in ManageFileEditSheet(model: model, targets: t.items).sheetEscapeRoot() }
            .sheet(item: $deleting) { t in
                V2ManageDeleteSheet(model: model, target: t)
                    .environment(store)
                    .v2PageGround(art: art)
            }
            .confirmationDialog(confirm?.title(model) ?? "", isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }),
                                titleVisibility: .visible, presenting: confirm) { c in
                V2ManageRowConfirmButtons(model: model, confirm: c)
            } message: { c in
                if let m = c.message { Text(m) }
            }
        }
        .task {
            model.client = app.client
            await model.load()
        }
        .onChange(of: model.items, initial: true) { _, items in
            groups = ManageEpisodes.groups(items, detail: model.detail)
            if expanded == nil, model.loaded { expanded = groups.count == 1 ? [groups[0].season] : [] }
        }
        .onDisappear { if model.changed { Task { await store.reload() } } }
        .retainsDraft("manage.model", $model)
        .retainsDraft("manage.tab", $tab)
        .retainsDraft("manage.expanded", $expanded)
    }

    private var tabPicker: some View {
        Picker("Show", selection: $tab) {
            Text("Files").tag(0)
            Text("Import loose files").tag(1)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var filesTab: some View {
        V2ManageFilesList(model: model, groups: groups,
                          expanded: Binding(get: { expanded ?? [] }, set: { expanded = $0 }),
                          actions: actions)
    }

    private var actions: V2ManageActions {
        V2ManageActions(
            edit: { editing = ManageFilesEditTarget(items: $0) },
            delete: { items in
                deleting = V2ManageDeleteTarget(items: items, groups: groups, detail: model.detail)
            },
            confirm: { confirm = $0 },
            recheck: { season in Task { await model.rescan(season: season) } }
        )
    }

    @ViewBuilder private var bulkBar: some View {
        if let n = model.deleting {
            V2ManageProgressBar(text: "Deleting \(n == 1 ? "1 file" : "\(n) files")…")
        } else if !model.selected.isEmpty {
            let summary = ManageEpisodes.summary(model.selected, groups: groups)
            V2ManageBulkBar(summary: summary, busy: model.busy,
                            edit: { editing = ManageFilesEditTarget(items: model.selectedItems) },
                            delete: { actions.delete(model.selectedItems) })
        }
    }
}

/// What a card or row asks the sheet to open.
struct V2ManageActions {
    let edit: ([ManagedFileItem]) -> Void
    let delete: ([ManagedFileItem]) -> Void
    let confirm: (ManageFilesConfirm) -> Void
    let recheck: (Int) -> Void
}
