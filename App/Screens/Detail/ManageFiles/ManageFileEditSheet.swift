import SwiftUI
import FusionhaKit

/// Edit one file, or set attributes on a selection (web `EditMovieFileDialog`
/// + `SetAttributeDialog`, one partial `files/bulk-edit` either way). One file
/// opens on its own values and sends what changed; a selection opens on
/// "Keep as is" for every field and sends only what was set.
struct ManageFileEditSheet: View {
    let model: ManageFilesModel
    let targets: [ManagedFileItem]
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ManageFileDraft
    @State private var saving = false

    init(model: ManageFilesModel, targets: [ManagedFileItem]) {
        self.model = model
        self.targets = targets
        _draft = State(initialValue: ManageFileDraft(targets.count == 1 ? targets.first?.row : nil))
    }

    private var single: Bool { targets.count == 1 }

    var body: some View {
        NavigationStack {
            Form {
                if single, let item = targets.first {
                    Section {
                        Text(item.row.relativePath).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.mut)
                            .textSelection(.enabled)
                    }
                }
                releaseSection
                if model.isSeries { episodesSection }
            }
            .disabled(saving)
            .navigationTitle(single ? "Edit file" : "Set on \(targets.count) files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") { Task { await save() } }
                        .disabled(saving || draft.fields.isEmpty)
                }
            }
        }
    }

    // MARK: Sections

    private var releaseSection: some View {
        Section("Release") {
            Picker("Quality", selection: $draft.quality) {
                if !single { Text("Keep as is").tag(String?.none) }
                ForEach(ManagedFileVocab.qualities, id: \.self) { Text(DetailText.quality($0)).tag(String?.some($0)) }
            }
            flag("Proper", $draft.proper)
            flag("Real", $draft.real)
            if single {
                TextField("Release group", text: Binding(get: { draft.group ?? "" }, set: { draft.group = $0 }))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            } else {
                Picker("Release group", selection: $draft.groupMode) {
                    Text("Keep as is").tag(ManageFileDraft.GroupMode.keep)
                    Text("Set").tag(ManageFileDraft.GroupMode.set)
                    Text("Clear").tag(ManageFileDraft.GroupMode.clear)
                }
                if draft.groupMode == .set {
                    TextField("Release group", text: Binding(get: { draft.group ?? "" }, set: { draft.group = $0 }))
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
            }
            pickList("Languages", ManagedFileVocab.languages, label: { $0 }, $draft.languages)
            pickList("Indexer flags", ManagedFileVocab.indexerFlags, label: ManagedFileVocab.flagLabel, $draft.flags)
        }
    }

    private var episodesSection: some View {
        Section {
            Picker("Release type", selection: $draft.releaseType) {
                if !single { Text("Keep as is").tag(String?.none) }
                ForEach(ManagedFileVocab.releaseTypes, id: \.self) { Text(ManagedFileVocab.releaseTypeLabel($0)).tag(String?.some($0)) }
            }
            Picker("Season", selection: $draft.season) {
                Text("Keep as is").tag(Int?.none)
                ForEach(model.detail.seasons ?? []) { s in
                    Text(s.seasonNumber == 0 ? "Specials" : "Season \(s.seasonNumber)").tag(Int?.some(s.seasonNumber))
                }
            }
            .onChange(of: draft.season) { draft.episodeIds = [] }
            if let n = draft.season, let season = model.detail.seasons?.first(where: { $0.seasonNumber == n }) {
                NavigationLink {
                    ManageFilePickList(title: "Episodes", options: season.episodes.map(\.id),
                                       label: { id in episodeLabel(season, id) },
                                       selection: Binding(get: { draft.episodeIds }, set: { draft.episodeIds = $0 ?? [] }))
                } label: {
                    LabeledContent("Episodes", value: draft.episodeIds.isEmpty ? "Same numbers"
                                   : season.episodes.filter { draft.episodeIds.contains($0.id) }.map { "E" + EpisodeCode.num($0.episodeNumber) }.joined(separator: " "))
                }
            }
        } header: {
            Text("Episodes")
        } footer: {
            Text("Picking a season with no episodes moves each file to the same episode number there. One episode applies to every file; pick as many as there are files to pair them in order.")
        }
    }

    private func episodeLabel(_ season: Season, _ id: Int) -> String {
        guard let e = season.episodes.first(where: { $0.id == id }) else { return "\(id)" }
        return EpisodeCode.episode(season: season.seasonNumber, episode: e.episodeNumber) + (e.title.map { " · \($0)" } ?? "")
    }

    // MARK: Controls

    @ViewBuilder private func flag(_ title: String, _ value: Binding<Bool?>) -> some View {
        if single {
            Toggle(title, isOn: Binding(get: { value.wrappedValue ?? false }, set: { value.wrappedValue = $0 })).tint(Theme.i1)
        } else {
            Picker(title, selection: value) {
                Text("Keep as is").tag(Bool?.none)
                Text("On").tag(Bool?.some(true))
                Text("Off").tag(Bool?.some(false))
            }
        }
    }

    private func pickList(_ title: String, _ options: [String], label: @escaping (String) -> String, _ selection: Binding<Set<String>?>) -> some View {
        NavigationLink {
            ManageFilePickList(title: title, options: options, label: label, selection: selection, canKeep: !single)
        } label: {
            LabeledContent(title, value: selection.wrappedValue.map { $0.isEmpty ? "None" : options.filter($0.contains).map(label).joined(separator: ", ") } ?? "Keep as is")
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        if await model.edit(targets.map(\.id), draft.fields) { dismiss() }
    }
}

/// A multi-select list; with `canKeep`, a "Keep as is" row resets it to nil.
struct ManageFilePickList<Key: Hashable>: View {
    let title: String
    let options: [Key]
    let label: (Key) -> String
    @Binding var selection: Set<Key>?
    var canKeep = false

    var body: some View {
        List {
            if canKeep {
                Button { selection = nil } label: {
                    row("Keep as is", on: selection == nil)
                }
            }
            ForEach(options, id: \.self) { key in
                Button {
                    var s = selection ?? []
                    if s.contains(key) { s.remove(key) } else { s.insert(key) }
                    selection = s
                } label: {
                    row(label(key), on: selection?.contains(key) == true)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ text: String, on: Bool) -> some View {
        HStack {
            Text(text).foregroundStyle(Theme.txt)
            Spacer()
            if on { Image(systemName: "checkmark").foregroundStyle(Theme.i1).fontWeight(.semibold) }
        }
        .contentShape(Rectangle())
    }
}

/// The editor's values; `original` (one file) decides what changed.
struct ManageFileDraft {
    enum GroupMode: Hashable { case keep, set, clear }

    var quality: String?
    var proper: Bool?
    var real: Bool?
    var group: String?
    var groupMode = GroupMode.keep
    var languages: Set<String>?
    var flags: Set<String>?
    var releaseType: String?
    var season: Int?
    var episodeIds: Set<Int> = []
    private let original: ManagedFileRow?

    init(_ row: ManagedFileRow?) {
        original = row
        guard let row else { return }
        quality = row.quality
        proper = (row.properVersion ?? 0) > 0
        real = row.isReal ?? false
        group = row.releaseGroup ?? ""
        languages = Set(row.languages)
        flags = Set(row.indexerFlags)
        releaseType = row.releaseType ?? "unknown"
    }

    /// The partial body: only what was set (bulk) or changed (one file).
    var fields: [String: SettingsJSON] {
        var out: [String: SettingsJSON] = [:]
        let o = original
        if let quality, quality != o?.quality { out["quality"] = .string(quality) }
        if let proper, o == nil || proper != ((o?.properVersion ?? 0) > 0) { out["proper"] = .bool(proper) }
        if let real, o == nil || real != (o?.isReal ?? false) { out["real"] = .bool(real) }
        if let o {
            let g = (group ?? "").trimmingCharacters(in: .whitespaces)
            if g != (o.releaseGroup ?? "") { out["release_group"] = .string(g) }
        } else if groupMode == .clear {
            out["release_group"] = .string("")
        } else if groupMode == .set, let g = group?.trimmingCharacters(in: .whitespaces), !g.isEmpty {
            out["release_group"] = .string(g)
        }
        if let languages, o == nil || languages != Set(o?.languages ?? []) {
            out["languages"] = .array(ManagedFileVocab.languages.filter(languages.contains).map { .string($0) })
        }
        if let flags, o == nil || flags != Set(o?.indexerFlags ?? []) {
            out["indexer_flags"] = .array(ManagedFileVocab.indexerFlags.filter(flags.contains).map { .string($0) })
        }
        if let releaseType, releaseType != (o?.releaseType ?? (o == nil ? nil : "unknown")) { out["release_type"] = .string(releaseType) }
        if let season {
            out["episodes"] = .object(["season": .int(season), "episode_ids": .array(episodeIds.sorted().map { .int($0) })])
        }
        return out
    }
}
