import SwiftUI
import FusionhaKit

/// Admin: the server's APNs channel (`PUT /api/v1/notifications/apns/settings`).
/// The `.p8` key is write-only — leave it empty to keep the saved one.
struct ApnsSettingsSheet: View {
    let settings: ApnsSettings?
    let onSaved: (ApnsSettings) -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var keyId = ""
    @State private var teamId = ""
    @State private var topic = "org.elabx.fusionha"
    @State private var environment = "auto"
    @State private var authKey = ""
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        FetchFormSheet(title: "iOS push (APNs)",
                       subtitle: "From developer.apple.com → Certificates, IDs & Profiles → Keys: an APNs auth key, its Key ID, and your Team ID.",
                       canSave: !keyId.isEmpty && !teamId.isEmpty && !topic.isEmpty
                           && (settings?.authKeySet == true || !authKey.isEmpty),
                       saving: saving,
                       onCancel: { dismiss() },
                       onSave: save) {
            Section {
                FetchTextRow(label: "Key ID", text: $keyId, prompt: "ABC123DEFG", mono: true)
                FetchTextRow(label: "Team ID", text: $teamId, prompt: "TEAM123456", mono: true)
                FetchTextRow(label: "Bundle ID", text: $topic, prompt: "org.elabx.fusionha", mono: true,
                             hint: "The app's APNs topic.")
                Picker("Environment", selection: $environment) {
                    Text("Auto").tag("auto")
                    Text("Sandbox").tag("sandbox")
                    Text("Production").tag("production")
                }
            } footer: {
                Text("Auto sends each device to the gateway its build reports (sandbox for development-signed builds) and corrects itself if Apple disagrees.")
            }
            Section {
                TextEditor(text: $authKey)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 120)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .overlay(alignment: .topLeading) {
                        if authKey.isEmpty {
                            Text(settings?.authKeySet == true ? "A key is saved. Paste a new one to replace it."
                                                              : "-----BEGIN PRIVATE KEY-----")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Theme.dim)
                                .padding(.top, 8).padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                PasteButton(payloadType: String.self) { strings in
                    if let first = strings.first { authKey = first }
                }
            } header: {
                Text("Auth key (.p8)")
            } footer: {
                Text("The contents of AuthKey_<KeyID>.p8. It is stored on the server and never shown again.")
            }
            if let error {
                Section { Text(error).foregroundStyle(Theme.danger).font(.system(size: 12.5)) }
            }
        }
        .onAppear {
            guard let settings else { return }
            keyId = settings.keyId
            teamId = settings.teamId
            topic = settings.topic
            environment = settings.environment
        }
    }

    private func save() {
        guard let client = model.client else { return }
        var body: [String: SettingsJSON] = [
            "key_id": .string(keyId.trimmingCharacters(in: .whitespaces)),
            "team_id": .string(teamId.trimmingCharacters(in: .whitespaces)),
            "topic": .string(topic.trimmingCharacters(in: .whitespaces)),
            "environment": .string(environment),
        ]
        let key = authKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty { body["auth_key"] = .string(key) }
        saving = true
        error = nil
        Task {
            do {
                let saved = try await client.updateApnsSettings(.object(body))
                onSaved(saved)
                dismiss()
            } catch {
                self.error = error.settingsMessage
            }
            saving = false
        }
    }
}
