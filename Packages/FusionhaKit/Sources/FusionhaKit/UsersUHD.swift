import Foundation

/// The Users list's UHD·4K pieces (web `users-uhd.ts`): the banner state from
/// the Plex access preview and each row's chip copy.
public enum UsersUHD {
    /// `off`: Plex derivation is off, so chips read "All versions";
    /// `noLibrary`: on, but no Plex library is marked 4K.
    public enum Banner: Equatable, Sendable { case off, noLibrary }

    public static func banner(active: Bool?, uhdLibraryCount: Int) -> Banner? {
        guard let active else { return nil }
        if !active { return .off }
        return uhdLibraryCount == 0 ? .noLibrary : nil
    }

    public static func banner(_ preview: PlexAccessPreview?) -> Banner? {
        banner(active: preview?.active, uhdLibraryCount: preview?.uhdLibraries.count ?? 0)
    }

    public struct Chip: Equatable, Sendable {
        public let label: String
        public let title: String
    }

    /// The chip's words: what the user may request, and which layer decided it.
    public static func chip(uhd: Bool, source: String, detail: String?, isAdmin: Bool = false) -> Chip {
        switch source {
        case "plex" where isAdmin && uhd:
            return Chip(label: "UHD·4K · admin", title: "Admin: always UHD·4K, whatever their Plex shares")
        case "plex":
            return Chip(label: uhd ? "UHD·4K · from Plex" : "HD only · from Plex",
                        title: "From Plex: \(detail ?? "not fetched from Plex yet")")
        case "role":
            return Chip(label: uhd ? "UHD·4K · from role" : "HD only · from role", title: "Set on their role")
        case "user":
            return Chip(label: uhd ? "UHD·4K · manual" : "HD only · manual", title: "Set by hand on this user")
        default:
            return Chip(label: "All versions", title: detail.map { "No restriction: \($0)" } ?? "No restriction")
        }
    }

    public static func chip(_ access: UserTierAccess) -> Chip {
        chip(uhd: access.uhd, source: access.source, detail: access.detail, isAdmin: access.isAdmin)
    }

    /// The legend's sample chips (web `UsersUhdLegend`), in precedence order.
    public static let legend: [Chip] = [
        chip(uhd: true, source: "user", detail: nil),
        chip(uhd: true, source: "plex", detail: "shares Movies 4K"),
        chip(uhd: true, source: "default", detail: nil),
    ]
    public static let legendOrder = "Order: user → Plex → default. Touch and hold a chip for its reason."

    /// The chip's qualifier line (web `UhdQualifiers`).
    public static func qualifier(_ access: UserTierAccess) -> String? {
        switch access.source {
        case "user": return "wins over Plex"
        case "default": return access.detail
        case "plex":
            var parts: [String] = []
            if access.frozen { parts.append("Not linked to Plex — last value kept") } else if let d = access.detail { parts.append(d) }
            if access.stale { parts.append("stale") }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        default: return nil
        }
    }
}
