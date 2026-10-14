import SwiftUI
import Charts
import FusionhaKit

// MARK: - Audit logic (lib/audit-format.ts)

enum AuditTone {
    case ok, warn, danger, neutral

    var color: Color {
        switch self {
        case .ok: return Theme.done
        case .warn: return Theme.stuck
        case .danger: return Theme.danger
        case .neutral: return Theme.dim
        }
    }

    var icon: String {
        switch self {
        case .ok: return "plus"
        case .warn: return "pencil"
        case .danger: return "trash"
        case .neutral: return "clock.arrow.circlepath"
        }
    }
}

enum AuditCategory: String, CaseIterable, Hashable {
    case added, changed, deleted

    var label: String {
        switch self {
        case .added: return "Added"
        case .changed: return "Changed"
        case .deleted: return "Deleted"
        }
    }

    var tone: AuditTone {
        switch self {
        case .added: return .ok
        case .changed: return .warn
        case .deleted: return .danger
        }
    }
}

enum AuditLogic {
    static func parse(_ action: String) -> (method: String, route: String) {
        guard let space = action.firstIndex(of: " ") else { return (action, "") }
        return (String(action[..<space]), String(action[action.index(after: space)...]))
    }

    static func actorName(_ actor: String) -> String {
        if actor == "trusted-key" { return "Trusted key" }
        if actor == "anonymous" { return "Anonymous" }
        if actor.hasPrefix("instance:") { return "Connected instance" }
        if actor.hasPrefix("user:") {
            let parts = actor.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            if parts.count >= 3, !parts[2].isEmpty {
                return parts.count > 3 && parts[3] == "pat" ? "\(parts[2]) · API token" : parts[2]
            }
            if parts.count > 1, !parts[1].isEmpty { return "Deleted user #\(parts[1])" }
            return "Deleted user"
        }
        return actor
    }

    private static let rules: [(method: String, pattern: String, label: String, tone: AuditTone)] = [
        ("POST", "/requests/[^/]+/approve$", "Approved a request", .ok),
        ("POST", "/requests/[^/]+/reject$", "Rejected a request", .warn),
        ("POST", "/requests$", "Submitted a request", .neutral),
        ("DELETE", "/requests/[^/]+$", "Withdrew a request", .neutral),
        ("DELETE", "/library/[^/]+$", "Deleted a title", .danger),
        ("POST", "/library$", "Added a title", .ok),
        // Versions (the native API renamed /editions to /versions; the old
        // paths stay as compat coverage for rows written before the rename).
        ("POST", "/library/[^/]+/versions$", "Added a version", .ok),
        ("DELETE", "/library/[^/]+/versions/[^/]+$", "Removed a version", .danger),
        ("POST", "/library/versions/[^/]+/replace-dead$", "Ran a search", .neutral),
        ("POST", "/library/[^/]+/editions$", "Added a version", .ok),
        ("POST", "/library/editions/[^/]+/replace-dead$", "Ran a search", .neutral),
        ("DELETE", "/library/[^/]+/editions/[^/]+$", "Removed a version", .danger),
        ("DELETE", "/blocklist/all$", "Cleared the entire blocklist", .danger),
        ("DELETE", "/blocklist/[^/]+$", "Cleared a blocklist entry", .warn),
        ("POST", "/blocklist", "Blocklisted a release", .danger),
        ("POST", "/grab$", "Grabbed a release", .ok),
        ("POST", "/search$", "Ran a search", .neutral),
        ("POST", "/users$", "Created a user", .ok),
        ("DELETE", "/users/[^/]+$", "Deleted a user", .danger),
        ("POST", "/grants$", "Granted access", .ok),
        ("DELETE", "/grants/[^/]+$", "Revoked access", .danger),
    ]

    private static func matches(_ route: String, _ pattern: String) -> Bool {
        route.range(of: pattern, options: .regularExpression) != nil
    }

    static func resolve(_ action: String) -> (label: String, tone: AuditTone) {
        let (method, route) = parse(action)
        if let rule = rules.first(where: { $0.method == method && matches(route, $0.pattern) }) {
            return (rule.label, rule.tone)
        }
        if (method == "PUT" || method == "PATCH") && matches(route, "/(settings|config)\\b") {
            return ("Changed a setting", .warn)
        }
        if ["POST", "PUT", "PATCH"].contains(method) && matches(route, "/roles\\b") {
            return ("Changed a role", .warn)
        }
        let m = method.uppercased()
        let tone: AuditTone = m == "DELETE" ? .danger : (m == "PUT" || m == "PATCH" ? .warn : (m == "POST" ? .ok : .neutral))
        let segments = route.split(separator: "/").map(String.init)
        let segment = segments.reversed().first { !$0.hasPrefix("{") } ?? segments.last ?? ""
        let words = segment.replacingOccurrences(of: "[-_]", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        let titled = method.isEmpty ? method : method.prefix(1).uppercased() + method.dropFirst().lowercased()
        return (words.isEmpty ? titled : "\(titled) \(words)", tone)
    }

    static func category(_ tone: AuditTone) -> AuditCategory? {
        switch tone {
        case .ok: return .added
        case .warn: return .changed
        case .danger: return .deleted
        case .neutral: return nil
        }
    }

    static func initials(_ name: String) -> String {
        let parts = name.split(whereSeparator: \.isWhitespace)
        guard let first = parts.first else { return "?" }
        if parts.count == 1 { return String(first.prefix(2)).uppercased() }
        return (String(first.prefix(1)) + String(parts[parts.count - 1].prefix(1))).uppercased()
    }
}
