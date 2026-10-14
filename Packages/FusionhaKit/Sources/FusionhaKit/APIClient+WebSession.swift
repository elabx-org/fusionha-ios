import Foundation

/// A web session minted from the device token (`POST /api/v1/auth/session`,
/// fusionha 0.4.192): the `fusionha_session` cookie value and when it ends.
public struct WebSessionSwap: Sendable, Equatable {
    public let cookie: String
    public let sessionId: String
    public let expiresAt: Date?
}

/// What a web view should do for sign-in, from `webSessionSwap`'s answer.
public enum WebSessionOutcome: Sendable, Equatable {
    /// Signed in: set this cookie on the web view.
    case cookie(WebSessionSwap)
    /// Sign-in is off on this server (`auth_not_active`): open the page without one.
    case notNeeded
    /// The swap was refused (a session token, the app key, a limited token,
    /// rate limit): fall back to the `X-Api-Key` page script.
    case refused
}

extension APIClient {
    private struct SwapBody: Decodable {
        let sessionId: String
        let expiresAt: String?
    }

    /// Swaps the device token for a web session cookie. Each swap signs out the
    /// token's previous web session, so callers reuse the stored cookie until it
    /// expires or `/auth/me` answers 401 (`webSessionValid`).
    public func webSessionSwap() async -> WebSessionOutcome {
        var req = request(method: "POST", path: "/api/v1/auth/session", query: [])
        // The cookie is for the web view only: keep it out of the shared store,
        // so the app's own calls stay on `X-Api-Key`.
        req.httpShouldHandleCookies = false
        do {
            let (data, http) = try await data(for: req)
            let body = try Self.decoder.decode(SwapBody.self, from: data)
            guard let value = Self.sessionCookie(in: http, url: req.url ?? baseURL) else { return .refused }
            return .cookie(WebSessionSwap(cookie: value, sessionId: body.sessionId,
                                          expiresAt: ServerTime.parse(body.expiresAt)))
        } catch let error as APIError where error.code == "auth_not_active" {
            return .notNeeded
        } catch {
            return .refused
        }
    }

    /// Whether a stored web cookie still signs in: `GET /auth/me` with only that cookie.
    public func webSessionValid(_ cookie: String) async -> Bool {
        var req = URLRequest(url: baseURL.appendingPathComponent("/api/v1/auth/me"))
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("\(Self.sessionCookieName)=\(cookie)", forHTTPHeaderField: "Cookie")
        req.httpShouldHandleCookies = false
        req.timeoutInterval = 10
        guard let result = try? await session.data(for: req),
              let status = (result.1 as? HTTPURLResponse)?.statusCode else { return true }
        // Only a 401/403 proves the cookie dead; a network blip keeps it.
        return status != 401 && status != 403
    }

    static func sessionCookie(in http: HTTPURLResponse, url: URL) -> String? {
        let fields = http.allHeaderFields.reduce(into: [String: String]()) { out, pair in
            if let k = pair.key as? String, let v = pair.value as? String { out[k] = v }
        }
        return HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
            .first { $0.name == sessionCookieName }?.value
    }
}
