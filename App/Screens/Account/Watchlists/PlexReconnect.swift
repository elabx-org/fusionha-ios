import SwiftUI
import FusionhaKit

/// "Sign in with Plex (again)" from the watchlist card (web `usePlexReconnect`):
/// the self-link PIN flow, since the server captures the watchlist token on the
/// user's own link. Opens Plex in Safari and polls every 2 s for up to 10 minutes.
@MainActor
@Observable
final class PlexReconnect {
    var authURL: URL?
    var busy = false
    private var task: Task<Void, Never>?

    func start(_ model: AppModel, then reload: @escaping @MainActor () async -> Void) {
        guard let client = model.client, let me = model.me else { return }
        task?.cancel()
        busy = true
        task = Task {
            defer { self.finish() }
            do {
                let pin = try await client.startPlexLink(userId: me.id)
                authURL = URL(string: pin.authUrl)
                let deadline = Date().addingTimeInterval(600)
                while !Task.isCancelled, Date() < deadline {
                    try await Task.sleep(for: .seconds(2))
                    if case .linked = try await client.checkPlexLink(userId: me.id, pinId: pin.id) {
                        authURL = nil
                        model.toast("Plex connected. Checking your watchlist…")
                        await model.loadMe()
                        await reload()
                        return
                    }
                }
            } catch is CancellationError {
            } catch {
                model.toast("Plex sign-in didn’t finish. Try again.", variant: .error)
            }
        }
    }

    func cancel() {
        task?.cancel()
        finish()
    }

    private func finish() {
        busy = false
        authURL = nil
    }
}
