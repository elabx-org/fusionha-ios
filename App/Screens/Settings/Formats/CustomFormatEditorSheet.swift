import SwiftUI
import FusionhaKit

/// The editor for one custom format (web `CfEditor`): name, kind, Include when
/// renaming, the condition blocks, and — once saved — the live tester. Saving
/// posts `{name, media_kind, include_when_renaming, specifications}` and keeps
/// the sheet open so the tester re-scores against the saved format.
struct CustomFormatEditorSheet: View {
    let profiles: [ProfileScoringSummary]
    let onChanged: () async -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var saved: CustomFormatInfo?
    @State private var name: String
    @State private var kind: String
    @State private var rename: Bool
    @State private var specs: [CustomFormatSpec]
    @State private var savedTick = 0
    @State private var working = false
    @State private var error: String?
    @State private var confirmDelete = false

    init(target: CfEditTarget, profiles: [ProfileScoringSummary], onChanged: @escaping () async -> Void) {
        self.profiles = profiles
        self.onChanged = onChanged
        let format = target.format
        _saved = State(initialValue: format)
        _name = State(initialValue: format?.name ?? "")
        _kind = State(initialValue: Self.initialKind(format))
        _rename = State(initialValue: format?.includeWhenRenaming ?? false)
        _specs = State(initialValue: Self.initialSpecs(format))
    }

    /// A legacy no-kind format (and a new one) defaults to movie.
    private static func initialKind(_ format: CustomFormatInfo?) -> String {
        CFLibrary.isKind(format?.mediaKind) ? (format?.mediaKind ?? "movie") : "movie"
    }

    private static func initialSpecs(_ format: CustomFormatInfo?) -> [CustomFormatSpec] {
        format?.specifications ?? [CFSpecVocab.newSpec("release_title")]
    }

    private var valid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    private var dirty: Bool {
        guard let saved else { return true }
        return name != saved.name || kind != Self.initialKind(saved)
            || rename != (saved.includeWhenRenaming ?? false) || specs != Self.initialSpecs(saved)
    }

    var body: some View {
        NavigationStack {
            Form {
                header
                Section {
                    Text("Matches when **every block** below is satisfied (AND). Within a block, **any one** condition matching is enough (OR). A ★ **required** condition must always match. This mirrors Sonarr/Radarr exactly, but shows it.")
                        .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                }
                .listRowBackground(Theme.card)
                CfConditionSections(specs: $specs)
                if let saved {
                    CfLiveTesterSections(formatName: saved.name, savedTick: savedTick)
                    footerActions(saved)
                }
                if let error { Section { FormatsErrorRow(message: error) } }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(saved == nil ? "New format" : saved?.name ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCancelButton(title: saved != nil && !dirty ? "Close" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") { Task { await save() } }
                        .disabled(!valid || working || !dirty)
                }
            }
            .confirmationDialog("Delete \(saved?.name ?? "this format")?", isPresented: $confirmDelete,
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) { Task { await delete() } }
            } message: {
                Text("Profiles stop scoring this format.")
            }
        }
    }

    private var header: some View {
        Section {
            TextField("Custom format name", text: $name)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityLabel("Custom format name")
            Picker("Kind", selection: $kind) {
                ForEach(CFLibrary.kinds.indices, id: \.self) { i in
                    Text(CFLibrary.kinds[i].1).tag(CFLibrary.kinds[i].0)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.mut)
            Toggle("Include when renaming", isOn: $rename).tint(Theme.i1)
            if let saved {
                HStack(spacing: 8) {
                    CfSourceBadge(source: saved.provenance)
                    let used = CFLibrary.usedIn(profiles, formatId: saved.id)
                    Text("Used in **\(used) profile\(used == 1 ? "" : "s")**")
                        .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                }
            }
        }
        .listRowBackground(Theme.card)
    }

    private func footerActions(_ format: CustomFormatInfo) -> some View {
        Section {
            Button("Revert", systemImage: "arrow.uturn.backward") { revert(format) }.disabled(!dirty)
            Button("Delete format", systemImage: "trash", role: .destructive) { confirmDelete = true }
        }
        .listRowBackground(Theme.card)
    }

    private func revert(_ format: CustomFormatInfo) {
        name = format.name
        kind = Self.initialKind(format)
        rename = format.includeWhenRenaming ?? false
        specs = Self.initialSpecs(format)
    }

    private func save() async {
        guard valid, let client = model.client else { return }
        working = true
        defer { working = false }
        do {
            let result = try await client.saveCustomFormat(id: saved?.id, name: name.trimmingCharacters(in: .whitespaces),
                                                           mediaKind: kind, includeWhenRenaming: rename, specifications: specs)
            saved = result
            revert(result)
            savedTick += 1
            error = nil
            await onChanged()
        } catch {
            self.error = error.settingsMessage
        }
    }

    private func delete() async {
        guard let client = model.client, let id = saved?.id else { return }
        do {
            try await client.deleteCustomFormat(id: id)
            await onChanged()
            dismiss()
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t delete the custom format.")
        }
    }
}
