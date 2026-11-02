import SwiftUI
import FusionhaKit

/// Settings › Media Management › Import lists (web `ImportListsPanel`,
/// requests phase 10b slice 3). Admin (`integrations.manage`): lists that add
/// titles straight to the library, with no requests and no quota. Lists,
/// Exclusions and Last run sit behind a segmented control, as on the web.
struct ImportListsSettingsPanel: View {
    enum Tab: String, CaseIterable, Identifiable {
        case lists = "Lists", exclusions = "Exclusions", run = "Last run"
        var id: String { rawValue }
    }

    @Environment(AppModel.self) private var model
    @State private var store = ImportListsStore()
    @State private var tab: Tab = .lists
    @State private var form: FormTarget?
    @State private var review: ImportList?

    /// The Add (no list) or Edit sheet.
    struct FormTarget: Identifiable {
        let list: ImportList?
        var id: Int { list?.id ?? 0 }
    }

    private var allowed: Bool { model.me?.hasPermission("integrations.manage") == true }

    var body: some View {
        SettingsForm(slug: "importlists") {
            if allowed {
                header
                switch tab {
                case .lists: ImportListsListsTab(store: store, onEdit: { form = FormTarget(list: $0) }, onReview: { review = $0 })
                case .exclusions: ImportListExclusionsTab(store: store)
                case .run: ImportListRunsTab(store: store, onReview: { review = $0 })
                }
            } else {
                Section { Text(ImportListCopy.noPermission).foregroundStyle(Theme.mut) }
            }
        }
        .task(id: allowed) {
            guard allowed else { return }
            await store.load(model.client)
        }
        .task(id: store.waitingOnSync) {
            // A Sync now is picked up within seconds; quiet otherwise.
            while store.waitingOnSync, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                await store.load(model.client)
            }
        }
        .sheet(item: $form) { target in
            ImportListFormSheet(store: store, list: target.list)
        }
        .sheet(item: $review) { list in
            ImportListUnmatchedSheet(store: store, list: list)
        }
    }

    @ViewBuilder private var header: some View {
        Section {
            Button(ImportListCopy.add, systemImage: "plus") { form = FormTarget(list: nil) }
                .font(.body.weight(.semibold))
                .settingsField(ImportListCopy.add)
            Label {
                (Text(ImportListCopy.adminLead).bold() + Text(" " + ImportListCopy.adminRest))
                    .font(.footnote).foregroundStyle(Theme.mut)
            } icon: {
                Image(systemName: "checkmark.shield").foregroundStyle(Theme.dim)
            }
        }
        Section {
            Picker("Import lists sections", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }
}

/// Tab 1: one row per list, then the global per-sync cap.
struct ImportListsListsTab: View {
    let store: ImportListsStore
    let onEdit: (ImportList) -> Void
    let onReview: (ImportList) -> Void

    var body: some View {
        Section {
            if !store.loaded {
                SettingsLoadingRow()
            } else if store.failed {
                SettingsLoadingRow(error: "Couldn’t load import lists. Try again in a moment.")
            } else if store.lists.isEmpty {
                Text(ImportListCopy.empty).font(.subheadline).foregroundStyle(Theme.mut)
            } else {
                ForEach(store.lists) { list in
                    ImportListRow(store: store, list: list, onEdit: { onEdit(list) }, onReview: { onReview(list) })
                }
            }
        }
        ImportListsMaxAddSection()
    }
}
