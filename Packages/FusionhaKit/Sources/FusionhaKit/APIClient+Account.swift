import Foundation

extension APIClient {
    /// `GET /api/v1/users/{id}/avatar`: the same-origin proxy of the Plex thumb.
    public func avatar(userId: Int) async throws -> Data {
        var req = request(method: "GET", path: "/api/v1/users/\(userId)/avatar", query: [])
        req.setValue("image/*", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status), !data.isEmpty else { throw APIError.http(status: status, body: "") }
        return data
    }

    // MARK: Sign-in methods

    public func updateCredential(userId: Int, credentialId: Int, _ patch: CredentialPatch) async throws {
        let _: EmptyResponse = try await send("PATCH", "/api/v1/users/\(userId)/credentials/\(credentialId)", body: patch)
    }

    public func deleteCredential(userId: Int, credentialId: Int) async throws {
        let _: EmptyResponse = try await send("DELETE", "/api/v1/users/\(userId)/credentials/\(credentialId)",
                                              body: Optional<String>.none)
    }

    public func addPassword(userId: Int, password: String) async throws {
        let _: EmptyResponse = try await send("POST", "/api/v1/users/\(userId)/credentials/local",
                                              body: PasswordCreate(password: password))
    }

    /// `POST /api/v1/users/{id}/plex/link`: a PIN plus the `authUrl` to open. The
    /// server binds the PIN to this client with a cookie, which URLSession keeps.
    public func startPlexLink(userId: Int) async throws -> PlexPin {
        var req = request(method: "POST", path: "/api/v1/users/\(userId)/plex/link", query: [])
        req.setValue(baseURL.absoluteString, forHTTPHeaderField: "Origin")
        return try await perform(req)
    }

    /// `POST /api/v1/users/{id}/plex/link/{pin}/check`: `202` pending, `200` the updated
    /// user, `409` when that Plex account belongs to someone else.
    public func checkPlexLink(userId: Int, pinId: Int) async throws -> PlexLinkState {
        let req = request(method: "POST", path: "/api/v1/users/\(userId)/plex/link/\(pinId)/check", query: [])
        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 202: return .pending
        case 200..<300:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            if let me = try? decoder.decode(Me.self, from: data) { return .linked(me) }
            return .pending
        default:
            throw APIError.http(status: status, body: String(decoding: data.prefix(500), as: UTF8.self))
        }
    }

    public func unlinkPlex(userId: Int) async throws {
        let _: EmptyResponse = try await send("POST", "/api/v1/users/\(userId)/plex/unlink", body: Optional<String>.none)
    }
}
