import SwiftUI
import FusionhaKit

/// Backups (web `BackupsCard` + `BackupKeyToggle`): include the key in backups
/// (turning it on asks you to confirm it's you), backups made before
/// encryption, and the retired keys.
struct SecurityBackupsSection: View {
    let status: SecretsStatus
    let store: SecurityStatusStore
    @Environment(\.settingsPush) private var push
    @State private var asking = false
    @State private var saving = false
    @State private var saveError: String?

    var body: some View {
        SettingsSection(footer: saveError) {
            Toggle(isOn: Binding(get: { status.backupIncludeSecretKey }, set: { toggle($0) })) {
                FieldLabel(label: "Include the key in backups",
                           description: "Off by default. A backup that holds the key can unlock every secret inside it, so anyone with that one file can read your passwords and API keys. Turning this on asks you to confirm it’s you.")
            }
            .tint(Theme.indigo)
            .disabled(saving)
            if status.backupIncludeSecretKey {
                SecurityNote(symbol: "exclamationmark.triangle",
                             text: "New backups contain the key. Anyone who gets one of those zips can read every secret in it. Store them somewhere only you can reach.")
            }
        }
        .sheet(isPresented: $asking) { SecurityBackupKeySheet(keyPath: status.keyPath, store: store) }
        if status.legacyBackups > 0 {
            SettingsSection {
                SecurityNote(symbol: "archivebox", text: legacyText)
                Button("Open Backup", systemImage: "arrow.right") { push("backup") }
            }
        }
        SettingsSection("Retired keys", footer: retiredFooter) {
            if status.retiredKeys.isEmpty {
                Text("None yet").font(.subheadline).foregroundStyle(Theme.mut)
            } else {
                ForEach(status.retiredKeys) { key in
                    SettingValueRow(label: SecretsCopy.groupFingerprint(key.fingerprint)) {
                        Text("Retired \(SecretsCopy.stamp(key.retiredAt))").font(.caption).foregroundStyle(Theme.mut)
                    }
                }
            }
        }
    }

    private var legacyText: String {
        let n = status.legacyBackups
        let head = n == 1 ? "1 backup was made before encryption and contains readable secrets."
            : "\(n) backups were made before encryption and contain readable secrets."
        return head + " fusionha never deletes them. Delete them or move them somewhere safe."
    }

    private var retiredFooter: String {
        status.retiredKeys.isEmpty
            ? "After a rotation the old key is kept as a file next to the current one, so older backups still open."
            : "Kept next to the key file, so older backups still open."
    }

    private func toggle(_ next: Bool) {
        saveError = nil
        if next { asking = true; return }
        guard let client = store.client else { return }
        saving = true
        Task {
            defer { saving = false }
            do {
                try await client.setBackupIncludesKey(false, proof: nil)
            } catch {
                saveError = SecretsErrorCopy.message(for: error)
            }
            await store.load()
        }
    }
}

/// "Include the key in backups?": re-auth before turning it on.
private struct SecurityBackupKeySheet: View {
    let keyPath: String?
    let store: SecurityStatusStore
    @Environment(\.dismiss) private var dismiss
    @State private var reauth = SecurityReauth()
    @State private var error: Error?
    @State private var working = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("New backups will contain the key file. Anyone who gets one of those zips can read every secret in it.")
                        .foregroundStyle(Theme.mut)
                }
                if let error, SecretsErrorCopy.isTooNew(error) {
                    SecurityTooNewNote(error: error, keyPath: keyPath)
                } else {
                    SecurityReauthSection(reauth: reauth, error: error.map { SecretsErrorCopy.message(for: $0, keyPath: keyPath) },
                                          plexDisabled: working, keyPath: keyPath) { submit(.grant($0)) }
                        .onChange(of: reauth.password) { error = nil }
                }
            }
            .navigationTitle("Include the key in backups?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                if reauth.hasPassword && !SecretsErrorCopy.isTooNew(error) {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(working ? "Turning on…" : "Turn on") { submit(.password(reauth.password)) }
                            .disabled(reauth.password.isEmpty || working)
                    }
                }
            }
            .task { await reauth.loadMethods(client: store.client) }
        }
        .onDisappear { reauth.reset() }
    }

    private func submit(_ proof: SecretsProof) {
        guard let client = store.client, !working else { return }
        working = true
        Task {
            defer { working = false; reauth.password = "" }
            do {
                try await client.setBackupIncludesKey(true, proof: proof)
                await store.load()
                dismiss()
            } catch {
                self.error = error
                await store.load()
            }
        }
    }
}
