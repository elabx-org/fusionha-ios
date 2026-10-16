import Foundation

// Settings › Quality › Quality Profiles, native (web `QualityProfilesPanel.tsx`,
// `quality-ladder.ts`, `profile-kind.ts`): the full profile read shape, the
// list-card ladder, and the `/api/v1/qualityprofiles` CRUD. The small read-only
// `QualityProfile` in ScreenModels stays as it is for the pickers.

/// One `items` entry: a standalone quality or an equal-rank group.
public enum QualityProfileItem: Decodable, Sendable, Hashable {
    case group(name: String, allowed: Bool, order: Int, qualities: [String])
    case quality(quality: String, allowed: Bool, order: Int)

    public var order: Int {
        switch self {
        case .group(_, _, let order, _): return order
        case .quality(_, _, let order): return order
        }
    }

    private enum CodingKeys: String, CodingKey { case type, name, allowed, order, qualities, quality }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let allowed = try c.decodeIfPresent(Bool.self, forKey: .allowed) ?? true
        let order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
        if (try c.decodeIfPresent(String.self, forKey: .type)) == "group" {
            self = .group(name: try c.decodeIfPresent(String.self, forKey: .name) ?? "",
                          allowed: allowed, order: order,
                          qualities: try c.decodeIfPresent([String].self, forKey: .qualities) ?? [])
        } else {
            self = .quality(quality: try c.decode(String.self, forKey: .quality), allowed: allowed, order: order)
        }
    }
}

public struct QualityProfileFormatScore: Decodable, Sendable, Hashable {
    public let customFormatId: Int
    public let score: Int
    public let isOverride: Bool?
}

/// A `(profile_kind, tier)` Add-defaults slot this profile fills.
public struct QualityProfileDefaultSlot: Decodable, Sendable, Hashable {
    public let profileKind: String
    public let tier: QualityTier
}

/// `QualityProfileRead`.
public struct QualityProfileRecord: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let name: String
    public let mediaKind: String?
    public let cutoff: String
    public let cutoffGroup: String?
    public let cutoffGroupIndex: Int?
    public let upgradeUntil: String?
    public let upgradeAllowed: Bool
    public let minFormatScore: Int
    public let cutoffFormatScore: Int?
    public let minUpgradeFormatScore: Int
    public let language: String?
    public let allowedQualities: [String]
    public let items: [QualityProfileItem]?
    public let formatScores: [QualityProfileFormatScore]
    public let source: String?
    public let inUse: Int?
    public let defaultFor: [QualityProfileDefaultSlot]?
}

/// The slice of a custom format the profile editor scores.
public struct QualityProfileFormatOption: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let name: String
    public let mediaKind: String?
}

// MARK: Labels

public enum QualityProfileKinds {
    /// Editor select order.
    public static let all = ["movie", "series", "anime"]

    public static func label(_ kind: String?) -> String {
        switch kind {
        case "movie": return "Movies"
        case "series": return "Series"
        case "anime": return "Anime"
        default: return "Any"
        }
    }

    /// `Default · Movies · HD` (the card badge; tier from `TIER_LOGO.primary`).
    public static func defaultBadge(_ slot: QualityProfileDefaultSlot) -> String {
        "Default · \(label(slot.profileKind)) · \(slot.tier.tierShort)"
    }

    /// Profile Language filter: `original`, `any`, or one arr Language name.
    public static let languages: [String] = [
        "English", "Japanese", "French", "Spanish", "German", "Italian", "Danish", "Dutch", "Icelandic",
        "Chinese", "Russian", "Polish", "Vietnamese", "Swedish", "Norwegian", "Finnish", "Turkish",
        "Portuguese", "Flemish", "Greek", "Korean", "Hungarian", "Hebrew", "Lithuanian", "Czech", "Arabic",
        "Hindi", "Bulgarian", "Malayalam", "Ukrainian", "Slovak", "Thai", "Portuguese (Brazil)",
        "Spanish (Latino)", "Romanian", "Latvian", "Persian", "Catalan", "Croatian", "Serbian", "Bosnian",
        "Estonian", "Tamil", "Indonesian", "Macedonian", "Slovenian",
    ]

    public static func languageLabel(_ value: String) -> String {
        switch value {
        case "original": return "Original"
        case "any": return "Any"
        default: return value
        }
    }
}

// MARK: List-card ladder (quality-ladder.ts)

public struct QualityProfileRung: Hashable, Sendable, Identifiable {
    public let tier: String
    public let resolution: String
    public let allowed: Bool
    public let isCutoff: Bool
    public var id: String { tier }
}

public enum QualityProfileRungs {
    public static let tiers: [(tier: String, resolution: String)] = [
        ("SD", "480p"), ("HD", "720p"), ("FHD", "1080p"), ("UHD", "2160p"),
    ]

    public static func tier(of quality: String) -> String {
        if quality.contains("2160") { return "UHD" }
        if quality.contains("1080") || quality == "RAWHD" { return "FHD" }
        if quality.contains("720") { return "HD" }
        return "SD"
    }

    /// Collapse the allowed set + cutoff onto SD / HD / FHD / UHD, worst → best.
    public static func derive(allowed: [String], cutoff: String?) -> [QualityProfileRung] {
        let lit = Set(allowed.map(tier(of:)))
        let cut = cutoff.map(tier(of:))
        return tiers.map { t in
            let on = lit.contains(t.tier)
            return QualityProfileRung(tier: t.tier, resolution: t.resolution, allowed: on, isCutoff: on && cut == t.tier)
        }
    }
}

// MARK: Endpoints

extension APIClient {
    public func qualityProfileRecords() async throws -> [QualityProfileRecord] {
        try await get("/api/v1/qualityprofiles")
    }

    public func createQualityProfile(_ body: [String: SettingsJSON]) async throws {
        try await sendJSON("POST", "/api/v1/qualityprofiles", .object(body))
    }

    public func updateQualityProfile(id: Int, _ body: [String: SettingsJSON]) async throws {
        try await sendJSON("PUT", "/api/v1/qualityprofiles/\(id)", .object(body))
    }

    public func deleteQualityProfile(id: Int) async throws {
        try await sendJSON("DELETE", "/api/v1/qualityprofiles/\(id)")
    }

    /// `GET /api/v1/customformats`, read only for the id, name and kind.
    public func qualityProfileFormatOptions() async throws -> [QualityProfileFormatOption] {
        try await get("/api/v1/customformats")
    }
}
