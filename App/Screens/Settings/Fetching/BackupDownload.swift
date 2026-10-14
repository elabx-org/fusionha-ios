import SwiftUI
import FusionhaKit

/// Downloading a backup archive to the share sheet. Since fusionha 0.4.188 a
/// backup that holds the secret key needs your password again: those go
/// through the password prompt and `POST …/download`. A backup whose record
/// predates the flag gets the prompt when the plain download is refused with
/// `reauth_required`.
@MainActor
@Observable
final class BackupDownloader {
    var downloading: String?
    var shareItem: FetchShareItem?
    /// The backup waiting on a password.
    var passwordFor: BackupRecord?
    var password = ""

    func start(_ record: BackupRecord, client: APIClient?, toaster: FetchToaster) {
        if record.keyIncluded == true {
            password = ""
            passwordFor = record
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

    private func fetch(_ record: BackupRecord, password: String?, client: APIClient?, toaster: FetchToaster) {
        guard let client else { return }
        downloading = record.id
        Task {
            defer { downloading = nil }
            do {
                let data = try await client.downloadBackup(id: record.id, password: password)
                let dir = FileManager.default.temporaryDirectory.appendingPathComponent("backups", isDirectory: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let url = dir.appendingPathComponent(record.id)
                try? FileManager.default.removeItem(at: url)
                try data.write(to: url, options: .atomic)
                shareItem = FetchShareItem(url: url)
            } catch let error as APIError where error.code == "reauth_required" && password == nil {
                self.password = ""
                passwordFor = record
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
                Button("Cancel", role: .cancel) { downloader.password = "" }
            } message: { _ in
                Text("This backup contains the server’s secret key, so downloading it needs your password.")
            }
            .sheet(item: $downloader.shareItem) { item in
                FetchActivityView(url: item.url)
                    .presentationDetents([.medium, .large])
                    .ignoresSafeArea()
            }
    }
}
