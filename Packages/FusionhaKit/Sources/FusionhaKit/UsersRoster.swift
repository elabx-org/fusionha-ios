import Foundation

/// The Users list's pulse and role groups (web `UsersPulse`, `UsersList`
/// `groupUsers`, `users-list-helpers`). Pure.
public enum UsersRoster {
    public static func isActive(_ u: UserAccount) -> Bool { u.isActive != false }

    public static func fromPlex(_ u: UserAccount) -> Bool {
        (u.credentials ?? []).contains { $0.provider == "plex" } || u.authProvider == "plex"
    }

    /// The search field (web `UsersList` `matches`): the shown name, the stored
    /// username, the Plex name, the role and the sign-in providers, case-insensitive.
    public static func matches(_ u: UserAccount, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return true }
        let hay = [u.displayName, u.username, u.plexUsername ?? "", u.roleName ?? ""]
            + (u.credentials ?? []).map(\.provider)
        return hay.joined(separator: " ").lowercased().contains(q)
    }

    /// A pulse tile; tapping one filters the list (tap again to clear).
    public enum PulseKey: String, CaseIterable, Sendable, Hashable {
        case total, admin, requestor, plex, disabled

        public var label: String {
            switch self {
            case .total: return "total"
            case .admin: return "admins"
            case .requestor: return "requestors"
            case .plex: return "from Plex"
            case .disabled: return "disabled"
            }
        }

        public func passes(_ u: UserAccount) -> Bool {
            switch self {
            case .total: return true
            case .admin: return u.isAdmin
            case .requestor: return u.roleName == "Requestor" && UsersRoster.isActive(u)
            case .plex: return UsersRoster.fromPlex(u)
            case .disabled: return !UsersRoster.isActive(u)
            }
        }
    }

    public static func count(_ key: PulseKey, in users: [UserAccount]) -> Int {
        users.filter(key.passes).count
    }

    /// The colour bucket a group or tile is drawn in (mapped to Theme in the app).
    public enum Accent: String, Sendable { case premiere, miss, grab, mut, unmonitored, danger, plex }

    public static func accent(_ key: PulseKey) -> Accent {
        switch key {
        case .total, .admin: return .premiere
        case .requestor: return .miss
        case .plex: return .plex
        case .disabled: return .danger
        }
    }

    public struct Group: Identifiable, Sendable {
        public let id: String
        public let label: String
        public let accent: Accent
        public let users: [UserAccount]
    }

    /// Administrators, then one group per role (Requestor, Manager, Viewer,
    /// then the rest A–Z), then Disabled.
    public static func groups(_ users: [UserAccount]) -> [Group] {
        let active = users.filter(isActive)
        let disabled = users.filter { !isActive($0) }
        var out: [Group] = []
        let admins = active.filter(\.isAdmin)
        if !admins.isEmpty { out.append(Group(id: "admin", label: "Administrators", accent: .premiere, users: admins)) }
        var byRole: [String: [UserAccount]] = [:]
        var order: [String] = []
        for u in active where !u.isAdmin {
            let role = u.roleName ?? "No role"
            if byRole[role] == nil { order.append(role) }
            byRole[role, default: []].append(u)
        }
        let rank = ["Requestor", "Manager", "Viewer"]
        let sorted = order.sorted { a, b in
            let ia = rank.firstIndex(of: a) ?? 99, ib = rank.firstIndex(of: b) ?? 99
            return ia != ib ? ia < ib : a < b
        }
        for role in sorted {
            out.append(Group(id: "role:\(role)", label: plural(role), accent: roleAccent(role), users: byRole[role] ?? []))
        }
        if !disabled.isEmpty { out.append(Group(id: "disabled", label: "Disabled", accent: .unmonitored, users: disabled)) }
        return out
    }

    static func plural(_ role: String) -> String {
        role == "No role" || role.hasSuffix("s") ? role : role + "s"
    }

    static func roleAccent(_ role: String) -> Accent {
        switch role {
        case "Requestor": return .miss
        case "Manager": return .grab
        default: return .mut
        }
    }

    /// The merge's default survivor: an admin, else a local sign-in, else the first.
    public static func defaultSurvivor(_ members: [DuplicateMember]) -> Int? {
        if let admin = members.first(where: { $0.isAdmin }) { return admin.id }
        if let local = members.first(where: { $0.authProvider == "local" }) { return local.id }
        return members.first?.id
    }

    /// "a ↔ b · c ↔ d": the duplicates banner's line.
    public static func duplicatesLine(_ groups: [DuplicateGroup]) -> String {
        groups.map { $0.members.map(\.username).joined(separator: " ↔ ") }.joined(separator: " · ")
    }
}
