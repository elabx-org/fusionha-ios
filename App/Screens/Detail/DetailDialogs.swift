import SwiftUI
import FusionhaKit

// The three item dialogs the detail page owns: Edit item, Add an edition and
// Delete. Native Form controls (the web's "no native controls" rule is a
// browser rule), with the web's fields, order and words.

// MARK: - Shared vocabulary

struct VocabOption: Hashable {
    let value: String
    let label: String
    init(_ value: String, _ label: String) {
        self.value = value
        self.label = label
    }
}

enum DetailVocab {
    static let monitorOptions: [VocabOption] = [
        VocabOption("all", "All"), VocabOption("future", "Future"), VocabOption("missing", "Missing"),
        VocabOption("existing", "Existing"), VocabOption("recent", "Recent"), VocabOption("pilot", "Pilot"),
        VocabOption("firstSeason", "First Season"), VocabOption("lastSeason", "Last Season"),
        VocabOption("monitorSpecials", "Monitor Specials"), VocabOption("none", "None"),
    ]
    /// Series type with its numbering hint (`S01E05` / `2020-05-25` / `absolute 005`).
    static let seriesTypes: [VocabOption] = [
        VocabOption("standard", "Standard · S01E05"), VocabOption("daily", "Daily · 2020-05-25"),
        VocabOption("anime", "Anime · absolute 005"),
    ]
    static let minimumAvailability: [VocabOption] = [
        VocabOption("announced", "Announced"), VocabOption("inCinemas", "In Cinemas"), VocabOption("released", "Released"),
    ]
    static let dispositions: [VocabOption] = [
        VocabOption("move", "Move the files to the new folder"),
        VocabOption("leave", "Leave the files where they are"),
        VocabOption("delete", "Delete the existing files"),
    ]

    static func monitorLabel(_ value: String?) -> String {
        monitorOptions.first { $0.value == value }?.label ?? "—"
    }

    /// The profile kinds an item can draw from: its own kind, plus `anime` for
    /// an anime title; legacy kind-less profiles always qualify.
    static func profiles(_ all: [QualityProfile], for detail: ItemDetail, keep: Int? = nil) -> [QualityProfile] {
        var kinds: Set<String> = [detail.kind.rawValue]
        if detail.isAnime == true { kinds.insert("anime") }
        return all.filter { p in p.mediaKind == nil || kinds.contains(p.mediaKind ?? "") || p.id == keep }
    }

    static func profileKind(_ detail: ItemDetail) -> String {
        detail.isAnime == true ? "anime" : detail.kind.rawValue
    }

    static func is4kRoot(_ path: String) -> Bool {
        let p = path.lowercased()
        return p.contains("4k") || p.contains("2160") || p.contains("uhd")
    }

    static func rootMatchesKind(_ path: String, detail: ItemDetail) -> Bool {
        let p = path.lowercased()
        if detail.isAnime == true { return p.contains("anime") }
        switch detail.kind {
        case .movie: return p.contains("movie") || p.contains("film")
        case .series: return p.contains("tv") || p.contains("series") || p.contains("show")
        }
    }

    /// Mirrors the web's `defaultRootId`: kind and tier, then kind, then tier.
    static func defaultRoot(_ tier: QualityTier, detail: ItemDetail, roots: [RootFolder]) -> Int? {
        let wants4k = tier == .uhd
        let kind: (RootFolder) -> Bool = { rootMatchesKind($0.path, detail: detail) }
        let tierMatch: (RootFolder) -> Bool = { is4kRoot($0.path) == wants4k }
        return (roots.first { kind($0) && tierMatch($0) } ?? roots.first(where: kind)
            ?? roots.first(where: tierMatch) ?? roots.first)?.id
    }

    static func defaultProfile(_ tier: QualityTier, profiles: [QualityProfile]) -> Int? {
        let wants4k = tier == .uhd
        let match = profiles.first { p in
            let n = p.name.lowercased()
            let is4k = n.contains("4k") || n.contains("2160") || n.contains("uhd") || n.contains("ultra")
            return is4k == wants4k
        }
        return (match ?? profiles.first)?.id
    }
}

private struct DialogFieldLabel: View {
    let title: String
    var subtitle: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).foregroundStyle(Theme.txt)
            if let subtitle {
                Text(subtitle).font(.system(size: 11.5)).foregroundStyle(Theme.mut)
            }
        }
    }
}

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
                            DialogFieldLabel(title: "Monitor", subtitle: "Sets the level for every edition")
                        }
                    }
                    LabeledContent("Metadata source") {
                        Text(DetailText.provider(detail.resolvedMetadataProvider ?? detail.metadataProvider ?? "tmdb"))
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
                        Label("Add edition", systemImage: "plus")
                    }
                }

                tagsSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Edit \(detail.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if busy { ProgressView() } else { Text("Save changes").fontWeight(.semibold) }
                    }
                    .disabled(busy)
                }
            }
            .confirmationDialog(removeTitle, isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                                titleVisibility: .visible, presenting: removing) { edition in
                Button("Remove edition", role: .destructive) { Task { await remove(edition, deleteFiles: false) } }
                Button("Remove and delete files on disk", role: .destructive) { Task { await remove(edition, deleteFiles: true) } }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("The edition stops being tracked. Its files stay on disk unless you also delete them.")
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.bg)
        .task { await seed() }
    }

    private var removeTitle: String {
        guard let removing else { return "Remove edition?" }
        return "Remove the \(removing.label) edition?"
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
                    Label("Remove edition", systemImage: "trash")
                }
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
            store.show("Removed the \(edition.label) edition", variant: .success)
            await store.reload()
            dismiss()
        } catch {
            store.show("Couldn't remove the \(edition.label) edition", variant: .error)
        }
    }
}

// MARK: - Add edition

struct AddEditionSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let detail: ItemDetail
    let preset: AddEditionPreset

    private static let standard = "Standard"
    private static let custom = "__custom__"

    @State private var tier: QualityTier = .hd
    @State private var editionChoice = AddEditionSheet.standard
    @State private var customEdition = ""
    @State private var presets: [String] = []
    @State private var rootFolderId: Int?
    @State private var folderName = ""
    @State private var profileId: Int?
    @State private var monitor = "all"
    @State private var minimumAvailability = "released"
    @State private var monitored = true
    @State private var searchNow = true
    @State private var defaults: [AddDefaultSlot] = []
    @State private var busy = false
    @State private var error: String?
    @State private var checking = false
    @State private var fourK: FourKCheck?
    @State private var seeded = false

    private var isSeries: Bool { detail.isSeries }
    private var profiles: [QualityProfile] { DetailVocab.profiles(store.profiles, for: detail) }

    private var effectiveEdition: String? {
        if editionChoice == Self.custom {
            let v = customEdition.trimmingCharacters(in: .whitespaces)
            return v.isEmpty ? nil : v
        }
        return editionChoice == Self.standard ? nil : editionChoice
    }

    private var canSubmit: Bool {
        rootFolderId != nil && profileId != nil && !busy
            && !(editionChoice == Self.custom && effectiveEdition == nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tier", selection: $tier) {
                        ForEach(QualityTier.ordered, id: \.self) { Text($0.chipLabel).tag($0) }
                    }
                    Picker(isSeries ? "Version" : "Movie edition", selection: $editionChoice) {
                        ForEach([Self.standard] + presets, id: \.self) { Text($0).tag($0) }
                        Text("Custom…").tag(Self.custom)
                    }
                    if editionChoice == Self.custom {
                        TextField(isSeries ? "Custom version name" : "Custom edition name", text: $customEdition)
                    }
                } header: {
                    Text("\(detail.title) · a new quality edition, tracked independently")
                        .textCase(nil)
                }

                if tier == .uhd {
                    fourKPanel
                }

                Section {
                    Picker("Root folder", selection: $rootFolderId) {
                        if rootFolderId == nil { Text("—").tag(Int?.none) }
                        ForEach(store.roots) { Text($0.path).tag(Int?.some($0.id)) }
                    }
                    LabeledContent("Folder name") {
                        TextField(defaultFolder, text: $folderName)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 14, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Text(previewPath)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                    Picker("Quality profile", selection: $profileId) {
                        if profileId == nil { Text("—").tag(Int?.none) }
                        ForEach(profiles) { Text($0.name).tag(Int?.some($0.id)) }
                    }
                    if isSeries {
                        Picker("Monitor level", selection: $monitor) {
                            ForEach(DetailVocab.monitorOptions, id: \.value) { Text($0.label).tag($0.value) }
                        }
                    } else {
                        Picker("Minimum availability", selection: $minimumAvailability) {
                            ForEach(DetailVocab.minimumAvailability, id: \.value) { Text($0.label).tag($0.value) }
                        }
                    }
                    Toggle("Monitored", isOn: $monitored).tint(Theme.indigo)
                    Toggle("Search for releases now", isOn: $searchNow).tint(Theme.indigo)
                }

                if let error {
                    Section {
                        Text(error).foregroundStyle(Theme.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Add an edition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if busy { ProgressView() } else { Text("Add edition").fontWeight(.semibold) }
                    }
                    .disabled(!canSubmit)
                }
            }
            .onChange(of: tier) { _, next in
                reseed(next)
                fourK = nil
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.bg)
        .task { await seed() }
    }

    private var fourKPanel: some View {
        Section {
            if let fourK {
                let found = fourK.foundUhd == true
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fourK.message ?? (found ? "4K releases are available." : "No 4K releases found yet."))
                            .foregroundStyle(Theme.txt)
                        if let best = fourK.bestReleaseName {
                            Text(best).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.mut)
                        }
                    }
                } icon: {
                    Image(systemName: found ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundStyle(found ? Theme.done : Theme.miss)
                }
                .transition(.opacity)
            }
            Button {
                Task { await runFourKCheck() }
            } label: {
                HStack {
                    Label("Check indexers for 4K", systemImage: "magnifyingglass")
                    Spacer()
                    if checking { ProgressView() }
                }
            }
            .disabled(checking)
        } header: {
            Text("4K availability")
        } footer: {
            Text(isSeries
                 ? "A quick look at whether 4K releases of this show exist before you add the edition."
                 : "A quick look at whether 4K releases of this movie exist before you add the edition.")
        }
    }

    private var defaultFolder: String {
        detail.year.map { "\(detail.title) (\(String($0)))" } ?? detail.title
    }

    private var previewPath: String {
        let root = store.roots.first { $0.id == rootFolderId }?.path ?? "—"
        let folder = folderName.trimmingCharacters(in: .whitespaces)
        return root + "/" + (folder.isEmpty ? defaultFolder : folder)
    }

    private func reseed(_ next: QualityTier) {
        let slot = defaults.first { $0.profileKind == DetailVocab.profileKind(detail) && $0.tier == next }
        rootFolderId = slot?.rootFolderId ?? DetailVocab.defaultRoot(next, detail: detail, roots: store.roots)
        profileId = slot?.qualityProfileId ?? DetailVocab.defaultProfile(next, profiles: profiles)
    }

    private func seed() async {
        guard !seeded else { return }
        seeded = true
        minimumAvailability = store.settings?.defaultMovieMinimumAvailability ?? "released"
        let start = preset.tier ?? (detail.editions.contains { $0.tier == .uhd } ? .hd : .uhd)
        tier = start
        if let client = store.client {
            async let d = try? client.addDefaults()
            async let e = try? client.editionDefinitions()
            let (slots, definitions) = await (d, e)
            defaults = slots ?? []
            presets = (definitions ?? []).filter { $0.enabled != false }.map(\.name)
        }
        if let version = preset.version, !version.isEmpty {
            if presets.contains(version) { editionChoice = version } else {
                editionChoice = Self.custom
                customEdition = version
            }
        }
        reseed(start)
    }

    private func runFourKCheck() async {
        guard let client = store.client else { return }
        checking = true
        defer { checking = false }
        do {
            let result = try await client.checkFourK(itemId: detail.id)
            withAnimation(DetailMotion.quick) { fourK = result }
        } catch {
            store.show("Couldn't check for 4K releases", variant: .error)
        }
    }

    private func submit() async {
        guard let client = store.client, let rootFolderId, let profileId else { return }
        busy = true
        self.error = nil
        defer { busy = false }
        let folder = folderName.trimmingCharacters(in: .whitespaces)
        let body = EditionAdd(
            tier: tier, movieEdition: effectiveEdition, rootFolderId: rootFolderId, qualityProfileId: profileId,
            monitored: monitored, folderName: folder.isEmpty ? nil : folder,
            monitor: isSeries ? monitor : nil, minimumAvailability: isSeries ? nil : minimumAvailability,
            searchNow: searchNow)
        do {
            try await client.addEdition(itemId: detail.id, body)
            let name = [tier.chipLabel, effectiveEdition].compactMap { $0 }.joined(separator: " · ")
            store.show("Added the \(name) edition", variant: .success)
            await store.reload()
            dismiss()
        } catch APIError.http(let status, _) where status == 409 {
            self.error = "That edition already exists on this title."
        } catch {
            self.error = "Couldn't add the edition. Try again."
        }
    }
}

// MARK: - Delete

struct DeleteItemSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let detail: ItemDetail

    @State private var deleteFiles = false
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.danger)
                    .frame(width: 34, height: 34)
                    .background(Theme.danger.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
                Text("Delete \(detail.title)?")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(2)
            }
            Text("This removes the title and all its editions from your library. This cannot be undone.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
            Toggle("Also delete the downloaded files from disk", isOn: $deleteFiles)
                .font(.system(size: 14))
                .tint(Theme.danger)
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text("Cancel").fontWeight(.semibold).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                Button {
                    Task {
                        busy = true
                        let ok = await store.deleteItem(deleteFiles: deleteFiles)
                        busy = false
                        if ok { dismiss() }
                    }
                } label: {
                    Text(busy ? "Deleting…" : "Delete").fontWeight(.bold).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.danger)
                .controlSize(.large)
                .disabled(busy)
            }
        }
        .padding(20)
        .presentationBackground(Theme.bg)
        .presentationDragIndicator(.visible)
    }
}
