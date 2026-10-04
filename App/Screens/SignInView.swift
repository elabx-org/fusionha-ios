import SwiftUI
import FusionhaKit

struct SignInView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("lastServer") private var server = ""
    @State private var username = ""
    @State private var password = ""
    @State private var working = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Theme.fusion)
                        Text("fusionha").font(.title.bold())
                        Text("Sign in to your server").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section("Server") {
                    TextField("192.168.1.10:8787 or https://…", text: $server)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Account") {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }

                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(Theme.danger) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task { await signIn() }
                } label: {
                    Group {
                        if working { ProgressView() } else { Text("Sign in").bold() }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .disabled(working || server.isEmpty || username.isEmpty || password.isEmpty)
                .padding()
            }
        }
    }

    private func signIn() async {
        working = true
        error = nil
        defer { working = false }
        do {
            try await model.signIn(server: server, username: username, password: password)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
