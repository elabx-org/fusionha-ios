import SwiftUI
import FusionhaKit

/// First run: server address, then whichever sign-in methods that server offers
/// (username/password and/or Plex), mirroring the web login.
struct SignInView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("lastServer") private var server = ""
    @State private var connected: (url: URL, status: SetupStatus)?
    @State private var username = ""
    @State private var password = ""
    @State private var working = false
    @State private var error: String?
    @State private var plexURL: URL?
    @State private var plexTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Theme.fusion)
                        Text("fusionha").font(.title.bold())
                        Text(connected == nil ? "Connect to your server" : "Sign in")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                if let connected {
                    methods(url: connected.url, status: connected.status)
                } else {
                    serverSection
                }

                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(Theme.danger) }
                }
            }
            .disabled(working)
            .sheet(item: $plexURL, onDismiss: cancelPlex) { url in
                SafariView(url: url).ignoresSafeArea()
            }
        }
    }

    // MARK: Step 1 — server

    private var serverSection: some View {
        Section {
            TextField("192.168.1.10:8787 or https://…", text: $server)
                .textContentType(.URL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { Task { await connect() } }
            Button {
                Task { await connect() }
            } label: {
                progressLabel("Continue")
            }
            .buttonStyle(.glassProminent)
            .disabled(server.isEmpty)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        } header: {
            Text("Server")
        } footer: {
            Text("The address you open fusionha's web app at.")
        }
    }

    // MARK: Step 2 — sign-in methods

    @ViewBuilder
    private func methods(url: URL, status: SetupStatus) -> some View {
        Section("Server") {
            HStack {
                Label(url.host() ?? url.absoluteString, systemImage: "server.rack")
                Spacer()
                Button("Change") {
                    connected = nil
                    error = nil
                }
            }
        }

        if status.needsSetup {
            Section {
                Text("This server hasn't been set up yet. Finish the first-run setup in the web app, then come back.")
                Link("Open the web app", destination: url)
            }
        } else {
            if status.offersPassword {
                Section("fusionha account") {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .onSubmit { Task { await passwordSignIn(url: url) } }
                    Button {
                        Task { await passwordSignIn(url: url) }
                    } label: {
                        progressLabel("Sign in")
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(username.isEmpty || password.isEmpty)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            if status.offersPlex {
                Section {
                    Button {
                        Task { await startPlex(url: url) }
                    } label: {
                        Label("Sign in with Plex", systemImage: "play.rectangle.fill")
                            .bold()
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glass)
                    .tint(Color(hex: 0xE5A00D))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } footer: {
                    if plexTask != nil {
                        Text("Waiting for Plex to confirm…")
                    }
                }
            }
            if !status.offersPassword && !status.offersPlex {
                Section { Text("This server has no sign-in method enabled for apps.") }
            }
        }
    }

    private func progressLabel(_ title: String) -> some View {
        Group {
            if working { ProgressView() } else { Text(title).bold() }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }

    // MARK: Actions

    private func connect() async {
        await run {
            let (url, status) = try await model.connect(server: server)
            connected = (url, status)
        }
    }

    private func passwordSignIn(url: URL) async {
        await run { try await model.signIn(server: url, username: username, password: password) }
    }

    private func startPlex(url: URL) async {
        await run {
            let pin = try await model.startPlexSignIn(server: url)
            guard let auth = URL(string: pin.authUrl) else { throw APIError.http(status: 502, body: "") }
            plexURL = auth
            plexTask = Task {
                do {
                    try await model.completePlexSignIn(server: url, pin: pin)
                    plexURL = nil
                } catch is CancellationError {
                } catch APIError.http(403, _) {
                    plexURL = nil
                    error = "That Plex account doesn't have access to this server."
                } catch {
                    plexURL = nil
                    self.error = error.localizedDescription
                }
                plexTask = nil
            }
        }
    }

    private func cancelPlex() {
        plexTask?.cancel()
        plexTask = nil
    }

    private func run(_ work: () async throws -> Void) async {
        working = true
        error = nil
        defer { working = false }
        do {
            try await work()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
