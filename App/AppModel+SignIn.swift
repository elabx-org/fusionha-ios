import Foundation
import UIKit
import WidgetKit
import FusionhaKit

enum PlexSignInError: Error {
    case timedOut
}

extension AppModel {
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
    /// `beforeEnter` runs once the password is accepted and the token minted,
    /// just before the app switches over (the Living logo's unlock plays there).
    func signIn(server url: URL, username: String, password: String,
                beforeEnter: (() async -> Void)? = nil) async throws {
        let anonymous = APIClient(baseURL: url, token: nil)
        try await anonymous.login(username: username, password: password)
        try await finishSignIn(with: anonymous, beforeEnter: beforeEnter)
    }

    /// First run: create the first admin on a fresh server. Returns the signed-in
    /// (cookie) client the wizard keeps using until `enterAfterSetup`.
    func createFirstAdmin(server url: URL, username: String, password: String) async throws -> APIClient {
        let anonymous = APIClient(baseURL: url, token: nil)
        try await anonymous.createFirstAdmin(username: username, password: password)
        return anonymous
    }

    /// The wizard's last step: mint this device's token and enter the app.
    func enterAfterSetup(_ session: APIClient) async throws {
        try await finishSignIn(with: session)
    }

    /// Step 2b: Plex. Mints a PIN whose `authUrl` the user opens in a browser sheet.
    func startPlexSignIn(server url: URL) async throws -> PlexPin {
        try await APIClient(baseURL: url, token: nil).createPlexPin()
    }

    /// Polls the PIN every 2s, like the web login, until Plex confirms (the server
    /// then sets the session cookie). Cancel the task to stop waiting.
    /// `authorized` runs before the app switches away from the sign-in screen, so
    /// the caller can close the Plex browser sheet while it can still dismiss it.
    func completePlexSignIn(server url: URL, pin: PlexPin, authorized: () async -> Void) async throws {
        let anonymous = APIClient(baseURL: url, token: nil)
        // The web gives up after 10 minutes.
        let deadline = Date().addingTimeInterval(600)
        while true {
            try Task.checkCancellation()
            if try await anonymous.checkPlexPin(id: pin.id) == .signedIn { break }
            if Date() > deadline { throw PlexSignInError.timedOut }
            try await Task.sleep(for: .seconds(2))
        }
        await authorized()
        try await finishSignIn(with: anonymous)
    }

    /// "Explore the demo": `POST /api/v1/demo/login` sets the read-only demo
    /// cookie, which this device then replays on every call.
    func demoSignIn(server url: URL, username: String?, password: String?) async throws {
        let anonymous = APIClient(baseURL: url, token: nil)
        try await anonymous.demoLogin(DemoLoginRequest(username: username, password: password))
        guard let token = anonymous.demoTokenFromCookie() else { throw APIError.http(status: 401, body: "") }
        let creds = Credentials(serverURL: url, token: token, tokenId: nil, method: .demoCookie)
        CredentialStore.save(creds)
        credentials = creds
    }

    /// OIDC providers offered on the login page (older servers have none).
    func signInProviders(server url: URL) async -> [SignInProvider] {
        let list = (try? await APIClient(baseURL: url, token: nil).authProviders()) ?? []
        return list.filter { $0.kind == "oidc" && $0.authorizeUrl != nil }
    }

    /// With a session cookie in place, mint a personal API token for this device so
    /// the widgets can call the API too.
    private func finishSignIn(with anonymous: APIClient, beforeEnter: (() async -> Void)? = nil) async throws {
        let url = anonymous.baseURL
        let creds: Credentials
        do {
            // v2's token gets its own name so Settings › API tokens tells the installs apart.
            #if V2
            let tokenName = "fusionha v2 iOS · \(UIDevice.current.name)"
            #else
            let tokenName = "fusionha iOS · \(UIDevice.current.name)"
            #endif
            let mint = try await anonymous.mintToken(name: tokenName)
            creds = Credentials(serverURL: url, token: mint.token, tokenId: mint.id)
        } catch APIError.http(403, _) {
            // Accounts without `tokens.manage.self` (e.g. requesters) fall back to the session token.
            guard let session = anonymous.sessionTokenFromCookie() else { throw APIError.http(status: 403, body: "") }
            creds = Credentials(serverURL: url, token: session, tokenId: nil, method: .session)
        }
        await beforeEnter?()
        CredentialStore.save(creds)
        WebSessionStore.save(anonymous.sessionTokenFromCookie(), server: url) // Settings web panels sign in with it.
        credentials = creds
        // The first load belongs to the model, not to a view: the sign-in →
        // app hand-over can cancel a view's `.task` mid-fetch.
        Task {
            await loadMe()
            if !requestScoped, !libraryLoaded { await loadLibrary() }
        }
        WidgetCenter.shared.reloadAllTimelines()
        AppDelegate.requestPushAuthorization()
        // A token from an earlier session registers right away; a fresh one
        // arrives via `.apnsTokenChanged`.
        await registerPushDevice()
    }

    // MARK: Sign-out

    /// Log out: end the server session and revoke this device's token, then
    /// forget the credentials.
    func logOut() async {
        if let client, let creds = credentials {
            // Stop pushes to this phone for the account that is leaving.
            await PushRegistration.unregister(with: client)
            try? await client.logout()
            if let tokenId = creds.tokenId { try? await client.revokeToken(id: tokenId) }
        }
        signOut()
    }
}
