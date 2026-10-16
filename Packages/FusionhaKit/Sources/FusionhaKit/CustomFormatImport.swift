import Foundation

// Custom Formats › Import (web `CfImportPanel`, `lib/api/cf-import.ts`):
// pull custom formats + scored profiles from a live Sonarr/Radarr, or apply
// a bundled arr-capture preset with no network.

/// One media section's import counts (`CfImportSectionResult`).
public struct CfImportSection: Decodable, Sendable, Hashable {
    public let mediaKind: String
    /// `created` / `updated` / `skipped`.
    public let customFormats: [String: Int]?
    public let profiles: Int?
    public let formatScores: Int?

    /// "Movies — 3 created · 1 updated · 0 skipped custom formats · 2 profiles · 40 format scores".
    public var summary: String {
        let cf = customFormats ?? [:]
        return "\(CfImportText.mediaLabel(mediaKind)) — \(cf["created"] ?? 0) created · \(cf["updated"] ?? 0) updated · "
            + "\(cf["skipped"] ?? 0) skipped custom formats · \(profiles ?? 0) profiles · \(formatScores ?? 0) format scores"
    }
}

public struct ArrCfImportResult: Decodable, Sendable {
    public let kind: String
    public let mediaKind: String
    public let section: CfImportSection
}

public struct BundledPresetSummary: Decodable, Sendable, Hashable, Identifiable {
    public struct Counts: Decodable, Sendable, Hashable {
        public let customFormats: Int
        public let profiles: Int
    }

    public let name: String
    public let filename: String
    public let sections: [String: Counts]

    public var id: String { filename }

    /// "Movies: 30 CFs · 2 profiles" per present section (movie, then series).
    public var chips: [String] {
        ["movie", "series"].compactMap { kind in
            guard let c = sections[kind] else { return nil }
            return "\(CfImportText.mediaLabel(kind)): \(c.customFormats) CFs · \(c.profiles) profiles"
        }
    }
}

public struct BundledPresetResult: Decodable, Sendable {
    public let name: String
    public let sections: [CfImportSection]
}

public enum CfImportText {
    public static func mediaLabel(_ kind: String) -> String {
        switch kind {
        case "movie": return "Movies"
        case "series": return "Series"
        case "anime": return "Anime"
        default: return kind.prefix(1).uppercased() + kind.dropFirst()
        }
    }

    /// Sonarr → series CFs, Radarr → movie CFs.
    public static func arrMediaKind(_ kind: String) -> String { kind == "sonarr" ? "series" : "movie" }
}

extension APIClient {
    /// `POST /customformats/import-from-arr`. With both imports off it is the
    /// zero-write Test probe (a bad URL or key still fails).
    public func importCustomFormatsFromArr(kind: String, url: String, apiKey: String, importCfs: Bool,
                                           importProfiles: Bool, overwrite: Bool) async throws -> ArrCfImportResult {
        try await sendJSON("POST", "/api/v1/customformats/import-from-arr", .object([
            "kind": .string(kind), "url": .string(url), "api_key": .string(apiKey),
            "import_cfs": .bool(importCfs), "import_profiles": .bool(importProfiles), "overwrite": .bool(overwrite),
        ]))
    }

    public func bundledCfPresets() async throws -> [BundledPresetSummary] {
        try await get("/api/v1/customformats/presets")
    }

    public func applyBundledCfPreset(name: String, overwrite: Bool) async throws -> BundledPresetResult {
        try await sendJSON("POST", "/api/v1/customformats/import-preset",
                           .object(["name": .string(name), "overwrite": .bool(overwrite)]))
    }
}
