import SwiftUI
import FusionhaKit

/// Secrets are locked (web `LockedCard`): why, what still works, and the way
/// out (unlock with the recovery key, or start over with a new key).
struct SecurityLockedSections: View {
    let status: SecretsStatus
    let store: SecurityStatusStore
    @State private var key = ""
    @State private var unlocking = false
    @State private var error: Error?
    @State private var startOver = false

    private var missing: Bool { status.state == "locked_missing" }

    var body: some View {
        SettingsSection {
            SecurityHeroRow(symbol: "lock", tone: Theme.miss,
                            title: missing ? "Secrets are locked: fusionha can’t find its encryption key"
                                : "Secrets are locked: the encryption key doesn’t match",
                            sub: missing ? "This database was encrypted with a key that isn’t on this server. That happens when you restore a backup on a new machine. Nothing has been changed or deleted."
                                : "A key file is here, but it belongs to another install or an older rotation. Nothing has been changed or deleted.")
            if missing {
                fact("Expected key", SecretsCopy.groupFingerprint(status.keyFingerprint))
                fact("Looked in", [status.keyPath, "FUSIONHA_SECRET_KEY"].compactMap { $0 }.joined(separator: " · "))
            } else {
                fact("Found", SecretsCopy.groupFingerprint(status.foundFingerprint), color: Theme.danger,
                     detail: status.keyPath ?? "FUSIONHA_SECRET_KEY")
                fact("Expected", SecretsCopy.groupFingerprint(status.keyFingerprint))
            }
        }
        let lists = SecretsCopy.lockedLists(status.integrations)
        SettingsSection("Still works") {
            ForEach(lists.works, id: \.label) { row($0, symbol: "checkmark.circle", tint: Theme.done) }
        }
        SettingsSection("Paused until unlocked") {
            ForEach(lists.paused, id: \.label) { row($0, symbol: "pause.circle", tint: Theme.miss) }
            SecurityNote(symbol: "info.circle", text: "Paused, not failing. Nothing is marked failed, retried or backed off while secrets are locked. Unlocking resumes everything straight away and clears any backoff.", amber: false)
        }
        unlockSection
            .sheet(isPresented: $startOver) {
                SecurityStartOverSheet(secretCount: status.encryptedCount + status.unreadable.count,
                                       keyPath: status.keyPath, store: store)
            }
    }

    private var unlockSection: some View {
        Section {
            TextField("Recovery key", text: $key,
                      prompt: Text("Paste the recovery key, or the whole key file. It starts with fusionha-key-v1:"),
                      axis: .vertical)
                .font(.system(size: 12.5, design: .monospaced))
                .lineLimit(3...8)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: key) { error = nil }
            Button(unlocking ? "Unlocking…" : "Unlock", systemImage: "key") { Task { await unlock() } }
                .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || unlocking)
            Button("Start over with a new key…", role: .destructive) { startOver = true }
        } header: {
            Text("Recovery key")
        } footer: {
            if let error {
                Text(SecretsErrorCopy.message(for: error, keyPath: status.keyPath)).foregroundStyle(Theme.danger)
            } else {
                Text((missing ? "From the .txt you downloaded, or the key file from your old server."
                      : "Paste the right recovery key, or put the right key file back and restart.")
                     + " Nothing you paste is shown again or logged.")
            }
        }
        .listRowBackground(Theme.card)
    }

    private func fact(_ label: String, _ value: String, color: Color = Theme.txt, detail: String? = nil) -> some View {
        SettingValueRow(label: label, description: detail) {
            MonoText(value, color: color)
        }
    }

    private func row(_ r: SecretsLockedRow, symbol: String, tint: Color) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(r.label).font(.subheadline).foregroundStyle(Theme.txt)
                if let small = r.small { Text(small).font(.caption).foregroundStyle(Theme.mut) }
            }
        } icon: {
            Image(systemName: symbol).foregroundStyle(tint)
        }
    }

    private func unlock() async {
        guard let client = store.client else { return }
        unlocking = true
        defer { unlocking = false; key = "" }
        do {
            store.apply(try await client.unlockSecrets(key: key))
            error = nil
        } catch {
            self.error = error
        }
    }
}

/// Destructive: a new key; everything the old key encrypted becomes unreadable
/// (web `StartOverDialog`). Needs re-auth and the exact phrase.
struct SecurityStartOverSheet: View {
    let secretCount: Int
    let keyPath: String?
    let store: SecurityStatusStore
    @Environment(\.dismiss) private var dismiss
    @State private var reauth = SecurityReauth()
    @State private var confirm = ""
    @State private var error: Error?
    @State private var working = false

    private var phraseOK: Bool { confirm == SecretsCopy.startOverPhrase }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Only do this if the old key is gone for good.").foregroundStyle(Theme.mut)
                    SecurityNote(symbol: "exclamationmark.triangle", text: warning)
                }
                if let error, SecretsErrorCopy.isTooNew(error) {
                    SecurityTooNewNote(error: error, keyPath: keyPath)
                } else {
                    SecurityReauthSection(reauth: reauth, error: error.map { SecretsErrorCopy.message(for: $0, keyPath: keyPath) },
                                          plexDisabled: !phraseOK || working, keyPath: keyPath) { submit(.grant($0)) }
                        .onChange(of: reauth.password) { error = nil }
                    Section("Type \(SecretsCopy.startOverPhrase) to confirm") {
                        TextField(SecretsCopy.startOverPhrase, text: $confirm)
                            .font(.system(size: 14, design: .monospaced))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }
                }
            }
            .navigationTitle("Start over with a new key?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                if reauth.hasPassword {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(working ? "Starting over…" : "Start over", role: .destructive) {
                            submit(.password(reauth.password))
                        }
                        .disabled(!phraseOK || reauth.password.isEmpty || working || SecretsErrorCopy.isTooNew(error))
                    }
                }
            }
            .task { await reauth.loadMethods(client: store.client) }
        }
        .onDisappear { reauth.reset() }
    }

    private var warning: String {
        let first = secretCount > 0
            ? "All \(SecretsCopy.secrets(secretCount)) the old key encrypted become unreadable."
            : "Every secret the old key encrypted becomes unreadable."
        return first + " You’ll reset them and enter each password and API key again. Virtual-instance keys are regenerated, so Overseerr and Prowlarr need re-pairing."
    }

    private func submit(_ proof: SecretsProof) {
        guard let client = store.client, !working else { return }
        working = true
        Task {
            defer { working = false; reauth.password = "" }
            do {
                store.apply(try await client.startOverSecrets(proof, confirm: confirm))
                dismiss()
            } catch {
                self.error = error
            }
        }
    }
}
