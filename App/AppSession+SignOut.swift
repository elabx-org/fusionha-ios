import Foundation
import WebKit
import FusionhaKit

/// What the sign-in screen says after the app signed itself out, and the
/// server it prefills.
struct SignedOutNotice: Equatable {
    let server: URL
    let message: String
}

extension AppSession {
    /// Signs out on this phone and leaves nothing of the sign-in behind: the
    /// credentials and fetched data (`forgetSignIn`), the server's cookies in
    /// the shared jar, `URLCache`, the web view's stored data, and this
    /// account's Live Activity registration. Server-side logout, token revoke
    /// and APNs unregister happen before this, in `AppModel.logOut`.
    func signOut() {
        let server = credentials?.serverURL
        forgetSignIn()
        Self.deleteCookies(for: server)
        URLCache.shared.removeAllCachedResponses()
        Task { @MainActor in
            await LiveActivityPushTokens.reset(client: nil)
            let store = WKWebsiteDataStore.default()
            await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        }
    }

    /// Every cookie the shared jar would send to `server`'s host (the
    /// `fusionha_session` the password sign-in set, the demo cookie, Plex's).
    static func deleteCookies(for server: URL?) {
        guard let host = server?.host()?.lowercased() else { return }
        let jar = HTTPCookieStorage.shared
        for cookie in jar.cookies ?? [] {
            let domain = cookie.domain.lowercased()
            let bare = domain.hasPrefix(".") ? String(domain.dropFirst()) : domain
            if bare == host || host.hasSuffix("." + bare) { jar.deleteCookie(cookie) }
        }
    }

    // MARK: Signed out by the server (401)

    /// Any signed-in request answered `401` (`UnauthorizedSignOut`) signs the
    /// app out: the same clean sign-out, then the sign-in screen with the
    /// server prefilled and a short note. Once per burst, and only for the
    /// sign-in that sent it (a late answer to an earlier sign-in is ignored).
    func observeUnauthorized() {
        NotificationCenter.default.addObserver(forName: UnauthorizedSignOut.notification, object: nil,
                                               queue: .main) { [weak self] note in
            let server = note.userInfo?["server"] as? URL
            let tokenHash = note.userInfo?["tokenHash"] as? Int
            let message = note.userInfo?["message"] as? String ?? UnauthorizedSignOut.neutralMessage
            Task { @MainActor in self?.signedOutByServer(server: server, tokenHash: tokenHash, message: message) }
        }
    }

    private func signedOutByServer(server: URL?, tokenHash: Int?, message: String) {
        // CI screenshots run against a mock server: never sign out there.
        guard ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_SERVER"] == nil,
              let credentials, credentials.serverURL == server, credentials.token.hashValue == tokenHash,
              unauthorizedGate.admit(at: Date()) else { return }
        signOut()
        signedOutNotice = SignedOutNotice(server: credentials.serverURL, message: message)
    }
}
