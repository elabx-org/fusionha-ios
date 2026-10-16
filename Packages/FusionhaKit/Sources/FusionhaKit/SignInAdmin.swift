import Foundation

// Settings › Access › Sign-in methods, native: the server-wide sign-in
// configuration (web `SignInMethodsPanel.tsx`, `PlexAccountField.tsx`,
// `TrustedProxiesCard.tsx`; `lib/api/plex.ts`, `lib/api/trusted-proxies.ts`).
// The on/off switches and Plex options are plain `/api/v1/settings` keys; this
// file owns the actions that are not settings CRUD.

/// `POST /settings/plex/connect/{id}/check`: `pending` or `connected`.
public struct SignInPlexConnectResult: Decodable, Sendable, Hashable {
    public let status: String
    public let ownerUsername: String?
    public let serverName: String?
    public let memberCount: Int?

    public var connected: Bool { status == "connected" }
}

/// `POST /settings/test-plex`.
public struct SignInPlexTestResult: Decodable, Sendable, Hashable {
    public let ok: Bool
    public let message: String?
    public let ownerUsername: String?
    public let serverName: String?
    public let memberCount: Int?

    /// The Test connection row's line (web `PlexConfigDialog`).
    public var summary: String {
        if ok {
            return "Connected to \"\(serverName ?? "")\" as \(ownerUsername ?? "") · \(memberCount ?? 0) member(s)."
        }
        let text = message ?? ""
        return text.isEmpty ? "The Plex connection test failed." : text
    }
}

public struct SignInPlexImportResult: Decodable, Sendable {
    public let created: Int
}

public struct SignInPlexPruneResult: Decodable, Sendable {
    public let removed: Int
    public let usernames: [String]

    /// The toast line after a cleanup.
    public var summary: String {
        if removed == 0 { return "No ineligible accounts to remove" }
        let names = usernames.isEmpty ? "" : " — " + usernames.joined(separator: ", ")
        return "Removed \(removed) account\(removed == 1 ? "" : "s")\(names)"
    }
}

private struct TrustedProxiesBody: Decodable { let cidrs: [String] }

/// Client-side checks for the trusted proxies list (the server is the authority).
public enum TrustedProxies {
    /// One entry per line or comma; blanks dropped.
    public static func parse(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Why an entry isn't an IPv4/IPv6 address with an optional /prefix, or nil.
    public static func problem(_ entry: String) -> String? {
        let parts = entry.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        if parts.count > 2 { return "\(entry) isn’t an IP address or CIDR." }
        let addr = parts.first ?? ""
        let v4 = isIPv4(addr)
        let v6 = !v4 && addr.contains(":") && addr.allSatisfy { $0.isHexDigit || $0 == ":" || $0 == "." }
        if !v4 && !v6 { return "\(entry) isn’t an IP address or CIDR." }
        if parts.count == 2 {
            let prefix = parts[1]
            let max = v4 ? 32 : 128
            guard !prefix.isEmpty, prefix.allSatisfy(\.isNumber), let n = Int(prefix), n <= max else {
                return "\(entry): the prefix must be 0–\(max)."
            }
        }
        return nil
    }

    static func isIPv4(_ s: String) -> Bool {
        let octets = s.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else { return false }
        return octets.allSatisfy { o in
            guard (1...3).contains(o.count), o.allSatisfy(\.isNumber), let n = Int(o) else { return false }
            // `1?\d?\d` / `2[0-4]\d` / `25[0-5]`: no leading zero padding past what the web allows.
            return n <= 255
        }
    }

    /// The server's 422 names the bad entry; anything else is generic.
    public static func saveError(_ error: Error) -> String {
        if let api = error as? APIError, case .http(422, _) = api, let detail = api.serverDetail, !detail.isEmpty {
            return detail.prefix(1).uppercased() + String(detail.dropFirst()) + "."
        }
        return "Couldn’t save. Try again."
    }
}

extension APIClient {
    /// Mints a PIN for "Connect Plex account" (admin); authorising it stores the owner token.
    public func startPlexConnect() async throws -> PlexPin {
        try await sendJSON("POST", "/api/v1/settings/plex/connect")
    }

    public func checkPlexConnect(pinId: Int) async throws -> SignInPlexConnectResult {
        try await sendJSON("POST", "/api/v1/settings/plex/connect/\(pinId)/check")
    }

    /// Probes the configured owner token (the Advanced fallback).
    public func testPlexOwnerToken() async throws -> SignInPlexTestResult {
        try await sendJSON("POST", "/api/v1/settings/test-plex")
    }

    public func importPlexUsers() async throws -> SignInPlexImportResult {
        try await sendJSON("POST", "/api/v1/settings/plex-import")
    }

    public func prunePlexUsers() async throws -> SignInPlexPruneResult {
        try await sendJSON("POST", "/api/v1/settings/plex-prune")
    }

    public func trustedProxies() async throws -> [String] {
        let body: TrustedProxiesBody = try await get("/api/v1/settings/trusted-proxies")
        return body.cidrs
    }

    public func updateTrustedProxies(_ cidrs: [String]) async throws -> [String] {
        let body: TrustedProxiesBody = try await sendJSON(
            "PUT", "/api/v1/settings/trusted-proxies", .object(["cidrs": .array(cidrs.map { .string($0) })]))
        return body.cidrs
    }
}
