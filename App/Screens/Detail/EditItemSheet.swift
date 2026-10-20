import SwiftUI
import FusionhaKit

// MARK: - Edit item

struct EditItemSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let detail: ItemDetail

    struct Draft: Equatable {
        var monitored: Bool
        var monitor: String
        var rootFolderId: Int?
        var folderName: String
        var qualityProfileId: Int?
        var minimumAvailability: String
        var disposition: String
    }

    @State private var monitored = true
    @State private var seriesType = "standard"
    @State private var drafts: [Int: Draft] = [:]
    @State private var originals: [Int: Draft] = [:]
    @State private var allTags: [ItemTag] = []
    @State private var selectedTags: [ItemTag] = []
    @State private var tagInput = ""
    @State private var busy = false
    @State private var removing: DetailEdition?
    @State private var removeFiles = false
    @State private var seeded = false

    private var isSeries: Bool { detail.isSeries }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $monitored) {
                        DialogFieldLabel(title: "Monitored", subtitle: "Whether fusionha tracks this title at all")
                    }
                    .tint(Theme.indigo)
                    if isSeries {
                        Picker(selection: $seriesType) {
                            ForEach(DetailVocab.seriesTypes, id: \.value) { option in
                                Text(option.label).tag(option.value)
                            }
                        } label: {
                            DialogFieldLabel(title: "Series type", subtitle: "Numbering — matching, searching & naming")
                        }
                        Picker(selection: masterMonitor) {
                            if masterMonitor.wrappedValue == "" { Text("Mixed").tag("") }
                            ForEach(DetailVocab.monitorOptions, id: \.value) { Text($0.label).tag($0.value) }
                        } label: {
                            DialogFieldLabel(title: "Monitor", subtitle: "Sets the level for every version")
                        }
                    }
                }

                EditSourceSection(detail: detail)

                ForEach(detail.orderedEditions) { edition in
                    editionSection(edition)
                }

                Section {
                    Button {
                        store.showingEdit = false
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(450))
                            store.addPreset = AddEditionPreset()
                        }
                    } label: {
                        Label("Add version", systemImage: "plus")
                    }
                } header: {
                    Text("Versions")
                } footer: {
                    Text("A new tier, or another edition ({edition-…})")
                }

                EditTagsSection(selectedTags: $selectedTags, allTags: $allTags, tagInput: $tagInput)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Edit \(detail.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if busy { ProgressView() } else { Label("Save changes", systemImage: "checkmark") }
                    }
                    .disabled(busy)
                }
            }
            .confirmationDialog(removeTitle, isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                                titleVisibility: .visible, presenting: removing) { edition in
                Button("Remove version", role: .destructive) { Task { await remove(edition, deleteFiles: false) } }
                Button("Remove and delete files on disk", role: .destructive) { Task { await remove(edition, deleteFiles: true) } }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("The version stops being tracked. Its files stay on disk unless you also delete them.")
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.bg)
        .task { await seed() }
        // Survives a fold / unfold (data safety): `seeded` keeps seed() from overwriting it.
        .retainsDraft("edit.seeded", $seeded)
        .retainsDraft("edit.monitored", $monitored)
        .retainsDraft("edit.seriesType", $seriesType)
        .retainsDraft("edit.drafts", $drafts)
        .retainsDraft("edit.originals", $originals)
        .retainsDraft("edit.allTags", $allTags)
        .retainsDraft("edit.selectedTags", $selectedTags)
        .retainsDraft("edit.tagInput", $tagInput)
        .retainsDraft("edit.removing", $removing)
    }

    private var removeTitle: String {
        guard let removing else { return "Remove version?" }
        return "Remove the \(removing.label) version?"
    }

    // MARK: Edition card

    private func editionSection(_ edition: DetailEdition) -> some View {
        EditEditionSection(detail: detail, edition: edition, draft: binding(edition.id),
                           original: originals[edition.id], removing: $removing)
    }

    // MARK: State

    private var masterMonitor: Binding<String> {
        Binding(
            get: {
                let levels = Set(detail.editions.compactMap { drafts[$0.id]?.monitor })
                return levels.count == 1 ? (levels.first ?? "") : ""
            },
            set: { value in
                guard !value.isEmpty else { return }
                for id in drafts.keys { drafts[id]?.monitor = value }
            }
        )
    }

    private func binding(_ id: Int) -> Binding<Draft> {
        Binding(
            get: { drafts[id] ?? Draft(monitored: true, monitor: "all", rootFolderId: nil, folderName: "",
                                       qualityProfileId: nil, minimumAvailability: "released", disposition: "move") },
            set: { drafts[id] = $0 }
        )
    }

    private func seed() async {
        guard !seeded else { return }
        seeded = true
        monitored = detail.monitored ?? true
        seriesType = detail.seriesType ?? "standard"
        selectedTags = detail.tags ?? []
        var next: [Int: Draft] = [:]
        for edition in detail.editions {
            let unresolved = (edition.unresolvedFileCount ?? 0) > 0
            next[edition.id] = Draft(
                monitored: edition.monitored,
                monitor: edition.monitor ?? (edition.monitored ? "all" : "none"),
                rootFolderId: edition.rootFolderId,
                folderName: edition.folderName ?? "",
                qualityProfileId: edition.qualityProfileId,
                minimumAvailability: edition.minimumAvailability ?? store.settings?.defaultMovieMinimumAvailability ?? "released",
                disposition: unresolved ? "leave" : "move")
        }
        drafts = next
        originals = next
        if let tags = try? await store.client?.tags() { allTags = tags }
    }

    private func save() async {
        guard let client = store.client else { return }
        busy = true
        defer { busy = false }
        var failed = false

        var item = ItemUpdate()
        if monitored != (detail.monitored ?? true) { item.monitored = monitored }
        if isSeries && seriesType != (detail.seriesType ?? "standard") { item.seriesType = seriesType }
        let before = Set((detail.tags ?? []).map(\.id))
        let after = selectedTags.map(\.id)
        if Set(after) != before { item.tagIds = after }
        if !item.isEmpty {
            do { try await client.updateItem(id: detail.id, item) } catch { failed = true }
        }

        for edition in detail.editions {
            guard let d = drafts[edition.id], let o = originals[edition.id], d != o else { continue }
            var update = EditionUpdate()
            if isSeries {
                if d.monitor != o.monitor { update.monitor = d.monitor }
            } else {
                if d.monitored != o.monitored { update.monitored = d.monitored }
                if d.minimumAvailability != o.minimumAvailability { update.minimumAvailability = d.minimumAvailability }
            }
            if d.qualityProfileId != o.qualityProfileId { update.qualityProfileId = d.qualityProfileId }
            let folder = d.folderName.trimmingCharacters(in: .whitespaces)
            let storageChanged = d.rootFolderId != o.rootFolderId || folder != o.folderName
            if d.rootFolderId != o.rootFolderId { update.rootFolderId = d.rootFolderId }
            if folder != o.folderName { update.folderName = folder }
            if storageChanged && detail.fileCount(edition) > 0 { update.rootFolderDisposition = d.disposition }
            guard !update.isEmpty else { continue }
            do { try await client.updateEdition(itemId: detail.id, editionId: edition.id, update) } catch { failed = true }
        }

        await store.reload()
        if failed {
            store.show("Some changes couldn't be saved", variant: .error)
        } else {
            store.show("Saved \(detail.title)", variant: .success)
            dismiss()
        }
    }

    private func remove(_ edition: DetailEdition, deleteFiles: Bool) async {
        guard let client = store.client else { return }
        do {
            try await client.deleteEdition(itemId: detail.id, editionId: edition.id, deleteFiles: deleteFiles)
            store.show("Removed the \(edition.label) version", variant: .success)
            await store.reload()
            dismiss()
        } catch {
            store.show("Couldn't remove the \(edition.label) version", variant: .error)
        }
    }
}
