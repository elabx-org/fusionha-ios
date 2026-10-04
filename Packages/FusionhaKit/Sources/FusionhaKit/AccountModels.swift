import Foundation

// The Account page ("You") and its Sign-in methods sheet
// (web `routes/Account.tsx`, `components/settings/UserCredentialsDialog.tsx`).

/// One way an identity can sign in (`UserRead.credentials[]`).
public struct UserCredential: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    /// `local`, `plex` or `oidc`.
    public let provider: String
    public let externalId: String?
    public let displayHandle: String?
    public let isPrimary: Bool
    public let isActive: Bool
    public let createdAt: String?
    public let lastLoginAt: String?

    /// `fusionha` for a password, `Plex`, `OIDC`.
    public var providerLabel: String {
        switch provider {
        case "local": return "fusionha"
        case "plex": return "Plex"
        case "oidc": return "OIDC"
        default: return provider
        }
    }
}

/// `PATCH /api/v1/users/{id}/credentials/{cid}`: `{"is_primary": true}` or `{"is_active": …}`.
public struct CredentialPatch: Encodable, Sendable {
    public var isPrimary: Bool?
    public var isActive: Bool?
    public init(isPrimary: Bool? = nil, isActive: Bool? = nil) {
        self.isPrimary = isPrimary
        self.isActive = isActive
    }
}

/// `POST /api/v1/users/{id}/credentials/local`.
public struct PasswordCreate: Encodable, Sendable {
    public let password: String
    public init(password: String) { self.password = password }
}

public enum PlexLinkState: Sendable {
    case pending
    case linked(Me)
}

/// The web's role tones (`access-shared.tsx`): Admin, Manager, Requestor, other.
public enum RoleTone: Sendable {
    case admin, manager, requestor, other
}

extension Me {
    /// `Admin` for admins, else the role name (nil shows as `No role`).
    public var accountRoleName: String? { isAdmin ? "Admin" : roleName }

    public var roleTone: RoleTone {
        switch accountRoleName {
        case "Admin": return .admin
        case "Manager": return .manager
        case "Requestor": return .requestor
        default: return .other
        }
    }

    /// `displayName`: the Plex username for a mangled ` (plex:…)` account name.
    public var displayName: String {
        if username.range(of: #"\s*\(plex:[^)]+\)\s*$"#, options: [.regularExpression, .caseInsensitive]) != nil,
           let plex = plexUsername, !plex.isEmpty {
            return plex
        }
        return username
    }

    /// `initials` of the display name, `?` when empty.
    public var displayInitials: String {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        let parts = name.split(whereSeparator: { $0 == " " || $0 == "." || $0 == "_" || $0 == "-" })
        let letters = parts.count >= 2 ? parts.prefix(2).compactMap(\.first) : Array(name.prefix(2))
        let out = String(letters).uppercased()
        return out.isEmpty ? "?" : out
    }

    public func has(_ permission: String) -> Bool {
        isAdmin || (permissions ?? []).contains(permission)
    }
}

extension APIError {
    /// The server's `detail` message, for error toasts.
    public var serverMessage: String {
        if case .http(_, let body) = self,
           let data = body.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let detail = object["detail"] as? String {
            return detail
        }
        return errorDescription ?? "Something went wrong."
    }
}
