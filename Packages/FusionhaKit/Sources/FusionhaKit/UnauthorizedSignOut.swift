import Foundation

/// A signed-in request the server answered with `401`: the device's sign-in
/// is no longer good (token revoked, password changed, session ended), so the
/// app signs out cleanly and asks to sign in again. `APIClient` reports each
/// one here; the app's session turns a burst of them into one sign-out.
///
/// Never a sign-out: a 403 (a permission, not the sign-in), a network error,
/// a request made without credentials (sign-in, probes), the sign-in
/// endpoints themselves, the token mint, and the read-only demo.
public enum UnauthorizedSignOut {
    /// Posted (on any thread) for each eligible 401. `userInfo` carries the
    /// `server` (URL), a `tokenHash` (Int, this process's hash of the token
    /// the request sent, never the token) and the `message` to show.
    public static let notification = Notification.Name("org.elabx.fusionha.unauthorized")
    public static let neutralMessage = "You've been signed out. Sign in again."
    /// A burst of 401s (every poller at once) signs out once.
    public static let quiet: TimeInterval = 5

    /// Whether this answer signs the app out. `auth` is how the request was
    /// authenticated, nil when it carried no credentials.
    public static func signsOut(status: Int, method: String?, url: URL, base: URL, auth: AuthMethod?) -> Bool {
        guard status == 401, let auth, auth != .demoCookie else { return false }
        let path = relativePath(url, base: base)
        if path == "/api/v1/auth" || path.hasPrefix("/api/v1/auth/") { return false }
        if path == "/api/v1/demo" || path.hasPrefix("/api/v1/demo/") { return false }
        if path == "/health" || path == "/api/v1/setup-status" { return false }
        if (method ?? "GET").uppercased() == "POST", path == "/api/v1/tokens" { return false }
        return true
    }

    /// The request's path below the server address (a reverse-proxy prefix in
    /// the address is dropped), without a trailing slash.
    static func relativePath(_ url: URL, base: URL) -> String {
        var path = url.path
        let prefix = base.path
        if !prefix.isEmpty, prefix != "/", path.hasPrefix(prefix) { path = String(path.dropFirst(prefix.count)) }
        while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return path.hasPrefix("/") ? path : "/" + path
    }

    /// The sentence for the sign-in screen: a specific one when the 401 says
    /// why (`code`, at the top level or under `detail`), else the neutral one.
    public static func message(for error: APIError) -> String {
        switch reasonCode(error) {
        case "token_revoked": return "This device's sign-in was revoked. Sign in again."
        case "password_changed": return "Your password was changed. Sign in again."
        case "session_revoked": return "Your session was ended. Sign in again."
        case "expired": return "Your sign-in expired. Sign in again."
        default: return neutralMessage
        }
    }

    static func reasonCode(_ error: APIError) -> String? {
        if let code = error.code { return code }
        guard case .http(_, let body) = error,
              let object = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any] else { return nil }
        return object["code"] as? String
    }

    /// One sign-out per quiet window, however many 401s arrive in it.
    public struct Gate: Sendable {
        public private(set) var last: Date?

        public init() {}

        public mutating func admit(at now: Date) -> Bool {
            if let last, now.timeIntervalSince(last) < UnauthorizedSignOut.quiet { return false }
            last = now
            return true
        }
    }
}

extension APIClient {
    /// Called with every non-2xx answer of a request this client sent.
    func reportUnauthorized(_ req: URLRequest, error: APIError) {
        guard !readsCache, case .http(let status, _) = error, let url = req.url,
              UnauthorizedSignOut.signsOut(status: status, method: req.httpMethod, url: url, base: baseURL,
                                           auth: sentAuth) else { return }
        let info: [String: Any] = [
            "server": baseURL,
            "tokenHash": sentTokenHash ?? 0,
            "message": UnauthorizedSignOut.message(for: error),
        ]
        NotificationCenter.default.post(name: UnauthorizedSignOut.notification, object: nil, userInfo: info)
    }
}
