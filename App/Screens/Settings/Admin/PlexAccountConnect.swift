import SwiftUI
import FusionhaKit

/// The Plex SSO sheet's "Plex account" field (web `PlexAccountField`): the
/// connected server and "Connect Plex account". Mints a PIN, opens Plex and
/// polls every 2 s (10 minutes) until the server has stored the owner token.
/// Connecting is full-admin only.
struct PlexAccountConnectSection: View {
    let canConnect: Bool
    let toaster: FetchToaster
    @Environment(SettingsStore.self) private var store
    @Environment(AppModel.self) private var model
    @State private var starting = false
    @State private var waiting = false
    @State private var page: URL?
    @State private var connected: SignInPlexConnectResult?
    @State private var task: Task<Void, Never>?

    var body: some View {
        Section {
            if let connected {
                connectedRow(connected.serverName ?? "Plex", members: connected.memberCount)
            } else if waiting {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Waiting for Plex authorization…").foregroundStyle(Theme.mut)
                    Spacer(minLength: 0)
                    Button("Cancel") { cancel() }
                }
            } else {
                if store.bool("plex_owner_token_set") {
                    let name = store.string("plex_server_name")
                    connectedRow(name.isEmpty ? "Plex" : name, members: nil)
                }
                if canConnect {
                    Button(starting ? "Starting…" : (store.bool("plex_owner_token_set") ? "Reconnect a different account" : "Connect Plex account"),
                           systemImage: "link") { start() }
                        .disabled(starting)
                }
            }
        } header: {
            Text("Plex account")
        } footer: {
            Text(canConnect
                 ? "Signs in as the server owner to resolve its shared users — the admin never pastes a token."
                 : "Only a full admin can connect or change the Plex account: it decides who can sign in and who gets UHD·4K.")
        }
        // Closing Plex keeps polling: it may already have approved.
        .sheet(item: $page) { url in
            SafariView(url: url).ignoresSafeArea()
        }
    }

    private func connectedRow(_ server: String, members: Int?) -> some View {
        Label {
            Text(LocalizedStringKey(members.map { "Connected to **\(server)** · **\($0)** members" } ?? "Connected to **\(server)**"))
                .font(.subheadline)
        } icon: {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.done)
        }
        .listRowBackground(Theme.done.opacity(0.10))
    }

    private func start() {
        guard let client = model.client else { return }
        starting = true
        task?.cancel()
        task = Task {
            do {
                let pin = try await client.startPlexConnect()
                starting = false
                waiting = true
                page = URL(string: pin.authUrl)
                let deadline = Date().addingTimeInterval(10 * 60)
                while waiting, Date() < deadline {
                    try await Task.sleep(for: .seconds(2))
                    let result = try await client.checkPlexConnect(pinId: pin.id)
                    if result.connected {
                        connected = result
                        finish()
                        await store.load()
                        return
                    }
                }
                if waiting {
                    finish()
                    toaster.show("The authorization window expired. Please try again.", title: "Plex connect timed out", tone: .error)
                }
            } catch is CancellationError {
            } catch {
                let title = waiting ? "Could not connect a Plex account" : "Could not start the Plex connect flow"
                starting = false
                finish()
                toaster.show(error.settingsMessage, title: title, tone: .error)
            }
        }
    }

    private func finish() {
        waiting = false
        page = nil
    }

    private func cancel() {
        task?.cancel()
        task = nil
        starting = false
        finish()
    }
}

/// Advanced (full admin): the manual owner token and the connection test —
/// the fallback for a headless setup.
struct PlexSSOAdvancedSection: View {
    let toaster: FetchToaster
    @Binding var expanded: Bool
    @Environment(SettingsStore.self) private var store
    @Environment(AppModel.self) private var model
    @State private var token = ""
    @State private var saving = false
    @State private var testing = false
    @State private var result: SignInPlexTestResult?

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $expanded) {
                SecureField(store.bool("plex_owner_token_set") ? "•••• (configured)" : "Paste the owner's X-Plex-Token", text: $token)
                    .textContentType(.password)
                    .onSubmit { Task { await saveToken() } }
                Button(saving ? "Saving…" : "Save token") { Task { await saveToken() } }
                    .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty || saving)
                FieldLabel(label: "Test connection",
                           description: result?.summary ?? "Validate the configured owner token.")
                Button(testing ? "Testing…" : "Test connection", systemImage: "bolt.horizontal") { Task { await test() } }
                    .disabled(testing)
            } label: {
                FieldLabel(label: "Advanced",
                           description: "Manual owner-token entry + a connection test — the fallback for a headless setup with no browser popup.")
            }
        } footer: {
            if expanded { Text("The owner token is never returned by the API — reads only report plex_owner_token_set: true.") }
        }
    }

    private func saveToken() async {
        let trimmed = token.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !saving else { return }
        saving = true
        defer { saving = false }
        do {
            try await SignInSettings.put(["plex_owner_token": .string(trimmed)], store: store)
            token = ""
        } catch {
            toaster.show(error.settingsMessage, title: "Could not save the owner token", tone: .error)
        }
    }

    private func test() async {
        guard let client = model.client else { return }
        testing = true
        defer { testing = false }
        do {
            result = try await client.testPlexOwnerToken()
        } catch {
            toaster.show(error.settingsMessage, title: "Could not test the Plex connection", tone: .error)
        }
    }
}
