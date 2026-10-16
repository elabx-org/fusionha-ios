import Foundation

// TRaSH Guides › Presets, native (web `PresetsTab`, `PresetDeployDialog`,
// `ArrConnectionsCard`; `lib/api/presets.ts`): saved arr connections, the
// captured profile bundles, and their review-and-deploy.
//
// Presets are read through `json(...)` (JSONSerialization), not the
// snake-case decoder: a manifest's `format_scores` / `format_specs` are keyed
// by trash_id or CF name, and those keys must survive verbatim because the
// deploy's `per_format` map sends them back.

public struct ArrConnection: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let name: String
    public let baseUrl: String
    /// `sonarr` · `radarr`.
    public let flavor: String
    public let apiKeyConfigured: Bool?
}

public struct PresetManifest: Sendable, Hashable {
    public let name: String
    public let mediaKind: String
    public let allowedQualities: [String]
    public let cutoff: String
    public let upgradeAllowed: Bool
    public let cutoffFormatScore: Int?
    /// trash_id (or CF name) → score, keys verbatim.
    public let formatScores: [String: Int]
    /// key → how many captured specs the manifest carries for it.
    public let formatSpecCounts: [String: Int]
    /// Raw, tolerantly read by `PresetLadder`.
    public let qualityGroups: JSONValue?
    public let cutoffGroup: JSONValue?
    public let cutoffGroupIndex: JSONValue?

    public init(json: JSONValue) {
        name = json["name"]?.string ?? ""
        mediaKind = json["media_kind"]?.string ?? ""
        allowedQualities = (json["allowed_qualities"]?.array ?? []).compactMap(\.string)
        cutoff = json["cutoff"]?.string ?? ""
        let upgrade = json["upgrade"]
        // An absent upgrade block reads as upgrades off (what the deployed profile gives).
        upgradeAllowed = upgrade?.object == nil ? false : (upgrade?["allowed"]?.bool ?? true)
        cutoffFormatScore = upgrade?["cutoff_format_score"]?.int
        var scores: [String: Int] = [:]
        for (key, value) in json["format_scores"]?.object ?? [:] { if let n = value.int { scores[key] = n } }
        formatScores = scores
        var specCounts: [String: Int] = [:]
        for (key, value) in json["format_specs"]?.object ?? [:] { specCounts[key] = value.array?.count ?? 0 }
        formatSpecCounts = specCounts
        qualityGroups = json["quality_groups"]
        cutoffGroup = json["cutoff_group"]
        cutoffGroupIndex = json["cutoff_group_index"]
    }

    /// `on · CF ≤10000` / `on` / `off`.
    public var upgradeSummary: String {
        guard upgradeAllowed else { return "off" }
        if let cutoffFormatScore { return "on · CF ≤\(cutoffFormatScore)" }
        return "on"
    }

    /// The four largest scores by magnitude (the card's "Top scoring").
    public var topScores: [(key: String, score: Int)] {
        formatScores.map { (key: $0.key, score: $0.value) }
            .sorted { abs($0.score) == abs($1.score) ? $0.key < $1.key : abs($0.score) > abs($1.score) }
            .prefix(4).map { $0 }
    }
}

public struct PresetInfo: Sendable, Hashable, Identifiable {
    public let id: Int
    public let name: String
    public let mediaKind: String
    public let sourceConnectionId: Int?
    public let deployName: String
    public let manifest: PresetManifest

    public init?(json: JSONValue) {
        guard let id = json["id"]?.int, let name = json["name"]?.string else { return nil }
        self.id = id
        self.name = name
        mediaKind = json["media_kind"]?.string ?? ""
        sourceConnectionId = json["source_connection_id"]?.int
        deployName = json["deploy_name"]?.string ?? name
        manifest = PresetManifest(json: json["manifest"] ?? .object([:]))
    }

    /// The card's tier tag: anime › 2160p cutoff (4K) › HD.
    public var tierLabel: String {
        if mediaKind == "anime" { return "ANIME" }
        return manifest.cutoff.contains("2160") ? "4K" : "HD"
    }
}

public struct PresetUnresolvedScore: Decodable, Sendable, Hashable {
    public let key: String
    public let score: Int
}

public struct PresetDeployResult: Decodable, Sendable, Hashable {
    public let profileId: Int
    public let name: String
    public let createdFormats: Int
    public let overwritten: Int
    public let skipped: Int
    public let formatScores: Int?
    public let replaced: Bool?
    public let preserved: [String]?
    public let unresolved: [PresetUnresolvedScore]?

    /// The web's deploy toast.
    public var toast: String {
        var text = "\(replaced == true ? "Rebuilt" : "Deployed") \(name) — \(createdFormats) new · \(overwritten) overwritten · \(skipped) skipped"
        let kept = preserved?.count ?? 0
        if kept > 0 { text += " · \(kept) shared format\(kept == 1 ? "" : "s") preserved" }
        let dropped = unresolved?.count ?? 0
        if dropped > 0 { text += " · \(dropped) scores unresolved" }
        return text
    }
}

// MARK: Deploy review

public enum PresetConflictMode: String, CaseIterable, Sendable {
    case overwrite, skip, perRow

    public var label: String {
        switch self {
        case .overwrite: return "Overwrite"
        case .skip: return "Skip"
        case .perRow: return "Decide each"
        }
    }
}

/// One manifest entry in the review: new / exists / unresolved.
public struct PresetFormatRow: Sendable, Hashable, Identifiable {
    public let key: String
    public let name: String
    public let score: Int
    public let exists: Bool
    /// Nothing can resolve it (no CF, no guide entry, no captured specs): its score would drop.
    public let unresolvable: Bool

    public var id: String { key }
    public var status: String { unresolvable ? "unresolved" : (exists ? "exists" : "new") }
}

public struct PresetDeployCounts: Sendable, Hashable {
    public var new = 0
    public var overwrite = 0
    public var skip = 0
    public var unresolved = 0
}

public enum PresetDeployPlan {
    /// Mirrors the backend's `_find_existing_cf`: by trash_id, or by name within the preset's kind.
    public static func rows(_ preset: PresetInfo, catalog: [TrashCatalogEntry], formats: [CustomFormatInfo]) -> [PresetFormatRow] {
        let byTid = Dictionary(catalog.map { ($0.trashId, $0) }, uniquingKeysWith: { first, _ in first })
        let guideNames = Set(catalog.map(\.name))
        let cfTids = Set(formats.compactMap(\.trashId))
        let cfNames = Set(formats.filter { $0.mediaKind == nil || $0.mediaKind == preset.mediaKind }.map(\.name))
        return preset.manifest.formatScores.map { pair -> PresetFormatRow in
            let key = pair.key
            let score = pair.value
            let entry = byTid[key]
            let resolved = entry?.name ?? key
            let exists = cfTids.contains(key) || (entry?.isAdded ?? false) || cfNames.contains(resolved)
            let unresolvable = !exists && entry == nil && !guideNames.contains(key)
                && (preset.manifest.formatSpecCounts[key] ?? 0) == 0
            return PresetFormatRow(key: key, name: resolved, score: score, exists: exists, unresolvable: unresolvable)
        }
        .sorted { $0.score == $1.score ? $0.name < $1.name : $0.score > $1.score }
    }

    /// A conflicted row's effective decision (`overwrite` / `skip`) under the mode.
    public static func decision(_ row: PresetFormatRow, mode: PresetConflictMode, perRow: [String: String]) -> String {
        guard row.exists else { return "overwrite" }
        switch mode {
        case .perRow: return perRow[row.key] ?? "overwrite"
        case .overwrite: return "overwrite"
        case .skip: return "skip"
        }
    }

    public static func counts(_ rows: [PresetFormatRow], mode: PresetConflictMode, perRow: [String: String]) -> PresetDeployCounts {
        var c = PresetDeployCounts()
        for row in rows {
            if row.unresolvable { c.unresolved += 1 }
            else if !row.exists { c.new += 1 }
            else if decision(row, mode: mode, perRow: perRow) == "skip" { c.skip += 1 }
            else { c.overwrite += 1 }
        }
        return c
    }

    /// The deploy body: "Decide each" sends the per-row map over a skip fallback.
    public static func body(name: String, rows: [PresetFormatRow], mode: PresetConflictMode, perRow: [String: String],
                            replace: Bool, allowUnresolved: Bool) -> SettingsJSON {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        var perFormat: SettingsJSON = .null
        if mode == .perRow {
            var map: [String: SettingsJSON] = [:]
            for row in rows where row.exists { map[row.key] = .string(decision(row, mode: mode, perRow: perRow)) }
            perFormat = .object(map)
        }
        return .object([
            "name": trimmed.isEmpty ? .null : .string(trimmed),
            "conflict": .string(mode == .perRow ? "skip" : mode.rawValue),
            "per_format": perFormat,
            "replace": .bool(replace),
            "allow_unresolved": .bool(replace ? allowUnresolved : false),
        ])
    }
}

// MARK: Endpoints

extension APIClient {
    public func arrConnections() async throws -> [ArrConnection] { try await get("/api/v1/arr-connections") }

    public func createArrConnection(name: String, baseUrl: String, apiKey: String, flavor: String) async throws -> ArrConnection {
        try await sendJSON("POST", "/api/v1/arr-connections", .object([
            "name": .string(name), "base_url": .string(baseUrl), "api_key": .string(apiKey), "flavor": .string(flavor),
        ]))
    }

    public func deleteArrConnection(id: Int) async throws { try await sendJSON("DELETE", "/api/v1/arr-connections/\(id)") }

    /// Probes the arr's system status with the stored key.
    public func testArrConnection(id: Int) async throws -> ConnectionTestResult {
        try await sendJSON("POST", "/api/v1/arr-connections/\(id)/test")
    }

    public func presets() async throws -> [PresetInfo] {
        (try await json("GET", "/api/v1/presets").array ?? []).compactMap { PresetInfo(json: $0) }
    }

    /// Read the named profile from a connected arr into a preset.
    public func capturePreset(connectionId: Int, profileName: String, asAnime: Bool, saveAs: String?) async throws -> PresetInfo? {
        let body: JSONValue = .object([
            "connection_id": .number(Double(connectionId)), "profile_name": .string(profileName),
            "media_kind": asAnime ? .string("anime") : .null, "name": saveAs.map(JSONValue.string) ?? .null,
        ])
        return PresetInfo(json: try await json("POST", "/api/v1/presets/capture", body: body))
    }

    public func renamePreset(id: Int, name: String) async throws {
        try await sendJSON("PATCH", "/api/v1/presets/\(id)", .object(["name": .string(name)]))
    }

    public func deployPreset(id: Int, body: SettingsJSON) async throws -> PresetDeployResult {
        try await sendJSON("POST", "/api/v1/presets/\(id)/deploy", body)
    }

    /// Claim an existing profile for this preset so a later deploy can rebuild it in place.
    public func adoptPreset(id: Int, qualityProfileId: Int) async throws {
        try await sendJSON("POST", "/api/v1/presets/\(id)/adopt", .object(["quality_profile_id": .int(qualityProfileId)]))
    }
}
