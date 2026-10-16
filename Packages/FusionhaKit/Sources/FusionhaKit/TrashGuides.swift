import Foundation

// Settings › Quality › TRaSH Guides, native (web `TrashPanel`, `CfCatalogPanel`;
// `lib/api/trash.ts`): the cached guide bundle's catalog, recommended
// profiles, sync status, overrides that diverge from the guide, and the
// anime score-nudge preferences.

/// The guide's three media sets.
public enum TrashCategory: String, CaseIterable, Sendable, Hashable, Identifiable {
    case movie, series, anime

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .movie: return "Movies"
        case .series: return "Series"
        case .anime: return "Anime"
        }
    }
}

public struct TrashCatalogEntry: Decodable, Sendable, Hashable, Identifiable {
    public let trashId: String
    public let name: String
    public let score: Int?
    public let categories: [String]?
    public let specSummary: String?
    public let added: Bool?

    public var id: String { trashId }
    public var isAdded: Bool { added ?? false }
    /// `+1750` / `-10000`.
    public var scoreText: String {
        let s = score ?? 0
        return s > 0 ? "+\(s)" : "\(s)"
    }
}

public struct TrashGroupCount: Decodable, Sendable, Hashable {
    public let name: String
    public let count: Int?
}

public struct TrashCatalog: Decodable, Sendable {
    public let category: String
    public let groups: [TrashGroupCount]
    public let formats: [TrashCatalogEntry]
}

public struct TrashProfileSummary: Decodable, Sendable, Hashable {
    public let name: String
    public let trashId: String?
    public let description: String?
    public let count: Int?
    public let cutoff: String?
    public let added: Bool?
}

public struct TrashGuides: Decodable, Sendable {
    public let category: String
    public let profiles: [TrashProfileSummary]
    public let languages: [String]?
}

public struct TrashStatus: Decodable, Sendable {
    public let autoSync: Bool
    public let lastSyncedAt: String?
}

public struct TrashConflictSpec: Decodable, Sendable, Hashable {
    public let specType: String
    public let value: String
    public let negate: Bool?
}

public struct TrashConflict: Decodable, Sendable, Hashable, Identifiable {
    public let trashId: String
    public let cfId: Int
    public let name: String
    public let mediaKind: String
    public let guideSpecs: [TrashConflictSpec]
    public let localSpecs: [TrashConflictSpec]

    public var id: Int { cfId }
}

public struct TrashConflicts: Decodable, Sendable {
    public let conflicts: [TrashConflict]
}

public struct TrashImportResult: Decodable, Sendable {
    public let kind: String
    public let category: String
    public let counts: [String: Int]?
}

public struct TrashAnimePreferences: Decodable, Sendable, Hashable {
    public var preferDualAudio: Bool
    public var preferUncensored: Bool
    public var preferDubs: Bool
    public var avoidRaws: Bool

    private enum CodingKeys: String, CodingKey { case preferDualAudio, preferUncensored, preferDubs, avoidRaws }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        preferDualAudio = (try c.decodeIfPresent(Bool.self, forKey: .preferDualAudio)) ?? false
        preferUncensored = (try c.decodeIfPresent(Bool.self, forKey: .preferUncensored)) ?? false
        preferDubs = (try c.decodeIfPresent(Bool.self, forKey: .preferDubs)) ?? false
        avoidRaws = (try c.decodeIfPresent(Bool.self, forKey: .avoidRaws)) ?? false
    }

    /// The four toggles in render order: wire key, label, hint.
    public static let fields: [(key: String, label: String, hint: String)] = [
        ("prefer_dual_audio", "Prefer Dual-Audio", "score dual-audio releases up"),
        ("prefer_uncensored", "Prefer Uncensored", "score uncensored up"),
        ("prefer_dubs", "Prefer Dubs (English)", "score English-dub up"),
        ("avoid_raws", "Avoid Raws / LQ", "penalise raw / low-quality groups"),
    ]

    public func value(_ key: String) -> Bool {
        switch key {
        case "prefer_dual_audio": return preferDualAudio
        case "prefer_uncensored": return preferUncensored
        case "prefer_dubs": return preferDubs
        default: return avoidRaws
        }
    }

    public func setting(_ key: String, _ on: Bool) -> TrashAnimePreferences {
        var next = self
        switch key {
        case "prefer_dual_audio": next.preferDualAudio = on
        case "prefer_uncensored": next.preferUncensored = on
        case "prefer_dubs": next.preferDubs = on
        default: next.avoidRaws = on
        }
        return next
    }

    var json: SettingsJSON {
        .object(["prefer_dual_audio": .bool(preferDualAudio), "prefer_uncensored": .bool(preferUncensored),
                 "prefer_dubs": .bool(preferDubs), "avoid_raws": .bool(avoidRaws)])
    }
}

private struct TrashAnimePreferencesResult: Decodable {
    let preferences: TrashAnimePreferences
}

// MARK: Text

public enum TrashText {
    /// Auto-sync cadences written to `trash_sync_interval_seconds` (plus "off").
    public static let syncIntervals: [(seconds: Int, label: String)] = [
        (21_600, "every 6h"), (43_200, "every 12h"), (86_400, "daily"), (172_800, "every 2 days"), (604_800, "weekly"),
    ]
    public static let defaultSyncInterval = 86_400

    /// The presets, plus the current value when the API set a non-preset one.
    public static func intervalOptions(current: Int) -> [(seconds: Int, label: String)] {
        if syncIntervals.contains(where: { $0.seconds == current }) { return syncIntervals }
        return (syncIntervals + [(current, "every \(current)s")]).sorted { $0.seconds < $1.seconds }
    }

    /// "just now" / "4m ago" / "2h ago" / a date.
    public static func synced(_ iso: String?, now: Date = Date()) -> String? {
        guard let when = ServerTime.parse(iso) else { return nil }
        let seconds = max(0, now.timeIntervalSince(when))
        if seconds < 60 { return "just now" }
        if seconds < 3_600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86_400 { return "\(Int(seconds / 3_600))h ago" }
        return when.formatted(date: .numeric, time: .omitted)
    }

    /// Guide descriptions ship HTML: `<br>` → space, other tags dropped, whitespace squeezed.
    public static func plain(_ html: String?) -> String {
        guard let html else { return "" }
        var text = html.replacingOccurrences(of: "<br\\s*/?>", with: " ", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `!source=BLURAY, release_title=\bIMAX\b`, or `(none)`.
    public static func specs(_ specs: [TrashConflictSpec]) -> String {
        let text = specs.map { "\($0.negate == true ? "!" : "")\($0.specType)=\($0.value)" }.joined(separator: ", ")
        return text.isEmpty ? "(none)" : text
    }
}

// MARK: Endpoints

extension APIClient {
    public func trashCatalog(_ category: TrashCategory, search: String? = nil, group: String? = nil) async throws -> TrashCatalog {
        var query = [URLQueryItem(name: "category", value: category.rawValue)]
        if let search, !search.isEmpty { query.append(URLQueryItem(name: "search", value: search)) }
        if let group { query.append(URLQueryItem(name: "group", value: group)) }
        return try await get("/api/v1/trash/catalog", query: query)
    }

    public func trashGuides(_ category: TrashCategory) async throws -> TrashGuides {
        try await get("/api/v1/trash/guides", query: [URLQueryItem(name: "category", value: category.rawValue)])
    }

    public func trashStatus() async throws -> TrashStatus { try await get("/api/v1/trash/status") }

    /// Add individual catalog CFs by trash_id (override-safe upsert).
    public func trashImportFormats(_ category: TrashCategory, trashIds: [String]) async throws -> TrashImportResult {
        try await sendJSON("POST", "/api/v1/trash/import", .object([
            "kind": "formats", "category": .string(category.rawValue),
            "trash_ids": .array(trashIds.map(SettingsJSON.string)),
        ]))
    }

    /// Import one recommended profile (`profile`), or a batch (`profiles`).
    public func trashImportProfiles(_ category: TrashCategory, names: [String]) async throws -> TrashImportResult {
        var body: [String: SettingsJSON] = ["kind": "profile", "category": .string(category.rawValue)]
        if names.count == 1 { body["profile"] = .string(names[0]) } else { body["profiles"] = .array(names.map(SettingsJSON.string)) }
        return try await sendJSON("POST", "/api/v1/trash/import", .object(body))
    }

    /// Sync now: re-pull every category from the guide.
    public func trashSync() async throws { try await sendJSON("POST", "/api/v1/trash/sync") }

    /// Every local override that now diverges from the latest guide (POST: it fetches the bundles).
    public func trashConflicts() async throws -> TrashConflicts { try await sendJSON("POST", "/api/v1/trash/conflicts") }

    /// Reset a hand-edited TRaSH format to its guide definition.
    public func resetCustomFormat(id: Int) async throws { try await sendJSON("POST", "/api/v1/customformats/\(id)/reset") }

    public func trashAnimePreferences() async throws -> TrashAnimePreferences {
        try await get("/api/v1/trash/anime-preferences")
    }

    public func updateTrashAnimePreferences(_ prefs: TrashAnimePreferences) async throws -> TrashAnimePreferences {
        let result: TrashAnimePreferencesResult = try await sendJSON("PUT", "/api/v1/trash/anime-preferences", prefs.json)
        return result.preferences
    }
}
