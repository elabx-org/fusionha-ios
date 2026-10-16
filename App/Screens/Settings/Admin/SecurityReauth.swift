import SwiftUI
import FusionhaKit

/// The re-auth step of the Security sheets (web `ReauthField` / `useReauth`):
/// the password, "Confirm with Plex", or both, depending on how the account
/// signs in. While the methods load (or can't be read) the password shows.
@MainActor
@Observable
final class SecurityReauth {
    var hasPassword = true
    var hasPlex = false
    var password = ""
    var waiting = false
    var timedOut = false
    var plexError: Error?
    /// Plex's approval page while a Plex re-auth is waiting.
    var plexPage: URL?
    private var task: Task<Void, Never>?

    func loadMethods(client: APIClient?) async {
        guard let client, let methods = try? await client.reauthMethods() else { return }
        hasPlex = methods.contains("plex")
        hasPassword = methods.contains("password") || !hasPlex
    }

    /// Opens Plex and polls every 2 s for the grant (15 minutes, like the web).
    func startPlex(client: APIClient?, onGrant: @escaping (String) -> Void) {
        guard let client else { return }
        task?.cancel()
        plexError = nil
        timedOut = false
        waiting = true
        task = Task {
            do {
                let pin = try await client.startPlexReauth()
                plexPage = URL(string: pin.authUrl)
                let deadline = Date().addingTimeInterval(15 * 60)
                while waiting, Date() < deadline {
                    try await Task.sleep(for: .seconds(2))
                    if let grant = try await client.checkPlexReauth(pinId: pin.id) {
                        finish()
                        onGrant(grant)
                        return
                    }
                }
                if waiting { finish(); timedOut = true }
            } catch is CancellationError {
            } catch {
                finish()
                plexError = error
            }
        }
    }

    func cancel() {
        task?.cancel()
        finish()
    }

    func reset() {
        cancel()
        password = ""
        timedOut = false
        plexError = nil
    }

    private func finish() {
        waiting = false
        plexPage = nil
    }
}

/// The password field and / or the Plex button, with the refusal under them.
struct SecurityReauthSection: View {
    @Bindable var reauth: SecurityReauth
    /// The server's refusal, already through `SecretsErrorCopy`.
    let error: String?
    var plexDisabled = false
    var keyPath: String?
    let onPlexGrant: (String) -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        Section {
            if reauth.hasPassword {
                SecureField(model.me.map { "Password for \($0.username)" } ?? "Password", text: $reauth.password)
                    .textContentType(.password)
                    .onChange(of: reauth.password) { reauth.plexError = nil }
            }
            if reauth.hasPlex { plexRow }
        } header: {
            Text(reauth.hasPassword ? "Your password" : "Confirm it’s you")
        } footer: {
            footer
        }
        .sheet(item: $reauth.plexPage, onDismiss: { if reauth.waiting { reauth.cancel() } }) { page in
            SafariView(url: page).ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var plexRow: some View {
        if reauth.waiting {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Waiting for Plex…").foregroundStyle(Theme.mut)
                Spacer(minLength: 0)
                Button("Cancel") { reauth.cancel() }
            }
        } else {
            Button(reauth.timedOut ? "Try again with Plex" : "Confirm with Plex", systemImage: "key") {
                reauth.startPlex(client: model.client, onGrant: onPlexGrant)
            }
            .disabled(plexDisabled)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let shown {
            Text(shown).foregroundStyle(Theme.danger)
        } else {
            Text(reauth.hasPassword ? SecretsCopy.passwordHint : SecretsCopy.plexHint)
        }
    }

    private var shown: String? {
        if let e = reauth.plexError { return SecretsErrorCopy.message(for: e, keyPath: keyPath) }
        if reauth.timedOut { return SecretsCopy.plexTimeout }
        return error
    }
}

/// The `reauth_too_new` refusal as an amber wait note (replaces the field).
struct SecurityTooNewNote: View {
    let error: Error
    let keyPath: String?

    var body: some View {
        let parts = SecretsErrorCopy.split(SecretsErrorCopy.message(for: error, keyPath: keyPath))
        Section {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(parts.head).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                    if !parts.rest.isEmpty { Text(parts.rest).font(.footnote).foregroundStyle(Theme.mut) }
                }
            } icon: {
                Image(systemName: "clock").foregroundStyle(Theme.miss)
            }
            .listRowBackground(Theme.miss.opacity(0.10))
        }
    }
}

/// An amber (or neutral) note row, the web's `.note` / `.noteAmber`.
struct SecurityNote: View {
    let symbol: String
    let text: String
    var amber = true

    var body: some View {
        Label {
            Text(text).font(.footnote).foregroundStyle(Theme.txt).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).foregroundStyle(amber ? Theme.miss : Theme.i2)
        }
        .listRowBackground((amber ? Theme.miss : Theme.i2).opacity(0.10))
    }
}
