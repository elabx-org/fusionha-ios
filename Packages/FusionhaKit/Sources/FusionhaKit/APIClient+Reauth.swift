import Foundation

/// Confirming a key reveal with Plex instead of a password (fusionha 0.4.191):
/// `GET /auth/reauth` lists the account's methods; a Plex PIN approved by the
/// linked Plex account yields a single-use `reauth_grant` (5 minutes, bound to
/// this token) that the backup download takes in place of `password`.
extension APIClient {
    private struct Methods: Decodable { let methods: [String] }
    private struct Grant: Decodable { let reauthGrant: String }

    /// `password` and/or `plex`; empty when the account can't re-auth.
    public func reauthMethods() async throws -> [String] {
        let body: Methods = try await get("/api/v1/auth/reauth")
        return body.methods
    }

    /// Mints the Plex PIN and its `authUrl`. The server binds it to this client
    /// with a cookie, which URLSession keeps.
    public func startPlexReauth() async throws -> PlexPin {
        var req = request(method: "POST", path: "/api/v1/auth/reauth/plex/pin", query: [])
        req.setValue(baseURL.absoluteString, forHTTPHeaderField: "Origin")
        return try await perform(req)
    }

    /// The grant once Plex has approved the PIN; nil while it is pending (202).
    public func checkPlexReauth(pinId: Int) async throws -> String? {
        var req = request(method: "POST", path: "/api/v1/auth/reauth/plex", query: [])
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["pin_id": pinId])
        let (data, http) = try await data(for: req)
        if http.statusCode == 202 { return nil }
        return try Self.decoder.decode(Grant.self, from: data).reauthGrant
    }
}
