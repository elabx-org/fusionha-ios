import SwiftUI
import FusionhaKit

/// Add / edit a root folder: a path plus its import mode.
struct RootFolderSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let folder: RootFolderInfo?
    let onSaved: () async -> Void
    @State private var path: String
    @State private var mode: ImportMode
    @State private var saving = false
    @State private var error: String?

    init(folder: RootFolderInfo?, onSaved: @escaping () async -> Void) {
        self.folder = folder
        self.onSaved = onSaved
        _path = State(initialValue: folder?.path ?? "")
        _mode = State(initialValue: folder?.importMode ?? .hardlink)
    }

    private var trimmed: String { path.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        FetchFormSheet(title: folder == nil ? "Add root folder" : "Edit root folder",
                       canSave: !trimmed.isEmpty, saving: saving,
                       onCancel: { dismiss() }, onSave: save) {
            SettingsSection {
                FetchTextRow(label: "Path", text: $path, prompt: "/movies-4k", mono: true)
                Picker(selection: $mode) {
                    ForEach(ImportMode.allCases) { Text($0.label).tag($0) }
                } label: {
                    FieldLabel(label: "Import mode",
                               description: "Hardlink falls back to copy across filesystems; symlink suits debrid/rclone mounts.")
                }
                .pickerStyle(.menu)
                .tint(Theme.mut)
            }
            if let error {
                Section { Label(error, systemImage: "xmark").font(.system(size: 12.5)).foregroundStyle(Theme.danger) }
                    .listRowBackground(Theme.card)
            }
        }
    }

    private func save() {
        guard let client = model.client, !trimmed.isEmpty else { return }
        let body: SettingsJSON = ["path": .string(trimmed), "default_import_mode": .string(mode.rawValue)]
        saving = true
        Task {
            do {
                if let folder {
                    try await client.configUpdate(.rootFolders, id: folder.id, body)
                } else {
                    try await client.configCreate(.rootFolders, body)
                }
                await onSaved()
                dismiss()
            } catch {
                self.error = error.settingsMessage
            }
            saving = false
        }
    }
}
