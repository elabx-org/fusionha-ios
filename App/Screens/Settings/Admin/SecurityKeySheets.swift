import SwiftUI
import FusionhaKit

/// Re-auth, then the recovery key once (web `RecoveryKeyDialog`). The key lives
/// only in this sheet's state; closing it drops it.
struct SecurityRecoveryKeySheet: View {
    let keyPath: String?
    let store: SecurityStatusStore
    @Environment(\.dismiss) private var dismiss
    @State private var reauth = SecurityReauth()
    @State private var result: SecretsRecoveryKey?
    @State private var error: Error?
    @State private var working = false
    @State private var copied = false
    @State private var shareItem: FetchShareItem?

    var body: some View {
        NavigationStack {
            Form {
                if let result { keyView(result) } else { askView }
            }
            .navigationTitle(result == nil ? "Download recovery key" : "Your recovery key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if result == nil {
                    ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                }
                if result == nil && reauth.hasPassword && !SecretsErrorCopy.isTooNew(error) {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(working ? "Showing…" : "Show key") { submit(.password(reauth.password)) }
                            .disabled(reauth.password.isEmpty || working)
                    }
                }
                if result != nil {
                    ToolbarItem(placement: .confirmationAction) { SheetDoneButton { dismiss() } }
                }
            }
            .task { await reauth.loadMethods(client: store.client) }
            .sheet(item: $shareItem) { item in
                FetchActivityView(url: item.url).presentationDetents([.medium, .large]).ignoresSafeArea()
            }
        }
        .onDisappear {
            reauth.reset()
            result = nil
            if let url = shareItem?.url { try? FileManager.default.removeItem(at: url) }
        }
    }

    @ViewBuilder
    private var askView: some View {
        Section {
            Text(reauth.hasPassword ? "Enter your password to show the key." : "Confirm with Plex to show the key.")
                .foregroundStyle(Theme.mut)
        }
        if let error, SecretsErrorCopy.isTooNew(error) {
            SecurityTooNewNote(error: error, keyPath: keyPath)
        } else {
            SecurityReauthSection(reauth: reauth, error: error.map { SecretsErrorCopy.message(for: $0, keyPath: keyPath) },
                                  keyPath: keyPath) { submit(.grant($0)) }
                .onChange(of: reauth.password) { error = nil }
        }
    }

    @ViewBuilder
    private func keyView(_ key: SecretsRecoveryKey) -> some View {
        Section {
            Text(key.key)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Theme.txt)
                .textSelection(.enabled)
        } header: {
            Text("Fingerprint \(SecretsCopy.groupFingerprint(key.fingerprint))")
        } footer: {
            Text("The key is shown once. Closing this sheet clears it.")
        }
        Section {
            Button(copied ? "Copied" : "Copy", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = key.key
                copied = true
            }
            Button("Download .txt", systemImage: "arrow.down.circle") { share(key) }
        }
        Section {
            SecurityNote(symbol: "exclamationmark.triangle",
                         text: "Anyone with this key and a copy of your database can read your secrets. Keep it off this server.")
        }
    }

    private func submit(_ proof: SecretsProof) {
        guard let client = store.client, !working else { return }
        working = true
        Task {
            defer { working = false; reauth.password = "" }
            do {
                result = try await client.secretsRecoveryKey(proof)
                error = nil
            } catch {
                self.error = error
            }
            await store.load()
        }
    }

    private func share(_ key: SecretsRecoveryKey) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(key.filename)
        do {
            try key.key.write(to: url, atomically: true, encoding: .utf8)
            shareItem = FetchShareItem(url: url)
        } catch {
            self.error = error
        }
    }
}

/// Explains a rotation and asks for re-auth (web `RotateDialog`); starting it
/// closes the sheet and the card shows progress.
struct SecurityRotateSheet: View {
    let secretCount: Int
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
                    Text("Use this if the key or a backup that holds it may have been seen by someone else.")
                        .foregroundStyle(Theme.mut)
                }
                Section {
                    step(1, "fusionha makes a new key.", "It’s added next to the current key before anything changes.")
                    step(2, secretCount > 0 ? "All \(SecretsCopy.secrets(secretCount)) are re-encrypted with it." : "Every secret is re-encrypted with it.",
                         "Downloads, indexers and notifications keep running. It takes a few seconds.")
                    step(3, "The old key is retired, not deleted.",
                         "Backups made before today still need the old key. fusionha keeps it as a retired file next to the key file, and those backups keep working.")
                }
                Section {
                    SecurityNote(symbol: "arrow.down.circle",
                                 text: "Your current recovery key stops working for new backups. Download the new one when the rotation finishes.")
                }
                if let error, SecretsErrorCopy.isTooNew(error) {
                    SecurityTooNewNote(error: error, keyPath: keyPath)
                } else {
                    SecurityReauthSection(reauth: reauth, error: error.map { SecretsErrorCopy.message(for: $0, keyPath: keyPath) },
                                          plexDisabled: working, keyPath: keyPath) { submit(.grant($0)) }
                        .onChange(of: reauth.password) { error = nil }
                }
            }
            .navigationTitle("Rotate the encryption key?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                if reauth.hasPassword && !SecretsErrorCopy.isTooNew(error) {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(working ? "Rotating…" : "Rotate key") { submit(.password(reauth.password)) }
                            .disabled(reauth.password.isEmpty || working)
                    }
                }
            }
            .task { await reauth.loadMethods(client: store.client) }
        }
        .onDisappear { reauth.reset() }
    }

    private func step(_ n: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.i2)
                .frame(width: 22, height: 22)
                .background(Theme.i2.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                Text(detail).font(.footnote).foregroundStyle(Theme.mut)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private func submit(_ proof: SecretsProof) {
        guard let client = store.client, !working else { return }
        working = true
        Task {
            defer { working = false; reauth.password = "" }
            do {
                _ = try await client.rotateSecretsKey(proof)
                await store.load()
                dismiss()
            } catch {
                self.error = error
                await store.load()
            }
        }
    }
}
