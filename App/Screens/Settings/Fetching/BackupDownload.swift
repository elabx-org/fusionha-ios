import SwiftUI
import FusionhaKit

/// Downloading a backup archive to the share sheet. Since fusionha 0.4.188 a
/// backup that holds the secret key needs your password again: those go
/// through the password prompt and `POST …/download`. A backup whose record
/// predates the flag gets the prompt when the plain download is refused with
/// `reauth_required`. A Plex-only account confirms with Plex instead
/// (`BackupPlexReauth`, fusionha 0.4.191); an account with both can pick it.
@MainActor
@Observable
final class BackupDownloader {
    var downloading: String?
    var shareItem: FetchShareItem?
    /// The backup waiting on a password.
    var passwordFor: BackupRecord?
    var password = ""
    /// The account can confirm with Plex (offered beside the password).
    var plexOffered = false
    /// The Plex approval page while a Plex re-auth is waiting.
    var plexPage: FetchShareItem?
    private var plexTask: Task<Void, Never>?

    func start(_ record: BackupRecord, client: APIClient?, toaster: FetchToaster) {
        if record.keyIncluded == true {
            askForReauth(record, client: client, toaster: toaster)
        } else {
            fetch(record, password: nil, client: client, toaster: toaster)
        }
    }

    func submitPassword(client: APIClient?, toaster: FetchToaster) {
        guard let record = passwordFor else { return }
        passwordFor = nil
        let typed = password
        password = ""
        fetch(record, password: typed, client: client, toaster: toaster)
    }

    /// The password prompt, or straight to Plex for a Plex-only account.
    private func askForReauth(_ record: BackupRecord, client: APIClient?, toaster: FetchToaster) {
        Task {
            let methods = (try? await client?.reauthMethods()) ?? ["password"]
            plexOffered = methods.contains("plex")
            if plexOffered && !methods.contains("password") {
                confirmWithPlex(record, client: client, toaster: toaster)
            } else {
                password = ""
                passwordFor = record
            }
        }
    }

    /// Opens Plex's approval page and polls every 2 s (10 minutes, like sign-in);
    /// the grant then downloads the backup.
    func confirmWithPlex(_ record: BackupRecord, client: APIClient?, toaster: FetchToaster) {
        guard let client else { return }
        passwordFor = nil
        plexTask?.cancel()
        plexTask = Task {
            do {
                let pin = try await client.startPlexReauth()
                guard let page = URL(string: pin.authUrl) else { return }
                plexPage = FetchShareItem(url: page)
                let deadline = Date().addingTimeInterval(600)
                while plexPage != nil, Date() < deadline {
                    try await Task.sleep(for: .seconds(2))
                    if let grant = try await client.checkPlexReauth(pinId: pin.id) {
                        plexPage = nil
                        fetch(record, password: nil, grant: grant, client: client, toaster: toaster)
                        return
                    }
                }
                if plexPage != nil {
                    plexPage = nil
                    toaster.show("Plex didn't confirm in time. Try again.", title: "Download cancelled", tone: .error)
                }
            } catch is CancellationError {
            } catch {
                plexPage = nil
                toaster.show(ErrorCopy.message(for: error, fallback: error.settingsMessage),
                             title: "Plex didn't confirm", tone: .error)
            }
        }
    }

    func cancelPlex() {
        plexTask?.cancel()
        plexPage = nil
    }

    private func fetch(_ record: BackupRecord, password: String?, grant: String? = nil,
                       client: APIClient?, toaster: FetchToaster) {
        guard let client else { return }
        downloading = record.id
        Task {
            defer { downloading = nil }
            do {
                let data = try await client.downloadBackup(id: record.id, password: password, grant: grant)
                let dir = FileManager.default.temporaryDirectory.appendingPathComponent("backups", isDirectory: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let url = dir.appendingPathComponent(record.id)
                try? FileManager.default.removeItem(at: url)
                try data.write(to: url, options: .atomic)
                shareItem = FetchShareItem(url: url)
            } catch let error as APIError where error.code == "reauth_required" && password == nil && grant == nil {
                askForReauth(record, client: client, toaster: toaster)
            } catch {
                toaster.show(ErrorCopy.message(for: error, fallback: error.settingsMessage),
                             title: "Download failed", tone: .error)
            }
        }
    }
}

extension View {
    /// The password prompt and the share sheet for `BackupDownloader`.
    func backupDownloadUI(_ downloader: BackupDownloader, client: APIClient?, toaster: FetchToaster) -> some View {
        @Bindable var downloader = downloader
        return self
            .alert("Enter your password",
                   isPresented: Binding(get: { downloader.passwordFor != nil },
                                        set: { if !$0 { downloader.passwordFor = nil } }),
                   presenting: downloader.passwordFor) { _ in
                SecureField("Password", text: $downloader.password)
                    .textContentType(.password)
                Button("Download") { downloader.submitPassword(client: client, toaster: toaster) }
                if downloader.plexOffered, let record = downloader.passwordFor {
                    Button("Confirm with Plex") { downloader.confirmWithPlex(record, client: client, toaster: toaster) }
                }
                Button("Cancel", role: .cancel) { downloader.password = "" }
            } message: { _ in
                Text("This backup contains the server’s secret key, so downloading it needs your password.")
            }
            // On its own host view: two sheets on one view can't both present.
            .background {
                Color.clear.sheet(item: Binding(get: { downloader.plexPage },
                                                set: { if $0 == nil { downloader.cancelPlex() } })) { page in
                    SafariView(url: page.url).ignoresSafeArea()
                }
            }
            .sheet(item: $downloader.shareItem) { item in
                FetchActivityView(url: item.url)
                    .presentationDetents([.medium, .large])
                    .ignoresSafeArea()
            }
    }
}
