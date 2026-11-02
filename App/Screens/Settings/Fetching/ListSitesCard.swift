import SwiftUI
import FusionhaKit

/// Settings › Indexers "List sites" (web `ListSitesCard`, fusionha 0.4.237):
/// the Trakt app id (client id) that lets people follow Trakt lists.
/// Write-only: the value is never read back, only Set / Not set.
struct ListSitesCard: View {
    @Environment(AppModel.self) private var model
    @State private var isSet = false
    @State private var value = ""
    @State private var saving = false
    @State private var saved = false
    @State private var error: String?

    private var isAdmin: Bool { model.me?.isAdmin == true }
    private static let label = "Trakt app id"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("List sites").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt)
            Text("People can follow public lists from MDBList and Trakt. MDBList needs nothing. Trakt needs an app id from trakt.tv/oauth/applications (only the client id; no secret, no sign-in).")
                .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            HStack(spacing: 8) {
                ProviderChip(provider: .mdblist)
                ProviderChip(provider: .trakt)
            }
            if isAdmin { editor } else {
                Label("Only an admin can change the Trakt app id.", systemImage: "lock")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.dim)
            }
        }
        .fetchCard()
        .task(id: isAdmin) { if isAdmin { await load() } }
    }

    @ViewBuilder private var editor: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Self.label).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.txt)
                Spacer()
                Text(isSet ? "Set" : "Not set")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSet ? Theme.text(.done) : Theme.dim)
            }
            SecureField(isSet ? "Saved · paste a new one to replace it" : "Paste the client id", text: $value)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.none)
                .textFieldStyle(.roundedBorder)
                .settingsField(Self.label)
            Label("Admin only. Stored encrypted and never shown again. Without it, followed Trakt lists wait as Unavailable.",
                  systemImage: "lock")
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
        }
        HStack(spacing: 8) {
            if saved { Label("Saved", systemImage: "checkmark").font(.caption).foregroundStyle(Theme.text(.done)) }
            Spacer()
            Button("Clear", systemImage: "trash") { Task { await clear() } }
                .buttonStyle(.web(.ghost))
                .disabled(!isSet || saving)
            Button(saving ? "Saving…" : "Save") { Task { await save() } }
                .buttonStyle(.web())
                .disabled(value.trimmingCharacters(in: .whitespaces).isEmpty || saving)
        }
        if let error { Text(error).font(.system(size: 12.5)).foregroundStyle(Theme.danger) }
    }

    private func load() async {
        guard let client = model.client, let settings = try? await client.settings() else { return }
        isSet = settings["trakt_client_id_set"]?.bool ?? false
    }

    private func save() async {
        guard let client = model.client else { return }
        await run {
            let fresh = try await client.setTraktClientId(value.trimmingCharacters(in: .whitespaces))
            isSet = fresh["trakt_client_id_set"]?.bool ?? true
            value = ""
        }
    }

    private func clear() async {
        guard let client = model.client else { return }
        await run {
            try await client.clearTraktClientId()
            isSet = false
        }
    }

    private func run(_ call: () async throws -> Void) async {
        saving = true
        saved = false
        error = nil
        defer { saving = false }
        do {
            try await call()
            saved = true
        } catch {
            self.error = "Couldn’t save. Try again."
        }
    }
}
