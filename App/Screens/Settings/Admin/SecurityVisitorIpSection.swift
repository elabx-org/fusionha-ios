import SwiftUI
import FusionhaKit

/// Settings › Security › Visitor IP addresses (web `VisitorIpCard`): record
/// on/off and how long an audit row keeps its address. Saves each change.
struct SecurityVisitorIpSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.settingsPush) private var push
    @State private var settings: VisitorIpSettings?
    @State private var loadFailed = false
    @State private var saving = false
    @State private var saveError: String?

    var body: some View {
        SettingsSection("Visitor IP addresses", footer: saveError) {
            Text("The address and device behind each audit row and sign-in session, as your trusted proxies report it.")
                .font(.footnote).foregroundStyle(Theme.mut)
            if loadFailed {
                SettingsLoadingRow(error: "Couldn’t load this setting. Pull to refresh to try again.")
            } else if let settings {
                controls(settings)
            } else {
                SettingsLoadingRow()
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private func controls(_ s: VisitorIpSettings) -> some View {
        Toggle(isOn: Binding(get: { s.recordingEnabled }, set: { save(["recording_enabled": .bool($0)]) })) {
            FieldLabel(label: "Record visitor IP addresses on audit rows and sessions")
        }
        .tint(Theme.indigo)
        .disabled(saving)
        .settingsField("Record visitor IP addresses")
        Picker(selection: Binding(get: { s.retentionDays }, set: { save(["retention_days": .int($0)]) })) {
            if !VisitorIpSettings.retentionOptions.contains(where: { $0.0 == s.retentionDays }) {
                Text("\(s.retentionDays) days").tag(s.retentionDays)
            }
            ForEach(VisitorIpSettings.retentionOptions, id: \.0) { option in
                Text(option.1).tag(option.0)
            }
        } label: {
            FieldLabel(label: "Keep IPs on audit rows for")
        }
        .pickerStyle(.menu)
        .tint(Theme.mut)
        .disabled(saving)
        .settingsField("Keep IPs on audit rows for")
        VStack(alignment: .leading, spacing: 6) {
            Text(VisitorIpSettings.keepText(on: s.recordingEnabled, days: s.retentionDays))
            Text("A session’s address lives and ends with the session (sign-out or expiry).")
            Text("Admins only. Addresses never leave this server.")
            Text("Behind a reverse proxy, set trusted proxies first, or every visitor shows the proxy’s address.")
        }
        .font(.footnote)
        .foregroundStyle(Theme.mut)
        .fixedSize(horizontal: false, vertical: true)
        Button("Trusted proxies", systemImage: "arrow.right") { push("signin") }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            settings = try await client.visitorIpSettings()
            loadFailed = false
        } catch {
            loadFailed = settings == nil
        }
    }

    private func save(_ fields: [String: SettingsJSON]) {
        guard let client = model.client else { return }
        saveError = nil
        saving = true
        Task {
            defer { saving = false }
            do {
                settings = try await client.updateVisitorIpSettings(fields)
            } catch {
                saveError = "Couldn’t save. Try again."
            }
        }
    }
}
