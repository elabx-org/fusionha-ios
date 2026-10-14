import Foundation
import FusionhaKit

/// How a `FusionhaWebView` page gets signed in (fusionha 0.4.192):
/// - reuse the stored `fusionha_session` cookie while it is fresh and
///   `/auth/me` accepts it;
/// - otherwise swap the device token for a new one (`POST /auth/session`) and
///   store it. Each swap signs out the token's previous web session, so swaps
///   are shared: two pages opening at once make one.
/// - When the swap is refused (a session-token account, a limited token, the
///   rate limit) the page falls back to the `X-Api-Key` script.
@MainActor
enum WebSignIn {
    enum Plan {
        case cookie(HTTPCookie)
        /// Sign-in is off on this server.
        case none
        /// Add the device token to the page's own requests.
        case apiKeyScript
    }

    private static var inFlight: Task<Plan, Never>?

    static func plan(server: URL, token: String?, method: AuthMethod) async -> Plan {
        guard let token else { return .none }
        // A session or demo token is not a device token: swapping it would only
        // log a failed sign-in, so those keep the sign-in cookie or the page script.
        guard method == .apiToken else {
            if let stored = WebSessionStore.load(), stored.serverURL.host == server.host,
               let cookie = cookie(stored.token, server: server, expires: stored.expiresAt) {
                return .cookie(cookie)
            }
            return .apiKeyScript
        }
        if let running = inFlight { return await running.value }
        let task = Task { await resolve(server: server, token: token) }
        inFlight = task
        defer { inFlight = nil }
        return await task.value
    }

    private static func resolve(server: URL, token: String) async -> Plan {
        let client = APIClient(baseURL: server, token: token)
        if let stored = WebSessionStore.load(), stored.serverURL.host == server.host, stored.isFresh(),
           await client.webSessionValid(stored.token),
           let cookie = cookie(stored.token, server: server, expires: stored.expiresAt) {
            return .cookie(cookie)
        }
        switch await client.webSessionSwap() {
        case .cookie(let swap):
            WebSessionStore.save(swap.cookie, server: server, expiresAt: swap.expiresAt)
            return cookie(swap.cookie, server: server, expires: swap.expiresAt).map(Plan.cookie) ?? .apiKeyScript
        case .notNeeded:
            return .none
        case .refused:
            return .apiKeyScript
        }
    }

    static func cookie(_ value: String, server: URL, expires: Date?) -> HTTPCookie? {
        guard let host = server.host else { return nil }
        var props: [HTTPCookiePropertyKey: Any] = [
            .name: APIClient.sessionCookieName,
            .value: value,
            .domain: host,
            .path: "/",
            .expires: expires ?? Date().addingTimeInterval(30 * 24 * 3600),
        ]
        if server.scheme == "https" { props[.secure] = "TRUE" }
        return HTTPCookie(properties: props)
    }
}
