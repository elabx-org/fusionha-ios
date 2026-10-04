import Foundation
import Observation
import UIKit
import WidgetKit
import FusionhaKit

enum AppTab: Hashable {
    case library, calendar, activity, wanted, search
}

@MainActor
@Observable
final class AppModel {
    var credentials: Credentials? = CredentialStore.load()
    var tab: AppTab = .library

    // Queue state drives the Activity tab, the downloads accessory, the
    // Live Activity and the Downloads widget.
    private(set) var queue: [QueueItem] = []
    private(set) var queueTotal = 0
    private(set) var queueError: String?
    private var lastQueueIds: [Int] = []

    var client: APIClient? {
        credentials?.client()
    }

    // MARK: Sign-in

    /// Step 1: check the server is a reachable fusionha and see which sign-in
    /// methods it offers (`GET /health`, `GET /api/v1/setup-status`).
    func connect(server: String) async throws -> (URL, SetupStatus) {
        guard let url = APIClient.normalisedServerURL(server) else { throw APIError.invalidServerURL }
        let anonymous = APIClient(baseURL: url, token: nil)
        _ = try await anonymous.health()
        return (url, try await anonymous.setupStatus())
    }

    /// Step 2a: username and password (sets the session cookie).
    func signIn(server url: URL, username: String, password: String) async throws {
        let anonymous = APIClient(baseURL: url, token: nil)
        try await anonymous.login(username: username, password: password)
        try await finishSignIn(with: anonymous)
    }

    /// Step 2b: Plex. Mints a PIN whose `authUrl` the user opens in a browser sheet.
    func startPlexSignIn(server url: URL) async throws -> PlexPin {
        try await APIClient(baseURL: url, token: nil).createPlexPin()
    }

    /// Polls the PIN every 2s, like the web login, until Plex confirms (the server
    /// then sets the session cookie). Cancel the task to stop waiting.
    func completePlexSignIn(server url: URL, pin: PlexPin) async throws {
        let anonymous = APIClient(baseURL: url, token: nil)
        while true {
            try Task.checkCancellation()
            if try await anonymous.checkPlexPin(id: pin.id) == .signedIn { break }
            try await Task.sleep(for: .seconds(2))
        }
        try await finishSignIn(with: anonymous)
    }

    /// With a session cookie in place, mint a personal API token for this device so
    /// the widgets can call the API too.
    private func finishSignIn(with anonymous: APIClient) async throws {
        let url = anonymous.baseURL
        let creds: Credentials
        do {
            let mint = try await anonymous.mintToken(name: "fusionha iOS · \(UIDevice.current.name)")
            creds = Credentials(serverURL: url, token: mint.token, tokenId: mint.id)
        } catch APIError.http(403, _) {
            // Accounts without `tokens.manage.self` (e.g. requesters) fall back to the session token.
            guard let session = anonymous.sessionTokenFromCookie() else { throw APIError.http(status: 403, body: "") }
            creds = Credentials(serverURL: url, token: session, tokenId: nil, method: .session)
        }
        CredentialStore.save(creds)
        credentials = creds
        AppDelegate.requestPushAuthorization()
    }

    func signOut() {
        CredentialStore.clear()
        credentials = nil
        queue = []
        queueTotal = 0
        LiveActivityController.endAll()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Queue polling (no stream on the server, so poll like the web does)

    func pollQueue() async {
        while !Task.isCancelled {
            await refreshQueue()
            let interval: Double = queue.isEmpty ? 6 : 2
            try? await Task.sleep(for: .seconds(interval))
        }
    }

    func refreshQueue() async {
        guard let client else { return }
        do {
            let page = try await client.queue()
            queue = page.items
            queueTotal = page.total
            queueError = nil
            LiveActivityController.sync(with: page.items)
            let ids = page.items.map(\.id)
            if ids != lastQueueIds {
                lastQueueIds = ids
                WidgetCenter.shared.reloadTimelines(ofKind: "Downloads")
            }
        } catch {
            queueError = error.localizedDescription
        }
    }
}
