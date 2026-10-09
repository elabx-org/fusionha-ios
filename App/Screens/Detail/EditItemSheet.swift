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
                    LabeledContent("Metadata source") {
                        ProviderMark(provider: detail.resolvedMetadataProvider ?? detail.metadataProvider ?? "tmdb", size: 15)
                            .foregroundStyle(Theme.mut)
                    }
                }

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

                tagsSection
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
    }

    private var removeTitle: String {
        guard let removing else { return "Remove version?" }
        return "Remove the \(removing.label) version?"
    }

    // MARK: Edition card

    @ViewBuilder
    private func editionSection(_ edition: DetailEdition) -> some View {
        let draft = binding(edition.id)
        let original = originals[edition.id]
        Section {
            if isSeries {
                Picker("Monitor", selection: draft.monitor) {
                    ForEach(DetailVocab.monitorOptions, id: \.value) { Text($0.label).tag($0.value) }
                }
            } else {
                Toggle(isOn: draft.monitored) {
                    Label(draft.wrappedValue.monitored ? "Monitored" : "Unmonitored",
                          systemImage: draft.wrappedValue.monitored ? "bookmark.fill" : "bookmark")
                }
                .tint(Theme.indigo)
            }
            Picker("Root folder", selection: draft.rootFolderId) {
                if draft.wrappedValue.rootFolderId == nil { Text("—").tag(Int?.none) }
                ForEach(store.roots) { root in
                    Text(root.path).font(.system(.body, design: .monospaced)).tag(Int?.some(root.id))
                }
            }
            LabeledContent("Folder name") {
                TextField("Folder name", text: draft.folderName)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 14, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Picker("Quality profile", selection: draft.qualityProfileId) {
                if draft.wrappedValue.qualityProfileId == nil { Text("—").tag(Int?.none) }
                ForEach(DetailVocab.profiles(store.profiles, for: detail, keep: edition.qualityProfileId)) { profile in
                    Text(profile.name).tag(Int?.some(profile.id))
                }
            }
            if !isSeries {
                Picker("Minimum availability", selection: draft.minimumAvailability) {
                    ForEach(DetailVocab.minimumAvailability, id: \.value) { Text($0.label).tag($0.value) }
                }
            }
            if let original {
                let d = draft.wrappedValue
                let storageChanged = d.rootFolderId != original.rootFolderId
                    || d.folderName.trimmingCharacters(in: .whitespaces) != original.folderName
                let hasFiles = detail.fileCount(edition) > 0
                VStack(alignment: .leading, spacing: 4) {
                    Text(previewPath(d))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                        .textSelection(.enabled)
                    if storageChanged && edition.movieEdition != nil && d.folderName != original.folderName {
                        Text("⚠ folder rename — your media server re-scans it as a new item; watch history resets")
                            .font(.system(size: 11.5)).foregroundStyle(Theme.miss)
                    } else if storageChanged {
                        Text("↪ move files on save").font(.system(size: 11.5)).foregroundStyle(Theme.edition)
                    }
                }
                if storageChanged && hasFiles {
                    Picker("Existing files", selection: draft.disposition) {
                        ForEach(DetailVocab.dispositions, id: \.value) { Text($0.label).tag($0.value) }
                    }
                    if d.disposition == "leave" {
                        Text("Files stay in the old folder and show as Missing until moved or re-imported.")
                            .font(.system(size: 11.5)).foregroundStyle(Theme.miss)
                    } else if d.disposition == "delete" {
                        Text("The existing files will be permanently deleted.")
                            .font(.system(size: 11.5)).foregroundStyle(Theme.danger)
                    }
                }
            }
            if detail.editions.count > 1 {
                Button(role: .destructive) { removing = edition } label: {
                    Label("Remove version", systemImage: "trash")
                }
            } else {
                Label("The last version can’t be removed — delete the title instead", systemImage: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.dim)
            }
        } header: {
            HStack(spacing: 8) {
                Text(edition.tier.chipLabel)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(DetailTokens.tier(edition.tier))
                if let version = edition.movieEdition, !version.isEmpty {
                    DetailVersionTag(text: version)
                }
            }
            .textCase(nil)
        }
    }

    private func previewPath(_ draft: Draft) -> String {
        let root = store.roots.first { $0.id == draft.rootFolderId }?.path ?? "—"
        let folder = draft.folderName.trimmingCharacters(in: .whitespaces)
        return root + "/" + (folder.isEmpty ? defaultFolder : folder)
    }

    private var defaultFolder: String {
        detail.year.map { "\(detail.title) (\(String($0)))" } ?? detail.title
    }

    // MARK: Tags

    private var tagsSection: some View {
        Section("Tags") {
            if selectedTags.isEmpty {
                Text("No tags").foregroundStyle(Theme.mut)
            } else {
                FlowRow(spacing: 6, lineSpacing: 6) {
                    ForEach(selectedTags) { tag in
                        Button {
                            withAnimation(DetailMotion.quick) { selectedTags.removeAll { $0.id == tag.id } }
                        } label: {
                            HStack(spacing: 4) {
                                Text(tag.label)
                                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                            }
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Theme.txt)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.panel2, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.line))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove tag \(tag.label)")
                    }
                }
            }
            HStack {
                TextField("Add tag", text: $tagInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await addTag() } }
                let available = allTags.filter { t in !selectedTags.contains { $0.id == t.id } }
                if !available.isEmpty {
                    Menu {
                        ForEach(available) { tag in
                            Button(tag.label) { selectedTags.append(tag) }
                        }
                    } label: {
                        Image(systemName: "tag")
                    }
                    .accessibilityLabel("Pick a tag")
                }
            }
        }
    }

    private func addTag() async {
        let label = tagInput.trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty else { return }
        tagInput = ""
        if let existing = allTags.first(where: { $0.label.lowercased() == label.lowercased() }) {
            if !selectedTags.contains(where: { $0.id == existing.id }) { selectedTags.append(existing) }
            return
        }
        guard let client = store.client else { return }
        do {
            let tag = try await client.createTag(label: label)
            allTags.append(tag)
            selectedTags.append(tag)
        } catch {
            store.show("Couldn't create the tag \(label)", variant: .error)
        }
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
