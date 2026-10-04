import SwiftUI
import FusionhaKit

// Settings → File Management and Media Versions.

// MARK: File Management

/// Propers, recycle bin, extra files, analysis, import guards, free space and
/// self-heal (the web's `FileManagementPanel`). Autosaves each control to
/// `PUT /api/v1/media-management` with only that key.
struct FileManagementSettingsPanel: View {
    @Environment(SettingsStore.self) private var settings
    @State private var store: SettingsStore?

    var body: some View {
        Group {
            if let store {
                FileManagementForm().environment(store)
            } else {
                Color.clear
            }
        }
        .task {
            guard store == nil else { return }
            let mm = SettingsStore(client: settings.client, path: "/api/v1/media-management")
            store = mm
            await mm.load()
        }
    }
}

private struct FileManagementForm: View {
    @Environment(SettingsStore.self) private var store
    @State private var requeueing = false
    @State private var requeueMessage: String?

    var body: some View {
        SettingsForm(slug: "filemanagement") {
            if !store.loaded {
                SettingsLoadingRow()
            } else if let error = store.error, store.values.isEmpty {
                SettingsLoadingRow(error: error)
            } else {
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        SettingsSection {
            SettingPicker(label: "Default import mode",
                          description: "New root folders use this; a symlinked (debrid) source is always relocated as a symlink regardless.",
                          options: [("HARDLINK", "Hardlink"), ("SYMLINK", "Symlink"), ("COPY", "Copy"), ("MOVE", "Move")],
                          selection: Binding(get: { store.string("default_import_mode", "MOVE").uppercased() },
                                             set: { store.save("default_import_mode", .string($0)) }))
            SettingToggle(key: "create_empty_folders", label: "Create empty folders on add",
                          description: "Create the show/movie folder on disk as soon as a title is added, before anything is grabbed — matching arr behaviour.")
            SettingPicker(label: "Propers & repacks",
                          description: "How to handle proper/repack releases. TRaSH recommends scoring these via custom formats instead.",
                          options: [("doNotPrefer", "Do Not Prefer"), ("preferAndUpgrade", "Prefer and Upgrade")],
                          selection: store.stringBinding("propers_repacks", "doNotPrefer"))
            SettingText(key: "recycle_bin", label: "Recycle bin",
                        description: "Deleted files move here instead of being permanently removed. Empty = permanent delete.",
                        placeholder: "/data/.recycle", trims: false)
            SettingNumber(key: "recycle_bin_cleanup_days", label: "Recycle bin cleanup",
                          description: "Delete files from the recycle bin after this many days (0 = never).", unit: "days")
            SettingToggle(key: "import_extra_files", label: "Import extra files",
                          description: "Import matching subtitle/metadata files alongside the video.")
            SettingText(key: "extra_file_extensions", label: "Extra file extensions",
                        description: "Comma-separated list imported with the video.", placeholder: "srt,sub,nfo", trims: false)
            SettingToggle(key: "analyse_video_files", label: "Analyse video files",
                          description: "Read MediaInfo (codecs / HDR / audio) for naming + custom formats.")
            SettingToggle(key: "probe_verify_resolution", label: "Verify resolution from probe",
                          description: "When the media probe measures a different resolution than the release name claims (e.g. a “4k to 1080p” downscale), correct the file's quality to what the pixels actually are. Keeps the source; only the resolution changes.")
            SettingNumber(key: "probe_timeout_seconds", label: "Media analysis timeout",
                          description: "How long one media-info read may run. Raise it for cold debrid/rclone mounts — a large 4K remux can take a minute to read. A wedged mount is still abandoned at this bound.",
                          unit: "s")
            SettingText(key: "rejected_file_extensions", label: "Rejected file extensions",
                        description: "Comma-separated extensions to reject at import (e.g. exe, lnk, iso). A downloaded file with one of these is skipped and flagged, never silently imported. Empty = allow all.",
                        placeholder: "exe,lnk,iso", trims: false)
            SettingPicker(label: "Corrupt / incomplete file at import",
                          description: "What to do when a freshly-downloaded file is detected corrupt or incomplete (the media probe rejects it as invalid, or the file is truncated — its end isn't there). Only fires on definitive proof, never on a slow cold-mount probe. “Block auto-import” holds it for manual review; “Delete + re-search” gets a fresh copy but never blocklists (keeps a fixable decode/obfuscation release eligible); “Blocklist + delete + re-search” treats it as bad content.",
                          options: [("off", "Off (no check)"), ("hold", "Block auto-import (hold for review)"),
                                    ("delete_research", "Delete + re-search (no blocklist)"),
                                    ("blocklist_delete_research", "Blocklist + delete + re-search")],
                          selection: store.stringBinding("corrupt_import_action", "hold"))
            SettingPicker(label: "Short / too-short runtime at import",
                          description: "What to do when a freshly-downloaded file's probed runtime is below the expected minimum — often a genuine sample, but also legitimately-short content (e.g. a 5-minute Peppa Pig episode with no runtime metadata, so the check falls to its 10-minute default). “Flag for manual import” holds it for you to import by hand — never deletes, blocklists or re-searches (the safe default); “Reject” treats it as a bad sample; “Import anyway” trusts the release. Tip: set the series’ runtime so short shows clear this automatically.",
                          options: [("hold", "Flag for manual import (hold)"), ("reject", "Reject (fail + blocklist + re-search)"),
                                    ("accept", "Import anyway (accept)")],
                          selection: store.stringBinding("short_runtime_action", "hold"))
            SettingValueRow(label: "Retry failed analysis",
                            description: requeueMessage ?? "Put files whose media analysis failed or was given up on back into the background queue. Do this after raising the timeout above.") {
                Button(requeueing ? "Queueing…" : "Retry now") { Task { await requeue() } }
                    .buttonStyle(.web())
                    .disabled(requeueing)
            }
            SettingNumber(key: "minimum_free_space_mb", label: "Minimum free space",
                          description: "Don't import if the destination has less than this free.", unit: "MB")
        }

        SettingsSection("Self-heal",
                        footer: "Detect broken symlinks (decypharr/zurg mounts), converge a confirmation window, and — only when a kind is opted in below — clean the dead file and re-search through the monitored gate. A mount outage stands the whole sweep down; a good file is never deleted.") {
            SettingToggle(key: "dangling_reconcile_enabled", label: "Background sweep",
                          description: "Periodically re-check tracked files for broken links. Off = detection stops refreshing; manual rescan + Replace/Clean-up still work.")
            SettingNumber(key: "dangling_reconcile_interval_hours", label: "Sweep interval",
                          description: "How often the background sweep runs (1–168 hours).", unit: "hours", min: 1, max: 168)
        }

        ForEach([("movie", "Movies"), ("series", "Series"), ("anime", "Anime")], id: \.0) { kind in
            SettingsSection(kind.1) {
                SettingToggle(key: "auto_cleanup_dead_links_\(kind.0)", label: "Clean up dead links — \(kind.1)")
                SettingToggle(key: "auto_search_after_loss_\(kind.0)", label: "Search after loss — \(kind.1)")
            }
        }

        SettingsSection("Confirmation") {
            SettingNumber(key: "dangling_reconcile_min_scans", label: "Confirmation scans",
                          description: "Consecutive sweeps a link must read dangling before it's eligible to clean.", unit: "scans", min: 1)
            SettingNumber(key: "dangling_reconcile_grace_hours", label: "Grace period",
                          description: "Time a link must stay dangling (accrued across sweeps) before it's eligible.", unit: "hours", min: 1)
            SettingNumber(key: "dangling_outage_min_count", label: "Outage minimum count",
                          description: "Dangling links into one mount above this count reads as an outage — stand down.", unit: "files", min: 1)
            SettingNumber(key: "dangling_outage_fraction", label: "Outage fraction",
                          description: "Fraction of a mount's files going dangling at once that reads as an outage.",
                          unit: "ratio", min: 0, max: 1, integer: false)
            SettingNumber(key: "dangling_probe_timeout_seconds", label: "Probe timeout",
                          description: "Per-file stat timeout before a target read is treated as unknown.", unit: "s", min: 1)
            SettingNumber(key: "dangling_probe_max_workers", label: "Probe workers",
                          description: "Max concurrent target probes per sweep.", unit: "workers", min: 1)
        }
    }

    private func requeue() async {
        guard let client = store.client else { return }
        requeueing = true
        defer { requeueing = false }
        do {
            let result = try await client.json("POST", "/api/v1/import/enrichment/requeue", body: .object(["scope": "failed"]))
            let n = result["requeued"]?.int ?? 0
            requeueMessage = n > 0 ? "\(n) file\(n == 1 ? "" : "s") queued for re-analysis" : "No files were waiting on a retry"
        } catch {
            requeueMessage = "Couldn't queue those files — try again"
        }
    }
}

// MARK: Media Versions

/// The edition vocabulary (Director's Cut · IMAX · Black & White …) — the
/// web's `MovieEditionsPanel.tsx`: reorder (drag, or Edit), enable, add,
/// rename / edit aliases, delete. `/api/v1/config/editions`.
struct MediaVersionsSettingsPanel: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var defs: [JSONRecord]?
    @State private var error: String?
    @State private var editing: EditionDraft?
    @State private var pendingDelete: JSONRecord?

    private static let base = "/api/v1/config/editions"

    var body: some View {
        SettingsForm(slug: "editions") {
            if let defs {
                Section {
                    ForEach(defs) { def in
                        row(def)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { pendingDelete = def } label: { Label("Delete", systemImage: "trash") }
                                Button { editing = EditionDraft(def) } label: { Label("Edit", systemImage: "pencil") }
                                    .tint(Theme.indigo)
                            }
                    }
                    .onMove(perform: move)
                } footer: {
                    Text("A cut composes with the quality tier — e.g. {Director's Cut · 4K} and {Theatrical · 1080p} are separate files on one movie. Aliases are the spellings the parser folds to this canonical name. Drag ≡ to reorder.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.mut)
                }
                .listRowBackground(Theme.card)
                Section {
                    Button { editing = EditionDraft(nil) } label: {
                        Label("Add edition", systemImage: "plus")
                    }
                    .buttonStyle(.web())
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
            } else {
                SettingsLoadingRow(error: error)
            }
        }
        .task { await load() }
        .sheet(item: $editing) { draft in
            EditionEditor(draft: draft) { await load() }
                .presentationDetents([.medium, .large])
                .presentationBackground(Theme.panel)
        }
        .confirmationDialog("Delete \(pendingDelete?["name"]?.string ?? "edition")?",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let def = pendingDelete { Task { await delete(def) } }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func row(_ def: JSONRecord) -> some View {
        let enabled = def["enabled"]?.bool ?? true
        let aliases = (def["aliases"]?.array ?? []).compactMap(\.string)
        return HStack(spacing: 12) {
            Image(systemName: "film")
                .font(.system(size: 14))
                .foregroundStyle(Theme.mut)
                .frame(width: 30, height: 30)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(def["name"]?.string ?? "").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                    if def["built_in"]?.bool == true { badge("Built-in") }
                    if !enabled { badge("Off") }
                }
                Text(aliases.isEmpty ? "No extra aliases" : aliases.joined(separator: " · "))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.mut)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: Binding(get: { enabled }, set: { value in Task { await setEnabled(def, value) } }))
                .labelsHidden()
                .tint(Theme.indigo)
                .accessibilityLabel("Enable \(def["name"]?.string ?? "")")
            Button { editing = EditionDraft(def) } label: { Image(systemName: "pencil") }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.mut)
                .accessibilityLabel("Edit \(def["name"]?.string ?? "")")
        }
        .opacity(enabled ? 1 : 0.6)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .bold))
            .foregroundStyle(Theme.mut)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .overlay(Capsule().strokeBorder(Theme.line))
    }

    private func load() async {
        guard let client = store.client else { return }
        do {
            let rows = try await client.records(Self.base)
            let sorted = rows.sorted { ($0["sort_order"]?.double ?? 0) < ($1["sort_order"]?.double ?? 0) }
            SettingsMotion.perform(motionOff) { defs = sorted }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        guard var list = defs else { return }
        list.move(fromOffsets: source, toOffset: destination)
        defs = list
        let ids = list.map { JSONValue.number(Double($0.id)) }
        Task {
            do {
                try await store.client?.json("POST", "\(Self.base)/reorder", body: .object(["ids": .array(ids)]))
            } catch {
                store.saveError = error.localizedDescription
                await load()
            }
        }
    }

    private func setEnabled(_ def: JSONRecord, _ enabled: Bool) async {
        if let i = defs?.firstIndex(where: { $0.id == def.id }) { defs?[i]["enabled"] = .bool(enabled) }
        do {
            try await store.client?.json("PATCH", "\(Self.base)/\(def.id)", body: .object(["enabled": .bool(enabled)]))
        } catch {
            store.saveError = error.localizedDescription
            await load()
        }
    }

    private func delete(_ def: JSONRecord) async {
        do {
            try await store.client?.json("DELETE", "\(Self.base)/\(def.id)")
            SettingsMotion.perform(motionOff) { defs?.removeAll { $0.id == def.id } }
        } catch {
            store.saveError = error.localizedDescription
        }
    }
}

struct EditionDraft: Identifiable {
    let id = UUID()
    let editionId: Int?
    var name: String
    var aliases: [String]

    init(_ def: JSONRecord?) {
        editionId = def?.id
        name = def?["name"]?.string ?? ""
        aliases = (def?["aliases"]?.array ?? []).compactMap(\.string)
    }
}

/// Add / edit an edition: name plus alias chips (Return adds one).
private struct EditionEditor: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var draft: EditionDraft
    let onSaved: () async -> Void
    @State private var aliasInput = ""
    @State private var error: String?
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("", text: $draft.name, prompt: Text("e.g. Open Matte").foregroundStyle(Theme.dim))
                        .onSubmit { Task { await save() } }
                }
                .listRowBackground(Theme.card)
                Section {
                    if draft.aliases.isEmpty {
                        Text("No extra aliases — the name is always matched")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.dim)
                    }
                    ForEach(draft.aliases, id: \.self) { alias in
                        HStack {
                            Text(alias).font(.system(size: 13))
                            Spacer()
                            Button { draft.aliases.removeAll { $0 == alias } } label: {
                                Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.mut)
                            .accessibilityLabel("Remove alias \(alias)")
                        }
                    }
                    TextField("", text: $aliasInput, prompt: Text("Add a spelling and press Return").foregroundStyle(Theme.dim))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .onSubmit(addAlias)
                        .accessibilityLabel("Add alias")
                } header: {
                    Text("Aliases")
                }
                .listRowBackground(Theme.card)
                if let error {
                    Text(error).font(.system(size: 12.5)).foregroundStyle(Theme.danger)
                        .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.panel)
            .navigationTitle(draft.editionId == nil ? "Add edition" : "Edit edition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty || saving)
                }
            }
        }
    }

    private func addAlias() {
        let value = aliasInput.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return }
        if !draft.aliases.contains(where: { $0.lowercased() == value.lowercased() }) {
            draft.aliases.append(value)
        }
        aliasInput = ""
    }

    private func save() async {
        addAlias()
        let name = draft.name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let client = store.client else { return }
        saving = true
        defer { saving = false }
        error = nil
        let body: JSONValue = .object(["name": .string(name), "aliases": .array(draft.aliases.map(JSONValue.string))])
        do {
            if let id = draft.editionId {
                try await client.json("PATCH", "/api/v1/config/editions/\(id)", body: body)
            } else {
                try await client.json("POST", "/api/v1/config/editions", body: body)
            }
            await onSaved()
            dismiss()
        } catch APIError.http(409, _) {
            error = "An edition with that name already exists."
        } catch {
            self.error = "Could not save the edition. Please try again."
        }
    }
}
